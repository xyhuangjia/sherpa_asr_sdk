# Sherpa ASR SDK

[![pub package](https://img.shields.io/pub/v/sherpa_asr_sdk.svg)](https://pub.dev/packages/sherpa_asr_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[English](README.md)

基于 Sherpa-Onnx 的 Flutter 离线语音识别 SDK。支持实时流式识别，自动下载模型。

## 功能特性

- 🎤 **离线识别** - 无需联网，基于 Sherpa-Onnx 引擎
- 🔄 **实时流式** - 边说边识别，即时返回结果
- 📦 **自动下载** - 首次使用时自动下载模型
- 🔧 **模型管理** - 支持下载和切换不同模型
- 🌐 **双语支持** - 内置中英双语模型
- 📱 **跨平台** - 支持 iOS 和 Android
- 🔌 **可插拔日志** - 灵活的日志接口，方便调试

## 安装

在 `pubspec.yaml` 中添加：

```yaml
dependencies:
  sherpa_asr_sdk: ^1.0.0
```

然后运行：

```bash
flutter pub get
```

## 平台配置

### iOS

在 `ios/Runner/Info.plist` 中添加：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>此应用需要麦克风权限以进行语音识别</string>
```

### Android

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

## 快速开始

### 1. 导入包

```dart
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';
```

### 2. 初始化 SDK（应用启动时调用一次）

```dart
AsrSdk.setLogger(DefaultAsrLogger());

final success = await AsrSdk.initialize(
  onProgress: (progress) => print('加载中: ${(progress * 100).toInt()}%'),
  onStatus: (status) => print('状态: $status'),
);

if (!success) {
  print('ASR SDK 初始化失败');
  return;
}
```

### 3. 启动服务（进入页面时调用）

```dart
await AsrSdk.start();
```

### 4. 开始识别

```dart
AsrSdk.recognize().listen((text) {
  print('识别结果: $text');
}, onDone: () {
  print('识别完成');
});
```

### 5. 停止识别

```dart
await AsrSdk.stopRecognition();
```

### 6. 停止服务（离开页面时调用）

```dart
await AsrSdk.stop();
```

### 7. 释放资源（应用退出时调用）

```dart
await AsrSdk.dispose();
```

## 完整示例

```dart
import 'package:flutter/material.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AsrSdk.setLogger(DefaultAsrLogger());
  
  await AsrSdk.initialize(
    onProgress: (p) => print('进度: ${(p * 100).toInt()}%'),
    onStatus: (s) => print('状态: $s'),
  );
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ASRScreen(),
    );
  }
}

class ASRScreen extends StatefulWidget {
  @override
  _ASRScreenState createState() => _ASRScreenState();
}

class _ASRScreenState extends State<ASRScreen> {
  String _recognizedText = '';
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    AsrSdk.start();
  }

  void _toggleRecognition() {
    if (_isListening) {
      AsrSdk.stopRecognition();
      setState(() => _isListening = false);
    } else {
      setState(() {
        _isListening = true;
        _recognizedText = '';
      });
      
      AsrSdk.recognize().listen((text) {
        setState(() => _recognizedText = text);
      }, onDone: () {
        setState(() => _isListening = false);
      });
    }
  }

  @override
  void dispose() {
    AsrSdk.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('语音识别')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                _recognizedText.isEmpty 
                    ? '点击按钮开始识别' 
                    : _recognizedText,
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _toggleRecognition,
              child: Text(_isListening ? '停止' : '开始'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## API 参考

### AsrSdk - 主要 SDK 类

#### 生命周期方法

| 方法 | 描述 | 调用时机 |
|------|------|----------|
| `initialize()` | 初始化 SDK | 应用启动时调用一次 |
| `start()` | 启动服务 | 进入页面时调用 |
| `stop()` | 停止服务 | 离开页面时调用 |
| `dispose()` | 释放所有资源 | 应用退出时调用 |

#### 识别方法

| 方法 | 返回值 | 描述 |
|------|--------|------|
| `recognize()` | `Stream<String>` | 开始语音识别 |
| `stopRecognition()` | `Future<void>` | 停止当前识别 |
| `cancelRecognition()` | `Future<void>` | 取消当前识别 |
| `pause()` | `Future<void>` | 暂停识别 |
| `resume()` | `Stream<String>` | 恢复识别 |

#### 状态属性

| 属性 | 类型 | 描述 |
|------|------|------|
| `isInitialized` | `bool` | SDK 是否已初始化 |
| `isStarted` | `bool` | 服务是否已启动 |
| `isListening` | `bool` | 是否正在识别 |
| `state` | `AsrSdkState` | 当前 SDK 状态 |
| `duration` | `int` | 录音时长（秒） |
| `stateStream` | `Stream<AsrSdkState>` | 状态变化流 |

#### 配置方法

| 方法 | 描述 |
|------|------|
| `setLogger(AsrLogger logger)` | 设置自定义日志记录器 |

### AsrSdkState - SDK 状态

| 状态 | 描述 |
|------|------|
| `notInitialized` | SDK 未初始化 |
| `initializing` | SDK 正在初始化 |
| `ready` | SDK 已就绪 |
| `started` | 服务已启动 |
| `error` | 发生错误 |

### AsrLogger - 日志接口

```dart
abstract class AsrLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message);
}
```

使用 `DefaultAsrLogger` 进行控制台日志输出，或实现自己的日志记录器。

## 模型管理

### 模型类型

| 类型 | 描述 | 大小 | 使用场景 |
|------|------|------|----------|
| 流式中英双语 | 中英文混合识别 | 约 30MB | 中英文混合场景 |
| 基础中文模型 | 纯中文识别 | 约 15MB | 纯中文场景 |
| 高级模型 | 更高质量 | 约 50MB | 需要更高准确度 |

### 模型操作

```dart
final manager = SherpaModelsManager.instance;

// 初始化管理器
await manager.initialize();

// 检查模型是否存在
final hasModel = await manager.hasStreamingBilingualModel();

// 获取可用模型路径
final modelPath = await manager.getBestModelPath();

// 下载模型
await manager.downloadStreamingBilingualModels(
  onProgress: (progress) => print('下载中: ${(progress * 100).toInt()}%'),
  onStatusChange: (status) => print('状态: $status'),
);
```

### 模型存储位置

模型存储在应用的文档目录中：
- **iOS**: `NSDocumentDirectory/sherpa_models/`
- **Android**: `files/sherpa_models/`

## 配置参数

### 音频参数

| 参数 | 值 | 描述 |
|------|-----|------|
| 采样率 | 16000 Hz | Sherpa-Onnx 要求 |
| 声道数 | 1 | 单声道 |
| 音频分块 | 100 ms | 实时处理 |
| 比特率 | 128 kbps | 音频质量 |

### 识别参数

| 参数 | 默认值 | 描述 |
|------|--------|------|
| 线程数 | 2 | 处理线程数 |
| 最大时长 | 60 秒 | 最大识别时长 |
| 最小时长 | 1 秒 | 最小识别时长 |

## 平台支持

| 平台 | 支持 | 说明 |
|------|------|------|
| iOS | ✅ | iOS 11.0+ |
| Android | ✅ | Android 5.0+ (API 21+) |
| Web | ❌ | 不支持 |
| macOS | ❌ | 不支持 |
| Windows | ❌ | 不支持 |
| Linux | ❌ | 不支持 |

## 性能指标

- **延迟**: 实时流式延迟 < 100ms
- **内存**: 约 50-100MB（取决于模型）
- **CPU**: 针对移动设备优化
- **电池**: 高效的能耗管理
- **离线**: 完全离线，无需网络

## 常见问题

### 常见问题排查

#### 1. 初始化失败

**症状**: `initialize()` 返回 `false`

**解决方案**:
- 检查麦克风权限
- 确保有足够的存储空间（约 100MB）
- 检查首次下载模型时的网络连接
- 使用 `AsrSdk.setLogger(DefaultAsrLogger())` 查看日志

#### 2. 无音频输入

**症状**: 没有识别结果

**解决方案**:
- 确认麦克风权限已授予
- 检查是否有其他应用正在使用麦克风
- 用其他录音应用测试麦克风

#### 3. 识别质量差

**症状**: 识别不准确或漏字

**解决方案**:
- 清晰说话，靠近麦克风
- 减少背景噪音
- 混合语言场景使用双语模型
- 确保音频输入正常

#### 4. 应用崩溃

**症状**: 识别过程中应用崩溃

**解决方案**:
- 检查可用内存
- 确保正确的生命周期管理（离开页面时调用 `stop()`）
- 查看崩溃日志

### 调试模式

启用详细日志：

```dart
AsrSdk.setLogger(DefaultAsrLogger());
```

监控状态变化：

```dart
AsrSdk.stateStream.listen((state) {
  print('状态变化: $state');
});
```

## 示例项目

查看 `/example` 目录获取完整示例：

- **基础用法**: 简单的语音识别
- **状态管理**: 集成 Provider/Riverpod
- **自定义日志**: 实现自定义日志记录
- **模型管理**: 下载和切换模型

## 架构设计

```
sherpa_asr_sdk/
├── lib/
│   ├── sherpa_asr_sdk.dart          # 主导出文件
│   └── src/
│       ├── asr_sdk.dart              # SDK 主类
│       ├── asr_service.dart          # 识别服务
│       ├── asr_recorder.dart         # 音频录制器
│       ├── asr_config.dart           # 配置
│       ├── asr_state.dart            # 状态定义
│       ├── asr_callbacks.dart        # 回调接口
│       ├── model/
│       │   └── sherpa_models_manager.dart  # 模型管理
│       └── utils/
│           ├── asr_logger.dart       # 日志工具
│           └── audio_converter.dart  # 音频处理
└── example/                          # 示例应用
```

## 贡献指南

欢迎贡献！请遵循以下步骤：

1. Fork 本仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

### 开发环境设置

1. 克隆仓库
2. 运行 `flutter pub get`
3. 运行测试: `flutter test`
4. 检查格式: `dart format .`
5. 分析代码: `flutter analyze`

## 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件。

## 致谢

- [Sherpa-Onnx](https://github.com/k2-fsa/sherpa-onnx) - 语音识别引擎
- [k2-fsa](https://github.com/k2-fsa) - 预训练模型
- [Flutter](https://flutter.dev) - UI 框架

## 技术支持

如果您遇到任何问题或有疑问：

1. 查看 [常见问题](https://github.com/xyhuangjia/sherpa_asr_sdk/wiki/FAQ)
2. 搜索 [已有问题](https://github.com/xyhuangjia/sherpa_asr_sdk/issues)
3. 创建 [新问题](https://github.com/xyhuangjia/sherpa_asr_sdk/issues/new)

## 更新日志

查看 [CHANGELOG.md](CHANGELOG.md) 了解版本历史。

## 开发路线

- [ ] 支持更多语言
- [ ] 唤醒词检测
- [ ] 说话人识别
- [ ] 降噪功能
- [ ] 平台优化


