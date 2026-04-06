import 'package:flutter_test/flutter_test.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

void main() {
  group('AsrTimestamp', () {
    test('fromTokensAndTimestamps 正常构建', () {
      final result = AsrTimestamp.fromTokensAndTimestamps(
        ['你', '好', '世', '界'],
        [0.1, 0.3, 0.5, 0.7],
      );

      expect(result.length, 4);
      expect(result[0].token, '你');
      expect(result[0].startTime, 0.1);
      expect(result[0].duration, closeTo(0.2, 0.001));
      expect(result[1].token, '好');
      expect(result[1].startTime, 0.3);
      expect(result[1].duration, closeTo(0.2, 0.001));
      expect(result[2].token, '世');
      expect(result[2].startTime, 0.5);
      expect(result[2].duration, closeTo(0.2, 0.001));
      expect(result[3].token, '界');
      expect(result[3].startTime, 0.7);
      expect(result[3].duration, 0.0);
    });

    test('fromTokensAndTimestamps 空列表', () {
      final result = AsrTimestamp.fromTokensAndTimestamps([], []);
      expect(result, isEmpty);
    });

    test('fromTokensAndTimestamps tokens 多于 timestamps', () {
      final result = AsrTimestamp.fromTokensAndTimestamps(
        ['你', '好', '世', '界'],
        [0.1, 0.3],
      );

      expect(result.length, 4);
      expect(result[0].startTime, 0.1);
      expect(result[0].duration, closeTo(0.2, 0.001));
      expect(result[1].startTime, 0.3);
      expect(result[1].duration, 0.0);
      expect(result[2].startTime, 0.3); // 使用最后一个时间戳
      expect(result[2].duration, 0.0);
      expect(result[3].startTime, 0.3);
      expect(result[3].duration, 0.0);
    });

    test('fromTokensAndTimestamps 单个 token', () {
      final result = AsrTimestamp.fromTokensAndTimestamps(['是'], [1.5]);

      expect(result.length, 1);
      expect(result[0].token, '是');
      expect(result[0].startTime, 1.5);
      expect(result[0].duration, 0.0);
    });

    test('toString 格式', () {
      final ts = AsrTimestamp(token: '你', startTime: 0.1, duration: 0.2);
      expect(ts.toString(), contains('你'));
      expect(ts.toString(), contains('0.10'));
    });
  });

  group('AsrResult', () {
    test('创建中间结果', () {
      final result = AsrResult(
        text: '你好',
        timestamps: [
          AsrTimestamp(token: '你', startTime: 0.0, duration: 0.1),
          AsrTimestamp(token: '好', startTime: 0.1, duration: 0.0),
        ],
        isFinal: false,
      );

      expect(result.text, '你好');
      expect(result.timestamps.length, 2);
      expect(result.isFinal, false);
    });

    test('创建最终结果', () {
      final result = AsrResult(
        text: '你好世界',
        timestamps: [],
        isFinal: true,
      );

      expect(result.text, '你好世界');
      expect(result.isFinal, true);
    });

    test('toString 包含关键信息', () {
      final result = AsrResult(
        text: '你好',
        timestamps: [
          AsrTimestamp(token: '你', startTime: 0.0, duration: 0.1),
        ],
        isFinal: false,
      );

      expect(result.toString(), contains('你好'));
      expect(result.toString(), contains('isFinal: false'));
    });
  });
}
