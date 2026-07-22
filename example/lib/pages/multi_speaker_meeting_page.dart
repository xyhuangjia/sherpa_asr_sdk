/// 多人会议识别页面
///
/// 展示多人场景下的说话人自动聚类功能。
/// 不同说话人的内容用不同颜色标记，实时显示说话人切换。
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

import '../theme/app_theme.dart';
import '../utils/format_utils.dart';
import '../widgets/tech_background.dart';
import '../widgets/tech_controls.dart';

/// 说话人颜色调色板（取自品牌色系 [AppColors.speakers]）。
const _speakerColors = AppColors.speakers;

/// 会议转录片段
class _TranscriptSegment {
  final String speakerLabel;
  final String text;
  final DateTime timestamp;

  _TranscriptSegment({
    required this.speakerLabel,
    required this.text,
    required this.timestamp,
  });
}

/// 多人会议识别页面
class MultiSpeakerMeetingPage extends StatefulWidget {
  const MultiSpeakerMeetingPage({super.key});

  @override
  State<MultiSpeakerMeetingPage> createState() =>
      _MultiSpeakerMeetingPageState();
}

class _MultiSpeakerMeetingPageState extends State<MultiSpeakerMeetingPage> {
  // 状态
  bool _isInitialized = false;
  bool _isListening = false;
  String _status = 'Not initialized';
  double _initProgress = 0.0;
  int _recordingDuration = 0;

  // 订阅
  StreamSubscription<AsrSdkState>? _stateSubscription;
  StreamSubscription<String?>? _speakerChangeSubscription;
  Timer? _recordingTimer;

  // 会议转录
  final List<_TranscriptSegment> _transcript = [];
  String _currentSpeaker = 'Unknown';
  String _partialText = '';

  // 说话人统计
  final Map<String, int> _speakerWordCount = {};

  @override
  void initState() {
    super.initState();
    _listenToStateChanges();
    _listenToSpeakerChanges();
    _initSdk();
  }

  void _listenToStateChanges() {
    _stateSubscription = AsrSdk.stateStream.listen((_) {});
  }

  void _listenToSpeakerChanges() {
    _speakerChangeSubscription = AsrSdk.speakerChangeStream.listen((label) {
      if (label != null) {
        setState(() {
          _currentSpeaker = label;
        });
      }
    });
  }

  Future<void> _initSdk() async {
    if (AsrSdk.isInitialized) {
      setState(() {
        _isInitialized = true;
        _status = 'Ready';
      });
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
      // 启用 VAD + Diarization
      await AsrSdk.enableVAD(true);
      await AsrSdk.enableDiarization(true);

      setState(() {
        _isInitialized = true;
        _status = 'Ready - Diarization enabled';
      });
      await AsrSdk.start();
    } else {
      setState(() {
        _status = 'Model not found';
        _initProgress = 0.0;
      });
    }
  }

  void _startMeeting() {
    setState(() {
      _transcript.clear();
      _speakerWordCount.clear();
      _partialText = '';
      _status = 'Meeting in progress...';
      _isListening = true;
      _recordingDuration = 0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _recordingDuration++);
      }
    });

    // 使用带时间戳的识别，获取说话人信息
    AsrSdk.recognizeWithTimestamps().listen(
      (result) {
        if (mounted) {
          setState(() {
            _partialText = result.labeledText;
          });
        }
      },
      onError: (error) {
        _recordingTimer?.cancel();
        if (mounted) {
          setState(() {
            _status = 'Error: $error';
            _isListening = false;
          });
          _showSnackBar('Recognition error: $error');
        }
      },
      onDone: () {
        _recordingTimer?.cancel();
        if (mounted) {
          setState(() {
            _isListening = false;
            _status = 'Meeting ended';
            _recordingDuration = 0;
          });
        }
      },
    );
  }

  Future<void> _stopMeeting() async {
    await AsrSdk.stopRecognition();
    _recordingTimer?.cancel();

    // 统计说话人字数
    for (final segment in _transcript) {
      final words = segment.text.split(RegExp(r'\s+')).length;
      _speakerWordCount[segment.speakerLabel] =
          (_speakerWordCount[segment.speakerLabel] ?? 0) + words;
    }

    if (mounted) {
      setState(() {
        _isListening = false;
        _status = 'Meeting ended';
        _recordingDuration = 0;
      });
    }
  }

  void _showSnackBar(String message) {
    showSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
              active: _isListening,
              color: _isListening
                  ? AppColors.error
                  : (_isInitialized ? AppColors.success : AppColors.onBgDim),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '多人会议',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onBg,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _isListening ? 'LIVE TRANSCRIPT' : _status,
                    style: mono(
                      size: 11,
                      letterSpacing: 1.6,
                      color: _isListening
                          ? AppColors.primary
                          : AppColors.onBgDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_transcript.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              onPressed: _showSpeakerStats,
              tooltip: '说话人统计',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
            tooltip: '关于',
          ),
        ],
      ),
      body: TechBackground(
        child: Column(
          children: [
            // 顶部状态区域
            _buildStatusSection(),

            // 分割线
            const Divider(height: 1, color: AppColors.outlineVariant),

            // 会议转录内容
            Expanded(child: _buildTranscriptArea()),

            // 底部控制栏
            _buildControlBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          // 状态指示器
          Row(
            children: [
              LiveDot(
                active: _isListening,
                color: _isListening
                    ? AppColors.error
                    : (_isInitialized ? AppColors.success : AppColors.onBgDim),
              ),
              const SizedBox(width: 8),
              Text(
                _isListening
                    ? 'MEETING'
                    : (AsrSdk.isInitialized ? 'READY' : 'STANDBY'),
                style: mono(
                  size: 11,
                  letterSpacing: 1.5,
                  color: _isListening
                      ? AppColors.error
                      : (_isInitialized
                            ? AppColors.success
                            : AppColors.onBgDim),
                ),
              ),

              // 时长
              if (_isListening) ...[
                const Spacer(),
                Text(
                  formatDuration(_recordingDuration),
                  style: mono(
                    size: 13,
                    color: AppColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ],
          ),

          // 当前说话人
          if (_isListening) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 14,
                  color: AppColors.onBgDim,
                ),
                const SizedBox(width: 4),
                Text(
                  '当前 · $_currentSpeaker',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onBgDim,
                  ),
                ),
                if (AsrSdk.activeSpeakerCount > 0) ...[
                  const Spacer(),
                  Chip(label: Text('${AsrSdk.activeSpeakerCount} 人已识别')),
                ],
              ],
            ),
          ],

          // 初始化进度条
          if (_initProgress > 0 && _initProgress < 1.0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _initProgress,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscriptArea() {
    if (!_isInitialized && _transcript.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.35),
                ),
                boxShadow: glow(AppColors.secondary, radius: 28, alpha: 0.22),
              ),
              child: const Icon(
                Icons.groups_2_rounded,
                size: 46,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '多人会议模式',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.onBg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'SPEAKER DIARIZATION  ·  自动区分说话人',
              style: mono(size: 11, color: AppColors.onBgDim, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '实时标记谁说了什么\n需启用 VAD 与 Diarization',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: AppColors.onBgDim.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 实时识别中的文本
          if (_partialText.isNotEmpty) ...[
            _buildPartialSegment(),
            const SizedBox(height: 12),
          ],

          // 历史转录
          for (int i = 0; i < _transcript.length; i++)
            _buildTranscriptSegment(_transcript[i]),
        ],
      ),
    );
  }

  Widget _buildPartialSegment() {
    final colorIndex = _getSpeakerColorIndex(_currentSpeaker);
    final color = _speakerColors[colorIndex % _speakerColors.length];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: glow(color, radius: 18, alpha: 0.14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.graphic_eq_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                _currentSpeaker,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              LiveDot(active: true, color: color),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: mono(
                  size: 10,
                  color: color.withValues(alpha: 0.85),
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _partialText,
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: AppColors.onBg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSegment(_TranscriptSegment segment) {
    final colorIndex = _getSpeakerColorIndex(segment.speakerLabel);
    final color = _speakerColors[colorIndex % _speakerColors.length];
    final rawLabel = segment.speakerLabel.replaceAll('Speaker ', '');
    final initial = rawLabel.isEmpty ? '?' : rawLabel.substring(0, 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左侧色条
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: glow(color, radius: 5, alpha: 0.5),
                            ),
                            child: Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: AppColors.bg,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            segment.speakerLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: color,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatTime(segment.timestamp),
                            style: mono(size: 10, color: AppColors.onBgDim),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        segment.text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.onBg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: _isListening
                      ? GradientFab(
                          key: const ValueKey('stop'),
                          gradient: AppGradients.stopButton,
                          glowColor: AppColors.error,
                          icon: Icons.stop_rounded,
                          onPressed: _stopMeeting,
                        )
                      : GradientFab(
                          key: const ValueKey('mic'),
                          gradient: AppGradients.micButton,
                          glowColor: AppColors.primary,
                          icon: Icons.groups_2_rounded,
                          glowAlpha: _isInitialized ? 0.6 : 0.0,
                          dimmed: !_isInitialized,
                          onPressed: _isInitialized ? _startMeeting : null,
                        ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isListening
                      ? '点击结束会议'
                      : (_isInitialized ? '点击开始会议' : '初始化中…'),
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

  /// 获取说话人颜色索引
  ///
  /// 支持两种格式：
  /// - "Speaker 1", "Speaker 2" 等 → 使用索引
  /// - 已注册用户名（如 "张三"）→ 使用内部 speaker 的 label 提取索引
  int _getSpeakerColorIndex(String speakerLabel) {
    // 直接匹配 "Speaker N" 格式
    final match = RegExp(r'Speaker\s*(\d+)').firstMatch(speakerLabel);
    if (match != null) {
      return int.parse(match.group(1)!) - 1;
    }

    // 查找对应的 IdentifiedSpeaker 获取索引
    final speakers = AsrSdk.activeSpeakers;
    for (final speaker in speakers) {
      if (speaker.displayLabel == speakerLabel) {
        final innerMatch = RegExp(r'Speaker\s*(\d+)').firstMatch(speaker.label);
        if (innerMatch != null) {
          return int.parse(innerMatch.group(1)!) - 1;
        }
      }
    }

    return 0;
  }

  void _showSpeakerStats() {
    // 统计每个说话人的发言
    final speakerSegments = <String, List<_TranscriptSegment>>{};
    for (final segment in _transcript) {
      speakerSegments.putIfAbsent(segment.speakerLabel, () => []).add(segment);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('说话人统计'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('共 ${_transcript.length} 段发言'),
              const SizedBox(height: 16),
              ...speakerSegments.entries.map((entry) {
                final colorIndex = _getSpeakerColorIndex(entry.key);
                final color =
                    _speakerColors[colorIndex % _speakerColors.length];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key}: ${entry.value.length} 段',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('多人会议模式'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自动识别不同说话人'),
            SizedBox(height: 8),
            Text('功能说明：'),
            SizedBox(height: 8),
            Text('• VAD 检测语音段开始/结束'),
            Text('• Diarization 自动聚类说话人'),
            Text('• 实时标记 [Speaker 1], [Speaker 2] 等'),
            SizedBox(height: 8),
            Text('注意：'),
            SizedBox(height: 8),
            Text('• 需要 Speaker ReID 模型'),
            Text('• 语音段需要足够长（>1秒）才能提取特征'),
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
    _speakerChangeSubscription?.cancel();
    _recordingTimer?.cancel();
    AsrSdk.stop();
    super.dispose();
  }
}
