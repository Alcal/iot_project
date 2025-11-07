'use strict';

const Gameboy = require('serverboy');

let gameboy = null;
let romBuffer = null;
let sram = [];
const keysHeld = new Set();

function initEmulator(buffer, initialSram) {
  romBuffer = buffer;
  sram = Array.isArray(initialSram) ? initialSram : [];
  gameboy = new Gameboy();
  gameboy.loadRom(romBuffer, sram);
}

function restart() {
  if (!gameboy) return;
  sram = gameboy.getSaveData();
  gameboy.loadRom(romBuffer, sram);
}

function handleKeyDown(key) {
  if (!key) return;
  keysHeld.add(String(key).toUpperCase());
}

function handleKeyUp(key) {
  if (!key) return;
  keysHeld.delete(String(key).toUpperCase());
}

function startLoop(onFrame) {
  let frames = 0;

  const tick = () => {
    try {
      if (!gameboy) return setTimeout(tick, 5);

      if (keysHeld.size > 0) {
        gameboy.pressKeys(Array.from(keysHeld));
      }

      const screen = gameboy.doFrame();

      frames++;
      if ((frames & 1) === 0 && typeof onFrame === 'function') {
        onFrame(screen);
      }
    } catch (err) {
      console.error('Emulation error:', err);
    } finally {
      setTimeout(tick, 5);
    }
  };

  tick();
}

function getAudio() {
  if (!gameboy) return null;
  try {
    return gameboy.getAudio();
  } catch (_) {
    return null;
  }
}

module.exports = {
  initEmulator,
  startLoop,
  getAudio,
  handleKeyDown,
  handleKeyUp,
  restart,
};


