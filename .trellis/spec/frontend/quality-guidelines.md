# Quality Guidelines

> Code quality standards for SDK development.

---

## Overview

本项目遵循 Flutter/Dart 最佳实践：
- 使用 `flutter_lints` 作为基础 lint 规则
- 注重 API 文档完整性
- 采用防御性编程策略

---

## Forbidden Patterns

### ❌ 不要：暴露内部实现

```dart
// lib/sherpa_asr_sdk.dart - 不要导出内部类
export 'src/asr_service.dart';   // 错误
export 'src/asr_recorder.dart';  // 错误
```

### ❌ 不要：使用全局可变状态

```dart
// 不要这样做
AsrState globalState = AsrState.idle;  // 全局变量
```

### ❌ 不要：异步方法无返回值

```dart
// 不要这样做
static void initialize() async { ... }  // 应返回 Future<bool>
```

### ❌ 不要：硬编码路径或 URL

```dart
// 不要这样做
final url = 'https://example.com/model.onnx';
```

---

## Required Patterns

### ✅ 文档注释

所有公共 API 必须有 dartdoc 注释：

```dart
// lib/src/asr_sdk.dart:83
/// 初始化服务（APP 启动时调用，只调用一次）
static Future<bool> initialize({...}) async { ... }
```

### ✅ 命名参数

公共方法使用命名参数：

```dart
// lib/src/asr_sdk.dart:84-86
static Future<bool> initialize({
  Function(double progress)? onProgress,
  Function(String status)? onStatus,
}) async { ... }
```

### ✅ 空安全处理

```dart
// lib/src/asr_sdk.dart:253
if (!_isListening || _recorder == null) return;
```

### ✅ 资源清理

```dart
// lib/src/asr_sdk.dart:200-208
static Future<void> dispose() async {
  await stop();
  await _asrService.dispose();
  await _stateController.close();
}
```

---

## Testing Requirements

### 测试命令

```bash
flutter test
```

### 测试范围

| 测试类型 | 文件位置 | 示例 |
|----------|----------|------|
| 状态枚举测试 | `test/sherpa_asr_sdk_test.dart` | `group('AsrSdkState', () {...})` |
| 配置测试 | `test/sherpa_asr_sdk_test.dart` | `expect(AsrConfig.targetSampleRate, 16000)` |
| 初始状态测试 | `test/sherpa_asr_sdk_test.dart` | `expect(AsrSdk.isInitialized, false)` |

### 测试示例

```dart
// test/sherpa_asr_sdk_test.dart:6-19
group('AsrSdkState', () {
  test('initial state is notInitialized', () {
    expect(AsrSdkState.notInitialized.index, 0);
  });

  test('all states are defined', () {
    expect(AsrSdkState.values.length, 5);
  });
});
```

---

## Code Review Checklist

### API 设计
- [ ] 公共 API 有 dartdoc 注释
- [ ] 使用命名参数，避免位置参数
- [ ] 方法命名清晰，符合 Dart 规范
- [ ] 内部实现使用 `_` 前缀标记私有

### 错误处理
- [ ] 异步方法返回成功/失败状态
- [ ] 异常被捕获并记录日志
- [ ] 资源在错误时被正确清理

### 类型安全
- [ ] 避免使用 `dynamic`
- [ ] 可空类型正确标记 `?`
- [ ] 使用 `?.` 和 `??` 进行空安全访问

### 文档
- [ ] 库级文档说明用途和快速开始
- [ ] 复杂方法有使用示例
- [ ] 状态枚举有中文注释

---

## Examples

### 良好的库文档

```dart
// lib/sherpa_asr_sdk.dart:1-33
/// Sherpa ASR SDK - Offline speech recognition for Flutter
///
/// A Flutter package for offline speech recognition using Sherpa-onnx.
/// Supports real-time streaming ASR with built-in Chinese model.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';
///
/// await AsrSdk.initialize();
/// await AsrSdk.start();
/// AsrSdk.recognize().listen((text) => print(text));
/// ```
library sherpa_asr_sdk;
```

### 良好的方法文档

```dart
// lib/src/asr_sdk.dart:11-46
/// ASR SDK 全局服务
///
/// 工作流程：
/// 1. initialize()     - APP 启动时初始化模型（只调用一次）
/// 2. start()          - 进入页面时启动服务（创建录音器）
/// 3. recognize()      - 开始语音识别
/// 4. stopRecognition()- 结束语音识别
/// 5. stop()           - 离开页面时停止服务
/// 6. dispose()        - 释放所有资源
class AsrSdk { ... }
```