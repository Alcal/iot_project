'use strict';

const Gameboy = require('serverboy');
const { encodeFrame } = require('./video');
const { encodeAudio } = require('./audio');

let gameboy = null;
let romBuffer = null;
let sram = [];
const keysHeld = new Set();
const keyStack = [];
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

function queueKey(key, times) {
  keyStack.push(...new Array(times).fill(key));
}

function startLoop(onFrame) {
  let frames = 0;
  let prevScreen = null;
  let screen = null;
  const tick = () => {
    try {
      if (!gameboy) return setTimeout(tick, 5);

      if (keyStack.length) {
        gameboy.pressKey(keyStack.shift());
      }
      prevScreen = screen;
      screen = gameboy.doFrame();
      const audioPacket = null;

      frames++;
      if ((frames & 1) === 0 && typeof onFrame === 'function') {
        const cur = Uint8Array.from(screen);
        // prev is ignored; we always send keyframes
        // const prev = prevScreen ? Uint8Array.from(prevScreen) : null;
        // Encode zlib keyframe once
        const keyPacket = encodeFrame(cur, null);
        onFrame(keyPacket, audioPacket);
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
  try {const audio = gameboy.getAudio();
    let audioPacket = null;
    if (audio && audio.length) {
      // Compress audio before sending
      // Game Boy (Color) is mono; many emulators produce ~32.768 kHz.
      // We resample to a standard 44.1 kHz by default to match most devices.
      const AUDIO_INPUT_SR = Number(process.env.AUDIO_INPUT_SAMPLE_RATE || 32768);
      const AUDIO_SR = Number(process.env.AUDIO_SAMPLE_RATE || 44100);
      audioPacket = encodeAudio(audio, {
        sampleRate: AUDIO_SR,
        channels: 1,
        inputSampleRate: AUDIO_INPUT_SR,
      });
    }
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
  queueKey,
};


