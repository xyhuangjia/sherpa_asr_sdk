import 'package:flutter_test/flutter_test.dart';

import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

void main() {
  group('AsrSdkState', () {
    test('initial state is notInitialized', () {
      expect(AsrSdkState.notInitialized.index, 0);
    });

    test('all states are defined', () {
      expect(AsrSdkState.values.length, 5);
      expect(AsrSdkState.values.contains(AsrSdkState.notInitialized), true);
      expect(AsrSdkState.values.contains(AsrSdkState.initializing), true);
      expect(AsrSdkState.values.contains(AsrSdkState.ready), true);
      expect(AsrSdkState.values.contains(AsrSdkState.started), true);
      expect(AsrSdkState.values.contains(AsrSdkState.error), true);
    });
  });

  group('AsrState', () {
    test('all states are defined', () {
      expect(AsrState.values.length, 6);
      expect(AsrState.values.contains(AsrState.idle), true);
      expect(AsrState.values.contains(AsrState.loading), true);
      expect(AsrState.values.contains(AsrState.ready), true);
      expect(AsrState.values.contains(AsrState.readyOnline), true);
      expect(AsrState.values.contains(AsrState.listening), true);
      expect(AsrState.values.contains(AsrState.error), true);
    });
  });

  group('AsrConfig', () {
    test('target sample rate is 16000', () {
      expect(AsrConfig.targetSampleRate, 16000);
    });

    test('num channels is 1', () {
      expect(AsrConfig.numChannels, 1);
    });

    test('model files are defined', () {
      expect(AsrConfig.baseModelFiles.length, greaterThan(0));
      expect(AsrConfig.streamingBilingualModelFiles.length, greaterThan(0));
    });
  });

  group('AsrSdk', () {
    test('initial state check', () {
      expect(AsrSdk.state, AsrSdkState.notInitialized);
      expect(AsrSdk.isInitialized, false);
      expect(AsrSdk.isStarted, false);
      expect(AsrSdk.isListening, false);
    });
  });
}
