import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

class DemoModelDownloadConfig {
  const DemoModelDownloadConfig._();

  static const String streamingBilingualModelArchiveUrl =
      'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/'
      'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20.tar.bz2';
}

class DemoModelDownloader {
  DemoModelDownloader({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<bool> downloadStreamingBilingualModel({
    Function(double progress)? onProgress,
    Function(String status)? onStatusChange,
  }) async {
    Directory? tempDir;
    try {
      tempDir = await Directory.systemTemp.createTemp(
        'sherpa_demo_streaming_model_',
      );
      final archiveFile = File(p.join(tempDir.path, 'model.tar.bz2'));

      onStatusChange?.call('正在下载模型...');
      await _dio.download(
        DemoModelDownloadConfig.streamingBilingualModelArchiveUrl,
        archiveFile.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total * 0.6);
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 10),
        ),
      );

      onStatusChange?.call('正在解压模型...');
      final extractDir = Directory(p.join(tempDir.path, 'extract'));
      await extractDir.create(recursive: true);
      await _extractTarBz2(
        archiveFile: archiveFile,
        targetDir: extractDir,
        onProgress: (progress) => onProgress?.call(0.6 + progress * 0.3),
      );

      onStatusChange?.call('正在安装模型...');
      final targetDir = await _streamingBilingualModelDir();
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await targetDir.create(recursive: true);

      final extractedFiles = await _findRequiredFiles(extractDir);
      for (final fileName in AsrConfig.streamingBilingualModelFiles) {
        final sourceFile = extractedFiles[fileName];
        if (sourceFile == null) {
          onStatusChange?.call('模型文件缺失: $fileName');
          await targetDir.delete(recursive: true);
          await targetDir.create(recursive: true);
          return false;
        }
        await sourceFile.copy(p.join(targetDir.path, fileName));
      }

      if (!await _hasRequiredFiles(targetDir)) {
        onStatusChange?.call('模型文件校验失败');
        return false;
      }

      onProgress?.call(1.0);
      onStatusChange?.call('模型下载完成');
      return true;
    } catch (e) {
      onStatusChange?.call('下载失败: $e');
      return false;
    } finally {
      if (tempDir != null && await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<Directory> _streamingBilingualModelDir() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return Directory(
      p.join(
        appDocDir.path,
        AsrConfig.modelsDirName,
        AsrConfig.streamingBilingualModelDirName,
      ),
    );
  }

  Future<void> _extractTarBz2({
    required File archiveFile,
    required Directory targetDir,
    Function(double progress)? onProgress,
  }) async {
    final bytes = await archiveFile.readAsBytes();
    final decompressedBytes = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(decompressedBytes);

    var completed = 0;
    for (final file in archive.files) {
      if (file.isFile) {
        final normalizedName = p.normalize(file.name);
        if (p.isAbsolute(normalizedName) ||
            normalizedName == '..' ||
            normalizedName.startsWith('../')) {
          continue;
        }

        final outputPath = p.join(targetDir.path, normalizedName);
        if (!p.isWithin(targetDir.path, outputPath)) {
          continue;
        }

        final outputFile = File(outputPath);
        await outputFile.create(recursive: true);
        await outputFile.writeAsBytes(file.content as List<int>);
      }

      completed++;
      onProgress?.call(completed / archive.files.length);
    }
  }

  Future<Map<String, File>> _findRequiredFiles(Directory extractDir) async {
    final requiredNames = AsrConfig.streamingBilingualModelFiles.toSet();
    final foundFiles = <String, File>{};

    await for (final entity in extractDir.list(recursive: true)) {
      if (entity is! File) continue;

      final fileName = p.basename(entity.path);
      if (!requiredNames.contains(fileName) ||
          foundFiles.containsKey(fileName)) {
        continue;
      }

      if (await entity.length() > 0) {
        foundFiles[fileName] = entity;
      }
    }

    return foundFiles;
  }

  Future<bool> _hasRequiredFiles(Directory modelDir) async {
    for (final fileName in AsrConfig.streamingBilingualModelFiles) {
      final file = File(p.join(modelDir.path, fileName));
      if (!await file.exists() || await file.length() == 0) {
        return false;
      }
    }
    return true;
  }
}
