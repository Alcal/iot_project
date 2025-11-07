## IoT Project: Game Server + Mobile MQTT Client

This repository contains two apps that work together:

- **game-server/** (Node.js): runs a Game Boy emulator (Serverboy), serves a simple web viewer, and integrates with MQTT for remote input/control (and optionally video frames).
- **mqtt_sandbox/** (Flutter): a cross‑platform client that connects to your MQTT broker to view frames from the server and send input/control commands back.

### High-level architecture

- The game server renders frames and exposes a web viewer at an HTTP port (default `3002`).
- Over MQTT, the server:
  - publishes metadata and health to `${MQTT_PREFIX}/meta` and `${MQTT_PREFIX}/health`.
  - optionally publishes raw frame buffers to `${MQTT_PREFIX}/frame`.
  - subscribes to input/control topics so clients can drive the emulator:
    - `${MQTT_PREFIX}/input/keydown` and `${MQTT_PREFIX}/input/keyup` (payload: key string)
    - `${MQTT_PREFIX}/control/restart`
- The Flutter client subscribes to `${MQTT_PREFIX}/meta` and `${MQTT_PREFIX}/frame`, and publishes input/control to the topics above.

---

## Prerequisites

- Node.js 18+ and npm
- Flutter SDK (stable channel) with a target platform set up (Android/iOS/Web/Desktop)
- An MQTT broker:
  - Cloud (e.g. HiveMQ Cloud) or local (e.g. Mosquitto)
  - TLS on port `8883` is supported; non‑TLS on `1883` also works

---

## 1) Configure the MQTT connection

Both apps read similar MQTT settings. Use the same values on server and client.

### Flutter client config

Edit `mqtt_sandbox/assets/env.json`:

```json
{
  "MQTT_HOST": "your-broker-host",
  "MQTT_PORT": 8883,
  "MQTT_USERNAME": "user",
  "MQTT_PASSWORD": "pass",
  "MQTT_PREFIX": "serverboy",
  "MQTT_TLS": true
}
```

Notes:
- `MQTT_TLS`: if omitted, the app infers TLS when `MQTT_PORT` is `8883`.
- `MQTT_PREFIX` is trimmed of trailing `/` and defaults to `serverboy`.

### Game server config

Create `game-server/.env` (or set environment variables):

```env
# HTTP server
PORT=3002

# Emulator ROM selection (optional)
# ROM_PATH=/absolute/path/to/your.rom

# MQTT
ENABLE_MQTT=true
MQTT_HOST=your-broker-host
MQTT_PORT=8883
MQTT_USERNAME=user
MQTT_PASSWORD=pass
MQTT_PREFIX=serverboy
# Publish meta with retain flag (optional)
MQTT_RETAIN_META=false
```

ROM lookup order:
1) `ROM_PATH` if set and exists
2) `game-server/roms/pokemon-red.gb` (repo default)
3) `node_modules/serverboy/roms/pokeyellow.gbc`

---

## 2) Run the game server

```bash
cd game-server
npm install
npm start
```

If successful, you should see a log like:

```text
[serverboy] Using ROM: /path/to/rom
[serverboy] listening on http://localhost:3002
```

Open the built‑in viewer at `http://localhost:3002` to see the emulator and test input with the on‑screen buttons or keyboard.

### Enable MQTT frame publishing (optional)

The server already publishes `${MQTT_PREFIX}/meta` and `${MQTT_PREFIX}/health` on connect.

To stream frames over MQTT (so the Flutter app can display them), enable publishing in `game-server/index.js` by uncommenting the indicated line:

```40:42:game-server/index.js
    if (mqttClient && typeof mqttClient.publishFrame === 'function') {
      // mqttClient.publishFrame(screen);
    }
```

Change it to:

```text
mqttClient.publishFrame(screen);
```

Restart the server after changing the file.

---

## 3) Run the Flutter MQTT client

```bash
cd mqtt_sandbox
flutter pub get
flutter run
```

Tips:
- Pick a target device (Android emulator, iOS simulator, Web, or Desktop).
- If using a local broker, use your machine's LAN IP instead of `localhost` when running on a physical device/emulator.
- Ensure the broker allows the selected TLS/non‑TLS mode and port.

---

## MQTT topics

- `${MQTT_PREFIX}/meta` (JSON): `{ width, height, format }`
- `${MQTT_PREFIX}/frame` (binary): raw frame buffer matching `rgba8888` layout
- `${MQTT_PREFIX}/health` (JSON): `{ ok, ts }`
- `${MQTT_PREFIX}/input/keydown` (UTF‑8 string): key name (e.g. `UP`, `DOWN`, `LEFT`, `RIGHT`, `A`, `B`, `START`, `SELECT`)
- `${MQTT_PREFIX}/input/keyup` (UTF‑8 string): key name
- `${MQTT_PREFIX}/control/restart` (empty payload)

Key mapping in the web viewer (for quick testing):
- Arrow keys → D‑Pad
- Z → A, X → B, Enter → START, Left Shift → SELECT

---

## Troubleshooting

- No frames in the Flutter app: verify frame publishing is enabled on the server and the client subscribes to the same `MQTT_PREFIX`.
- Connection fails: check broker hostname, port, credentials, and TLS settings on both sides.
- Local broker from mobile device/emulator: use the host machine's LAN IP (e.g. `192.168.x.y`) instead of `localhost`.
- ROM not found: set `ROM_PATH` or place a `.gb/.gbc` file at `game-server/roms/pokemon-red.gb`.


