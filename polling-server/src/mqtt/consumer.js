const { increment } = require('../input_tally');
const INPUT_TOPIC = 'input';


const consumers = {
	[`${INPUT_TOPIC}`]: (payload /*, topic */) => {
		const str = (payload || '').toString().trim();
		const inputId = Number.parseInt(str, 10);
		if (!Number.isNaN(inputId)) {
			increment(inputId);
		}
	}
}

module.exports = consumers;