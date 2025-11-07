'use strict';

function handleInputKeydown(emulator, payload) {
  const key = (payload || '').toUpperCase();
  if (key) emulator.handleKeyDown(key);
}

function handleInputKeyup(emulator, payload) {
  const key = (payload || '').toUpperCase();
  if (key) emulator.handleKeyUp(key);
}

function handleControlRestart(emulator) {
  emulator.restart();
}

module.exports = {
  handleInputKeydown,
  handleInputKeyup,
  handleControlRestart,
};


