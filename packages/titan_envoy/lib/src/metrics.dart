import 'package:meta/meta.dart';

/// An EnvoyMetric captures performance data for a single HTTP request.
///
/// Used by [MetricsCourier] to report API activity. Connect the metrics
/// callback to Colossus for MCP-accessible API monitoring.
///
/// ```dart
/// envoy.addCourier(MetricsCourier(
///   onMetric: (metric) {
///     print('${metric.method} ${metric.url} → ${metric.statusCode}'
///         ' in ${metric.duration.inMilliseconds}ms');
///   },
/// ));
/// ```
@immutable
class EnvoyMetric {
  /// Creates a new [EnvoyMetric].
  const EnvoyMetric({
    required this.method,
    required this.url,
    required this.duration,
    required this.success,
    required this.timestamp,
    this.statusCode,
    this.error,
    this.requestSize,
    this.responseSize,
    this.cached = false,
  });

  /// The HTTP method (GET, POST, etc.).
  final String method;

  /// The request URL.
  final String url;

  /// The response status code, if received.
  final int? statusCode;

  /// Total round-trip duration.
  final Duration duration;

  /// Whether the request succeeded.
  final bool success;

  /// Error message, if the request failed.
  final String? error;

  /// Request body size in bytes, if known.
  final int? requestSize;

  /// Response body size in bytes, if known.
  final int? responseSize;

  /// Whether this response was served from cache.
  final bool cached;

  /// When the request was initiated.
  final DateTime timestamp;

  /// Serializes this metric to a JSON-compatible map.
  ///
  /// Useful for passing to Colossus:
  /// ```dart
  /// Colossus.instance.trackApiMetric(metric.toJson());
  /// ```
  Map<String, dynamic> toJson() {
    return {
      'method': method,
      'url': url,
      'statusCode': statusCode,
      'durationMs': duration.inMilliseconds,
      'success': success,
      'error': error,
      'requestSize': requestSize,
      'responseSize': responseSize,
      'cached': cached,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() {
    final status = statusCode != null ? ' → $statusCode' : '';
    final ms = '${duration.inMilliseconds}ms';
    final flag = success ? '✓' : '✗';
    return 'EnvoyMetric($flag $method $url$status $ms)';
  }
}
