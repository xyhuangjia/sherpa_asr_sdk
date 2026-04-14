// example/lib/widgets/audio_player_widget.dart

import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';

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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 进度条
          Slider(
            value: _position.inMilliseconds.toDouble().clamp(
                0.0, _duration.inMilliseconds.toDouble()),
            max: _duration.inMilliseconds.toDouble().clamp(1.0, double.infinity),
            onChanged: (value) {
              _player.seek(Duration(milliseconds: value.toInt()));
            },
          ),

          // 时间显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position)),
              Text(_formatDuration(_duration)),
            ],
          ),

          const SizedBox(height: 8),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _state == PlayerState.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
                onPressed: _togglePlayPause,
              ),
              IconButton(
                icon: const Icon(Icons.stop_rounded),
                onPressed: () => _player.stop(),
              ),
            ],
          ),
        ],
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