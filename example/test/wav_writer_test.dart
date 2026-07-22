import 'dart:io';
import 'dart:typed_data';

import 'package:example/utils/wav_writer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'rapid PCM writes are serialized before stop updates the WAV header',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wav_writer_test_',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      final writer = WavWriter(filePath: '${directory.path}/recording.wav');

      await writer.start();

      final chunk = Uint8List(16 * 1024);
      for (var i = 0; i < 64; i++) {
        writer.writePcm16(chunk);
      }

      await writer.stop();

      final file = File('${directory.path}/recording.wav');
      expect(await file.length(), 44 + chunk.length * 64);
    },
  );
}
