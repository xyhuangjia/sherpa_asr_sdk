import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../asr_config.dart';
import '../utils/asr_logger.dart';

/// Sherpa-onnx 模型管理器
/// 负责模型的下载、存储、验证和管理
class SherpaModelsManager {
  SherpaModelsManager._internal();

  static final SherpaModelsManager instance = SherpaModelsManager._internal();

  final Dio _dio = Dio();

  Directory? _modelsRootDir;
  Directory? _baseModelDir;
  Directory? _advancedModelDir;
  Directory? _streamingBilingualModelDir;

  AsrLogger? _logger;

  void setLogger(AsrLogger logger) {
    _logger = logger;
  }

  void _log(String message) {
    _logger?.debug(message);
    debugPrint(message);
  }

  /// 初始化管理器
  Future<void> initialize() async {
    await _initializeDirectories();
    await _copyAssetsModelIfNeeded();
  }

  /// 将 assets 中预置的模型文件复制到文件系统
  Future<void> _copyAssetsModelIfNeeded() async {
    if (await hasStreamingBilingualModel()) return;
    try {
      for (final fileName in AsrConfig.streamingBilingualModelFiles) {
        final assetPath = '${AsrConfig.assetsModelPath}/$fileName';
        final targetPath = '${_streamingBilingualModelDir!.path}/$fileName';
        final targetFile = File(targetPath);
        if (await targetFile.exists() && await targetFile.length() > 0) {
          continue;
        }
        final data = await rootBundle.load(assetPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await targetFile.writeAsBytes(bytes);
        _log('已复制模型文件: $fileName');
      }
    } catch (e) {
      _log('从 assets 复制模型失败: $e');
    }
  }

  /// 初始化目录结构
  Future<void> _initializeDirectories() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _modelsRootDir = Directory('${appDocDir.path}/${AsrConfig.modelsDirName}');
    _baseModelDir = Directory(
      '${_modelsRootDir!.path}/${AsrConfig.baseModelDirName}',
    );
    _advancedModelDir = Directory(
      '${_modelsRootDir!.path}/${AsrConfig.advancedModelDirName}',
    );
    _streamingBilingualModelDir = Directory(
      '${_modelsRootDir!.path}/${AsrConfig.streamingBilingualModelDirName}',
    );

    if (!await _modelsRootDir!.exists()) {
      await _modelsRootDir!.create(recursive: true);
    }
    if (!await _baseModelDir!.exists()) {
      await _baseModelDir!.create(recursive: true);
    }
    if (!await _advancedModelDir!.exists()) {
      await _advancedModelDir!.create(recursive: true);
    }
    if (!await _streamingBilingualModelDir!.exists()) {
      await _streamingBilingualModelDir!.create(recursive: true);
    }
  }

  // ==================== 模型检查 ====================

  /// 检查基础模型是否存在
  Future<bool> hasBaseModel() async {
    if (_baseModelDir == null) {
      await _initializeDirectories();
    }
    return await _hasAnyModelType(_baseModelDir!);
  }

  Future<bool> _hasAnyModelType(Directory modelDir) async {
    if (!await modelDir.exists()) {
      return false;
    }

    final ctcModel = File('${modelDir.path}/model.int8.onnx');
    if (await ctcModel.exists() && await ctcModel.length() > 0) {
      return true;
    }

    final encoderModel = File('${modelDir.path}/encoder-epoch-20-avg-1.onnx');
    if (await encoderModel.exists() && await encoderModel.length() > 0) {
      return true;
    }

    return false;
  }

  /// 检查 VAD 模型是否存在
  Future<bool> hasVadModel() async {
    if (_baseModelDir == null) {
      await _initializeDirectories();
    }
    final vadModel = File('${_baseModelDir!.path}/silero_vad.onnx');
    return await vadModel.exists() && await vadModel.length() > 0;
  }

  Future<String> _detectModelType() async {
    if (_baseModelDir == null || !await _baseModelDir!.exists()) {
      return 'unknown';
    }

    final ctcModel = File('${_baseModelDir!.path}/model.int8.onnx');
    if (await ctcModel.exists()) {
      return 'ctc';
    }

    final encoderModel = File(
      '${_baseModelDir!.path}/encoder-epoch-20-avg-1.onnx',
    );
    if (await encoderModel.exists()) {
      return 'transducer';
    }

    return 'unknown';
  }

  /// 检查高级模型是否存在
  Future<bool> hasAdvancedModel() async {
    if (_advancedModelDir == null) {
      await _initializeDirectories();
    }
    return await _validateModelFiles(
      _advancedModelDir!,
      AsrConfig.advancedModelFiles,
    );
  }

  /// 检查流式中英模型是否存在
  Future<bool> hasStreamingBilingualModel() async {
    if (_streamingBilingualModelDir == null) {
      await _initializeDirectories();
    }
    return await _validateModelFiles(
      _streamingBilingualModelDir!,
      AsrConfig.streamingBilingualModelFiles,
    );
  }

  Future<bool> _validateModelFiles(
    Directory modelDir,
    List<String> requiredFiles,
  ) async {
    if (!await modelDir.exists()) {
      return false;
    }

    for (final fileName in requiredFiles) {
      _log('检查模型文件: ${modelDir.path}/$fileName');
      final file = File('${modelDir.path}/$fileName');
      if (!await file.exists()) {
        _log('模型文件缺失: $fileName');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        _log('模型文件为空: $fileName');
        return false;
      }
    }

    return true;
  }

  // ==================== 模型获取 ====================

  /// 获取最佳可用模型路径
  Future<String?> getBestModelPath() async {
    if (await hasStreamingBilingualModel()) {
      return _streamingBilingualModelDir!.path;
    }
    if (await hasAdvancedModel()) {
      return _advancedModelDir!.path;
    }
    if (await hasBaseModel()) {
      return _baseModelDir!.path;
    }
    return null;
  }

  /// 获取流式中英模型路径
  Future<String?> getStreamingBilingualModelPath() async {
    if (await hasStreamingBilingualModel()) {
      return _streamingBilingualModelDir!.path;
    }
    return null;
  }

  /// 获取基础模型路径
  Future<String?> getBaseModelPath() async {
    if (await hasBaseModel()) {
      return _baseModelDir!.path;
    }
    return null;
  }

  /// 获取高级模型路径
  Future<String?> getAdvancedModelPath() async {
    if (await hasAdvancedModel()) {
      return _advancedModelDir!.path;
    }
    return null;
  }

  // ==================== 模型下载 ====================

  static const String _hfModelRepo =
      'csukuangfj/sherpa-onnx-streaming-zipformer-zh-14M-02-23';

  Future<bool> _downloadBaseModelArchive({
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('正在下载主模型压缩包...');

      final tempDir = Directory.systemTemp;
      final archiveFile = File('${tempDir.path}/sherpa_model.tar.bz2');

      final downloadSuccess = await _downloadFile(
        url: AsrConfig.modelArchiveUrl,
        savePath: archiveFile.path,
        onProgress: (progress) {
          onProgress?.call(progress * 0.6);
        },
      );

      if (!downloadSuccess) {
        onStatusChange?.call('压缩包下载失败');
        return false;
      }

      onStatusChange?.call('正在解压模型文件...');
      onProgress?.call(0.6);

      final extractSuccess = await _extractTarBz2(
        archiveFile: archiveFile,
        targetDir: _baseModelDir!,
        onProgress: (progress) {
          onProgress?.call(0.6 + progress * 0.3);
        },
      );

      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }

      if (!extractSuccess) {
        onStatusChange?.call('解压失败');
        return false;
      }

      onStatusChange?.call('正在下载 VAD 模型...');
      final vadSuccess = await _downloadVadModel(
        onProgress: (progress) {
          onProgress?.call(0.9 + progress * 0.1);
        },
      );

      if (!vadSuccess) {
        onStatusChange?.call('VAD 模型下载失败，但主模型可用');
      }

      onStatusChange?.call('模型下载完成');
      onProgress?.call(1.0);
      return true;
    } catch (e) {
      _log('下载压缩包失败: $e');
      onStatusChange?.call('下载失败: $e');
      return false;
    }
  }

  Future<bool> _extractTarBz2({
    required File archiveFile,
    required Directory targetDir,
    Function(double progress)? onProgress,
  }) async {
    try {
      final bytes = await archiveFile.readAsBytes();
      final decompressedBytes = BZip2Decoder().decodeBytes(bytes);
      final archive = TarDecoder().decodeBytes(decompressedBytes);

      final totalFiles = archive.files.length;
      int extractedFiles = 0;

      for (final file in archive.files) {
        if (file.isFile) {
          final filePath = '${targetDir.path}/${file.name}';
          final outputFile = File(filePath);
          await outputFile.create(recursive: true);
          await outputFile.writeAsBytes(file.content as List<int>);
        }

        extractedFiles++;
        onProgress?.call(extractedFiles / totalFiles);
      }

      _log('解压完成，共 $totalFiles 个文件');
      return true;
    } catch (e) {
      _log('解压失败: $e');
      return false;
    }
  }

  Future<bool> _downloadVadModel({
    Function(double progress)? onProgress,
  }) async {
    try {
      final vadPath = '${_baseModelDir!.path}/silero_vad.onnx';
      final vadFile = File(vadPath);
      if (await vadFile.exists() && await vadFile.length() > 0) {
        _log('VAD 模型已存在');
        onProgress?.call(1.0);
        return true;
      }

      return await _downloadFile(
        url: AsrConfig.vadModelUrl,
        savePath: vadPath,
        onProgress: onProgress,
      );
    } catch (e) {
      _log('下载 VAD 模型失败: $e');
      return false;
    }
  }

  /// 下载基础模型
  Future<bool> downloadBaseModels({
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('准备下载基础模型...');

      if (await hasBaseModel()) {
        onStatusChange?.call('清理旧模型...');
        await _deleteDirectory(_baseModelDir!);
        await _baseModelDir!.create(recursive: true);
      }

      _log('尝试使用压缩包方式下载模型...');
      final success = await _downloadBaseModelArchive(
        onProgress: onProgress,
        onStatusChange: onStatusChange,
      );

      if (success) {
        return true;
      }

      onStatusChange?.call('切换下载方式...');
      return await downloadBaseModelsLegacy(
        onProgress: onProgress,
        onStatusChange: onStatusChange,
      );
    } catch (e) {
      _log('下载基础模型失败: $e');
      onStatusChange?.call('下载失败: $e');
      return false;
    }
  }

  /// 下载基础模型（旧版逐文件方式）
  Future<bool> downloadBaseModelsLegacy({
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('准备下载基础模型...');

      if (await hasBaseModel()) {
        onStatusChange?.call('清理旧模型...');
        await _deleteDirectory(_baseModelDir!);
        await _baseModelDir!.create(recursive: true);
      }

      final modelFiles = [
        'encoder-epoch-20-avg-1.onnx',
        'decoder-epoch-20-avg-1.onnx',
        'joiner-epoch-20-avg-1.onnx',
        'tokens.txt',
        'lang.txt',
      ];

      final totalFiles = modelFiles.length;
      int completedFiles = 0;

      for (final fileName in modelFiles) {
        onStatusChange?.call('正在下载: $fileName');

        final url = _getBaseModelDownloadUrl(fileName);
        final savePath = '${_baseModelDir!.path}/$fileName';

        final success = await _downloadFileWithRetry(
          url: url,
          savePath: savePath,
          onProgress: (progress) {
            final fileProgress = progress / totalFiles;
            final overallProgress =
                (completedFiles + fileProgress) / totalFiles;
            onProgress?.call(overallProgress);
          },
        );

        if (!success) {
          onStatusChange?.call('下载失败: $fileName');
          await _deleteDirectory(_baseModelDir!);
          await _baseModelDir!.create(recursive: true);
          return false;
        }

        completedFiles++;
        onProgress?.call(completedFiles / totalFiles);
      }

      onStatusChange?.call('基础模型下载完成');
      return true;
    } catch (e) {
      _log('下载基础模型失败: $e');
      onStatusChange?.call('下载失败: $e');
      return false;
    }
  }

  /// 下载流式中英模型
  Future<bool> downloadStreamingBilingualModels({
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    try {
      if (_streamingBilingualModelDir == null) {
        await _initializeDirectories();
      }
      onStatusChange?.call('正在下载流式中英模型...');
      final tempDir = Directory.systemTemp;
      final archiveFile = File(
        '${tempDir.path}/sherpa_streaming_bilingual.tar.bz2',
      );
      final downloadSuccess = await _downloadFile(
        url: AsrConfig.streamingBilingualModelArchiveUrl,
        savePath: archiveFile.path,
        onProgress: (p) => onProgress?.call(p * 0.6),
      );
      if (!downloadSuccess) {
        onStatusChange?.call('压缩包下载失败');
        return false;
      }
      onStatusChange?.call('正在解压...');
      onProgress?.call(0.6);
      final extractDir = Directory('${tempDir.path}/sherpa_streaming_extract');
      if (await extractDir.exists()) {
        await _deleteDirectory(extractDir);
      }
      await extractDir.create(recursive: true);
      final extractOk = await _extractTarBz2(
        archiveFile: archiveFile,
        targetDir: extractDir,
        onProgress: (p) => onProgress?.call(0.6 + p * 0.3),
      );
      if (await archiveFile.exists()) {
        await archiveFile.delete();
      }
      if (!extractOk) {
        onStatusChange?.call('解压失败');
        return false;
      }
      final subdirs = await extractDir
          .list()
          .where((e) => e is Directory)
          .toList();
      if (subdirs.isEmpty) {
        onStatusChange?.call('压缩包格式异常');
        return false;
      }
      final innerDir = subdirs.first as Directory;
      if (await _streamingBilingualModelDir!.exists()) {
        await _deleteDirectory(_streamingBilingualModelDir!);
        await _streamingBilingualModelDir!.create(recursive: true);
      }
      await for (final entity in innerDir.list()) {
        if (entity is File) {
          final name = entity.path.split(RegExp(r'[/\\]')).last;
          await entity.copy('${_streamingBilingualModelDir!.path}/$name');
        }
      }
      await _deleteDirectory(extractDir);
      onStatusChange?.call('模型下载完成');
      onProgress?.call(1.0);
      return await hasStreamingBilingualModel();
    } catch (e) {
      _log('下载流式中英模型失败: $e');
      onStatusChange?.call('下载失败: $e');
      return false;
    }
  }

  /// 下载高级模型
  Future<bool> downloadAdvancedModels({
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    try {
      onStatusChange?.call('准备下载模型...');

      if (await hasAdvancedModel()) {
        onStatusChange?.call('清理旧模型...');
        await _deleteDirectory(_advancedModelDir!);
        await _advancedModelDir!.create(recursive: true);
      }

      final totalFiles = AsrConfig.advancedModelFiles.length;
      int completedFiles = 0;

      for (final fileName in AsrConfig.advancedModelFiles) {
        onStatusChange?.call('正在下载: $fileName');

        final success = await _downloadFile(
          url: AsrConfig.getAdvancedModelUrl(fileName),
          savePath: '${_advancedModelDir!.path}/$fileName',
          onProgress: (progress) {
            final fileProgress = progress / totalFiles;
            final overallProgress =
                (completedFiles + fileProgress) / totalFiles;
            onProgress?.call(overallProgress);
          },
        );

        if (!success) {
          onStatusChange?.call('下载失败: $fileName');
          await _deleteDirectory(_advancedModelDir!);
          await _advancedModelDir!.create(recursive: true);
          return false;
        }

        completedFiles++;
        onProgress?.call(completedFiles / totalFiles);
      }

      onStatusChange?.call('模型下载完成');
      return true;
    } catch (e) {
      _log('下载模型失败: $e');
      onStatusChange?.call('下载失败: $e');
      return false;
    }
  }

  Future<bool> _downloadFileWithRetry({
    required String url,
    required String savePath,
    Function(double progress)? onProgress,
  }) async {
    final uri = Uri.parse(url);
    final pathParts = uri.path.split('/');
    if (pathParts.length < 3) {
      return false;
    }

    final repoIndex = pathParts.indexWhere((p) => p.contains('sherpa-onnx'));
    if (repoIndex < 0) {
      return await _downloadFile(
        url: url,
        savePath: savePath,
        onProgress: onProgress,
      );
    }

    final repo = pathParts.sublist(repoIndex).join('/');
    final fileName = pathParts.last;

    final mirrors = ['https://hf-mirror.com', 'https://huggingface.co'];

    for (final mirror in mirrors) {
      final mirrorUrl = '$mirror/$repo/resolve/main/$fileName';
      if (await _downloadFile(
        url: mirrorUrl,
        savePath: savePath,
        onProgress: onProgress,
      )) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _downloadFile({
    required String url,
    required String savePath,
    Function(double progress)? onProgress,
  }) async {
    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress?.call(received / total);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );
      return true;
    } catch (e) {
      _log('下载文件失败: $url, 错误: $e');
      return false;
    }
  }

  String _getBaseModelDownloadUrl(String fileName) {
    final mirrors = ['https://hf-mirror.com', 'https://huggingface.co'];
    return '${mirrors[0]}/$_hfModelRepo/resolve/main/$fileName';
  }

  // ==================== 模型删除 ====================

  Future<void> deleteAllModels() async {
    if (_modelsRootDir != null && await _modelsRootDir!.exists()) {
      await _deleteDirectory(_modelsRootDir!);
    }
    await _initializeDirectories();
  }

  Future<void> deleteBaseModel() async {
    if (_baseModelDir != null && await _baseModelDir!.exists()) {
      await _deleteDirectory(_baseModelDir!);
      await _baseModelDir!.create(recursive: true);
    }
  }

  Future<void> deleteAdvancedModel() async {
    if (_advancedModelDir != null && await _advancedModelDir!.exists()) {
      await _deleteDirectory(_advancedModelDir!);
      await _advancedModelDir!.create(recursive: true);
    }
  }

  Future<void> _deleteDirectory(Directory dir) async {
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  // ==================== 模型信息 ====================

  Future<int> getBaseModelSize() async {
    return await _getDirectorySize(_baseModelDir);
  }

  Future<int> getAdvancedModelSize() async {
    return await _getDirectorySize(_advancedModelDir);
  }

  Future<int> _getDirectorySize(Directory? dir) async {
    if (dir == null || !await dir.exists()) {
      return 0;
    }

    int size = 0;
    try {
      final entities = dir.list(recursive: true, followLinks: false);
      await for (final entity in entities) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (e) {
      _log('计算目录大小失败: $e');
    }
    return size;
  }

  String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  Future<Map<String, dynamic>> getModelStatus() async {
    final hasBase = await hasBaseModel();
    final hasAdvanced = await hasAdvancedModel();
    final hasVad = await hasVadModel();
    final modelType = await _detectModelType();
    final baseSize = await getBaseModelSize();
    final advancedSize = await getAdvancedModelSize();

    return {
      'hasBaseModel': hasBase,
      'hasAdvancedModel': hasAdvanced,
      'hasVadModel': hasVad,
      'baseModelType': modelType,
      'baseModelSize': baseSize,
      'advancedModelSize': advancedSize,
      'baseModelSizeFormatted': formatFileSize(baseSize),
      'advancedModelSizeFormatted': formatFileSize(advancedSize),
    };
  }
}
