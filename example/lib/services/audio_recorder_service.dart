// example/lib/services/audio_recorder_service.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:path/path.dart' as p;

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

  final StreamController<List<double>> _audioStreamController =
      StreamController<List<double>>.broadcast();

  Stream<List<double>> get audioStream => _audioStreamController.stream;
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
      // 写入 WAV 文件
      _wavWriter!.writePcm16(Uint8List.fromList(data));

      // 转换为 Float32 并发送给识别服务
      final float32 = _convertPcm16ToFloat32(Uint8List.fromList(data));
      _audioStreamController.add(float32.toList());
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

  /// 将 PCM16 转换为 Float32
  List<double> _convertPcm16ToFloat32(Uint8List pcmData) {
    final int16Data = Int16List.view(pcmData.buffer);
    final float32Data = Float32List(int16Data.length);

    for (int i = 0; i < int16Data.length; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }

    return float32Data.toList();
  }
}