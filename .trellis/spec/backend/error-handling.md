# Error Handling

> How errors are handled in this project.

---

## Overview

SDK 采用防御性编程策略：
- **不抛出异常给调用者** - 返回 `bool` 或 `null` 表示失败
- **通过回调通知错误** - `onError` 回调
- **日志记录详细错误** - 使用 `AsrLogger` 接口

---

## Error Handling Patterns

### 1. 返回布尔值表示成功/失败

```dart
// lib/src/asr_sdk.dart:84-124
static Future<bool> initialize({...}) async {
  try {
    // ... 初始化逻辑
    return true;
  } catch (e) {
    _logError('ASR SDK: 注册异常 - $e');
    return false;
  }
}
```

### 2. 通过回调传递错误信息

```dart
// lib/src/asr_recorder.dart:29-34
class AsrRecorder {
  final Function(String) onPartialResult;
  final Function(String) onFinalResult;
  final Function(String)? onError;  // 可选的错误回调
  final Function(AsrRecorderState)? onStateChanged;
}
```

### 3. Stream 错误传递

```dart
// lib/src/asr_sdk.dart:149-154
onError: (error) {
  _logError('ASR SDK: 识别错误 - $error');
  _streamController?.addError(error);  // 通过 Stream 传递错误
  _streamController?.close();
  _isListening = false;
},
```

---

## State-Based Error Handling

SDK 使用状态机处理错误，错误时切换到 `error` 状态：

```dart
// lib/src/asr_service.dart:77-82
void _updateState(AsrState newState) {
  if (_state != newState) {
    _state = newState;
    _stateController.add(newState);  // 通知状态变化
  }
}

// 错误时设置错误状态
_updateState(AsrState.error);
```

---

## Common Mistakes

### ❌ 错误：直接抛出异常

```dart
// 不要这样做
if (!_asrService!.isReady) {
  throw Exception('服务未就绪');
}
```

### ✅ 正确：返回失败并记录日志

```dart
// lib/src/asr_sdk.dart:134-137
if (_state != AsrSdkState.ready) {
  _logError('ASR SDK: 请先调用 initialize()');
  return false;
}
```

### ❌ 错误：吞掉异常不处理

```dart
// 不要这样做
try {
  await someOperation();
} catch (e) {
  // 什么都不做
}
```

### ✅ 正确：记录日志并清理资源

```dart
// lib/src/asr_sdk.dart:174-179
} catch (e) {
  _logError('ASR SDK: 启动失败 - $e');
  _recorder?.dispose();  // 清理资源
  _recorder = null;
  return false;
}
```