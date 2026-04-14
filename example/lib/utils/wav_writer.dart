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

  WavWriter({
    required String filePath,
    this.sampleRate = 16000,
    this.numChannels = 1,
    this.bitsPerSample = 16,
  }) : file = File(filePath);

  /// 开始写入 WAV 文件
  Future<void> start() async {
    if (_isWriting) return;

    _raf = await file.open(mode: FileMode.write);
    _isWriting = true;
    _dataSize = 0;

    // 写入 WAV header（44字节）
    // RIFF header
    _raf!.writeFrom(_bytes('RIFF'));
    _raf!.writeFrom(_uint32ToBytes(0)); // 文件大小（最后更新）
    _raf!.writeFrom(_bytes('WAVE'));

    // fmt chunk
    _raf!.writeFrom(_bytes('fmt '));
    _raf!.writeFrom(_uint32ToBytes(16)); // fmt chunk size
    _raf!.writeFrom(_uint16ToBytes(1)); // audio format (PCM)
    _raf!.writeFrom(_uint16ToBytes(numChannels));
    _raf!.writeFrom(_uint32ToBytes(sampleRate));
    _raf!.writeFrom(_uint32ToBytes(
        sampleRate * numChannels * bitsPerSample ~/ 8)); // byte rate
    _raf!.writeFrom(_uint16ToBytes(numChannels * bitsPerSample ~/ 8)); // block align
    _raf!.writeFrom(_uint16ToBytes(bitsPerSample));

    // data chunk
    _raf!.writeFrom(_bytes('data'));
    _raf!.writeFrom(_uint32ToBytes(0)); // data size（最后更新）
  }

  /// 写入 PCM16 音频数据
  void writePcm16(Uint8List pcmData) {
    if (!_isWriting || _raf == null) return;

    _raf!.writeFrom(pcmData);
    _dataSize += pcmData.length;
  }

  /// 结束写入并更新 header
  Future<void> stop() async {
    if (!_isWriting || _raf == null) return;

    // 更新文件大小
    final fileSize = _dataSize + 44 - 8;

    // 更新 RIFF chunk size (位置 4)
    await _raf!.setPosition(4);
    await _raf!.writeFrom(_uint32ToBytes(fileSize));

    // 更新 data chunk size (位置 40)
    await _raf!.setPosition(40);
    await _raf!.writeFrom(_uint32ToBytes(_dataSize));

    await _raf!.close();
    _isWriting = false;
  }

  /// 取消写入并删除文件
  Future<void> cancel() async {
    if (_isWriting && _raf != null) {
      await _raf!.close();
      _isWriting = false;
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