# 音频回放与历史记录存储功能设计

## 概述

为 Sherpa ASR SDK Example App 添加以下功能：
1. 语音回放 - 录制并保存音频，支持播放回听
2. 历史记录持久化 - 使用 SQLite 存储识别记录
3. 历史记录搜索/过滤 - 支持文本、日期、时长、收藏筛选

## 目标

- 用户可以回放每次识别的原始录音
- 历史记录在应用重启后保留
- 用户可以搜索和过滤历史记录

## 数据模型

### RecognitionRecord 表结构（SQLite）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | INTEGER PRIMARY KEY AUTOINCREMENT | 自增主键 |
| text | TEXT NOT NULL | 识别文本内容 |
| audioPath | TEXT NOT NULL | 音频文件绝对路径 |
| duration | INTEGER NOT NULL | 录音时长（秒） |
| timestamp | INTEGER NOT NULL | 创建时间（毫秒时间戳） |
| isFavorite | INTEGER DEFAULT 0 | 是否收藏（0=否，1=是） |
| tags | TEXT | 可选标签（JSON 数组，预留） |

### 索引设计

- `idx_timestamp` - 日期筛选优化
- `idx_text` - 文本搜索优化（使用 LIKE 查询）
- `idx_favorite` - 收藏筛选优化

### 文件存储

- 音频文件：`{appDocumentDirectory}/audio_records/{id}.wav`
- 数据库：`{appDocumentDirectory}/sherpa_history.db`
- 音频格式：WAV（无损，16kHz，mono）

## 服务层架构

### AudioRecorderService

职责：扩展录制功能，同时保存音频到 WAV 文件

```dart
class AudioRecorderService {
  Future<String> startRecording();      // 返回临时音频文件路径
  Future<String?> stopRecording();      // 结束录制，返回最终文件路径
  Future<void> cancelRecording();       // 取消并删除临时文件
  Stream<List<double>> get audioStream; // 提供音频流给识别服务
  bool get isRecording;
}
```

实现要点：
- 使用 `record` 包录制 PCM16 音频
- 实时写入 WAV 文件（添加 WAV header）
- 同时提供 Float32 音频流给 `AsrService`

### AudioPlayerService

职责：播放保存的 WAV 文件

```dart
class AudioPlayerService {
  Future<void> play(String audioPath);
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Stream<PlayerState> get playerStateStream;
  Stream<Duration> get positionStream;
  Duration get duration;
}
```

实现要点：
- 使用 `just_audio` 包播放音频
- 支持播放进度监听
- 支持拖动进度条跳转

### HistoryStorageService

职责：SQLite 数据库管理

```dart
class HistoryStorageService {
  Future<void> initialize();
  Future<int> insertRecord(RecognitionRecord record);
  Future<List<RecognitionRecord>> getAllRecords({int limit = 100, int offset = 0});
  Future<List<RecognitionRecord>> search(SearchFilter filter);
  Future<void> updateFavorite(int id, bool isFavorite);
  Future<void> deleteRecord(int id);  // 同时删除音频文件
  Future<void> clearAll();            // 清空所有记录和文件
  Future<int> getCount();
}
```

实现要点：
- 使用 `sqflite` 包管理数据库
- CRUD 操作使用事务保证原子性
- 删除记录时同步删除音频文件

### SearchFilter 模型

```dart
class SearchFilter {
  String? keyword;           // 文本关键词
  DateTime? startDate;       // 开始日期
  DateTime? endDate;         // 结束日期
  int? minDuration;          // 最小时长（秒）
  int? maxDuration;          // 最大时长（秒）
  bool? isFavorite;          // 收藏筛选
}
```

## UI 层设计

### 页面结构

```
HomePage
├── AppBar
│   ├── 标题 + 状态
│   └── 搜索按钮 → 打开 SearchOverlay
│
├── StatusSection（顶部状态栏）
│   ├── SDK 状态指示器
│   └── 下载进度（如果需要）
│
├── ContentArea（中间内容区）
│   ├── CurrentResultCard（当前识别结果）
│   │   ├── 文本显示区
│   │   ├── 录音时长计时器
│   │   └── 操作按钮：Copy、Play（录制后）
│   │
│   └── HistoryList（历史记录列表）
│       ├── SearchBar（搜索/过滤栏）
│       │   ├── 搜索输入框
│       │   ├── 日期范围选择器
│       │   ├── 时长范围选择器
│       │   └── 收藏筛选开关
│       │
│       └── HistoryItems（每条记录）
│           ├── 时间戳 + 时长
│           ├── 收藏标记（可切换）
│           ├── 文本预览（3行截断）
│           └── 操作按钮：Play、Copy、Delete
│
├── ControlBar（底部控制栏）
│   ├── 麦克风按钮（开始录制）
│   └── Stop 按钮（停止录制）
│
└── SearchOverlay（搜索覆盖层）
    ├── 全屏搜索界面
    ├── 实时搜索结果
    └── 快速过滤选项
```

### 新增组件

| 组件 | 功能 |
|------|------|
| `SearchBarWidget` | 搜索输入 + 过滤选项 |
| `AudioPlayerWidget` | 播放进度条 + 播放/暂停按钮 |
| `FavoriteToggleWidget` | 收藏开关按钮 |
| `DateRangePickerWidget` | 日期范围选择 |
| `DurationFilterWidget` | 时长范围滑块选择 |

### 交互流程

1. **录制流程：**
   - 用户点击麦克风 → 开始录制 + 开始识别
   - 音频实时保存到临时 WAV 文件
   - 用户点击停止 → 保存最终文件 + 存入数据库

2. **播放流程：**
   - 用户点击播放按钮 → 加载音频文件
   - 显示播放进度条 + 播放状态
   - 支持拖动进度条跳转

3. **搜索流程：**
   - 打开搜索栏 → 输入关键词或选择过滤条件
   - 实时显示匹配结果
   - 点击结果跳转到详情或直接播放

## 错误处理

### 录制阶段

| 场景 | 处理策略 |
|------|----------|
| 麦克风权限未授予 | 提示用户授权，显示引导对话框 |
| 存储空间不足 | 检测可用空间，不足时警告并停止录制 |
| 录制过程异常中断 | 保存已录制部分，标记为"中断"状态 |
| WAV 文件写入失败 | 重试机制（最多 3 次），失败则丢弃本次录制 |

### 播放阶段

| 场景 | 处理策略 |
|------|----------|
| 音频文件不存在 | 显示"文件已删除"提示，标记记录为无效 |
| 文件损坏无法播放 | 显示错误提示，提供删除选项 |
| 播放过程异常 | 自动停止播放，恢复 UI 到初始状态 |

### 数据库阶段

| 场景 | 处理策略 |
|------|----------|
| 数据库初始化失败 | 使用内存缓存作为临时方案，提示用户重启 |
| 查询超时 | 限制查询数量（最多 100 条），分页加载 |
| 写入冲突 | 使用事务机制，失败时回滚 |

### 边界情况

- 空历史记录：显示空状态提示 + 麦克风引导图标
- 搜索无结果：显示"未找到匹配结果"提示 + 清除筛选按钮
- 大量历史记录（>1000条）：分页加载，每次 20 条，下拉加载更多
- 长文本识别结果：详情页完整显示，列表页截断 3 行
- 长录音（>5分钟）：播放进度条分段标记，支持快进快退

### 数据一致性

- 删除记录时同步删除对应音频文件
- 使用数据库事务保证原子操作
- 定期检查孤儿文件，自动清理

## 测试策略

### 单元测试

| 测试目标 | 测试内容 |
|----------|----------|
| AudioRecorderService | 录制启动/停止、文件路径生成、临时文件清理 |
| AudioPlayerService | 播放状态切换、进度控制、错误处理 |
| HistoryStorageService | CRUD 操作、搜索过滤、数据库事务 |
| SearchFilter | 过滤逻辑、条件组合、空条件处理 |

### Widget 测试

| 测试目标 | 测试内容 |
|----------|----------|
| AudioPlayerWidget | 播放按钮响应、进度条交互、状态显示 |
| SearchBarWidget | 输入响应、过滤选项切换、搜索触发 |
| HistoryListWidget | 列表渲染、点击交互、删除操作 |

### 集成测试

| 测试场景 | 测试内容 |
|----------|----------|
| 完整录制流程 | 录制 → 保存 → 数据库写入 → UI 更新 |
| 完整播放流程 | 点击播放 → 加载音频 → 播放完成 → UI 重置 |
| 搜索功能 | 输入搜索 → 结果返回 → 点击结果 → 播放 |
| 数据持久化 | 重启应用 → 历史记录恢复 → 数据完整 |

### 测试覆盖率目标

- 服务层：≥ 80%
- 关键业务逻辑：≥ 90%

## 依赖

```yaml
dependencies:
  sqflite: ^2.3.0          # SQLite 数据库
  path_provider: ^2.1.1    # 已有，文件路径
  just_audio: ^0.9.36      # 音频播放
  path: ^1.8.3             # 路径操作
```

## 文件结构

```
example/lib/
├── main.dart                        # 入口 + UI 层
├── models/
│   ├── recognition_record.dart      # 数据模型
│   └── search_filter.dart           # 搜索过滤器
├── services/
│   ├── audio_recorder_service.dart  # 音频录制服务
│   ├── audio_player_service.dart    # 音频播放服务
│   └── history_storage_service.dart # 历史存储服务
├── database/
│   └── app_database.dart            # SQLite 初始化
├── widgets/
│   ├── audio_player_widget.dart     # 播放器组件
│   ├── search_bar_widget.dart       # 搜索栏组件
│   └── history_list_widget.dart     # 历史列表组件
└── utils/
    └── wav_writer.dart              # WAV 文件写入工具
```

## 预估工作量

- 服务层实现：约 800 行代码
- UI 层实现：约 500 行代码（重构现有 main.dart）
- 数据库层：约 200 行代码
- 测试代码：约 300 行代码