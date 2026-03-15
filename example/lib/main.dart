import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sherpa_asr_sdk/sherpa_asr_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AsrSdk.setLogger(DefaultAsrLogger());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sherpa ASR Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  AsrSdkState _sdkState = AsrSdkState.notInitialized;
  String _status = 'Not initialized';
  String _result = '';
  String _partialResult = '';
  double _initProgress = 0.0;
  double _downloadProgress = 0.0;
  bool _isDownloading = false;
  StreamSubscription<AsrSdkState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _listenToStateChanges();
    _initSdk();
  }

  void _listenToStateChanges() {
    _stateSubscription = AsrSdk.stateStream.listen((state) {
      setState(() => _sdkState = state);
    });
  }

  Future<void> _initSdk() async {
    if (AsrSdk.isInitialized) {
      setState(() => _status = 'Ready');
      await AsrSdk.start();
      return;
    }

    setState(() {
      _status = 'Initializing...';
      _initProgress = 0.0;
    });

    final success = await AsrSdk.initialize(
      onProgress: (progress) {
        setState(() => _initProgress = progress);
      },
      onStatus: (status) {
        setState(() => _status = status);
      },
    );

    if (success) {
      setState(() => _status = 'Ready');
      await AsrSdk.start();
    } else {
      setState(() {
        _status = 'Model not found - Download required';
        _initProgress = 0.0;
      });
    }
  }

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _status = 'Downloading model...';
    });

    final manager = SherpaModelsManager.instance;
    final success = await manager.downloadStreamingBilingualModels(
      onProgress: (progress) {
        setState(() => _downloadProgress = progress);
      },
      onStatusChange: (status) {
        setState(() => _status = status);
      },
    );

    setState(() {
      _isDownloading = false;
      _downloadProgress = 0.0;
    });

    if (success) {
      setState(() => _status = 'Model downloaded, initializing...');
      await _initSdk();
    } else {
      setState(() => _status = 'Download failed');
    }
  }

  void _startRecognition() {
    setState(() {
      _result = '';
      _partialResult = '';
      _status = 'Listening...';
    });

    AsrSdk.recognize().listen(
      (text) {
        setState(() {
          _partialResult = text;
        });
      },
      onError: (error) {
        setState(() {
          _status = 'Error: $error';
        });
        _showSnackBar('Recognition error: $error');
      },
      onDone: () {
        setState(() {
          if (_partialResult.isNotEmpty) {
            _result = _partialResult;
          }
          _partialResult = '';
          _status = 'Ready';
        });
      },
    );
  }

  Future<void> _stopRecognition() async {
    await AsrSdk.stopRecognition();
    setState(() {
      _status = 'Ready';
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Sherpa ASR Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 24),
            _buildResultCard(),
            const SizedBox(height: 24),
            _buildControlButtons(),
            const SizedBox(height: 24),
            _buildModelSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getStatusIcon(), color: _getStatusColor()),
                const SizedBox(width: 8),
                Text('Status', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(_status, style: Theme.of(context).textTheme.bodyMedium),
            if (_initProgress > 0 && _initProgress < 1.0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _initProgress),
              Text(
                '${(_initProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.record_voice_over),
                const SizedBox(width: 8),
                Text(
                  'Recognition Result',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _partialResult.isNotEmpty
                    ? _partialResult
                    : _result.isNotEmpty
                    ? _result
                    : 'Press the microphone button to start',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _partialResult.isNotEmpty
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    final isReady = AsrSdk.isStarted;
    final isListening = AsrSdk.isListening;
    final needsModel = !AsrSdk.isInitialized;

    if (needsModel) {
      return Card(
        color: const Color.fromARGB(255, 136, 101, 45),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Please download the model first to enable speech recognition',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (!isListening)
          FloatingActionButton.large(
            heroTag: 'mic',
            onPressed: isReady ? _startRecognition : null,
            child: const Icon(Icons.mic),
          ),
        if (isListening)
          FloatingActionButton.large(
            heroTag: 'stop',
            onPressed: _stopRecognition,
            backgroundColor: Colors.red,
            child: const Icon(Icons.stop),
          ),
      ],
    );
  }

  Widget _buildModelSection() {
    final needsDownload = !AsrSdk.isInitialized && !_isDownloading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  needsDownload ? Icons.warning_amber : Icons.check_circle,
                  color: needsDownload ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'Model Management',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isDownloading) ...[
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 8),
              Text(
                'Downloading: ${(_downloadProgress * 100).toInt()}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (needsDownload) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Model required for speech recognition. Click below to download (~30MB)',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadModel,
                  icon: const Icon(Icons.download),
                  label: const Text('Download Model'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Model is ready', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_sdkState) {
      case AsrSdkState.notInitialized:
        return Icons.hourglass_empty;
      case AsrSdkState.initializing:
        return Icons.sync;
      case AsrSdkState.ready:
        return Icons.check_circle;
      case AsrSdkState.started:
        return Icons.mic;
      case AsrSdkState.error:
        return Icons.error;
    }
  }

  Color _getStatusColor() {
    switch (_sdkState) {
      case AsrSdkState.notInitialized:
        return Colors.grey;
      case AsrSdkState.initializing:
        return Colors.orange;
      case AsrSdkState.ready:
      case AsrSdkState.started:
        return Colors.green;
      case AsrSdkState.error:
        return Colors.red;
    }
  }

  void _showInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sherpa ASR SDK Demo'),
            SizedBox(height: 8),
            Text('Offline speech recognition using Sherpa-onnx.'),
            SizedBox(height: 16),
            Text('Features:'),
            SizedBox(height: 8),
            Text('• Real-time streaming recognition'),
            Text('• Offline processing (no internet needed)'),
            Text('• Chinese & English support'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    AsrSdk.stop();
    super.dispose();
  }
}
