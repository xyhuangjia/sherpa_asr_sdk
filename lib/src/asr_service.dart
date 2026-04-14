import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'asr_config.dart';
import 'asr_result.dart';
import 'asr_state.dart';
import 'model/sherpa_models_manager.dart';
import 'utils/asr_logger.dart';
import 'vad/asr_vad_config.dart';
import 'vad/asr_vad_state.dart';
import 'speaker/asr_speaker_config.dart';
import 'speaker/asr_diarizer.dart';
import 'speaker/speaker_data_storage.dart';

/// ASR 服务
/// 单例模式，提供语音识别功能
class AsrService {
  AsrService._internal();

  static final AsrService instance = AsrService._internal();

  AsrLogger? _logger;
  AsrState _state = AsrState.idle;

  final StreamController<AsrState> _stateController =
      StreamController<AsrState>.broadcast();

  final StreamController<String> _resultController =
      StreamController<String>.broadcast();

  final StreamController<AsrResult> _resultWithTimestampsController =
      StreamController<AsrResult>.broadcast();

  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  sherpa_onnx.OnlineRecognizer? _sherpaRecognizer;
  sherpa_onnx.OnlineStream? _stream;
  String? _modelPath;
  AsrMode _currentMode = AsrMode.offline;
  String _accumulatedText = '';
  DateTime? _recognitionStartTime;
  Timer? _silenceTimer;

  // VAD 相关成员
  sherpa_onnx.VoiceActivityDetector? _vad;
  AsrVadConfig _vadConfig = const AsrVadConfig();
  bool _isVadEnabled = false;
  bool _isSpeechDetected = false;
  final StreamController<VadState> _vadStateController =
      StreamController<VadState>.broadcast();

  // VAD 状态流
  Stream<VadState> get vadStateStream => _vadStateController.stream;

  // VAD 配置
  AsrVadConfig get vadConfig => _vadConfig;
  bool get isVadEnabled => _isVadEnabled;

  // Speaker ID 相关成员
  sherpa_onnx.SpeakerEmbeddingExtractor? _speakerExtractor;
  sherpa_onnx.SpeakerEmbeddingManager? _speakerManager;
  AsrSpeakerConfig _speakerConfig = const AsrSpeakerConfig();
  bool _isSpeakerIdEnabled = false;
  final SpeakerDataStorage _speakerStorage = SpeakerDataStorage();

  // Speaker ID 活跃流管理
  sherpa_onnx.OnlineStream? _speakerStream;

  // Speaker ID 状态流
  final StreamController<String> _speakerStateController =
      StreamController<String>.broadcast();
  Stream<String> get speakerStateStream => _speakerStateController.stream;

  // Speaker ID 配置和状态
  AsrSpeakerConfig get speakerConfig => _speakerConfig;
  bool get isSpeakerIdEnabled => _isSpeakerIdEnabled;

  // ==================== Diarization (多人说话人自动聚类) ====================

  AsrDiarizer? _diarizer;
  AsrDiarizationConfig _diarizationConfig = const AsrDiarizationConfig();
  bool _isDiarizationEnabled = false;
  String? _currentSpeakerLabel;
  sherpa_onnx.OnlineStream? _diarizationSpeakerStream;

  final StreamController<String?> _diarizationStateController =
      StreamController<String?>.broadcast();

  Stream<String?> get speakerChangeStream => _diarizationStateController.stream;
  bool get isDiarizationEnabled => _isDiarizationEnabled;
  String? get currentSpeakerLabel => _currentSpeakerLabel;
  int get activeSpeakerCount => _diarizer?.speakerCount ?? 0;
  List<IdentifiedSpeaker> get activeSpeakers => _diarizer?.speakers ?? [];

  Future<void> setDiarizationConfig(AsrDiarizationConfig config) async {
    _diarizationConfig = config;
    _diarizer?.updateConfig(config);
    _log('ASR: 说话人自动聚类配置已更新 - $config');
  }

  /// 状态流
  Stream<AsrState> get stateStream => _stateController.stream;

  /// 识别结果流
  Stream<String> get resultStream => _resultController.stream;

  /// 带时间戳的识别结果流
  Stream<AsrResult> get resultWithTimestampsStream =>
      _resultWithTimestampsController.stream;

  /// 初始化进度流
  Stream<double> get progressStream => _progressController.stream;

  /// 状态描述流
  Stream<String> get statusStream => _statusController.stream;

  /// 当前状态
  AsrState get state => _state;

  /// 是否已就绪
  bool get isReady =>
      _state == AsrState.ready || _state == AsrState.readyOnline;

  /// 是否正在识别
  bool get isListening => _state == AsrState.listening;

  /// 当前识别模式
  AsrMode get currentMode => _currentMode;

  /// 识别时长（秒）
  int get recognitionDuration {
    if (_recognitionStartTime == null) return 0;
    return DateTime.now().difference(_recognitionStartTime!).inSeconds;
  }

  void _log(String message) {
    _logger?.debug(message);
  }

  void _updateState(AsrState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// 设置日志记录器
  void setLogger(AsrLogger logger) {
    _logger = logger;
  }

  /// 初始化离线 ASR
  Future<bool> initialize({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    try {
      _updateState(AsrState.loading);
      _statusController.add('正在初始化识别器...');
      onStatus?.call('正在初始化识别器...');

      await SherpaModelsManager.instance.initialize();

      onProgress?.call(0.2);
      onStatus?.call('检查模型文件...');

      String? modelPath = await SherpaModelsManager.instance.getBestModelPath();
      if (modelPath == null) {
        onStatus?.call('准备模型文件...');
        final success = await _downloadModelIfNeeded(
          onProgress: (p) => onProgress?.call(0.2 + p * 0.3),
          onStatus: onStatus,
        );
        if (!success) {
          _updateState(AsrState.error);
          _statusController.add('模型文件不可用');
          return false;
        }
        modelPath = await SherpaModelsManager.instance.getBestModelPath();
      }
      _modelPath = modelPath;

      onProgress?.call(0.5);
      onStatus?.call('加载识别模型...');

      final success = await _initializeSherpaRecognizer(
        onProgress: (p) => onProgress?.call(0.5 + p * 0.5),
        onStatus: onStatus,
      );

      if (success) {
        _currentMode = AsrMode.offline;
        _updateState(AsrState.ready);
        _statusController.add('离线识别就绪');
        _log('ASR: 初始化成功（离线模式）');
        return true;
      } else {
        _updateState(AsrState.error);
        _statusController.add('初始化失败');
        return false;
      }
    } catch (e) {
      _log('ASR: 初始化失败: $e');
      _updateState(AsrState.error);
      _statusController.add('初始化失败: $e');
      return false;
    }
  }

  /// 初始化 Sherpa-onnx 识别器
  Future<bool> _initializeSherpaRecognizer({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    try {
      if (_modelPath == null) {
        _log('ASR: 模型路径未设置');
        return false;
      }
      onStatus?.call('加载 Sherpa-onnx...');
      final modelType = await _detectModelType();
      _log('ASR: 检测到模型类型: $modelType');
      if (modelType != 'streaming_transducer') {
        _log('ASR: 当前仅支持流式 Transducer 模型');
        return false;
      }
      sherpa_onnx.initBindings();
      final modelConfig = sherpa_onnx.OnlineModelConfig(
        transducer: sherpa_onnx.OnlineTransducerModelConfig(
          encoder: '$_modelPath/encoder-epoch-99-avg-1.int8.onnx',
          decoder: '$_modelPath/decoder-epoch-99-avg-1.onnx',
          joiner: '$_modelPath/joiner-epoch-99-avg-1.onnx',
        ),
        tokens: '$_modelPath/tokens.txt',
        modelType: 'zipformer',
      );
      final config = sherpa_onnx.OnlineRecognizerConfig(
        model: modelConfig,
        ruleFsts: '',
      );
      _sherpaRecognizer = sherpa_onnx.OnlineRecognizer(config);
      onProgress?.call(1.0);
      _log('ASR: 初始化成功');
      return true;
    } catch (e) {
      _log('ASR: 初始化失败: $e');
      return false;
    }
  }

  /// 检测当前模型类型
  Future<String> _detectModelType() async {
    if (_modelPath == null) {
      return 'unknown';
    }
    final streamingEncoder = File(
      '$_modelPath/encoder-epoch-99-avg-1.int8.onnx',
    );
    if (await streamingEncoder.exists()) {
      return 'streaming_transducer';
    }
    final ctcModel = File('$_modelPath/model.int8.onnx');
    if (await ctcModel.exists()) {
      return 'ctc';
    }
    final encoderModel = File('$_modelPath/encoder-epoch-20-avg-1.onnx');
    if (await encoderModel.exists()) {
      return 'transducer';
    }
    return 'unknown';
  }

  /// 下载模型
  Future<bool> _downloadModelIfNeeded({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    try {
      onStatus?.call('首次使用，需要下载模型...');
      bool success = await SherpaModelsManager.instance
          .downloadStreamingBilingualModels(
            onProgress: onProgress,
            onStatusChange: onStatus,
          );
      if (success) return true;
      success = await SherpaModelsManager.instance.downloadBaseModels(
        onProgress: onProgress,
        onStatusChange: onStatus,
      );
      if (success) {
        _log('ASR: 基础模型下载成功');
        return true;
      }
      _log('ASR: 模型下载失败');
      return false;
    } catch (e) {
      _log('ASR: 下载模型失败: $e');
      return false;
    }
  }

  /// 开始识别
  Future<void> startRecognition() async {
    if (_state == AsrState.listening) {
      _log('ASR: 识别已在进行中');
      return;
    }
    if (!isReady) {
      _log('ASR: 识别器未就绪');
      return;
    }
    _accumulatedText = '';
    _recognitionStartTime = DateTime.now();
    if (_currentMode == AsrMode.offline && _sherpaRecognizer != null) {
      _stream?.free();
      _stream = _sherpaRecognizer!.createStream();
    }
    _updateState(AsrState.listening);
    _log('ASR: 开始识别');
  }

  /// 停止识别
  Future<String?> stopRecognition() async {
    if (_state != AsrState.listening) {
      return null;
    }
    _silenceTimer?.cancel();
    String? finalResult;
    if (_currentMode == AsrMode.offline &&
        _sherpaRecognizer != null &&
        _stream != null) {
      final remaining = _sherpaRecognizer!.getResult(_stream!).text;
      finalResult = _accumulatedText + remaining;
      _stream?.free();
      _stream = _sherpaRecognizer!.createStream();
    }
    _updateState(isReady ? AsrState.ready : AsrState.readyOnline);
    _log('ASR: 停止识别，结果: $finalResult');
    if (finalResult != null && finalResult.isNotEmpty) {
      _resultController.add(finalResult);
    }
    return finalResult;
  }

  /// 取消识别
  Future<void> cancelRecognition() async {
    if (_state != AsrState.listening) {
      return;
    }
    _silenceTimer?.cancel();
    if (_currentMode == AsrMode.offline &&
        _sherpaRecognizer != null &&
        _stream != null) {
      _stream?.free();
      _stream = _sherpaRecognizer!.createStream();
    }
    _updateState(isReady ? AsrState.ready : AsrState.readyOnline);
    _log('ASR: 取消识别');
  }

  /// 接受音频数据
  void acceptAudio(List<double> samples) {
    if (_state != AsrState.listening) {
      return;
    }
    if (_currentMode == AsrMode.offline &&
        _sherpaRecognizer != null &&
        _stream != null) {
      // 使用 VAD 处理或直接用原有方法
      if (_isVadEnabled && _vad != null) {
        _processAudioWithVad(samples);
      } else {
        _processOfflineSamples(samples);
      }
    }
  }

  /// 处理流式识别音频
  void _processOfflineSamples(List<double> samples) {
    try {
      final float32 = Float32List.fromList(samples);
      _stream!.acceptWaveform(
        samples: float32,
        sampleRate: AsrConfig.targetSampleRate,
      );
      while (_sherpaRecognizer!.isReady(_stream!)) {
        _sherpaRecognizer!.decode(_stream!);
      }
      final sherpaResult = _sherpaRecognizer!.getResult(_stream!);
      final text = sherpaResult.text;
      final fullText = _accumulatedText + text;
      final isEndpoint = _sherpaRecognizer!.isEndpoint(_stream!);

      if (fullText.isNotEmpty) {
        _resultController.add(fullText);

        // 构建带时间戳的结果
        final asrTimestamps = AsrTimestamp.fromTokensAndTimestamps(
          sherpaResult.tokens,
          sherpaResult.timestamps,
        );
        _resultWithTimestampsController.add(AsrResult(
          text: fullText,
          timestamps: asrTimestamps,
          isFinal: isEndpoint,
        ));
      }
      if (isEndpoint) {
        _sherpaRecognizer!.reset(_stream!);
        if (text.isNotEmpty) {
          _accumulatedText = fullText;
        }
      }
    } catch (e) {
      _log('ASR: 处理音频数据失败: $e');
    }
  }

  /// 重置识别器状态
  void reset() {
    if (_currentMode == AsrMode.offline &&
        _sherpaRecognizer != null &&
        _stream != null) {
      _sherpaRecognizer!.reset(_stream!);
    }
    if (_isDiarizationEnabled) {
      resetDiarization();
    }
    _log('ASR: 识别器已重置');
  }

  // ==================== VAD 方法 ====================

  /// 启用/禁用 VAD
  Future<void> enableVAD(bool enabled) async {
    _isVadEnabled = enabled;
    if (enabled) {
      await _initializeVad();
    } else {
      _vad?.free();
      _vad = null;
    }
    _log('ASR: VAD 已${enabled ? "启用" : "禁用"}');
  }

  /// 设置 VAD 配置
  Future<void> setVadConfig(AsrVadConfig config) async {
    _vadConfig = config;
    _log('ASR: VAD 配置已更新 - $config');

    // 如果 VAD 已启用，重新初始化
    if (_isVadEnabled) {
      await _initializeVad();
    }
  }

  /// 初始化 VAD
  Future<void> _initializeVad() async {
    try {
      _vad?.free();

      // 获取 VAD 模型路径
      String? vadModelPath = await SherpaModelsManager.instance.getVadModelPath();

      // 如果没有独立 VAD 模型，尝试基础模型目录中的 VAD 模型
      if (vadModelPath == null) {
        final baseVadFile = File(
          '${await SherpaModelsManager.instance.getBaseModelPath()}/silero_vad.onnx',
        );
        if (await baseVadFile.exists()) {
          vadModelPath = '${await SherpaModelsManager.instance.getBaseModelPath()}';
        }
      }

      if (vadModelPath == null) {
        _log('ASR: VAD 模型未找到，VAD 功能不可用');
        return;
      }

      final config = sherpa_onnx.VadModelConfig(
        sileroVad: sherpa_onnx.SileroVadModelConfig(
          model: '$vadModelPath/silero_vad.onnx',
          threshold: _vadConfig.threshold,
          minSilenceDuration: _vadConfig.minSilenceDuration,
          minSpeechDuration: _vadConfig.minSpeechDuration,
          maxSpeechDuration: _vadConfig.maxSpeechDuration,
          windowSize: _vadConfig.windowSize,
        ),
        sampleRate: AsrConfig.targetSampleRate,
        numThreads: 1,
        provider: 'cpu',
        debug: true,
      );

      _vad = sherpa_onnx.VoiceActivityDetector(
        config: config,
        bufferSizeInSeconds: 60,
      );

      _log('ASR: VAD 初始化成功');
    } catch (e) {
      _log('ASR: VAD 初始化失败 - $e');
      _isVadEnabled = false;
    }
  }

  /// 处理带 VAD 的音频数据
  void _processAudioWithVad(List<double> samples) {
    if (!_isVadEnabled || _vad == null) {
      _processOfflineSamples(samples);
      return;
    }

    try {
      final float32 = Float32List.fromList(samples);
      _vad!.acceptWaveform(float32);

      // 检查是否检测到语音
      if (_vad!.isDetected()) {
        if (!_isSpeechDetected) {
          // 语音开始
          _isSpeechDetected = true;
          _vadStateController.add(VadState.speechStarted);
          _log('ASR VAD: 检测到语音开始');

          // 创建新的识别流
          _stream?.free();
          _stream = _sherpaRecognizer?.createStream();

          // 创建 Speaker Stream 并开始收集音频
          _startDiarizationSegment();
        } else {
          _vadStateController.add(VadState.speechInProgress);
        }

        // 喂音频给 Speaker Stream（Diarization）
        _feedDiarizationAudio(float32);

        // 处理音频（空值检查）
        if (_sherpaRecognizer != null && _stream != null) {
          _processOfflineSamples(samples);
        }
      } else {
        // VAD 未检测到语音，可能是静音
        if (_isSpeechDetected) {
          _vadStateController.add(VadState.silence);
        }
      }

      // 检查是否有完整的语音段
      if (!_vad!.isEmpty()) {
        final segment = _vad!.front();
        if (segment.samples.isNotEmpty) {
          // 语音结束
          _isSpeechDetected = false;
          _vadStateController.add(VadState.speechEnded);
          _log('ASR VAD: 检测到语音结束');

          // 提取说话人特征并识别
          _identifySpeakerAtSegmentEnd();

          // 获取最终识别结果
          if (_sherpaRecognizer != null && _stream != null) {
            final text = _sherpaRecognizer!.getResult(_stream!).text;
            if (text.isNotEmpty) {
              final result = AsrResult(
                text: text,
                timestamps: [],
                isFinal: true,
                speakerLabel: _currentSpeakerLabel,
              );
              _resultController.add(result.labeledText);
            }

            _stream?.free();
            _stream = _sherpaRecognizer?.createStream();
          }
          _vad!.pop();
        }
      }
    } catch (e) {
      _log('ASR VAD: 处理音频失败 - $e');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _silenceTimer?.cancel();

    // 释放 VAD 资源
    _vad?.free();
    _vad = null;

    // 释放 Speaker ID 资源
    _speakerStream?.free();
    _speakerStream = null;
    _speakerExtractor?.free();
    _speakerExtractor = null;
    _speakerManager?.free();
    _speakerManager = null;

    // 关闭所有流控制器
    await _vadStateController.close();
    await _speakerStateController.close();
    await _diarizationStateController.close();
    await _stateController.close();
    await _resultController.close();
    await _resultWithTimestampsController.close();
    await _progressController.close();
    await _statusController.close();

    // 释放 ASR 资源
    _stream?.free();
    _stream = null;
    _sherpaRecognizer?.free();
    _sherpaRecognizer = null;

    _updateState(AsrState.idle);
    _log('ASR: 服务已释放');
  }

  // ==================== Speaker ID 方法 ====================

  /// 启用/禁用说话人识别
  Future<void> enableSpeakerId(bool enabled) async {
    _isSpeakerIdEnabled = enabled;
    if (enabled) {
      await _initializeSpeakerId();
    }
    _log('ASR: 说话人识别已${enabled ? "启用" : "禁用"}');
  }

  /// 设置说话人识别配置
  Future<void> setSpeakerIdConfig(AsrSpeakerConfig config) async {
    _speakerConfig = config;
    _log('ASR: 说话人识别配置已更新 - $config');

    if (_isSpeakerIdEnabled) {
      await _initializeSpeakerId();
    }
  }

  /// 初始化说话人识别
  Future<void> _initializeSpeakerId() async {
    try {
      _speakerExtractor?.free();
      _speakerManager?.free();

      // 初始化存储
      await _speakerStorage.initialize();

      // 获取说话人识别模型路径
      String? reidModelPath = await SherpaModelsManager.instance.getSpeakerReidModelPath();

      if (reidModelPath == null) {
        _log('ASR: 说话人识别模型未找到，功能不可用');
        _isSpeakerIdEnabled = false;
        return;
      }

      // 创建特征提取器
      final extractorConfig = sherpa_onnx.SpeakerEmbeddingExtractorConfig(
        model: '$reidModelPath/model.onnx',
        numThreads: 1,
        debug: true,
        provider: 'cpu',
      );

      _speakerExtractor = sherpa_onnx.SpeakerEmbeddingExtractor(
        config: extractorConfig,
      );

      // 创建管理器
      final dim = _speakerExtractor!.dim;
      _speakerManager = sherpa_onnx.SpeakerEmbeddingManager(dim);

      // 加载已保存的说话人数据
      await _loadSavedSpeakers();

      _log('ASR: 说话人识别初始化成功，维度：$dim');
    } catch (e) {
      _log('ASR: 说话人识别初始化失败 - $e');
      _isSpeakerIdEnabled = false;
    }
  }

  /// 加载已保存的说话人数据
  Future<void> _loadSavedSpeakers() async {
    try {
      final speakers = await _speakerStorage.getAllSpeakers();
      for (final name in speakers) {
        final embedding = await _speakerStorage.loadSpeaker(name);
        if (embedding != null) {
          _speakerManager?.add(name: name, embedding: embedding);
        }
      }
      _log('ASR: 已加载 ${speakers.length} 个说话人');
    } catch (e) {
      _log('ASR: 加载说话人数据失败 - $e');
    }
  }

  /// 注册说话人
  ///
  /// [name] 说话人姓名
  /// [duration] 注册时长（建议 3-5 秒）
  ///
  /// 注意：调用此方法前，需要先调用 [startSpeakerRegistration] 开始录音，
  /// 并在注册期间持续调用 [acceptAudioForSpeaker] 提供音频数据。
  /// 或者，使用简化版本：直接调用本方法，会在指定时长内等待音频数据。
  Future<bool> registerSpeaker(String name, Duration duration) async {
    if (!_isSpeakerIdEnabled || _speakerExtractor == null) {
      _log('ASR: 说话人识别未启用');
      return false;
    }

    try {
      _log('ASR: 开始注册说话人 - $name');

      // 创建新的流
      final stream = _speakerExtractor!.createStream();

      // 简化实现：等待指定时长，假设外部会调用 acceptAudioForSpeaker 提供数据
      // 实际使用中，应该在使用 AsrRecorder 时自动完成这个过程
      final startTime = DateTime.now();
      while (DateTime.now().difference(startTime) < duration) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 计算特征
      if (!_speakerExtractor!.isReady(stream)) {
        _log('ASR: 说话人注册失败 - 流未就绪');
        stream.free();
        return false;
      }

      final embedding = _speakerExtractor!.compute(stream);
      stream.free();

      if (embedding.isEmpty) {
        _log('ASR: 说话人注册失败 - 特征提取失败');
        return false;
      }

      // 保存到管理器
      final added = _speakerManager?.add(name: name, embedding: embedding);
      if (added != true) {
        _log('ASR: 说话人注册失败 - 添加到管理器失败');
        return false;
      }

      // 持久化存储
      final saved = await _speakerStorage.saveSpeaker(name, embedding);
      if (!saved) {
        _log('ASR: 说话人注册失败 - 持久化失败');
        _speakerManager?.remove(name);
        return false;
      }

      _log('ASR: 说话人注册成功 - $name');
      return true;
    } catch (e) {
      _log('ASR: 说话人注册失败 - $e');
      return false;
    }
  }

  /// 开始说话人注册
  ///
  /// 调用此方法后，需要持续调用 [acceptAudioForSpeaker] 提供音频数据
  void startSpeakerRegistration() {
    if (!_isSpeakerIdEnabled || _speakerExtractor == null) {
      return;
    }
    resetSpeakerId();
    _log('ASR: 开始说话人注册流程');
  }

  /// 完成说话人注册并获取特征
  ///
  /// 返回提取的 embedding 向量，调用者负责保存到 Manager 和存储
  Float32List? finishSpeakerRegistration() {
    if (_speakerStream == null || _speakerExtractor == null) {
      return null;
    }

    try {
      if (!_speakerExtractor!.isReady(_speakerStream!)) {
        return null;
      }

      final embedding = _speakerExtractor!.compute(_speakerStream!);
      resetSpeakerId();

      return embedding.isEmpty ? null : embedding;
    } catch (e) {
      _log('ASR: 完成说话人注册失败 - $e');
      return null;
    }
  }

  /// 识别当前说话人
  Future<String> identifySpeaker() async {
    if (!_isSpeakerIdEnabled || _speakerExtractor == null) {
      return '';
    }

    try {
      // 注意：实际使用中需要从音频流提取特征
      // 这里简化处理，返回空字符串表示未知
      _log('ASR: 识别说话人 - 需要从音频流提取特征');
      return '';
    } catch (e) {
      _log('ASR: 识别说话人失败 - $e');
      return '';
    }
  }

  /// 验证说话人身份
  Future<bool> verifySpeaker(String name, Float32List embedding) async {
    if (!_isSpeakerIdEnabled || _speakerManager == null) {
      return false;
    }

    try {
      final verified = _speakerManager!.verify(
        name: name,
        embedding: embedding,
        threshold: _speakerConfig.verificationThreshold,
      );
      return verified;
    } catch (e) {
      _log('ASR: 验证说话人失败 - $e');
      return false;
    }
  }

  /// 移除说话人
  Future<void> removeSpeaker(String name) async {
    if (_speakerManager != null) {
      _speakerManager?.remove(name);
    }
    await _speakerStorage.deleteSpeaker(name);
    _log('ASR: 说话人已移除 - $name');
  }

  /// 列出所有已注册的说话人
  Future<List<String>> listSpeakers() async {
    return await _speakerStorage.getAllSpeakers();
  }

  /// 清除所有说话人数据
  Future<void> clearAllSpeakers() async {
    _speakerManager = null;
    await _speakerStorage.clearAllSpeakers();

    // 重新初始化管理器
    if (_isSpeakerIdEnabled) {
      await _initializeSpeakerId();
    }
    _log('ASR: 所有说话人已清除');
  }

  /// 获取已注册说话人数量
  Future<int> getSpeakerCount() async {
    return await _speakerStorage.getSpeakerCount();
  }

  /// 为说话人识别提供音频数据
  void acceptAudioForSpeaker(List<double> samples) {
    if (!_isSpeakerIdEnabled || _speakerExtractor == null) {
      return;
    }

    try {
      // 如果还没有活跃流，创建一个
      _speakerStream ??= _speakerExtractor!.createStream();

      final float32 = Float32List.fromList(samples);
      _speakerStream!.acceptWaveform(
        samples: float32,
        sampleRate: AsrConfig.targetSampleRate,
      );
    } catch (e) {
      _log('ASR: 提取说话人特征失败 - $e');
    }
  }

  /// 计算当前说话人特征
  /// 返回提取的 embedding 向量
  Float32List? computeSpeakerEmbedding() {
    if (_speakerStream == null || _speakerExtractor == null) {
      return null;
    }

    try {
      if (!_speakerExtractor!.isReady(_speakerStream!)) {
        return null;
      }

      final embedding = _speakerExtractor!.compute(_speakerStream!);

      // 释放旧流并创建新流
      _speakerStream?.free();
      _speakerStream = _speakerExtractor!.createStream();

      return embedding.isEmpty ? null : embedding;
    } catch (e) {
      _log('ASR: 计算说话人特征失败 - $e');
      return null;
    }
  }

  /// 重置说话识别流
  void resetSpeakerId() {
    _speakerStream?.free();
    _speakerStream = null;
  }

  // ==================== Diarization (多人说话人自动聚类) ====================

  /// 启用/禁用说话人自动聚类
  Future<void> enableDiarization(bool enabled) async {
    _isDiarizationEnabled = enabled;
    if (enabled) {
      await _initializeDiarization();
    } else {
      _diarizer?.reset();
      _diarizer = null;
      _diarizationSpeakerStream?.free();
      _diarizationSpeakerStream = null;
    }
    _log('ASR: 说话人自动聚类已${enabled ? "启用" : "禁用"}');
  }

  /// 初始化 Diarization（自动下载并初始化 Speaker Extractor）
  Future<void> _initializeDiarization() async {
    // 检查模型是否存在，不存在则下载
    if (!await SherpaModelsManager.instance.hasSpeakerReidModel()) {
      _log('ASR: 说话人识别模型不存在，开始下载...');
      _statusController.add('下载说话人识别模型...');
      final downloadOk = await SherpaModelsManager.instance.downloadSpeakerReidModel(
        onProgress: (p) => _progressController.add(p),
        onStatusChange: (s) => _statusController.add(s),
      );
      if (!downloadOk) {
        _log('ASR: Speaker ReID 模型下载失败');
        _statusController.add('模型下载失败');
        _isDiarizationEnabled = false;
        return;
      }
    }

    // 初始化 Speaker Extractor（如果还没初始化）
    if (_speakerExtractor == null) {
      final success = await _initSpeakerExtractorForDiarization();
      if (!success) {
        _log('ASR: Speaker Extractor 初始化失败，Diarization 不可用');
        _isDiarizationEnabled = false;
        return;
      }
    }

    // 创建 Diarizer
    _diarizer = AsrDiarizer(_diarizationConfig);
    _log('ASR: 说话人自动聚类器已初始化');
  }

  /// 为 Diarization 初始化 Speaker Extractor
  Future<bool> _initSpeakerExtractorForDiarization() async {
    try {
      String? reidModelPath =
          await SherpaModelsManager.instance.getSpeakerReidModelPath();

      if (reidModelPath == null) {
        _log('ASR: 说话人识别模型未找到，Diarization 不可用');
        return false;
      }

      final extractorConfig = sherpa_onnx.SpeakerEmbeddingExtractorConfig(
        model: '$reidModelPath/model.onnx',
        numThreads: 1,
        debug: true,
        provider: 'cpu',
      );

      _speakerExtractor = sherpa_onnx.SpeakerEmbeddingExtractor(
        config: extractorConfig,
      );

      _log('ASR: Speaker Extractor 初始化成功，维度：${_speakerExtractor!.dim}');
      return true;
    } catch (e) {
      _log('ASR: Speaker Extractor 初始化失败 - $e');
      return false;
    }
  }

  /// 语音段开始时创建 Speaker Stream
  void _startDiarizationSegment() {
    if (!_isDiarizationEnabled || _speakerExtractor == null) return;

    _diarizationSpeakerStream?.free();
    _diarizationSpeakerStream = _speakerExtractor!.createStream();
  }

  /// 处理音频时喂给 Speaker Stream
  void _feedDiarizationAudio(Float32List samples) {
    if (!_isDiarizationEnabled || _diarizationSpeakerStream == null) return;

    try {
      _diarizationSpeakerStream!.acceptWaveform(
        samples: samples,
        sampleRate: AsrConfig.targetSampleRate,
      );
    } catch (e) {
      _log('ASR: Diarization 音频喂入失败 - $e');
    }
  }

  /// 语音段结束时提取说话人特征并识别
  void _identifySpeakerAtSegmentEnd() {
    if (!_isDiarizationEnabled ||
        _speakerExtractor == null ||
        _diarizationSpeakerStream == null) {
      return;
    }

    try {
      if (!_speakerExtractor!.isReady(_diarizationSpeakerStream!)) {
        _diarizationSpeakerStream?.free();
        _diarizationSpeakerStream = null;
        return;
      }

      final embedding = _speakerExtractor!.compute(_diarizationSpeakerStream!);
      _diarizationSpeakerStream?.free();
      _diarizationSpeakerStream = null;

      if (embedding.isEmpty) {
        _log('ASR: 说话人特征提取失败');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final duration = _recognitionStartTime != null
          ? DateTime.now().difference(_recognitionStartTime!).inSeconds.toDouble()
          : 0.0;

      final label = _diarizer!.identifySpeaker(embedding, duration, timestamp);

      if (_currentSpeakerLabel != label) {
        _currentSpeakerLabel = label;
        _diarizationStateController.add(label);
        _log('ASR: 说话人切换 -> $label');
      }
    } catch (e) {
      _log('ASR: 说话人识别失败 - $e');
    }
  }

  /// 重置说话人自动聚类状态
  void resetDiarization() {
    _diarizer?.reset();
    _currentSpeakerLabel = null;
    _diarizationSpeakerStream?.free();
    _diarizationSpeakerStream = null;
    _diarizationStateController.add(null);
    _log('ASR: 说话人自动聚类状态已重置');
  }
}
