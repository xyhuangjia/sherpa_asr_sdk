/// 多人会议识别页面
///
/// 展示多人场景下的说话人自动聚类功能。
/// 不同说话人的内容用不同颜色标记，实时显示说话人切换。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

/// 说话人颜色调色板
/// 为不同说话人分配不同的颜色，便于视觉区分
const _speakerColors = [
  Colors.blue,
  Colors.orange,
  Colors.green,
  Colors.purple,
  Colors.red,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
  Colors.cyan,
  Colors.lime,
  Colors.deepOrange,
  Colors.deepPurple,
  Colors.lightBlue,
  Colors.lightGreen,
  Colors.brown,
  Colors.blueGrey,
  Colors.yellow,
  Colors.grey,
  Colors.black,
];

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
    _stateSubscription = AsrSdk.stateStream.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });
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

  // 将当前部分文本添加到转录中（保留供未来使用）
  // ignore: unused_element
  void _addCurrentPartialToTranscript() {
    if (_partialText.isEmpty) return;

    final segment = _TranscriptSegment(
      speakerLabel: _currentSpeaker,
      text: _partialText,
      timestamp: DateTime.now(),
    );

    setState(() {
      _transcript.add(segment);
      _partialText = '';
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
              '多人会议',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            Text(
              _status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
            tooltip: 'About',
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部状态区域
          _buildStatusSection(),

          // 分割线
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),

          // 会议转录内容
          Expanded(child: _buildTranscriptArea()),

          // 底部控制栏
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        children: [
          // 状态指示器
          Row(
            children: [
              // 录音指示点
              if (_isListening)
                PulseIndicator(color: Theme.of(context).colorScheme.error)
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isInitialized
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 8),
              Text(
                _isListening ? 'MEETING' : (AsrSdk.isInitialized ? 'READY' : 'NOT INITIALIZED'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _isListening
                          ? Theme.of(context).colorScheme.error
                          : _isInitialized
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),

              // 时长
              if (_isListening) ...[
                const Spacer(),
                Text(
                  _formatDuration(_recordingDuration),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
                Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '当前: $_currentSpeaker',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                if (AsrSdk.activeSpeakerCount > 0) ...[
                  const Spacer(),
                  Chip(
                    label: Text(
                      '${AsrSdk.activeSpeakerCount} 人已识别',
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
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
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
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
            Icon(
              Icons.groups_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              '多人会议模式',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                '自动识别不同说话人，实时标记谁说了什么。\n需要启用 VAD 和 Diarization。',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                _currentSpeaker,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: color,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                '正在识别...',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _partialText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.6,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSegment(_TranscriptSegment segment) {
    final colorIndex = _getSpeakerColorIndex(segment.speakerLabel);
    final color = _speakerColors[colorIndex % _speakerColors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：说话人 + 时间
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    segment.speakerLabel.replaceAll('Speaker ', '').substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
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
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(segment.timestamp),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 文本内容
          Text(
            segment.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar() {
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
        child: Column(
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
                        onPressed: _stopMeeting,
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        elevation: 8,
                        child: const Icon(Icons.stop_rounded, size: 36),
                      ),
                    )
                  : SizedBox(
                      key: const ValueKey('mic'),
                      child: FloatingActionButton.large(
                        onPressed: _isInitialized ? _startMeeting : null,
                        elevation: 8,
                        child: const Icon(Icons.groups_rounded, size: 36),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              _isListening ? 'Tap to end meeting' : (_isInitialized ? 'Tap to start meeting' : 'Initializing...'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取说话人颜色索引
  int _getSpeakerColorIndex(String speakerLabel) {
    final match = RegExp(r'Speaker\s*(\d+)').firstMatch(speakerLabel);
    if (match != null) {
      return int.parse(match.group(1)!) - 1;
    }
    return 0;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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
                final color = _speakerColors[colorIndex % _speakerColors.length];
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
                        style: TextStyle(fontWeight: FontWeight.w600, color: color),
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

/// 脉冲动画指示器
class PulseIndicator extends StatefulWidget {
  final Color color;

  const PulseIndicator({super.key, required this.color});

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
