import 'dart:async';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../asr_config.dart';
import '../utils/asr_logger.dart';
import '../utils/sherpa_models_manager.dart';
import 'asr_diarizer.dart';
import 'asr_speaker_manager.dart';

/// Diarization 管理器
///
/// 负责多人场景下的说话人自动聚类。
/// 共享 AsrSpeakerManager 的 Speaker Embedding Extractor。
class AsrDiarizationManager {
  AsrDiarizationManager(this._speakerManager);

  final AsrSpeakerManager _speakerManager;

  AsrDiarizer? _diarizer;
  AsrDiarizationConfig _config = const AsrDiarizationConfig();
  bool _isEnabled = false;
  String? _currentSpeakerLabel;
  sherpa_onnx.OnlineStream? _diarizationStream;
  DateTime? _recognitionStartTime;

  AsrLogger? _logger;

  final StreamController<String?> _stateController =
      StreamController<String?>.broadcast();

  Stream<String?> get stateStream => _stateController.stream;
  bool get isEnabled => _isEnabled;
  String? get currentSpeakerLabel => _currentSpeakerLabel;
  int get activeSpeakerCount => _diarizer?.speakerCount ?? 0;
  List<IdentifiedSpeaker> get activeSpeakers => _diarizer?.speakers ?? [];

  void setLogger(AsrLogger logger) {
    _logger = logger;
  }

  void _log(String message) {
    _logger?.debug(message);
  }

  /// 设置识别开始时间（用于计算语音段时间戳）
  void setRecognitionStartTime(DateTime? time) {
    _recognitionStartTime = time;
  }

  /// 启用/禁用说话人自动聚类
  Future<void> enable(bool enabled) async {
    _isEnabled = enabled;
    if (enabled) {
      await _initialize();
    } else {
      _diarizer?.reset();
      _diarizer = null;
      _diarizationStream?.free();
      _diarizationStream = null;
    }
    _log('ASR Diarization: 已${enabled ? "启用" : "禁用"}');
  }

  /// 更新配置
  Future<void> updateConfig(AsrDiarizationConfig config) async {
    _config = config;
    _diarizer?.updateConfig(config);
    _log('ASR Diarization: 配置已更新 - $config');
  }

  /// 初始化 Diarization
  Future<void> _initialize() async {
    // 检查模型是否存在，不存在则下载
    if (!await SherpaModelsManager.instance.hasSpeakerReidModel()) {
      _log('ASR Diarization: 模型不存在，开始下载...');
      final downloadOk = await SherpaModelsManager.instance
          .downloadSpeakerReidModel(
            onProgress: (p) {},
            onStatusChange: (s) => _log('ASR Diarization: $s'),
          );
      if (!downloadOk) {
        _log('ASR Diarization: 模型下载失败');
        _isEnabled = false;
        return;
      }
    }

    // 确保 Speaker Extractor 已初始化（共享 SpeakerManager 的）
    if (_speakerManager.extractor == null) {
      await _speakerManager.enable(true);
      if (_speakerManager.extractor == null) {
        _log('ASR Diarization: Speaker Extractor 初始化失败');
        _isEnabled = false;
        return;
      }
    }

    _diarizer = AsrDiarizer(_config);
    _log('ASR Diarization: 聚类器已初始化');
  }

  /// 语音段开始时创建 Speaker Stream
  void startSegment() {
    if (!_isEnabled || _speakerManager.extractor == null) return;

    _diarizationStream?.free();
    _diarizationStream = _speakerManager.extractor!.createStream();
  }

  /// 喂入音频数据
  void feedAudio(Float32List samples) {
    if (!_isEnabled || _diarizationStream == null) return;

    try {
      _diarizationStream!.acceptWaveform(
        samples: samples,
        sampleRate: AsrConfig.targetSampleRate,
      );
    } catch (e) {
      _log('ASR Diarization: 音频喂入失败 - $e');
    }
  }

  /// 语音段结束时提取说话人特征并识别
  void identifySpeakerAtSegmentEnd() {
    if (!_isEnabled ||
        _speakerManager.extractor == null ||
        _diarizationStream == null) {
      return;
    }

    try {
      if (!_speakerManager.extractor!.isReady(_diarizationStream!)) {
        _diarizationStream?.free();
        _diarizationStream = null;
        return;
      }

      final embedding = _speakerManager.extractor!.compute(_diarizationStream!);
      _diarizationStream?.free();
      _diarizationStream = null;

      if (embedding.isEmpty) {
        _log('ASR Diarization: 说话人特征提取失败');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0;
      final duration = _recognitionStartTime != null
          ? DateTime.now()
                .difference(_recognitionStartTime!)
                .inSeconds
                .toDouble()
          : 0.0;

      final label = _diarizer!.identifySpeaker(embedding, duration, timestamp);

      if (_currentSpeakerLabel != label) {
        _currentSpeakerLabel = label;
        _stateController.add(label);
        _log('ASR Diarization: 说话人切换 -> $label');
      }
    } catch (e) {
      _log('ASR Diarization: 说话人识别失败 - $e');
    }
  }

  /// 重置聚类状态
  void reset() {
    _diarizer?.reset();
    _currentSpeakerLabel = null;
    _diarizationStream?.free();
    _diarizationStream = null;
    _stateController.add(null);
    _log('ASR Diarization: 状态已重置');
  }

  /// 释放资源
  void dispose() {
    _diarizer?.reset();
    _diarizer = null;
    _diarizationStream?.free();
    _diarizationStream = null;
    _stateController.close();
  }
}
