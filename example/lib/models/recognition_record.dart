// example/lib/models/recognition_record.dart

/// 识别记录数据模型
class RecognitionRecord {
  final int? id;
  final String text;
  final String audioPath;
  final int duration;
  final DateTime timestamp;
  final bool isFavorite;
  final List<String>? tags;

  RecognitionRecord({
    this.id,
    required this.text,
    required this.audioPath,
    required this.duration,
    required this.timestamp,
    this.isFavorite = false,
    this.tags,
  });

  /// 从数据库 Map 创建
  factory RecognitionRecord.fromMap(Map<String, dynamic> map) {
    return RecognitionRecord(
      id: map['id'] as int?,
      text: map['text'] as String,
      audioPath: map['audioPath'] as String,
      duration: map['duration'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      isFavorite: map['isFavorite'] == 1,
      tags: map['tags'] != null
          ? (map['tags'] as String).split(',').toList()
          : null,
    );
  }

  /// 转换为数据库 Map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'text': text,
      'audioPath': audioPath,
      'duration': duration,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isFavorite': isFavorite ? 1 : 0,
      'tags': tags?.join(','),
    };
  }

  /// 复制并修改
  RecognitionRecord copyWith({
    int? id,
    String? text,
    String? audioPath,
    int? duration,
    DateTime? timestamp,
    bool? isFavorite,
    List<String>? tags,
  }) {
    return RecognitionRecord(
      id: id ?? this.id,
      text: text ?? this.text,
      audioPath: audioPath ?? this.audioPath,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }

  /// 格式化时长为 MM:SS
  String formattedDuration() {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化时间戳为 HH:MM
  String formattedTime() {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}