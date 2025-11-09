import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createMqttClient({
  required String host,
  required int port,
  required String clientId,
  required bool useTLS,
}) {
  final serverClient = MqttServerClient.withPort(host, clientId, port);
  serverClient.secure = useTLS;
  serverClient.keepAlivePeriod = 0;
  return serverClient;
}
