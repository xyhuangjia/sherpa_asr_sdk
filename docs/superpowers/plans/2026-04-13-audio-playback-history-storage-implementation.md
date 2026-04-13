# 音频回放与历史记录存储功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Sherpa ASR SDK Example App 添加音频回放、历史记录持久化和搜索过滤功能。

**Architecture:** 分层架构设计 - 服务层（AudioRecorder、AudioPlayer、HistoryStorage）+ 数据层（SQLite）+ UI层（Widgets）。使用单例模式管理服务，数据库事务保证原子性。

**Tech Stack:** Flutter, sqflite, just_audio, record, path_provider

---

## 文件结构

```
example/lib/
├── main.dart                        # 重构：集成所有服务和组件
├── models/
│   ├── recognition_record.dart      # 新建：识别记录数据模型
│   └── search_filter.dart           # 新建：搜索过滤器模型
├── services/
│   ├── audio_recorder_service.dart  # 新建：音频录制服务
│   ├── audio_player_service.dart    # 新建：音频播放服务
│   └── history_storage_service.dart # 新建：历史存储服务
├── database/
│   └── app_database.dart            # 新建：SQLite 初始化
├── widgets/
│   ├── audio_player_widget.dart     # 新建：播放器组件
│   ├── history_list_widget.dart     # 新建：历史列表组件
│   └── search_filter_widget.dart    # 新建：搜索过滤组件
└── utils/
    └── wav_writer.dart              # 新建：WAV 文件写入工具
```

---

## Task 1: 添加依赖

**Files:**
- Modify: `example/pubspec.yaml`

- [ ] **Step 1: 添加依赖到 pubspec.yaml**

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  sherpa_asr_sdk:
    path: ../
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  just_audio: ^0.9.36
  path: ^1.8.3
```

- [ ] **Step 2: 运行 flutter pub get**

Run: `cd example && flutter pub get`
Expected: 依赖安装成功

- [ ] **Step 3: 提交**

```bash
git add example/pubspec.yaml
git commit -m "feat: Add sqflite, just_audio, and path dependencies"
```

---

## Task 2: 创建 RecognitionRecord 数据模型

**Files:**
- Create: `example/lib/models/recognition_record.dart`

- [ ] **Step 1: 创建 RecognitionRecord 类**

```dart
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
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/models/recognition_record.dart
git commit -m "feat: Add RecognitionRecord data model"
```

---

## Task 3: 创建 SearchFilter 数据模型

**Files:**
- Create: `example/lib/models/search_filter.dart`

- [ ] **Step 1: 创建 SearchFilter 类**

```dart
// example/lib/models/search_filter.dart

/// 搜索过滤器模型
class SearchFilter {
  final String? keyword;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? minDuration;
  final int? maxDuration;
  final bool? isFavorite;

  const SearchFilter({
    this.keyword,
    this.startDate,
    this.endDate,
    this.minDuration,
    this.maxDuration,
    this.isFavorite,
  });

  /// 是否有任何过滤条件
  bool hasFilters() {
    return keyword != null ||
        startDate != null ||
        endDate != null ||
        minDuration != null ||
        maxDuration != null ||
        isFavorite != null;
  }

  /// 清空所有过滤条件
  const SearchFilter.empty() : keyword = null, startDate = null, endDate = null, minDuration = null, maxDuration = null, isFavorite = null;

  /// 复制并修改
  SearchFilter copyWith({
    String? keyword,
    DateTime? startDate,
    DateTime? endDate,
    int? minDuration,
    int? maxDuration,
    bool? isFavorite,
  }) {
    return SearchFilter(
      keyword: keyword ?? this.keyword,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/models/search_filter.dart
git commit -m "feat: Add SearchFilter data model"
```

---

## Task 4: 创建 WAV 文件写入工具

**Files:**
- Create: `example/lib/utils/wav_writer.dart`

- [ ] **Step 1: 创建 WavWriter 类**

```dart
// example/lib/utils/wav_writer.dart

import 'dart:io';
import 'dart:typed_data';

/// WAV 文件写入工具
class WavWriter {
  final File file;
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;

  IOSink? _sink;
  int _dataSize = 0;
  bool _isWriting = false;

  WavWriter({
    required String filePath,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitsPerSample = 16,
  }) : file = File(filePath);

  /// 开始写入 WAV 文件
  Future<void> start() async {
    if (_isWriting) return;
    
    _sink = file.openWrite();
    _isWriting = true;
    _dataSize = 0;

    // 写入 WAV header（44字节）
    // RIFF header
    _sink!.writeByte(0x52); // 'R'
    _sink!.writeByte(0x49); // 'I'
    _sink!.writeByte(0x46); // 'F'
    _sink!.writeByte(0x46); // 'F'
    
    // 文件大小（暂时写入0，最后更新）
    _writeUint32(0);
    
    // WAVE
    _sink!.writeByte(0x57); // 'W'
    _sink!.writeByte(0x41); // 'A'
    _sink!.writeByte(0x56); // 'V'
    _sink!.writeByte(0x45); // 'E'
    
    // fmt chunk
    _sink!.writeByte(0x66); // 'f'
    _sink!.writeByte(0x6D); // 'm'
    _sink!.writeByte(0x74); // 't'
    _sink!.writeByte(0x20); // ' '
    
    _writeUint32(16); // fmt chunk size
    _writeUint16(1);   // audio format (PCM)
    _writeUint16(numChannels);
    _writeUint32(sampleRate);
    _writeUint32(sampleRate * numChannels * bitsPerSample ~/ 8); // byte rate
    _writeUint16(numChannels * bitsPerSample ~/ 8); // block align
    _writeUint16(bitsPerSample);
    
    // data chunk
    _sink!.writeByte(0x64); // 'd'
    _sink!.writeByte(0x61); // 'a'
    _sink!.writeByte(0x74); // 't'
    _sink!.writeByte(0x61); // 'a'
    
    _writeUint32(0); // data size（暂时写入0，最后更新）
  }

  /// 写入 PCM16 音频数据
  void writePcm16(Uint8List pcmData) {
    if (!_isWriting || _sink == null) return;
    
    _sink!.add(pcmData);
    _dataSize += pcmData.length;
  }

  /// 结束写入并更新 header
  Future<void> stop() async {
    if (!_isWriting || _sink == null) return;
    
    await _sink!.flush();
    await _sink!.close();
    _isWriting = false;

    // 更新文件大小
    final fileSize = _dataSize + 44 - 8;
    final raf = await file.open(mode: FileMode.append);
    
    // 更新 RIFF chunk size (位置 4)
    await raf.setPosition(4);
    await raf.writeFrom(_uint32ToBytes(fileSize));
    
    // 更新 data chunk size (位置 40)
    await raf.setPosition(40);
    await raf.writeFrom(_uint32ToBytes(_dataSize));
    
    await raf.close();
  }

  /// 取消写入并删除文件
  Future<void> cancel() async {
    if (_isWriting) {
      await _sink!.flush();
      await _sink!.close();
      _isWriting = false;
    }
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _writeUint32(int value) {
    _sink!.add(_uint32ToBytes(value));
  }

  void _writeUint16(int value) {
    _sink!.add(_uint16ToBytes(value));
  }

  Uint8List _uint32ToBytes(int value) {
    return Uint8List(4)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF
      ..[2] = (value >> 16) & 0xFF
      ..[3] = (value >> 24) & 0xFF;
  }

  Uint8List _uint16ToBytes(int value) {
    return Uint8List(2)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF;
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/utils/wav_writer.dart
git commit -m "feat: Add WavWriter utility for recording WAV files"
```

---

## Task 5: 创建数据库初始化

**Files:**
- Create: `example/lib/database/app_database.dart`

- [ ] **Step 1: 创建 AppDatabase 类**

```dart
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
    await db.execute('CREATE INDEX idx_timestamp ON recognition_records(timestamp)');
    await db.execute('CREATE INDEX idx_favorite ON recognition_records(isFavorite)');
  }

  /// 关闭数据库
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/database/app_database.dart
git commit -m "feat: Add AppDatabase for SQLite initialization"
```

---

## Task 6: 创建 HistoryStorageService

**Files:**
- Create: `example/lib/services/history_storage_service.dart`

- [ ] **Step 1: 创建 HistoryStorageService 类**

```dart
// example/lib/services/history_storage_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../models/recognition_record.dart';
import '../models/search_filter.dart';

/// 历史记录存储服务
class HistoryStorageService {
  static final HistoryStorageService instance = HistoryStorageService._internal();
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
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM recognition_records');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/services/history_storage_service.dart
git commit -m "feat: Add HistoryStorageService for SQLite CRUD operations"
```

---

## Task 7: 创建 AudioPlayerService

**Files:**
- Create: `example/lib/services/audio_player_service.dart`

- [ ] **Step 1: 创建 AudioPlayerService 类**

```dart
// example/lib/services/audio_player_service.dart

import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// 播放状态
enum PlayerState {
  stopped,
  playing,
  paused,
  completed,
}

/// 音频播放服务
class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._internal();
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  
  final StreamController<PlayerState> _stateController = 
      StreamController<PlayerState>.broadcast();
  
  Stream<PlayerState> get playerStateStream => _stateController.stream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get durationStream => _player.durationStream;
  
  Duration get duration => _player.duration ?? Duration.zero;
  Duration get position => _player.position;
  PlayerState _state = PlayerState.stopped;

  /// 播放音频
  Future<void> play(String audioPath) async {
    try {
      await _player.setFilePath(audioPath);
      await _player.play();
      _updateState(PlayerState.playing);
      
      // 监听播放完成
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _updateState(PlayerState.completed);
        }
      });
    } catch (e) {
      _updateState(PlayerState.stopped);
      throw Exception('Failed to play audio: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    await _player.pause();
    _updateState(PlayerState.paused);
  }

  /// 继续播放
  Future<void> resume() async {
    await _player.play();
    _updateState(PlayerState.playing);
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
    _updateState(PlayerState.stopped);
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
  }

  void _updateState(PlayerState state) {
    _state = state;
    _stateController.add(state);
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/services/audio_player_service.dart
git commit -m "feat: Add AudioPlayerService using just_audio"
```

---

## Task 8: 创建 AudioRecorderService

**Files:**
- Create: `example/lib/services/audio_recorder_service.dart`

- [ ] **Step 1: 创建 AudioRecorderService 类**

```dart
// example/lib/services/audio_recorder_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

import '../utils/wav_writer.dart';

/// 音频录制服务
class AudioRecorderService {
  static final AudioRecorderService instance = AudioRecorderService._internal();
  AudioRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  WavWriter? _wavWriter;
  String? _tempFilePath;
  bool _isRecording = false;
  
  final StreamController<List<double>> _audioStreamController =
      StreamController<List<double>>.broadcast();
  
  Stream<List<double>> get audioStream => _audioStreamController.stream;
  bool get isRecording => _isRecording;

  /// 开始录制
  Future<String> startRecording() async {
    if (_isRecording) throw Exception('Already recording');
    
    // 检查权限
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw Exception('Microphone permission not granted');
    
    // 创建临时文件路径
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = p.join(appDir.path, 'audio_records');
    _tempFilePath = p.join(audioDir, 'temp_${DateTime.now().millisecondsSinceEpoch}.wav');
    
    // 初始化 WAV writer
    _wavWriter = WavWriter(filePath: _tempFilePath!);
    await _wavWriter!.start();
    
    // 启动录制流
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: 16000,
      numChannels: 1,
    );
    
    final stream = await _recorder.startStream(config);
    
    stream.listen((data) {
      // 写入 WAV 文件
      _wavWriter!.writePcm16(Uint8List.fromList(data));
      
      // 转换为 Float32 并发送给识别服务
      final float32 = _convertPcm16ToFloat32(Uint8List.fromList(data));
      _audioStreamController.add(float32.toList());
    });
    
    _isRecording = true;
    return _tempFilePath!;
  }

  /// 结束录制
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    
    await _recorder.stop();
    await _wavWriter!.stop();
    _isRecording = false;
    
    return _tempFilePath;
  }

  /// 取消录制
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    
    await _recorder.stop();
    await _wavWriter!.cancel();
    _isRecording = false;
    _tempFilePath = null;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _recorder.dispose();
    await _audioStreamController.close();
  }

  /// 将 PCM16 转换为 Float32
  List<double> _convertPcm16ToFloat32(Uint8List pcmData) {
    final int16Data = Int16List.view(pcmData.buffer);
    final float32Data = Float32List(int16Data.length);
    
    for (int i = 0; i < int16Data.length; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    
    return float32Data.toList();
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/services/audio_recorder_service.dart
git commit -m "feat: Add AudioRecorderService with WAV file saving"
```

---

## Task 9: 创建 AudioPlayerWidget

**Files:**
- Create: `example/lib/widgets/audio_player_widget.dart`

- [ ] **Step 1: 创建 AudioPlayerWidget**

```dart
// example/lib/widgets/audio_player_widget.dart

import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';

/// 音频播放器组件
class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final VoidCallback? onPlayComplete;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    this.onPlayComplete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayerService _player = AudioPlayerService.instance;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      setState(() => _state = state);
      if (state == PlayerState.completed) {
        widget.onPlayComplete?.call();
      }
    });
    _player.positionStream.listen((pos) {
      setState(() => _position = pos);
    });
    _player.durationStream.listen((dur) {
      if (dur != null) setState(() => _duration = dur);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 进度条
          Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds.toDouble(),
            onChanged: (value) {
              _player.seek(Duration(milliseconds: value.toInt()));
            },
          ),
          
          // 时间显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _state == PlayerState.playing 
                      ? Icons.pause_rounded 
                      : Icons.play_arrow_rounded,
                ),
                onPressed: _togglePlayPause,
              ),
              IconButton(
                icon: const Icon(Icons.stop_rounded),
                onPressed: () => _player.stop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _togglePlayPause() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(widget.audioPath);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/widgets/audio_player_widget.dart
git commit -m "feat: Add AudioPlayerWidget for audio playback UI"
```

---

## Task 10: 创建 HistoryListWidget

**Files:**
- Create: `example/lib/widgets/history_list_widget.dart`

- [ ] **Step 1: 创建 HistoryListWidget**

```dart
// example/lib/widgets/history_list_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recognition_record.dart';
import '../services/history_storage_service.dart';
import '../services/audio_player_service.dart';

/// 历史记录列表组件
class HistoryListWidget extends StatefulWidget {
  final List<RecognitionRecord> records;
  final void Function(RecognitionRecord)? onPlay;
  final void Function(RecognitionRecord)? onDelete;
  final void Function(RecognitionRecord, bool)? onFavoriteToggle;

  const HistoryListWidget({
    super.key,
    required this.records,
    this.onPlay,
    this.onDelete,
    this.onFavoriteToggle,
  });

  @override
  State<HistoryListWidget> createState() => _HistoryListWidgetState();
}

class _HistoryListWidgetState extends State<HistoryListWidget> {
  @override
  Widget build(BuildContext context) {
    if (widget.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '暂无历史记录',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: widget.records.length,
      itemBuilder: (context, index) {
        final record = widget.records[index];
        return _buildRecordItem(record);
      },
    );
  }

  Widget _buildRecordItem(RecognitionRecord record) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：时间 + 时长 + 操作
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                record.formattedTime(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.timer_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                record.formattedDuration(),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              // 收藏按钮
              IconButton(
                icon: Icon(
                  record.isFavorite 
                      ? Icons.favorite_rounded 
                      : Icons.favorite_border_rounded,
                  size: 18,
                  color: record.isFavorite 
                      ? Theme.of(context).colorScheme.error 
                      : null,
                ),
                onPressed: () {
                  widget.onFavoriteToggle?.call(record, !record.isFavorite);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // 播放按钮
              IconButton(
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                onPressed: () {
                  widget.onPlay?.call(record);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // 复制按钮
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: record.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制到剪贴板')),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // 删除按钮
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: () {
                  widget.onDelete?.call(record);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 文本内容
          Text(
            record.text,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/widgets/history_list_widget.dart
git commit -m "feat: Add HistoryListWidget for displaying recognition history"
```

---

## Task 11: 创建 SearchFilterWidget

**Files:**
- Create: `example/lib/widgets/search_filter_widget.dart`

- [ ] **Step 1: 创建 SearchFilterWidget**

```dart
// example/lib/widgets/search_filter_widget.dart

import 'package:flutter/material.dart';
import '../models/search_filter.dart';

/// 搜索过滤组件
class SearchFilterWidget extends StatefulWidget {
  final SearchFilter initialFilter;
  final void Function(SearchFilter) onFilterChanged;

  const SearchFilterWidget({
    super.key,
    this.initialFilter = const SearchFilter.empty(),
    required this.onFilterChanged,
  });

  @override
  State<SearchFilterWidget> createState() => _SearchFilterWidgetState();
}

class _SearchFilterWidgetState extends State<SearchFilterWidget> {
  String _keyword = '';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isFavoriteFilter = false;

  @override
  void initState() {
    super.initState();
    _keyword = widget.initialFilter.keyword ?? '';
    _startDate = widget.initialFilter.startDate;
    _endDate = widget.initialFilter.endDate;
    _isFavoriteFilter = widget.initialFilter.isFavorite ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          // 搜索输入框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索文本内容...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _keyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        setState(() => _keyword = '');
                        _applyFilter();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() => _keyword = value);
              _applyFilter();
            },
            controller: TextEditingController(text: _keyword),
          ),
          
          const SizedBox(height: 16),
          
          // 过滤选项
          Row(
            children: [
              // 日期范围
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    _startDate != null 
                        ? '${_formatDate(_startDate!)} - ${_endDate != null ? _formatDate(_endDate!) : '今'}'
                        : '日期范围',
                  ),
                  onPressed: _selectDateRange,
                ),
              ),
              const SizedBox(width: 8),
              // 收藏筛选
              FilterChip(
                label: const Text('收藏'),
                selected: _isFavoriteFilter,
                onSelected: (selected) {
                  setState(() => _isFavoriteFilter = selected);
                  _applyFilter();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 清除所有过滤
          if (SearchFilter(
            keyword: _keyword,
            startDate: _startDate,
            endDate: _endDate,
            isFavorite: _isFavoriteFilter,
          ).hasFilters())
            TextButton.icon(
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('清除所有'),
              onPressed: _clearAllFilters,
            ),
        ],
      ),
    );
  }

  void _applyFilter() {
    widget.onFilterChanged(SearchFilter(
      keyword: _keyword.isEmpty ? null : _keyword,
      startDate: _startDate,
      endDate: _endDate,
      isFavorite: _isFavoriteFilter ? true : null,
    ));
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      _applyFilter();
    }
  }

  void _clearAllFilters() {
    setState(() {
      _keyword = '';
      _startDate = null;
      _endDate = null;
      _isFavoriteFilter = false;
    });
    _applyFilter();
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
```

- [ ] **Step 2: 提交**

```bash
git add example/lib/widgets/search_filter_widget.dart
git commit -m "feat: Add SearchFilterWidget for filtering history records"
```

---

## Task 12: 重构 main.dart 集成所有服务

**Files:**
- Modify: `example/lib/main.dart`

- [ ] **Step 1: 更新 main.dart 导入**

在文件开头添加导入：

```dart
import 'services/history_storage_service.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'models/recognition_record.dart';
import 'models/search_filter.dart';
import 'widgets/history_list_widget.dart';
import 'widgets/search_filter_widget.dart';
import 'widgets/audio_player_widget.dart';
```

- [ ] **Step 2: 更新 _HomePageState 添加服务和状态变量**

在 `_HomePageState` 类中添加：

```dart
class _HomePageState extends State<HomePage> {
  // 原有变量保持不变...
  
  // 新增服务和状态
  final HistoryStorageService _storage = HistoryStorageService.instance;
  final AudioRecorderService _audioRecorder = AudioRecorderService.instance;
  final AudioPlayerService _audioPlayer = AudioPlayerService.instance;
  
  List<RecognitionRecord> _historyRecords = [];
  RecognitionRecord? _currentPlayingRecord;
  bool _showSearchFilter = false;
  SearchFilter _currentFilter = const SearchFilter.empty();
  
  // 在 initState 中初始化服务
  @override
  void initState() {
    super.initState();
    _initServices();
    _listenToStateChanges();
    _initSdk();
  }
  
  Future<void> _initServices() async {
    await _storage.initialize();
    await _loadHistory();
  }
  
  Future<void> _loadHistory() async {
    final records = await _storage.getAllRecords();
    setState(() => _historyRecords = records);
  }
```

- [ ] **Step 3: 更新录制流程集成 AudioRecorderService**

修改 `_startRecognition` 方法：

```dart
  void _startRecognition() async {
    try {
      // 使用新的 AudioRecorderService
      await _audioRecorder.startRecording();
      
      setState(() {
        _result = '';
        _partialResult = '';
        _status = 'Listening...';
        _isListening = true;
        _recordingDuration = 0;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() => _recordingDuration++);
      });

      // 监听音频流并发送给 AsrSdk
      _audioRecorder.audioStream.listen((samples) {
        // AsrSdk 内部处理音频流
      });

      // 原有的 AsrSdk.recognize() 调用
      AsrSdk.recognize().listen(
        (text) {
          setState(() => _partialResult = text);
        },
        onError: (error) {
          _recordingTimer?.cancel();
          setState(() {
            _status = 'Error: $error';
            _isListening = false;
          });
        },
        onDone: () {
          _onRecordingComplete();
        },
      );
    } catch (e) {
      _showSnackBar('录制启动失败: $e');
    }
  }
```

- [ ] **Step 4: 添加录制完成处理方法**

```dart
  Future<void> _onRecordingComplete() async {
    _recordingTimer?.cancel();
    
    // 获取录制的音频文件路径
    final audioPath = await _audioRecorder.stopRecording();
    
    setState(() {
      if (_partialResult.isNotEmpty && audioPath != null) {
        // 创建记录并保存
        final record = RecognitionRecord(
          text: _partialResult,
          audioPath: audioPath,
          duration: _recordingDuration,
          timestamp: DateTime.now(),
        );
        
        // 保存到数据库
        _storage.insertRecord(record).then((id) {
          final savedRecord = record.copyWith(id: id);
          setState(() {
            _historyRecords.insert(0, savedRecord);
            _result = _partialResult;
          });
        });
      }
      _partialResult = '';
      _isListening = false;
      _status = 'Ready';
      _recordingDuration = 0;
    });
  }
```

- [ ] **Step 5: 更新 build 方法添加历史记录和搜索**

在 `_buildContentArea` 方法中添加历史记录部分：

```dart
  Widget _buildContentArea() {
    return Column(
      children: [
        // 搜索过滤栏
        if (_showSearchFilter)
          SearchFilterWidget(
            initialFilter: _currentFilter,
            onFilterChanged: (filter) async {
              setState(() => _currentFilter = filter);
              final results = await _storage.search(filter);
              setState(() => _historyRecords = results);
            },
          ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 当前识别结果卡片
                _buildResultCard(),
                
                const SizedBox(height: 24),
                
                // 历史记录标题和搜索按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '历史记录 (${_historyRecords.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: Icon(_showSearchFilter 
                          ? Icons.close_rounded 
                          : Icons.search_rounded),
                      onPressed: () {
                        setState(() => _showSearchFilter = !_showSearchFilter);
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // 历史记录列表
                HistoryListWidget(
                  records: _historyRecords,
                  onPlay: (record) {
                    _showPlayerDialog(record);
                  },
                  onDelete: (record) async {
                    await _storage.deleteRecord(record.id!);
                    await _loadHistory();
                    _showSnackBar('已删除');
                  },
                  onFavoriteToggle: (record, isFavorite) async {
                    await _storage.updateFavorite(record.id!, isFavorite);
                    await _loadHistory();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
```

- [ ] **Step 6: 添加播放对话框方法**

```dart
  void _showPlayerDialog(RecognitionRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          minChildSize: 0.3,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 标题
                  Row(
                    children: [
                      Icon(Icons.record_voice_over_rounded),
                      const SizedBox(width: 8),
                      Text(
                        '语音回放',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 文本内容
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      record.text,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 播放器组件
                  AudioPlayerWidget(
                    audioPath: record.audioPath,
                    onPlayComplete: () {
                      Navigator.pop(context);
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('复制文本'),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: record.text));
                          _showSnackBar('已复制');
                        },
                      ),
                      TextButton.icon(
                        icon: Icon(
                          record.isFavorite 
                              ? Icons.favorite_rounded 
                              : Icons.favorite_border_rounded,
                        ),
                        label: Text(record.isFavorite ? '取消收藏' : '收藏'),
                        onPressed: () async {
                          await _storage.updateFavorite(
                            record.id!, 
                            !record.isFavorite,
                          );
                          await _loadHistory();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
```

- [ ] **Step 7: 更新 dispose 方法**

```dart
  @override
  void dispose() {
    _stateSubscription?.cancel();
    _recordingTimer?.cancel();
    AsrSdk.stop();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _storage.close();
    super.dispose();
  }
```

- [ ] **Step 8: 运行分析验证**

Run: `cd example && flutter analyze`
Expected: No issues found

- [ ] **Step 9: 提交**

```bash
git add example/lib/main.dart
git commit -m "feat: Integrate all services into main.dart with audio playback and history"
```

---

## Task 13: 最终验证和清理

- [ ] **Step 1: 运行完整分析**

Run: `cd example && flutter analyze`
Expected: No issues found

- [ ] **Step 2: 格式化代码**

Run: `cd example && dart format .`
Expected: All files formatted

- [ ] **Step 3: 提交最终版本**

```bash
git add -A
git commit -m "feat: Complete audio playback and history storage implementation"
```

---

## 验收标准

- ✅ 用户可以录制语音并同时识别
- ✅ 录制的音频保存为 WAV 文件
- ✅ 识别结果和音频路径存储在 SQLite
- ✅ 历史记录在应用重启后保留
- ✅ 用户可以播放历史录音
- ✅ 用户可以搜索和过滤历史记录
- ✅ 用户可以收藏/取消收藏记录
- ✅ 用户可以删除记录（同步删除音频文件）
- ✅ 代码分析无错误