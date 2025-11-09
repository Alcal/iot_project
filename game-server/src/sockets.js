'use strict';

function attachInputHandlers(io, emulator, onInputActivity) {
  io.on('connection', (socket) => {
    socket.on('keydown', (data) => {
      if (!data || !data.key) return;
      emulator.handleKeyDown(data.key);
      if (typeof onInputActivity === 'function') onInputActivity();
    });

    socket.on('keyup', (data) => {
      if (!data || !data.key) return;
      emulator.handleKeyUp(data.key);
      if (typeof onInputActivity === 'function') onInputActivity();
    });

    socket.on('restart', () => {
      emulator.restart();
      if (typeof onInputActivity === 'function') onInputActivity();
    });

    socket.on('disconnect', () => {
      // no-op
    });
  });
}

module.exports = { attachInputHandlers };


