import 'dart:async';

import '../courier.dart';
import '../dispatch.dart';
import '../envoy_error.dart';
import '../metrics.dart';
import '../missive.dart';

/// A [Courier] that tracks request metrics and reports them via callback.
///
/// Captures method, URL, status, duration, and error information for every
/// request. Connect the [onMetric] callback to Colossus for MCP-accessible
/// API monitoring, or to any analytics system.
///
/// ```dart
/// envoy.addCourier(MetricsCourier(
///   onMetric: (metric) {
///     // Report to Colossus for MCP monitoring
///     Colossus.instance.trackApiMetric(metric.toJson());
///   },
/// ));
/// ```
class MetricsCourier extends Courier {
  /// Creates a [MetricsCourier] with the given callback.
  MetricsCourier({required this.onMetric});

  /// Called after every request with the collected metric data.
  final void Function(EnvoyMetric metric) onMetric;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    final stopwatch = Stopwatch()..start();
    final timestamp = DateTime.now();

    try {
      final dispatch = await chain.proceed(missive);
      stopwatch.stop();

      onMetric(
        EnvoyMetric(
          method: missive.method.verb,
          url: missive.resolvedUri.toString(),
          statusCode: dispatch.statusCode,
          duration: stopwatch.elapsed,
          success: dispatch.isSuccess,
          responseSize: dispatch.rawBody?.length,
          cached: dispatch.headers['x-envoy-cache'] == 'hit',
          timestamp: timestamp,
        ),
      );

      return dispatch;
    } on EnvoyError catch (e) {
      stopwatch.stop();

      onMetric(
        EnvoyMetric(
          method: missive.method.verb,
          url: missive.resolvedUri.toString(),
          statusCode: e.dispatch?.statusCode,
          duration: stopwatch.elapsed,
          success: false,
          error: e.message,
          timestamp: timestamp,
        ),
      );

      rethrow;
    }
  }
}
