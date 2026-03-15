# Directory Structure

> How public API is organized in this project.

---

## Overview

SDK 采用**最小化导出**策略：
- `lib/sherpa_asr_sdk.dart` 作为唯一入口点
- `lib/src/` 内部实现不直接暴露
- 使用 `export` 语句选择性导出公共 API

---

## Directory Layout

```
lib/
├── sherpa_asr_sdk.dart          # 库入口（唯一导出点）
└── src/                         # 内部实现
    ├── asr_sdk.dart             # 主 API 类
    ├── asr_state.dart           # 状态枚举
    ├── asr_config.dart          # 配置常量
    ├── asr_callbacks.dart       # 回调类型
    ├── asr_service.dart         # 内部服务
    ├── asr_recorder.dart        # 内部录音器
    ├── model/                   # 内部模型
    └── utils/                   # 内部工具
```

---

## Public API Exports

```dart
// lib/sherpa_asr_sdk.dart:34-40
library sherpa_asr_sdk;

export 'src/asr_sdk.dart';              // 主 API
export 'src/asr_state.dart';            // 状态枚举
export 'src/asr_config.dart';           // 配置常量
export 'src/asr_callbacks.dart';        // 回调类型
export 'src/utils/asr_logger.dart';     // 日志接口
export 'src/model/sherpa_models_manager.dart';  // 模型管理
```

---

## API Organization Principles

### 1. 单一入口

所有公共 API 通过一个文件导出：

```dart
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';
```

### 2. 分层暴露

| 层级 | 导出内容 | 用途 |
|------|----------|------|
| **门面层** | `AsrSdk` | 主要使用入口 |
| **配置层** | `AsrConfig` | 读取配置参数 |
| **状态层** | `AsrSdkState`, `AsrState` | 监听状态变化 |
| **工具层** | `AsrLogger` | 自定义日志 |

### 3. 隐藏实现

以下不导出，保持内部实现自由度：
- `AsrService` - 内部服务实现
- `AsrRecorder` - 内部录音处理
- `AudioConverter` - 内部音频工具

---

## Naming Conventions

### 公共类命名
- 使用简洁、描述性名称：`AsrSdk`, `AsrConfig`, `AsrState`
- 避免冗余前缀：`SherpaAsrSdk` ❌ → `AsrSdk` ✅

### 公共方法命名
- 使用动词开头：`initialize`, `start`, `stop`, `recognize`
- 布尔返回值用 `is*` 前缀：`isInitialized`, `isListening`

### 参数命名
- 使用命名参数：`onProgress`, `onStatus`, `onError`
- 提供默认值或标记可选

---

## Examples

### 库文档示例

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
/// // Initialize (call once when app starts)
/// await AsrSdk.initialize(
///   onProgress: (p) => print('Progress: ${(p * 100).toInt()}%'),
/// );
///
/// // Start service (when entering a page)
/// await AsrSdk.start();
///
/// // Recognize speech
/// AsrSdk.recognize().listen((text) {
///   print('Recognized: $text');
/// });
/// ```
library sherpa_asr_sdk;
```

### 良好的 API 设计

```dart
// 清晰的生命周期方法
await AsrSdk.initialize();  // 1. 初始化
await AsrSdk.start();       // 2. 启动服务
AsrSdk.recognize();         // 3. 开始识别
await AsrSdk.stop();        // 4. 停止服务
await AsrSdk.dispose();     // 5. 释放资源
```