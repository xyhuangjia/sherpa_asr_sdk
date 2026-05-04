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
  static final AudioRecorderService instance =
      AudioRecorderService._internal();
  AudioRecorderService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  WavWriter? _wavWriter;
  String? _tempFilePath;
  bool _isRecording = false;

  final StreamController<Float32List> _audioStreamController =
      StreamController<Float32List>.broadcast();

  Stream<Float32List> get audioStream => _audioStreamController.stream;
  bool get isRecording => _isRecording;

  /// 开始录制
  Future<String> startRecording() async {
    if (_isRecording) throw Exception('Already recording');

    // 检查权限
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) throw Exception('Microphone permission not granted');

    // 创建临时文件路径
    final appDir = await getApplicationDocumentsDirectory();
    final audioDir = p.join(appDir.path, 'audio_records');
    _tempFilePath = p.join(
        audioDir, 'temp_${DateTime.now().millisecondsSinceEpoch}.wav');

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

    stream.listen((data) {
      final bytes = Uint8List.fromList(data);
      _wavWriter!.writePcm16(bytes);
      _audioStreamController.add(AudioConverter.convertBytesToFloat32(bytes));
    });

    _isRecording = true;
    return _tempFilePath!;
  }

  /// 结束录制
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    await _recorder.stop();
    await _wavWriter!.stop();
    _isRecording = false;

    return _tempFilePath;
  }

  /// 取消录制
  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    await _recorder.stop();
    await _wavWriter!.cancel();
    _isRecording = false;
    _tempFilePath = null;
  }

  /// 释放资源
  Future<void> dispose() async {
    await _recorder.dispose();
    await _audioStreamController.close();
  }

}