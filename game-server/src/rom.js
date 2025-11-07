'use strict';

const fs = require('fs');
const path = require('path');

function resolveRomPath() {
  const envRom = process.env.ROM_PATH;
  if (envRom && fs.existsSync(envRom)) return envRom;

  const projectRoot = path.resolve(__dirname, '..');

  const projectRom = path.join(projectRoot, 'roms/pokemon-red.gb');
  if (fs.existsSync(projectRom)) return projectRom;

  const packagedRom = path.join(projectRoot, 'node_modules/serverboy/roms/pokeyellow.gbc');
  if (fs.existsSync(packagedRom)) return packagedRom;

  throw new Error('No ROM found. Set ROM_PATH to a valid .gb/.gbc file.');
}

function loadRomBuffer(romPath) {
  return fs.readFileSync(romPath);
}

module.exports = { resolveRomPath, loadRomBuffer };


