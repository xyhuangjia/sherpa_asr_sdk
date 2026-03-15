# Logging Guidelines

> How logging is done in this project.

---

## Overview

SDK 使用可插拔的日志接口 `AsrLogger`：
- **抽象接口** - 允许使用者自定义日志实现
- **默认实现** - 使用 `print` 输出到控制台
- **多级别日志** - debug, info, warning, error

---

## Log Interface

```dart
// lib/src/utils/asr_logger.dart:1-8
abstract class AsrLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message);
}
```

---

## Log Levels

| 级别 | 用途 | 示例 |
|------|------|------|
| **debug** | 调试信息、流程跟踪 | `'ASR: 录音器初始化成功'` |
| **info** | 正常操作日志 | `'ASR SDK: 服务已启动'` |
| **warning** | 警告信息 | 暂未使用 |
| **error** | 错误信息 | `'ASR SDK: 注册异常 - $e'` |

---

## Logging Patterns

### 1. 私有日志方法

每个类提供私有 `_log` 方法，支持可选 logger：

```dart
// lib/src/asr_sdk.dart:73-79
static AsrLogger? _logger;

static void _log(String message) {
  _logger?.info(message);
}

static void _logError(String message) {
  _logger?.error(message);
}
```

### 2. 服务类日志传递

```dart
// lib/src/asr_sdk.dart:68-71
static void setLogger(AsrLogger logger) {
  _logger = logger;
  _asrService.setLogger(logger);  // 传递给内部服务
}
```

### 3. 模型管理器日志

```dart
// lib/src/model/sherpa_models_manager.dart:32-35
void _log(String message) {
  _logger?.debug(message);
  debugPrint(message);  // 同时输出到 Flutter debug console
}
```

---

## Default Implementation

```dart
// lib/src/utils/asr_logger.dart:10-23
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
```

---

## What to Log

✅ **应该记录**：
- 初始化成功/失败
- 服务启动/停止
- 识别开始/结束
- 模型下载进度
- 状态转换
- 错误和异常

```dart
// lib/src/asr_sdk.dart:101-102
_log('ASR SDK: 开始注册...');
_log('ASR SDK: 注册成功');
```

---

## What NOT to Log

❌ **不应记录**：
- 用户语音内容（隐私）
- 音频原始数据
- 敏感配置信息
- 内部实现细节

---

## Examples

### 使用日志

```dart
// 设置自定义日志记录器
AsrSdk.setLogger(DefaultAsrLogger());

// 或自定义实现
class MyLogger implements AsrLogger {
  @override
  void debug(String message) => developer.log(message, name: 'ASR');
  @override
  void info(String message) => developer.log(message, name: 'ASR');
  @override
  void warning(String message) => developer.log(message, name: 'ASR');
  @override
  void error(String message) => developer.log(message, name: 'ASR', level: 1000);
}
```