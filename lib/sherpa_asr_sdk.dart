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
///
/// // Stop recognition
/// await AsrSdk.stopRecognition();
///
/// // Stop service (when leaving the page)
/// await AsrSdk.stop();
///
/// // Dispose (when app exits)
/// await AsrSdk.dispose();
/// ```
library sherpa_asr_sdk;

export 'src/asr_sdk.dart';
export 'src/asr_state.dart';
export 'src/asr_config.dart';
export 'src/asr_callbacks.dart';
export 'src/utils/asr_logger.dart';
export 'src/model/sherpa_models_manager.dart';
