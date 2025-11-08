import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mqtt_sandbox/services/logger.dart';

class MqttEnv {
  MqttEnv({
    required this.host,
    required this.port,
    required this.tls,
    required this.username,
    required this.password,
    required this.prefix,
  });

  final String host;
  final int port;
  final bool tls;
  final String username;
  final String password;
  final String prefix;

  static const String _defaultEnvPath = 'assets/env.json';
  static const String _envOverridePath = String.fromEnvironment(
    'ENV_FILE',
    defaultValue: _defaultEnvPath,
  );

  static Future<MqttEnv> load() async {
    Map<String, dynamic> jsonMap = {};
    try {
      final contents = await rootBundle.loadString(_envOverridePath);
      jsonMap = json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      log.i('ENV file not found or invalid at $_envOverridePath. Using defaults. ($e)');
    }

    String host = (jsonMap['MQTT_HOST'] ?? 'localhost').toString();
    int port;
    final portRaw = jsonMap['MQTT_PORT'];
    if (portRaw is int) {
      port = portRaw;
    } else {
      port = int.tryParse('$portRaw') ?? 1883;
    }

    // Prefer explicit MQTT_TLS; otherwise infer TLS from common secure port 8883
    bool tls;
    final tlsRaw = jsonMap['MQTT_TLS'];
    if (tlsRaw is bool) {
      tls = tlsRaw;
    } else if (tlsRaw is String) {
      tls = tlsRaw.toLowerCase() == 'true';
    } else {
      tls = port == 8883;
    }

    final username = (jsonMap['MQTT_USERNAME'] ?? '').toString();
    final password = (jsonMap['MQTT_PASSWORD'] ?? '').toString();
    final prefix = (jsonMap['MQTT_PREFIX'] ?? 'serverboy')
        .toString()
        .replaceAll(RegExp(r'/+$'), '');

    return MqttEnv(
      host: host,
      port: port,
      tls: tls,
      username: username,
      password: password,
      prefix: prefix,
    );
  }
}
