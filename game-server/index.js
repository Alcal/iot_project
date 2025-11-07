'use strict';

const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });

const { resolveRomPath, loadRomBuffer } = require('./src/rom');
const { createServer } = require('./src/createServer');
const emulator = require('./src/emulator');
const { attachInputHandlers } = require('./src/sockets');
let mqttClient = null;

const PORT = process.env.PORT ? Number(process.env.PORT) : 3002;

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
  emulator.startLoop((screen) => {
    io.emit('frame', screen);
    try {
      const audio = emulator.getAudio && emulator.getAudio();
      if (audio && audio.length) {
        io.emit('audio', audio);
      }
    } catch (_) {}
    
    if (mqttClient && typeof mqttClient.publishFrame === 'function') {
      // mqttClient.publishFrame(screen);
    }
  });
})();

httpServer.listen(PORT, () => {
  console.log(`[serverboy] listening on http://localhost:${PORT}`);
});

process.on('SIGINT', () => {
  try { if (mqttClient && mqttClient.close) mqttClient.close(); } catch (_) {}
  process.exit(0);
});

