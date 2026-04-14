// example/lib/database/app_database.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite 数据库管理
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  static Database? _database;

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sherpa_history.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// 创建表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recognition_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        audioPath TEXT NOT NULL,
        duration INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        isFavorite INTEGER DEFAULT 0,
        tags TEXT
      )
    ''');

    // 创建索引
    await db.execute(
        'CREATE INDEX idx_timestamp ON recognition_records(timestamp)');
    await db.execute(
        'CREATE INDEX idx_favorite ON recognition_records(isFavorite)');
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}