/// 说话人自动聚类器
///
/// 负责在多人会议场景中自动识别并标记不同说话人。
/// 无需提前注册，通过 Embedding 余弦相似度自动聚类。
library;

import 'dart:math';
import 'dart:typed_data';

/// Embedding 相似度计算工具
///
/// 提供向量相似度计算的通用方法，高内聚低耦合。
class EmbeddingSimilarity {
  /// 计算余弦相似度
  ///
  /// 返回值范围 [0.0, 1.0]，1.0 表示完全相同
  static double cosine(Float32List a, Float32List b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// 计算与多个 embedding 的最佳匹配分数
  ///
  /// 返回与 embeddings 集合中最相似的一个的分数
  static double bestMatch(Float32List incoming, List<Float32List> embeddings) {
    if (embeddings.isEmpty) return 0.0;
    return embeddings
        .map((e) => cosine(incoming, e))
        .reduce((a, b) => a > b ? a : b);
  }
}

/// 说话人自动聚类配置
class AsrDiarizationConfig {
  /// 会话内匹配的余弦相似度阈值 (0.0-1.0)
  /// 高于此值判定为同一说话人
  final double similarityThreshold;

  /// 最大聚类说话人数
  final int maxSpeakers;

  /// 注册所需的最少音频时长（秒）
  /// 低于此时长不提取说话人特征
  final double minSpeechDuration;

  /// 是否启用已注册说话人匹配
  final bool enableRegisteredMatching;

  /// 已注册说话人匹配阈值 (0.0-1.0)
  /// 用于匹配已注册用户（如"张三"），更严格
  final double registeredMatchThreshold;

  /// 每个说话人最多存储的 embedding 数量
  final int maxEmbeddingsPerSpeaker;

  const AsrDiarizationConfig({
    this.similarityThreshold = 0.5,
    this.maxSpeakers = 20,
    this.minSpeechDuration = 1.0,
    this.enableRegisteredMatching = true,
    this.registeredMatchThreshold = 0.7,
    this.maxEmbeddingsPerSpeaker = 5,
  });

  AsrDiarizationConfig copyWith({
    double? similarityThreshold,
    int? maxSpeakers,
    double? minSpeechDuration,
    bool? enableRegisteredMatching,
    double? registeredMatchThreshold,
    int? maxEmbeddingsPerSpeaker,
  }) {
    return AsrDiarizationConfig(
      similarityThreshold: similarityThreshold ?? this.similarityThreshold,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      minSpeechDuration: minSpeechDuration ?? this.minSpeechDuration,
      enableRegisteredMatching:
          enableRegisteredMatching ?? this.enableRegisteredMatching,
      registeredMatchThreshold:
          registeredMatchThreshold ?? this.registeredMatchThreshold,
      maxEmbeddingsPerSpeaker:
          maxEmbeddingsPerSpeaker ?? this.maxEmbeddingsPerSpeaker,
    );
  }
}

/// 已识别的说话人信息
///
/// 高内聚：所有说话人状态和行为封装在此类
class IdentifiedSpeaker {
  /// 说话人标签 (如 "Speaker 1")
  final String label;

  /// 关联的已注册说话人名称 (如 "张三")
  final String? registeredName;

  /// 说话人 Embedding 向量列表
  final List<Float32List> _embeddings;

  /// 首次出现时间戳（秒）
  final double firstSeenAt;

  /// 说话次数
  int utteranceCount;

  /// 最大 embedding 数量（从配置传入）
  final int maxEmbeddings;

  IdentifiedSpeaker({
    required this.label,
    this.registeredName,
    required Float32List initialEmbedding,
    required this.firstSeenAt,
    this.maxEmbeddings = 5,
    this.utteranceCount = 1,
  }) : _embeddings = [Float32List.fromList(initialEmbedding)];

  /// 所有 embedding（只读）
  List<Float32List> get embeddings => List.unmodifiable(_embeddings);

  /// 显示标签（优先使用已注册名称）
  String get displayLabel => registeredName ?? label;

  /// 计算最佳匹配分数（委托给 EmbeddingSimilarity）
  double bestMatchScore(Float32List incoming) =>
      EmbeddingSimilarity.bestMatch(incoming, _embeddings);

  /// 添加新 embedding（保持上限）
  void addEmbedding(Float32List newEmbedding) {
    if (_embeddings.length >= maxEmbeddings) {
      _embeddings.removeAt(0);
    }
    _embeddings.add(Float32List.fromList(newEmbedding));
    utteranceCount++;
  }
}

/// 说话人自动聚类器
///
/// 高内聚：聚类逻辑封装在此类
/// 低耦合：依赖 EmbeddingSimilarity 工具类，不直接实现相似度计算
///
/// 工作流程：
/// 1. Layer 1: 匹配已注册说话人（如"张三"）
/// 2. Layer 2: 匹配会话内已出现说话人（支持重识别）
/// 3. Layer 3: 创建新说话人标签
class AsrDiarizer {
  AsrDiarizationConfig _config;
  final List<IdentifiedSpeaker> _speakers = [];
  final Map<String, Float32List> _registeredSpeakers;
  int _nextSpeakerIndex = 1;
  String? _currentSpeakerLabel;

  AsrDiarizer(this._config, {Map<String, Float32List>? registeredSpeakers})
    : _registeredSpeakers = registeredSpeakers ?? {};

  AsrDiarizationConfig get config => _config;
  int get speakerCount => _speakers.length;
  List<IdentifiedSpeaker> get speakers => List.unmodifiable(_speakers);
  String? get currentSpeakerLabel => _currentSpeakerLabel;

  void updateConfig(AsrDiarizationConfig config) {
    _config = config;
  }

  void updateRegisteredSpeakers(Map<String, Float32List> registeredSpeakers) {
    _registeredSpeakers.clear();
    _registeredSpeakers.addAll(registeredSpeakers);
  }

  /// 识别说话人（分层匹配）
  String identifySpeaker(
    Float32List embedding,
    double duration,
    double timestamp,
  ) {
    if (duration < _config.minSpeechDuration) {
      return _currentSpeakerLabel ?? 'Speaker 1';
    }

    // Layer 1: 已注册说话人匹配
    final registeredResult = _tryMatchRegistered(embedding, timestamp);
    if (registeredResult != null) return registeredResult;

    // Layer 2: 会话内匹配（重识别）
    final sessionResult = _tryMatchSession(embedding);
    if (sessionResult != null) return sessionResult;

    // 达到上限时使用最相似的
    if (_speakers.length >= _config.maxSpeakers) {
      return _findMostSimilar(embedding);
    }

    // Layer 3: 创建新说话人
    return _createSpeaker(embedding, timestamp);
  }

  /// Layer 1: 尝试匹配已注册说话人
  String? _tryMatchRegistered(Float32List embedding, double timestamp) {
    if (!_config.enableRegisteredMatching || _registeredSpeakers.isEmpty) {
      return null;
    }

    final match = _findBestRegisteredMatch(embedding);
    if (match == null) return null;

    final existingSpeaker = _findSpeakerByRegisteredName(match);
    if (existingSpeaker != null) {
      existingSpeaker.addEmbedding(embedding);
      _currentSpeakerLabel = existingSpeaker.displayLabel;
      return existingSpeaker.displayLabel;
    }

    return _createSpeaker(embedding, timestamp, registeredName: match);
  }

  /// Layer 2: 尝试匹配会话内说话人
  String? _tryMatchSession(Float32List embedding) {
    if (_speakers.isEmpty) return null;

    final match = _findBestSessionMatch(embedding);
    if (match == null) return null;

    match.addEmbedding(embedding);
    _currentSpeakerLabel = match.displayLabel;
    return match.displayLabel;
  }

  /// 查找最佳已注册匹配
  String? _findBestRegisteredMatch(Float32List incoming) {
    String? bestMatch;
    double bestScore = 0.0;

    for (final entry in _registeredSpeakers.entries) {
      final score = EmbeddingSimilarity.cosine(incoming, entry.value);
      if (score > bestScore && score >= _config.registeredMatchThreshold) {
        bestScore = score;
        bestMatch = entry.key;
      }
    }
    return bestMatch;
  }

  /// 查找最佳会话匹配
  IdentifiedSpeaker? _findBestSessionMatch(Float32List incoming) {
    IdentifiedSpeaker? bestMatch;
    double bestScore = 0.0;

    for (final speaker in _speakers) {
      final score = speaker.bestMatchScore(incoming);
      if (score > bestScore && score >= _config.similarityThreshold) {
        bestScore = score;
        bestMatch = speaker;
      }
    }
    return bestMatch;
  }

  /// 查找已关联指定已注册名称的说话人
  IdentifiedSpeaker? _findSpeakerByRegisteredName(String registeredName) {
    for (final speaker in _speakers) {
      if (speaker.registeredName == registeredName) return speaker;
    }
    return null;
  }

  /// 创建新说话人（可选关联已注册用户）
  String _createSpeaker(
    Float32List embedding,
    double timestamp, {
    String? registeredName,
  }) {
    final speaker = IdentifiedSpeaker(
      label: 'Speaker $_nextSpeakerIndex',
      registeredName: registeredName,
      initialEmbedding: embedding,
      firstSeenAt: timestamp,
      maxEmbeddings: _config.maxEmbeddingsPerSpeaker,
    );
    _speakers.add(speaker);
    _nextSpeakerIndex++;
    _currentSpeakerLabel = speaker.displayLabel;
    return speaker.displayLabel;
  }

  /// 查找最相似的说话人（达到上限时）
  String _findMostSimilar(Float32List embedding) {
    IdentifiedSpeaker? bestMatch;
    double bestScore = -1.0;

    for (final speaker in _speakers) {
      final score = speaker.bestMatchScore(embedding);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = speaker;
      }
    }

    final label = bestMatch?.displayLabel ?? 'Speaker 1';
    _currentSpeakerLabel = label;
    return label;
  }

  void reset() {
    _speakers.clear();
    _nextSpeakerIndex = 1;
    _currentSpeakerLabel = null;
  }
}
