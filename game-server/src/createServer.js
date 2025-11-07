'use strict';

const path = require('path');
const express = require('express');
const http = require('http');
const { Server: SocketIOServer } = require('socket.io');

function createServer() {
  const app = express();

  // Serve static assets (viewer)
  const publicDir = path.resolve(__dirname, '../public');
  app.use(express.static(publicDir));

  // Health endpoint
  app.get('/health', (_req, res) => res.status(200).json({ ok: true }));

  const httpServer = http.createServer(app);
  const io = new SocketIOServer(httpServer, {
    cors: { origin: '*' },
  });

  return { app, httpServer, io };
}

module.exports = { createServer };


