import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

import 'models/recognition_record.dart';
import 'pages/multi_speaker_meeting_page.dart';
import 'services/audio_recorder_service.dart';
import 'services/history_storage_service.dart';
import 'utils/format_utils.dart';
import 'widgets/audio_player_widget.dart';
import 'widgets/history_list_widget.dart';
import 'widgets/waveform_painter.dart';

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
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomePage(),
    );
  }
}

/// 应用页面状态
enum _PageState { ready, recording, result }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // --- SDK 状态 ---
  AsrSdkState _sdkState = AsrSdkState.notInitialized;
  String _status = 'Not initialized';
  double _initProgress = 0.0;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;

  // --- 页面状态 ---
  _PageState _pageState = _PageState.ready;

  // --- 录音状态 ---
  int _recordingDuration = 0;
  String _partialResult = '';
  String _finalResult = '';
  String? _audioPath;
  StreamSubscription<AsrSdkState>? _stateSubscription;
  Timer? _recordingTimer;

  // --- 动画 ---
  late AnimationController _waveformController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // --- 历史记录 ---
  List<RecognitionRecord> _history = [];

  @override
  void initState() {
    super.initState();

    // 波形动画 — 持续循环
    _waveformController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // 脉冲动画 — 录音按钮呼吸效果
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _listenToStateChanges();
    _initServices();
  }

  // ==================== 初始化 ====================

  void _listenToStateChanges() {
    _stateSubscription = AsrSdk.stateStream.listen((state) {
      if (mounted) setState(() => _sdkState = state);
    });
  }

  Future<void> _initServices() async {
    await HistoryStorageService.instance.initialize();
    await _loadHistory();
    await _initSdk();
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

  // ==================== 历史记录 ====================

  Future<void> _loadHistory() async {
    final records = await HistoryStorageService.instance.getAllRecords();
    if (mounted) setState(() => _history = records);
  }

  Future<void> _saveRecording() async {
    if (_finalResult.isEmpty) return;

    final record = RecognitionRecord(
      text: _finalResult,
      audioPath: _audioPath ?? '',
      duration: _recordingDuration,
      timestamp: DateTime.now(),
    );

    await HistoryStorageService.instance.insertRecord(record);
    await _loadHistory();
  }

  Future<void> _deleteRecord(RecognitionRecord record) async {
    if (record.id != null) {
      await HistoryStorageService.instance.deleteRecord(record.id!);
      await _loadHistory();
    }
  }

  Future<void> _toggleFavorite(RecognitionRecord record, bool value) async {
    if (record.id != null) {
      await HistoryStorageService.instance.updateFavorite(record.id!, value);
      await _loadHistory();
    }
  }

  // ==================== 录音控制 ====================

  void _startRecognition() {
    HapticFeedback.mediumImpact();

    setState(() {
      _partialResult = '';
      _finalResult = '';
      _audioPath = null;
      _status = 'Listening...';
      _pageState = _PageState.recording;
      _recordingDuration = 0;
    });

    // 启动动画
    _waveformController.repeat();
    _pulseController.repeat(reverse: true);

    // 启动计时器
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _recordingDuration++);
    });

    // 启动音频录制（保存 WAV 文件）
    AudioRecorderService.instance.startRecording().then((path) {
      _audioPath = path;
    }).catchError((_) {});

    // 启动 ASR 识别流
    AsrSdk.recognize().listen(
      (text) {
        if (mounted) {
          final changed = text != _partialResult;
          setState(() => _partialResult = text);
          if (changed) HapticFeedback.selectionClick();
        }
      },
      onError: (error) {
        _recordingTimer?.cancel();
        _waveformController.stop();
        _pulseController.stop();
        AudioRecorderService.instance.cancelRecording();
        if (mounted) {
          setState(() {
            _status = 'Error: $error';
            _pageState = _PageState.ready;
          });
          showSnackBar(context, 'Recognition error: $error');
        }
      },
      onDone: () {
        _recordingTimer?.cancel();
        _waveformController.stop();
        _pulseController.stop();
        AudioRecorderService.instance.stopRecording();
        if (mounted) {
          setState(() {
            if (_partialResult.isNotEmpty) {
              _finalResult = _partialResult;
              _pageState = _PageState.result;
              _saveRecording();
            } else {
              _pageState = _PageState.ready;
            }
            _partialResult = '';
            _status = 'Ready';
          });
        }
      },
    );
  }

  Future<void> _stopRecognition() async {
    HapticFeedback.heavyImpact();
    await AsrSdk.stopRecognition();
    _recordingTimer?.cancel();
    _waveformController.stop();
    _pulseController.stop();

    _audioPath = await AudioRecorderService.instance.stopRecording();

    if (mounted) {
      setState(() {
        if (_partialResult.isNotEmpty) {
          _finalResult = _partialResult;
          _pageState = _PageState.result;
          _saveRecording();
        } else {
          _pageState = _PageState.ready;
        }
        _partialResult = '';
        _status = 'Ready';
      });
    }
  }

  void _resetForNewRecording() {
    HapticFeedback.lightImpact();
    setState(() {
      _pageState = _PageState.ready;
      _finalResult = '';
      _partialResult = '';
      _audioPath = null;
    });
  }

  // ==================== 操作 ====================

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    showSnackBar(context, '已复制到剪贴板');
  }

  void _playAudio(String audioPath) {
    if (audioPath.isEmpty) {
      showSnackBar(context, '无音频文件');
      return;
    }
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: AudioPlayerWidget(audioPath: audioPath),
      ),
    );
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          if (_pageState != _PageState.recording) _buildStatusSection(),
          if (_pageState != _PageState.recording)
            Divider(
              height: 1,
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          Expanded(child: _buildBody()),
          _buildControlBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isRecording = _pageState == _PageState.recording;

    return AppBar(
      backgroundColor: isRecording
          ? Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3)
          : Theme.of(context).colorScheme.surfaceContainer,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isRecording
                ? '正在录音'
                : _pageState == _PageState.result
                    ? '识别完成'
                    : '语音识别',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          if (isRecording)
            Text(
              formatDuration(_recordingDuration),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            )
          else
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
    );
  }

  Widget _buildStatusSection() {
    final needsModel = !AsrSdk.isInitialized;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
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

  Widget _buildBody() {
    switch (_pageState) {
      case _PageState.recording:
        return _buildRecordingState();
      case _PageState.result:
        return _buildResultState();
      case _PageState.ready:
        return _buildReadyState();
    }
  }

  // --- 就绪态：历史记录列表 ---
  Widget _buildReadyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 空状态引导
          if (_history.isEmpty) ...[
            const SizedBox(height: 60),
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
              '支持中文和英文语音识别',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
            ),
          ],

          // 历史记录
          if (_history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '识别记录',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${_history.length} 条',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            HistoryListWidget(
              records: _history,
              onPlay: (record) => _playAudio(record.audioPath),
              onDelete: (record) => _deleteRecord(record),
              onFavoriteToggle: (record, value) =>
                  _toggleFavorite(record, value),
            ),
          ],
        ],
      ),
    );
  }

  // --- 录音态：沉浸式波形界面 ---
  Widget _buildRecordingState() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          // 波形动画区域
          Expanded(
            flex: 3,
            child: Center(
              child: AnimatedBuilder(
                animation: _waveformController,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(260, 260),
                    painter: WaveformPainter(
                      animationValue: _waveformController.value,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
            ),
          ),

          // 实时识别文本
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.record_voice_over_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '正在识别...',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _partialResult.isEmpty
                            ? '等待语音输入...'
                            : _partialResult,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.6,
                                  color: _partialResult.isEmpty
                                      ? Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.4)
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 结果态：识别结果卡片 ---
  Widget _buildResultState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 结果卡片
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头部
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '识别结果',
                      style:
                          Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
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
                      child: Text(
                        formatDuration(_recordingDuration),
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 识别文本
                Text(
                  _finalResult,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                ),
                const SizedBox(height: 16),

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _copyText(_finalResult),
                      icon: const Icon(Icons.copy_all_rounded, size: 16),
                      label: const Text('复制'),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: _audioPath != null
                          ? () => _playAudio(_audioPath!)
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('播放'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 历史记录标题
          if (_history.isNotEmpty) ...[
            Text(
              '识别记录',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            HistoryListWidget(
              records: _history,
              onPlay: (record) => _playAudio(record.audioPath),
              onDelete: (record) => _deleteRecord(record),
              onFavoriteToggle: (record, value) =>
                  _toggleFavorite(record, value),
            ),
          ],
        ],
      ),
    );
  }

  // --- 底部控制栏 ---
  Widget _buildControlBar() {
    final isReady = AsrSdk.isStarted && AsrSdk.isInitialized;
    final needsModel = !AsrSdk.isInitialized;
    final isRecording = _pageState == _PageState.recording;
    final isResult = _pageState == _PageState.result;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: needsModel
            ? _buildModelWarning()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: _buildMicButton(isReady, isRecording, isResult),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isRecording
                        ? '点击停止'
                        : isResult
                            ? '点击再次录音'
                            : isReady
                                ? '点击开始识别'
                                : '初始化中...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildModelWarning() {
    return Container(
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(bool isReady, bool isRecording, bool isResult) {
    if (isRecording) {
      return SizedBox(
        key: const ValueKey('stop'),
        child: FloatingActionButton.large(
          onPressed: _stopRecognition,
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
          elevation: 8,
          child: const Icon(Icons.stop_rounded, size: 36),
        ),
      );
    }

    if (isResult) {
      return SizedBox(
        key: const ValueKey('retry'),
        child: ScaleTransition(
          scale: _pulseAnimation,
          child: FloatingActionButton.large(
            onPressed: _resetForNewRecording,
            elevation: 8,
            child: const Icon(Icons.mic_rounded, size: 36),
          ),
        ),
      );
    }

    return SizedBox(
      key: const ValueKey('mic'),
      child: ScaleTransition(
        scale: isReady ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
        child: FloatingActionButton.large(
          onPressed: isReady ? _startRecognition : null,
          elevation: 8,
          child: const Icon(Icons.mic_rounded, size: 36),
        ),
      ),
    );
  }

  // ==================== 辅助 ====================

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
            Text('• Recognition history with audio playback'),
            Text('• Multi-speaker meeting mode'),
            Text('• Copy & share results'),
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
    _waveformController.dispose();
    _pulseController.dispose();
    AsrSdk.stop();
    super.dispose();
  }
}
