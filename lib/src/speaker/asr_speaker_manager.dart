import 'dart:async';
import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../asr_config.dart';
import '../utils/asr_logger.dart';
import '../utils/sherpa_models_manager.dart';
import 'asr_speaker_config.dart';
import 'speaker_data_storage.dart';

/// Speaker ID 管理器
///
/// 负责说话人识别：注册、验证、Embedding 提取。
class AsrSpeakerManager {
  AsrSpeakerManager();

  sherpa_onnx.SpeakerEmbeddingExtractor? _extractor;
  sherpa_onnx.SpeakerEmbeddingManager? _manager;
  AsrSpeakerConfig _config = const AsrSpeakerConfig();
  bool _isEnabled = false;
  bool _isRegistering = false;
  final SpeakerDataStorage _storage = SpeakerDataStorage();

  sherpa_onnx.OnlineStream? _stream;

  AsrLogger? _logger;

  final StreamController<String> _stateController =
      StreamController<String>.broadcast();

  Stream<String> get stateStream => _stateController.stream;
  AsrSpeakerConfig get config => _config;
  bool get isEnabled => _isEnabled;
  bool get isRegistering => _isRegistering;

  /// 获取 extractor（供 DiarizationManager 共享）
  sherpa_onnx.SpeakerEmbeddingExtractor? get extractor => _extractor;

  /// 获取所有已注册说话人的 Embedding
  ///
  /// 返回 Map<说话人名称, Embedding向量>
  /// 用于 Diarization 的分层匹配
  Future<Map<String, Float32List>> getRegisteredEmbeddings() async {
    final result = <String, Float32List>{};
    try {
      final speakers = await _storage.getAllSpeakers();
      for (final name in speakers) {
        final embedding = await _storage.loadSpeaker(name);
        if (embedding != null) {
          result[name] = embedding;
        }
      }
      _log('ASR Speaker: 已获取 ${result.length} 个已注册说话人的 embedding');
    } catch (e) {
      _log('ASR Speaker: 获取已注册 embedding 失败 - $e');
    }
    return result;
  }

  void setLogger(AsrLogger logger) {
    _logger = logger;
    _storage.setLogger(logger);
  }

  void _log(String message) {
    _logger?.debug(message);
  }

  /// 创建 Speaker Embedding Extractor
  Future<bool> _createExtractor() async {
    try {
      String? reidModelPath = await SherpaModelsManager.instance
          .getSpeakerReidModelPath();

      if (reidModelPath == null) {
        _log('ASR Speaker: 说话人识别模型未找到');
        return false;
      }

      _extractor?.free();
      final extractorConfig = sherpa_onnx.SpeakerEmbeddingExtractorConfig(
        model: '$reidModelPath/model.onnx',
        numThreads: 1,
        debug: true,
        provider: 'cpu',
      );

      _extractor = sherpa_onnx.SpeakerEmbeddingExtractor(
        config: extractorConfig,
      );

      _log('ASR Speaker: Extractor 初始化成功，维度：${_extractor!.dim}');
      return true;
    } catch (e) {
      _log('ASR Speaker: Extractor 初始化失败 - $e');
      return false;
    }
  }

  /// 初始化 Speaker ID
  Future<void> initialize() async {
    try {
      _manager?.free();

      await _storage.initialize();

      if (!await _createExtractor()) {
        _isEnabled = false;
        return;
      }

      final dim = _extractor!.dim;
      _manager = sherpa_onnx.SpeakerEmbeddingManager(dim);

      await _loadSavedSpeakers();

      _log('ASR Speaker: 初始化成功，维度：$dim');
    } catch (e) {
      _log('ASR Speaker: 初始化失败 - $e');
      _isEnabled = false;
    }
  }

  /// 加载已保存的说话人数据
  Future<void> _loadSavedSpeakers() async {
    try {
      final speakers = await _storage.getAllSpeakers();
      for (final name in speakers) {
        final embedding = await _storage.loadSpeaker(name);
        if (embedding != null) {
          _manager?.add(name: name, embedding: embedding);
        }
      }
      _log('ASR Speaker: 已加载 ${speakers.length} 个说话人');
    } catch (e) {
      _log('ASR Speaker: 加载说话人数据失败 - $e');
    }
  }

  /// 启用/禁用说话人识别
  Future<void> enable(bool enabled) async {
    _isEnabled = enabled;
    if (enabled) {
      await initialize();
    }
    _log('ASR Speaker: 已${enabled ? "启用" : "禁用"}');
  }

  /// 更新配置
  Future<void> updateConfig(AsrSpeakerConfig config) async {
    _config = config;
    _log('ASR Speaker: 配置已更新 - $config');
    if (_isEnabled) {
      await initialize();
    }
  }

  /// 注册说话人
  ///
  /// 调用后等待 [duration]，期间通过 [acceptAudio] 喂入音频。
  /// 时间到后提取 embedding 并保存。
  Future<bool> registerSpeaker(String name, Duration duration) async {
    if (!_isEnabled || _extractor == null) {
      _log('ASR Speaker: 说话人识别未启用');
      return false;
    }

    try {
      _log('ASR Speaker: 开始注册 - $name');
      _isRegistering = true;
      resetStream();

      await Future.delayed(duration);

      final embedding = computeEmbedding();
      _isRegistering = false;

      if (embedding == null || embedding.isEmpty) {
        _log('ASR Speaker: 注册失败 - 特征提取失败');
        return false;
      }

      final added = _manager?.add(name: name, embedding: embedding);
      if (added != true) {
        _log('ASR Speaker: 注册失败 - 添加到管理器失败');
        return false;
      }

      final saved = await _storage.saveSpeaker(name, embedding);
      if (!saved) {
        _log('ASR Speaker: 注册失败 - 持久化失败');
        _manager?.remove(name);
        return false;
      }

      _log('ASR Speaker: 注册成功 - $name');
      return true;
    } catch (e) {
      _isRegistering = false;
      _log('ASR Speaker: 注册失败 - $e');
      return false;
    }
  }

  /// 开始说话人注册流程
  void startRegistration() {
    if (!_isEnabled || _extractor == null) return;
    _isRegistering = true;
    resetStream();
    _log('ASR Speaker: 开始注册流程');
  }

  /// 完成说话人注册并获取特征
  Float32List? finishRegistration() {
    _isRegistering = false;
    if (_stream == null || _extractor == null) return null;

    try {
      if (!_extractor!.isReady(_stream!)) return null;

      final embedding = _extractor!.compute(_stream!);
      resetStream();

      return embedding.isEmpty ? null : embedding;
    } catch (e) {
      _log('ASR Speaker: 完成注册失败 - $e');
      return null;
    }
  }

  /// 验证说话人身份
  Future<bool> verifySpeaker(String name, Float32List embedding) async {
    if (!_isEnabled || _manager == null) return false;

    try {
      return _manager!.verify(
        name: name,
        embedding: embedding,
        threshold: _config.verificationThreshold,
      );
    } catch (e) {
      _log('ASR Speaker: 验证失败 - $e');
      return false;
    }
  }

  /// 移除说话人
  Future<void> removeSpeaker(String name) async {
    _manager?.remove(name);
    await _storage.deleteSpeaker(name);
    _log('ASR Speaker: 已移除 - $name');
  }

  /// 列出所有已注册的说话人
  Future<List<String>> listSpeakers() async {
    return await _storage.getAllSpeakers();
  }

  /// 清除所有说话人数据
  Future<void> clearAll() async {
    _manager?.free();
    _manager = null;
    await _storage.clearAllSpeakers();

    if (_isEnabled) {
      await initialize();
    }
    _log('ASR Speaker: 所有说话人已清除');
  }

  /// 获取已注册说话人数量
  Future<int> getCount() async {
    return await _storage.getSpeakerCount();
  }

  /// 喂入音频数据
  void acceptAudio(Float32List samples) {
    if (!_isEnabled || _extractor == null) return;

    try {
      _stream ??= _extractor!.createStream();

      _stream!.acceptWaveform(
        samples: samples,
        sampleRate: AsrConfig.targetSampleRate,
      );
    } catch (e) {
      _log('ASR Speaker: 喂入音频失败 - $e');
    }
  }

  /// 计算当前说话人 Embedding
  Float32List? computeEmbedding() {
    if (_stream == null || _extractor == null) return null;

    try {
      if (!_extractor!.isReady(_stream!)) return null;

      final embedding = _extractor!.compute(_stream!);

      _stream?.free();
      _stream = _extractor!.createStream();

      return embedding.isEmpty ? null : embedding;
    } catch (e) {
      _log('ASR Speaker: 计算特征失败 - $e');
      return null;
    }
  }

  /// 重置音频流
  void resetStream() {
    _stream?.free();
    _stream = null;
  }

  /// 释放资源
  void dispose() {
    _stream?.free();
    _stream = null;
    _extractor?.free();
    _extractor = null;
    _manager?.free();
    _manager = null;
    _stateController.close();
  }
}
