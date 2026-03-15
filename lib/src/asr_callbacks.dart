import 'asr_state.dart';

/// ASR 识别回调配置类
///
/// 封装所有 ASR 识别相关的回调函数
class AsrCallbacks {
  /// 实时部分识别结果回调
  final Function(String) onPartialResult;

  /// 最终识别结果回调
  final Function(String) onFinalResult;

  /// 错误回调
  final Function(String)? onError;

  /// 状态变化回调
  final Function(AsrRecorderState)? onStateChanged;

  const AsrCallbacks({
    required this.onPartialResult,
    required this.onFinalResult,
    this.onError,
    this.onStateChanged,
  });

  /// 从命名参数创建
  factory AsrCallbacks.from({
    required Function(String) onPartialResult,
    required Function(String) onFinalResult,
    Function(String)? onError,
    Function(AsrRecorderState)? onStateChanged,
  }) {
    return AsrCallbacks(
      onPartialResult: onPartialResult,
      onFinalResult: onFinalResult,
      onError: onError,
      onStateChanged: onStateChanged,
    );
  }
}
