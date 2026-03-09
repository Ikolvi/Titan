import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

void main() {
  late HttpServer server;
  late Envoy envoy;
  late String baseUrl;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://localhost:${server.port}';
    envoy = Envoy(baseUrl: baseUrl);

    server.listen((request) async {
      final path = request.uri.path;
      final method = request.method;

      switch ((method, path)) {
        case ('GET', '/users'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode([
                {'id': 1, 'name': 'Kael'},
                {'id': 2, 'name': 'Lyra'},
              ]),
            );
        case ('GET', '/users/1'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'id': 1, 'name': 'Kael'}));
        case ('POST', '/users'):
          final body = await utf8.decoder.bind(request).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..statusCode = 201
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'id': 3, ...data}));
        case ('PUT', '/users/1'):
          final body = await utf8.decoder.bind(request).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'id': 1, ...data}));
        case ('DELETE', '/users/1'):
          request.response.statusCode = 204;
        case ('PATCH', '/users/1'):
          final body = await utf8.decoder.bind(request).join();
          final data = jsonDecode(body) as Map<String, dynamic>;
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'id': 1, ...data}));
        case ('HEAD', '/users'):
          request.response
            ..statusCode = 200
            ..headers.add('x-total-count', '42');
        case ('GET', '/error'):
          request.response
            ..statusCode = 500
            ..write('Internal Server Error');
        case ('GET', '/not-found'):
          request.response
            ..statusCode = 404
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'Not found'}));
        case ('GET', '/query'):
          final params = request.uri.queryParameters;
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(params));
        case ('GET', '/slow'):
          await Future<void>.delayed(Duration(seconds: 2));
          request.response
            ..statusCode = 200
            ..write('slow response');
        case ('GET', '/plain'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.text
            ..write('Hello, World!');
        case ('POST', '/upload'):
          final body = await utf8.decoder.bind(request).join();
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'received': true,
                'contentType': request.headers.contentType?.toString(),
                'bodyLength': body.length,
              }),
            );
        case ('GET', '/headers'):
          request.response
            ..statusCode = 200
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'authorization': request.headers.value('authorization'),
                'x-custom': request.headers.value('x-custom'),
                'accept': request.headers.value('accept'),
              }),
            );
        default:
          request.response
            ..statusCode = 404
            ..write('Not found: $method $path');
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    envoy.close();
    await server.close();
  });

  group('Envoy HTTP Methods', () {
    test('GET returns parsed JSON list', () async {
      final dispatch = await envoy.get('/users');
      expect(dispatch.statusCode, 200);
      expect(dispatch.isSuccess, isTrue);
      expect(dispatch.jsonList, hasLength(2));
      expect(dispatch.jsonList[0]['name'], 'Kael');
    });

    test('GET returns parsed JSON object', () async {
      final dispatch = await envoy.get('/users/1');
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['name'], 'Kael');
    });

    test('POST sends and receives JSON', () async {
      final dispatch = await envoy.post('/users', data: {'name': 'Theron'});
      expect(dispatch.statusCode, 201);
      expect(dispatch.jsonMap['id'], 3);
      expect(dispatch.jsonMap['name'], 'Theron');
    });

    test('PUT updates resource', () async {
      final dispatch = await envoy.put(
        '/users/1',
        data: {'name': 'Updated Kael'},
      );
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['name'], 'Updated Kael');
    });

    test('DELETE removes resource', () async {
      final dispatch = await envoy.delete('/users/1');
      expect(dispatch.statusCode, 204);
    });

    test('PATCH partially updates resource', () async {
      final dispatch = await envoy.patch('/users/1', data: {'level': 10});
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['level'], 10);
    });

    test('HEAD returns headers only', () async {
      final dispatch = await envoy.head('/users');
      expect(dispatch.statusCode, 200);
      expect(dispatch.headers['x-total-count'], '42');
    });

    test('GET with query parameters', () async {
      final dispatch = await envoy.get(
        '/query',
        queryParameters: {'page': '1', 'limit': '10'},
      );
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['page'], '1');
      expect(dispatch.jsonMap['limit'], '10');
    });
  });

  group('Envoy Configuration', () {
    test('default headers are sent with every request', () async {
      final customEnvoy = Envoy(
        baseUrl: baseUrl,
        headers: {'Accept': 'application/json', 'X-Custom': 'global-value'},
      );
      final dispatch = await customEnvoy.get('/headers');
      expect(dispatch.jsonMap['accept'], 'application/json');
      expect(dispatch.jsonMap['x-custom'], 'global-value');
      customEnvoy.close();
    });

    test('per-request headers override defaults', () async {
      final customEnvoy = Envoy(
        baseUrl: baseUrl,
        headers: {'X-Custom': 'default'},
      );
      final dispatch = await customEnvoy.get(
        '/headers',
        headers: {'X-Custom': 'overridden'},
      );
      expect(dispatch.jsonMap['x-custom'], 'overridden');
      customEnvoy.close();
    });

    test('absolute URLs bypass baseUrl', () async {
      final dispatch = await envoy.get('$baseUrl/users/1');
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['name'], 'Kael');
    });
  });

  group('Envoy Error Handling', () {
    test('throws EnvoyError on 500', () async {
      await expectLater(
        () => envoy.get('/error'),
        throwsA(
          isA<EnvoyError>()
              .having((e) => e.type, 'type', EnvoyErrorType.badResponse)
              .having((e) => e.dispatch?.statusCode, 'status', 500),
        ),
      );
    });

    test('throws EnvoyError on 404', () async {
      await expectLater(
        () => envoy.get('/not-found'),
        throwsA(
          isA<EnvoyError>()
              .having((e) => e.type, 'type', EnvoyErrorType.badResponse)
              .having((e) => e.dispatch?.statusCode, 'status', 404),
        ),
      );
    });

    test('custom validateStatus changes error behavior', () async {
      final customEnvoy = Envoy(
        baseUrl: baseUrl,
        validateStatus: (status) => status < 500,
      );
      // 404 should now be treated as success
      final dispatch = await customEnvoy.get('/not-found');
      expect(dispatch.statusCode, 404);
      customEnvoy.close();
    });

    test('throws on timeout', () async {
      final fastEnvoy = Envoy(
        baseUrl: baseUrl,
        receiveTimeout: Duration(milliseconds: 100),
      );
      await expectLater(
        () => fastEnvoy.get('/slow'),
        throwsA(
          isA<EnvoyError>().having(
            (e) => e.type,
            'type',
            EnvoyErrorType.timeout,
          ),
        ),
      );
      fastEnvoy.close();
    });

    test('throws StateError after close', () async {
      envoy.close();
      expect(() => envoy.get('/users'), throwsStateError);
    });
  });

  group('Envoy Recall (Cancellation)', () {
    test('cancels in-flight request', () async {
      final recall = Recall();
      final future = envoy.get('/slow', recall: recall);

      // Cancel after a short delay
      Timer(Duration(milliseconds: 50), () => recall.cancel('too slow'));

      await expectLater(
        () => future,
        throwsA(
          isA<EnvoyError>().having(
            (e) => e.type,
            'type',
            EnvoyErrorType.cancelled,
          ),
        ),
      );
    });

    test('pre-cancelled recall throws immediately', () async {
      final recall = Recall()..cancel('already cancelled');
      await expectLater(
        () => envoy.get('/users', recall: recall),
        throwsA(isA<EnvoyError>()),
      );
    });
  });

  group('Envoy Courier Chain', () {
    test('courier sees requests and responses', () async {
      final seen = <String>[];
      envoy.addCourier(_TrackingCourier(seen));

      await envoy.get('/users');
      expect(seen, ['request:GET /users', 'response:200']);
    });

    test('multiple couriers execute in order', () async {
      final order = <int>[];
      envoy
        ..addCourier(_OrderCourier(1, order))
        ..addCourier(_OrderCourier(2, order));

      await envoy.get('/users');
      // Request phase: 1, 2. Response phase: 2, 1 (unwinding)
      expect(order, [1, 2, 2, 1]);
    });

    test('removeCourier removes interceptor', () async {
      final courier = _TrackingCourier([]);
      envoy.addCourier(courier);
      expect(envoy.couriers, contains(courier));

      envoy.removeCourier(courier);
      expect(envoy.couriers, isNot(contains(courier)));
    });

    test('clearCouriers removes all', () async {
      envoy
        ..addCourier(_TrackingCourier([]))
        ..addCourier(_TrackingCourier([]));
      expect(envoy.couriers, hasLength(2));

      envoy.clearCouriers();
      expect(envoy.couriers, isEmpty);
    });
  });

  group('Envoy with Parcel (FormData)', () {
    test('sends form-encoded data', () async {
      final parcel = Parcel()
        ..addField('name', 'Kael')
        ..addField('level', '5');
      final dispatch = await envoy.post('/upload', data: parcel);
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['received'], isTrue);
    });

    test('sends multipart data with files', () async {
      final parcel = Parcel()
        ..addField('name', 'attached')
        ..addFile(
          'file',
          ParcelFile.fromString(content: 'file content', filename: 'test.txt'),
        );
      final dispatch = await envoy.post('/upload', data: parcel);
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['received'], isTrue);
    });
  });

  group('Envoy Dispatch properties', () {
    test('dispatch includes duration', () async {
      final dispatch = await envoy.get('/users');
      expect(dispatch.duration, isNotNull);
      expect(dispatch.duration!.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('dispatch rawBody contains response text', () async {
      final dispatch = await envoy.get('/users/1');
      expect(dispatch.rawBody, isNotNull);
      expect(dispatch.rawBody, contains('Kael'));
    });

    test('dispatch includes resolved missive', () async {
      final dispatch = await envoy.get('/users');
      expect(dispatch.missive.method, Method.get);
      expect(dispatch.missive.uri.path, '/users');
    });
  });

  group('Envoy send() method', () {
    test('accepts custom Missive', () async {
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('$baseUrl/users/1'),
        headers: {'Accept': 'application/json'},
      );
      final dispatch = await envoy.send(missive);
      expect(dispatch.statusCode, 200);
      expect(dispatch.jsonMap['name'], 'Kael');
    });
  });
}

class _TrackingCourier extends Courier {
  final List<String> log;
  _TrackingCourier(this.log);

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    log.add('request:${missive.method.verb} ${missive.uri.path}');
    final dispatch = await chain.proceed(missive);
    log.add('response:${dispatch.statusCode}');
    return dispatch;
  }
}

class _OrderCourier extends Courier {
  final int id;
  final List<int> order;
  _OrderCourier(this.id, this.order);

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    order.add(id);
    final dispatch = await chain.proceed(missive);
    order.add(id);
    return dispatch;
  }
}
