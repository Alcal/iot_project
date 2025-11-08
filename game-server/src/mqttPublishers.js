'use strict';

function publishMeta(client, prefix, meta, shouldRetainMeta) {
  if (!client || !client.connected) return;
  const payload = meta || { width: 160, height: 144, format: 'rgba8888' };
  client.publish(`${prefix}/meta`, JSON.stringify(payload), { qos: 0, retain: !!shouldRetainMeta });
}

function publishHealth(client, prefix, health) {
  if (!client || !client.connected) return;
  const payload = health || { ok: true, ts: Date.now() };
  client.publish(`${prefix}/health`, JSON.stringify(payload), { qos: 0, retain: false });
}

function publishFrame(client, prefix, screen) {
  if (!client || !client.connected || !screen) return;
  const buf = Buffer.isBuffer(screen) ? screen : Buffer.from(screen);
  client.publish(`${prefix}/frame`, buf, { qos: 0, retain: false });
}

function publishAudio(client, prefix, audio) {
  if (!client || !client.connected || !audio) return;
  const buf = Buffer.isBuffer(audio) ? audio : Buffer.from(audio);
  client.publish(`${prefix}/audio`, buf, { qos: 0, retain: false });
}

module.exports = {
  publishMeta,
  publishHealth,
  publishFrame,
  publishAudio,
};


