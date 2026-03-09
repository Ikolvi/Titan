import 'dart:async';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

/// A test courier that records calls and can transform requests/responses.
class _RecordingCourier extends Courier {
  final List<Missive> interceptedMissives = [];
  final List<Dispatch> interceptedDispatches = [];
  Missive Function(Missive)? transformMissive;
  Dispatch Function(Dispatch)? transformDispatch;
  bool shouldShortCircuit = false;
  Dispatch? shortCircuitResponse;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    interceptedMissives.add(missive);

    final actualMissive = transformMissive != null
        ? transformMissive!(missive)
        : missive;

    if (shouldShortCircuit && shortCircuitResponse != null) {
      return shortCircuitResponse!;
    }

    final dispatch = await chain.proceed(actualMissive);
    interceptedDispatches.add(dispatch);

    return transformDispatch != null ? transformDispatch!(dispatch) : dispatch;
  }
}

/// A fake executor that returns pre-configured dispatches.
Future<Dispatch> _fakeExecutor(Missive missive) async {
  return Dispatch(
    statusCode: 200,
    data: {'result': 'ok'},
    rawBody: '{"result":"ok"}',
    headers: const {'content-type': 'application/json'},
    missive: missive,
    duration: Duration(milliseconds: 50),
  );
}

void main() {
  group('CourierChain', () {
    test('executes without couriers', () async {
      final chain = CourierChain(couriers: [], execute: _fakeExecutor);
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      final dispatch = await chain.proceed(missive);
      expect(dispatch.statusCode, 200);
    });

    test('passes through single courier', () async {
      final courier = _RecordingCourier();
      final chain = CourierChain(couriers: [courier], execute: _fakeExecutor);
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await chain.proceed(missive);
      expect(courier.interceptedMissives, hasLength(1));
      expect(courier.interceptedDispatches, hasLength(1));
    });

    test('couriers execute in order', () async {
      final order = <int>[];
      final courier1 = _RecordingCourier()
        ..transformMissive = (m) {
          order.add(1);
          return m;
        };
      final courier2 = _RecordingCourier()
        ..transformMissive = (m) {
          order.add(2);
          return m;
        };
      final chain = CourierChain(
        couriers: [courier1, courier2],
        execute: _fakeExecutor,
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await chain.proceed(missive);
      expect(order, [1, 2]);
    });

    test('courier can modify request', () async {
      final courier = _RecordingCourier()
        ..transformMissive = (m) {
          return m.copyWith(headers: {...m.headers, 'X-Custom': 'added'});
        };
      Uri? receivedUri;
      Map<String, String>? receivedHeaders;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          receivedUri = m.resolvedUri;
          receivedHeaders = m.headers;
          return _fakeExecutor(m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await chain.proceed(missive);
      expect(receivedUri, isNotNull);
      expect(receivedHeaders?['X-Custom'], 'added');
    });

    test('courier can modify response', () async {
      final courier = _RecordingCourier()
        ..transformDispatch = (d) {
          return d.copyWith(headers: {...d.headers, 'x-modified': 'true'});
        };
      final chain = CourierChain(couriers: [courier], execute: _fakeExecutor);
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      final dispatch = await chain.proceed(missive);
      expect(dispatch.headers['x-modified'], 'true');
    });

    test('courier can short-circuit request', () async {
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      final cachedResponse = Dispatch(
        statusCode: 200,
        data: {'cached': true},
        headers: const {},
        missive: missive,
      );
      final courier = _RecordingCourier()
        ..shouldShortCircuit = true
        ..shortCircuitResponse = cachedResponse;
      var executorCalled = false;
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          executorCalled = true;
          return _fakeExecutor(m);
        },
      );
      final dispatch = await chain.proceed(missive);
      expect(dispatch.data, {'cached': true});
      expect(executorCalled, isFalse);
    });
  });

  group('LogCourier', () {
    test('logs request and response', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add);
      final chain = CourierChain(couriers: [courier], execute: _fakeExecutor);
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/users'),
      );
      await chain.proceed(missive);
      expect(logs, hasLength(2));
      expect(logs[0], contains('→ GET'));
      expect(logs[0], contains('users'));
      expect(logs[1], contains('✓ GET'));
      expect(logs[1], contains('200'));
    });

    test('logs headers when enabled', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add, logHeaders: true);
      final chain = CourierChain(couriers: [courier], execute: _fakeExecutor);
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
        headers: {'Accept': 'application/json'},
      );
      await chain.proceed(missive);
      expect(logs.any((l) => l.contains('Accept')), isTrue);
    });

    test('logs body when enabled', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add, logBody: true);
      final chain = CourierChain(couriers: [courier], execute: _fakeExecutor);
      final missive = Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com'),
        data: {'name': 'Kael'},
      );
      await chain.proceed(missive);
      expect(logs.any((l) => l.contains('Kael')), isTrue);
    });

    test('logs errors', () async {
      final logs = <String>[];
      final courier = LogCourier(log: logs.add, logErrors: true);
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          throw EnvoyError.timeout(missive: m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await expectLater(
        () => chain.proceed(missive),
        throwsA(isA<EnvoyError>()),
      );
      expect(logs.any((l) => l.contains('✗')), isTrue);
    });
  });

  group('RetryCourier', () {
    test('retries on server error status', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 2,
        retryDelay: Duration(milliseconds: 1),
        addJitter: false,
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          return Dispatch(
            statusCode: attempts < 3 ? 500 : 200,
            headers: const {},
            missive: m,
            data: {'attempt': attempts},
          );
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      final dispatch = await chain.proceed(missive);
      expect(attempts, 3);
      expect(dispatch.statusCode, 200);
    });

    test('gives up after max retries', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 2,
        retryDelay: Duration(milliseconds: 1),
        addJitter: false,
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.connectionError(missive: m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await expectLater(
        () => chain.proceed(missive),
        throwsA(isA<EnvoyError>()),
      );
      expect(attempts, 3); // 1 initial + 2 retries
    });

    test('does not retry on cancellation', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.cancelled(missive: m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await expectLater(
        () => chain.proceed(missive),
        throwsA(isA<EnvoyError>()),
      );
      expect(attempts, 1);
    });

    test('does not retry on parse error', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.parseError(missive: m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await expectLater(
        () => chain.proceed(missive),
        throwsA(isA<EnvoyError>()),
      );
      expect(attempts, 1);
    });

    test('retries on configurable status codes', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 1,
        retryDelay: Duration(milliseconds: 1),
        retryOn: {429},
        addJitter: false,
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          return Dispatch(
            statusCode: attempts == 1 ? 429 : 200,
            headers: const {},
            missive: m,
          );
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      final dispatch = await chain.proceed(missive);
      expect(dispatch.statusCode, 200);
      expect(attempts, 2);
    });

    test('custom shouldRetry predicate', () async {
      var attempts = 0;
      final courier = RetryCourier(
        maxRetries: 3,
        retryDelay: Duration(milliseconds: 1),
        shouldRetry: (error, attempt) => attempt <= 1,
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempts++;
          throw EnvoyError.connectionError(missive: m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await expectLater(
        () => chain.proceed(missive),
        throwsA(isA<EnvoyError>()),
      );
      expect(
        attempts,
        2,
      ); // 1 initial + 1 retry (shouldRetry returns false for attempt 2)
    });
  });

  group('AuthCourier', () {
    test('injects token header', () async {
      Map<String, String>? sentHeaders;
      final courier = AuthCourier(tokenProvider: () => 'my-token-123');
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentHeaders = m.headers;
          return _fakeExecutor(m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await chain.proceed(missive);
      expect(sentHeaders?['Authorization'], 'Bearer my-token-123');
    });

    test('skips when header already present', () async {
      Map<String, String>? sentHeaders;
      final courier = AuthCourier(tokenProvider: () => 'should-not-use');
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentHeaders = m.headers;
          return _fakeExecutor(m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
        headers: {'Authorization': 'Custom token'},
      );
      await chain.proceed(missive);
      expect(sentHeaders?['Authorization'], 'Custom token');
    });

    test('custom header name and prefix', () async {
      Map<String, String>? sentHeaders;
      final courier = AuthCourier(
        tokenProvider: () => 'api-key-123',
        headerName: 'X-API-Key',
        tokenPrefix: '',
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentHeaders = m.headers;
          return _fakeExecutor(m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await chain.proceed(missive);
      expect(sentHeaders?['X-API-Key'], 'api-key-123');
    });

    test('async token provider', () async {
      Map<String, String>? sentHeaders;
      final courier = AuthCourier(
        tokenProvider: () async {
          await Future<void>.delayed(Duration(milliseconds: 1));
          return 'async-token';
        },
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentHeaders = m.headers;
          return _fakeExecutor(m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await chain.proceed(missive);
      expect(sentHeaders?['Authorization'], 'Bearer async-token');
    });

    test('skips when token is null', () async {
      Map<String, String>? sentHeaders;
      final courier = AuthCourier(tokenProvider: () => null);
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          sentHeaders = m.headers;
          return _fakeExecutor(m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      await chain.proceed(missive);
      expect(sentHeaders?.containsKey('Authorization'), isFalse);
    });

    test('refreshes token on 401', () async {
      var attempt = 0;
      var refreshCalled = false;
      final courier = AuthCourier(
        tokenProvider: () => 'old-token',
        onUnauthorized: () {
          refreshCalled = true;
          return 'new-token';
        },
      );
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          attempt++;
          final statusCode = attempt == 1 ? 401 : 200;
          return Dispatch(
            statusCode: statusCode,
            headers: const {},
            missive: m,
          );
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      final dispatch = await chain.proceed(missive);
      expect(refreshCalled, isTrue);
      expect(dispatch.statusCode, 200);
      expect(attempt, 2);
    });
  });

  group('MetricsCourier', () {
    test('reports success metric', () async {
      EnvoyMetric? reported;
      final courier = MetricsCourier(onMetric: (m) => reported = m);
      final chain = CourierChain(couriers: [courier], execute: _fakeExecutor);
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/test'),
      );
      await chain.proceed(missive);
      expect(reported, isNotNull);
      expect(reported!.method, 'GET');
      expect(reported!.url, contains('test'));
      expect(reported!.statusCode, 200);
      expect(reported!.success, isTrue);
      expect(reported!.duration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('reports error metric', () async {
      EnvoyMetric? reported;
      final courier = MetricsCourier(onMetric: (m) => reported = m);
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          throw EnvoyError.timeout(missive: m);
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/slow'),
      );
      await expectLater(
        () => chain.proceed(missive),
        throwsA(isA<EnvoyError>()),
      );
      expect(reported, isNotNull);
      expect(reported!.success, isFalse);
      expect(reported!.error, isNotNull);
    });

    test('detects cached responses', () async {
      EnvoyMetric? reported;
      final courier = MetricsCourier(onMetric: (m) => reported = m);
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) async {
          return Dispatch(
            statusCode: 200,
            headers: const {'x-envoy-cache': 'hit'},
            missive: m,
          );
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/cached'),
      );
      await chain.proceed(missive);
      expect(reported!.cached, isTrue);
    });
  });

  group('DedupCourier', () {
    test('deduplicates concurrent identical requests', () async {
      var executionCount = 0;
      final completer = Completer<Dispatch>();
      final courier = DedupCourier();
      final chain = CourierChain(
        couriers: [courier],
        execute: (m) {
          executionCount++;
          return completer.future.then((d) => d.copyWith(missive: m));
        },
      );
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/users'),
      );

      // Fire two identical requests
      final future1 = chain.proceed(missive);
      final future2 = CourierChain(
        couriers: [courier],
        execute: (m) {
          executionCount++;
          return completer.future.then((d) => d.copyWith(missive: m));
        },
      ).proceed(missive);

      // Complete the single network call
      completer.complete(
        Dispatch(
          statusCode: 200,
          headers: const {},
          missive: missive,
          data: {'deduped': true},
        ),
      );

      final r1 = await future1;
      final r2 = await future2;
      expect(executionCount, 1);
      expect(r1.data, {'deduped': true});
      expect(r2.data, {'deduped': true});
    });

    test('tracks in-flight count', () {
      final courier = DedupCourier();
      expect(courier.inFlightCount, 0);
    });

    test('allows different URLs concurrently', () async {
      var executionCount = 0;
      final courier = DedupCourier();
      final chain1 = CourierChain(
        couriers: [courier],
        execute: (m) async {
          executionCount++;
          return _fakeExecutor(m);
        },
      );
      final chain2 = CourierChain(
        couriers: [courier],
        execute: (m) async {
          executionCount++;
          return _fakeExecutor(m);
        },
      );
      final missive1 = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/users'),
      );
      final missive2 = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/posts'),
      );
      await Future.wait([chain1.proceed(missive1), chain2.proceed(missive2)]);
      expect(executionCount, 2);
    });
  });
}
