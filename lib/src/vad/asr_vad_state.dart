/// VAD (Voice Activity Detection) 状态枚举
enum VadState {
  /// 空闲状态
  idle,

  /// 检测到语音开始
  speechStarted,

  /// 语音进行中
  speechInProgress,

  /// 检测到语音结束
  speechEnded,

  /// 检测到静音
  silence,
}
