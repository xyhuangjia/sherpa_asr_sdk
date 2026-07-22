// example/lib/services/audio_recorder_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

import '../utils/wav_writer.dart';

/// 音频录制服务
class AudioRecorderService {
  static final AudioRecorderService instance = AudioRecorderService._internal();
  AudioRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _streamSubscription;
  WavWriter? _wavWriter;
  String? _tempFilePath;
  bool _isRecording = false;
  bool _isStarting = false;
  Future<String?>? _stopFuture;
  Future<void>? _cancelFuture;

  final StreamController<Float32List> _audioStreamController =
      StreamController<Float32List>.broadcast();

  Stream<Float32List> get audioStream => _audioStreamController.stream;
  bool get isRecording => _isRecording;

  /// 开始录制
  Future<String> startRecording() async {
    if (_isRecording || _isStarting || _stopFuture != null) {
      throw Exception('Already recording');
    }

    _isStarting = true;

    try {
      // 检查权限
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) throw Exception('Microphone permission not granted');

      // 创建临时文件路径
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = p.join(appDir.path, 'audio_records');
      _tempFilePath = p.join(
        audioDir,
        'temp_${DateTime.now().millisecondsSinceEpoch}.wav',
      );

      // 初始化 WAV writer
      _wavWriter = WavWriter(filePath: _tempFilePath!);
      await _wavWriter!.start();

      // 启动录制流
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final stream = await _recorder.startStream(config);

      _streamSubscription = stream.listen((data) {
        final bytes = Uint8List.fromList(data);
        _wavWriter?.writePcm16(bytes);
        _audioStreamController.add(AudioConverter.convertBytesToFloat32(bytes));
      });

      _isRecording = true;
      return _tempFilePath!;
    } catch (_) {
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      await _wavWriter?.cancel();
      _wavWriter = null;
      _tempFilePath = null;
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  /// 结束录制
  Future<String?> stopRecording() async {
    final activeStop = _stopFuture;
    if (activeStop != null) return await activeStop;
    if (!_isRecording && _streamSubscription == null && _wavWriter == null) {
      return null;
    }

    _stopFuture = _stopRecording();
    try {
      return await _stopFuture;
    } finally {
      _stopFuture = null;
    }
  }

  Future<String?> _stopRecording() async {
    final path = _tempFilePath;
    final writer = _wavWriter;

    _isRecording = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _recorder.stop();
    await writer?.stop();
    _wavWriter = null;

    return path;
  }

  /// 取消录制
  Future<void> cancelRecording() async {
    final activeCancel = _cancelFuture;
    if (activeCancel != null) {
      await activeCancel;
      return;
    }
    if (_stopFuture != null) {
      await _stopFuture;
      return;
    }
    if (!_isRecording && _streamSubscription == null && _wavWriter == null) {
      return;
    }

    _cancelFuture = _cancelRecording();
    try {
      await _cancelFuture;
    } finally {
      _cancelFuture = null;
    }
  }

  Future<void> _cancelRecording() async {
    final writer = _wavWriter;

    _isRecording = false;
    _tempFilePath = null;
    _wavWriter = null;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    await _recorder.stop();
    await writer?.cancel();
  }

  /// 释放资源
  Future<void> dispose() async {
    await _streamSubscription?.cancel();
    await _recorder.dispose();
    await _audioStreamController.close();
  }
}
