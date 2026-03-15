# Sherpa ASR SDK

[English](#english) | [中文](#中文)

---

<a name="english"></a>

## English

Offline speech recognition SDK for Flutter using Sherpa-onnx. Supports real-time streaming ASR with automatic model download.

### Features

- 🎤 **Offline Recognition** - No internet required, powered by Sherpa-onnx
- 🔄 **Real-time Streaming** - Get results as you speak
- 📦 **Auto Download** - Models downloaded automatically on first use
- 🔧 **Model Management** - Download and switch between models
- 📱 **Cross Platform** - iOS and Android support

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  sherpa_asr_sdk: ^1.0.0
```

### Quick Start

```dart
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

// 1. Initialize (call once at app startup)
AsrSdk.setLogger(DefaultAsrLogger());
final success = await AsrSdk.initialize(
  onProgress: (p) => print('Loading: ${(p * 100).toInt()}%'),
);

// 2. Start service (when entering a page)
await AsrSdk.start();

// 3. Recognize speech
AsrSdk.recognize().listen((text) {
  print('Recognized: $text');
});

// 4. Stop recognition
await AsrSdk.stopRecognition();

// 5. Stop service (when leaving page)
await AsrSdk.stop();

// 6. Dispose (when app exits)
await AsrSdk.dispose();
```

### API Reference

#### Lifecycle Methods

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize SDK (call once at startup) |
| `start()` | Start service (create recorder) |
| `stop()` | Stop service (destroy recorder) |
| `dispose()` | Release all resources |

#### Recognition Methods

| Method | Description |
|--------|-------------|
| `recognize()` | Start recognition, returns `Stream<String>` |
| `stopRecognition()` | Stop current recognition |
| `cancelRecognition()` | Cancel current recognition |

#### State Properties

| Property | Description |
|----------|-------------|
| `isInitialized` | SDK initialized |
| `isStarted` | Service started |
| `isListening` | Recognition in progress |
| `state` | Current SDK state |
| `stateStream` | Stream of state changes |

### Model Management

```dart
final manager = SherpaModelsManager.instance;

// Check models
final hasModel = await manager.hasStreamingBilingualModel();

// Download model
await manager.downloadStreamingBilingualModels(
  onProgress: (p) => print('Download: ${(p * 100).toInt()}%'),
);
```

### Model Types

| Type | Description | Size |
|------|-------------|------|
| Streaming Bilingual | Chinese-English | ~30MB |
| Base | Chinese only | ~15MB |
| Advanced | Higher quality | ~50MB |

### Platform Setup

#### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for speech recognition</string>
```

#### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

<a name="中文"></a>

## 中文

基于 Sherpa-onnx 的 Flutter 离线语音识别 SDK。支持实时流式识别，自动下载模型。

### 功能特性

- 🎤 **离线识别** - 无需联网，基于 Sherpa-onnx
- 🔄 **实时流式** - 边说边识别，即时返回结果
- 📦 **自动下载** - 首次使用时自动下载模型
- 🔧 **模型管理** - 支持下载和切换不同模型
- 📱 **跨平台** - 支持 iOS 和 Android

### 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  sherpa_asr_sdk: ^1.0.0
```

### 快速开始

```dart
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

// 1. 初始化（应用启动时调用一次）
AsrSdk.setLogger(DefaultAsrLogger());
final success = await AsrSdk.initialize(
  onProgress: (p) => print('加载中: ${(p * 100).toInt()}%'),
);

// 2. 启动服务（进入页面时调用）
await AsrSdk.start();

// 3. 开始识别
AsrSdk.recognize().listen((text) {
  print('识别结果: $text');
});

// 4. 停止识别
await AsrSdk.stopRecognition();

// 5. 停止服务（离开页面时调用）
await AsrSdk.stop();

// 6. 释放资源（应用退出时调用）
await AsrSdk.dispose();
```

### API 参考

#### 生命周期方法

| 方法 | 描述 |
|------|------|
| `initialize()` | 初始化 SDK（启动时调用一次） |
| `start()` | 启动服务（创建录音器） |
| `stop()` | 停止服务（销毁录音器） |
| `dispose()` | 释放所有资源 |

#### 识别方法

| 方法 | 描述 |
|------|------|
| `recognize()` | 开始识别，返回 `Stream<String>` |
| `stopRecognition()` | 停止当前识别 |
| `cancelRecognition()` | 取消当前识别 |

#### 状态属性

| 属性 | 描述 |
|------|------|
| `isInitialized` | SDK 是否已初始化 |
| `isStarted` | 服务是否已启动 |
| `isListening` | 是否正在识别 |
| `state` | 当前 SDK 状态 |
| `stateStream` | 状态变化流 |

### 模型管理

```dart
final manager = SherpaModelsManager.instance;

// 检查模型
final hasModel = await manager.hasStreamingBilingualModel();

// 下载模型
await manager.downloadStreamingBilingualModels(
  onProgress: (p) => print('下载中: ${(p * 100).toInt()}%'),
);
```

### 模型类型

| 类型 | 描述 | 大小 |
|------|------|------|
| 流式中英双语 | 中英文混合识别 | 约 30MB |
| 基础中文 | 纯中文识别 | 约 15MB |
| 高级模型 | 更高质量 | 约 50MB |

### 平台配置

#### iOS

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>此应用需要麦克风权限以进行语音识别</string>
```

#### Android

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

---

## Example / 示例

See the `example/` directory for a complete sample app.

查看 `example/` 目录获取完整示例应用。

## License / 许可证

MIT License