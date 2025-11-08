import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_sandbox/services/mqtt_services.dart';
import 'package:mqtt_sandbox/services/mqtt_env.dart';
import 'package:mqtt_sandbox/widgets/controls_grid.dart';
import 'package:mqtt_sandbox/widgets/settings_dialog.dart';
import 'package:mqtt_sandbox/widgets/game_screen.dart';
import 'package:mqtt_sandbox/services/logger.dart';

void main() {
  log.init();
  FlutterError.onError = (details) {
    log.flutterError(details);
    FlutterError.presentError(details);
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    log.safeError('Uncaught platform error', error, stack);
    return true;
  };
  runZonedGuarded(
    () {
      runApp(const ServerboyMqttApp());
    },
    (error, stack) {
      log.safeError('Uncaught zone error', error, stack);
    },
  );
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
  // --- Connection state ---
  StreamSubscription<bool>? _connSub;
  bool _connecting = false;
  bool _connected = false;

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Subscriptions are set up in a post-frame callback to ensure Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<MqttService>();
      _connSub = svc.connectionStream.listen((connected) {
        if (!mounted) return;
        setState(() {
          _connected = connected;
          _connecting = false;
        });
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

  void _publishKey(int key, bool down) {
    context.read<MqttService>().sendKey(key, down: down);
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
              Expanded(child: Center(child: const GameScreen())),
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
