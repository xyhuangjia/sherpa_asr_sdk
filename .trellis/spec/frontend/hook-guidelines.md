# Hook Guidelines

> How reactive patterns are used in this project.

---

## Overview

本项目是 Dart SDK，不使用 React Hooks。但采用类似的**响应式模式**：
- **Stream** 替代 hooks 进行状态订阅
- **回调函数** 处理事件响应
- **getter** 提供响应式状态访问

---

## Stream Patterns

### 状态流 (State Stream)

使用 `StreamController.broadcast()` 创建多监听者流：

```dart
// lib/src/asr_sdk.dart:58-63
static final StreamController<AsrSdkState> _stateController =
    StreamController<AsrSdkState>.broadcast();

static Stream<AsrSdkState> get stateStream => _stateController.stream;
```

使用方式：

```dart
AsrSdk.stateStream.listen((state) {
  print('State changed to: $state');
});
```

### 结果流 (Result Stream)

```dart
// lib/src/asr_sdk.dart:216-224
static Stream<String> recognize() {
  _streamController?.close();
  _streamController = StreamController<String>();
  _isListening = true;
  _beginRecognition();
  return _streamController!.stream;
}
```

使用方式：

```dart
AsrSdk.recognize().listen(
  (text) => print('Recognized: $text'),
  onDone: () => print('Recognition complete'),
  onError: (e) => print('Error: $e'),
);
```

---

## Callback Patterns

### 进度回调

```dart
// lib/src/asr_sdk.dart:84-86
static Future<bool> initialize({
  Function(double progress)? onProgress,
  Function(String status)? onStatus,
}) async { ... }
```

使用方式：

```dart
await AsrSdk.initialize(
  onProgress: (p) => print('Progress: ${(p * 100).toInt()}%'),
  onStatus: (s) => print('Status: $s'),
);
```

### 结果回调

```dart
// lib/src/asr_recorder.dart:15-18
final Function(String) onPartialResult;  // 实时部分结果
final Function(String) onFinalResult;    // 最终结果
final Function(String)? onError;         // 错误
final Function(AsrRecorderState)? onStateChanged;  // 状态变化
```

---

## Reactive Getters

使用 getter 提供实时状态访问：

```dart
// lib/src/asr_sdk.dart:291-305
static bool get isInitialized =>
    _state == AsrSdkState.ready || _state == AsrSdkState.started;

static bool get isStarted => _state == AsrSdkState.started;

static bool get isListening => _isListening;

static AsrSdkState get state => _state;

static int get duration => _recorder?.duration ?? 0;
```

---

## Naming Conventions

| 类型 | 命名模式 | 示例 |
|------|----------|------|
| **Stream** | `xxxStream` | `stateStream`, `resultStream` |
| **Getter** | `isXxx`, `xxx` | `isListening`, `state`, `duration` |
| **回调** | `onXxx` | `onProgress`, `onError`, `onStatus` |

---

## Common Mistakes

### ❌ 错误：使用单播 StreamController

```dart
// 不要这样做 - 只能有一个监听者
static final _controller = StreamController<AsrState>();
```

### ✅ 正确：使用广播 StreamController

```dart
// lib/src/asr_service.dart:22-23
final StreamController<AsrState> _stateController =
    StreamController<AsrState>.broadcast();
```

### ❌ 错误：忘记关闭 StreamController

```dart
// 不要这样做
static void dispose() {
  // 忘记关闭 _stateController
}
```

### ✅ 正确：正确清理资源

```dart
// lib/src/asr_sdk.dart:200-208
static Future<void> dispose() async {
  await stop();
  await _asrService.dispose();
  _state = AsrSdkState.notInitialized;
  _stateController.add(_state);
  await _stateController.close();  // 关闭 Stream
}
```

### ❌ 错误：忘记订阅内部服务的 Stream

```dart
// 不要这样做 - AsrService 的结果流没有被监听
class AsrRecorder {
  Future<void> startRecording() async {
    await _asrService!.startRecognition();
    final stream = await _audioRecorder.startStream(config);
    _streamSubscription = stream.listen((data) {
      _asrService!.acceptAudio(float32.toList());
    });
    // 缺少: 没有订阅 _asrService.resultStream
    // 结果: onPartialResult/onFinalResult 永远不会被调用
  }
}
```

### ✅ 正确：订阅所有相关的 Stream

```dart
// lib/src/asr_recorder.dart:88-106
Future<void> startRecording() async {
  await _asrService!.startRecognition();

  // 订阅识别结果流
  _resultSubscription = _asrService!.resultStream.listen(
    (text) {
      onPartialResult(text);  // 转发结果到回调
    },
    onError: (e) {
      onError?.call('识别错误: $e');
    },
  );

  // 订阅录音流
  final stream = await _audioRecorder.startStream(config);
  _streamSubscription = stream.listen((data) {
    _asrService!.acceptAudio(float32.toList());
  });
}

Future<void> stopRecording() async {
  await _resultSubscription?.cancel();  // 清理结果订阅
  _resultSubscription = null;
  // ...
}
```