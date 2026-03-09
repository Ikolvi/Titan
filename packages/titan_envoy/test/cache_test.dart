import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

void main() {
  group('MemoryCache', () {
    test('starts empty', () {
      final cache = MemoryCache();
      expect(cache.size, 0);
      expect(cache.keys, isEmpty);
    });

    test('put and get entry', () {
      final cache = MemoryCache();
      final entry = CacheEntry(
        statusCode: 200,
        data: {'name': 'Kael'},
        rawBody: '{"name":"Kael"}',
        headers: const {'content-type': 'application/json'},
        storedAt: DateTime.now(),
      );
      cache.put('test-key', entry);
      expect(cache.size, 1);

      final retrieved = cache.get('test-key');
      expect(retrieved, isNotNull);
      expect(retrieved!.statusCode, 200);
      expect(retrieved.data, {'name': 'Kael'});
    });

    test('get returns null for missing key', () {
      final cache = MemoryCache();
      expect(cache.get('missing'), isNull);
    });

    test('remove deletes entry', () {
      final cache = MemoryCache();
      final entry = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now(),
      );
      cache.put('key', entry);
      expect(cache.size, 1);

      cache.remove('key');
      expect(cache.size, 0);
      expect(cache.get('key'), isNull);
    });

    test('clear removes all entries', () {
      final cache = MemoryCache();
      final entry = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now(),
      );
      cache.put('a', entry);
      cache.put('b', entry);
      cache.put('c', entry);
      expect(cache.size, 3);

      cache.clear();
      expect(cache.size, 0);
    });

    test('evicts oldest when at capacity', () {
      final cache = MemoryCache(maxEntries: 3);
      for (var i = 0; i < 5; i++) {
        cache.put(
          'key-$i',
          CacheEntry(
            statusCode: 200,
            headers: const {},
            storedAt: DateTime.now(),
            data: i,
          ),
        );
      }
      expect(cache.size, 3);
      expect(cache.get('key-0'), isNull); // evicted
      expect(cache.get('key-1'), isNull); // evicted
      expect(cache.get('key-2'), isNotNull); // kept
      expect(cache.get('key-3'), isNotNull);
      expect(cache.get('key-4'), isNotNull);
    });

    test('auto-evicts expired entries on read', () {
      final cache = MemoryCache();
      final expiredEntry = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now().subtract(Duration(hours: 2)),
        ttl: Duration(hours: 1),
      );
      cache.put('expired', expiredEntry);
      expect(cache.size, 1);

      final result = cache.get('expired');
      expect(result, isNull);
      expect(cache.size, 0);
    });

    test('returns non-expired entries', () {
      final cache = MemoryCache();
      final freshEntry = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now(),
        ttl: Duration(hours: 1),
      );
      cache.put('fresh', freshEntry);

      final result = cache.get('fresh');
      expect(result, isNotNull);
    });

    test('evictExpired removes all expired entries', () {
      final cache = MemoryCache();
      final now = DateTime.now();

      cache.put(
        'expired-1',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: now.subtract(Duration(hours: 2)),
          ttl: Duration(hours: 1),
        ),
      );
      cache.put(
        'expired-2',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: now.subtract(Duration(hours: 3)),
          ttl: Duration(hours: 1),
        ),
      );
      cache.put(
        'fresh',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: now,
          ttl: Duration(hours: 1),
        ),
      );

      expect(cache.size, 3);
      final evicted = cache.evictExpired();
      expect(evicted, 2);
      expect(cache.size, 1);
      expect(cache.get('fresh'), isNotNull);
    });

    test('overwriting key does not increase size', () {
      final cache = MemoryCache();
      final entry1 = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now(),
        data: 'v1',
      );
      final entry2 = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now(),
        data: 'v2',
      );
      cache.put('key', entry1);
      cache.put('key', entry2);
      expect(cache.size, 1);
      expect(cache.get('key')!.data, 'v2');
    });
  });

  group('CacheEntry', () {
    test('isExpired returns false without ttl', () {
      final entry = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now().subtract(Duration(days: 365)),
      );
      expect(entry.isExpired, isFalse);
    });

    test('isExpired returns true when past ttl', () {
      final entry = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now().subtract(Duration(hours: 2)),
        ttl: Duration(hours: 1),
      );
      expect(entry.isExpired, isTrue);
    });

    test('isExpired returns false when within ttl', () {
      final entry = CacheEntry(
        statusCode: 200,
        headers: const {},
        storedAt: DateTime.now(),
        ttl: Duration(hours: 1),
      );
      expect(entry.isExpired, isFalse);
    });

    test('toJson serializes all fields', () {
      final entry = CacheEntry(
        statusCode: 200,
        rawBody: '{"data":true}',
        headers: const {'content-type': 'application/json'},
        storedAt: DateTime(2024, 1, 1),
        ttl: Duration(minutes: 30),
      );
      final json = entry.toJson();
      expect(json['statusCode'], 200);
      expect(json['rawBody'], '{"data":true}');
      expect(json['headers'], {'content-type': 'application/json'});
      expect(json['storedAt'], contains('2024'));
      expect(json['ttlMs'], 30 * 60 * 1000);
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'statusCode': 201,
        'rawBody': '{"id":1}',
        'headers': {'content-type': 'application/json'},
        'storedAt': '2024-06-15T12:00:00.000',
        'ttlMs': 60000,
      };
      final entry = CacheEntry.fromJson(json);
      expect(entry.statusCode, 201);
      expect(entry.rawBody, '{"id":1}');
      expect(entry.headers['content-type'], 'application/json');
      expect(entry.storedAt.year, 2024);
      expect(entry.ttl, Duration(minutes: 1));
    });

    test('fromJson handles null ttl', () {
      final json = {
        'statusCode': 200,
        'rawBody': null,
        'headers': <String, String>{},
        'storedAt': '2024-01-01T00:00:00.000',
        'ttlMs': null,
      };
      final entry = CacheEntry.fromJson(json);
      expect(entry.ttl, isNull);
    });
  });

  group('CachePolicy', () {
    test('cacheFirst factory', () {
      const policy = CachePolicy.cacheFirst(ttl: Duration(minutes: 5));
      expect(policy.strategy, CacheStrategy.cacheFirst);
      expect(policy.ttl, Duration(minutes: 5));
    });

    test('networkFirst factory', () {
      const policy = CachePolicy.networkFirst(ttl: Duration(hours: 1));
      expect(policy.strategy, CacheStrategy.networkFirst);
      expect(policy.ttl, Duration(hours: 1));
    });

    test('cacheOnly factory', () {
      const policy = CachePolicy.cacheOnly();
      expect(policy.strategy, CacheStrategy.cacheOnly);
      expect(policy.ttl, isNull);
    });

    test('networkOnly factory', () {
      const policy = CachePolicy.networkOnly();
      expect(policy.strategy, CacheStrategy.networkOnly);
      expect(policy.ttl, isNull);
    });

    test('staleWhileRevalidate factory', () {
      const policy = CachePolicy.staleWhileRevalidate(
        ttl: Duration(minutes: 10),
      );
      expect(policy.strategy, CacheStrategy.staleWhileRevalidate);
      expect(policy.ttl, Duration(minutes: 10));
    });

    test('toString includes strategy and ttl', () {
      const policy = CachePolicy.cacheFirst(ttl: Duration(minutes: 5));
      expect(policy.toString(), contains('cacheFirst'));
      expect(policy.toString(), contains('0:05'));
    });
  });

  group('CacheCourier', () {
    late MemoryCache cache;
    late CacheCourier courier;

    final baseMissive = Missive(
      method: Method.get,
      uri: Uri.parse('https://api.example.com/data'),
    );

    Dispatch fakeDispatch(Missive m, {Object? data}) => Dispatch(
      statusCode: 200,
      data: data ?? {'fresh': true},
      rawBody: '{"fresh":true}',
      headers: const {'content-type': 'application/json'},
      missive: m,
    );

    setUp(() {
      cache = MemoryCache();
      courier = CacheCourier(
        cache: cache,
        defaultPolicy: const CachePolicy.cacheFirst(ttl: Duration(hours: 1)),
      );
    });

    test('cacheFirst returns cached data on hit', () async {
      // Pre-populate cache
      cache.put(
        'GET:https://api.example.com/data',
        CacheEntry(
          statusCode: 200,
          data: {'cached': true},
          rawBody: '{"cached":true}',
          headers: const {},
          storedAt: DateTime.now(),
        ),
      );

      var networkCalled = false;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          networkCalled = true;
          return fakeDispatch(m);
        },
      );

      final dispatch = await chain.proceed(baseMissive);
      expect(networkCalled, isFalse);
      expect(dispatch.data, {'cached': true});
      expect(dispatch.headers['x-envoy-cache'], 'hit');
    });

    test('cacheFirst fetches on miss', () async {
      var networkCalled = false;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          networkCalled = true;
          return fakeDispatch(m);
        },
      );

      final dispatch = await chain.proceed(baseMissive);
      expect(networkCalled, isTrue);
      expect(dispatch.data, {'fresh': true});
      expect(cache.size, 1);
    });

    test('skips non-GET methods', () async {
      var networkCalled = false;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          networkCalled = true;
          return fakeDispatch(m);
        },
      );

      final postMissive = Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com/data'),
        data: {'name': 'test'},
      );
      await chain.proceed(postMissive);
      expect(networkCalled, isTrue);
      expect(cache.size, 0);
    });

    test('skips when skip key is set', () async {
      cache.put(
        'GET:https://api.example.com/data',
        CacheEntry(
          statusCode: 200,
          data: {'cached': true},
          headers: const {},
          storedAt: DateTime.now(),
        ),
      );

      var networkCalled = false;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          networkCalled = true;
          return fakeDispatch(m);
        },
      );

      final skipMissive = baseMissive.copyWith(
        extra: {CacheCourier.skipKey: true},
      );
      await chain.proceed(skipMissive);
      expect(networkCalled, isTrue);
    });

    test('networkFirst fetches from network', () async {
      final nfCourier = CacheCourier(
        cache: cache,
        defaultPolicy: const CachePolicy.networkFirst(ttl: Duration(hours: 1)),
      );

      var networkCalled = false;
      final chain = CourierChain(
        couriers: [nfCourier],
        execute: (m) async {
          networkCalled = true;
          return fakeDispatch(m);
        },
      );

      final dispatch = await chain.proceed(baseMissive);
      expect(networkCalled, isTrue);
      expect(dispatch.data, {'fresh': true});
      expect(cache.size, 1);
    });

    test('networkFirst falls back to cache on error', () async {
      cache.put(
        'GET:https://api.example.com/data',
        CacheEntry(
          statusCode: 200,
          data: {'stale': true},
          headers: const {},
          storedAt: DateTime.now(),
        ),
      );

      final nfCourier = CacheCourier(
        cache: cache,
        defaultPolicy: const CachePolicy.networkFirst(),
      );

      final chain = CourierChain(
        couriers: [nfCourier],
        execute: (m) async {
          throw EnvoyError.connectionError(missive: m);
        },
      );

      final dispatch = await chain.proceed(baseMissive);
      expect(dispatch.data, {'stale': true});
    });

    test('cacheOnly returns cached or throws', () async {
      final coCourier = CacheCourier(
        cache: cache,
        defaultPolicy: const CachePolicy.cacheOnly(),
      );

      final chain = CourierChain(
        couriers: [coCourier],
        execute: (m) async => fakeDispatch(m),
      );

      // Should throw — no cache
      await expectLater(
        () => chain.proceed(baseMissive),
        throwsA(isA<StateError>()),
      );

      // Populate and retry
      cache.put(
        'GET:https://api.example.com/data',
        CacheEntry(
          statusCode: 200,
          data: {'offline': true},
          headers: const {},
          storedAt: DateTime.now(),
        ),
      );

      final dispatch = await CourierChain(
        couriers: [coCourier],
        execute: (m) async => fakeDispatch(m),
      ).proceed(baseMissive);
      expect(dispatch.data, {'offline': true});
    });

    test('per-request policy override via extra', () async {
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async => fakeDispatch(m),
      );

      // Override to networkOnly
      final missiveWithPolicy = baseMissive.copyWith(
        extra: {CacheCourier.policyKey: const CachePolicy.networkOnly()},
      );
      final dispatch = await chain.proceed(missiveWithPolicy);
      expect(dispatch.data, {'fresh': true});
    });

    test('expired cache entry triggers fresh fetch in cacheFirst', () async {
      cache.put(
        'GET:https://api.example.com/data',
        CacheEntry(
          statusCode: 200,
          data: {'expired': true},
          headers: const {},
          storedAt: DateTime.now().subtract(Duration(hours: 2)),
          ttl: Duration(hours: 1),
        ),
      );

      var networkCalled = false;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          networkCalled = true;
          return fakeDispatch(m);
        },
      );

      await chain.proceed(baseMissive);
      expect(networkCalled, isTrue);
    });
  });
}
