import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

class AppLogger {
  AppLogger._internal();
  static final AppLogger instance = AppLogger._internal();

  Logger? _logger;

  void init({Level? level}) {
    final resolvedLevel = level ?? (kReleaseMode ? Level.info : Level.debug);
    _logger = Logger(
      level: resolvedLevel,
      printer: PrettyPrinter(
        methodCount: 1,
        errorMethodCount: 5,
        lineLength: 100,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
        noBoxingByDefault: true,
      ),
      filter: null,
      output: null,
    );
    d('Logger initialized (level=$resolvedLevel)');
  }

  bool get _isReady => _logger != null;

  void v(String message) => _logger?.v(message);
  void d(String message) => _logger?.d(message);
  void i(String message) => _logger?.i(message);
  void w(String message) => _logger?.w(message);

  void e(String message, [Object? error, StackTrace? stackTrace]) {
    _logger?.e(message, error: error, stackTrace: stackTrace);
  }

  void wtf(String message, [Object? error, StackTrace? stackTrace]) {
    _logger?.wtf(message, error: error, stackTrace: stackTrace);
  }

  // Safe wrapper for places where logger may not be initialized yet.
  void safeError(String message, [Object? error, StackTrace? stackTrace]) {
    if (_isReady) {
      e(message, error, stackTrace);
    } else {
      // Best-effort fallback to print to avoid losing the error.
      // ignore: avoid_print
      print('ERROR: $message ${error != null ? '- $error' : ''}');
      if (stackTrace != null) {
        // ignore: avoid_print
        print(stackTrace);
      }
    }
  }

  void flutterError(FlutterErrorDetails details) {
    final exception = details.exception;
    final stack = details.stack ?? StackTrace.current;
    e('FlutterError: $exception', exception, stack);
  }
}

// Convenient alias used throughout the app.
final AppLogger log = AppLogger.instance;


