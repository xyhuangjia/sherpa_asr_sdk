// example/lib/services/audio_player_service.dart

import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// 播放状态
enum PlayerState {
  stopped,
  playing,
  paused,
  completed,
}

/// 音频播放服务
class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._internal();
  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();

  final StreamController<PlayerState> _stateController =
      StreamController<PlayerState>.broadcast();

  Stream<PlayerState> get playerStateStream => _stateController.stream;
  Stream<Duration> get positionStream => _player.positionStream;
  
  /// 获取音频时长流（过滤掉 null 值）
  Stream<Duration> get durationStream =>
      _player.durationStream.where((d) => d != null).cast<Duration>();

  Duration get duration => _player.duration ?? Duration.zero;
  Duration get position => _player.position;

  /// 播放音频
  Future<void> play(String audioPath) async {
    try {
      await _player.setFilePath(audioPath);
      await _player.play();
      _updateState(PlayerState.playing);

      // 监听播放完成
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _updateState(PlayerState.completed);
        }
      });
    } catch (e) {
      _updateState(PlayerState.stopped);
      throw Exception('Failed to play audio: $e');
    }
  }

  /// 暂停播放
  Future<void> pause() async {
    await _player.pause();
    _updateState(PlayerState.paused);
  }

  /// 继续播放
  Future<void> resume() async {
    await _player.play();
    _updateState(PlayerState.playing);
  }

  /// 停止播放
  Future<void> stop() async {
    await _player.stop();
    _updateState(PlayerState.stopped);
  }

  /// 跳转到指定位置
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 释放资源
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
  }

  void _updateState(PlayerState state) {
    _stateController.add(state);
  }
}