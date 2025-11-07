import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

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

class MqttService {
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  String _host = 'localhost';
  int _port = 1883;
  bool _useTLS = false;
  String? _username;
  String? _password;
  String _topicPrefix = 'serverboy';

  final StreamController<bool> _connectionCtrl =
      StreamController<bool>.broadcast();
  final StreamController<FrameMeta> _metaCtrl =
      StreamController<FrameMeta>.broadcast();
  final StreamController<Uint8List> _frameCtrl =
      StreamController<Uint8List>.broadcast();

  Stream<bool> get connectionStream => _connectionCtrl.stream;
  Stream<FrameMeta> get metaStream => _metaCtrl.stream;
  Stream<Uint8List> get frameStream => _frameCtrl.stream;

  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect({
    required String host,
    required int port,
    required bool useTLS,
    String? username,
    String? password,
    required String topicPrefix,
  }) async {
    if (isConnected) return;

    _host = host;
    _port = port;
    _useTLS = useTLS;
    _username = (username != null && username.isEmpty) ? null : username;
    _password = (password != null && password.isEmpty) ? null : password;
    _topicPrefix = topicPrefix.replaceAll(RegExp(r'/+$'), '');

    final clientId =
        'mqtt_viewer_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 32)}';
    final client = MqttServerClient.withPort(_host, clientId, _port);

    client.logging(on: false);
    client.secure = _useTLS;
    client.keepAlivePeriod = 20;

    client.onDisconnected = () {
      _connectionCtrl.add(false);
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
      rethrow;
    }

    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      client.disconnect();
      _connectionCtrl.add(false);
      throw StateError('Connection failed: ${client.connectionStatus?.state}');
    }

    client.subscribe('$_topicPrefix/meta', MqttQos.atMostOnce);
    client.subscribe('$_topicPrefix/frame', MqttQos.atMostOnce);

    _subscription?.cancel();
    _subscription = client.updates?.listen(_handleUpdates);

    _client = client;
    _connectionCtrl.add(true);
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _client = null;
    _connectionCtrl.add(false);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _client = null;

    _metaCtrl.close();
    _frameCtrl.close();
    _connectionCtrl.close();
  }

  void sendKey(String key, {required bool down}) {
    final client = _client;
    if (client == null ||
        client.connectionStatus?.state != MqttConnectionState.connected) {
      return;
    }
    final topic = '$_topicPrefix/input/${down ? 'keydown' : 'keyup'}';
    final builder = MqttClientPayloadBuilder()
      ..addUTF8String(key.toUpperCase());
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
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
          // ignore malformed meta
        }
        continue;
      }

      if (topic.endsWith('/frame')) {
        _frameCtrl.add(bytes);
        continue;
      }
    }
  }
}
