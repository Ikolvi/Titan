import 'package:meta/meta.dart';

/// Caching strategies supported by [CacheCourier].
enum CacheStrategy {
  /// Try cache first; fall back to network on miss or expiry.
  cacheFirst,

  /// Try network first; fall back to cache on failure.
  networkFirst,

  /// Only use cache; never hit the network.
  cacheOnly,

  /// Only use network; bypass cache entirely.
  networkOnly,

  /// Return stale cache immediately; revalidate in background.
  staleWhileRevalidate,
}

/// Configures how [CacheCourier] handles caching for a request.
///
/// ```dart
/// // Cache-first with 5 minute TTL
/// CachePolicy.cacheFirst(ttl: Duration(minutes: 5))
///
/// // Network-first with 1 hour fallback cache
/// CachePolicy.networkFirst(ttl: Duration(hours: 1))
///
/// // Stale-while-revalidate for fast UI
/// CachePolicy.staleWhileRevalidate(ttl: Duration(minutes: 10))
/// ```
@immutable
class CachePolicy {
  /// Creates a [CachePolicy] with the given strategy and TTL.
  const CachePolicy({required this.strategy, this.ttl});

  /// Cache-first: serve from cache if available and fresh, otherwise fetch.
  ///
  /// Best for data that changes infrequently (settings, profiles).
  const CachePolicy.cacheFirst({this.ttl})
    : strategy = CacheStrategy.cacheFirst;

  /// Network-first: always fetch, but fall back to cache on failure.
  ///
  /// Best for data that should be current but must be available offline.
  const CachePolicy.networkFirst({this.ttl})
    : strategy = CacheStrategy.networkFirst;

  /// Cache-only: never make network requests.
  ///
  /// Useful for offline mode or pre-loaded data.
  const CachePolicy.cacheOnly()
    : strategy = CacheStrategy.cacheOnly,
      ttl = null;

  /// Network-only: always fetch, cache the result for future fallback.
  ///
  /// Best for real-time data that must always be fresh.
  const CachePolicy.networkOnly()
    : strategy = CacheStrategy.networkOnly,
      ttl = null;

  /// Stale-while-revalidate: return cache immediately, refresh in background.
  ///
  /// Best for data that should load instantly but eventually be current.
  const CachePolicy.staleWhileRevalidate({this.ttl})
    : strategy = CacheStrategy.staleWhileRevalidate;

  /// The caching strategy to use.
  final CacheStrategy strategy;

  /// How long cached entries remain valid.
  ///
  /// `null` means entries never expire (until evicted).
  final Duration? ttl;

  @override
  String toString() => 'CachePolicy($strategy, ttl: $ttl)';
}
