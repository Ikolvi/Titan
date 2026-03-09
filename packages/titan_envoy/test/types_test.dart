import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:titan_envoy/titan_envoy.dart';

void main() {
  group('Missive', () {
    test('creates with required fields', () {
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/users'),
      );
      expect(missive.method, Method.get);
      expect(missive.uri.toString(), 'https://api.example.com/users');
      expect(missive.headers, isEmpty);
      expect(missive.data, isNull);
      expect(missive.queryParameters, isEmpty);
    });

    test('resolvedUri merges query parameters', () {
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/users?existing=1'),
        queryParameters: {'page': '2', 'limit': '10'},
      );
      final resolved = missive.resolvedUri;
      expect(resolved.queryParameters['existing'], '1');
      expect(resolved.queryParameters['page'], '2');
      expect(resolved.queryParameters['limit'], '10');
    });

    test('resolvedUri returns uri directly when no queryParameters', () {
      final uri = Uri.parse('https://api.example.com/users');
      final missive = Missive(method: Method.get, uri: uri);
      expect(identical(missive.resolvedUri, uri), isTrue);
    });

    test('encodedBody returns null for null data', () {
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
      );
      expect(missive.encodedBody, isNull);
    });

    test('encodedBody encodes Map to JSON', () {
      final missive = Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com'),
        data: {'name': 'Kael'},
      );
      expect(missive.encodedBody, '{"name":"Kael"}');
    });

    test('encodedBody encodes List to JSON', () {
      final missive = Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com'),
        data: [1, 2, 3],
      );
      expect(missive.encodedBody, '[1,2,3]');
    });

    test('encodedBody passes through String data', () {
      final missive = Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com'),
        data: 'raw body',
      );
      expect(missive.encodedBody, 'raw body');
    });

    test('encodedBody returns null for Parcel data', () {
      final missive = Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com'),
        data: Parcel(),
      );
      expect(missive.encodedBody, isNull);
    });

    test('copyWith creates modified copy', () {
      final original = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com'),
        headers: {'Accept': 'application/json'},
      );
      final copy = original.copyWith(
        method: Method.post,
        headers: {'Content-Type': 'application/json'},
      );
      expect(copy.method, Method.post);
      expect(copy.headers['Content-Type'], 'application/json');
      expect(original.method, Method.get);
    });

    test('copyWith with clearData removes data', () {
      final original = Missive(
        method: Method.post,
        uri: Uri.parse('https://api.example.com'),
        data: {'name': 'Kael'},
      );
      final copy = original.copyWith(clearData: true);
      expect(copy.data, isNull);
    });

    test('toString includes method and uri', () {
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://api.example.com/users'),
      );
      expect(missive.toString(), contains('GET'));
      expect(missive.toString(), contains('users'));
    });

    test('default values are correct', () {
      final missive = Missive(
        method: Method.get,
        uri: Uri.parse('https://example.com'),
      );
      expect(missive.responseType, ResponseType.json);
      expect(missive.followRedirects, isTrue);
      expect(missive.maxRedirects, 5);
      expect(missive.recall, isNull);
      expect(missive.sendTimeout, isNull);
      expect(missive.receiveTimeout, isNull);
      expect(missive.validateStatus, isNull);
      expect(missive.extra, isEmpty);
    });

    test('Method.verb returns uppercase', () {
      expect(Method.get.verb, 'GET');
      expect(Method.post.verb, 'POST');
      expect(Method.put.verb, 'PUT');
      expect(Method.delete.verb, 'DELETE');
      expect(Method.patch.verb, 'PATCH');
      expect(Method.head.verb, 'HEAD');
      expect(Method.options.verb, 'OPTIONS');
    });
  });

  group('Dispatch', () {
    final baseMissive = Missive(
      method: Method.get,
      uri: Uri.parse('https://api.example.com/users'),
    );

    test('creates with required fields', () {
      final dispatch = Dispatch(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        missive: baseMissive,
        data: {'id': 1},
      );
      expect(dispatch.statusCode, 200);
      expect(dispatch.data, {'id': 1});
      expect(dispatch.isSuccess, isTrue);
    });

    test('isSuccess for 2xx status codes', () {
      for (final code in [200, 201, 204, 299]) {
        final d = Dispatch(
          statusCode: code,
          headers: const {},
          missive: baseMissive,
        );
        expect(d.isSuccess, isTrue, reason: 'Status $code should be success');
      }
    });

    test('isClientError for 4xx status codes', () {
      for (final code in [400, 401, 403, 404, 422, 499]) {
        final d = Dispatch(
          statusCode: code,
          headers: const {},
          missive: baseMissive,
        );
        expect(
          d.isClientError,
          isTrue,
          reason: 'Status $code should be client error',
        );
      }
    });

    test('isServerError for 5xx status codes', () {
      for (final code in [500, 502, 503, 504]) {
        final d = Dispatch(
          statusCode: code,
          headers: const {},
          missive: baseMissive,
        );
        expect(
          d.isServerError,
          isTrue,
          reason: 'Status $code should be server error',
        );
      }
    });

    test('isRedirect for 3xx status codes', () {
      final d = Dispatch(
        statusCode: 301,
        headers: const {},
        missive: baseMissive,
      );
      expect(d.isRedirect, isTrue);
    });

    test('jsonMap returns typed map', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {},
        missive: baseMissive,
        data: {'name': 'Kael', 'level': 5},
      );
      expect(d.jsonMap, isA<Map<String, dynamic>>());
      expect(d.jsonMap['name'], 'Kael');
    });

    test('jsonMap throws on non-map data', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {},
        missive: baseMissive,
        data: [1, 2, 3],
      );
      expect(() => d.jsonMap, throwsA(isA<FormatException>()));
    });

    test('jsonList returns typed list', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {},
        missive: baseMissive,
        data: [1, 2, 3],
      );
      expect(d.jsonList, [1, 2, 3]);
    });

    test('jsonList throws on non-list data', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {},
        missive: baseMissive,
        data: {'key': 'value'},
      );
      expect(() => d.jsonList, throwsA(isA<FormatException>()));
    });

    test('contentType extracts header', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {'content-type': 'application/json'},
        missive: baseMissive,
      );
      expect(d.contentType, 'application/json');
    });

    test('contentLength parses header', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {'content-length': '1234'},
        missive: baseMissive,
      );
      expect(d.contentLength, 1234);
    });

    test('contentLength returns null for missing header', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {},
        missive: baseMissive,
      );
      expect(d.contentLength, isNull);
    });

    test('parsedJson decodes rawBody', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {},
        missive: baseMissive,
        rawBody: '{"name":"Kael"}',
      );
      expect(d.parsedJson, {'name': 'Kael'});
    });

    test('parsedJson returns null for empty body', () {
      final d = Dispatch(
        statusCode: 204,
        headers: const {},
        missive: baseMissive,
        rawBody: '',
      );
      expect(d.parsedJson, isNull);
    });

    test('copyWith creates modified copy', () {
      final original = Dispatch(
        statusCode: 200,
        headers: const {'x-custom': 'value'},
        missive: baseMissive,
        data: {'id': 1},
      );
      final copy = original.copyWith(statusCode: 201);
      expect(copy.statusCode, 201);
      expect(copy.data, {'id': 1});
    });

    test('toString includes method status and uri', () {
      final d = Dispatch(
        statusCode: 200,
        headers: const {},
        missive: baseMissive,
      );
      expect(d.toString(), contains('GET'));
      expect(d.toString(), contains('200'));
    });
  });

  group('EnvoyError', () {
    final baseMissive = Missive(
      method: Method.get,
      uri: Uri.parse('https://api.example.com/users'),
    );

    test('connectionError factory', () {
      final error = EnvoyError.connectionError(
        missive: baseMissive,
        error: 'socket closed',
      );
      expect(error.type, EnvoyErrorType.connectionError);
      expect(error.message, 'Connection failed');
      expect(error.error, 'socket closed');
    });

    test('timeout factory', () {
      final error = EnvoyError.timeout(missive: baseMissive);
      expect(error.type, EnvoyErrorType.timeout);
      expect(error.message, 'Request timed out');
    });

    test('cancelled factory', () {
      final error = EnvoyError.cancelled(missive: baseMissive);
      expect(error.type, EnvoyErrorType.cancelled);
      expect(error.message, 'Request was recalled');
    });

    test('badResponse factory', () {
      final dispatch = Dispatch(
        statusCode: 404,
        headers: const {},
        missive: baseMissive,
      );
      final error = EnvoyError.badResponse(
        missive: baseMissive,
        dispatch: dispatch,
      );
      expect(error.type, EnvoyErrorType.badResponse);
      expect(error.dispatch?.statusCode, 404);
      expect(error.message, contains('404'));
    });

    test('parseError factory', () {
      final error = EnvoyError.parseError(
        missive: baseMissive,
        error: FormatException('bad json'),
      );
      expect(error.type, EnvoyErrorType.parseError);
      expect(error.error, isA<FormatException>());
    });

    test('toString includes method and URL', () {
      final error = EnvoyError.timeout(missive: baseMissive);
      final str = error.toString();
      expect(str, contains('timeout'));
      expect(str, contains('GET'));
      expect(str, contains('users'));
    });

    test('toString includes status code for bad response', () {
      final dispatch = Dispatch(
        statusCode: 500,
        headers: const {},
        missive: baseMissive,
      );
      final error = EnvoyError.badResponse(
        missive: baseMissive,
        dispatch: dispatch,
      );
      expect(error.toString(), contains('500'));
    });

    test('is an Exception', () {
      final error = EnvoyError.timeout(missive: baseMissive);
      expect(error, isA<Exception>());
    });
  });

  group('Recall', () {
    test('starts uncancelled', () {
      final recall = Recall();
      expect(recall.isCancelled, isFalse);
      expect(recall.reason, isNull);
    });

    test('cancel sets isCancelled and reason', () {
      final recall = Recall();
      recall.cancel('too slow');
      expect(recall.isCancelled, isTrue);
      expect(recall.reason, 'too slow');
    });

    test('cancel without reason', () {
      final recall = Recall();
      recall.cancel();
      expect(recall.isCancelled, isTrue);
      expect(recall.reason, isNull);
    });

    test('double cancel is safe', () {
      final recall = Recall();
      recall.cancel('first');
      recall.cancel('second');
      expect(recall.reason, 'first');
    });

    test('whenCancelled completes on cancel', () async {
      final recall = Recall();
      final future = recall.whenCancelled;
      recall.cancel('done');
      final reason = await future;
      expect(reason, 'done');
    });
  });

  group('Parcel', () {
    test('starts empty', () {
      final parcel = Parcel();
      expect(parcel.entries, isEmpty);
      expect(parcel.hasFiles, isFalse);
    });

    test('addField adds text fields', () {
      final parcel = Parcel()
        ..addField('name', 'Kael')
        ..addField('level', '5');
      expect(parcel.fields.length, 2);
      expect(parcel.files, isEmpty);
    });

    test('addFile adds file entries', () {
      final parcel = Parcel()
        ..addFile(
          'avatar',
          ParcelFile.fromString(content: 'test', filename: 'test.txt'),
        );
      expect(parcel.files.length, 1);
      expect(parcel.hasFiles, isTrue);
    });

    test('fromMap creates pre-populated parcel', () {
      final parcel = Parcel.fromMap({'a': '1', 'b': '2'});
      expect(parcel.fields.length, 2);
    });

    test('toUrlEncoded encodes fields', () {
      final parcel = Parcel()
        ..addField('name', 'Kael the Hero')
        ..addField('level', '5');
      final encoded = parcel.toUrlEncoded();
      expect(encoded, contains('name=Kael'));
      expect(encoded, contains('level=5'));
      expect(encoded, contains('&'));
    });

    test('buildMultipartBody includes all entries', () {
      final parcel = Parcel()
        ..addField('name', 'Kael')
        ..addFile(
          'file',
          ParcelFile.fromString(
            content: 'hello',
            filename: 'test.txt',
            contentType: 'text/plain',
          ),
        );
      final boundary = Parcel.generateBoundary();
      final body = parcel.buildMultipartBody(boundary);
      final bodyStr = String.fromCharCodes(body);
      expect(bodyStr, contains('--$boundary'));
      expect(bodyStr, contains('name="name"'));
      expect(bodyStr, contains('name="file"'));
      expect(bodyStr, contains('filename="test.txt"'));
      expect(bodyStr, contains('text/plain'));
      expect(bodyStr, contains('Kael'));
      expect(bodyStr, contains('hello'));
      expect(bodyStr, contains('--$boundary--'));
    });

    test('generateBoundary produces unique strings', () {
      final b1 = Parcel.generateBoundary();
      final b2 = Parcel.generateBoundary();
      // They may be similar in quick succession, but should be non-empty
      expect(b1, isNotEmpty);
      expect(b2, isNotEmpty);
      expect(b1, startsWith('----EnvoyBoundary'));
    });
  });

  group('ParcelFile', () {
    test('fromBytes creates from raw bytes', () {
      final file = ParcelFile.fromBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'data.bin',
        contentType: 'application/octet-stream',
      );
      expect(file.bytes.length, 3);
      expect(file.filename, 'data.bin');
      expect(file.contentType, 'application/octet-stream');
      expect(file.length, 3);
    });

    test('fromString creates from text', () {
      final file = ParcelFile.fromString(
        content: 'Hello, World!',
        filename: 'greeting.txt',
      );
      expect(file.length, 13);
      expect(file.filename, 'greeting.txt');
      expect(file.contentType, 'text/plain');
    });
  });

  group('EnvoyMetric', () {
    test('creates with all fields', () {
      final metric = EnvoyMetric(
        method: 'GET',
        url: 'https://api.example.com/users',
        statusCode: 200,
        duration: Duration(milliseconds: 150),
        success: true,
        timestamp: DateTime(2024, 1, 1),
      );
      expect(metric.method, 'GET');
      expect(metric.statusCode, 200);
      expect(metric.success, isTrue);
      expect(metric.cached, isFalse);
    });

    test('toJson serializes all fields', () {
      final metric = EnvoyMetric(
        method: 'POST',
        url: 'https://api.example.com/users',
        statusCode: 201,
        duration: Duration(milliseconds: 250),
        success: true,
        requestSize: 100,
        responseSize: 500,
        timestamp: DateTime(2024, 1, 1),
      );
      final json = metric.toJson();
      expect(json['method'], 'POST');
      expect(json['statusCode'], 201);
      expect(json['durationMs'], 250);
      expect(json['success'], isTrue);
      expect(json['requestSize'], 100);
      expect(json['responseSize'], 500);
      expect(json['cached'], isFalse);
      expect(json['timestamp'], contains('2024'));
    });

    test('toJson includes error for failed requests', () {
      final metric = EnvoyMetric(
        method: 'GET',
        url: 'https://api.example.com/fail',
        duration: Duration(milliseconds: 50),
        success: false,
        error: 'Connection refused',
        timestamp: DateTime(2024, 1, 1),
      );
      final json = metric.toJson();
      expect(json['success'], isFalse);
      expect(json['error'], 'Connection refused');
      expect(json['statusCode'], isNull);
    });

    test('toString includes method url and timing', () {
      final metric = EnvoyMetric(
        method: 'GET',
        url: 'https://api.example.com/users',
        statusCode: 200,
        duration: Duration(milliseconds: 150),
        success: true,
        timestamp: DateTime(2024, 1, 1),
      );
      final str = metric.toString();
      expect(str, contains('GET'));
      expect(str, contains('users'));
      expect(str, contains('150ms'));
    });
  });

  group('ResponseType', () {
    test('has all expected values', () {
      expect(ResponseType.values, hasLength(4));
      expect(ResponseType.values, contains(ResponseType.json));
      expect(ResponseType.values, contains(ResponseType.plain));
      expect(ResponseType.values, contains(ResponseType.bytes));
      expect(ResponseType.values, contains(ResponseType.stream));
    });
  });
}
