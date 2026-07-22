import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

import 'models/recognition_record.dart';
import 'pages/multi_speaker_meeting_page.dart';
import 'services/audio_recorder_service.dart';
import 'services/history_storage_service.dart';
import 'theme/app_theme.dart';
import 'utils/demo_model_downloader.dart';
import 'utils/format_utils.dart';
import 'widgets/audio_player_widget.dart';
import 'widgets/history_list_widget.dart';
import 'widgets/tech_background.dart';
import 'widgets/tech_controls.dart';
import 'widgets/waveform_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AsrSdk.setLogger(DefaultAsrLogger());
  // 锁定浅色系统栏图标（深色背景）。
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sherpa ASR',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      darkTheme: appTheme,
      themeMode: ThemeMode.dark,
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
  bool _isCompletingRecognition = false;
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

    final success = await DemoModelDownloader().downloadStreamingBilingualModel(
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
    AudioRecorderService.instance
        .startRecording()
        .then((path) {
          _audioPath = path;
        })
        .catchError((_) {});

    // 启动 ASR 识别流
    AsrSdk.recognize().listen(
      (text) {
        if (mounted) {
          final changed = text != _partialResult;
          setState(() => _partialResult = text);
          if (changed) HapticFeedback.selectionClick();
        }
      },
      onError: (error) async {
        _recordingTimer?.cancel();
        _waveformController.stop();
        _pulseController.stop();
        await AudioRecorderService.instance.cancelRecording();
        if (mounted) {
          setState(() {
            _status = 'Error: $error';
            _pageState = _PageState.ready;
          });
          showSnackBar(context, 'Recognition error: $error');
        }
      },
      onDone: _completeRecognition,
    );
  }

  Future<void> _stopRecognition() async {
    HapticFeedback.heavyImpact();
    await AsrSdk.stopRecognition();
    await _completeRecognition();
  }

  Future<void> _completeRecognition() async {
    if (_isCompletingRecognition) return;

    _isCompletingRecognition = true;
    try {
      final recognizedText = _partialResult;

      _recordingTimer?.cancel();
      _waveformController.stop();
      _pulseController.stop();

      _audioPath = await AudioRecorderService.instance.stopRecording();

      if (!mounted) return;

      final shouldSave = recognizedText.isNotEmpty;
      setState(() {
        if (shouldSave) {
          _finalResult = recognizedText;
          _pageState = _PageState.result;
        } else {
          _pageState = _PageState.ready;
        }
        _partialResult = '';
        _status = 'Ready';
      });

      if (shouldSave) {
        await _saveRecording();
      }
    } finally {
      _isCompletingRecognition = false;
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
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              AudioPlayerWidget(audioPath: audioPath),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 构建 ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: TechBackground(
        child: Column(
          children: [
            if (_pageState != _PageState.recording) _buildStatusSection(),
            if (_pageState != _PageState.recording)
              const Divider(height: 1, color: AppColors.outlineVariant),
            Expanded(child: _buildBody()),
            _buildControlBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isRecording = _pageState == _PageState.recording;

    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceHigh.withValues(alpha: 0.92),
              AppColors.surfaceHigh.withValues(alpha: 0.0),
            ],
          ),
        ),
      ),
      titleSpacing: 16,
      title: Row(
        children: [
          LiveDot(
            active: isRecording,
            color: isRecording ? AppColors.error : _getStatusColor(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRecording
                      ? '正在录音'
                      : _pageState == _PageState.result
                      ? '识别完成'
                      : '语音识别',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBg,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isRecording ? 'LIVE STREAM' : _status,
                  style: mono(
                    size: 11,
                    letterSpacing: 1.6,
                    color: isRecording ? AppColors.primary : AppColors.onBgDim,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.groups_2_rounded),
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
          tooltip: '关于',
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    final needsModel = !AsrSdk.isInitialized;
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: glow(statusColor, radius: 6, alpha: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _sdkState.name.toUpperCase(),
                style: mono(size: 11, color: statusColor, letterSpacing: 1.5),
              ),
              if (_initProgress > 0 && _initProgress < 1.0) ...[
                const Spacer(),
                Text(
                  '${(_initProgress * 100).toString().padLeft(2, '0')}%',
                  style: mono(size: 11, color: AppColors.onBgDim),
                ),
              ],
            ],
          ),
          if (_initProgress > 0 && _initProgress < 1.0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _initProgress,
                minHeight: 4,
              ),
            ),
          ],
          if (needsModel && !_isDownloading) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _downloadModel,
                icon: const Icon(Icons.cloud_download_rounded, size: 18),
                label: const Text('下载模型  ·  ~30MB'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          ],
          if (_isDownloading) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DOWNLOAD',
                  style: mono(size: 10, color: AppColors.onBgDim),
                ),
                Text(
                  '${(_downloadProgress * 100).toString().padLeft(2, '0')}%',
                  style: mono(size: 11, color: AppColors.primary),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 空状态引导
          if (_history.isEmpty) ...[
            const SizedBox(height: 72),
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                  boxShadow: glow(AppColors.primary, radius: 28, alpha: 0.25),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '点击麦克风开始识别',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.onBg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SHERPA-ONNX  ·  离线语音识别  ·  中英双语',
              textAlign: TextAlign.center,
              style: mono(size: 11, color: AppColors.onBgDim, letterSpacing: 1),
            ),
          ],

          // 历史记录
          if (_history.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: glow(
                          AppColors.primary,
                          radius: 4,
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '识别记录',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBg,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${_history.length} 条',
                  style: mono(size: 11, color: AppColors.onBgDim),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          // 顶部 REC + 大号计时器
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const LiveDot(active: true, color: AppColors.error),
                const SizedBox(width: 8),
                Text(
                  'REC',
                  style: mono(
                    size: 12,
                    color: AppColors.error,
                    letterSpacing: 3,
                  ),
                ),
                const Spacer(),
                AnimatedBuilder(
                  animation: _waveformController,
                  builder: (context, _) {
                    final blink =
                        (_waveformController.value * 2).floor() % 2 == 0;
                    return Text(
                      '${formatDuration(_recordingDuration)}${blink ? '▍' : ' '}',
                      style: mono(
                        size: 30,
                        color: AppColors.primary,
                        letterSpacing: 2,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

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
                      color: AppColors.primary,
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
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: glow(
                            AppColors.primary,
                            radius: 4,
                            alpha: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '正在识别',
                        style: mono(
                          size: 11,
                          color: AppColors.primary,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.graphic_eq_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _partialResult.isEmpty ? '等待语音输入…' : _partialResult,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: _partialResult.isEmpty
                              ? AppColors.onBgDim.withValues(alpha: 0.5)
                              : AppColors.onBg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: glow(AppColors.primary, radius: 24, alpha: 0.12),
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
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '识别结果',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onBg,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        formatDuration(_recordingDuration),
                        style: mono(size: 11, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: AppColors.outlineVariant),
                const SizedBox(height: 14),

                // 识别文本
                Text(
                  _finalResult,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: AppColors.onBg,
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
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: glow(AppColors.primary, radius: 4, alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '识别记录',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          decoration: BoxDecoration(
            color: AppColors.bg.withValues(alpha: 0.72),
            border: Border(
              top: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
            ),
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
                      const SizedBox(height: 10),
                      Text(
                        isRecording
                            ? '点击停止'
                            : isResult
                            ? '点击再次录音'
                            : isReady
                            ? '点击开始识别'
                            : '初始化中…',
                        style: mono(
                          size: 11,
                          color: AppColors.onBgDim,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildModelWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '请先在上方下载模型',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.error.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton(bool isReady, bool isRecording, bool isResult) {
    if (isRecording) {
      return GradientFab(
        key: const ValueKey('stop'),
        gradient: AppGradients.stopButton,
        glowColor: AppColors.error,
        icon: Icons.stop_rounded,
        onPressed: _stopRecognition,
      );
    }

    if (isResult) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: GradientFab(
          key: const ValueKey('retry'),
          gradient: AppGradients.micButton,
          glowColor: AppColors.primary,
          icon: Icons.mic_rounded,
          onPressed: _resetForNewRecording,
        ),
      );
    }

    return ScaleTransition(
      scale: isReady ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
      child: GradientFab(
        key: const ValueKey('mic'),
        gradient: AppGradients.micButton,
        glowColor: AppColors.primary,
        glowAlpha: isReady ? 0.6 : 0.0,
        dimmed: !isReady,
        icon: Icons.mic_rounded,
        onPressed: isReady ? _startRecognition : null,
      ),
    );
  }

  // ==================== 辅助 ====================

  Color _getStatusColor() {
    switch (_sdkState) {
      case AsrSdkState.notInitialized:
        return AppColors.onBgDim;
      case AsrSdkState.initializing:
        return AppColors.secondary;
      case AsrSdkState.ready:
      case AsrSdkState.started:
        return AppColors.success;
      case AsrSdkState.error:
        return AppColors.error;
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
