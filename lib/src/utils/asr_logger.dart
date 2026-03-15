/// 简单日志接口
/// SDK 使用此接口输出日志，使用者可以自定义实现
abstract class AsrLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message);
}

/// 默认日志实现（使用 debugPrint）
class DefaultAsrLogger implements AsrLogger {
  @override
  void debug(String message) => print('[ASR DEBUG] $message');

  @override
  void info(String message) => print('[ASR INFO] $message');

  @override
  void warning(String message) => print('[ASR WARNING] $message');

  @override
  void error(String message) => print('[ASR ERROR] $message');
}
