import 'dart:async';
import 'dart:typed_data';

import 'asr_recorder.dart';
import 'asr_service.dart';
import 'asr_state.dart';
import 'utils/asr_logger.dart';
import 'vad/asr_vad_config.dart';
import 'vad/asr_vad_state.dart';
import 'speaker/asr_speaker_config.dart';

/// ASR SDK 全局服务
///
/// 工作流程：
/// 1. initialize()     - APP 启动时初始化模型（只调用一次）
/// 2. start()          - 进入页面时启动服务（创建录音器）
/// 3. recognize()      - 开始语音识别 ←┐
/// 4. stopRecognition()- 结束语音识别 ─┘ 可反复调用
/// 5. stop()           - 离开页面时停止服务（销毁录音器）
/// 6. dispose()        - 释放所有资源
///
/// 使用示例：
/// ```dart
/// // 设置日志（可选）
/// AsrSdk.setLogger(DefaultAsrLogger());
///
/// // 1. App 启动时（只调用一次）
/// await AsrSdk.initialize(
///   onProgress: (p) => print('进度: ${(p * 100).toInt()}%'),
///   onStatus: (s) => print('状态: $s'),
/// );
///
/// // 2. 进入页面时
/// await AsrSdk.start();
///
/// // 3. 开始识别（可反复调用）
/// AsrSdk.recognize().listen(
///   (text) => print('识别: $text'),
///   onDone: () => print('完成'),
/// );
///
/// // 4. 结束识别
/// await AsrSdk.stopRecognition();
///
/// // 5. 离开页面
/// await AsrSdk.stop();
///
/// // 6. 释放资源
/// await AsrSdk.dispose();
/// ```
class AsrSdk {
  AsrSdk._();

  static AsrService get _asrService => AsrService.instance;

  static AsrSdkState _state = AsrSdkState.notInitialized;
  static AsrRecorder? _recorder;
  static StreamController<String>? _streamController;
  static bool _isListening = false;
  static AsrLogger? _logger;

  /// 状态变化流
  static final StreamController<AsrSdkState> _stateController =
      StreamController<AsrSdkState>.broadcast();

  /// 获取状态流
  static Stream<AsrSdkState> get stateStream => _stateController.stream;

  // ==================== VAD 相关 ====================

  /// VAD 状态流
  static Stream<VadState> get vadStateStream => _asrService.vadStateStream;

  /// 是否启用 VAD
  static bool get isVadEnabled => _asrService.isVadEnabled;

  /// VAD 配置
  static AsrVadConfig get vadConfig => _asrService.vadConfig;

  // ==================== Speaker ID 相关 ====================

  /// Speaker ID 状态流
  static Stream<String> get speakerStateStream => _asrService.speakerStateStream;

  /// 是否启用 Speaker ID
  static bool get isSpeakerIdEnabled => _asrService.isSpeakerIdEnabled;

  /// Speaker ID 配置
  static AsrSpeakerConfig get speakerConfig => _asrService.speakerConfig;

  // ==================== 日志配置 ====================

  /// 设置日志记录器
  static void setLogger(AsrLogger logger) {
    _logger = logger;
    _asrService.setLogger(logger);
  }

  static void _log(String message) {
    _logger?.info(message);
  }

  static void _logError(String message) {
    _logger?.error(message);
  }

  // ==================== 生命周期管理 ====================

  /// 初始化服务（APP 启动时调用，只调用一次）
  static Future<bool> initialize({
    Function(double progress)? onProgress,
    Function(String status)? onStatus,
  }) async {
    if (_state == AsrSdkState.ready || _state == AsrSdkState.started) {
      _log('ASR SDK: 已注册');
      return true;
    }

    if (_state == AsrSdkState.initializing) {
      _log('ASR SDK: 正在注册中');
      return false;
    }

    try {
      _state = AsrSdkState.initializing;
      _stateController.add(_state);
      _log('ASR SDK: 开始注册...');

      final success = await _asrService.initialize(
        onProgress: onProgress,
        onStatus: onStatus,
      );

      if (success) {
        _state = AsrSdkState.ready;
        _stateController.add(_state);
        _log('ASR SDK: 注册成功');
        return true;
      } else {
        _state = AsrSdkState.error;
        _stateController.add(_state);
        _logError('ASR SDK: 注册失败');
        return false;
      }
    } catch (e) {
      _state = AsrSdkState.error;
      _stateController.add(_state);
      _logError('ASR SDK: 注册异常 - $e');
      return false;
    }
  }

  /// 启动服务（进入页面时调用，创建录音器）
  static Future<bool> start() async {
    if (_state == AsrSdkState.started) {
      _log('ASR SDK: 已启动');
      return true;
    }

    if (_state != AsrSdkState.ready) {
      _logError('ASR SDK: 请先调用 initialize()');
      return false;
    }

    try {
      _recorder = AsrRecorder(
        onPartialResult: (text) {
          _streamController?.add(text);
        },
        onFinalResult: (text) {
          _streamController?.add(text);
          _streamController?.close();
          _isListening = false;
        },
        onError: (error) {
          _logError('ASR SDK: 识别错误 - $error');
          _streamController?.addError(error);
          _streamController?.close();
          _isListening = false;
        },
        onStateChanged: (state) {
          _log('ASR SDK: 录音器状态 - $state');
        },
      );

      if (_logger != null) {
        _recorder!.setLogger(_logger!);
      }

      final success = await _recorder!.initialize();
      if (!success) {
        throw Exception('录音器初始化失败');
      }

      _state = AsrSdkState.started;
      _stateController.add(_state);
      _isListening = false;
      _log('ASR SDK: 服务已启动');
      return true;
    } catch (e) {
      _logError('ASR SDK: 启动失败 - $e');
      _recorder?.dispose();
      _recorder = null;
      return false;
    }
  }

  /// 停止服务（离开页面时调用，销毁录音器）
  static Future<void> stop() async {
    _isListening = false;
    _streamController?.close();
    _streamController = null;

    if (_recorder != null) {
      await _recorder!.dispose();
      _recorder = null;
    }

    if (_state == AsrSdkState.started) {
      _state = AsrSdkState.ready;
      _stateController.add(_state);
    }
    _log('ASR SDK: 服务已停止');
  }

  /// 释放所有资源
  static Future<void> dispose() async {
    await stop();
    await _asrService.dispose();
    _state = AsrSdkState.notInitialized;
    _stateController.add(_state);
    await _stateController.close();
    _log('ASR SDK: 资源已释放');
  }

  // ==================== 识别控制（可反复调用） ====================

  /// 开始语音识别
  ///
  /// 每次调用返回当前次识别结果的 Stream。
  /// 如果之前有识别在进行，会先停止再开始新的。
  static Stream<String> recognize() {
    _streamController?.close();
    _streamController = StreamController<String>();
    _isListening = true;

    _beginRecognition();

    return _streamController!.stream;
  }

  /// 内部开始识别
  static void _beginRecognition() {
    if (_recorder == null) {
      _streamController?.addError('服务未启动');
      _streamController?.close();
      _isListening = false;
      return;
    }

    _asrService.reset();
    _recorder!
        .startRecording()
        .then((_) {
          _log('ASR SDK: 开始识别');
        })
        .catchError((e) {
          _logError('ASR SDK: 启动识别失败 - $e');
          _streamController?.addError('启动识别失败: $e');
          _streamController?.close();
          _isListening = false;
        });
  }

  /// 结束语音识别（不销毁录音器，可再次 recognize）
  ///
  /// 调用后会等待识别完成，结果通过 Stream 推送。
  static Future<void> stopRecognition() async {
    if (!_isListening || _recorder == null) return;

    try {
      await _recorder!.stopRecording();
      _isListening = false;
      _log('ASR SDK: 识别已结束');
    } catch (e) {
      _logError('ASR SDK: 结束识别失败 - $e');
      _isListening = false;
    }
  }

  /// 取消语音识别
  static Future<void> cancelRecognition() async {
    if (!_isListening || _recorder == null) return;

    try {
      await _recorder!.cancelRecording();
      _isListening = false;
      _log('ASR SDK: 识别已取消');
    } catch (e) {
      _logError('ASR SDK: 取消识别失败 - $e');
      _isListening = false;
    }
  }

  /// 暂停识别（等同于 stopRecognition）
  static Future<void> pause() async {
    await stopRecognition();
  }

  /// 恢复识别（等同于重新开始 recognize）
  static Stream<String> resume() {
    return recognize();
  }

  // ==================== VAD 控制 ====================

  /// 启用/禁用 VAD (Voice Activity Detection)
  ///
  /// VAD 可以自动检测语音活动，实现：
  /// - 自动开始识别（检测到语音时）
  /// - 自动结束识别（检测到静音时）
  /// - 语音事件回调
  static Future<void> enableVAD(bool enabled) async {
    await _asrService.enableVAD(enabled);
  }

  /// 设置 VAD 配置
  static Future<void> setVadConfig(AsrVadConfig config) async {
    await _asrService.setVadConfig(config);
  }

  // ==================== Speaker ID 控制 ====================

  /// 启用/禁用说话人识别
  static Future<void> enableSpeakerId(bool enabled) async {
    await _asrService.enableSpeakerId(enabled);
  }

  /// 设置说话人识别配置
  static Future<void> setSpeakerIdConfig(AsrSpeakerConfig config) async {
    await _asrService.setSpeakerIdConfig(config);
  }

  /// 注册说话人
  ///
  /// [name] 说话人姓名
  /// [duration] 注册时长（建议 3-5 秒）
  static Future<bool> registerSpeaker({
    required String name,
    required Duration duration,
  }) async {
    return await _asrService.registerSpeaker(name, duration);
  }

  /// 识别当前说话人
  static Future<String> identifySpeaker() async {
    return await _asrService.identifySpeaker();
  }

  /// 验证说话人身份
  static Future<bool> verifySpeaker({
    required String name,
    required Float32List embedding,
  }) async {
    return await _asrService.verifySpeaker(name, embedding);
  }

  /// 移除说话人
  static Future<void> removeSpeaker(String name) async {
    await _asrService.removeSpeaker(name);
  }

  /// 列出所有已注册的说话人
  static Future<List<String>> listSpeakers() async {
    return await _asrService.listSpeakers();
  }

  /// 清除所有说话人数据
  static Future<void> clearAllSpeakers() async {
    await _asrService.clearAllSpeakers();
  }

  /// 获取已注册说话人数量
  static Future<int> getSpeakerCount() async {
    return await _asrService.getSpeakerCount();
  }

  // ==================== 状态查询 ====================

  /// 是否已初始化
  static bool get isInitialized =>
      _state == AsrSdkState.ready || _state == AsrSdkState.started;

  /// 是否已启动
  static bool get isStarted => _state == AsrSdkState.started;

  /// 是否正在识别
  static bool get isListening => _isListening;

  /// 当前状态
  static AsrSdkState get state => _state;

  /// 录音时长（秒）
  static int get duration => _recorder?.duration ?? 0;
}
