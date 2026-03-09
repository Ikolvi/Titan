import 'envoy_cache.dart';

/// A simple in-memory [EnvoyCache] implementation.
///
/// Supports automatic eviction by max entry count (LRU-style, oldest first)
/// and expiry-based cleanup. Suitable for development and lightweight apps.
/// For production, implement [EnvoyCache] with a persistent backend.
///
/// ```dart
/// final cache = MemoryCache(maxEntries: 100);
/// envoy.addCourier(CacheCourier(cache: cache));
///
/// // Check stats
/// print(cache.size);  // number of cached entries
/// cache.clear();      // flush everything
/// ```
class MemoryCache implements EnvoyCache {
  /// Creates a [MemoryCache] with an optional entry limit.
  ///
  /// When [maxEntries] is reached, the oldest entry is evicted.
  MemoryCache({this.maxEntries = 200});

  /// Maximum number of entries before eviction.
  final int maxEntries;

  final Map<String, CacheEntry> _store = {};

  @override
  CacheEntry? get(String key) {
    final entry = _store[key];
    if (entry == null) return null;

    // Auto-evict expired entries on read
    if (entry.isExpired) {
      _store.remove(key);
      return null;
    }

    return entry;
  }

  @override
  void put(String key, CacheEntry entry) {
    // Evict oldest if at capacity
    while (_store.length >= maxEntries && !_store.containsKey(key)) {
      _store.remove(_store.keys.first);
    }
    _store[key] = entry;
  }

  @override
  void remove(String key) {
    _store.remove(key);
  }

  @override
  void clear() {
    _store.clear();
  }

  @override
  int get size => _store.length;

  /// Returns all cache keys.
  Iterable<String> get keys => _store.keys;

  /// Removes all expired entries from the cache.
  int evictExpired() {
    final expiredKeys = _store.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();
    for (final key in expiredKeys) {
      _store.remove(key);
    }
    return expiredKeys.length;
  }
}
