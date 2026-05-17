# 任务清单：增强说话人分离功能

## Phase 1: IdentifiedSpeaker 重构

- [x] Task 1.1: 改造 IdentifiedSpeaker 类 - 将 `embedding` 改为 `_embeddings` (List<Float32List>), 添加 `registeredName` 字段, 添加 `maxEmbeddings` 常量 (5), 添加 `addEmbedding()` 方法, 添加 `bestMatchScore()` 方法, 添加 `displayLabel` getter
- [x] Task 1.2: 更新 AsrDiarizationConfig - 新增 `enableRegisteredMatching` (bool), `registeredMatchThreshold` (double, 0.7), `maxEmbeddingsPerSpeaker` (int, 5), 更新 `copyWith()` 方法

## Phase 2: AsrDiarizer 分层匹配

- [x] Task 2.1: 添加已注册说话人数据支持 - 构造函数添加可选参数 `registeredSpeakers`, 存储 `Map<String, Float32List> _registeredSpeakers`
- [x] Task 2.2: 实现分层匹配逻辑 - 实现 `_matchRegisteredSpeaker()`, `_matchSessionSpeaker()`, `_findSessionSpeakerByRegisteredName()`, `_addRegisteredSessionSpeaker()`, 重构 `identifySpeaker()` 使用分层逻辑
- [x] Task 2.3: 更新 `_addNewSpeaker` 和相关方法 - `_addNewSpeaker()` 使用新 IdentifiedSpeaker 构造, `_findMostSimilarSpeaker()` 使用 bestMatchScore, `reset()` 清空数据

## Phase 3: AsrSpeakerManager 扩展

- [x] Task 3.1: 添加 getRegisteredEmbeddings 方法 - 返回 `Map<String, Float32List>`, 内部调用 `_storage.getAllSpeakers()` + `_storage.loadSpeaker()`

## Phase 4: AsrDiarizationManager 改造

- [x] Task 4.1: 初始化时获取已注册数据 - `_initialize()` 时调用 `_speakerManager.getRegisteredEmbeddings()`, 传递给 `AsrDiarizer` 构造函数
- [x] Task 4.2: 支持动态更新已注册数据 - 新增 `refreshRegisteredSpeakers()` 方法

## Phase 5: AsrService 层集成

- [x] Task 5.1: 确保 SpeakerManager 初始化顺序 - 检查 `_ensureManagers()` 中 DiarizationManager 接收已初始化的 SpeakerManager, 添加 `refreshDiarizationSpeakers()` 方法

## Phase 6: 测试

- [x] Task 6.1: 单元测试 - IdentifiedSpeaker - 测试 addEmbedding() 累积和上限, bestMatchScore() 计算, displayLabel 优先级
- [x] Task 6.2: 单元测试 - 分层匹配 - 测试 Layer 1/2/3 匹配, 已注册用户会话内重识别
- [x] Task 6.3: 集成测试 - SpeakerManager + DiarizationManager 协作测试

## Phase 7: Example App 更新

- [x] Task 7.1: 更新 MultiSpeakerMeetingPage 显示 - 使用 `displayLabel` 替代 `label`, 支持已注册用户名称的颜色映射