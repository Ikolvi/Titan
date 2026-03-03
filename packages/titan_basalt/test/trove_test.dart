import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Trove', () {
    late Trove<String, int> cache;

    setUp(() {
      cache = Trove<String, int>(name: 'test');
    });

    tearDown(() {
      cache.dispose();
    });

    // -----------------------------------------------------------------------
    // Basic operations
    // -----------------------------------------------------------------------

    group('basic operations', () {
      test('put and get stores and retrieves values', () {
        cache.put('a', 1);
        cache.put('b', 2);
        expect(cache.get('a'), 1);
        expect(cache.get('b'), 2);
      });

      test('get returns null for missing keys', () {
        expect(cache.get('missing'), isNull);
      });

      test('put overwrites existing keys', () {
        cache.put('a', 1);
        cache.put('a', 99);
        expect(cache.get('a'), 99);
      });

      test('evict removes a specific entry', () {
        cache.put('a', 1);
        cache.put('b', 2);
        final removed = cache.evict('a');
        expect(removed, 1);
        expect(cache.get('a'), isNull);
        expect(cache.get('b'), 2);
      });

      test('evict returns null for missing keys', () {
        expect(cache.evict('missing'), isNull);
      });

      test('clear removes all entries', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        cache.clear();
        expect(cache.size.value, 0);
        expect(cache.get('a'), isNull);
        expect(cache.get('b'), isNull);
      });

      test('reset clears entries and stats', () {
        cache.put('a', 1);
        cache.get('a'); // hit
        cache.get('missing'); // miss
        cache.reset();
        expect(cache.size.value, 0);
        expect(cache.hits.value, 0);
        expect(cache.misses.value, 0);
        expect(cache.evictions.value, 0);
      });

      test('containsKey returns true for present keys', () {
        cache.put('a', 1);
        expect(cache.containsKey('a'), isTrue);
        expect(cache.containsKey('b'), isFalse);
      });

      test('keys returns all non-expired keys', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        expect(cache.keys, containsAll(['a', 'b', 'c']));
      });

      test('isEmpty and isNotEmpty work correctly', () {
        expect(cache.isEmpty, isTrue);
        expect(cache.isNotEmpty, isFalse);
        cache.put('a', 1);
        expect(cache.isEmpty, isFalse);
        expect(cache.isNotEmpty, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Reactive state
    // -----------------------------------------------------------------------

    group('reactive state', () {
      test('size tracks entry count', () {
        expect(cache.size.value, 0);
        cache.put('a', 1);
        expect(cache.size.value, 1);
        cache.put('b', 2);
        expect(cache.size.value, 2);
        cache.evict('a');
        expect(cache.size.value, 1);
      });

      test('hits tracks cache hits', () {
        cache.put('a', 1);
        expect(cache.hits.value, 0);
        cache.get('a');
        expect(cache.hits.value, 1);
        cache.get('a');
        expect(cache.hits.value, 2);
      });

      test('misses tracks cache misses', () {
        expect(cache.misses.value, 0);
        cache.get('missing');
        expect(cache.misses.value, 1);
        cache.get('also-missing');
        expect(cache.misses.value, 2);
      });

      test('evictions tracks eviction count', () {
        cache.put('a', 1);
        expect(cache.evictions.value, 0);
        cache.evict('a');
        expect(cache.evictions.value, 1);
      });

      test('hitRate calculates correctly', () {
        expect(cache.hitRate, 0.0);
        cache.put('a', 1);
        cache.get('a'); // hit
        cache.get('b'); // miss
        expect(cache.hitRate, 50.0);
        cache.get('a'); // hit
        // 2 hits, 1 miss = 66.67%
        expect(cache.hitRate, closeTo(66.67, 0.1));
      });

      test('missRate calculates correctly', () {
        cache.put('a', 1);
        cache.get('a'); // hit
        cache.get('b'); // miss
        expect(cache.missRate, 50.0);
      });
    });

    // -----------------------------------------------------------------------
    // TTL expiry
    // -----------------------------------------------------------------------

    group('TTL expiry', () {
      test('entries expire after TTL', () async {
        final ttlCache = Trove<String, int>(
          defaultTtl: const Duration(milliseconds: 50),
          cleanupInterval: const Duration(milliseconds: 20),
          name: 'ttl-test',
        );
        ttlCache.put('a', 1);
        expect(ttlCache.get('a'), 1);

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(ttlCache.get('a'), isNull);
        ttlCache.dispose();
      });

      test('per-entry TTL overrides default', () async {
        final ttlCache = Trove<String, int>(
          defaultTtl: const Duration(seconds: 60),
          name: 'per-entry-ttl',
        );
        ttlCache.put('long', 1);
        ttlCache.put('short', 2, ttl: const Duration(milliseconds: 50));

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(ttlCache.get('long'), 1);
        expect(ttlCache.get('short'), isNull);
        ttlCache.dispose();
      });

      test('isExpired returns true for expired entries', () async {
        final ttlCache = Trove<String, int>(
          defaultTtl: const Duration(milliseconds: 50),
          name: 'expired-test',
        );
        ttlCache.put('a', 1);
        expect(ttlCache.isExpired('a'), isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(ttlCache.isExpired('a'), isTrue);
        ttlCache.dispose();
      });

      test('remainingTtl returns correct duration', () {
        final ttlCache = Trove<String, int>(
          defaultTtl: const Duration(seconds: 60),
          name: 'remaining-ttl',
        );
        ttlCache.put('a', 1);
        final remaining = ttlCache.remainingTtl('a');
        expect(remaining, isNotNull);
        expect(remaining!.inSeconds, greaterThan(50));
        expect(remaining.inSeconds, lessThanOrEqualTo(60));

        expect(ttlCache.remainingTtl('missing'), isNull);
        ttlCache.dispose();
      });

      test('entries without TTL never expire', () {
        // No defaultTtl set
        cache.put('forever', 42);
        expect(cache.remainingTtl('forever'), isNull);
        expect(cache.isExpired('forever'), isFalse);
        expect(cache.get('forever'), 42);
      });

      test('containsKey returns false for expired entries', () async {
        final ttlCache = Trove<String, int>(
          defaultTtl: const Duration(milliseconds: 50),
          name: 'contains-expired',
        );
        ttlCache.put('a', 1);
        expect(ttlCache.containsKey('a'), isTrue);

        await Future<void>.delayed(const Duration(milliseconds: 80));

        expect(ttlCache.containsKey('a'), isFalse);
        ttlCache.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // LRU eviction
    // -----------------------------------------------------------------------

    group('LRU eviction', () {
      test('evicts LRU entry when at max capacity', () {
        final lruCache = Trove<String, int>(maxEntries: 3, name: 'lru');
        lruCache.put('a', 1);
        lruCache.put('b', 2);
        lruCache.put('c', 3);

        // Adding a 4th entry should evict 'a' (oldest)
        lruCache.put('d', 4);
        expect(lruCache.get('a'), isNull); // evicted
        expect(lruCache.get('b'), 2);
        expect(lruCache.get('c'), 3);
        expect(lruCache.get('d'), 4);
        expect(lruCache.size.value, 3);
        lruCache.dispose();
      });

      test('accessing an entry updates LRU order', () {
        final lruCache = Trove<String, int>(maxEntries: 3, name: 'lru-access');
        lruCache.put('a', 1);
        lruCache.put('b', 2);
        lruCache.put('c', 3);

        // Access 'a' to make it most recently used
        lruCache.get('a');

        // Adding 'd' should now evict 'b' (least recently used)
        lruCache.put('d', 4);
        expect(lruCache.get('a'), 1); // kept (was accessed)
        expect(lruCache.get('b'), isNull); // evicted
        lruCache.dispose();
      });

      test('overwriting an entry does not cause double eviction', () {
        final lruCache = Trove<String, int>(
          maxEntries: 3,
          name: 'lru-overwrite',
        );
        lruCache.put('a', 1);
        lruCache.put('b', 2);
        lruCache.put('c', 3);

        // Overwrite 'b' — should not evict anything
        lruCache.put('b', 99);
        expect(lruCache.size.value, 3);
        expect(lruCache.get('a'), 1);
        expect(lruCache.get('b'), 99);
        expect(lruCache.get('c'), 3);
        lruCache.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Batch operations
    // -----------------------------------------------------------------------

    group('batch operations', () {
      test('putAll stores multiple entries', () {
        cache.putAll({'a': 1, 'b': 2, 'c': 3});
        expect(cache.get('a'), 1);
        expect(cache.get('b'), 2);
        expect(cache.get('c'), 3);
        expect(cache.size.value, 3);
      });

      test('getAll retrieves multiple entries', () {
        cache.putAll({'a': 1, 'b': 2, 'c': 3});
        final results = cache.getAll(['a', 'c', 'missing']);
        expect(results, {'a': 1, 'c': 3});
      });
    });

    // -----------------------------------------------------------------------
    // putIfAbsent / getOrPut
    // -----------------------------------------------------------------------

    group('putIfAbsent and getOrPut', () {
      test('putIfAbsent returns existing value', () {
        cache.put('a', 1);
        final result = cache.putIfAbsent('a', () => 99);
        expect(result, 1); // existing value
        expect(cache.get('a'), 1);
      });

      test('putIfAbsent computes on miss', () {
        final result = cache.putIfAbsent('a', () => 42);
        expect(result, 42);
        expect(cache.get('a'), 42);
      });

      test('getOrPut returns existing value', () async {
        cache.put('a', 1);
        final result = await cache.getOrPut('a', () async => 99);
        expect(result, 1);
      });

      test('getOrPut computes async on miss', () async {
        final result = await cache.getOrPut('a', () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 42;
        });
        expect(result, 42);
        expect(cache.get('a'), 42);
      });
    });

    // -----------------------------------------------------------------------
    // Eviction callback
    // -----------------------------------------------------------------------

    group('eviction callbacks', () {
      test('onEvict called with reason on manual evict', () {
        TroveEvictionReason? lastReason;
        String? lastKey;
        int? lastValue;

        final callbackCache = Trove<String, int>(
          onEvict: (key, value, reason) {
            lastKey = key;
            lastValue = value;
            lastReason = reason;
          },
          name: 'callback',
        );

        callbackCache.put('a', 1);
        callbackCache.evict('a');

        expect(lastKey, 'a');
        expect(lastValue, 1);
        expect(lastReason, TroveEvictionReason.manual);
        callbackCache.dispose();
      });

      test('onEvict called with reason on TTL expiry', () async {
        TroveEvictionReason? lastReason;

        final callbackCache = Trove<String, int>(
          defaultTtl: const Duration(milliseconds: 50),
          onEvict: (key, value, reason) {
            lastReason = reason;
          },
          name: 'callback-ttl',
        );

        callbackCache.put('a', 1);

        await Future<void>.delayed(const Duration(milliseconds: 80));

        // Access triggers lazy eviction
        callbackCache.get('a');
        expect(lastReason, TroveEvictionReason.expired);
        callbackCache.dispose();
      });

      test('onEvict called with reason on LRU capacity eviction', () {
        TroveEvictionReason? lastReason;
        String? lastKey;

        final callbackCache = Trove<String, int>(
          maxEntries: 2,
          onEvict: (key, value, reason) {
            lastKey = key;
            lastReason = reason;
          },
          name: 'callback-lru',
        );

        callbackCache.put('a', 1);
        callbackCache.put('b', 2);
        callbackCache.put('c', 3); // triggers eviction of 'a'

        expect(lastKey, 'a');
        expect(lastReason, TroveEvictionReason.capacity);
        callbackCache.dispose();
      });

      test('onEvict called for each entry on clear', () {
        final evictedKeys = <String>[];

        final callbackCache = Trove<String, int>(
          onEvict: (key, value, reason) {
            evictedKeys.add(key);
          },
          name: 'callback-clear',
        );

        callbackCache.put('a', 1);
        callbackCache.put('b', 2);
        callbackCache.clear();

        expect(evictedKeys, containsAll(['a', 'b']));
        callbackCache.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    group('Pillar integration', () {
      test('trove() factory creates managed cache', () {
        final pillar = _TestPillar();
        pillar.initialize();

        pillar.items.put('x', 100);
        expect(pillar.items.get('x'), 100);
        expect(pillar.items.size.value, 1);

        pillar.dispose();
      });

      test('trove is disposed with Pillar', () {
        final pillar = _TestPillar();
        pillar.initialize();

        pillar.items.put('x', 100);
        pillar.dispose();

        // After disposal, the managed nodes are disposed
        expect(pillar.isDisposed, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------

    test('toString includes stats', () {
      cache.put('a', 1);
      cache.get('a');
      cache.get('missing');
      final str = cache.toString();
      expect(str, contains('Trove<String, int>'));
      expect(str, contains('size: 1'));
      expect(str, contains('hits: 1'));
      expect(str, contains('misses: 1'));
      expect(str, contains('hitRate: 50.0%'));
    });
  });
}

// ---------------------------------------------------------------------------
// Test Pillar
// ---------------------------------------------------------------------------

class _TestPillar extends Pillar {
  late final items = trove<String, int>(
    defaultTtl: const Duration(minutes: 5),
    maxEntries: 100,
    name: 'test-items',
  );
}
