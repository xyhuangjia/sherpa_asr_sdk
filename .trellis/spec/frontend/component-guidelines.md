# Component Guidelines

> How API components are designed in this project.

---

## Overview

SDK 采用**门面模式**设计：
- `AsrSdk` 作为唯一对外入口
- 静态方法简化调用
- 状态机管理生命周期

---

## API Component Structure

### 主门面类：AsrSdk

```dart
// lib/src/asr_sdk.dart:47-56
class AsrSdk {
  AsrSdk._();  // 私有构造函数，防止实例化

  static AsrSdkState _state = AsrSdkState.notInitialized;
  static AsrRecorder? _recorder;
  static StreamController<String>? _streamController;
  static bool _isListening = false;
  static AsrLogger? _logger;
}
```

### 设计原则

1. **不可实例化** - 私有构造函数 `AsrSdk._()`
2. **静态方法** - 无需创建实例即可调用
3. **状态隔离** - 内部状态通过 getter 暴露

---

## Method Design Patterns

### 1. 生命周期方法

```dart
// lib/src/asr_sdk.dart:83-125
/// 初始化服务（APP 启动时调用，只调用一次）
static Future<bool> initialize({
  Function(double progress)? onProgress,
  Function(String status)? onStatus,
}) async {
  // 幂等性检查
  if (_state == AsrSdkState.ready || _state == AsrSdkState.started) {
    return true;
  }
  // ...
}
```

### 2. 状态查询方法

```dart
// lib/src/asr_sdk.dart:291-305
static bool get isInitialized =>
    _state == AsrSdkState.ready || _state == AsrSdkState.started;

static bool get isStarted => _state == AsrSdkState.started;

static bool get isListening => _isListening;

static AsrSdkState get state => _state;
```

### 3. 异步返回方法

```dart
// lib/src/asr_sdk.dart:216-224
/// 开始语音识别
static Stream<String> recognize() {
  _streamController?.close();
  _streamController = StreamController<String>();
  _isListening = true;
  _beginRecognition();
  return _streamController!.stream;
}
```

---

## Props/Parameters Conventions

### 命名参数 + 可选

```dart
static Future<bool> initialize({
  Function(double progress)? onProgress,  // 可选回调
  Function(String status)? onStatus,
}) async { ... }
```

### 回调命名规范

| 回调名 | 用途 | 参数类型 |
|--------|------|----------|
| `onProgress` | 进度更新 | `Function(double)` |
| `onStatus` | 状态更新 | `Function(String)` |
| `onPartialResult` | 部分结果 | `Function(String)` |
| `onFinalResult` | 最终结果 | `Function(String)` |
| `onError` | 错误处理 | `Function(String)` |
| `onStateChanged` | 状态变化 | `Function(AsrState)` |

---

## Callbacks Class Pattern

```dart
// lib/src/asr_callbacks.dart:6-24
class AsrCallbacks {
  final Function(String) onPartialResult;
  final Function(String) onFinalResult;
  final Function(String)? onError;
  final Function(AsrRecorderState)? onStateChanged;

  const AsrCallbacks({
    required this.onPartialResult,
    required this.onFinalResult,
    this.onError,
    this.onStateChanged,
  });

  factory AsrCallbacks.from({...}) { ... }
}
```

---

## Common Mistakes

### ❌ 错误：暴露内部实现

```dart
// 不要这样做
class AsrSdk {
  static AsrService service = AsrService.instance;  // 暴露内部服务
}
```

### ✅ 正确：隐藏内部实现

```dart
// lib/src/asr_sdk.dart:50
static AsrService get _asrService => AsrService.instance;  // 私有 getter
```

### ❌ 错误：复杂的参数结构

```dart
// 不要这样做
static void configure({
  required int sampleRate,
  required int channels,
  required double vadThreshold,
  // ... 过多参数
}) { ... }
```

### ✅ 正确：使用配置类

```dart
// 使用 AsrConfig 提供默认配置
static const int targetSampleRate = AsrConfig.targetSampleRate;  // 16000
```