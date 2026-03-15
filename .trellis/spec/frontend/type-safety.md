# Type Safety

> Type safety patterns in this project.

---

## Overview

本项目使用 Dart 3.10+ 的**空安全**特性：
- 所有类型默认非空
- 可空类型使用 `?` 标记
- 使用 `late` 和 `!` 谨慎处理延迟初始化

---

## Type Organization

### 状态枚举 (Enums)

集中定义在 `asr_state.dart`：

```dart
// lib/src/asr_state.dart
enum AsrSdkState { notInitialized, initializing, ready, started, error }
enum AsrState { idle, loading, ready, readyOnline, listening, error }
enum AsrRecorderState { idle, initializing, recording, ... }
enum AsrMode { offline, online }
enum ModelType { base, advanced, streamingBilingual }
enum RecognitionLanguage { chinese, english, bilingual }
```

### 配置常量类

使用静态常量组织配置：

```dart
// lib/src/asr_config.dart:3-4
class AsrConfig {
  AsrConfig._();  // 私有构造函数，防止实例化

  static const int targetSampleRate = 16000;
  static const String modelsDirName = 'sherpa_models';
  // ...
}
```

### 回调类型

使用类封装回调参数：

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
}
```

---

## Nullable Types

### 可空类型声明

```dart
// lib/src/asr_sdk.dart:52-56
static AsrRecorder? _recorder;           // 可空
static StreamController<String>? _streamController;  // 可空
static AsrLogger? _logger;               // 可空
```

### 空安全访问

```dart
// 使用 ?. 和 ??
_logger?.info(message);              // 安全调用
int get duration => _recorder?.duration ?? 0;  // 空合并
```

### 非空断言（谨慎使用）

```dart
// lib/src/asr_sdk.dart:223
return _streamController!.stream;  // 在确认非空后使用
```

---

## Common Patterns

### 1. 私有构造函数 + 静态成员

```dart
class AsrConfig {
  AsrConfig._();  // 防止实例化

  static const int targetSampleRate = 16000;
  static int get samplesPerChunk => (targetSampleRate * 100) ~/ 1000;
}
```

### 2. 工厂构造函数

```dart
// lib/src/asr_callbacks.dart:27-39
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
```

### 3. 类型推断

```dart
// 使用 var 让编译器推断类型
final values = Float32List(bytes.length ~/ 2);  // Float32List

// 显式类型用于公共 API
Stream<String> recognize() { ... }
```

---

## Forbidden Patterns

### ❌ 不要：使用 dynamic

```dart
// 不要这样做
dynamic result = someFunction();
```

### ✅ 正确：使用具体类型

```dart
String? result = someFunction();
```

### ❌ 不要：过度使用 !

```dart
// 不要这样做（可能导致运行时错误）
String value = nullableString!;
```

### ✅ 正确：先检查再使用

```dart
if (nullableString != null) {
  String value = nullableString;  // 自动提升为非空
}
```

### ❌ 不要：忽略类型参数

```dart
// 不要这样做
final list = [];  // List<dynamic>
```

### ✅ 正确：明确类型参数

```dart
final list = <String>[];
```

---

## Examples

### 良好的类型定义

```dart
// lib/src/asr_config.dart:83-88
static const List<String> baseModelFilesCtc = [
  'model.int8.onnx',
  'tokens.txt',
  'bbpe.model',
  'silero_vad.onnx',
];
```

### 良好的可空处理

```dart
// lib/src/asr_sdk.dart:252-262
static Future<void> stopRecognition() async {
  if (!_isListening || _recorder == null) return;  // 先检查

  try {
    await _recorder!.stopRecording();  // 确认非空后使用
    _isListening = false;
  } catch (e) {
    _isListening = false;
  }
}
```