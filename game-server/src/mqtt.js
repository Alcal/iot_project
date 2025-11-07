'use strict';

const mqtt = require('mqtt');

function createMqttClient(emulator) {
  const url = process.env.MQTT_URL || 'mqtt://localhost:1883';
  const prefix = (process.env.MQTT_PREFIX || 'serverboy').replace(/\/$/, '');
  const shouldRetainMeta = process.env.MQTT_RETAIN_META === 'true';

  const client = mqtt.connect(url, {
    clientId: `serverboy-server-${process.pid}`,
    clean: true,
    reconnectPeriod: 1000,
  });

  client.on('connect', () => {
    console.log(`[serverboy][mqtt] connected to ${url}`);
    client.subscribe([
      `${prefix}/input/#`,
      `${prefix}/control/#`,
    ], (err) => {
      if (err) console.error('[serverboy][mqtt] subscribe error:', err);
    });

    // Publish metadata once on connect
    const meta = {
      width: 160,
      height: 144,
      format: 'rgba8888',
    };
    client.publish(`${prefix}/meta`, JSON.stringify(meta), { qos: 0, retain: shouldRetainMeta });
    client.publish(`${prefix}/health`, JSON.stringify({ ok: true, ts: Date.now() }), { qos: 0, retain: false });
  });

  client.on('error', (err) => {
    console.error('[serverboy][mqtt] error:', err);
  });

  client.on('message', (topic, payloadBuffer) => {
    try {
      const payload = payloadBuffer ? String(payloadBuffer) : '';
      if (topic.endsWith('/input/keydown')) {
        const key = (payload || '').toUpperCase();
        if (key) emulator.handleKeyDown(key);
        return;
      }
      if (topic.endsWith('/input/keyup')) {
        const key = (payload || '').toUpperCase();
        if (key) emulator.handleKeyUp(key);
        return;
      }
      if (topic.endsWith('/control/restart')) {
        emulator.restart();
        return;
      }
    } catch (err) {
      console.error('[serverboy][mqtt] message handling error:', err);
    }
  });

  function publishFrame(screen) {
    if (!client || !client.connected || !screen) return;
    // screen is a typed array of RGBA bytes; publish as binary
    const buf = Buffer.isBuffer(screen) ? screen : Buffer.from(screen);
    client.publish(`${prefix}/frame`, buf, { qos: 0, retain: false });
  }

  function close() {
    try {
      client.end(true);
    } catch (_) {}
  }

  return { client, publishFrame, close };
}

module.exports = { createMqttClient };


