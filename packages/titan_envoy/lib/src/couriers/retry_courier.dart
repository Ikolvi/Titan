import 'dart:async';
import 'dart:math';

import '../courier.dart';
import '../dispatch.dart';
import '../envoy_error.dart';
import '../missive.dart';

/// A [Courier] that automatically retries failed requests.
///
/// Implements exponential backoff with optional jitter. Retries on
/// connection errors, timeouts, and configurable status codes.
///
/// ```dart
/// envoy.addCourier(RetryCourier(
///   maxRetries: 3,
///   retryDelay: Duration(milliseconds: 500),
///   retryOn: {500, 502, 503},
/// ));
/// ```
class RetryCourier extends Courier {
  /// Creates a [RetryCourier] with configurable retry behavior.
  RetryCourier({
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 300),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.addJitter = true,
    Set<int>? retryOn,
    this.retryOnTimeout = true,
    this.retryOnConnectionError = true,
    this.shouldRetry,
  }) : retryOn = retryOn ?? {408, 429, 500, 502, 503, 504};

  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Initial delay between retries.
  final Duration retryDelay;

  /// Factor by which the delay increases after each retry.
  final double backoffMultiplier;

  /// Maximum delay between retries (caps exponential growth).
  final Duration maxDelay;

  /// Whether to add random jitter to retry delays.
  final bool addJitter;

  /// HTTP status codes that trigger a retry.
  final Set<int> retryOn;

  /// Whether to retry on timeout errors.
  final bool retryOnTimeout;

  /// Whether to retry on connection errors.
  final bool retryOnConnectionError;

  /// Custom retry predicate. Overrides default behavior when provided.
  ///
  /// Return `true` to retry, `false` to propagate the error.
  final bool Function(EnvoyError error, int attempt)? shouldRetry;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    var attempt = 0;

    while (true) {
      try {
        final dispatch = await chain.proceed(missive);

        // Check if the successful response should trigger a retry
        if (attempt < maxRetries && retryOn.contains(dispatch.statusCode)) {
          attempt++;
          await _delay(attempt);
          continue;
        }

        return dispatch;
      } on EnvoyError catch (e) {
        if (attempt >= maxRetries || !_shouldRetry(e, attempt + 1)) {
          rethrow;
        }
        attempt++;
        await _delay(attempt);
      }
    }
  }

  bool _shouldRetry(EnvoyError error, int attempt) {
    if (shouldRetry != null) return shouldRetry!(error, attempt);

    return switch (error.type) {
      EnvoyErrorType.timeout => retryOnTimeout,
      EnvoyErrorType.connectionError => retryOnConnectionError,
      EnvoyErrorType.badResponse =>
        error.dispatch != null && retryOn.contains(error.dispatch!.statusCode),
      EnvoyErrorType.cancelled => false,
      EnvoyErrorType.parseError => false,
      EnvoyErrorType.unknown => false,
    };
  }

  Future<void> _delay(int attempt) async {
    final baseMs =
        retryDelay.inMilliseconds * pow(backoffMultiplier, attempt - 1).toInt();
    final cappedMs = min(baseMs, maxDelay.inMilliseconds);

    final delayMs = addJitter
        ? (cappedMs * 0.5 + Random().nextDouble() * cappedMs * 0.5).toInt()
        : cappedMs;

    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }
}
