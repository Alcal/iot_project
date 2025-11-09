'use strict';

const { createMqttClient: createMqttCoreClient } = require('./mqtt/mqtt_client');
const { createConsumer } = require('./mqtt/consumer_utils');
const createGameServerConsumers = require('./mqtt/consumer');
const gameServerPublishers = require('./mqtt/publisher');

function createMqttClient(emulator, onInputActivity) {
  const shouldRetainMeta = process.env.MQTT_RETAIN_META === 'true';
  const consumers = createConsumer(createGameServerConsumers(emulator, onInputActivity));
  let connection = null;
  connection = createMqttCoreClient(consumers, gameServerPublishers, ({ client, publishers }) => {
    try {
      const meta = { width: 160, height: 144, format: 'rgba8888' };
      publishers.publishMeta(meta, shouldRetainMeta);
      publishers.publishHealth({ ok: true, ts: Date.now() });
    } catch (_) {}
  });

  function publishFrameBound(screen) {
    try {
      if (connection && connection.publishers && typeof connection.publishers.publishFrame === 'function') {
        connection.publishers.publishFrame(screen);
      }
    } catch (_) {}
  }

  function publishAudioBound(audio) {
    try {
      if (connection && connection.publishers && typeof connection.publishers.publishAudio === 'function') {
        connection.publishers.publishAudio(audio);
      }
    } catch (_) {}
  }

  function close() {
    try {
      if (connection && connection.client && typeof connection.client.end === 'function') {
        connection.client.end(true);
      }
    } catch (_) {}
  }

  return { client: connection && connection.client, publishFrame: publishFrameBound, publishAudio: publishAudioBound, close };
}

module.exports = { createMqttClient };


