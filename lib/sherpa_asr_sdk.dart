/// Flutter 离线语音识别 SDK，基于 Sherpa-onnx
///
/// 支持实时流式 ASR、VAD、说话人识别和多人对话分离。
///
/// ```dart
/// import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';
///
/// await AsrSdk.initialize();
/// await AsrSdk.start();
/// AsrSdk.recognize().listen((text) => print(text));
/// await AsrSdk.stopRecognition();
/// await AsrSdk.stop();
/// await AsrSdk.dispose();
/// ```
library;

// Core
export 'src/asr_sdk.dart';
export 'src/model/asr_result.dart';
export 'src/model/asr_state.dart';
export 'src/asr_config.dart';

// Utils
export 'src/utils/asr_logger.dart';
export 'src/utils/audio_converter.dart';

// Model
export 'src/utils/sherpa_models_manager.dart';

// VAD
export 'src/vad/asr_vad_config.dart';
export 'src/vad/asr_vad_state.dart';
export 'src/vad/asr_vad_manager.dart';

// Speaker & Diarization
export 'src/speaker/asr_speaker_config.dart';
export 'src/speaker/speaker_data_storage.dart';
export 'src/speaker/asr_diarizer.dart';
export 'src/speaker/asr_speaker_manager.dart';
export 'src/speaker/asr_diarization_manager.dart';
