import 'dart:async';

import '../cache/cache_policy.dart';
import '../cache/envoy_cache.dart';
import '../courier.dart';
import '../dispatch.dart';
import '../missive.dart';

/// A [Courier] that caches HTTP responses via a pluggable [EnvoyCache] adapter.
///
/// Only caches GET requests by default. Supports multiple caching strategies
/// via [CachePolicy]. The cache backend is fully decoupled — provide any
/// [EnvoyCache] implementation (memory, shared preferences, sqlite, etc.).
///
/// ```dart
/// envoy.addCourier(CacheCourier(
///   cache: MemoryCache(maxEntries: 100),
///   defaultPolicy: CachePolicy.networkFirst(ttl: Duration(minutes: 5)),
/// ));
/// ```
class CacheCourier extends Courier {
  /// Creates a [CacheCourier] with the given cache adapter and policy.
  CacheCourier({
    required this.cache,
    this.defaultPolicy = const CachePolicy.networkFirst(),
    this.cacheableMethods = const {Method.get},
  });

  /// The cache storage adapter.
  final EnvoyCache cache;

  /// Default caching policy for requests without a specific policy.
  final CachePolicy defaultPolicy;

  /// HTTP methods eligible for caching.
  final Set<Method> cacheableMethods;

  /// Extra key in [Missive.extra] to override the cache policy per-request.
  ///
  /// ```dart
  /// envoy.get('/data', extra: {
  ///   CacheCourier.policyKey: CachePolicy.cacheFirst(ttl: Duration(hours: 1)),
  /// });
  /// ```
  static const String policyKey = 'envoy.cache.policy';

  /// Extra key in [Missive.extra] to force skip cache for a single request.
  ///
  /// ```dart
  /// envoy.get('/data', extra: {CacheCourier.skipKey: true});
  /// ```
  static const String skipKey = 'envoy.cache.skip';

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    // Skip non-cacheable methods
    if (!cacheableMethods.contains(missive.method)) {
      return chain.proceed(missive);
    }

    // Skip if explicitly requested
    if (missive.extra[skipKey] == true) {
      return chain.proceed(missive);
    }

    final key = _cacheKey(missive);
    final policy = missive.extra[policyKey] as CachePolicy? ?? defaultPolicy;

    return switch (policy.strategy) {
      CacheStrategy.cacheFirst => _cacheFirst(key, missive, chain, policy),
      CacheStrategy.networkFirst => _networkFirst(key, missive, chain, policy),
      CacheStrategy.cacheOnly => _cacheOnly(key, missive),
      CacheStrategy.networkOnly => _networkOnly(key, missive, chain),
      CacheStrategy.staleWhileRevalidate => _staleWhileRevalidate(
        key,
        missive,
        chain,
        policy,
      ),
    };
  }

  Future<Dispatch> _cacheFirst(
    String key,
    Missive missive,
    CourierChain chain,
    CachePolicy policy,
  ) async {
    final cached = await cache.get(key);
    if (cached != null && !_isExpired(cached, policy)) {
      return _fromCacheEntry(cached, missive);
    }

    final dispatch = await chain.proceed(missive);
    if (dispatch.isSuccess) {
      await _store(key, dispatch, policy);
    }
    return dispatch;
  }

  Future<Dispatch> _networkFirst(
    String key,
    Missive missive,
    CourierChain chain,
    CachePolicy policy,
  ) async {
    try {
      final dispatch = await chain.proceed(missive);
      if (dispatch.isSuccess) {
        await _store(key, dispatch, policy);
      }
      return dispatch;
    } catch (_) {
      // Fall back to cache on network failure
      final cached = await cache.get(key);
      if (cached != null) {
        return _fromCacheEntry(cached, missive);
      }
      rethrow;
    }
  }

  Future<Dispatch> _cacheOnly(String key, Missive missive) async {
    final cached = await cache.get(key);
    if (cached != null) {
      return _fromCacheEntry(cached, missive);
    }
    throw StateError('No cached response for ${missive.resolvedUri}');
  }

  Future<Dispatch> _networkOnly(
    String key,
    Missive missive,
    CourierChain chain,
  ) async {
    final dispatch = await chain.proceed(missive);
    if (dispatch.isSuccess) {
      await _store(key, dispatch, const CachePolicy.networkFirst());
    }
    return dispatch;
  }

  Future<Dispatch> _staleWhileRevalidate(
    String key,
    Missive missive,
    CourierChain chain,
    CachePolicy policy,
  ) async {
    final cached = await cache.get(key);

    if (cached != null) {
      // Revalidate in background
      unawaited(_revalidate(key, missive, chain, policy));
      return _fromCacheEntry(cached, missive);
    }

    // No cache — must wait for network
    final dispatch = await chain.proceed(missive);
    if (dispatch.isSuccess) {
      await _store(key, dispatch, policy);
    }
    return dispatch;
  }

  Future<void> _revalidate(
    String key,
    Missive missive,
    CourierChain chain,
    CachePolicy policy,
  ) async {
    try {
      final dispatch = await chain.proceed(missive);
      if (dispatch.isSuccess) {
        await _store(key, dispatch, policy);
      }
    } catch (_) {
      // Silently fail — stale data is already returned
    }
  }

  /// Builds a cache key from the request method and resolved URI.
  String _cacheKey(Missive missive) {
    return '${missive.method.verb}:${missive.resolvedUri}';
  }

  bool _isExpired(CacheEntry entry, CachePolicy policy) {
    if (policy.ttl == null) return false;
    return DateTime.now().difference(entry.storedAt) > policy.ttl!;
  }

  Dispatch _fromCacheEntry(CacheEntry entry, Missive missive) {
    return Dispatch(
      statusCode: entry.statusCode,
      data: entry.data,
      rawBody: entry.rawBody,
      headers: {...entry.headers, 'x-envoy-cache': 'hit'},
      missive: missive,
    );
  }

  Future<void> _store(String key, Dispatch dispatch, CachePolicy policy) async {
    await cache.put(
      key,
      CacheEntry(
        statusCode: dispatch.statusCode,
        data: dispatch.data,
        rawBody: dispatch.rawBody,
        headers: dispatch.headers,
        storedAt: DateTime.now(),
        ttl: policy.ttl,
      ),
    );
  }
}
