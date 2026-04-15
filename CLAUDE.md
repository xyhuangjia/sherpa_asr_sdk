# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands

```bash
flutter pub get                    # Install dependencies
flutter test                       # Run all tests
flutter test test/sherpa_asr_sdk_test.dart  # Run single test file
flutter analyze                    # Static analysis
dart format . --set-exit-if-changed  # Format check
```

## Architecture Overview

This is a Flutter SDK for offline speech recognition using Sherpa-Onnx. The architecture follows a layered pattern:

**SDK Layer (`AsrSdk`)** - Global singleton providing the public API. Manages lifecycle states and coordinates between components.

**Service Layer (`AsrService`)** - Singleton that wraps Sherpa-Onnx recognizer. Handles model initialization, streaming recognition, and result processing.

**Recorder Layer (`AsrRecorder`)** - Manages audio capture via `record` package, converts PCM16 to Float32, and feeds to AsrService.

**Model Management (`SherpaModelsManager`)** - Singleton handling model download, storage, and validation. Models stored in app document directory under `sherpa_models/`.

### Lifecycle Workflow

The SDK requires strict lifecycle ordering:

```
initialize() → start() → recognize() ⟲ stopRecognition() → stop() → dispose()
    ↑              ↑           ↑                ↑            ↑         ↑
  app startup   enter page   begin speech    end speech   leave page  app exit
```

Each method must be called in order. `recognize()` returns a `Stream<String>` that emits partial and final results.

### Model Types

- **Streaming Bilingual** (preferred): Chinese-English, ~30MB, files: `encoder-epoch-99-avg-1.int8.onnx`, `decoder-epoch-99-avg-1.onnx`, `joiner-epoch-99-avg-1.onnx`, `tokens.txt`
- **Base CTC Model**: Chinese only, ~15MB, files: `model.int8.onnx`, `tokens.txt`, `bbpe.model`, `silero_vad.onnx`
- **Advanced Model**: Higher quality bilingual, ~50MB

Models can be bundled in `assets/models/sherpa-onnx/base/` for offline-first deployment, or downloaded on first use via `SherpaModelsManager.downloadStreamingBilingualModels()`.

### Audio Parameters

Sherpa-Onnx requires 16kHz mono audio. The `record` package captures PCM16 which is converted to Float32 via `AudioConverter.convertBytesToFloat32()`.

## Key Files

- `lib/src/asr_sdk.dart` - Public API and lifecycle management
- `lib/src/asr_service.dart` - Sherpa-Onnx integration
- `lib/src/asr_recorder.dart` - Audio capture and streaming
- `lib/src/model/sherpa_models_manager.dart` - Model download/storage
- `lib/src/asr_config.dart` - Constants and configuration

## Platform Requirements

- **iOS**: Add `NSMicrophoneUsageDescription` to Info.plist
- **Android**: Add `RECORD_AUDIO` and `INTERNET` permissions to AndroidManifest.xml

## Notes

- Comments and logs are in Chinese throughout the codebase
- Uses singleton pattern for `AsrService` and `SherpaModelsManager`
- Model files are large; downloads use Dio with 10-minute timeout
- `AsrLogger` interface allows custom logging implementations

## Approach
- Think before acting. Read existing files before writing code.
- Be concise in output but thorough in reasoning.
- Prefer editing over rewriting whole files.
- Do not re-read files you have already read unless the file may have changed.
- Test your code before declaring done.
- No sycophantic openers or closing fluff.
- Keep solutions simple and direct.
- User instructions always override this file.