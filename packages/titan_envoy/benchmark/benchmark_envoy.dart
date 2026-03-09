// ignore_for_file: avoid_print
import 'dart:async';

import 'package:titan_envoy/titan_envoy.dart';

// =============================================================================
// Titan Envoy Benchmarks
// =============================================================================
//
// Run with: dart run benchmark/benchmark_envoy.dart
//
// Covers:
//  1. Missive — Request construction throughput
//  2. Dispatch — Response wrapper construction
//  3. CourierChain — Interceptor pipeline throughput
//  4. MemoryCache — Put/get/eviction performance
//  5. Gate — Throttle token acquire overhead
//  6. Parcel — Multipart form data construction
//  7. Recall — Cancel token check throughput
//  8. CachePolicy — Strategy evaluation
// =============================================================================

void main() async {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TITAN ENVOY BENCHMARKS');
  print('═══════════════════════════════════════════════════════');
  print('');

  _benchMissive();
  _benchDispatch();
  await _benchCourierChain();
  _benchMemoryCache();
  _benchParcel();
  _benchRecall();
  _benchCachePolicy();

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  ALL ENVOY BENCHMARKS COMPLETE');
  print('═══════════════════════════════════════════════════════');
}

// ---------------------------------------------------------------------------
// 1. Missive — Request construction
// ---------------------------------------------------------------------------

void _benchMissive() {
  print('┌─ 1. Missive (Request Construction) ──────────────────');

  // a) Basic GET construction
  {
    for (final count in [1000, 10000, 100000]) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Missive(
          method: Method.get,
          uri: Uri.parse('https://api.example.com/users/$i'),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print(
        '│  GET construction (${_pad(count)}): ${_ms(sw)}'
        '  ($perOp µs/op)',
      );
    }
  }

  // b) Full POST with headers + query params
  {
    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com/users'),
        headers: {
          'Authorization': 'Bearer token-$i',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Request-Id': 'req-$i',
        },
        queryParameters: {'page': '$i', 'limit': '20'},
        data: {'name': 'User $i', 'email': 'user$i@test.com'},
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  POST + headers + params ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 2. Dispatch — Response construction
// ---------------------------------------------------------------------------

void _benchDispatch() {
  print('┌─ 2. Dispatch (Response Construction) ────────────────');

  final missive = Missive(
    method: Method.get,
    uri: Uri.parse('https://api.example.com/users'),
  );

  // a) Basic response construction
  {
    for (final count in [1000, 10000, 100000]) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        Dispatch(
          statusCode: 200,
          headers: {
            'content-type': 'application/json',
            'x-request-id': 'req-$i',
          },
          missive: missive,
          data: {'id': i, 'name': 'User $i'},
          rawBody: '{"id": $i, "name": "User $i"}',
          duration: const Duration(milliseconds: 150),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print(
        '│  Dispatch construction (${_pad(count)}): ${_ms(sw)}'
        '  ($perOp µs/op)',
      );
    }
  }

  // b) Status check throughput
  {
    const iterations = 100000;
    final dispatches = <Dispatch>[
      Dispatch(statusCode: 200, headers: const {}, missive: missive),
      Dispatch(statusCode: 301, headers: const {}, missive: missive),
      Dispatch(statusCode: 404, headers: const {}, missive: missive),
      Dispatch(statusCode: 500, headers: const {}, missive: missive),
    ];
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final d = dispatches[i % 4];
      d.isSuccess;
      d.isRedirect;
      d.isClientError;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Status checks ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 3. CourierChain — Interceptor pipeline
// ---------------------------------------------------------------------------

Future<void> _benchCourierChain() async {
  print('┌─ 3. CourierChain (Interceptor Pipeline) ─────────────');

  final missive = Missive(
    method: Method.get,
    uri: Uri.parse('https://api.example.com/data'),
  );

  final mockResponse = Dispatch(
    statusCode: 200,
    headers: const {'content-type': 'application/json'},
    missive: missive,
    data: {'result': 'ok'},
  );

  // No-op passthrough courier for measuring chain overhead
  final passthrough = _PassthroughCourier();

  for (final chainLength in [0, 1, 3, 5, 7]) {
    final couriers = List.generate(chainLength, (_) => passthrough);
    const iterations = 10000;

    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final chain = CourierChain(
        couriers: couriers,
        execute: (_) async => mockResponse,
      );
      await chain.proceed(missive);
    }
    sw.stop();

    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Chain($chainLength couriers) × $iterations: ${_ms(sw)}'
      '  ($perOp µs/req)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 4. MemoryCache — Put / Get / Eviction
// ---------------------------------------------------------------------------

void _benchMemoryCache() {
  print('┌─ 4. MemoryCache (Put / Get / Eviction) ─────────────');

  // a) Put throughput
  {
    for (final count in [100, 1000, 10000]) {
      final cache = MemoryCache(maxEntries: count + 100);
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        cache.put(
          'key-$i',
          CacheEntry(
            statusCode: 200,
            headers: const {},
            storedAt: DateTime.now(),
            data: 'value-$i',
          ),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print('│  Put (${_pad(count)}): ${_ms(sw)}  ($perOp µs/op)');
    }
  }

  // b) Get throughput (cache hits)
  {
    const size = 10000;
    final cache = MemoryCache(maxEntries: size + 100);
    for (var i = 0; i < size; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }

    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      cache.get('key-${i % size}');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Get hits ($lookups from $size): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // c) Get throughput (cache misses)
  {
    final cache = MemoryCache(maxEntries: 100);
    for (var i = 0; i < 100; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }

    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      cache.get('miss-$i');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print('│  Get misses ($lookups): ${_ms(sw)}  ($perOp µs/op)');
  }

  // d) LRU eviction (put beyond maxEntries)
  {
    const maxEntries = 1000;
    final cache = MemoryCache(maxEntries: maxEntries);

    // Fill cache
    for (var i = 0; i < maxEntries; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }

    // Overflow by 1000, causing 1000 evictions
    const overflow = 1000;
    final sw = Stopwatch()..start();
    for (var i = maxEntries; i < maxEntries + overflow; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: DateTime.now(),
          data: 'value-$i',
        ),
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / overflow).toStringAsFixed(2);
    print(
      '│  LRU eviction ($overflow overflows): ${_ms(sw)}'
      '  ($perOp µs/evict)',
    );
  }

  // e) TTL eviction
  {
    const count = 1000;
    final cache = MemoryCache(maxEntries: count + 100);
    final expired = DateTime.now().subtract(const Duration(hours: 1));
    for (var i = 0; i < count; i++) {
      cache.put(
        'key-$i',
        CacheEntry(
          statusCode: 200,
          headers: const {},
          storedAt: expired,
          data: 'value-$i',
          ttl: const Duration(seconds: 1), // Already expired
        ),
      );
    }

    final sw = Stopwatch()..start();
    final evicted = cache.evictExpired();
    sw.stop();
    print('│  TTL eviction ($evicted expired): ${_ms(sw)}');
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 5. Parcel — Multipart form data
// ---------------------------------------------------------------------------

void _benchParcel() {
  print('┌─ 5. Parcel (Multipart Form Data) ────────────────────');

  // a) Field-only construction
  {
    for (final fields in [10, 50, 100]) {
      const iterations = 1000;
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        final parcel = Parcel();
        for (var f = 0; f < fields; f++) {
          parcel.addField('field_$f', 'value_$f');
        }
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
      print(
        '│  $fields fields × $iterations: ${_ms(sw)}'
        '  ($perOp µs/parcel)',
      );
    }
  }

  // b) fromMap construction
  {
    final fieldMap = {for (var i = 0; i < 50; i++) 'field_$i': 'value_$i'};
    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      Parcel.fromMap(fieldMap);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  fromMap(50 fields) × $iterations: ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // c) toUrlEncoded
  {
    final parcel = Parcel();
    for (var i = 0; i < 50; i++) {
      parcel.addField('field_$i', 'value with spaces $i');
    }
    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      parcel.toUrlEncoded();
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  toUrlEncoded(50 fields) × $iterations: ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 6. Recall — Cancel token
// ---------------------------------------------------------------------------

void _benchRecall() {
  print('┌─ 6. Recall (Cancel Token) ───────────────────────────');

  // a) isCancelled check throughput (not cancelled)
  {
    final recall = Recall();
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      recall.isCancelled;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  isCancelled check ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // b) Creation + cancellation throughput
  {
    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final recall = Recall();
      recall.cancel('reason $i');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Create + cancel ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 7. CachePolicy — Strategy evaluation
// ---------------------------------------------------------------------------

void _benchCachePolicy() {
  print('┌─ 7. CachePolicy (Strategy Evaluation) ──────────────');

  // a) Policy construction
  {
    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      switch (i % 4) {
        case 0:
          const CachePolicy.networkFirst();
        case 1:
          const CachePolicy.cacheFirst();
        case 2:
          const CachePolicy.networkOnly();
        case 3:
          CachePolicy.cacheFirst(ttl: Duration(minutes: i % 60));
      }
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Policy construction ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  // b) Strategy name access (enum)
  {
    const iterations = 1000000;
    const policies = [
      CachePolicy.networkFirst(),
      CachePolicy.cacheFirst(),
      CachePolicy.networkOnly(),
    ];
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      policies[i % 3].strategy.name;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  Strategy name ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _PassthroughCourier extends Courier {
  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) {
    return chain.proceed(missive);
  }
}

/// Format stopwatch to ms string.
String _ms(Stopwatch sw) {
  if (sw.elapsedMilliseconds > 0) {
    return '${sw.elapsedMilliseconds} ms';
  }
  return '${sw.elapsedMicroseconds} µs';
}

/// Right-pad a number for alignment.
String _pad(int n) => n.toString().padLeft(6);
