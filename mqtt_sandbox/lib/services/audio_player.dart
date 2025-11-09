import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:collection';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:iot_gameboy/services/logger.dart';

class AudioPlayerService {
  AudioPlayerService(this._audioStream);

  final Stream<Uint8List> _audioStream;
  StreamSubscription<Uint8List>? _sub;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _playerOpened = false;
  int _currentSampleRate = 0;
  int _currentChannels = 0;
  // Jitter buffer and drain timer
  final Queue<Uint8List> _bufferQueue = Queue<Uint8List>();
  int _bufferedBytes = 0;
  Timer? _drainTimer;

  // Audio packet constants (must match server/src/audio.js)
  static const int _magic = 0x41; // 'A'
  static const int _version = 0x01;
  static const int _formatInt16Le = 0;
  // Use a standard output sample rate like the web client (index.html)
  static const int _targetSampleRate = 44100;
  static const int _drainIntervalMs = 20; // 20ms cadence similar to index.html
  static const int _maxBufferedMs = 180; // cap jitter buffer around 180ms

  Future<void> start() async {
    if (_sub != null) return;
    await _ensurePlayer(
      sampleRate: _targetSampleRate,
      channels: 1,
      reset: true,
    );
    _startDrainTimer();
    _sub = _audioStream.listen(
      _onPacket,
      onError: (e, st) => log.d('Audio stream error: $e\n$st'),
      onDone: () => stop(),
    );
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _stopDrainTimer();
    _clearQueue();
    await _teardownPlayer();
  }

  Future<void> _onPacket(Uint8List packet) async {
    if (packet.length < 6) return;
    if (packet[0] != _magic || packet[1] != _version) return;

    final format = packet[2];
    final channels = packet[3];
    final sampleRate = packet[4] | (packet[5] << 8);
    if (format != _formatInt16Le) {
      return; // unsupported
    }
    if (channels < 1) return;
    if (sampleRate <= 0) return;

    try {
      // Inflate zlib body
      final body = packet.sublist(6);
      final inflated = Uint8List.fromList(ZLibDecoder().decodeBytes(body));
      if (inflated.isEmpty || (inflated.length & 1) == 1) {
        return;
      }

      // Reconfigure player if channels changed (we fix output SR to 44.1k like web)
      if (_currentChannels != channels ||
          _currentSampleRate != _targetSampleRate) {
        await _ensurePlayer(
          sampleRate: _targetSampleRate,
          channels: channels,
          reset: true,
        );
      }

      // Convert Int16LE -> Float32 mono
      final pcmI16 = _int16FromLittleEndianBytes(inflated);
      if (pcmI16.isEmpty) return;
      final f32 = Float32List(pcmI16.length);
      for (var i = 0; i < pcmI16.length; i++) {
        f32[i] = pcmI16[i] / 32768.0;
      }

      // Resample to target SR (linear interpolation, like index.html)
      final resampled = _resampleLinear(f32, sampleRate, _targetSampleRate);
      if (resampled.isEmpty) return;

      // Float32 -> Int16LE bytes
      final outBytes = _float32ToInt16LeBytes(resampled);

      // Enqueue for clocked draining
      _enqueue(outBytes);
    } catch (e, st) {
      log.d('Audio packet inflate/playback failed: $e\n$st');
    }
  }

  Future<void> _ensurePlayer({
    required int sampleRate,
    required int channels,
    bool reset = false,
  }) async {
    if (reset) {
      await _teardownPlayer();
    }
    if (!_playerOpened) {
      await _player.openPlayer();
      _playerOpened = true;
    }
    // If already streaming with correct params, do nothing
    if (_player.isPlaying &&
        _currentSampleRate == sampleRate &&
        _currentChannels == channels) {
      return;
    }
    if (_player.isPlaying) {
      await _player.stopPlayer();
    }
    // Start stream mode (PCM16 mono)
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: channels,
      sampleRate: sampleRate,
      interleaved: true,
      // Slightly larger buffer to reduce underruns on some devices
      bufferSize: 12288,
    );
    _currentSampleRate = sampleRate;
    _currentChannels = channels;
  }

  Future<void> _teardownPlayer() async {
    try {
      if (_player.isPlaying) {
        await _player.stopPlayer();
      }
    } catch (_) {}
    if (_playerOpened) {
      try {
        await _player.closePlayer();
      } catch (_) {}
      _playerOpened = false;
    }
    _currentSampleRate = 0;
    _currentChannels = 0;
  }

  // --- Helpers: PCM conversions & resampling ---
  int get _bytesPerMs {
    final ch = _currentChannels > 0 ? _currentChannels : 1;
    return (ch * _targetSampleRate * 2) ~/ 1000;
  }

  int get _drainChunkBytes {
    final b = _bytesPerMs * _drainIntervalMs;
    return b > 0 ? b : 2;
  }

  int get _maxBufferedBytes => _bytesPerMs * _maxBufferedMs;

  void _startDrainTimer() {
    _drainTimer ??= Timer.periodic(
      const Duration(milliseconds: _drainIntervalMs),
      (_) {
        _drainOnce();
      },
    );
  }

  void _stopDrainTimer() {
    _drainTimer?.cancel();
    _drainTimer = null;
  }

  void _enqueue(Uint8List bytes) {
    if (bytes.isEmpty) return;
    _bufferQueue.add(bytes);
    _bufferedBytes += bytes.length;
    // Bound the jitter buffer to avoid runaway latency
    while (_bufferedBytes > _maxBufferedBytes && _bufferQueue.isNotEmpty) {
      final removed = _bufferQueue.removeFirst();
      _bufferedBytes -= removed.length;
    }
  }

  void _clearQueue() {
    _bufferQueue.clear();
    _bufferedBytes = 0;
  }

  void _drainOnce() {
    final sink = _player.foodSink;
    if (sink == null) return;
    final need = _drainChunkBytes;
    if (need <= 0) return;

    if (_bufferedBytes <= 0) {
      // No data available: maintain clock with silence
      sink.add(FoodData(Uint8List(need)));
      return;
    }

    final out = Uint8List(need);
    var written = 0;
    while (written < need && _bufferQueue.isNotEmpty) {
      final head = _bufferQueue.first;
      final take = math.min(head.length, need - written);
      out.setRange(written, written + take, head, 0);
      written += take;
      if (take == head.length) {
        _bufferQueue.removeFirst();
      } else {
        // Put back the remainder
        _bufferQueue.removeFirst();
        _bufferQueue.addFirst(Uint8List.fromList(head.sublist(take)));
      }
      _bufferedBytes -= take;
    }
    sink.add(FoodData(out));
  }

  Int16List _int16FromLittleEndianBytes(Uint8List bytes) {
    if (bytes.isEmpty || (bytes.length & 1) == 1) return Int16List(0);
    final bd = ByteData.sublistView(bytes);
    final n = bytes.length >> 1;
    final out = Int16List(n);
    for (var i = 0; i < n; i++) {
      out[i] = bd.getInt16(i * 2, Endian.little);
    }
    return out;
  }

  Uint8List _float32ToInt16LeBytes(Float32List f32) {
    if (f32.isEmpty) return Uint8List(0);
    final out = Uint8List(f32.length * 2);
    final bd = ByteData.sublistView(out);
    for (var i = 0; i < f32.length; i++) {
      final s = f32[i];
      final clamped = s.isFinite ? math.max(-1.0, math.min(1.0, s)) : 0.0;
      final v = (clamped * 32767.0).round();
      bd.setInt16(i * 2, v, Endian.little);
    }
    return out;
  }

  Float32List _resampleLinear(Float32List input, int fromSR, int toSR) {
    if (input.isEmpty || fromSR <= 0 || toSR <= 0) return Float32List(0);
    if (fromSR == toSR) return input;
    final ratio = toSR / fromSR;
    final outLen = math.max(1, (input.length * ratio).round());
    if (outLen == 1) return Float32List.fromList([input[0]]);
    final out = Float32List(outLen);
    final step = (input.length - 1) / (outLen - 1);
    for (var i = 0; i < outLen; i++) {
      final pos = i * step;
      final i0 = pos.floor();
      final i1 = math.min(input.length - 1, i0 + 1);
      final t = pos - i0;
      out[i] = input[i0] * (1 - t) + input[i1] * t;
    }
    return out;
  }
}
