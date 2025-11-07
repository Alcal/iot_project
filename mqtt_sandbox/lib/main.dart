import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_sandbox/services/mqtt_services.dart';
import 'package:mqtt_sandbox/services/mqtt_env.dart';

void main() {
  runApp(const ServerboyMqttApp());
}

class ServerboyMqttApp extends StatelessWidget {
  const ServerboyMqttApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<MqttService>(
      create: (_) => MqttService(),
      child: MaterialApp(
        title: 'Serverboy MQTT Viewer',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        ),
        home: const ViewerPage(),
      ),
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
    // Load environment from assets/env.json (or overridden with --dart-define=ENV_FILE)
    () async {
      final env = await MqttEnv.load();
      if (!mounted) return;
      setState(() {
        brokerHost = env.host;
        brokerPort = env.port;
        useTLS = env.tls;
        username = env.username;
        password = env.password;
        topicPrefix = env.prefix;
      });
    }();
    // Subscriptions are set up in a post-frame callback to ensure Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<MqttService>();
      _connSub = svc.connectionStream.listen((connected) {
        if (!mounted) return;
        setState(() {
          _connected = connected;
          _connecting = false;
        });
        _showSnack(connected
            ? 'Connected to $brokerHost:$brokerPort'
            : 'Disconnected');
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
    });
  }

  Future<void> _connect() async {
    if (_connecting || _connected) return;
    setState(() => _connecting = true);
    final svc = context.read<MqttService>();
    try {
      await svc.connect(
        host: brokerHost,
        port: brokerPort,
        useTLS: useTLS,
        username: username,
        password: password,
        topicPrefix: topicPrefix,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _connecting = false);
        _showSnack('MQTT connect failed: $e');
      }
    }
  }

  void _disconnect() {
    context.read<MqttService>().disconnect();
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

  void _publishKey(String key, bool down) {
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
      backgroundColor: const Color(0xFF111111),
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
              _ControlsGrid(
                onKeyDown: (k) => _publishKey(k, true),
                onKeyUp: (k) => _publishKey(k, false),
                onRestart: _publishRestart,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _connected ? _disconnect : _connect,
                      icon: Icon(_connected ? Icons.link_off : Icons.link),
                      label: Text(
                        _connected
                            ? 'Disconnect'
                            : (_connecting ? 'Connecting…' : 'Connect'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    final hostCtrl = TextEditingController(text: brokerHost);
    final portCtrl = TextEditingController(text: brokerPort.toString());
    final userCtrl = TextEditingController(text: username);
    final passCtrl = TextEditingController(text: password);
    final prefixCtrl = TextEditingController(text: topicPrefix);
    bool tls = useTLS;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('MQTT Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Host'),
                  controller: hostCtrl,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Port'),
                  controller: portCtrl,
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Username'),
                  controller: userCtrl,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Password'),
                  controller: passCtrl,
                  obscureText: true,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Topic Prefix'),
                  controller: prefixCtrl,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Use TLS'),
                    const Spacer(),
                    Switch(value: tls, onChanged: (v) => tls = v),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  brokerHost = hostCtrl.text.trim();
                  brokerPort = int.tryParse(portCtrl.text.trim()) ?? brokerPort;
                  username = userCtrl.text;
                  password = passCtrl.text;
                  topicPrefix = prefixCtrl.text.trim().replaceAll(
                    RegExp(r'/+$'),
                    '',
                  );
                  useTLS = tls;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _ControlsGrid extends StatelessWidget {
  const _ControlsGrid({
    required this.onKeyDown,
    required this.onKeyUp,
    required this.onRestart,
  });

  final void Function(String key) onKeyDown;
  final void Function(String key) onKeyUp;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              label: 'UP',
              onDown: () => onKeyDown('UP'),
              onUp: () => onKeyUp('UP'),
            ),
            const SizedBox(width: 8),
            _ControlButton(
              label: 'A',
              onDown: () => onKeyDown('A'),
              onUp: () => onKeyUp('A'),
            ),
            const SizedBox(width: 8),
            _ControlButton(
              label: 'B',
              onDown: () => onKeyDown('B'),
              onUp: () => onKeyUp('B'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ControlButton(
              label: 'LEFT',
              onDown: () => onKeyDown('LEFT'),
              onUp: () => onKeyUp('LEFT'),
            ),
            const SizedBox(width: 8),
            _ControlButton(
              label: 'DOWN',
              onDown: () => onKeyDown('DOWN'),
              onUp: () => onKeyUp('DOWN'),
            ),
            const SizedBox(width: 8),
            _ControlButton(
              label: 'RIGHT',
              onDown: () => onKeyDown('RIGHT'),
              onUp: () => onKeyUp('RIGHT'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => onKeyDown('START'),
              onLongPress: null,
              onHover: null,
              child: const Text('START'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => onKeyDown('SELECT'),
              child: const Text('SELECT'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: onRestart, child: const Text('RESTART')),
          ],
        ),
      ],
    );
  }
}

class _ControlButton extends StatefulWidget {
  const _ControlButton({
    required this.label,
    required this.onDown,
    required this.onUp,
  });

  final String label;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _pressed = false;

  void _handleDown() {
    if (_pressed) return;
    setState(() => _pressed = true);
    widget.onDown();
  }

  void _handleUp() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _handleDown(),
      onPointerUp: (_) => _handleUp(),
      onPointerCancel: (_) => _handleUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFF2A2A2A) : const Color(0xFF333333),
          border: Border.all(color: const Color(0xFF444444)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
