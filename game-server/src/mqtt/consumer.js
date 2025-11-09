'use strict';

const { handleControlRestart, handleCommand } = require('../consumersHandlers');

const INPUT_KEYDOWN = 'input/keydown';
const INPUT_KEYUP = 'input/keyup';
const CONTROL_RESTART = 'control/restart';
const COMMAND_TOPIC = 'command';

function createGameServerConsumers(emulator, onInputActivity) {
  return {
    // [INPUT_KEYDOWN]: (payload /*, topic */) => {
    //   if (typeof onInputActivity === 'function') onInputActivity();
    //   const str = (payload || '').toString();
    //   handleInputKeydown(emulator, str);
    // },
    // [INPUT_KEYUP]: (payload /*, topic */) => {
    //   if (typeof onInputActivity === 'function') onInputActivity();
    //   const str = (payload || '').toString();
    //   handleInputKeyup(emulator, str);
    // },
    [CONTROL_RESTART]: (/* payload, topic */) => {
      if (typeof onInputActivity === 'function') onInputActivity();
      handleControlRestart(emulator);
    },
    [COMMAND_TOPIC]: (payload /*, topic */) => {
      if (typeof onInputActivity === 'function') onInputActivity();
      handleCommand(emulator, payload);
    },
  };
}

module.exports = createGameServerConsumers;


