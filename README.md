# Sherpa ASR SDK

Offline speech recognition SDK for Flutter using Sherpa-onnx. Supports real-time streaming ASR with built-in Chinese model.

## Features

- 🎤 **Offline Recognition** - No internet required, powered by Sherpa-onnx
- 🔄 **Real-time Streaming** - Get results as you speak
- 📦 **Built-in Model** - Chinese small model included (~15MB)
- 🔧 **Model Management** - Download and switch between models
- 📱 **Cross Platform** - iOS and Android support

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  sherpa_asr_sdk: ^1.0.0
```

## Quick Start

### 1. Initialize (App Startup)

```dart
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

// Optional: Set custom logger
AsrSdk.setLogger(DefaultAsrLogger());

// Initialize the SDK
final success = await AsrSdk.initialize(
  onProgress: (progress) {
    print('Loading: ${(progress * 100).toInt()}%');
  },
  onStatus: (status) {
    print('Status: $status');
  },
);

if (!success) {
  print('Failed to initialize ASR SDK');
}
```

### 2. Start Service (Enter Page)

```dart
@override
void initState() {
  super.initState();
  AsrSdk.start();
}
```

### 3. Recognize Speech

```dart
void startListening() {
  AsrSdk.recognize().listen(
    (text) {
      print('Recognized: $text');
      // Update UI with partial results
    },
    onError: (error) {
      print('Error: $error');
    },
    onDone: () {
      print('Recognition completed');
    },
  );
}

void stopListening() async {
  await AsrSdk.stopRecognition();
}
```

### 4. Cleanup (Leave Page)

```dart
@override
void dispose() {
  AsrSdk.stop();
  super.dispose();
}
```

### 5. Dispose (App Exit)

```dart
await AsrSdk.dispose();
```

## API Reference

### AsrSdk

Main SDK class with static methods.

#### Lifecycle Methods

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize the SDK (call once at app startup) |
| `start()` | Start the service (create recorder) |
| `stop()` | Stop the service (destroy recorder) |
| `dispose()` | Release all resources |

#### Recognition Methods

| Method | Description |
|--------|-------------|
| `recognize()` | Start recognition, returns `Stream<String>` |
| `stopRecognition()` | Stop current recognition |
| `cancelRecognition()` | Cancel current recognition |
| `pause()` | Pause recognition (same as stopRecognition) |
| `resume()` | Resume recognition (same as recognize) |

#### State Properties

| Property | Description |
|----------|-------------|
| `isInitialized` | Whether SDK is initialized |
| `isStarted` | Whether service is started |
| `isListening` | Whether recognition is in progress |
| `state` | Current SDK state |
| `stateStream` | Stream of state changes |
| `duration` | Recording duration in seconds |

### AsrSdkState

| State | Description |
|-------|-------------|
| `notInitialized` | SDK not initialized |
| `initializing` | SDK is initializing |
| `ready` | SDK is ready (model loaded) |
| `started` | Service started (recorder created) |
| `error` | Error state |

### Model Management

```dart
final manager = SherpaModelsManager.instance;

// Check available models
final hasBase = await manager.hasBaseModel();
final hasAdvanced = await manager.hasStreamingBilingualModel();

// Download models
await manager.downloadStreamingBilingualModels(
  onProgress: (p) => print('Download: ${(p * 100).toInt()}%'),
);

// Get model path
final path = await manager.getBestModelPath();
```

## Model Types

| Type | Description | Size |
|------|-------------|------|
| Base | Chinese small model | ~15MB |
| Streaming Bilingual | Chinese-English model | ~30MB |
| Advanced | Higher quality bilingual | ~50MB |

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
```

## Example

See the `example/` directory for a complete sample app.

## License

MIT License