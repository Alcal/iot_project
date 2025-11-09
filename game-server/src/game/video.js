'use strict';

/**
 * Video frame encoding utilities for reducing bandwidth of screen frames.
 *
 * Strategy (simplified):
 * - Keyframes only: zlib-compressed full frame.
 *
 * Screen format assumptions (based on serverboy and existing code):
 * - Width: 160
 * - Height: 144
 * - Pixel format: rgba8888 (4 bytes per pixel)
 *
 * Exports:
 * - encodeFrame(currentScreen: Uint8Array|Buffer, prevScreen?: Uint8Array|Buffer, options?): Buffer
 * - decodeFrame(prevScreen: Uint8Array|Buffer|null, packet: Uint8Array|Buffer): Uint8Array
 * - constants: FRAME_TYPE, DEFAULTS
 */

const zlib = require('zlib');

const DEFAULTS = {
  width: 160,
  height: 144,
  bytesPerPixel: 4, // rgba8888
  tileSize: 8, // 8x8 tiles
  // If the fraction of changed tiles exceeds this, send a keyframe instead of delta.
  maxDeltaTileRatio: 0.6,
  // Force a keyframe every N frames if the caller wants (not enforced here; caller can decide).
};

const FRAME_TYPE = {
  KEYFRAME_RAW: 0, // not used by default
  KEYFRAME_ZLIB: 1,
  KEYFRAME_RLE: 2, // not used by default
  // Delta strategies removed
};

function toUint8Array(data) {
  if (!data) return null;
  if (data instanceof Uint8Array) return data;
  if (Buffer.isBuffer(data)) return new Uint8Array(data.buffer, data.byteOffset, data.byteLength);
  throw new TypeError('Expected Uint8Array or Buffer');
}

function writeHeader({ frameType, width, height, bytesPerPixel }) {
  // Header layout (8 bytes):
  // [0]: 'V' (0x56)
  // [1]: version (0x01)
  // [2]: frameType (see FRAME_TYPE)
  // [3..4]: width (uint16 LE)
  // [5..6]: height (uint16 LE)
  // [7]: bytesPerPixel (uint8)
  const header = Buffer.allocUnsafe(8);
  header[0] = 0x56; // 'V'
  header[1] = 0x01; // version 1
  header[2] = frameType & 0xff;
  header.writeUInt16LE(width & 0xffff, 3);
  header.writeUInt16LE(height & 0xffff, 5);
  header[7] = bytesPerPixel & 0xff;
  return header;
}

function readHeader(buf) {
  if (!buf || buf.length < 8) throw new Error('Packet too short for header');
  if (buf[0] !== 0x56) throw new Error('Invalid magic');
  if (buf[1] !== 0x01) throw new Error('Unsupported version');
  const frameType = buf[2];
  const width = buf.readUInt16LE(3);
  const height = buf.readUInt16LE(5);
  const bytesPerPixel = buf[7];
  return { frameType, width, height, bytesPerPixel, headerBytes: 8 };
}

// Simple 7-bit varint (unsigned LEB128) up to 32-bit
function writeVarint(value) {
  if (value < 0) throw new RangeError('varint must be >= 0');
  const out = [];
  let v = value >>> 0;
  while (v >= 0x80) {
    out.push((v & 0x7f) | 0x80);
    v >>>= 7;
  }
  out.push(v);
  return Buffer.from(out);
}

function readVarint(buf, offset) {
  let result = 0 >>> 0;
  let shift = 0;
  let i = offset;
  for (; i < buf.length && shift <= 28; i++) {
    const byte = buf[i];
    result |= ((byte & 0x7f) << shift) >>> 0;
    if ((byte & 0x80) === 0) {
      return { value: result >>> 0, nextOffset: i + 1 };
    }
    shift += 7;
  }
  throw new Error('Invalid varint');
}

/**
 * Zero run-length encoding (ZRLE)
 * - Control byte < 128: literal run length = control + 1, followed by that many literal bytes
 * - Control byte >= 128: zero run length = (control - 128) + 1 zeros
 */
function zrleEncode(input) {
  const src = toUint8Array(input);
  const out = [];
  let i = 0;
  while (i < src.length) {
    if (src[i] === 0) {
      // zero run
      let run = 1;
      const end = Math.min(src.length, i + 128);
      for (let j = i + 1; j < end && src[j] === 0; j++) run++;
      out.push(0x80 + (run - 1));
      i += run;
    } else {
      // literal run up to 128 or until a zero appears
      let run = 1;
      const end = Math.min(src.length, i + 128);
      for (let j = i + 1; j < end && src[j] !== 0; j++) run++;
      out.push(run - 1);
      out.push(...src.subarray(i, i + run));
      i += run;
    }
  }
  return Buffer.from(out);
}

function zrleDecode(input) {
  const src = toUint8Array(input);
  const out = [];
  let i = 0;
  while (i < src.length) {
    const ctrl = src[i++];
    if (ctrl < 128) {
      const run = ctrl + 1;
      if (i + run > src.length) throw new Error('ZRLE literal overrun');
      for (let j = 0; j < run; j++) out.push(src[i + j]);
      i += run;
    } else {
      const run = (ctrl - 128) + 1;
      for (let j = 0; j < run; j++) out.push(0);
    }
  }
  return Buffer.from(out);
}

function computeTilesMeta(width, height, tileSize) {
  const tilesX = Math.ceil(width / tileSize);
  const tilesY = Math.ceil(height / tileSize);
  const totalTiles = tilesX * tilesY;
  return { tilesX, tilesY, totalTiles };
}

function tileRegionOffsets(tileX, tileY, width, height, tileSize, bytesPerPixel) {
  const x0 = tileX * tileSize;
  const y0 = tileY * tileSize;
  const w = Math.min(tileSize, width - x0);
  const h = Math.min(tileSize, height - y0);
  const rowStrideBytes = width * bytesPerPixel;
  const tileRowBytes = w * bytesPerPixel;
  return { x0, y0, w, h, rowStrideBytes, tileRowBytes };
}

function tilesDiffer(cur, prev, width, height, bytesPerPixel, tileSize, tileX, tileY) {
  const { x0, y0, w, h, rowStrideBytes, tileRowBytes } = tileRegionOffsets(
    tileX, tileY, width, height, tileSize, bytesPerPixel
  );
  const startByte = (y0 * width + x0) * bytesPerPixel;
  for (let row = 0; row < h; row++) {
    const off = startByte + row * rowStrideBytes;
    const a = cur.subarray(off, off + tileRowBytes);
    const b = prev.subarray(off, off + tileRowBytes);
    for (let i = 0; i < tileRowBytes; i++) {
      if (a[i] !== b[i]) return true;
    }
  }
  return false;
}

function extractTileXor(cur, prev, width, height, bytesPerPixel, tileSize, tileX, tileY) {
  const { x0, y0, w, h, rowStrideBytes, tileRowBytes } = tileRegionOffsets(
    tileX, tileY, width, height, tileSize, bytesPerPixel
  );
  const out = Buffer.allocUnsafe(w * h * bytesPerPixel);
  let p = 0;
  const startByte = (y0 * width + x0) * bytesPerPixel;
  for (let row = 0; row < h; row++) {
    const off = startByte + row * rowStrideBytes;
    const a = cur.subarray(off, off + tileRowBytes);
    const b = prev.subarray(off, off + tileRowBytes);
    for (let i = 0; i < tileRowBytes; i++) {
      out[p++] = a[i] ^ b[i];
    }
  }
  return out;
}

function applyTileXor(dst, prev, xorData, width, height, bytesPerPixel, tileSize, tileX, tileY) {
  const { x0, y0, w, h, rowStrideBytes, tileRowBytes } = tileRegionOffsets(
    tileX, tileY, width, height, tileSize, bytesPerPixel
  );
  const startByte = (y0 * width + x0) * bytesPerPixel;
  let p = 0;
  for (let row = 0; row < h; row++) {
    const off = startByte + row * rowStrideBytes;
    for (let i = 0; i < tileRowBytes; i++) {
      dst[off + i] = prev[off + i] ^ xorData[p++];
    }
  }
}

/**
 * Encodes a frame.
 * - Always returns a zlib-compressed keyframe (prevScreen is ignored).
 */
function encodeFrame(currentScreen, prevScreen, options) {
  const opts = Object.assign({}, DEFAULTS, options || {});
  const { width, height, bytesPerPixel } = opts;
  const cur = toUint8Array(currentScreen);

  if (!cur) throw new Error('currentScreen is required');
  const expectedLen = width * height * bytesPerPixel;
  if (cur.length !== expectedLen) {
    throw new Error(`currentScreen length ${cur.length} != expected ${expectedLen}`);
  }

  // Always keyframe (zlib)
  const header = writeHeader({
    frameType: FRAME_TYPE.KEYFRAME_ZLIB,
    width, height, bytesPerPixel,
  });
  const body = zlib.deflateSync(Buffer.from(cur), { level: 6 });
  return Buffer.concat([header, body]);
}

/**
 * Quick stats helper for analysis/logging.
 */
function diffStats(currentScreen, prevScreen, options) {
  const opts = Object.assign({}, DEFAULTS, options || {});
  const { width, height, bytesPerPixel, tileSize } = opts;
  const cur = toUint8Array(currentScreen);
  const prev = toUint8Array(prevScreen);
  const { tilesX, tilesY, totalTiles } = computeTilesMeta(width, height, tileSize);
  let changedTiles = 0;
  if (!prev) {
    changedTiles = totalTiles;
  } else {
    for (let ty = 0; ty < tilesY; ty++) {
      for (let tx = 0; tx < tilesX; tx++) {
        if (tilesDiffer(cur, prev, width, height, bytesPerPixel, tileSize, tx, ty)) changedTiles++;
      }
    }
  }
  return {
    changedTiles,
    totalTiles,
    ratio: changedTiles / totalTiles,
  };
}

module.exports = {
  DEFAULTS,
  FRAME_TYPE,
  encodeFrame,
  zrleEncode,
  zrleDecode,
  diffStats,
};


