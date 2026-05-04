# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands

```bash
flutter pub get                    # Install dependencies
flutter test                       # Run all tests (15 tests)
flutter test test/asr_result_test.dart  # Run single test file
flutter analyze                    # Static analysis
dart format . --set-exit-if-changed  # Format check
bash scripts/download_model.sh     # Download streaming bilingual model to assets/
```

Requires Dart SDK `^3.10.1` and Flutter `>=3.10.0`.

## Architecture Overview

Flutter SDK for offline speech recognition using Sherpa-Onnx. Static facade pattern with manager delegation:

```
AsrSdk (static facade, public API)
  → AsrService (singleton, Sherpa-onnx wrapper)
    → AsrVadManager (speech segment detection)
    → AsrSpeakerManager (speaker registration/embedding)
    → AsrDiarizationManager (multi-speaker clustering, shares SpeakerManager's extractor)
  → AsrRecorder (audio capture via `record` package, mutable callbacks)
  → SherpaModelsManager (singleton, model download/storage)
```

### Lifecycle (must follow order)

```
initialize() → start() → recognize()/recognizeWithTimestamps() ⟲ stopRecognition() → stop() → dispose()
```

`recognize()` returns `Stream<String>`, `recognizeWithTimestamps()` returns `Stream<AsrResult>`. Breaking lifecycle order causes state errors.

### Modules

- **Core** (`lib/src/`): `asr_sdk.dart` (static facade), `asr_service.dart` (singleton coordinator, lazy-inits managers), `asr_recorder.dart` (audio capture, mutable callbacks via `updateCallbacks()`), `asr_state.dart`, `asr_config.dart`, `asr_result.dart`
- **VAD** (`lib/src/vad/`): `asr_vad_manager.dart` (Silero VAD lifecycle, drives diarization segments), `asr_vad_config.dart`, `asr_vad_state.dart`
- **Speaker** (`lib/src/speaker/`): `asr_speaker_manager.dart` (registration/embedding/verification, owns SpeakerEmbeddingExtractor), `asr_diarization_manager.dart` (auto-clustering via cosine similarity, shares extractor from SpeakerManager), `asr_diarizer.dart` (pure-logic clustering), `asr_speaker_config.dart`, `speaker_data_storage.dart` (file-based JSON persistence)
- **Model** (`lib/src/model/`): `sherpa_models_manager.dart` — download (Dio + tar.bz2), validation, asset copying. Stores under app doc dir `sherpa_models/`
- **Utils** (`lib/src/utils/`): `audio_converter.dart` (PCM16→Float32, resample, energy), `asr_logger.dart` (pluggable interface + DefaultAsrLogger)

### Key Patterns

- **Singletons**: `AsrService`, `SherpaModelsManager`, `AsrSdk` (static class)
- **Lazy manager init**: `AsrService._ensureManagers()` creates VAD/Speaker/Diarization managers on first use
- **Shared extractor**: `AsrDiarizationManager` accesses `AsrSpeakerManager.extractor` — they share the same native SpeakerEmbeddingExtractor instance
- **Mutable callbacks**: `AsrRecorder.updateCallbacks()` swaps callbacks without recreating the recorder. Used by `recognize()` vs `recognizeWithTimestamps()`
- **Hot path**: Audio flows as `Float32List` throughout — `AudioConverter.convertBytesToFloat32()` → `AsrService.acceptAudio(Float32List)` → VAD/ASR processing. No `List<double>` intermediate copies

### Model Types

- **Streaming Bilingual** (preferred): Chinese-English, ~30MB. Files: `encoder-epoch-99-avg-1.int8.onnx`, `decoder-epoch-99-avg-1.onnx`, `joiner-epoch-99-avg-1.onnx`, `tokens.txt`
- **Base CTC**: Chinese only, ~15MB. Files: `model.int8.onnx`, `tokens.txt`, `bbpe.model`, `silero_vad.onnx`
- **Advanced**: Higher quality bilingual, ~50MB

Can bundle in `assets/models/sherpa-onnx/base/` for offline-first, or download via `SherpaModelsManager.downloadStreamingBilingualModels()`.

## Platform Requirements

- **iOS**: `NSMicrophoneUsageDescription` in Info.plist
- **Android**: `RECORD_AUDIO` + `INTERNET` in AndroidManifest.xml

## Notes

- Comments/logs in Chinese throughout codebase
- Model downloads use Dio with 10-minute timeout
- `AsrLogger` interface for custom logging
- All public types exported via `lib/sherpa_asr_sdk.dart`
- Example app in `example/` demonstrates single-speaker ASR, multi-speaker meeting with diarization, history storage, audio playback

## Approach

- Think before acting. Read existing files before writing code.
- Prefer editing over rewriting whole files.
- Test your code before declaring done.
- Keep solutions simple and direct.
- User instructions always override this file.
