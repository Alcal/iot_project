import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iot_gameboy/services/mqtt_services.dart';

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.read<MqttService>();
    final host = svc.defaultHost;
    final port = svc.defaultPort;
    final tls = svc.defaultUseTLS;
    final username = svc.defaultUsername;
    final password = svc.defaultPassword;
    final prefix = svc.defaultTopicPrefix;

    return AlertDialog(
      title: const Text('MQTT Settings'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingRow(label: 'Host', value: host),
            _SettingRow(label: 'Port', value: '$port'),
            _SettingRow(label: 'Use TLS', value: tls ? 'Yes' : 'No'),
            _SettingRow(
              label: 'Username',
              value: username.isEmpty ? '(none)' : username,
            ),
            _SettingRow(
              label: 'Password',
              value: password.isEmpty ? '(none)' : '••••',
            ),
            _SettingRow(label: 'Topic Prefix', value: prefix),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
