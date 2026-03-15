# Directory Structure

> How SDK code is organized in this project.

---

## Overview

这是一个 Flutter SDK 包项目，采用分层架构设计：
- **lib/** - 公共 API 和源代码
- **lib/src/** - 内部实现，不直接暴露给使用者
- **test/** - 单元测试
- **example/** - 使用示例
- **assets/** - 预置资源文件

---

## Directory Layout

```
sherpa_asr_sdk/
├── lib/
│   ├── sherpa_asr_sdk.dart      # 库入口，导出公共 API
│   └── src/                     # 内部实现（不导出）
│       ├── asr_sdk.dart         # 主门面类
│       ├── asr_service.dart     # 核心服务
│       ├── asr_config.dart      # 配置常量
│       ├── asr_state.dart       # 状态枚举
│       ├── asr_callbacks.dart   # 回调类型
│       ├── asr_recorder.dart    # 录音处理
│       ├── model/               # 数据模型
│       │   └── sherpa_models_manager.dart
│       └── utils/               # 工具类
│           ├── asr_logger.dart
│           └── audio_converter.dart
├── test/                        # 单元测试
├── example/                     # 使用示例
└── assets/                      # 预置资源
```

---

## Module Organization

### 核心模块职责

| 模块 | 职责 | 文件 |
|------|------|------|
| **SDK 门面** | 对外暴露的统一接口 | `asr_sdk.dart` |
| **服务层** | 核心业务逻辑 | `asr_service.dart` |
| **配置层** | 常量定义、参数配置 | `asr_config.dart` |
| **状态管理** | 状态枚举、状态流转 | `asr_state.dart` |
| **录音器** | 音频录制、流处理 | `asr_recorder.dart` |
| **模型管理** | 模型下载、存储、验证 | `model/sherpa_models_manager.dart` |
| **工具类** | 日志、音频转换等 | `utils/*.dart` |

### 新功能添加位置

- **公共 API** → 在 `lib/sherpa_asr_sdk.dart` 中 export
- **核心逻辑** → 在 `lib/src/` 下新建文件或扩展现有文件
- **配置参数** → 在 `asr_config.dart` 中添加
- **状态类型** → 在 `asr_state.dart` 中添加枚举

---

## Naming Conventions

### 文件命名
- 使用 `snake_case`：`asr_service.dart`, `audio_converter.dart`
- 文件名与主类名对应：`asr_service.dart` → `AsrService`

### 类命名
- 使用 `PascalCase`：`AsrService`, `AsrRecorder`
- 单例类使用 `._internal()` 私有构造函数

### 变量/方法命名
- 使用 `camelCase`：`startRecognition`, `isListening`
- 私有成员使用 `_` 前缀：`_state`, `_log()`
- 常量使用 `camelCase`：`targetSampleRate`, `modelBaseUrl`

---

## Examples

### 良好的模块组织示例

**`lib/src/asr_sdk.dart`** - 门面模式，静态方法对外暴露：
```dart
class AsrSdk {
  AsrSdk._();  // 私有构造函数

  static AsrService get _asrService => AsrService.instance;

  static Future<bool> initialize({...}) async {...}
  static Future<bool> start() async {...}
  static Stream<String> recognize() {...}
}
```

**`lib/src/asr_service.dart`** - 单例模式：
```dart
class AsrService {
  AsrService._internal();
  static final AsrService instance = AsrService._internal();
}
```

**`lib/src/utils/asr_logger.dart`** - 可扩展接口：
```dart
abstract class AsrLogger {
  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message);
}
```