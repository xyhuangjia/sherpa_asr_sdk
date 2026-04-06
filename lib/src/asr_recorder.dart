import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'asr_config.dart';
import 'asr_result.dart';
import 'asr_service.dart';
import 'asr_state.dart';
import 'utils/asr_logger.dart';
import 'utils/audio_converter.dart';

/// ASR 录音识别器
/// 使用 record 包获取 16kHz PCM 流，送入 Sherpa-onnx 流式识别
class AsrRecorder {
  final Function(String) onPartialResult;
  final Function(String) onFinalResult;
  final Function(String)? onError;
  final Function(AsrRecorderState)? onStateChanged;
  final Function(AsrResult)? onPartialResultWithTimestamps;
  final Function(AsrResult)? onFinalResultWithTimestamps;

  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<List<int>>? _streamSubscription;
  StreamSubscription<String>? _resultSubscription;
  StreamSubscription<AsrResult>? _resultWithTimestampsSubscription;
  bool _isRecording = false;
  DateTime? _startTime;
  AsrRecorderState _state = AsrRecorderState.idle;
  AsrService? _asrService;

  AsrLogger? _logger;

  AsrRecorder({
    required this.onPartialResult,
    required this.onFinalResult,
    this.onError,
    this.onStateChanged,
    this.onPartialResultWithTimestamps,
    this.onFinalResultWithTimestamps,
  });

  void setLogger(AsrLogger logger) {
    _logger = logger;
  }

  void _log(String message) {
    _logger?.debug(message);
  }

  AsrRecorderState get state => _state;
  bool get isRecording => _isRecording;
  int get duration {
    if (_startTime == null) return 0;
    return DateTime.now().difference(_startTime!).inSeconds;
  }

  void _updateState(AsrRecorderState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call(newState);
    }
  }

  Future<bool> initialize({AsrService? asrService}) async {
    try {
      _asrService = asrService ?? AsrService.instance;
      _log('ASR: 录音器初始化成功');
      return true;
    } catch (e) {
      _log('ASR: 录音器初始化失败 - $e');
      onError?.call('录音器初始化失败: $e');
      return false;
    }
  }

  Future<void> startRecording() async {
    if (_isRecording) {
      _log('ASR: 录音已在进行中');
      return;
    }
    try {
      _updateState(AsrRecorderState.initializing);
      if (!_asrService!.isReady) {
        _log('ASR: 服务未就绪，正在初始化...');
        final success = await _asrService!.initialize();
        if (!success) {
          throw Exception('ASR 服务初始化失败');
        }
      }
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        throw Exception('需要麦克风权限');
      }
      await _asrService!.startRecognition();

      _resultSubscription = _asrService!.resultStream.listen(
        (text) {
          _log('ASR: 识别结果 - $text');
          onPartialResult(text);
        },
        onError: (e) {
          _log('ASR: 识别错误 - $e');
          onError?.call('识别错误: $e');
        },
      );

      if (onPartialResultWithTimestamps != null) {
        _resultWithTimestampsSubscription =
            _asrService!.resultWithTimestampsStream.listen(
          (result) {
            _log('ASR: 带时间戳识别结果 - ${result.text}');
            onPartialResultWithTimestamps!(result);
          },
          onError: (e) {
            _log('ASR: 时间戳识别错误 - $e');
            onError?.call('时间戳识别错误: $e');
          },
        );
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: AsrConfig.targetSampleRate,
        numChannels: AsrConfig.numChannels,
      );
      final stream = await _audioRecorder.startStream(config);
      _streamSubscription = stream.listen(
        (List<int> data) {
          final float32 = AudioConverter.convertBytesToFloat32(
            Uint8List.fromList(data),
          );
          _asrService!.acceptAudio(float32.toList());
        },
        onError: (e) {
          _log('ASR: 录音流错误 - $e');
          onError?.call('录音异常: $e');
        },
      );
      _isRecording = true;
      _startTime = DateTime.now();
      _updateState(AsrRecorderState.recording);
      _log('ASR: 开始录音识别');
    } catch (e) {
      _log('ASR: 开始录音失败 - $e');
      onError?.call('开始录音失败: $e');
      _updateState(AsrRecorderState.error);
      await _cleanup();
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) {
      _log('ASR: 没有正在进行的录音');
      return;
    }
    try {
      _updateState(AsrRecorderState.stopping);
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _audioRecorder.stop();
      final result = await _asrService!.stopRecognition();
      await _resultSubscription?.cancel();
      _resultSubscription = null;
      await _resultWithTimestampsSubscription?.cancel();
      _resultWithTimestampsSubscription = null;
      if (result != null && result.isNotEmpty) {
        _log('ASR: 最终结果 - $result');
        onFinalResult(result);
      }
      _isRecording = false;
      _startTime = null;
      _updateState(AsrRecorderState.completed);
      _log('ASR: 停止录音识别');
    } catch (e) {
      _log('ASR: 停止录音失败 - $e');
      onError?.call('停止录音失败: $e');
      _updateState(AsrRecorderState.error);
      await _cleanup();
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      _updateState(AsrRecorderState.canceling);
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _resultSubscription?.cancel();
      _resultSubscription = null;
      await _resultWithTimestampsSubscription?.cancel();
      _resultWithTimestampsSubscription = null;
      await _audioRecorder.stop();
      await _asrService!.cancelRecognition();
      _isRecording = false;
      _startTime = null;
      _updateState(AsrRecorderState.canceled);
      _log('ASR: 取消录音识别');
    } catch (e) {
      _log('ASR: 取消录音失败 - $e');
      _updateState(AsrRecorderState.error);
    }
    await _cleanup();
  }

  Future<void> _cleanup() async {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _resultSubscription?.cancel();
    _resultSubscription = null;
    _resultWithTimestampsSubscription?.cancel();
    _resultWithTimestampsSubscription = null;
    if (_isRecording) {
      try {
        await _audioRecorder.stop();
      } catch (e) {
        _log('ASR: 停止录音器失败 - $e');
      }
      _isRecording = false;
    }
    if (_state == AsrRecorderState.error) {
      _updateState(AsrRecorderState.idle);
    }
  }

  Future<void> dispose() async {
    await _cleanup();
    _audioRecorder.dispose();
    _log('ASR: 录音器已释放');
  }
}
