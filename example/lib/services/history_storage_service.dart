// example/lib/services/history_storage_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/recognition_record.dart';
import '../models/search_filter.dart';

/// 历史记录存储服务
class HistoryStorageService {
  static final HistoryStorageService instance =
      HistoryStorageService._internal();
  HistoryStorageService._internal();

  late Directory _audioDir;

  /// 初始化服务
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _audioDir = Directory(p.join(appDir.path, 'audio_records'));
    if (!await _audioDir.exists()) {
      await _audioDir.create(recursive: true);
    }
  }

  /// 获取音频文件路径
  String getAudioPath(int id) {
    return p.join(_audioDir.path, '$id.wav');
  }

  /// 插入记录
  Future<int> insertRecord(RecognitionRecord record) async {
    final db = await AppDatabase.instance.database;
    return await db.insert('recognition_records', record.toMap());
  }

  /// 获取所有记录
  Future<List<RecognitionRecord>> getAllRecords({
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await AppDatabase.instance.database;
    final maps = await db.query(
      'recognition_records',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => RecognitionRecord.fromMap(m)).toList();
  }

  /// 搜索记录
  Future<List<RecognitionRecord>> search(SearchFilter filter) async {
    final db = await AppDatabase.instance.database;

    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (filter.keyword != null && filter.keyword!.isNotEmpty) {
      whereClause += 'text LIKE ?';
      whereArgs.add('%${filter.keyword}%');
    }

    if (filter.startDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp >= ?';
      whereArgs.add(filter.startDate!.millisecondsSinceEpoch);
    }

    if (filter.endDate != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'timestamp <= ?';
      whereArgs.add(filter.endDate!.millisecondsSinceEpoch);
    }

    if (filter.minDuration != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'duration >= ?';
      whereArgs.add(filter.minDuration);
    }

    if (filter.maxDuration != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'duration <= ?';
      whereArgs.add(filter.maxDuration);
    }

    if (filter.isFavorite != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'isFavorite = ?';
      whereArgs.add(filter.isFavorite! ? 1 : 0);
    }

    final maps = await db.query(
      'recognition_records',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: 100,
    );

    return maps.map((m) => RecognitionRecord.fromMap(m)).toList();
  }

  /// 更新收藏状态
  Future<void> updateFavorite(int id, bool isFavorite) async {
    final db = await AppDatabase.instance.database;
    await db.update(
      'recognition_records',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除记录（同时删除音频文件）
  Future<void> deleteRecord(int id) async {
    final db = await AppDatabase.instance.database;

    // 先获取记录以找到音频路径
    final maps = await db.query(
      'recognition_records',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final record = RecognitionRecord.fromMap(maps.first);
      final audioFile = File(record.audioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
    }

    // 删除数据库记录
    await db.delete(
      'recognition_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清空所有记录和音频文件
  Future<void> clearAll() async {
    final db = await AppDatabase.instance.database;
    await db.delete('recognition_records');

    // 删除所有音频文件
    if (await _audioDir.exists()) {
      await for (final file in _audioDir.list()) {
        if (file is File) {
          await file.delete();
        }
      }
    }
  }

  /// 获取记录总数
  Future<int> getCount() async {
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM recognition_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}