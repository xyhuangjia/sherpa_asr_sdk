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

/// VAD 事件回调类
///
/// 用于注册 VAD 相关的事件回调函数
class AsrVadCallbacks {
  /// 语音开始回调
  final Function()? onSpeechStart;

  /// 语音结束回调（带识别结果）
  final Function(String speech)? onSpeechEnd;

  /// 静音检测回调
  final Function(Duration duration)? onSilence;

  const AsrVadCallbacks({
    this.onSpeechStart,
    this.onSpeechEnd,
    this.onSilence,
  });

  /// 从命名参数创建
  factory AsrVadCallbacks.from({
    Function()? onSpeechStart,
    Function(String speech)? onSpeechEnd,
    Function(Duration duration)? onSilence,
  }) {
    return AsrVadCallbacks(
      onSpeechStart: onSpeechStart,
      onSpeechEnd: onSpeechEnd,
      onSilence: onSilence,
    );
  }
}
