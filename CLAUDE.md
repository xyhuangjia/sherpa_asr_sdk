# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands

```bash
flutter pub get                    # Install dependencies
flutter test                       # Run all tests
flutter test test/asr_result_test.dart  # Run single test file
flutter analyze                    # Static analysis
dart format . --set-exit-if-changed  # Format check
bash scripts/download_model.sh     # Download streaming bilingual model to assets/
```

Requires Dart SDK `^3.10.1` and Flutter `>=3.10.0`.

## Architecture Overview

Flutter SDK for offline speech recognition using Sherpa-Onnx. Layered architecture with strict lifecycle ordering:

**AsrSdk** (public API singleton) → **AsrService** (Sherpa-Onnx wrapper) → **AsrRecorder** (audio capture via `record` package). `SherpaModelsManager` handles model download/storage independently.

### Lifecycle (must follow order)

```
initialize() → start() → recognize() ⟲ stopRecognition() → stop() → dispose()
```

`recognize()` returns `Stream<String>` emitting partial and final results. Breaking lifecycle order causes state errors.

### Modules

- **Core** (`lib/src/`): `asr_sdk.dart`, `asr_service.dart`, `asr_recorder.dart`, `asr_state.dart`, `asr_config.dart`, `asr_callbacks.dart`, `asr_result.dart`
- **VAD** (`lib/src/vad/`): Voice activity detection config and state — `asr_vad_config.dart`, `asr_vad_state.dart`
- **Speaker** (`lib/src/speaker/`): Multi-speaker diarization — `asr_diarizer.dart`, `asr_speaker_config.dart`, `speaker_data_storage.dart`
- **Model** (`lib/src/model/`): `sherpa_models_manager.dart` — download, storage, validation under app doc dir `sherpa_models/`
- **Utils** (`lib/src/utils/`): `audio_converter.dart` (PCM16→Float32), `asr_logger.dart` (pluggable logging interface)

### Model Types

- **Streaming Bilingual** (preferred): Chinese-English, ~30MB. Files: `encoder-epoch-99-avg-1.int8.onnx`, `decoder-epoch-99-avg-1.onnx`, `joiner-epoch-99-avg-1.onnx`, `tokens.txt`
- **Base CTC**: Chinese only, ~15MB. Files: `model.int8.onnx`, `tokens.txt`, `bbpe.model`, `silero_vad.onnx`
- **Advanced**: Higher quality bilingual, ~50MB

Can bundle in `assets/models/sherpa-onnx/base/` for offline-first, or download via `SherpaModelsManager.downloadStreamingBilingualModels()`.

### Audio

Sherpa-Onnx requires 16kHz mono. `record` captures PCM16 → `AudioConverter.convertBytesToFloat32()` converts to Float32.

## Platform Requirements

- **iOS**: `NSMicrophoneUsageDescription` in Info.plist
- **Android**: `RECORD_AUDIO` + `INTERNET` in AndroidManifest.xml

## Notes

- Comments/logs in Chinese throughout codebase
- Singleton pattern: `AsrService`, `SherpaModelsManager`
- Model downloads use Dio with 10-minute timeout
- `AsrLogger` interface for custom logging
- All public types exported via `lib/sherpa_asr_sdk.dart`
- Example app in `example/` includes multi-speaker meeting page, history storage, audio player

## Approach

- Think before acting. Read existing files before writing code.
- Prefer editing over rewriting whole files.
- Test your code before declaring done.
- Keep solutions simple and direct.
- User instructions always override this file.