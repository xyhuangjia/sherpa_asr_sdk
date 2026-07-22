// example/lib/widgets/audio_player_widget.dart

import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import '../theme/app_theme.dart';

/// 音频播放器组件
class AudioPlayerWidget extends StatefulWidget {
  final String audioPath;
  final VoidCallback? onPlayComplete;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
    this.onPlayComplete,
  });

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayerService _player = AudioPlayerService.instance;
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() => _state = state);
        if (state == PlayerState.completed) {
          widget.onPlayComplete?.call();
        }
      }
    });
    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                '音频回放',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onBg,
                ),
              ),
              const Spacer(),
              Text(
                'PLAYBACK',
                style: mono(
                  size: 10,
                  color: AppColors.onBgDim,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // 进度条
          Slider(
            value: _position.inMilliseconds.toDouble().clamp(
              0.0,
              _duration.inMilliseconds.toDouble(),
            ),
            max: _duration.inMilliseconds.toDouble().clamp(
              1.0,
              double.infinity,
            ),
            onChanged: (value) {
              _player.seek(Duration(milliseconds: value.toInt()));
            },
          ),

          // 时间显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: mono(size: 11, color: AppColors.primary),
              ),
              Text(
                _formatDuration(_duration),
                style: mono(size: 11, color: AppColors.onBgDim),
              ),
            ],
          ),

          const SizedBox(height: 4),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _circleButton(
                icon: _state == PlayerState.playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: _togglePlayPause,
                primary: true,
              ),
              const SizedBox(width: 16),
              _circleButton(
                icon: Icons.stop_rounded,
                onTap: () => _player.stop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    VoidCallback? onTap,
    bool primary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: primary ? 52 : 44,
        height: primary ? 52 : 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary ? AppColors.primary : AppColors.surface,
          border: primary ? null : Border.all(color: AppColors.outline),
          boxShadow: primary
              ? glow(AppColors.primary, radius: 16, alpha: 0.5)
              : null,
        ),
        child: Icon(
          icon,
          size: primary ? 28 : 22,
          color: primary ? AppColors.bg : AppColors.onBg,
        ),
      ),
    );
  }

  void _togglePlayPause() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else if (_state == PlayerState.paused) {
      await _player.resume();
    } else {
      await _player.play(widget.audioPath);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
