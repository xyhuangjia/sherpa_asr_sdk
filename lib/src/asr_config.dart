/// ASR 配置类
/// 定义 Sherpa-onnx 语音识别相关的配置参数
class AsrConfig {
  AsrConfig._();

  // ==================== 模型配置 ====================

  /// 新基础模型版本（CTC int8 量化模型）
  static const String baseModelVersionCtc =
      'sherpa-onnx-zipformer-ctc-zh-int8-2025-07-03';

  /// 旧基础模型版本（保留作为备选）
  static const String baseModelVersionTransducer =
      'sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23';

  /// 基础模型版本（当前使用）
  static const String baseModelVersion = baseModelVersionCtc;

  /// 高级模型版本
  static const String advancedModelVersion =
      'sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16';

  /// 流式中英模型版本
  static const String streamingBilingualModelVersion =
      'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20';

  /// 默认使用的模型版本
  static const String defaultModelVersion = baseModelVersion;

  // ==================== 音频参数 ====================

  /// 目标采样率（Sherpa-onnx 要求 16kHz）
  static const int targetSampleRate = 16000;

  /// 当前录音采样率
  static const int currentSampleRate = 8000;

  /// 声道数（单声道）
  static const int numChannels = 1;

  /// 比特率
  static const int bitRate = 128000;

  // ==================== 识别参数 ====================

  /// 使用的线程数
  static const int numThreads = 2;

  /// VAD 阈值
  static const double vadThreshold = 0.5;

  /// VAD 窗口大小
  static const int vadWindowSize = 512;

  /// VAD 最小语音长度（毫秒）
  static const int vadMinSpeechDuration = 500;

  /// VAD 最大静音长度（毫秒）
  static const int vadMaxSilenceDuration = 2000;

  // ==================== 模型下载配置 ====================

  /// 模型下载基础 URL
  static const String modelBaseUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models';

  /// 主模型压缩包 URL
  static const String modelArchiveUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-zipformer-ctc-zh-int8-2025-07-03.tar.bz2';

  /// VAD 模型下载 URL
  static const String vadModelUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/vad-models/'
      'silero_vad.onnx';

  /// 流式中英模型压缩包 URL
  static const String streamingBilingualModelArchiveUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2';

  /// 模型文件列表（新 CTC 基础模型）
  static const List<String> baseModelFilesCtc = [
    'model.int8.onnx',
    'tokens.txt',
    'bbpe.model',
    'silero_vad.onnx',
  ];

  /// 模型文件列表（基础模型）
  static const List<String> baseModelFiles = baseModelFilesCtc;

  /// 模型文件列表（高级模型）
  static const List<String> advancedModelFiles = [
    'encoder-epoch-99-avg-1.onnx',
    'decoder-epoch-99-avg-1.onnx',
    'joiner-epoch-99-avg-1.onnx',
    'tokens.txt',
    'lang.txt',
  ];

  /// 流式中英模型文件列表
  static const List<String> streamingBilingualModelFiles = [
    'encoder-epoch-99-avg-1.int8.onnx',
    'decoder-epoch-99-avg-1.onnx',
    'joiner-epoch-99-avg-1.onnx',
    'tokens.txt',
  ];

  // ==================== 路径配置 ====================

  /// 模型存储目录名称
  static const String modelsDirName = 'sherpa_models';

  /// 基础模型目录名称
  static const String baseModelDirName = 'base_model';

  /// 高级模型目录名称
  static const String advancedModelDirName = 'advanced_model';

  /// 流式中英模型目录名称
  static const String streamingBilingualModelDirName =
      'streaming_bilingual_model';

  /// VAD 模型目录名称
  static const String vadModelDirName = 'vad_model';

  /// 说话人识别模型目录名称
  static const String speakerReidModelDirName = 'speaker_reid_model';

  /// Speaker ReID 模型版本
  static const String speakerReidModelVersion =
      'sherpa-onnx-3dspeaker-speech-eres2net-base-26k';

  /// Speaker ReID 模型文件列表
  static const List<String> speakerReidModelFiles = [
    'model.onnx',
  ];

  /// Speaker ReID 模型压缩包 URL
  static const String speakerReidModelArchiveUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-3dspeaker-speech-eres2net-base-26k-2024-01-17.tar.bz2';

  /// 预置模型 assets 路径
  static const String assetsModelPath =
      'packages/sherpa_asr_sdk/assets/models/sherpa-onnx/base';

  // ==================== 性能配置 ====================

  /// 音频分块大小（毫秒）
  static const int audioChunkDuration = 100;

  /// 每块音频采样数
  static int get samplesPerChunk =>
      (targetSampleRate * audioChunkDuration) ~/ 1000;

  /// 最大识别时长（秒）
  static const int maxRecognitionDuration = 60;

  /// 最小识别时长（秒）
  static const int minRecognitionDuration = 1;

  // ==================== 降级配置 ====================

  /// 是否启用在线 ASR 降级
  static const bool enableOnlineFallback = false;

  /// 降级超时时间（秒）
  static const int fallbackTimeout = 5;

  // ==================== 辅助方法 ====================

  /// 获取基础模型下载 URL
  static String getBaseModelUrl(String fileName) {
    return '$modelBaseUrl/$baseModelVersion/$fileName';
  }

  /// 获取高级模型下载 URL
  static String getAdvancedModelUrl(String fileName) {
    return '$modelBaseUrl/$advancedModelVersion/$fileName';
  }

  /// 获取流式中英模型下载 URL
  static String getStreamingBilingualModelUrl(String fileName) {
    return '$modelBaseUrl/$streamingBilingualModelVersion/$fileName';
  }

  /// 检测模型类型
  static String detectModelType(List<String> existingFiles) {
    if (existingFiles.contains('model.int8.onnx')) {
      return 'ctc';
    }
    if (existingFiles.contains('encoder-epoch-99-avg-1.int8.onnx')) {
      return 'streaming_transducer';
    }
    if (existingFiles.contains('encoder-epoch-20-avg-1.onnx')) {
      return 'transducer';
    }
    return 'unknown';
  }

  /// 根据设备性能计算线程数
  static int calculateOptimalThreads(int cpuCores) {
    return (cpuCores / 2).clamp(1, 4).toInt();
  }
}
