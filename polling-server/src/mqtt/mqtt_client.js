const mqtt = require('mqtt');

const MQTT_HOST = process.env.MQTT_HOST;
const MQTT_PORT = process.env.MQTT_PORT;
const MQTT_USERNAME = process.env.MQTT_USERNAME;
const MQTT_PASSWORD = process.env.MQTT_PASSWORD;
const MQTT_PREFIX = process.env.MQTT_PREFIX || 'serverboy';
const MQTT_PROTOCOL = process.env.MQTT_PROTOCOL || 'mqtts';
const MQTT_KEEPALIVE = process.env.MQTT_KEEPALIVE ? Number(process.env.MQTT_KEEPALIVE) : 300;

function createMqttClient(consumers, publishers, cb) {
  console.log(`[polling-server] Connecting to MQTT broker: ${MQTT_HOST}:${MQTT_PORT}`);
  const client = mqtt.connect({
    host: MQTT_HOST,
    port: MQTT_PORT,
    username: MQTT_USERNAME,
    password: MQTT_PASSWORD,
    protocol: MQTT_PROTOCOL,
    keepalive: MQTT_KEEPALIVE,
  });
  const boundPublishers = {};
  let isReadyDelivered = false;
  client.on('connect', function () {
    console.log(`[polling-server] Connected to MQTT! Subscribing to prefix ${MQTT_PREFIX}`);
    const topicKeys = Object.keys(consumers);
    client.subscribe(topicKeys, function (err) {
      if (err) {
          console.error('[polling-server] Failed to subscribe:', err);
          return;
      }
      console.log(`[polling-server] Subscribed to topics: \n ${topicKeys.join('\n\t')}`);
      Object.keys(publishers).forEach((publishKey) => {
        boundPublishers[publishKey] = (...args) => publishers[publishKey](client, ...args);
      });
      if (typeof cb === 'function' && !isReadyDelivered) {
        isReadyDelivered = true;
        cb({ client, publishers: boundPublishers });
      }
    });
  });

  client.on('message', function (topic, message) {
    // message is a Buffer
    console.log(`[polling-server] MQTT message received on topic '${topic}':`, message.toString());
    const consumer = consumers[topic];
    if (consumer) {
      consumer(message);
    }
  });

  client.on('error', function (err) {
    console.error('[polling-server] MQTT client error:', err);
  });

  client.on('close', function (...args) {
    console.log('[polling-server] MQTT connection closed', ...args);
  });

  return { client, publishers: boundPublishers };
}

module.exports = {
    createMqttClient,
};