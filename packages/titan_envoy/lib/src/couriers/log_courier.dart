import 'dart:async';

import '../courier.dart';
import '../dispatch.dart';
import '../envoy_error.dart';
import '../missive.dart';

/// A [Courier] that logs HTTP requests and responses.
///
/// Useful for debugging network calls during development. Logs can be
/// directed to any output via the [log] callback (default: `print`).
///
/// ```dart
/// envoy.addCourier(LogCourier());
///
/// // Custom logger
/// envoy.addCourier(LogCourier(
///   log: (message) => chronicle.info(message),
///   logHeaders: true,
///   logBody: true,
/// ));
/// ```
class LogCourier extends Courier {
  /// Creates a [LogCourier] with configurable output options.
  LogCourier({
    this.log = print,
    this.logHeaders = false,
    this.logBody = false,
    this.logErrors = true,
  });

  /// Output function for log messages. Defaults to [print].
  final void Function(String message) log;

  /// Whether to log request and response headers.
  final bool logHeaders;

  /// Whether to log request and response bodies.
  final bool logBody;

  /// Whether to log errors.
  final bool logErrors;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    _logRequest(missive);
    final stopwatch = Stopwatch()..start();

    try {
      final dispatch = await chain.proceed(missive);
      stopwatch.stop();
      _logResponse(dispatch, stopwatch.elapsed);
      return dispatch;
    } on EnvoyError catch (e) {
      stopwatch.stop();
      if (logErrors) {
        log(
          '[Envoy] ✗ ${missive.method.verb} ${missive.resolvedUri} '
          '→ ${e.type.name} (${stopwatch.elapsedMilliseconds}ms)',
        );
        if (e.error != null) log('[Envoy]   Error: ${e.error}');
      }
      rethrow;
    }
  }

  void _logRequest(Missive missive) {
    log('[Envoy] → ${missive.method.verb} ${missive.resolvedUri}');
    if (logHeaders && missive.headers.isNotEmpty) {
      for (final entry in missive.headers.entries) {
        log('[Envoy]   ${entry.key}: ${entry.value}');
      }
    }
    if (logBody && missive.data != null) {
      log('[Envoy]   Body: ${missive.encodedBody}');
    }
  }

  void _logResponse(Dispatch dispatch, Duration duration) {
    log(
      '[Envoy] ✓ ${dispatch.missive.method.verb} '
      '${dispatch.missive.resolvedUri} → ${dispatch.statusCode} '
      '(${duration.inMilliseconds}ms)',
    );
    if (logHeaders && dispatch.headers.isNotEmpty) {
      for (final entry in dispatch.headers.entries) {
        log('[Envoy]   ${entry.key}: ${entry.value}');
      }
    }
    if (logBody && dispatch.rawBody != null) {
      final body = dispatch.rawBody!;
      final truncated = body.length > 500
          ? '${body.substring(0, 500)}...'
          : body;
      log('[Envoy]   Body: $truncated');
    }
  }
}
