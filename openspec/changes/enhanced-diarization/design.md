# 设计文档：增强说话人分离功能

## 核心变更

### 1. IdentifiedSpeaker 增强

当前 `IdentifiedSpeaker` 只存一个 embedding：

```dart
class IdentifiedSpeaker {
  final String label;
  final Float32List embedding;  // 单个 embedding
  ...
}
```

改造为存储多个 embedding：

```dart
class IdentifiedSpeaker {
  final String label;
  final List<Float32List> embeddings;  // 多个 embedding（最多 5 个）
  final double firstSeenAt;
  int utteranceCount;

  // 计算最佳匹配分数
  double bestMatchScore(Float32List incoming) {
    return embeddings.map((e) => cosineSimilarity(incoming, e)).max();
  }

  // 添加新 embedding（保持上限）
  void addEmbedding(Float32List newEmbedding) {
    if (embeddings.length >= maxEmbeddings) {
      embeddings.removeAt(0);  // 移除最旧的
    }
    embeddings.add(newEmbedding);
  }
}
```

### 2. 分层匹配架构

```
┌─────────────────────────────────────────────────────────────┐
│                    AsrDiarizer.matchSpeaker()               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  incomingEmbedding                                          │
│       │                                                     │
│       ▼                                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Layer 1: Registered Speakers (SpeakerManager)       │   │
│  │ threshold: registeredMatchThreshold (default 0.7)   │   │
│  │ 来源: SpeakerDataStorage 持久化数据                  │   │
│  └─────────────────────────────────────────────────────┘   │
│       │                                                     │
│  match ≥ 0.7? → return "张三"                               │
│       │ else                                                │
│       ▼                                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Layer 2: Session Speakers (_speakers)               │   │
│  │ threshold: sessionMatchThreshold (default 0.5)      │   │
│  │ 使用 bestMatchScore() 多 embedding 匹配              │   │
│  └─────────────────────────────────────────────────────┘   │
│       │                                                     │
│  match ≥ 0.5? → return "Speaker 1"                         │
│                → addEmbedding(incoming)                     │
│       │ else                                                │
│       ▼                                                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Layer 3: New Speaker                                │   │
│  │ 创建新的 IdentifiedSpeaker                          │   │
│  │ label: "Speaker $_nextIndex"                        │   │
│  │ embeddings: [incomingEmbedding]                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3. AsrDiarizationConfig 扩展

新增配置项：

```dart
class AsrDiarizationConfig {
  // 原有配置
  final double similarityThreshold;      // 会话内匹配阈值（重命名）
  final int maxSpeakers;
  final double minSpeechDuration;

  // 新增配置
  final bool enableRegisteredMatching;   // 是否启用已注册说话人匹配
  final double registeredMatchThreshold; // 已注册说话人匹配阈值（更严格）
  final int maxEmbeddingsPerSpeaker;     // 每个说话人最多存储的 embedding 数

  const AsrDiarizationConfig({
    this.similarityThreshold = 0.5,       // Layer 2 阈值
    this.maxSpeakers = 20,
    this.minSpeechDuration = 1.0,
    this.enableRegisteredMatching = true,
    this.registeredMatchThreshold = 0.7,  // Layer 1 阈值
    this.maxEmbeddingsPerSpeaker = 5,
  });
}
```

### 4. AsrDiarizationManager 改造

持有 SpeakerManager 引用：

```dart
class AsrDiarizationManager {
  final AsrSpeakerManager _speakerManager;  // 已有
  AsrDiarizer? _diarizer;

  // 新增：获取已注册说话人数据
  Map<String, Float32List> get _registeredSpeakers {
    return _speakerManager.getRegisteredEmbeddings();
  }

  // 初始化时传入已注册数据
  Future<void> _initialize() async {
    _diarizer = AsrDiarizer(
      _config,
      registeredSpeakers: _registeredSpeakers,
    );
  }
}
```

### 5. AsrSpeakerManager 新增方法

提供已注册说话人数据访问：

```dart
class AsrSpeakerManager {
  // 新增：获取所有已注册说话人的 embedding
  Map<String, Float32List> getRegisteredEmbeddings() {
    final result = <String, Float32List>{};
    for (final speaker in _registeredSpeakers) {
      final embedding = _storage.loadSpeaker(speaker);
      if (embedding != null) {
        result[speaker] = embedding;
      }
    }
    return result;
  }
}
```

### 6. AsrDiarizer 核心改造

```dart
class AsrDiarizer {
  AsrDiarizationConfig _config;
  final List<IdentifiedSpeaker> _speakers = [];
  final Map<String, Float32List> _registeredSpeakers;  // 新增
  int _nextSpeakerIndex = 1;

  AsrDiarizer(
    this._config,
    {Map<String, Float32List>? registeredSpeakers}
  ) : _registeredSpeakers = registeredSpeakers ?? {};

  String identifySpeaker(Float32List embedding, double duration, double timestamp) {
    if (duration < _config.minSpeechDuration) {
      return _currentSpeakerLabel ?? 'Speaker 1';
    }

    // Layer 1: 已注册说话人匹配
    if (_config.enableRegisteredMatching && _registeredSpeakers.isNotEmpty) {
      final registeredMatch = _matchRegisteredSpeaker(embedding);
      if (registeredMatch != null) {
        // 检查是否已在会话中关联
        final sessionMatch = _findSessionSpeakerByRegisteredName(registeredMatch);
        if (sessionMatch != null) {
          sessionMatch.addEmbedding(embedding);
          _currentSpeakerLabel = sessionMatch.label;
          return sessionMatch.label;
        }
        // 新关联：创建标记为已注册的会话说话人
        return _addRegisteredSessionSpeaker(registeredMatch, embedding, timestamp);
      }
    }

    // Layer 2: 会话内匹配（支持重识别）
    final sessionMatch = _matchSessionSpeaker(embedding);
    if (sessionMatch != null) {
      sessionMatch.addEmbedding(embedding);
      _currentSpeakerLabel = sessionMatch.label;
      return sessionMatch.label;
    }

    // Layer 3: 新说话人
    return _addNewSpeaker(embedding, timestamp);
  }

  // 已注册说话人匹配
  String? _matchRegisteredSpeaker(Float32List incoming) {
    String? bestMatch;
    double bestScore = 0.0;

    for (final entry in _registeredSpeakers.entries) {
      final score = cosineSimilarity(incoming, entry.value);
      if (score > bestScore && score >= _config.registeredMatchThreshold) {
        bestScore = score;
        bestMatch = entry.key;
      }
    }
    return bestMatch;
  }

  // 会话内匹配（多 embedding）
  IdentifiedSpeaker? _matchSessionSpeaker(Float32List incoming) {
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
}
```

## IdentifiedSpeaker 完整改造

```dart
class IdentifiedSpeaker {
  final String label;
  final String? registeredName;  // 新增：关联的已注册名称
  final List<Float32List> _embeddings;  // 私有，通过方法访问
  final double firstSeenAt;
  int utteranceCount;

  static const int maxEmbeddings = 5;

  IdentifiedSpeaker({
    required this.label,
    this.registeredName,
    required Float32List initialEmbedding,
    required this.firstSeenAt,
    this.utteranceCount = 1,
  }) : _embeddings = [Float32List.fromList(initialEmbedding)];

  List<Float32List> get embeddings => List.unmodifiable(_embeddings);

  // 多 embedding 最佳匹配
  double bestMatchScore(Float32List incoming) {
    if (_embeddings.isEmpty) return 0.0;
    return _embeddings.map((e) => _cosineSimilarity(incoming, e)).reduce(math.max);
  }

  // 添加新 embedding
  void addEmbedding(Float32List newEmbedding) {
    if (_embeddings.length >= maxEmbeddings) {
      _embeddings.removeAt(0);
    }
    _embeddings.add(Float32List.fromList(newEmbedding));
    utteranceCount++;
  }

  // 显示标签（优先使用已注册名称）
  String get displayLabel => registeredName ?? label;

  static double _cosineSimilarity(Float32List a, Float32List b) {
    // ... 计算余弦相似度
  }
}
```

## 数据流图

```
┌─────────────────────────────────────────────────────────────────┐
│                        完整数据流                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  音频输入                                                        │
│     │                                                           │
│     ▼                                                           │
│  VAD 检测语音段                                                  │
│     │                                                           │
│     ▼                                                           │
│  SpeakerEmbeddingExtractor                                      │
│     │                                                           │
│     ▼                                                           │
│  AsrDiarizationManager.identifySpeakerAtSegmentEnd()            │
│     │                                                           │
│     ▼                                                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ AsrDiarizer.identifySpeaker()                            │   │
│  │                                                           │   │
│  │   ┌─────────────────────┐                                │   │
│  │   │ Registered Speakers │ ← SpeakerManager               │   │
│  │   │ (张三, 李四...)      │   (持久化存储)                 │   │
│  │   └─────────────────────┘                                │   │
│  │          │ threshold: 0.7                                │   │
│  │          ▼                                                │   │
│  │   ┌─────────────────────┐                                │   │
│  │   │ Session Speakers    │ ← _speakers                    │   │
│  │   │ (Speaker 1, ...)    │   (多 embedding)               │   │
│  │   └─────────────────────┘                                │   │
│  │          │ threshold: 0.5                                │   │
│  │          ▼                                                │   │
│  │   ┌─────────────────────┐                                │   │
│  │   │ New Speaker         │                                │   │
│  │   └─────────────────────┘                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│     │                                                           │
│     ▼                                                           │
│  输出: displayLabel                                             │
│  ("张三" 或 "Speaker 1")                                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 兼容性保证

- `AsrDiarizer` 构造函数可选参数 `registeredSpeakers`，不传则保持原有行为
- `AsrDiarizationConfig` 新增字段有默认值，旧配置自动兼容
- API 层面 `AsrSdk` 接口不变，`result.labeledText` 格式不变

## 测试要点

1. **已注册匹配测试**
   - 注册张三 → 张三发言 → 应显示 "张三"
   - 未注册用户发言 → 应显示 "Speaker 1"

2. **重识别测试**
   - 张三发言 → "张三"
   - 李四发言 → "李四"
   - 张三再次发言 → 应继续 "张三"，而非新标签

3. **阈值边界测试**
   - 相似度 0.68（低于 0.7）→ 不匹配已注册
   - 相似度 0.52（高于 0.5）→ 匹配会话内说话人

4. **多 embedding 测试**
   - 同一说话人多次发言 → embedding 累积
   - 超过上限 → 移除最旧 embedding