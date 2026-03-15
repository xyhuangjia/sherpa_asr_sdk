# State Management

> How state is managed in this project.

---

## Overview

SDK 采用**内部状态机**管理状态：
- 状态通过枚举定义
- 状态变化通过 Stream 通知外部
- 使用单例模式保证状态一致性

---

## State Categories

### 1. SDK 全局状态 (AsrSdkState)

```dart
// lib/src/asr_state.dart:1-17
enum AsrSdkState {
  notInitialized,  // 未初始化
  initializing,    // 初始化中
  ready,           // 已就绪
  started,         // 服务已启动
  error,           // 错误状态
}
```

### 2. ASR 识别状态 (AsrState)

```dart
// lib/src/asr_state.dart:19-38
enum AsrState {
  idle,         // 空闲
  loading,      // 加载中
  ready,        // 就绪（离线）
  readyOnline,  // 就绪（在线）
  listening,    // 识别中
  error,        // 错误
}
```

### 3. 录音器状态 (AsrRecorderState)

```dart
// lib/src/asr_state.dart:40-50
enum AsrRecorderState {
  idle, initializing, recording, stopping,
  completed, canceling, canceled, error,
}
```

---

## State Machine Flow

```
┌─────────────────────────────────────────────────────────┐
│                     AsrSdkState                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   notInitialized ──► initializing ──► ready            │
│                           │              │              │
│                           ▼              ▼              │
│                        error ◄──────► started           │
│                                          │              │
│                                          ▼              │
│   dispose() ◄─────────────────────── dispose()         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## State Update Pattern

### 内部更新 + 外部通知

```dart
// lib/src/asr_sdk.dart:98-125
static Future<bool> initialize({...}) async {
  // 幂等性检查
  if (_state == AsrSdkState.ready || _state == AsrSdkState.started) {
    return true;
  }

  try {
    _state = AsrSdkState.initializing;
    _stateController.add(_state);  // 通知状态变化
    // ...
    _state = AsrSdkState.ready;
    _stateController.add(_state);
    return true;
  } catch (e) {
    _state = AsrSdkState.error;
    _stateController.add(_state);
    return false;
  }
}
```

---

## When to Use Global State

SDK 使用单例模式保证全局状态唯一：

```dart
// lib/src/asr_service.dart:14-17
class AsrService {
  AsrService._internal();
  static final AsrService instance = AsrService._internal();
}
```

**适用场景**：
- SDK 初始化状态
- 模型加载状态
- 识别进行状态

---

## State Observation

### 方式 1：Stream 订阅

```dart
AsrSdk.stateStream.listen((state) {
  switch (state) {
    case AsrSdkState.ready:
      print('SDK is ready');
      break;
    case AsrSdkState.error:
      print('SDK error');
      break;
    // ...
  }
});
```

### 方式 2：Getter 即时查询

```dart
if (AsrSdk.isInitialized) {
  await AsrSdk.start();
}

if (AsrSdk.isListening) {
  await AsrSdk.stopRecognition();
}
```

---

## Common Mistakes

### ❌ 错误：直接修改状态

```dart
// 不要这样做
AsrSdk.state = AsrSdkState.ready;  // 无法赋值（getter only）
```

### ✅ 正确：通过方法改变状态

```dart
await AsrSdk.initialize();  // 内部会更新状态
```

### ❌ 错误：忽略状态检查

```dart
// 不要这样做
AsrSdk.recognize();  // 可能未初始化
```

### ✅ 正确：先检查状态

```dart
// lib/src/asr_sdk.dart:134-137
if (_state != AsrSdkState.ready) {
  _logError('ASR SDK: 请先调用 initialize()');
  return false;
}
```