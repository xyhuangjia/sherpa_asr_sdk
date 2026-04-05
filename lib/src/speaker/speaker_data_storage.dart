import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 说话人数据持久化存储
///
/// 使用文件系统存储说话人的 Embedding 向量
/// 使用 SharedPreferences 存储说话人姓名列表（待实现）
class SpeakerDataStorage {
  static final SpeakerDataStorage _instance =
      SpeakerDataStorage._internal();
  factory SpeakerDataStorage() => _instance;
  SpeakerDataStorage._internal();

  Directory? _storageDir;
  final Map<String, Float32List> _cache = {};

  /// 初始化存储目录
  Future<void> initialize() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _storageDir = Directory('${appDocDir.path}/sherpa_speakers');
    if (!await _storageDir!.exists()) {
      await _storageDir!.create(recursive: true);
    }
    _log('说话人存储目录：${_storageDir!.path}');
  }

  /// 保存说话人 Embedding
  ///
  /// 将 Embedding 向量保存为 JSON 文件
  Future<bool> saveSpeaker(String name, Float32List embedding) async {
    try {
      if (_storageDir == null) {
        await initialize();
      }

      final filePath = '${_storageDir!.path}/$name.json';
      final file = File(filePath);

      // 转换为 List<double> 以便 JSON 序列化
      final jsonData = {
        'name': name,
        'embedding': embedding.toList(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      await file.writeAsString(jsonEncode(jsonData));
      _cache[name] = embedding;

      _log('说话人已保存：$name');
      return true;
    } catch (e) {
      _logError('保存说话人失败：$e');
      return false;
    }
  }

  /// 加载说话人 Embedding
  Future<Float32List?> loadSpeaker(String name) async {
    try {
      // 先检查缓存
      if (_cache.containsKey(name)) {
        return _cache[name];
      }

      if (_storageDir == null) {
        await initialize();
      }

      final filePath = '${_storageDir!.path}/$name.json';
      final file = File(filePath);

      if (!await file.exists()) {
        return null;
      }

      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

      final embeddingList = jsonData['embedding'] as List;
      final embedding = Float32List.fromList(
        embeddingList.map((e) => (e as num).toDouble()).toList(),
      );

      _cache[name] = embedding;
      return embedding;
    } catch (e) {
      _logError('加载说话人失败：$e');
      return null;
    }
  }

  /// 删除说话人
  Future<bool> deleteSpeaker(String name) async {
    try {
      if (_storageDir == null) {
        await initialize();
      }

      final filePath = '${_storageDir!.path}/$name.json';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
      }

      _cache.remove(name);
      _log('说话人已删除：$name');
      return true;
    } catch (e) {
      _logError('删除说话人失败：$e');
      return false;
    }
  }

  /// 获取所有说话人姓名
  Future<List<String>> getAllSpeakers() async {
    try {
      if (_storageDir == null) {
        await initialize();
      }

      final speakers = <String>[];
      await for (final entity in _storageDir!.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final name = entity.path
              .split('/')
              .last
              .replaceAll('.json', '');
          speakers.add(name);
        }
      }
      return speakers;
    } catch (e) {
      _logError('获取说话人列表失败：$e');
      return [];
    }
  }

  /// 清除所有说话人数据
  Future<void> clearAllSpeakers() async {
    try {
      if (_storageDir == null) {
        await initialize();
      }

      await for (final entity in _storageDir!.list()) {
        if (entity is File) {
          await entity.delete();
        }
      }

      _cache.clear();
      _log('所有说话人数据已清除');
    } catch (e) {
      _logError('清除所有说话人失败：$e');
    }
  }

  /// 获取说话人数量
  Future<int> getSpeakerCount() async {
    final speakers = await getAllSpeakers();
    return speakers.length;
  }

  /// 检查说话人是否存在
  Future<bool> hasSpeaker(String name) async {
    if (_cache.containsKey(name)) {
      return true;
    }

    if (_storageDir == null) {
      await initialize();
    }

    final filePath = '${_storageDir!.path}/$name.json';
    final file = File(filePath);
    return await file.exists();
  }

  void _log(String message) {
    print('[SpeakerStorage] $message');
  }

  void _logError(String message) {
    print('[SpeakerStorage] ERROR: $message');
  }
}
