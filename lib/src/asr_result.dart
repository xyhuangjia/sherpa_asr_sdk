/// 单个 token 的时间戳信息
class AsrTimestamp {
  /// token 文本
  final String token;

  /// 起始时间（秒）
  final double startTime;

  /// 持续时间（秒），最后一个 token 为 0.0
  final double duration;

  const AsrTimestamp({
    required this.token,
    required this.startTime,
    required this.duration,
  });

  @override
  String toString() => 'AsrTimestamp($token, ${startTime.toStringAsFixed(2)}s, ${duration.toStringAsFixed(2)}s)';

  /// 从 sherpa_onnx 的 tokens 和 timestamps 列表构建 AsrTimestamp 列表
  ///
  /// [tokens] token 文本列表
  /// [timestamps] 每个 token 的起始时间列表（秒）
  ///
  /// 持续时间通过相邻时间差计算，最后一个 token 的 duration 为 0.0
  static List<AsrTimestamp> fromTokensAndTimestamps(
    List<String> tokens,
    List<double> timestamps,
  ) {
    if (tokens.isEmpty || timestamps.isEmpty) {
      return const [];
    }

    final result = <AsrTimestamp>[];
    final len = tokens.length;

    for (int i = 0; i < len; i++) {
      final double start;
      final double dur;

      if (i < timestamps.length) {
        start = timestamps[i];
      } else {
        // tokens 多于 timestamps 时，使用最后一个时间戳
        start = timestamps.last;
      }

      if (i + 1 < timestamps.length) {
        dur = timestamps[i + 1] - start;
      } else {
        dur = 0.0;
      }

      result.add(AsrTimestamp(
        token: tokens[i],
        startTime: start,
        duration: dur,
      ));
    }

    return result;
  }
}

/// 语音识别结果，包含文本和时间戳信息
class AsrResult {
  /// 完整识别文本
  final String text;

  /// token 级时间戳列表
  final List<AsrTimestamp> timestamps;

  /// 是否为最终结果（端点检测后为 true）
  final bool isFinal;

  /// 说话人标签（多人场景，如 "Speaker 1"）
  /// 为 null 表示未启用说话人聚类
  final String? speakerLabel;

  /// 语音段在录音中的起始时间（秒）
  /// 多人场景下表示这段话什么时候开始
  final double segmentStart;

  /// 语音段在录音中的结束时间（秒）
  /// 多人场景下表示这段话什么时候结束
  final double segmentEnd;

  const AsrResult({
    required this.text,
    required this.timestamps,
    required this.isFinal,
    this.speakerLabel,
    this.segmentStart = 0.0,
    this.segmentEnd = 0.0,
  });

  /// 带说话人标签和时间戳的显示文本
  /// 格式: "[Speaker 1] 你好 (00:15)"
  String get labeledText {
    final speaker = speakerLabel != null ? '[$speakerLabel] ' : '';
    final timeStr = segmentStart > 0 ? ' (${_formatTime(segmentStart)})' : '';
    return '$speaker$text$timeStr';
  }

  static String _formatTime(double seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds.truncate() % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  String toString() {
    final parts = [
      'text: $text',
      'timestamps: ${timestamps.length}',
      'isFinal: $isFinal',
      if (speakerLabel != null) 'speaker: $speakerLabel',
      if (segmentStart > 0) 'segment: ${_formatTime(segmentStart)}-${_formatTime(segmentEnd)}',
    ];
    return 'AsrResult(${parts.join(', ')})';
  }
}
