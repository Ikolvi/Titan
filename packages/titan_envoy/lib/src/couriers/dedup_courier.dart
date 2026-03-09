import 'dart:async';

import '../courier.dart';
import '../dispatch.dart';
import '../missive.dart';

/// A [Courier] that deduplicates identical in-flight requests.
///
/// When multiple calls to the same URL (with the same method and parameters)
/// are made concurrently, only one network request is executed. All callers
/// receive the same [Dispatch] response.
///
/// This is especially useful for UI components that may trigger the same
/// API call multiple times during rebuilds.
///
/// ```dart
/// envoy.addCourier(DedupCourier());
///
/// // These two calls result in only ONE network request:
/// final a = envoy.get('/users');
/// final b = envoy.get('/users');
/// final results = await Future.wait([a, b]);
/// // results[0] == results[1]
/// ```
class DedupCourier extends Courier {
  /// Creates a [DedupCourier].
  ///
  /// - [ttl]: How long to keep a dedup entry after completion.
  ///   Set to [Duration.zero] to remove immediately after resolution.
  DedupCourier({this.ttl = Duration.zero});

  /// Time to keep the dedup entry after the request completes.
  final Duration ttl;

  final Map<String, Future<Dispatch>> _inFlight = {};

  /// Number of currently in-flight deduplicated requests.
  int get inFlightCount => _inFlight.length;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) {
    final key = _dedupKey(missive);

    // Return existing in-flight request if available
    final existing = _inFlight[key];
    if (existing != null) return existing;

    // Create new request and track it
    final future = chain.proceed(missive).whenComplete(() {
      if (ttl == Duration.zero) {
        _inFlight.remove(key);
      } else {
        Future<void>.delayed(ttl, () => _inFlight.remove(key));
      }
    });

    _inFlight[key] = future;
    return future;
  }

  String _dedupKey(Missive missive) {
    return '${missive.method.verb}:${missive.resolvedUri}';
  }
}
