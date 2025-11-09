'use strict';

/**
 * Audio packet encoder.
 * - Converts input samples to Int16 PCM (mono), then zlib-deflates.
 * - Prepends a compact header so the client can identify and decode quickly.
 *
 * Header layout (6 bytes):
 * [0]: 'A' (0x41) - magic
 * [1]: version (0x01)
 * [2]: format (0 = int16_le)
 * [3]: channels (uint8) - currently 1 (mono)
 * [4..5]: sampleRate (uint16 LE) - default 44100
 */

const zlib = require('zlib');

const AUDIO_MAGIC = 0x41; // 'A'
const AUDIO_VERSION = 0x01;
const FORMAT_INT16_LE = 0;

function toInt16PcmMono(samples) {
  if (!samples) return new Int16Array(0);
  // If already Int16Array, return directly (ensure mono)
  if (samples instanceof Int16Array) return samples;

  // If Float32Array or any typed numeric view: clamp and scale
  if (ArrayBuffer.isView(samples)) {
    const len = samples.length >>> 0;
    const out = new Int16Array(len);
    for (let i = 0; i < len; i++) {
      const v = Math.max(-1, Math.min(1, Number(samples[i]) || 0));
      out[i] = (v * 32767) | 0;
    }
    return out;
  }

  // If ArrayBuffer, assume Int16 PCM
  if (samples instanceof ArrayBuffer) {
    return new Int16Array(samples);
  }

  // If plain array of numbers
  if (Array.isArray(samples)) {
    const len = samples.length >>> 0;
    const out = new Int16Array(len);
    for (let i = 0; i < len; i++) {
      const v = Math.max(-1, Math.min(1, Number(samples[i]) || 0));
      out[i] = (v * 32767) | 0;
    }
    return out;
  }

  return new Int16Array(0);
}

function int16ToFloat32(pcm) {
  const n = pcm ? pcm.length >>> 0 : 0;
  const out = new Float32Array(n);
  for (let i = 0; i < n; i++) out[i] = pcm[i] / 32768;
  return out;
}

function float32ToInt16(f32) {
  const n = f32 ? f32.length >>> 0 : 0;
  const out = new Int16Array(n);
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, Number(f32[i]) || 0));
    out[i] = (v * 32767) | 0;
  }
  return out;
}

function resampleLinearFloat32(input, fromSR, toSR) {
  if (!input || !input.length || !isFinite(fromSR) || !isFinite(toSR) || fromSR <= 0 || toSR <= 0) {
    return new Float32Array(0);
  }
  if (fromSR === toSR) return input;
  const ratio = toSR / fromSR;
  const outLen = Math.max(1, Math.round(input.length * ratio));
  const out = new Float32Array(outLen);
  if (outLen === 1) { out[0] = input[0]; return out; }
  const step = (input.length - 1) / (outLen - 1);
  for (let i = 0; i < outLen; i++) {
    const pos = i * step;
    const i0 = Math.floor(pos);
    const i1 = Math.min(input.length - 1, i0 + 1);
    const t = pos - i0;
    out[i] = input[i0] * (1 - t) + input[i1] * t;
  }
  return out;
}

function encodeAudio(samples, options) {
  const opts = Object.assign({ sampleRate: 44100, channels: 1, inputSampleRate: 0 }, options || {});
  const pcm = toInt16PcmMono(samples);
  let pcmToEncode = pcm;

  // Optional server-side resampling if input sample rate is provided and differs
  if (opts.inputSampleRate && opts.inputSampleRate > 0 && opts.inputSampleRate !== opts.sampleRate) {
    const f32 = int16ToFloat32(pcm);
    const f32Resampled = resampleLinearFloat32(f32, opts.inputSampleRate, opts.sampleRate);
    pcmToEncode = float32ToInt16(f32Resampled);
  }

  // Header (6 bytes)
  const header = Buffer.allocUnsafe(6);
  header[0] = AUDIO_MAGIC;
  header[1] = AUDIO_VERSION;
  header[2] = FORMAT_INT16_LE;
  header[3] = (opts.channels >>> 0) & 0xff;
  header.writeUInt16LE((opts.sampleRate >>> 0) & 0xffff, 4);

  // Body (zlib-deflated PCM)
  const body = zlib.deflateSync(Buffer.from(pcmToEncode.buffer, pcmToEncode.byteOffset, pcmToEncode.byteLength), { level: 6 });
  return Buffer.concat([header, body]);
}

module.exports = {
  encodeAudio,
};



