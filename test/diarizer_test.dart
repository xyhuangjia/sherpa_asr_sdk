import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

void main() {
  group('IdentifiedSpeaker', () {
    test('创建时包含初始 embedding', () {
      final embedding = Float32List.fromList([0.1, 0.2, 0.3]);
      final speaker = IdentifiedSpeaker(
        label: 'Speaker 1',
        initialEmbedding: embedding,
        firstSeenAt: 100.0,
      );

      expect(speaker.label, 'Speaker 1');
      expect(speaker.registeredName, null);
      expect(speaker.embeddings.length, 1);
      expect(speaker.utteranceCount, 1);
    });

    test('displayLabel 优先使用 registeredName', () {
      final embedding = Float32List.fromList([0.1, 0.2, 0.3]);

      // 无 registeredName
      final speaker1 = IdentifiedSpeaker(
        label: 'Speaker 1',
        initialEmbedding: embedding,
        firstSeenAt: 100.0,
      );
      expect(speaker1.displayLabel, 'Speaker 1');

      // 有 registeredName
      final speaker2 = IdentifiedSpeaker(
        label: 'Speaker 2',
        registeredName: '张三',
        initialEmbedding: embedding,
        firstSeenAt: 100.0,
      );
      expect(speaker2.displayLabel, '张三');
    });

    test('addEmbedding 累积并保持上限', () {
      final embedding = Float32List.fromList([0.1, 0.2, 0.3]);
      final speaker = IdentifiedSpeaker(
        label: 'Speaker 1',
        initialEmbedding: embedding,
        firstSeenAt: 100.0,
        maxEmbeddings: 5,
      );

      expect(speaker.embeddings.length, 1);
      expect(speaker.utteranceCount, 1);

      // 添加第二个
      speaker.addEmbedding(Float32List.fromList([0.4, 0.5, 0.6]));
      expect(speaker.embeddings.length, 2);
      expect(speaker.utteranceCount, 2);

      // 添加直到超过上限
      for (int i = 0; i < speaker.maxEmbeddings; i++) {
        speaker.addEmbedding(Float32List.fromList([i * 0.1, i * 0.2, i * 0.3]));
      }
      expect(speaker.embeddings.length, speaker.maxEmbeddings);
    });

    test('bestMatchScore 计算最佳匹配', () {
      // 创建两个不同的 embedding
      final embedding1 = Float32List.fromList([1.0, 0.0, 0.0]);
      final embedding2 = Float32List.fromList([0.0, 1.0, 0.0]);

      final speaker = IdentifiedSpeaker(
        label: 'Speaker 1',
        initialEmbedding: embedding1,
        firstSeenAt: 100.0,
      );
      speaker.addEmbedding(embedding2);

      // 测试匹配：与 embedding1 完全相同
      final test1 = Float32List.fromList([1.0, 0.0, 0.0]);
      expect(speaker.bestMatchScore(test1), closeTo(1.0, 0.01));

      // 测试匹配：与 embedding2 完全相同
      final test2 = Float32List.fromList([0.0, 1.0, 0.0]);
      expect(speaker.bestMatchScore(test2), closeTo(1.0, 0.01));

      // 测试匹配：与两者都不同（计算正确的余弦相似度）
      // [0.5, 0.5, 0.0] 与 [1.0, 0.0, 0.0] 的相似度 = 0.5 / sqrt(0.5) ≈ 0.707
      final test3 = Float32List.fromList([0.5, 0.5, 0.0]);
      expect(speaker.bestMatchScore(test3), closeTo(0.707, 0.01));
    });
  });

  group('AsrDiarizationConfig', () {
    test('默认配置值', () {
      const config = AsrDiarizationConfig();

      expect(config.similarityThreshold, 0.5);
      expect(config.maxSpeakers, 20);
      expect(config.minSpeechDuration, 1.0);
      expect(config.enableRegisteredMatching, true);
      expect(config.registeredMatchThreshold, 0.7);
      expect(config.maxEmbeddingsPerSpeaker, 5);
    });

    test('copyWith 更新部分配置', () {
      const original = AsrDiarizationConfig();
      final updated = original.copyWith(
        similarityThreshold: 0.6,
        enableRegisteredMatching: false,
      );

      expect(updated.similarityThreshold, 0.6);
      expect(updated.enableRegisteredMatching, false);
      expect(updated.maxSpeakers, original.maxSpeakers); // 保持不变
      expect(updated.registeredMatchThreshold, original.registeredMatchThreshold);
    });
  });

  group('AsrDiarizer 分层匹配', () {
    test('Layer 1: 匹配已注册说话人', () {
      // 创建已注册说话人数据（模拟"张三"的 embedding）
      final zhangSanEmbedding = Float32List.fromList([
        0.9, 0.1, 0.05, 0.05, 0.0,
      ]);
      final registeredSpeakers = {'张三': zhangSanEmbedding};

      final diarizer = AsrDiarizer(
        const AsrDiarizationConfig(
          enableRegisteredMatching: true,
          registeredMatchThreshold: 0.7,
        ),
        registeredSpeakers: registeredSpeakers,
      );

      // 发送与张三高度相似的 embedding
      final incoming = Float32List.fromList([
        0.88, 0.12, 0.06, 0.04, 0.0,
      ]);
      final label = diarizer.identifySpeaker(incoming, 2.0, 100.0);

      expect(label, '张三');
      expect(diarizer.speakerCount, 1);
      expect(diarizer.speakers[0].registeredName, '张三');
    });

    test('Layer 2: 匹配会话内说话人（重识别）', () {
      final diarizer = AsrDiarizer(
        const AsrDiarizationConfig(
          enableRegisteredMatching: false, // 禁用 Layer 1
          similarityThreshold: 0.5,
        ),
      );

      // 第一次发言
      final embedding1 = Float32List.fromList([0.5, 0.5, 0.0, 0.0, 0.0]);
      final label1 = diarizer.identifySpeaker(embedding1, 2.0, 100.0);
      expect(label1, 'Speaker 1');

      // 第二个不同说话人
      final embedding2 = Float32List.fromList([0.0, 0.0, 0.5, 0.5, 0.0]);
      final label2 = diarizer.identifySpeaker(embedding2, 2.0, 200.0);
      expect(label2, 'Speaker 2');

      // 重识别：第一个说话人再次发言（相似度 > 0.5）
      final embedding1Again = Float32List.fromList([0.52, 0.48, 0.0, 0.0, 0.0]);
      final label3 = diarizer.identifySpeaker(embedding1Again, 2.0, 300.0);
      expect(label3, 'Speaker 1'); // 应识别为同一人
      expect(diarizer.speakerCount, 2); // 不应增加新说话人
    });

    test('Layer 3: 创建新说话人', () {
      final diarizer = AsrDiarizer(const AsrDiarizationConfig());

      // 第一个说话人
      final embedding1 = Float32List.fromList([1.0, 0.0, 0.0, 0.0, 0.0]);
      final label1 = diarizer.identifySpeaker(embedding1, 2.0, 100.0);
      expect(label1, 'Speaker 1');

      // 完全不同的 embedding（低相似度）
      final embedding2 = Float32List.fromList([0.0, 0.0, 0.0, 0.0, 1.0]);
      final label2 = diarizer.identifySpeaker(embedding2, 2.0, 200.0);
      expect(label2, 'Speaker 2'); // 新说话人
    });

    test('短语音段使用上一个说话人', () {
      final diarizer = AsrDiarizer(const AsrDiarizationConfig(
        minSpeechDuration: 1.0,
      ));

      // 正常发言
      final embedding = Float32List.fromList([0.5, 0.5, 0.0, 0.0, 0.0]);
      diarizer.identifySpeaker(embedding, 2.0, 100.0);

      // 短语音段（低于 minSpeechDuration）
      final shortEmbedding = Float32List.fromList([0.0, 0.0, 0.5, 0.5, 0.0]);
      final label = diarizer.identifySpeaker(shortEmbedding, 0.5, 200.0);
      expect(label, 'Speaker 1'); // 使用上一个
    });

    test('updateRegisteredSpeakers 动态更新', () {
      final diarizer = AsrDiarizer(const AsrDiarizationConfig());

      expect(diarizer.speakerCount, 0);

      // 动态添加已注册说话人
      final newRegistered = {
        '李四': Float32List.fromList([0.8, 0.2, 0.0, 0.0, 0.0]),
      };
      diarizer.updateRegisteredSpeakers(newRegistered);

      // 发送与李四相似的 embedding
      final incoming = Float32List.fromList([0.78, 0.22, 0.0, 0.0, 0.0]);
      final label = diarizer.identifySpeaker(incoming, 2.0, 100.0);

      expect(label, '李四');
    });

    test('达到最大说话人数时使用最相似的', () {
      final diarizer = AsrDiarizer(const AsrDiarizationConfig(
        maxSpeakers: 2,
      ));

      // 添加两个说话人
      diarizer.identifySpeaker(Float32List.fromList([1.0, 0.0, 0.0, 0.0, 0.0]), 2.0, 100.0);
      diarizer.identifySpeaker(Float32List.fromList([0.0, 0.0, 0.0, 0.0, 1.0]), 2.0, 200.0);

      expect(diarizer.speakerCount, 2);

      // 第三个不同的 embedding
      final incoming = Float32List.fromList([0.9, 0.1, 0.0, 0.0, 0.0]);
      final label = diarizer.identifySpeaker(incoming, 2.0, 300.0);

      // 应匹配最相似的（Speaker 1）
      expect(label, 'Speaker 1');
      expect(diarizer.speakerCount, 2); // 不增加
    });
  });
}