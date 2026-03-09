@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Integration tests for the MCP Streamable HTTP transport (2025-03-26 spec).
///
/// Spawns the MCP server with `--transport streamable` and verifies:
/// - `GET /health` returns 200 with transport info
/// - `POST /mcp` with initialize returns JSON response + Mcp-Session-Id
/// - `POST /mcp` with tools/list returns all tools as JSON
/// - `POST /mcp` with notifications-only returns 202 Accepted
/// - `POST /mcp` with invalid JSON returns 400 parse error
/// - `GET /mcp` without session returns 400
/// - `DELETE /mcp` terminates session
/// - Unknown routes return 404
/// - CORS headers are present
void main() {
  const port = 18644; // Non-conflicting port for tests

  late Process serverProcess;
  late HttpClient httpClient;

  setUpAll(() async {
    serverProcess = await Process.start('dart', [
      'run',
      'titan_colossus:blueprint_mcp_server',
      '--transport',
      'streamable',
      '--streamable-port',
      '$port',
    ], workingDirectory: Directory.current.path);

    httpClient = HttpClient();

    // Wait for server to be ready
    var ready = false;
    for (var i = 0; i < 30; i++) {
      try {
        final req = await httpClient.getUrl(
          Uri.parse('http://127.0.0.1:$port/health'),
        );
        final res = await req.close();
        if (res.statusCode == 200) {
          await res.drain<void>();
          ready = true;
          break;
        }
        await res.drain<void>();
      } catch (_) {
        // Server not ready yet
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    if (!ready) {
      throw StateError(
        'MCP Streamable HTTP server failed to start on port $port',
      );
    }
  });

  tearDownAll(() {
    serverProcess.kill();
    httpClient.close(force: true);
  });

  group('MCP Streamable HTTP Transport', () {
    test('GET /health returns 200 with transport info', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final data = jsonDecode(body) as Map<String, dynamic>;

      expect(res.statusCode, 200);
      expect(data['status'], 'ok');
      expect(data['transport'], 'streamable');
      expect(data['protocol'], '2025-03-26');
    });

    test('GET /health includes CORS headers', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      await res.drain<void>();

      expect(res.headers.value('access-control-allow-origin'), '*');
      expect(
        res.headers.value('access-control-allow-methods'),
        contains('POST'),
      );
      expect(
        res.headers.value('access-control-allow-headers'),
        contains('Mcp-Session-Id'),
      );
      expect(
        res.headers.value('access-control-expose-headers'),
        contains('Mcp-Session-Id'),
      );
    });

    test('GET /unknown returns 404', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/unknown'),
      );
      final res = await req.close();
      await res.drain<void>();

      expect(res.statusCode, 404);
    });

    test('POST /mcp initialize returns JSON + Mcp-Session-Id', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      expect(res.headers.contentType?.mimeType, 'application/json');

      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['jsonrpc'], '2.0');
      expect(data['id'], 1);
      final result = data['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], isNotNull);
      expect(result['serverInfo'], isNotNull);

      // Session ID must be returned
      final sessionId = res.headers.value('mcp-session-id');
      expect(sessionId, isNotNull);
      expect(sessionId, isNotEmpty);
    });

    test('POST /mcp tools/list returns tools as JSON', () async {
      // First initialize to get a session
      final initReq = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      initReq.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');
      initReq.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );
      final initRes = await initReq.close();
      await initRes.drain<void>();
      final sessionId = initRes.headers.value('mcp-session-id');
      expect(sessionId, isNotNull);

      // Now request tools/list
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream')
        ..set('Mcp-Session-Id', sessionId!);
      req.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'tools/list', 'id': 2}),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['jsonrpc'], '2.0');
      expect(data['id'], 2);
      final result = data['result'] as Map<String, dynamic>;
      final tools = result['tools'] as List;
      expect(tools.length, greaterThanOrEqualTo(40));

      // Verify key tools
      final toolNames = tools
          .cast<Map<String, dynamic>>()
          .map((t) => t['name'] as String)
          .toSet();
      expect(toolNames, contains('get_terrain'));
      expect(toolNames, contains('scry'));
      expect(toolNames, contains('relay_status'));
    });

    test('POST /mcp notification-only returns 202 Accepted', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');
      // Notification has 'method' but no 'id'
      req.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      final res = await req.close();
      await res.drain<void>();

      expect(res.statusCode, 202);
    });

    test('POST /mcp invalid JSON returns 400', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');
      req.write('not valid json');
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 400);
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['error'], isNotNull);
      final error = data['error'] as Map<String, dynamic>;
      expect(error['code'], -32700);
    });

    test('GET /mcp without session returns 400', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers.set('Accept', 'text/event-stream');
      final res = await req.close();
      await res.drain<void>();

      expect(res.statusCode, 400);
    });

    test('DELETE /mcp terminates session', () async {
      // Initialize to get a session
      final initReq = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      initReq.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');
      initReq.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-03-26',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );
      final initRes = await initReq.close();
      await initRes.drain<void>();
      final sessionId = initRes.headers.value('mcp-session-id');
      expect(sessionId, isNotNull);

      // Delete session
      final deleteReq = await httpClient.deleteUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      deleteReq.headers.set('Mcp-Session-Id', sessionId!);
      final deleteRes = await deleteReq.close();
      final deleteBody = await utf8.decodeStream(deleteRes);

      expect(deleteRes.statusCode, 200);
      final data = jsonDecode(deleteBody) as Map<String, dynamic>;
      expect(data['terminated'], isTrue);

      // Subsequent DELETE with same session should return 404
      final deleteReq2 = await httpClient.deleteUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      deleteReq2.headers.set('Mcp-Session-Id', sessionId);
      final deleteRes2 = await deleteReq2.close();
      await deleteRes2.drain<void>();

      expect(deleteRes2.statusCode, 404);
    });

    test('POST /mcp batch request returns batch response', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');

      // Send a batch with initialize + a shutdown
      req.write(
        jsonEncode([
          {
            'jsonrpc': '2.0',
            'method': 'initialize',
            'params': {
              'protocolVersion': '2025-03-26',
              'capabilities': {},
              'clientInfo': {'name': 'test', 'version': '1.0.0'},
            },
            'id': 10,
          },
          {'jsonrpc': '2.0', 'method': 'shutdown', 'id': 11},
        ]),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      final data = jsonDecode(body) as List;
      expect(data.length, 2);

      // Find initialize response
      final initResponse = data.cast<Map<String, dynamic>>().firstWhere(
        (r) => r['id'] == 10,
      );
      expect(initResponse['result'], isNotNull);
      expect((initResponse['result'] as Map)['serverInfo'], isNotNull);
    });

    test('PUT /mcp returns 405 Method Not Allowed', () async {
      final req = await httpClient.putUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers.contentType = ContentType.json;
      req.write('{}');
      final res = await req.close();
      await res.drain<void>();

      expect(res.statusCode, 405);
    });
  });
}
