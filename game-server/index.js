'use strict';
const { encodeFrame } = require('./src/video');
const { encodeAudio } = require('./src/audio');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });

const { resolveRomPath, loadRomBuffer } = require('./src/rom');
const { createServer } = require('./src/createServer');
const emulator = require('./src/emulator');
const { attachInputHandlers } = require('./src/sockets');
let mqttClient = null;

const PORT = process.env.PORT ? Number(process.env.PORT) : 3002;
const TARGET_FPS = Number(process.env.TARGET_FPS || process.env.VIDEO_FPS || 15);
const FRAME_INTERVAL_MS = Math.max(1, Math.floor(1000 / TARGET_FPS));

const { httpServer, io } = createServer();

(function bootstrap() {
  const romPath = resolveRomPath();
  console.log(`[serverboy] Using ROM: ${romPath}`);
  const buffer = loadRomBuffer(romPath);
  emulator.initEmulator(buffer);
  attachInputHandlers(io, emulator);
  const enableMqtt = (process.env.ENABLE_MQTT || 'true') !== 'false';
  if (enableMqtt) {
    try {
      const { createMqttClient } = require('./src/mqtt');
      mqttClient = createMqttClient(emulator);
    } catch (err) {
      console.warn('[serverboy] MQTT not enabled:', err && err.message ? err.message : err);
    }
  }
  
  let lastFrameSentAt = 0;
  emulator.startLoop((screen, prevScreen) => {
    const now = Date.now();
    if (now - lastFrameSentAt >= FRAME_INTERVAL_MS) {
      lastFrameSentAt = now;
      // Prepare typed views
      const cur = Uint8Array.from(screen);
      // prev is ignored; we always send keyframes
      // const prev = prevScreen ? Uint8Array.from(prevScreen) : null;
      // Encode zlib keyframe once
      const keyPacket = encodeFrame(cur, null);
      // Broadcast the keyframe to all clients
      io.emit('frame', keyPacket);
      if (mqttClient && typeof mqttClient.publishFrame === 'function') {
        mqttClient.publishFrame(keyPacket);
      }
    }
    try {
      const audio = emulator.getAudio && emulator.getAudio();
      if (audio && audio.length) {
        // Compress audio before sending
        // Game Boy (Color) is mono; many emulators produce ~32.768 kHz. Allow override via env.
        const AUDIO_SR = Number(process.env.AUDIO_SAMPLE_RATE || 32768);
        const packet = encodeAudio(audio, { sampleRate: AUDIO_SR, channels: 1 });
        io.emit('audio', packet);
        if (mqttClient && typeof mqttClient.publishAudio === 'function') {
          mqttClient.publishAudio(packet);
        }
      }
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

