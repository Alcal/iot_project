'use strict';

(function (global) {
  const FRAME_TYPE = { KEYFRAME_ZLIB: 1 };

  function toU8(input) {
    if (input == null) return null;
    if (input instanceof Uint8Array) return input;
    if (input instanceof ArrayBuffer) return new Uint8Array(input);
    if (ArrayBuffer.isView(input)) return new Uint8Array(input.buffer, input.byteOffset, input.byteLength);
    throw new TypeError('Expected Uint8Array or ArrayBuffer');
  }

  function readHeader(buf) {
    if (!buf || buf.length < 8) throw new Error('Packet too short for header');
    if (buf[0] !== 0x56) throw new Error('Invalid magic');
    if (buf[1] !== 0x01) throw new Error('Unsupported version');
    const frameType = buf[2];
    const width = buf[3] | (buf[4] << 8);
    const height = buf[5] | (buf[6] << 8);
    const bytesPerPixel = buf[7];
    return { frameType, width, height, bytesPerPixel, headerBytes: 8 };
  }

  function decodeFrame(packet) {
    const buf = toU8(packet);
    const { frameType, width, height, bytesPerPixel, headerBytes } = readHeader(buf);
    const expectedLen = width * height * bytesPerPixel;

    if (frameType === FRAME_TYPE.KEYFRAME_ZLIB) {
      if (!global.pako || !global.pako.inflate) throw new Error('pako.inflate not available');
      const body = buf.subarray(headerBytes);
      const inflated = global.pako.inflate(body);
      if (inflated.length !== expectedLen) {
        throw new Error('Keyframe size mismatch');
      }
      return inflated;
    }

    throw new Error('Unsupported frame type: ' + frameType);
  }

  global.VideoCodec = {
    decodeFrame,
  };
})(typeof window !== 'undefined' ? window : globalThis);


