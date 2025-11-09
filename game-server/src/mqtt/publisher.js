'use strict';

const MQTT_PREFIX = process.env.MQTT_PREFIX || 'serverboy';

module.exports = {
  publishMeta: (mqttClient, meta, retain) => {
    if (!mqttClient) return;
    const payload = typeof meta === 'string' ? meta : JSON.stringify(meta || { width: 160, height: 144, format: 'rgba8888' });
    mqttClient.publish(`${MQTT_PREFIX}/meta`, payload, { qos: 0, retain: !!retain });
  },
  publishHealth: (mqttClient, health) => {
    if (!mqttClient) return;
    const payload = typeof health === 'string' ? health : JSON.stringify(health || { ok: true, ts: Date.now() });
    mqttClient.publish(`${MQTT_PREFIX}/health`, payload, { qos: 0, retain: false });
  },
  publishFrame: (mqttClient, screen) => {
    if (!mqttClient || !screen) return;
    const buf = Buffer.isBuffer(screen) ? screen : Buffer.from(screen);
    mqttClient.publish(`${MQTT_PREFIX}/frame`, buf, { qos: 0, retain: false });
  },
  publishAudio: (mqttClient, audio) => {
    if (!mqttClient || !audio) return;
    const buf = Buffer.isBuffer(audio) ? audio : Buffer.from(audio);
    mqttClient.publish(`${MQTT_PREFIX}/audio`, buf, { qos: 0, retain: false });
  },
};


