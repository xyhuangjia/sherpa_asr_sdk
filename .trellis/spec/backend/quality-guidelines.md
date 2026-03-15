# Quality Guidelines

> Code quality standards for SDK development.

---

## Overview

本项目遵循 Flutter/Dart 最佳实践：
- 使用 `flutter_lints` 作为基础 lint 规则
- 注重代码可读性和文档完整性
- 采用单例和门面模式简化 API

---

## Forbidden Patterns

### ❌ 不要：暴露内部实现

```dart
// 不要在公共 API 中暴露内部类
export 'src/asr_service.dart';  // 错误：内部服务不应导出
```

### ❌ 不要：使用全局可变状态

```dart
// 不要这样做
AsrState currentState = AsrState.idle;  // 全局变量
```

### ❌ 不要：忽略异步错误

```dart
// 不要这样做
_asrService.initialize();  // 缺少 await 或错误处理
```

---

## Required Patterns

### ✅ 单例模式

```dart
// lib/src/asr_service.dart:14-17
class AsrService {
  AsrService._internal();
  static final AsrService instance = AsrService._internal();
}
```

### ✅ 静态门面模式

```dart
// lib/src/asr_sdk.dart:47-48
class AsrSdk {
  AsrSdk._();  // 私有构造函数，防止实例化
}
```

### ✅ 资源清理

```dart
// lib/src/asr_sdk.dart:200-208
static Future<void> dispose() async {
  await stop();
  await _asrService.dispose();
  _state = AsrSdkState.notInitialized;
  _stateController.add(_state);
  await _stateController.close();
  _log('ASR SDK: 资源已释放');
}
```

### ✅ 空安全检查

```dart
// lib/src/asr_sdk.dart:228-233
static void _beginRecognition() {
  if (_recorder == null) {
    _streamController?.addError('服务未启动');
    _streamController?.close();
    _isListening = false;
    return;
  }
}
```

---

## Testing Requirements

### 测试文件位置
- `test/sherpa_asr_sdk_test.dart`

### 测试内容
- 状态枚举完整性测试
- 配置参数测试
- 初始状态测试

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
- [ ] 公共 API 在 `sherpa_asr_sdk.dart` 中正确导出
- [ ] 方法命名清晰，符合 Dart 命名规范
- [ ] 参数使用命名参数，提供默认值
- [ ] 有完整的 dartdoc 文档注释

### 错误处理
- [ ] 异常被捕获并记录日志
- [ ] 返回值正确表示成功/失败
- [ ] 资源在错误时被正确清理

### 状态管理
- [ ] 状态转换逻辑正确
- [ ] 状态变化通过 Stream 通知
- [ ] 边界条件已处理（null 检查）

### 文档
- [ ] 公共 API 有 dartdoc 注释
- [ ] 复杂逻辑有中文注释说明
- [ ] 示例代码可运行

---

## Examples

### 良好的 API 文档

```dart
// lib/src/asr_sdk.dart:83-96
/// 初始化服务（APP 启动时调用，只调用一次）
static Future<bool> initialize({
  Function(double progress)? onProgress,
  Function(String status)? onStatus,
}) async {
  // ...
}
```

### 良好的状态管理

```dart
// lib/src/asr_sdk.dart:98-125
static Future<bool> initialize({...}) async {
  if (_state == AsrSdkState.ready || _state == AsrSdkState.started) {
    _log('ASR SDK: 已注册');
    return true;  // 幂等性检查
  }

  if (_state == AsrSdkState.initializing) {
    _log('ASR SDK: 正在注册中');
    return false;  // 防止重复初始化
  }

  try {
    _state = AsrSdkState.initializing;
    _stateController.add(_state);
    // ...
  }
}
```