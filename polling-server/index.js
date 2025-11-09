// Basic MQTT server using same env vars as game-server
const http = require('http');
const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '.env') });
const { createMqttClient } = require('./src/mqtt/mqtt_client');
const { createConsumer } = require('./src/mqtt/consumer_utils');
const inputConsumers = require('./src/mqtt/consumer');
const commandPublisher = require('./src/mqtt/publisher');
const { startLogging, stopLogging, startCommandPublishing, stopCommandPublishing } = require('./src/input_tally');

let mqttConnection;

(function bootstrap() {
  const consumers = createConsumer({
    ...inputConsumers,
  });
  const publishers = {
    ...commandPublisher,
  };
  createMqttClient(consumers, publishers, (connection) => {
    mqttConnection = connection;
    // Start interval logging and publish tallies only after ready.
    // Skip publishing consecutive all-zero tallies until a non-zero appears.
    startLogging((snapshot) => {
      try {
        if (
          mqttConnection &&
          mqttConnection.publishers &&
          typeof mqttConnection.publishers.publishTally === 'function'
        ) {
          mqttConnection.publishers.publishTally(JSON.stringify(snapshot));
        }
      } catch (_) {
        // no-op
      }
    });
    // Start decision loop to publish command with index of the largest tally,
    // preferring lower indices on ties, only when any is > 0, then reset.
    startCommandPublishing((commandIndex) => {
      try {
        if (
          mqttConnection &&
          mqttConnection.publishers &&
          typeof mqttConnection.publishers.publishCommand === 'function'
        ) {
          mqttConnection.publishers.publishCommand(String(commandIndex));
        }
      } catch (_) {
        // no-op
      }
    });
  });
})();

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Polling server is running\n');
});

server.listen(process.env.PORT, () => {
  console.log(`Web server listening on port ${process.env.PORT}`);
});



process.on('SIGINT', () => {
  try { stopLogging(); } catch (_) {}
  try { stopCommandPublishing(); } catch (_) {}
  try { if (mqttConnection && mqttConnection.client && mqttConnection.client.end) mqttConnection.client.end(true); } catch (_) {}
  process.exit(0);
});
