import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_sandbox/services/mqtt_services.dart';
import 'package:mqtt_sandbox/services/mqtt_env.dart';
import 'package:mqtt_sandbox/widgets/controls_grid.dart';
import 'package:mqtt_sandbox/widgets/settings_dialog.dart';

void main() {
  runApp(const ServerboyMqttApp());
}

class ServerboyMqttApp extends StatelessWidget {
  const ServerboyMqttApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MqttEnv>(
      future: MqttEnv.load(),
      builder: (context, snapshot) {
        // Show a basic loading app while env loads
        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'Serverboy MQTT Viewer',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
              scaffoldBackgroundColor: const Color(0xFFC2C2C2),
            ),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final env = snapshot.data!;
        return ChangeNotifierProvider<MqttService>(
          create: (_) => MqttService(env: env),
          child: MaterialApp(
            title: 'Serverboy MQTT Viewer',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
              scaffoldBackgroundColor: const Color(0xFFC2C2C2),
            ),
            home: const ViewerPage(),
          ),
        );
      },
    );
  }
}

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key});

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  // --- Connection settings (edit these for your broker) ---
  String brokerHost = 'localhost';
  int brokerPort = 1883; // 1883 (mqtt) or 8883 (mqtts)
  bool useTLS = false; // set true for TLS if your broker requires it
  String username = '';
  String password = '';
  String topicPrefix = 'serverboy';

  // --- Connection state ---
  StreamSubscription<bool>? _connSub;
  StreamSubscription<FrameMeta>? _metaSub;
  StreamSubscription<Uint8List>? _frameSub;
  bool _connecting = false;
  bool _connected = false;

  // --- Frame/meta state ---
  int _frameWidth = 160;
  int _frameHeight = 144;
  String _format = 'rgba8888';
  ui.Image? _lastImage;

  @override
  void dispose() {
    _disposeImage();
    _connSub?.cancel();
    _metaSub?.cancel();
    _frameSub?.cancel();
    super.dispose();
  }

  void _disposeImage() {
    try {
      // dispose is available on recent Flutter versions
      // ignore: deprecated_member_use
      _lastImage?.dispose();
    } catch (_) {}
    _lastImage = null;
  }

  @override
  void initState() {
    super.initState();
    // Initialize defaults from the injected MqttService (which was created with env)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final svc = context.read<MqttService>();
      setState(() {
        brokerHost = svc.defaultHost;
        brokerPort = svc.defaultPort;
        useTLS = svc.defaultUseTLS;
        username = svc.defaultUsername;
        password = svc.defaultPassword;
        topicPrefix = svc.defaultTopicPrefix;
      });
    });
    // Subscriptions are set up in a post-frame callback to ensure Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<MqttService>();
      _connSub = svc.connectionStream.listen((connected) {
        if (!mounted) return;
        setState(() {
          _connected = connected;
          _connecting = false;
        });
        _showSnack(
          connected ? 'Connected to $brokerHost:$brokerPort' : 'Disconnected',
        );
      });
      _metaSub = svc.metaStream.listen((meta) {
        if (!mounted) return;
        setState(() {
          _frameWidth = meta.width;
          _frameHeight = meta.height;
          _format = meta.format;
        });
      });
      _frameSub = svc.frameStream.listen((bytes) {
        if (!mounted) return;
        if (_format != 'rgba8888') return;
        final expected = _frameWidth * _frameHeight * 4;
        if (bytes.length < expected) return;
        _decodeAndSetFrame(bytes.sublist(0, expected));
      });
      // Auto-connect on startup
      _connect();
    });
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    setState(() => _connecting = true);
    final svc = context.read<MqttService>();
    try {
      await svc.connect();
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false);
        _showSnack('MQTT connect failed: $e');
      }
    }
  }

  // MQTT message handling moved into MqttService; UI now listens to service streams.

  Future<void> _decodeAndSetFrame(Uint8List rgba) async {
    final completer = Completer<ui.Image>();
    try {
      ui.decodeImageFromPixels(
        rgba,
        _frameWidth,
        _frameHeight,
        ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );
      final img = await completer.future;
      if (!mounted) {
        // dispose if the widget is gone
        try {
          img.dispose();
        } catch (_) {}
        return;
      }
      _disposeImage();
      setState(() {
        _lastImage = img;
      });
    } catch (_) {
      // ignore decode failures
    }
  }

  void _publishKey(int key, bool down) {
    context.read<MqttService>().sendKey(key, down: down);
  }

  void _publishRestart() {
    context.read<MqttService>().sendRestart();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serverboy MQTT Viewer'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _frameWidth / _frameHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: const Color(0xFF333333)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _lastImage == null
                          ? const Center(
                              child: Text(
                                'Waiting for frame...\nSubscribe to ${'meta'} and ${'frame'}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
                              ),
                            )
                          : FittedBox(
                              fit: BoxFit.contain,
                              child: RawImage(image: _lastImage),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ControlsGrid(
                onKeyDown: (k) => _publishKey(k, true),
                onKeyUp: (k) => _publishKey(k, false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => const SettingsDialog(),
    );
  }
}
