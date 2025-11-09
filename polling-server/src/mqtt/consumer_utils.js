const createConsumer = (consumersDefintions) => {
    const prefix = process.env.MQTT_PREFIX || 'serverboy';
    const routes = {};
    if (consumersDefintions && typeof consumersDefintions === 'object') {
        Object.keys(consumersDefintions).forEach((topicAction) => {
            routes[`${prefix}/${topicAction}`] = consumersDefintions[topicAction];
        });
    }
    return routes;
}

const routeMessage = (consumers, topic, message) => {
    const consumer = consumers[topic];
    if (consumer) {
        consumer(message, topic);
    }
}

module.exports = {
    createConsumer,
};