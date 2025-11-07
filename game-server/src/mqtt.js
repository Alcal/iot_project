'use strict';

const mqtt = require('mqtt');

function createMqttClient(emulator) {
  // Build connection parameters from environment variables with sensible defaults
  // Backward compatible: if MQTT_URL is provided, it takes precedence
  const envHost = process.env.MQTT_HOST;
  const envPort = process.env.MQTT_PORT ? Number(process.env.MQTT_PORT) : undefined;
  const envProtocol = process.env.MQTT_PROTOCOL;
  const envUsername = process.env.MQTT_USERNAME;
  const envPassword = process.env.MQTT_PASSWORD;

  let url = process.env.MQTT_URL;
  if (!url) {
    const protocol = envProtocol || 'mqtt';
    const host = envHost || 'localhost';
    const defaultPort = (protocol === 'mqtts' || protocol === 'wss') ? 8883 : 1883;
    const port = typeof envPort === 'number' ? envPort : defaultPort;
    url = `${protocol}://${host}:${port}`;
  }
  const prefix = (process.env.MQTT_PREFIX || 'serverboy').replace(/\/$/, '');
  const shouldRetainMeta = process.env.MQTT_RETAIN_META === 'true';

  const connectOptions = {
    clientId: `serverboy-server-${process.pid}`,
    clean: true,
    reconnectPeriod: 1000,
  };
  if (envUsername) connectOptions.username = envUsername;
  if (envPassword) connectOptions.password = envPassword;

  const client = mqtt.connect(url, connectOptions);

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


