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

function handleCommand(emulator, payload) {
  const inputKey = parseInt(payload, 10);
  if (Number.isNaN(inputKey)) return;
  emulator.queueKey(inputKey, 3);
}

module.exports = {
  handleInputKeydown,
  handleInputKeyup,
  handleControlRestart,
  handleCommand,
};


