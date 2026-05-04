/// ASR SDK 状态枚举
enum AsrSdkState {
  /// 未初始化
  notInitialized,

  /// 初始化中
  initializing,

  /// 已就绪（模型已加载）
  ready,

  /// 服务已启动（录音器已创建）
  started,

  /// 错误状态
  error,
}

/// ASR 识别状态枚举
enum AsrState {
  /// 空闲状态
  idle,

  /// 初始化中
  loading,

  /// 已就绪（离线模式）
  ready,

  /// 已就绪（在线模式）
  readyOnline,

  /// 识别中
  listening,

  /// 错误状态
  error,
}

/// ASR 录音器状态枚举
enum AsrRecorderState {
  idle,
  initializing,
  recording,
  stopping,
  completed,
  canceling,
  canceled,
  error,
}

/// 识别模式枚举
enum AsrMode {
  /// 离线模式
  offline,

  /// 在线模式
  online,
}

/// 模型类型枚举
enum ModelType {
  /// 基础模型（中文小模型）
  base,

  /// 高级模型（中英双语）
  advanced,

  /// 流式中英模型
  streamingBilingual,
}

/// 识别语言枚举
enum RecognitionLanguage {
  /// 中文
  chinese,

  /// 英文
  english,

  /// 中英混合（自动检测）
  bilingual,
}
