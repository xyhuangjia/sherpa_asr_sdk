/// 说话人自动聚类器
///
/// 负责在多人会议场景中自动识别并标记不同说话人。
/// 无需提前注册，通过 Embedding 余弦相似度自动聚类。
library;

import 'dart:math';
import 'dart:typed_data';

/// 说话人自动聚类配置
class AsrDiarizationConfig {
  /// 余弦相似度阈值 (0.0-1.0)
  /// 高于此值判定为同一说话人
  final double similarityThreshold;

  /// 最大聚类说话人数
  final int maxSpeakers;

  /// 注册所需的最少音频时长（秒）
  /// 低于此时长不提取说话人特征
  final double minSpeechDuration;

  const AsrDiarizationConfig({
    this.similarityThreshold = 0.5,
    this.maxSpeakers = 20,
    this.minSpeechDuration = 1.0,
  });

  AsrDiarizationConfig copyWith({
    double? similarityThreshold,
    int? maxSpeakers,
    double? minSpeechDuration,
  }) {
    return AsrDiarizationConfig(
      similarityThreshold: similarityThreshold ?? this.similarityThreshold,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      minSpeechDuration: minSpeechDuration ?? this.minSpeechDuration,
    );
  }
}

/// 已识别的说话人信息
class IdentifiedSpeaker {
  /// 说话人标签 (如 "Speaker 1")
  final String label;

  /// 说话人 Embedding 向量
  final Float32List embedding;

  /// 首次出现时间戳（秒）
  final double firstSeenAt;

  /// 说话次数
  int utteranceCount;

  IdentifiedSpeaker({
    required this.label,
    required this.embedding,
    required this.firstSeenAt,
    this.utteranceCount = 1,
  });
}

/// 说话人自动聚类器
///
/// 工作流程：
/// 1. 接收新语音段的 Embedding
/// 2. 与已有说话人比较相似度
/// 3. 高于阈值 → 标记为同一说话人
/// 4. 低于阈值 → 创建新说话人标签
class AsrDiarizer {
  AsrDiarizationConfig _config;
  final List<IdentifiedSpeaker> _speakers = [];
  int _nextSpeakerIndex = 1;

  /// 当前说话人标签（最近一次识别的）
  String? _currentSpeakerLabel;

  AsrDiarizer([this._config = const AsrDiarizationConfig()]);

  /// 当前配置
  AsrDiarizationConfig get config => _config;

  /// 已识别的说话人数量
  int get speakerCount => _speakers.length;

  /// 所有已识别说话人
  List<IdentifiedSpeaker> get speakers => List.unmodifiable(_speakers);

  /// 当前说话人标签
  String? get currentSpeakerLabel => _currentSpeakerLabel;

  /// 更新配置
  void updateConfig(AsrDiarizationConfig config) {
    _config = config;
  }

  /// 识别说话人
  ///
  /// [embedding] 语音段的说话人 Embedding
  /// [duration] 语音时长（秒）
  /// [timestamp] 时间戳（秒）
  ///
  /// 返回说话人标签，如 "Speaker 1"
  String identifySpeaker(Float32List embedding, double duration, double timestamp) {
    if (duration < _config.minSpeechDuration) {
      // 语音时长太短，使用上一个说话人标签
      return _currentSpeakerLabel ?? 'Speaker 1';
    }

    if (_speakers.isEmpty) {
      // 第一个说话人
      return _addNewSpeaker(embedding, timestamp);
    }

    if (_speakers.length >= _config.maxSpeakers) {
      // 达到最大说话人数，使用最相似的
      return _findMostSimilarSpeaker(embedding);
    }

    // 查找最相似的已有说话人
    String? bestMatch;
    double bestSimilarity = 0.0;

    for (final speaker in _speakers) {
      final similarity = _cosineSimilarity(embedding, speaker.embedding);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = speaker.label;
      }
    }

    if (bestSimilarity >= _config.similarityThreshold) {
      // 匹配到已有说话人
      final speaker = _speakers.firstWhere((s) => s.label == bestMatch);
      speaker.utteranceCount++;
      _currentSpeakerLabel = speaker.label;
      return speaker.label;
    }

    // 创建新说话人标签
    return _addNewSpeaker(embedding, timestamp);
  }

  /// 添加新说话人
  String _addNewSpeaker(Float32List embedding, double timestamp) {
    final label = 'Speaker $_nextSpeakerIndex';
    _speakers.add(IdentifiedSpeaker(
      label: label,
      embedding: Float32List.fromList(embedding),
      firstSeenAt: timestamp,
      utteranceCount: 1,
    ));
    _nextSpeakerIndex++;
    _currentSpeakerLabel = label;
    return label;
  }

  /// 查找最相似的说话人
  String _findMostSimilarSpeaker(Float32List embedding) {
    String? bestMatch;
    double bestSimilarity = -1.0;

    for (final speaker in _speakers) {
      final similarity = _cosineSimilarity(embedding, speaker.embedding);
      if (similarity > bestSimilarity) {
        bestSimilarity = similarity;
        bestMatch = speaker.label;
      }
    }

    return bestMatch ?? 'Speaker 1';
  }

  /// 计算余弦相似度
  double _cosineSimilarity(Float32List a, Float32List b) {
    if (a.length != b.length) {
      return 0.0;
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) {
      return 0.0;
    }

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// 清空所有说话人数据
  void reset() {
    _speakers.clear();
    _nextSpeakerIndex = 1;
    _currentSpeakerLabel = null;
  }
}
