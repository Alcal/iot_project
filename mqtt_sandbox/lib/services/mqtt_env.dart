import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:iot_gameboy/services/logger.dart';

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
    // 1) Try to load .env (works on all platforms when declared in pubspec assets)
    try {
      if (!dotenv.isInitialized) {
        await dotenv.load(fileName: '.env');
      }
    } catch (e) {
      log.i('No .env found or failed to load: $e');
    }

    // 2) Also attempt to read legacy JSON for backward compatibility/fallback
    Map<String, dynamic> jsonMap = {};
    try {
      final contents = await rootBundle.loadString(_envOverridePath);
      jsonMap = json.decode(contents) as Map<String, dynamic>;
    } catch (e) {
      log.i('ENV file not found or invalid at $_envOverridePath ($e)');
    }

    // Resolve values preferring .env -> json -> defaults
    String host =
        (dotenv.env['MQTT_HOST'] ?? jsonMap['MQTT_HOST'] ?? 'localhost')
            .toString()
            .trim();

    int port = () {
      final fromDotEnv = dotenv.env['MQTT_PORT'];
      if (fromDotEnv != null && fromDotEnv.isNotEmpty) {
        return int.tryParse(fromDotEnv) ?? 1883;
      }
      final fromJson = jsonMap['MQTT_PORT'];
      if (fromJson is int) return fromJson;
      return int.tryParse('$fromJson') ?? 1883;
    }();

    // Prefer explicit MQTT_TLS; otherwise infer TLS from common secure port 8883
    bool tls = () {
      final tlsEnv = dotenv.env['MQTT_TLS'];
      if (tlsEnv != null) {
        return tlsEnv.toLowerCase() == 'true';
      }
      final tlsJson = jsonMap['MQTT_TLS'];
      if (tlsJson is bool) return tlsJson;
      if (tlsJson is String) return tlsJson.toLowerCase() == 'true';
      return port == 8883;
    }();

    final username =
        (dotenv.env['MQTT_USERNAME'] ?? jsonMap['MQTT_USERNAME'] ?? '')
            .toString();
    final password =
        (dotenv.env['MQTT_PASSWORD'] ?? jsonMap['MQTT_PASSWORD'] ?? '')
            .toString();
    final prefix =
        (dotenv.env['MQTT_PREFIX'] ?? jsonMap['MQTT_PREFIX'] ?? 'serverboy')
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
