// example/lib/utils/wav_writer.dart

import 'dart:io';
import 'dart:typed_data';

/// WAV 文件写入工具
class WavWriter {
  final File file;
  final int sampleRate;
  final int numChannels;
  final int bitsPerSample;

  RandomAccessFile? _raf;
  int _dataSize = 0;
  bool _isWriting = false;
  Future<void> _pendingWrite = Future.value();

  WavWriter({
    required String filePath,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitsPerSample = 16,
  }) : file = File(filePath);

  /// 开始写入 WAV 文件
  Future<void> start() async {
    if (_isWriting) return;

    await file.parent.create(recursive: true);
    _raf = await file.open(mode: FileMode.write);
    _isWriting = true;
    _dataSize = 0;
    _pendingWrite = Future.value();

    // 写入 WAV header（44字节）
    // RIFF header
    await _raf!.writeFrom(_bytes('RIFF'));
    await _raf!.writeFrom(_uint32ToBytes(0)); // 文件大小（最后更新）
    await _raf!.writeFrom(_bytes('WAVE'));

    // fmt chunk
    await _raf!.writeFrom(_bytes('fmt '));
    await _raf!.writeFrom(_uint32ToBytes(16)); // fmt chunk size
    await _raf!.writeFrom(_uint16ToBytes(1)); // audio format (PCM)
    await _raf!.writeFrom(_uint16ToBytes(numChannels));
    await _raf!.writeFrom(_uint32ToBytes(sampleRate));
    await _raf!.writeFrom(
      _uint32ToBytes(sampleRate * numChannels * bitsPerSample ~/ 8),
    ); // byte rate
    await _raf!.writeFrom(
      _uint16ToBytes(numChannels * bitsPerSample ~/ 8),
    ); // block align
    await _raf!.writeFrom(_uint16ToBytes(bitsPerSample));

    // data chunk
    await _raf!.writeFrom(_bytes('data'));
    await _raf!.writeFrom(_uint32ToBytes(0)); // data size（最后更新）
  }

  /// 写入 PCM16 音频数据
  Future<void> writePcm16(Uint8List pcmData) {
    final raf = _raf;
    if (!_isWriting || raf == null) return Future.value();

    final bytes = Uint8List.fromList(pcmData);
    _pendingWrite = _pendingWrite.then((_) async {
      await raf.writeFrom(bytes);
      _dataSize += bytes.length;
    });

    return _pendingWrite;
  }

  /// 结束写入并更新 header
  Future<void> stop() async {
    if (!_isWriting || _raf == null) return;

    _isWriting = false;
    await _pendingWrite;

    // 更新文件大小
    final fileSize = _dataSize + 44 - 8;

    // 更新 RIFF chunk size (位置 4)
    await _raf!.setPosition(4);
    await _raf!.writeFrom(_uint32ToBytes(fileSize));

    // 更新 data chunk size (位置 40)
    await _raf!.setPosition(40);
    await _raf!.writeFrom(_uint32ToBytes(_dataSize));

    await _raf!.close();
    _raf = null;
    _pendingWrite = Future.value();
  }

  /// 取消写入并删除文件
  Future<void> cancel() async {
    if (_raf != null) {
      _isWriting = false;
      await _pendingWrite;
      await _raf!.close();
      _raf = null;
      _pendingWrite = Future.value();
    }
    if (await file.exists()) {
      await file.delete();
    }
  }

  Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

  Uint8List _uint32ToBytes(int value) {
    return Uint8List(4)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF
      ..[2] = (value >> 16) & 0xFF
      ..[3] = (value >> 24) & 0xFF;
  }

  Uint8List _uint16ToBytes(int value) {
    return Uint8List(2)
      ..[0] = value & 0xFF
      ..[1] = (value >> 8) & 0xFF;
  }
}
