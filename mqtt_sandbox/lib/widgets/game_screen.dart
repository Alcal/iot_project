import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mqtt_sandbox/services/mqtt_services.dart';
import 'package:archive/archive.dart';
import 'package:mqtt_sandbox/services/logger.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  StreamSubscription<bool>? _connSub;
  StreamSubscription<FrameMeta>? _metaSub;
  StreamSubscription<Uint8List>? _frameSub;

  int _frameWidth = 160;
  int _frameHeight = 144;
  String _format = 'rgba8888';
  ui.Image? _lastImage;

  // Video packet constants (must match server/public decoder)
  static const int _magic = 0x56; // 'V'
  static const int _version = 0x01;
  static const int _frameTypeKeyframeZlib = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final svc = context.read<MqttService>();
      _connSub = svc.connectionStream.listen((connected) {
        if (!mounted) return;
        if (!connected) {
          _disposeImage();
          setState(() {});
        }
      });
      _metaSub = svc.metaStream.listen((meta) {
        if (!mounted) return;
        setState(() {
          _frameWidth = meta.width;
          _frameHeight = meta.height;
          _format = meta.format;
        });
      });
      _frameSub = svc.frameStream.listen((bytes) {
        if (!mounted) return;
        // Try to decode compressed packet (with header). If not a packet, fall back to raw RGBA.
        final decoded = _tryDecodePacket(bytes);
        if (decoded != null) {
          _decodeAndSetFrame(decoded);
          return;
        }
        // Fallback: old behavior expecting raw rgba8888
        if (_format != 'rgba8888') return;
        final expected = _frameWidth * _frameHeight * 4;
        if (bytes.length < expected) return;
        _decodeAndSetFrame(bytes.sublist(0, expected));
      });
    });
  }

  @override
  void dispose() {
    _disposeImage();
    _connSub?.cancel();
    _metaSub?.cancel();
    _frameSub?.cancel();
    super.dispose();
  }

  void _disposeImage() {
    try {
      // ignore: deprecated_member_use
      _lastImage?.dispose();
    } catch (e, st) {
      log.d('Image dispose failed: $e\n$st');
    }
    _lastImage = null;
  }

  Future<void> _decodeAndSetFrame(Uint8List rgba) async {
    final completer = Completer<ui.Image>();
    try {
      ui.decodeImageFromPixels(
        rgba,
        _frameWidth,
        _frameHeight,
        ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );
      final img = await completer.future;
      if (!mounted) {
        try {
          img.dispose();
        } catch (e) {
          log.d('Late image dispose failed: $e');
        }
        return;
      }
      _disposeImage();
      setState(() {
        _lastImage = img;
      });
    } catch (e, st) {
      log.d('Image decode failed: $e\n$st');
    }
  }

  // Attempts to decode a compressed video packet per public/video-decode.js
  // Returns RGBA8888 pixel buffer or null if the data is not a valid packet.
  Uint8List? _tryDecodePacket(Uint8List packet) {
    if (packet.length < 8) return null;
    if (packet[0] != _magic || packet[1] != _version) return null;
    final frameType = packet[2];
    final width = packet[3] | (packet[4] << 8);
    final height = packet[5] | (packet[6] << 8);
    final bytesPerPixel = packet[7];
    if (frameType != _frameTypeKeyframeZlib) {
      return null; // unsupported type for now
    }
    try {
      final body = packet.sublist(8);
      final inflated = Uint8List.fromList(ZLibDecoder().decodeBytes(body));
      final expectedLen = width * height * bytesPerPixel;
      if (inflated.length != expectedLen) {
        return null;
      }
      // Update meta inferred from packet header
      if (mounted) {
        setState(() {
          _frameWidth = width;
          _frameHeight = height;
          _format = bytesPerPixel == 4 ? 'rgba8888' : 'unknown';
        });
      } else {
        _frameWidth = width;
        _frameHeight = height;
        _format = bytesPerPixel == 4 ? 'rgba8888' : 'unknown';
      }
      if (bytesPerPixel != 4) {
        // Only rgba8888 is supported by the current renderer
        return null;
      }
      return inflated;
    } catch (e) {
      log.d('Video packet inflate failed: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _frameWidth / _frameHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: const Color(0xFF333333)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: _lastImage == null
            ? const Center(
                child: Text(
                  'Waiting for frame...\nSubscribe to meta and frame',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : FittedBox(
                fit: BoxFit.contain,
                child: RawImage(image: _lastImage),
              ),
      ),
    );
  }
}
