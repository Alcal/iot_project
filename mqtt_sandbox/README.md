# mqtt_sandbox

Serverboy MQTT viewer built with Flutter.

## Environment configuration (HiveMQ compatible)

The app reads connection settings from an environment JSON file located at `assets/env.json` (can be overridden). Keys mirror the Node game-server params:

- `MQTT_HOST`
- `MQTT_PORT`
- `MQTT_USERNAME`
- `MQTT_PASSWORD`
- `MQTT_PREFIX` (default `serverboy`)
- `MQTT_TLS` (optional; if omitted, TLS is inferred as `port == 8883`)

To use a different env file, pass `--dart-define=ENV_FILE=assets/env.prod.json` and include that file in assets.

### Run (Android/iOS/desktop)

1) Edit `assets/env.json` with your HiveMQ cluster values and run:

```bash
flutter run
```

2) Or provide an alternate env file (remember to add it to `pubspec.yaml` assets):

```bash
flutter run --dart-define=ENV_FILE=assets/env.prod.json
```

### Run (Web)

```bash
flutter run -d chrome
```

You can still override settings at runtime via the in-app Settings dialog.
