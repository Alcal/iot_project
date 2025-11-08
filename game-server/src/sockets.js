'use strict';

function attachInputHandlers(io, emulator) {
  io.on('connection', (socket) => {
    socket.on('keydown', (data) => {
      if (!data || !data.key) return;
      emulator.handleKeyDown(data.key);
    });

    socket.on('keyup', (data) => {
      if (!data || !data.key) return;
      emulator.handleKeyUp(data.key);
    });

    socket.on('restart', () => {
      emulator.restart();
    });

    socket.on('disconnect', () => {
      // no-op
    });
  });
}

module.exports = { attachInputHandlers };


