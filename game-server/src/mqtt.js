'use strict';

const mqtt = require('mqtt');
const { publishMeta, publishHealth, publishFrame } = require('./mqttPublishers');
const { handleInputKeydown, handleInputKeyup, handleControlRestart } = require('./mqttConsumers');

function createMqttClient(emulator) {
  // Build connection parameters from environment variables with sensible defaults
  // Backward compatible: if MQTT_URL is provided, it takes precedence
  const options = {
    host: process.env.MQTT_HOST,
    port: process.env.MQTT_PORT,
    protocol: 'mqtts',
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD
}

const prefix = (process.env.MQTT_PREFIX || 'serverboy').replace(/\/$/, '');
const shouldRetainMeta = process.env.MQTT_RETAIN_META === 'true';

// initialize the MQTT client
  const client = mqtt.connect(options);
  client.on('connect', () => {
    console.log(`[serverboy][mqtt] connected to ${options.host}:${options.port}`);
    client.subscribe([
      `${prefix}/input/#`,
      `${prefix}/control/#`,
    ], (err) => {
      if (err) console.error('[serverboy][mqtt] subscribe error:', err);
    });

    // Publish metadata once on connect
    const meta = { width: 160, height: 144, format: 'rgba8888' };
    publishMeta(client, prefix, meta, shouldRetainMeta);
    publishHealth(client, prefix, { ok: true, ts: Date.now() });
  });

  client.on('error', (err) => {
    console.error('[serverboy][mqtt] error:', err);
  });

  client.on('message', (topic, payloadBuffer) => {
    try {
      const payload = payloadBuffer ? String(payloadBuffer) : '';
      if (topic.endsWith('/input/keydown')) {
        handleInputKeydown(emulator, payload);
        return;
      }
      if (topic.endsWith('/input/keyup')) {
        handleInputKeyup(emulator, payload);
        return;
      }
      if (topic.endsWith('/control/restart')) {
        handleControlRestart(emulator);
        return;
      }
    } catch (err) {
      console.error('[serverboy][mqtt] message handling error:', err);
    }
  });

  function publishFrameBound(screen) {
    publishFrame(client, prefix, screen);
  }

  function publishAudioBound(audio) {
    publishAudio(client, prefix, audio);
  }

  function close() {
    try {
      client.end(true);
    } catch (_) {}
  }

  return { client, publishFrame: publishFrameBound, publishAudio: publishAudioBound, close };
}

module.exports = { createMqttClient };


