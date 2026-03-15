import 'dart:math';
import 'dart:typed_data';

import '../asr_config.dart';

/// 音频转换器
/// 负责将录音数据转换为 Sherpa-onnx 需要的格式
class AudioConverter {
  AudioConverter._();

  /// PCM16 字节转 Float32（16kHz 单声道）
  static Float32List convertBytesToFloat32(
    Uint8List bytes, [
    Endian endian = Endian.little,
  ]) {
    final values = Float32List(bytes.length ~/ 2);
    final data = ByteData.view(bytes.buffer);
    for (var i = 0; i < bytes.length; i += 2) {
      final short = data.getInt16(i, endian);
      values[i ~/ 2] = short / 32768.0;
    }
    return values;
  }

  /// 将 PCM16 字节数据转换为 int16 列表
  static List<int> bytesToInt16List(Uint8List bytes) {
    final int16List = <int>[];
    for (int i = 0; i < bytes.length - 1; i += 2) {
      final int16 = (bytes[i + 1] << 8) | bytes[i];
      int16List.add(int16.toSigned(16));
    }
    return int16List;
  }

  /// 将 int16 转换为 float32（归一化到 [-1, 1]）
  static List<double> int16ToFloat32(List<int> int16Data) {
    return int16Data.map((sample) => sample / 32768.0).toList();
  }

  /// 将 float32 转换回 int16
  static List<int> float32ToInt16(List<double> float32Data) {
    return float32Data
        .map((sample) => (sample.clamp(-1.0, 1.0) * 32767.0).round())
        .toList();
  }

  /// 线性插值重采样
  static List<double> resample(List<int> samples, int fromRate, int toRate) {
    if (fromRate == toRate) {
      return int16ToFloat32(samples);
    }

    final ratio = fromRate / toRate;
    final outputLength = (samples.length / ratio).ceil();
    final result = List<double>.filled(outputLength, 0.0);

    for (int i = 0; i < outputLength; i++) {
      final position = i * ratio;
      final index0 = position.floor();
      final index1 = (index0 + 1).clamp(0, samples.length - 1);

      final frac = position - index0;
      final sample0 = samples[index0];
      final sample1 = samples[index1];

      final value0 = sample0 / 32768.0;
      final value1 = sample1 / 32768.0;
      result[i] = value0 + (value1 - value0) * frac;
    }

    return result;
  }

  /// 将 PCM16 转换为 16000Hz Float32
  static List<double> convertPcm16ToFloat32(
    List<int> pcm16Data,
    int sourceSampleRate,
  ) {
    return resample(pcm16Data, sourceSampleRate, AsrConfig.targetSampleRate);
  }

  /// 分块处理音频数据
  static List<List<double>> chunkAudio(List<double> samples, int chunkSize) {
    final chunks = <List<double>>[];
    for (int i = 0; i < samples.length; i += chunkSize) {
      final end = (i + chunkSize).clamp(0, samples.length);
      chunks.add(samples.sublist(i, end));
    }
    return chunks;
  }

  /// 计算音频能量（用于 VAD）
  static double calculateEnergy(List<double> samples) {
    if (samples.isEmpty) return 0.0;

    double sum = 0.0;
    for (final sample in samples) {
      sum += sample * sample;
    }
    return (sum / samples.length);
  }

  /// 计算分贝值
  static double energyToDecibels(double energy) {
    if (energy <= 0) return -100.0;
    return 10 * (log(energy) / ln10);
  }

  /// 检测静音
  static bool isSilence(List<double> samples, {double threshold = 0.01}) {
    final energy = calculateEnergy(samples);
    return energy < threshold;
  }

  /// 应用预加重滤波器
  static List<double> preEmphasis(List<double> samples, {double alpha = 0.97}) {
    if (samples.isEmpty) return samples;

    final result = List<double>.filled(samples.length, 0.0);
    result[0] = samples[0];

    for (int i = 1; i < samples.length; i++) {
      result[i] = samples[i] - alpha * samples[i - 1];
    }

    return result;
  }

  /// 归一化音频
  static List<double> normalize(
    List<double> samples, {
    double targetLevel = 0.95,
  }) {
    if (samples.isEmpty) return samples;

    double maxValue = 0.0;
    for (final sample in samples) {
      final abs = sample.abs();
      if (abs > maxValue) maxValue = abs;
    }

    if (maxValue < 0.001) return samples;

    final scale = targetLevel / maxValue;
    return samples.map((sample) => sample * scale).toList();
  }

  /// 裁剪静音部分
  static List<double> trimSilence(
    List<double> samples, {
    double threshold = 0.01,
    int windowSize = 400,
  }) {
    if (samples.length < windowSize * 2) return samples;

    int startIndex = 0;
    for (int i = 0; i < samples.length - windowSize; i += windowSize) {
      final window = samples.sublist(i, i + windowSize);
      if (!isSilence(window, threshold: threshold)) {
        startIndex = i;
        break;
      }
    }

    int endIndex = samples.length;
    for (int i = samples.length - windowSize; i > startIndex; i -= windowSize) {
      final window = samples.sublist(i, i + windowSize);
      if (!isSilence(window, threshold: threshold)) {
        endIndex = i + windowSize;
        break;
      }
    }

    return samples.sublist(startIndex, endIndex);
  }

  static const double ln10 = 2.302585092994046;
}
