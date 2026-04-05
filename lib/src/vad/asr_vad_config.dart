/// VAD (Voice Activity Detection) 配置类
///
/// 用于配置语音活动检测的参数
class AsrVadConfig {
  /// 是否启用 VAD
  final bool enabled;

  /// VAD 阈值 (0.0-1.0)
  /// 较高的阈值会使检测更严格，较低的阈值更敏感
  final double threshold;

  /// 最小静音时长（秒）
  /// 低于此时长的静音不会触发语音结束
  final double minSilenceDuration;

  /// 最小语音时长（秒）
  /// 低于此时长的语音不会被识别
  final double minSpeechDuration;

  /// 最大语音时长（秒）
  /// 超过此时长后强制结束识别
  final double maxSpeechDuration;

  /// VAD 检测窗口大小（采样点数）
  final int windowSize;

  const AsrVadConfig({
    this.enabled = false,
    this.threshold = 0.5,
    this.minSilenceDuration = 0.5,
    this.minSpeechDuration = 0.25,
    this.maxSpeechDuration = 5.0,
    this.windowSize = 512,
  });

  /// 从 JSON 创建配置
  factory AsrVadConfig.fromJson(Map<String, dynamic> json) {
    return AsrVadConfig(
      enabled: json['enabled'] as bool? ?? false,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.5,
      minSilenceDuration:
          (json['minSilenceDuration'] as num?)?.toDouble() ?? 0.5,
      minSpeechDuration:
          (json['minSpeechDuration'] as num?)?.toDouble() ?? 0.25,
      maxSpeechDuration:
          (json['maxSpeechDuration'] as num?)?.toDouble() ?? 5.0,
      windowSize: json['windowSize'] as int? ?? 512,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'threshold': threshold,
        'minSilenceDuration': minSilenceDuration,
        'minSpeechDuration': minSpeechDuration,
        'maxSpeechDuration': maxSpeechDuration,
        'windowSize': windowSize,
      };

  /// 复制并修改配置
  AsrVadConfig copyWith({
    bool? enabled,
    double? threshold,
    double? minSilenceDuration,
    double? minSpeechDuration,
    double? maxSpeechDuration,
    int? windowSize,
  }) {
    return AsrVadConfig(
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
      minSilenceDuration: minSilenceDuration ?? this.minSilenceDuration,
      minSpeechDuration: minSpeechDuration ?? this.minSpeechDuration,
      maxSpeechDuration: maxSpeechDuration ?? this.maxSpeechDuration,
      windowSize: windowSize ?? this.windowSize,
    );
  }

  @override
  String toString() {
    return 'AsrVadConfig(enabled: $enabled, threshold: $threshold, '
        'minSilenceDuration: $minSilenceDuration, '
        'minSpeechDuration: $minSpeechDuration, '
        'maxSpeechDuration: $maxSpeechDuration, '
        'windowSize: $windowSize)';
  }
}
