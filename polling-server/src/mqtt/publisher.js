const MQTT_PREFIX = process.env.MQTT_PREFIX || 'serverboy';
module.exports = {
    publishCommand: (mqttClient, command) => {
        mqttClient.publish(`${MQTT_PREFIX}/command`, command, { qos: 2});
    },  
    publishTally: (mqttClient, tally) => {
        mqttClient.publish(`${MQTT_PREFIX}/tally`, tally, { qos: 1, retain: true });
    }
}