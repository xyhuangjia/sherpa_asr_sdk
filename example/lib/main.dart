import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

import 'pages/multi_speaker_meeting_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AsrSdk.setLogger(DefaultAsrLogger());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sherpa ASR Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AsrSdkState _sdkState = AsrSdkState.notInitialized;
  String _status = 'Not initialized';
  String _result = '';
  String _partialResult = '';
  double _initProgress = 0.0;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  bool _isListening = false;
  int _recordingDuration = 0;
  StreamSubscription<AsrSdkState>? _stateSubscription;
  Timer? _recordingTimer;

  // 识别历史记录
  final List<_RecognitionRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _listenToStateChanges();
    _initSdk();
  }

  void _listenToStateChanges() {
    _stateSubscription = AsrSdk.stateStream.listen((state) {
      if (mounted) setState(() => _sdkState = state);
    });
  }

  Future<void> _initSdk() async {
    if (AsrSdk.isInitialized) {
      setState(() => _status = 'Ready');
      await AsrSdk.start();
      return;
    }

    setState(() {
      _status = 'Initializing...';
      _initProgress = 0.0;
    });

    final success = await AsrSdk.initialize(
      onProgress: (progress) {
        setState(() => _initProgress = progress);
      },
      onStatus: (status) {
        setState(() => _status = status);
      },
    );

    if (success) {
      setState(() => _status = 'Ready');
      await AsrSdk.start();
    } else {
      setState(() {
        _status = 'Model not found - Download required';
        _initProgress = 0.0;
      });
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _status = 'Downloading model...';
    });

    final manager = SherpaModelsManager.instance;
    final success = await manager.downloadStreamingBilingualModels(
      onProgress: (progress) {
        setState(() => _downloadProgress = progress);
      },
      onStatusChange: (status) {
        setState(() => _status = status);
      },
    );

    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
    });

    if (success) {
      setState(() => _status = 'Model downloaded, initializing...');
      await _initSdk();
    } else {
      setState(() => _status = 'Download failed');
    }
  }

  void _startRecognition() {
    setState(() {
      _result = '';
      _partialResult = '';
      _status = 'Listening...';
      _isListening = true;
      _recordingDuration = 0;
    });

    // 启动计时器
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _recordingDuration++);
    });

    AsrSdk.recognize().listen(
      (text) {
        setState(() {
          _partialResult = text;
        });
      },
      onError: (error) {
        _recordingTimer?.cancel();
        setState(() {
          _status = 'Error: $error';
          _isListening = false;
        });
        _showSnackBar('Recognition error: $error');
      },
      onDone: () {
        _recordingTimer?.cancel();
        setState(() {
          if (_partialResult.isNotEmpty) {
            // 保存到历史记录
            _history.insert(
              0,
              _RecognitionRecord(
                text: _partialResult,
                timestamp: DateTime.now(),
                duration: _recordingDuration,
              ),
            );
            _result = _partialResult;
          }
          _partialResult = '';
          _isListening = false;
          _status = 'Ready';
          _recordingDuration = 0;
        });
      },
    );
  }

  Future<void> _stopRecognition() async {
    await AsrSdk.stopRecognition();
    _recordingTimer?.cancel();
    setState(() {
      _status = 'Ready';
      _isListening = false;
      _recordingDuration = 0;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '语音识别',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MultiSpeakerMeetingPage(),
                ),
              );
            },
            tooltip: '多人会议',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
            tooltip: 'About',
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部状态卡片
          _buildStatusSection(),

          // 分割线
          Divider(
            height: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),

          // 中间内容区域
          Expanded(child: _buildContentArea()),

          // 底部控制栏
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    final needsModel = !AsrSdk.isInitialized;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          // SDK 状态指示器
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _sdkState.name.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_initProgress > 0 && _initProgress < 1.0) ...[
                const Spacer(),
                Text(
                  '${(_initProgress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),

          // 初始化进度条
          if (_initProgress > 0 && _initProgress < 1.0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _initProgress,
                minHeight: 4,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
            ),
          ],

          // 模型下载提示
          if (needsModel && !_isDownloading) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloadModel,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Download Model (~30MB)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(
                    context,
                  ).colorScheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],

          // 下载进度
          if (_isDownloading) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _downloadProgress,
              minHeight: 4,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading: ${(_downloadProgress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    final hasHistory = _history.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 当前识别结果卡片
          _buildResultCard(),

          const SizedBox(height: 24),

          // 历史记录标题
          if (hasHistory) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '识别记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _history.clear());
                  },
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Clear All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 历史记录列表
          if (hasHistory)
            for (final record in _history) _buildHistoryItem(record),

          // 空状态提示
          if (!hasHistory && !_isListening) ...[
            SizedBox(height: 60),
            Icon(
              Icons.mic_none_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '点击麦克风开始识别',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '识别结果将显示在这里',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final displayText = _partialResult.isNotEmpty
        ? _partialResult
        : _result.isNotEmpty
        ? _result
        : '';
    final isPartial = _partialResult.isNotEmpty;
    final hasContent = displayText.isNotEmpty;

    return Container(
      constraints: BoxConstraints(minHeight: 120, maxHeight: 300),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPartial
              ? Theme.of(context).colorScheme.primary
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: isPartial ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头部
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.record_voice_over_rounded,
                  size: 20,
                  color: isPartial
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  isPartial ? '正在识别...' : '识别结果',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isPartial
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (isPartial) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 6,
                          height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(_recordingDuration),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 文本内容
          Expanded(
            child: hasContent
                ? SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      displayText,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: isPartial
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'Press the microphone button to start',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),

          // 操作按钮
          if (hasContent && !isPartial)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // TODO: 实现复制功能
                      _showSnackBar('Copy feature coming soon');
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 16),
                    label: const Text('Copy'),
                  ),
                  const SizedBox(width: 4),
                  TextButton.icon(
                    onPressed: () {
                      // TODO: 实现语音回放功能
                      _showSnackBar('Audio playback feature coming soon');
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text('Play Audio'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(_RecognitionRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 时间和时长
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatTime(record.timestamp),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.timer_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDuration(record.duration),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // 操作按钮
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      // TODO: 实现语音回放
                      _showSnackBar('Audio playback coming soon');
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    tooltip: 'Play Audio',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      // TODO: 实现复制
                      _showSnackBar('Copy feature coming soon');
                    },
                    icon: const Icon(Icons.copy_all_rounded, size: 18),
                    tooltip: 'Copy Text',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 识别文本
          Text(
            record.text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.5),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
    final isReady = AsrSdk.isStarted && AsrSdk.isInitialized;
    final needsModel = !AsrSdk.isInitialized;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (needsModel)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please download model first',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: _isListening
                        ? SizedBox(
                            key: const ValueKey('stop'),
                            child: FloatingActionButton.large(
                              onPressed: _stopRecognition,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onError,
                              elevation: 8,
                              child: const Icon(Icons.stop_rounded, size: 36),
                            ),
                          )
                        : SizedBox(
                            key: const ValueKey('mic'),
                            child: FloatingActionButton.large(
                              onPressed: isReady ? _startRecognition : null,
                              elevation: 8,
                              child: const Icon(Icons.mic_rounded, size: 36),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isListening
                        ? 'Tap to stop'
                        : isReady
                        ? 'Tap to start'
                        : 'Initializing...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_sdkState) {
      case AsrSdkState.notInitialized:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case AsrSdkState.initializing:
        return Theme.of(context).colorScheme.primary;
      case AsrSdkState.ready:
      case AsrSdkState.started:
        return Theme.of(context).colorScheme.primary;
      case AsrSdkState.error:
        return Theme.of(context).colorScheme.error;
    }
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sherpa ASR SDK Demo'),
            SizedBox(height: 8),
            Text('Offline speech recognition using Sherpa-onnx.'),
            SizedBox(height: 16),
            Text('Features:'),
            SizedBox(height: 8),
            Text('• Real-time streaming recognition'),
            Text('• Offline processing (no internet needed)'),
            Text('• Chinese & English support'),
            SizedBox(height: 8),
            Text('• Recognition history'),
            Text('• Multi-speaker meeting mode'),
            Text('• Audio playback (coming soon)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _recordingTimer?.cancel();
    AsrSdk.stop();
    super.dispose();
  }
}

// 识别记录数据类
class _RecognitionRecord {
  final String text;
  final DateTime timestamp;
  final int duration;

  _RecognitionRecord({
    required this.text,
    required this.timestamp,
    required this.duration,
  });
}
