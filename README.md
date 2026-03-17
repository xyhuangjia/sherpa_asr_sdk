# Sherpa ASR SDK

[![pub package](https://img.shields.io/pub/v/sherpa_asr_sdk.svg)](https://pub.dev/packages/sherpa_asr_sdk)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

[中文文档](README-CN.md)

Offline speech recognition SDK for Flutter using Sherpa-Onnx. Supports real-time streaming ASR with automatic model download.

## Features

- 🎤 **Offline Recognition** - No internet required, powered by Sherpa-Onnx
- 🔄 **Real-time Streaming** - Get instant results as you speak
- 📦 **Auto Download** - Models downloaded automatically on first use
- 🔧 **Model Management** - Download and switch between different models
- 🌐 **Bilingual Support** - Built-in Chinese/English bilingual model
- 📱 **Cross Platform** - iOS and Android support
- 🔌 **Pluggable Logger** - Flexible logging interface for debugging

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  sherpa_asr_sdk: ^1.0.0
```

Then run:

```bash
flutter pub get
```

## Platform Setup

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for speech recognition</string>
```

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

## Quick Start

### 1. Import the package

```dart
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';
```

### 2. Initialize SDK (call once at app startup)

```dart
AsrSdk.setLogger(DefaultAsrLogger());

final success = await AsrSdk.initialize(
  onProgress: (progress) => print('Loading: ${(progress * 100).toInt()}%'),
  onStatus: (status) => print('Status: $status'),
);

if (!success) {
  print('Failed to initialize ASR SDK');
  return;
}
```

### 3. Start service (when entering a page)

```dart
await AsrSdk.start();
```

### 4. Recognize speech

```dart
AsrSdk.recognize().listen((text) {
  print('Recognized: $text');
}, onDone: () {
  print('Recognition completed');
});
```

### 5. Stop recognition

```dart
await AsrSdk.stopRecognition();
```

### 6. Stop service (when leaving page)

```dart
await AsrSdk.stop();
```

### 7. Dispose resources (when app exits)

```dart
await AsrSdk.dispose();
```

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  AsrSdk.setLogger(DefaultAsrLogger());
  
  await AsrSdk.initialize(
    onProgress: (p) => print('Progress: ${(p * 100).toInt()}%'),
    onStatus: (s) => print('Status: $s'),
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
      appBar: AppBar(title: Text('Speech Recognition')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                _recognizedText.isEmpty 
                    ? 'Press button to start' 
                    : _recognizedText,
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _toggleRecognition,
              child: Text(_isListening ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## API Reference

### AsrSdk - Main SDK Class

#### Lifecycle Methods

| Method | Description | When to Call |
|--------|-------------|--------------|
| `initialize()` | Initialize SDK | Once at app startup |
| `start()` | Start service | When entering a page |
| `stop()` | Stop service | When leaving a page |
| `dispose()` | Release all resources | When app exits |

#### Recognition Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `recognize()` | `Stream<String>` | Start speech recognition |
| `stopRecognition()` | `Future<void>` | Stop current recognition |
| `cancelRecognition()` | `Future<void>` | Cancel current recognition |
| `pause()` | `Future<void>` | Pause recognition |
| `resume()` | `Stream<String>` | Resume recognition |

#### State Properties

| Property | Type | Description |
|----------|------|-------------|
| `isInitialized` | `bool` | Whether SDK is initialized |
| `isStarted` | `bool` | Whether service is started |
| `isListening` | `bool` | Whether currently recognizing |
| `state` | `AsrSdkState` | Current SDK state |
| `duration` | `int` | Recording duration in seconds |
| `stateStream` | `Stream<AsrSdkState>` | Stream of state changes |

#### Configuration Methods

| Method | Description |
|--------|-------------|
| `setLogger(AsrLogger logger)` | Set custom logger |

### AsrSdkState - SDK States

| State | Description |
|-------|-------------|
| `notInitialized` | SDK not initialized |
| `initializing` | SDK is initializing |
| `ready` | SDK is ready |
| `started` | Service started |
| `error` | Error occurred |

### AsrLogger - Logging Interface

```dart
abstract class AsrLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message);
}
```

Use `DefaultAsrLogger` for console logging or implement your own logger.

## Model Management

### Model Types

| Type | Description | Size | Use Case |
|------|-------------|------|----------|
| Streaming Bilingual | Chinese-English | ~30MB | Mixed language recognition |
| Base Model | Chinese only | ~15MB | Pure Chinese recognition |
| Advanced Model | Higher quality | ~50MB | Better accuracy |

### Model Operations

```dart
final manager = SherpaModelsManager.instance;

// Initialize manager
await manager.initialize();

// Check if model exists
final hasModel = await manager.hasStreamingBilingualModel();

// Get available model path
final modelPath = await manager.getBestModelPath();

// Download model
await manager.downloadStreamingBilingualModels(
  onProgress: (progress) => print('Download: ${(progress * 100).toInt()}%'),
  onStatusChange: (status) => print('Status: $status'),
);
```

### Model Storage

Models are stored in the app's document directory:
- **iOS**: `NSDocumentDirectory/sherpa_models/`
- **Android**: `files/sherpa_models/`

## Configuration

### Audio Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Sample Rate | 16000 Hz | Required by Sherpa-Onnx |
| Channels | 1 | Mono audio |
| Audio Chunk | 100 ms | Real-time processing |
| Bit Rate | 128 kbps | Audio quality |

### Recognition Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Num Threads | 2 | Processing threads |
| Max Duration | 60 seconds | Maximum recognition duration |
| Min Duration | 1 second | Minimum recognition duration |

## Platform Support

| Platform | Support | Notes |
|----------|---------|-------|
| iOS | ✅ | iOS 11.0+ |
| Android | ✅ | Android 5.0+ (API 21+) |
| Web | ❌ | Not supported |
| macOS | ❌ | Not supported |
| Windows | ❌ | Not supported |
| Linux | ❌ | Not supported |

## Performance

- **Latency**: < 100ms for real-time streaming
- **Memory**: ~50-100MB depending on model
- **CPU**: Optimized for mobile devices
- **Battery**: Efficient power usage
- **Offline**: Fully offline, no network required

## Troubleshooting

### Common Issues

#### 1. Initialization Fails

**Symptoms**: `initialize()` returns `false`

**Solutions**:
- Check microphone permission
- Ensure sufficient storage space (~100MB)
- Check internet connection for first-time model download
- Review logs using `AsrSdk.setLogger(DefaultAsrLogger())`

#### 2. No Audio Input

**Symptoms**: No recognition results

**Solutions**:
- Verify microphone permission is granted
- Check if another app is using the microphone
- Test with another audio recording app

#### 3. Poor Recognition Quality

**Symptoms**: Inaccurate or missing words

**Solutions**:
- Speak clearly and close to microphone
- Reduce background noise
- Try bilingual model for mixed language
- Ensure proper audio input

#### 4. App Crashes

**Symptoms**: App crashes during recognition

**Solutions**:
- Check available memory
- Ensure proper lifecycle management (call `stop()` when leaving page)
- Review crash logs

### Debug Mode

Enable detailed logging:

```dart
AsrSdk.setLogger(DefaultAsrLogger());
```

Monitor state changes:

```dart
AsrSdk.stateStream.listen((state) {
  print('State changed to: $state');
});
```

## Examples

See the `/example` directory for complete examples:

- **Basic Usage**: Simple speech recognition
- **State Management**: Integration with Provider/Riverpod
- **Custom Logger**: Implement custom logging
- **Model Management**: Download and switch models

## Architecture

```
sherpa_asr_sdk/
├── lib/
│   ├── sherpa_asr_sdk.dart          # Main export
│   └── src/
│       ├── asr_sdk.dart              # SDK main class
│       ├── asr_service.dart          # Recognition service
│       ├── asr_recorder.dart         # Audio recorder
│       ├── asr_config.dart           # Configuration
│       ├── asr_state.dart            # State definitions
│       ├── asr_callbacks.dart        # Callback interfaces
│       ├── model/
│       │   └── sherpa_models_manager.dart
│       └── utils/
│           ├── asr_logger.dart       # Logging utilities
│           └── audio_converter.dart  # Audio processing
└── example/                          # Example app
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

1. Clone the repository
2. Run `flutter pub get`
3. Run tests: `flutter test`
4. Check formatting: `dart format .`
5. Analyze code: `flutter analyze`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Sherpa-Onnx](https://github.com/k2-fsa/sherpa-onnx) - The speech recognition engine
- [k2-fsa](https://github.com/k2-fsa) - For the pre-trained models
- [Flutter](https://flutter.dev) - The UI framework

## Support

If you encounter any issues or have questions:

1. Check the [FAQ](https://github.com/xyhuangjia/sherpa_asr_sdk/wiki/FAQ)
2. Search [existing issues](https://github.com/xyhuangjia/sherpa_asr_sdk/issues)
3. Create a [new issue](https://github.com/xyhuangjia/sherpa_asr_sdk/issues/new)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Roadmap

- [ ] Support for more languages
- [ ] Wake word detection
- [ ] Speaker identification
- [ ] Noise reduction
- [ ] Platform optimization


