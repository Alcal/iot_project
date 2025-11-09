'use strict';
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });
const throttle = require('lodash.throttle');

const { resolveRomPath, loadRomBuffer } = require('./src/game/rom');
const { createServer } = require('./src/createServer');
const emulator = require('./src/game/emulator');
const { attachInputHandlers } = require('./src/sockets');
const { createMqttClient } = require('./src/mqtt');
let mqttClient = null;

const PORT = process.env.PORT ? Number(process.env.PORT) : 3002;
const TARGET_FPS = Number(process.env.TARGET_FPS || process.env.VIDEO_FPS || 15);
const FRAME_INTERVAL_MS = Math.max(1, Math.floor(1000 / TARGET_FPS));
const INACTIVITY_MS = Number(process.env.INACTIVITY_MS || 60000);

const { httpServer, io } = createServer();

// Throttle MQTT frame publishing to the target frame interval
const publishFrameThrottled = throttle((framePacket) => {
  try {
    if (mqttClient && typeof mqttClient.publishFrame === 'function') {
      mqttClient.publishFrame(framePacket);
    }
  } catch (_) {}
}, FRAME_INTERVAL_MS, { leading: true, trailing: true });
let isLoopActive = true;
(function bootstrap() {
  const romPath = resolveRomPath();
  console.log(`[serverboy] Using ROM: ${romPath}`);
  const buffer = loadRomBuffer(romPath);
  emulator.initEmulator(buffer);
  const noteInputActivity = () => {
  };
  try {
    mqttClient = createMqttClient(emulator, noteInputActivity);
  } catch (err) {
    console.warn('[serverboy] MQTT not enabled:', err && err.message ? err.message : err);
  }
  emulator.startLoop((framePacket, audioPacket) => {
    try {
      io.emit('frame', framePacket);
      publishFrameThrottled(framePacket);
      io.emit('audio', audioPacket);
      // if (mqttClient && typeof mqttClient.publishAudio === 'function') {
      //   mqttClient.publishAudio(audioPacket);
      // }
    } catch (_) {}
  });
})();

httpServer.listen(PORT, () => {
  console.log(`[serverboy] listening on http://localhost:${PORT}`);
});

process.on('SIGINT', () => {
  try { if (mqttClient && mqttClient.close) mqttClient.close(); } catch (_) {}
  process.exit(0);
});

