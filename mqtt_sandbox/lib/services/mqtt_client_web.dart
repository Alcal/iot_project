import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createMqttClient({
  required String host,
  required int port,
  required String clientId,
  required bool useTLS,
}) {
  final scheme = useTLS ? 'wss' : 'ws';
  final wsPath = '/mqtt';
  final url = '$scheme://$host:$port$wsPath';
  return MqttBrowserClient(url, clientId);
}
