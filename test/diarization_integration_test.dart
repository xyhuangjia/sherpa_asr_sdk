import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

void main() {
  group('SpeakerManager + Diarizer 协作', () {
    test('Diarizer 使用已注册说话人数据', () {
      // 模拟已注册说话人数据（来自 SpeakerManager.getRegisteredEmbeddings）
      final registeredSpeakers = <String, Float32List>{
        '张三': Float32List.fromList([
          0.9, 0.05, 0.05, 0.0, 0.0,
          0.0, 0.0, 0.0, 0.0, 0.0,
        ]),
        '李四': Float32List.fromList([
          0.05, 0.9, 0.05, 0.0, 0.0,
          0.0, 0.0, 0.0, 0.0, 0.0,
        ]),
      };

      final diarizer = AsrDiarizer(
        const AsrDiarizationConfig(
          enableRegisteredMatching: true,
          registeredMatchThreshold: 0.7,
          similarityThreshold: 0.5,
        ),
        registeredSpeakers: registeredSpeakers,
      );

      // 张三发言
      final zhangSanVoice = Float32List.fromList([
        0.88, 0.06, 0.06, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0,
      ]);
      final label1 = diarizer.identifySpeaker(zhangSanVoice, 2.0, 100.0);
      expect(label1, '张三');

      // 李四发言
      final liSiVoice = Float32List.fromList([
        0.06, 0.88, 0.06, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0,
      ]);
      final label2 = diarizer.identifySpeaker(liSiVoice, 2.0, 200.0);
      expect(label2, '李四');

      // 张三再次发言（重识别）
      final zhangSanAgain = Float32List.fromList([
        0.85, 0.08, 0.07, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0,
      ]);
      final label3 = diarizer.identifySpeaker(zhangSanAgain, 2.0, 300.0);
      expect(label3, '张三');
      expect(diarizer.speakerCount, 2); // 张三和李四
    });

    test('动态注册新说话人后刷新', () {
      final diarizer = AsrDiarizer(
        const AsrDiarizationConfig(
          enableRegisteredMatching: true,
          registeredMatchThreshold: 0.7,
        ),
      );

      // 开始没有已注册说话人
      final unknownVoice = Float32List.fromList([
        0.8, 0.1, 0.1, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0,
      ]);
      final label1 = diarizer.identifySpeaker(unknownVoice, 2.0, 100.0);
      expect(label1, 'Speaker 1'); // 未识别，创建新标签

      // 模拟注册新用户后刷新
      diarizer.updateRegisteredSpeakers({
        '王五': Float32List.fromList([
          0.78, 0.12, 0.1, 0.0, 0.0,
          0.0, 0.0, 0.0, 0.0, 0.0,
        ]),
      });

      // 王五发言
      final wangWuVoice = Float32List.fromList([
        0.76, 0.14, 0.1, 0.0, 0.0,
        0.0, 0.0, 0.0, 0.0, 0.0,
      ]);
      final label2 = diarizer.identifySpeaker(wangWuVoice, 2.0, 200.0);
      expect(label2, '王五');
    });

    test('已注册匹配优先于会话内匹配', () {
      // 创建已注册说话人
      final registeredSpeakers = <String, Float32List>{
        '张三': Float32List.fromList([0.9, 0.1, 0.0, 0.0, 0.0]),
      };

      final diarizer = AsrDiarizer(
        const AsrDiarizationConfig(
          enableRegisteredMatching: true,
          registeredMatchThreshold: 0.7,
          similarityThreshold: 0.5,
        ),
        registeredSpeakers: registeredSpeakers,
      );

      // 第一次发言（匹配已注册的张三）
      final voice1 = Float32List.fromList([0.88, 0.12, 0.0, 0.0, 0.0]);
      final label1 = diarizer.identifySpeaker(voice1, 2.0, 100.0);
      expect(label1, '张三');

      // 不匹配张三的发言（相似度低于 0.7，会创建新 Speaker）
      // 使用几乎垂直的向量，确保余弦相似度很低
      final voice2 = Float32List.fromList([0.0, 0.0, 1.0, 0.0, 0.0]);
      final label2 = diarizer.identifySpeaker(voice2, 2.0, 200.0);
      expect(label2, 'Speaker 2');

      // 张三再次发言（仍应匹配张三，而非 Speaker 2）
      final voice3 = Float32List.fromList([0.85, 0.15, 0.0, 0.0, 0.0]);
      final label3 = diarizer.identifySpeaker(voice3, 2.0, 300.0);
      expect(label3, '张三');
    });

    test('IdentifiedSpeaker 关联已注册用户后 displayLabel', () {
      final registeredSpeakers = <String, Float32List>{
        '张三': Float32List.fromList([0.9, 0.1, 0.0, 0.0, 0.0]),
      };

      final diarizer = AsrDiarizer(
        const AsrDiarizationConfig(
          enableRegisteredMatching: true,
          registeredMatchThreshold: 0.7,
        ),
        registeredSpeakers: registeredSpeakers,
      );

      // 张三发言
      diarizer.identifySpeaker(
        Float32List.fromList([0.88, 0.12, 0.0, 0.0, 0.0]),
        2.0,
        100.0,
      );

      // 检查 speaker 数据
      expect(diarizer.speakerCount, 1);
      final speaker = diarizer.speakers[0];
      expect(speaker.label, 'Speaker 1');
      expect(speaker.registeredName, '张三');
      expect(speaker.displayLabel, '张三');
    });
  });
}