import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../asr_config.dart';
import '../utils/asr_logger.dart';
import '../utils/sherpa_models_manager.dart';
import '../speaker/asr_diarization_manager.dart';
import 'asr_vad_config.dart';
import 'asr_vad_state.dart';

/// VAD 管理器
///
/// 负责语音活动检测，管理 VAD 模型生命周期。
/// 检测到语音段时通过回调通知上层处理。
class AsrVadManager {
  AsrVadManager({
    required this.onProcessSamples,
    required this.onResultWithSpeaker,
    required AsrDiarizationManager diarizationManager,
  }) : _diarizationManager = diarizationManager;

  /// 处理识别音频的回调（由 AsrService 提供）
  final void Function(Float32List samples) onProcessSamples;

  /// 带说话人标签的结果回调
  final void Function(String labeledText) onResultWithSpeaker;

  final AsrDiarizationManager _diarizationManager;

  sherpa_onnx.VoiceActivityDetector? _vad;
  AsrVadConfig _config = const AsrVadConfig();
  bool _isEnabled = false;
  bool _isSpeechDetected = false;

  AsrLogger? _logger;

  final StreamController<VadState> _stateController =
      StreamController<VadState>.broadcast();

  Stream<VadState> get stateStream => _stateController.stream;
  AsrVadConfig get config => _config;
  bool get isEnabled => _isEnabled;

  void setLogger(AsrLogger logger) {
    _logger = logger;
  }

  void _log(String message) {
    _logger?.debug(message);
  }

  /// 启用/禁用 VAD
  Future<void> enable(bool enabled) async {
    _isEnabled = enabled;
    if (enabled) {
      await _initialize();
    } else {
      _vad?.free();
      _vad = null;
    }
    _log('ASR VAD: 已${enabled ? "启用" : "禁用"}');
  }

  /// 更新配置
  Future<void> updateConfig(AsrVadConfig config) async {
    _config = config;
    _log('ASR VAD: 配置已更新 - $config');
    if (_isEnabled) {
      await _initialize();
    }
  }

  /// 初始化 VAD 模型
  Future<void> _initialize() async {
    try {
      _vad?.free();

      String? vadModelPath = await SherpaModelsManager.instance
          .getVadModelPath();

      if (vadModelPath == null) {
        final baseVadFile = File(
          '${await SherpaModelsManager.instance.getBaseModelPath()}/silero_vad.onnx',
        );
        if (await baseVadFile.exists()) {
          vadModelPath = await SherpaModelsManager.instance.getBaseModelPath();
        }
      }

      if (vadModelPath == null) {
        _log('ASR VAD: 模型未找到，功能不可用');
        return;
      }

      final config = sherpa_onnx.VadModelConfig(
        sileroVad: sherpa_onnx.SileroVadModelConfig(
          model: '$vadModelPath/silero_vad.onnx',
          threshold: _config.threshold,
          minSilenceDuration: _config.minSilenceDuration,
          minSpeechDuration: _config.minSpeechDuration,
          maxSpeechDuration: _config.maxSpeechDuration,
          windowSize: _config.windowSize,
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

      _log('ASR VAD: 初始化成功');
    } catch (e) {
      _log('ASR VAD: 初始化失败 - $e');
      _isEnabled = false;
    }
  }

  /// 处理音频（VAD 模式）
  void processAudio(Float32List samples, String? Function() getSpeakerLabel) {
    if (!_isEnabled || _vad == null) {
      onProcessSamples(samples);
      return;
    }

    try {
      _vad!.acceptWaveform(samples);

      if (_vad!.isDetected()) {
        if (!_isSpeechDetected) {
          _isSpeechDetected = true;
          _stateController.add(VadState.speechStarted);
          _log('ASR VAD: 检测到语音开始');
          _diarizationManager.startSegment();
        } else {
          _stateController.add(VadState.speechInProgress);
        }

        _diarizationManager.feedAudio(samples);
        onProcessSamples(samples);
      } else {
        if (_isSpeechDetected) {
          _stateController.add(VadState.silence);
        }
      }

      if (!_vad!.isEmpty()) {
        final segment = _vad!.front();
        if (segment.samples.isNotEmpty) {
          _isSpeechDetected = false;
          _stateController.add(VadState.speechEnded);
          _log('ASR VAD: 检测到语音结束');

          _diarizationManager.identifySpeakerAtSegmentEnd();

          final speakerLabel = getSpeakerLabel();
          if (speakerLabel != null) {
            onResultWithSpeaker(speakerLabel);
          }

          _vad!.pop();
        }
      }
    } catch (e) {
      _log('ASR VAD: 处理音频失败 - $e');
    }
  }

  /// 释放资源
  void dispose() {
    _vad?.free();
    _vad = null;
    _stateController.close();
  }
}
