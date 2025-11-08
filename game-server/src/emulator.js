'use strict';

const Gameboy = require('serverboy');

let gameboy = null;
let romBuffer = null;
let sram = [];
const keysHeld = new Set();
let heldKey = null;

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
  heldKey = parseInt(key);
}

function handleKeyUp(key) {
  if (!key) return;
  keysHeld.delete(String(key).toUpperCase());
}

function startLoop(onFrame) {
  let frames = 0;
  let prevScreen = null;
  let screen = null;
  const tick = () => {
    try {
      if (!gameboy) return setTimeout(tick, 5);

      if (heldKey !== null) {
        gameboy.pressKey(heldKey);
        heldKey = null;
      }
      prevScreen = screen;
      screen = gameboy.doFrame();

      frames++;
      if ((frames & 1) === 0 && typeof onFrame === 'function') {
        onFrame(screen, prevScreen);
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


