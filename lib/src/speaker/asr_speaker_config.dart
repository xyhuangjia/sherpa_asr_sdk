/// Speaker ID (说话人识别) 配置类
///
/// 用于配置说话人识别的参数
class AsrSpeakerConfig {
  /// 是否启用说话人识别
  final bool enabled;

  /// 说话人识别模型路径
  final String reidModelPath;

  /// 验证阈值 (0.0-1.0)
  /// 较高的阈值使验证更严格，较低的阈值更宽松
  final double verificationThreshold;

  /// 最大注册说话人数
  final int maxSpeakers;

  /// 注册所需的最小时长（秒）
  final int minRegistrationDuration;

  const AsrSpeakerConfig({
    this.enabled = false,
    this.reidModelPath = '',
    this.verificationThreshold = 0.7,
    this.maxSpeakers = 100,
    this.minRegistrationDuration = 3,
  });

  /// 从 JSON 创建配置
  factory AsrSpeakerConfig.fromJson(Map<String, dynamic> json) {
    return AsrSpeakerConfig(
      enabled: json['enabled'] as bool? ?? false,
      reidModelPath: json['reidModelPath'] as String? ?? '',
      verificationThreshold:
          (json['verificationThreshold'] as num?)?.toDouble() ?? 0.7,
      maxSpeakers: json['maxSpeakers'] as int? ?? 100,
      minRegistrationDuration:
          json['minRegistrationDuration'] as int? ?? 3,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'reidModelPath': reidModelPath,
        'verificationThreshold': verificationThreshold,
        'maxSpeakers': maxSpeakers,
        'minRegistrationDuration': minRegistrationDuration,
      };

  /// 复制并修改配置
  AsrSpeakerConfig copyWith({
    bool? enabled,
    String? reidModelPath,
    double? verificationThreshold,
    int? maxSpeakers,
    int? minRegistrationDuration,
  }) {
    return AsrSpeakerConfig(
      enabled: enabled ?? this.enabled,
      reidModelPath: reidModelPath ?? this.reidModelPath,
      verificationThreshold:
          verificationThreshold ?? this.verificationThreshold,
      maxSpeakers: maxSpeakers ?? this.maxSpeakers,
      minRegistrationDuration:
          minRegistrationDuration ?? this.minRegistrationDuration,
    );
  }

  @override
  String toString() {
    return 'AsrSpeakerConfig(enabled: $enabled, reidModelPath: $reidModelPath, '
        'verificationThreshold: $verificationThreshold, '
        'maxSpeakers: $maxSpeakers, '
        'minRegistrationDuration: $minRegistrationDuration)';
  }
}
