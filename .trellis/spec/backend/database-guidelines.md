# Database Guidelines

> Data storage patterns for this project.

---

## Overview

本项目是 Flutter SDK 包，**不使用传统数据库**。数据存储主要涉及：
- **模型文件存储** - 使用文件系统存储 AI 模型
- **配置持久化** - 使用 `path_provider` 获取应用目录

---

## Storage Patterns

### 模型文件存储

使用 `path_provider` 获取应用文档目录：

```dart
// lib/src/model/sherpa_models_manager.dart:68-93
Future<void> _initializeDirectories() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  _modelsRootDir = Directory('${appDocDir.path}/${AsrConfig.modelsDirName}');
  _baseModelDir = Directory(
    '${_modelsRootDir!.path}/${AsrConfig.baseModelDirName}',
  );
  // ...

  if (!await _modelsRootDir!.exists()) {
    await _modelsRootDir!.create(recursive: true);
  }
}
```

### 目录结构约定

```
<ApplicationDocumentsDirectory>/
└── sherpa_models/
    ├── base_model/           # 基础模型
    │   ├── model.int8.onnx
    │   ├── tokens.txt
    │   └── ...
    ├── advanced_model/       # 高级模型
    └── streaming_bilingual_model/  # 流式中英模型
```

---

## File Operations

### 文件检查

```dart
// lib/src/model/sherpa_models_manager.dart:98-103
Future<bool> hasBaseModel() async {
  if (_baseModelDir == null) {
    await _initializeDirectories();
  }
  return await _hasAnyModelType(_baseModelDir!);
}
```

### 文件验证

```dart
// lib/src/model/sherpa_models_manager.dart:174-198
Future<bool> _validateModelFiles(
  Directory modelDir,
  List<String> requiredFiles,
) async {
  if (!await modelDir.exists()) {
    return false;
  }

  for (final fileName in requiredFiles) {
    final file = File('${modelDir.path}/$fileName');
    if (!await file.exists()) {
      return false;
    }
    final fileSize = await file.length();
    if (fileSize == 0) {
      return false;
    }
  }
  return true;
}
```

### 目录清理

```dart
// lib/src/model/sherpa_models_manager.dart:679-683
Future<void> _deleteDirectory(Directory dir) async {
  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
}
```

---

## Configuration Constants

所有存储相关配置集中在 `AsrConfig`：

```dart
// lib/src/asr_config.dart:111-124
static const String modelsDirName = 'sherpa_models';
static const String baseModelDirName = 'base_model';
static const String advancedModelDirName = 'advanced_model';
static const String streamingBilingualModelDirName = 'streaming_bilingual_model';
static const String assetsModelPath = 'assets/models/sherpa-onnx/base';
```

---

## Common Mistakes

### ❌ 硬编码路径

```dart
// 不要这样做
final dir = Directory('/Users/xxx/models');
```

### ✅ 使用 path_provider

```dart
// lib/src/model/sherpa_models_manager.dart:69
final appDocDir = await getApplicationDocumentsDirectory();
```

### ❌ 忽略文件存在检查

```dart
// 不要这样做
await file.writeAsBytes(bytes);
```

### ✅ 先检查再写入

```dart
// lib/src/model/sherpa_models_manager.dart:51-53
if (await targetFile.exists() && await targetFile.length() > 0) {
  continue;
}
```