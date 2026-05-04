import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'asr_config.dart';
import 'model/asr_result.dart';
import 'model/asr_state.dart';
import 'utils/sherpa_models_manager.dart';
import 'utils/asr_logger.dart';
import 'vad/asr_vad_config.dart';
import 'vad/asr_vad_manager.dart';
import 'vad/asr_vad_state.dart';
import 'speaker/asr_speaker_config.dart';
import 'speaker/asr_speaker_manager.dart';
import 'speaker/asr_diarization_manager.dart';
import 'speaker/asr_diarizer.dart';

/// ASR 服务
/// 单例模式，协调 ASR 识别、VAD、Speaker ID、Diarization
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

  // 子管理器
  late final AsrSpeakerManager _speakerManager;
  late final AsrDiarizationManager _diarizationManager;
  late final AsrVadManager _vadManager;

  bool _managersInitialized = false;

  // ==================== 公开 getter（转发到管理器） ====================

  // VAD
  Stream<VadState> get vadStateStream => _vadManager.stateStream;
  AsrVadConfig get vadConfig => _vadManager.config;
  bool get isVadEnabled => _vadManager.isEnabled;

  // Speaker ID
  Stream<String> get speakerStateStream => _speakerManager.stateStream;
  AsrSpeakerConfig get speakerConfig => _speakerManager.config;
  bool get isSpeakerIdEnabled => _speakerManager.isEnabled;

  // Diarization
  Stream<String?> get speakerChangeStream => _diarizationManager.stateStream;
  bool get isDiarizationEnabled => _diarizationManager.isEnabled;
  String? get currentSpeakerLabel => _diarizationManager.currentSpeakerLabel;
  int get activeSpeakerCount => _diarizationManager.activeSpeakerCount;
  List<IdentifiedSpeaker> get activeSpeakers =>
      _diarizationManager.activeSpeakers;

  // 状态
  Stream<AsrState> get stateStream => _stateController.stream;
  Stream<String> get resultStream => _resultController.stream;
  Stream<AsrResult> get resultWithTimestampsStream =>
      _resultWithTimestampsController.stream;
  Stream<double> get progressStream => _progressController.stream;
  Stream<String> get statusStream => _statusController.stream;

  AsrState get state => _state;
  bool get isReady =>
      _state == AsrState.ready || _state == AsrState.readyOnline;
  bool get isListening => _state == AsrState.listening;
  AsrMode get currentMode => _currentMode;

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

  /// 初始化管理器（延迟初始化，避免构造时依赖未就绪）
  void _ensureManagers() {
    if (_managersInitialized) return;
    _managersInitialized = true;

    _speakerManager = AsrSpeakerManager();
    _diarizationManager = AsrDiarizationManager(_speakerManager);
    _vadManager = AsrVadManager(
      onProcessSamples: _processOfflineSamples,
      onResultWithSpeaker: (labeledText) {
        _resultController.add(labeledText);
      },
      diarizationManager: _diarizationManager,
    );
  }

  /// 设置日志记录器
  void setLogger(AsrLogger logger) {
    _logger = logger;
    _ensureManagers();
    _speakerManager.setLogger(logger);
    _diarizationManager.setLogger(logger);
    _vadManager.setLogger(logger);
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
    if (_modelPath == null) return 'unknown';
    final streamingEncoder = File(
      '$_modelPath/encoder-epoch-99-avg-1.int8.onnx',
    );
    if (await streamingEncoder.exists()) return 'streaming_transducer';
    final ctcModel = File('$_modelPath/model.int8.onnx');
    if (await ctcModel.exists()) return 'ctc';
    final encoderModel = File('$_modelPath/encoder-epoch-20-avg-1.onnx');
    if (await encoderModel.exists()) return 'transducer';
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

  // ==================== 识别核心 ====================

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
    _diarizationManager.setRecognitionStartTime(_recognitionStartTime);
    if (_currentMode == AsrMode.offline && _sherpaRecognizer != null) {
      _stream?.free();
      _stream = _sherpaRecognizer!.createStream();
    }
    _updateState(AsrState.listening);
    _log('ASR: 开始识别');
  }

  /// 停止识别
  Future<String?> stopRecognition() async {
    if (_state != AsrState.listening) return null;

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
    if (_state != AsrState.listening) return;

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
  void acceptAudio(Float32List samples) {
    if (_state != AsrState.listening) return;
    if (_currentMode == AsrMode.offline &&
        _sherpaRecognizer != null &&
        _stream != null) {
      if (_vadManager.isEnabled) {
        _vadManager.processAudio(samples, () => currentSpeakerLabel);
      } else {
        _processOfflineSamples(samples);
      }
    }
  }

  /// 处理流式识别音频
  void _processOfflineSamples(Float32List samples) {
    try {
      _stream!.acceptWaveform(
        samples: samples,
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

        final asrTimestamps = AsrTimestamp.fromTokensAndTimestamps(
          sherpaResult.tokens,
          sherpaResult.timestamps,
        );
        _resultWithTimestampsController.add(
          AsrResult(
            text: fullText,
            timestamps: asrTimestamps,
            isFinal: isEndpoint,
          ),
        );
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
    if (_diarizationManager.isEnabled) {
      _diarizationManager.reset();
    }
    _log('ASR: 识别器已重置');
  }

  // ==================== VAD 转发 ====================

  Future<void> enableVAD(bool enabled) async {
    _ensureManagers();
    await _vadManager.enable(enabled);
  }

  Future<void> setVadConfig(AsrVadConfig config) async {
    _ensureManagers();
    await _vadManager.updateConfig(config);
  }

  // ==================== Speaker ID 转发 ====================

  Future<void> enableSpeakerId(bool enabled) async {
    _ensureManagers();
    await _speakerManager.enable(enabled);
  }

  Future<void> setSpeakerIdConfig(AsrSpeakerConfig config) async {
    _ensureManagers();
    await _speakerManager.updateConfig(config);
  }

  Future<bool> registerSpeaker(String name, Duration duration) async {
    _ensureManagers();
    return await _speakerManager.registerSpeaker(name, duration);
  }

  void startSpeakerRegistration() {
    _ensureManagers();
    _speakerManager.startRegistration();
  }

  Float32List? finishSpeakerRegistration() {
    _ensureManagers();
    return _speakerManager.finishRegistration();
  }

  Future<String> identifySpeaker() async {
    return '';
  }

  Future<bool> verifySpeaker(String name, Float32List embedding) async {
    _ensureManagers();
    return await _speakerManager.verifySpeaker(name, embedding);
  }

  Future<void> removeSpeaker(String name) async {
    _ensureManagers();
    await _speakerManager.removeSpeaker(name);
  }

  Future<List<String>> listSpeakers() async {
    _ensureManagers();
    return await _speakerManager.listSpeakers();
  }

  Future<void> clearAllSpeakers() async {
    _ensureManagers();
    await _speakerManager.clearAll();
  }

  Future<int> getSpeakerCount() async {
    _ensureManagers();
    return await _speakerManager.getCount();
  }

  void acceptAudioForSpeaker(Float32List samples) {
    _ensureManagers();
    _speakerManager.acceptAudio(samples);
  }

  Float32List? computeSpeakerEmbedding() {
    _ensureManagers();
    return _speakerManager.computeEmbedding();
  }

  void resetSpeakerId() {
    _ensureManagers();
    _speakerManager.resetStream();
  }

  // ==================== Diarization 转发 ====================

  Future<void> enableDiarization(bool enabled) async {
    _ensureManagers();
    await _diarizationManager.enable(enabled);
  }

  Future<void> setDiarizationConfig(AsrDiarizationConfig config) async {
    _ensureManagers();
    await _diarizationManager.updateConfig(config);
  }

  void resetDiarization() {
    _ensureManagers();
    _diarizationManager.reset();
  }

  // ==================== 资源释放 ====================

  Future<void> dispose() async {
    _silenceTimer?.cancel();

    if (_managersInitialized) {
      _vadManager.dispose();
      _speakerManager.dispose();
      _diarizationManager.dispose();
    }

    await _stateController.close();
    await _resultController.close();
    await _resultWithTimestampsController.close();
    await _progressController.close();
    await _statusController.close();

    _stream?.free();
    _stream = null;
    _sherpaRecognizer?.free();
    _sherpaRecognizer = null;

    _updateState(AsrState.idle);
    _log('ASR: 服务已释放');
  }
}
