import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:iot_gameboy/services/mqtt_env.dart';
import 'package:iot_gameboy/services/logger.dart';
import 'package:iot_gameboy/services/mqtt_client_io.dart'
    if (dart.library.html) 'package:iot_gameboy/services/mqtt_client_web.dart'
    as mqtt_factory;

class FrameMeta {
  const FrameMeta({
    required this.width,
    required this.height,
    required this.format,
  });

  final int width;
  final int height;
  final String format;
}

class MqttService extends ChangeNotifier {
  late String _host;
  late int _port;
  late bool _useTLS;
  late String? _username;
  late String? _password;
  late String _topicPrefix;
  MqttService({MqttEnv? env}) {
    if (env != null) {
      _host = env.host;
      _port = env.port;
      _useTLS = env.tls;
      _username = env.username.isEmpty ? null : env.username;
      _password = env.password.isEmpty ? null : env.password;
      _topicPrefix = env.prefix;
    }
  }

  MqttClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  final StreamController<bool> _connectionCtrl =
      StreamController<bool>.broadcast();
  final StreamController<FrameMeta> _metaCtrl =
      StreamController<FrameMeta>.broadcast();
  final StreamController<Uint8List> _frameCtrl =
      StreamController<Uint8List>.broadcast();
  final StreamController<Uint8List> _audioCtrl =
      StreamController<Uint8List>.broadcast();

  Stream<bool> get connectionStream => _connectionCtrl.stream;
  Stream<FrameMeta> get metaStream => _metaCtrl.stream;
  Stream<Uint8List> get frameStream => _frameCtrl.stream;
  Stream<Uint8List> get audioStream => _audioCtrl.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  // Expose current/default configuration (initialized from env if provided)
  String get defaultHost => _host;
  int get defaultPort => _port;
  bool get defaultUseTLS => _useTLS;
  String get defaultUsername => _username ?? '';
  String get defaultPassword => _password ?? '';
  String get defaultTopicPrefix => _topicPrefix;

  /// Update the MQTT configuration used by this service.
  /// If currently connected, the caller should handle disconnect/reconnect.
  void updateConfig({
    String? host,
    int? port,
    bool? useTLS,
    String? username,
    String? password,
    String? topicPrefix,
  }) {
    if (host != null && host.isNotEmpty) {
      _host = host;
    }
    if (port != null && port > 0) {
      _port = port;
    }
    if (useTLS != null) {
      _useTLS = useTLS;
    }
    if (username != null) {
      _username = username.isEmpty ? null : username;
    }
    if (password != null) {
      _password = password.isEmpty ? null : password;
    }
    if (topicPrefix != null) {
      _topicPrefix = topicPrefix.replaceAll(RegExp(r'/+$'), '');
    }
  }

  Future<void> connect() async {
    if (isConnected) return;

    // Use a safe upper bound for web (avoid 1 << 32 which may compile oddly)
    final randomSuffix = Random().nextInt(0x7fffffff);
    final clientId =
        'mqtt_viewer_${DateTime.now().microsecondsSinceEpoch}_${randomSuffix.toRadixString(36)}';
    final client = mqtt_factory.createMqttClient(
      host: _host,
      port: _port,
      clientId: clientId,
      useTLS: _useTLS,
    );

    client.logging(on: false);

    client.onDisconnected = () {
      _connectionCtrl.add(false);
      notifyListeners();
    };

    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    try {
      await client.connect(_username, _password);
    } catch (e) {
      client.disconnect();
      _connectionCtrl.add(false);
      notifyListeners();
      log.e('MQTT connection failed', e);
      rethrow;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      client.disconnect();
      _connectionCtrl.add(false);
      throw StateError('Connection failed: ${client.connectionStatus?.state}');
    }

    client.subscribe('$_topicPrefix/meta', MqttQos.atMostOnce);
    client.subscribe('$_topicPrefix/frame', MqttQos.atMostOnce);
    client.subscribe('$_topicPrefix/audio', MqttQos.atMostOnce);

    _subscription?.cancel();
    _subscription = client.updates?.listen(_handleUpdates);

    _client = client;
    _connectionCtrl.add(true);
    notifyListeners();
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _client = null;
    _connectionCtrl.add(false);
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _client = null;

    _metaCtrl.close();
    _frameCtrl.close();
    _audioCtrl.close();
    _connectionCtrl.close();
    super.dispose();
  }

  void sendKey(int key, {required bool down}) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final topic = '$_topicPrefix/input/${down ? 'keydown' : 'keyup'}';
    final builder = MqttClientPayloadBuilder()..addUTF8String(key.toString());
    client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  void sendRestart() {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final builder = MqttClientPayloadBuilder();
    client.publishMessage(
      '$_topicPrefix/control/restart',
      MqttQos.atMostOnce,
      builder.payload!,
    );
  }

  void _handleUpdates(List<MqttReceivedMessage<MqttMessage>> events) {
    for (final event in events) {
      final message = event.payload;
      if (message is! MqttPublishMessage) continue;
      final topic = event.topic;
      final bytes = Uint8List.fromList(message.payload.message);

      if (topic.endsWith('/meta')) {
        try {
          final meta = json.decode(utf8.decode(bytes)) as Map<String, dynamic>;
          final width = meta['width'] is int
              ? meta['width'] as int
              : int.tryParse('${meta['width']}') ?? 160;
          final height = meta['height'] is int
              ? meta['height'] as int
              : int.tryParse('${meta['height']}') ?? 144;
          final format = (meta['format'] ?? 'rgba8888').toString();
          _metaCtrl.add(
            FrameMeta(width: width, height: height, format: format),
          );
        } catch (_) {
          log.d('Ignoring malformed meta message on topic: $topic');
        }
        continue;
      }

      if (topic.endsWith('/frame')) {
        _frameCtrl.add(bytes);
        continue;
      }
      if (topic.endsWith('/audio')) {
        _audioCtrl.add(bytes);
        continue;
      }
    }
  }
}
