@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/mcp/mcp_ws_client.dart';

/// Integration tests for MCP server authentication.
///
/// Starts the server with `--auth-token` and verifies that:
/// - Unauthenticated requests return 401
/// - Bearer token in Authorization header works
/// - Token in query parameter works (WebSocket)
/// - Health check is always accessible (no auth)
/// - McpWebSocketClient sends the auth token
void main() {
  const port = 18647; // Non-conflicting port for auth tests
  const authToken = 'test-secret-token-42';

  late Process serverProcess;
  late HttpClient httpClient;

  setUpAll(() async {
    // Start the MCP server with auth token (auto transport to test all)
    serverProcess = await Process.start('dart', [
      'run',
      'titan_colossus:blueprint_mcp_server',
      '--transport',
      'auto',
      '--port',
      '$port',
      '--auth-token',
      authToken,
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
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    if (!ready) {
      throw StateError('MCP auth server failed to start on port $port');
    }
  });

  tearDownAll(() {
    serverProcess.kill();
    httpClient.close(force: true);
  });

  group('MCP Authentication', () {
    test('health check is accessible without auth', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final data = jsonDecode(body) as Map<String, dynamic>;

      expect(res.statusCode, 200);
      expect(data['status'], 'ok');
    });

    test('POST /mcp without auth returns 401', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 401);
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['error'], isNotNull);
      expect(
        (data['error'] as Map<String, dynamic>)['message'],
        contains('Unauthorized'),
      );
    });

    test('POST /mcp with valid Bearer token succeeds', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Authorization', 'Bearer $authToken');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 200);
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['result'], isNotNull);
    });

    test('POST /mcp with wrong token returns 401', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Authorization', 'Bearer wrong-token');
      req.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );
      final res = await req.close();

      expect(res.statusCode, 401);
      await res.drain<void>();
    });

    test('WebSocket /ws without auth returns 401', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/ws'),
      );
      req.headers
        ..set('Upgrade', 'websocket')
        ..set('Connection', 'Upgrade')
        ..set('Sec-WebSocket-Key', 'dGhlIHNhbXBsZSBub25jZQ==')
        ..set('Sec-WebSocket-Version', '13');
      final res = await req.close();

      expect(res.statusCode, 401);
      await res.drain<void>();
    });

    test('WebSocket with Bearer header auth connects', () async {
      final ws = await WebSocket.connect(
        'ws://127.0.0.1:$port/ws',
        headers: {'Authorization': 'Bearer $authToken'},
      );

      final completer = Completer<Map<String, dynamic>>();
      ws.listen((data) {
        if (data is String && !completer.isCompleted) {
          completer.complete(jsonDecode(data) as Map<String, dynamic>);
        }
      });

      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'auth-test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );

      final response = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      expect(response['result'], isNotNull);
      await ws.close();
    });

    test('WebSocket with query param auth connects', () async {
      final ws = await WebSocket.connect(
        'ws://127.0.0.1:$port/ws?token=$authToken',
      );

      final completer = Completer<Map<String, dynamic>>();
      ws.listen((data) {
        if (data is String && !completer.isCompleted) {
          completer.complete(jsonDecode(data) as Map<String, dynamic>);
        }
      });

      ws.add(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'query-auth-test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );

      final response = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      expect(response['result'], isNotNull);
      await ws.close();
    });

    test('McpWebSocketClient with authToken connects', () async {
      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        authToken: authToken,
        heartbeatTimeout: null,
      );

      await client.connect();
      expect(client.isConnected, isTrue);

      final response = await client.request(
        'initialize',
        params: {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'client-auth-test', 'version': '1.0.0'},
        },
      );

      expect(response['result'], isNotNull);
      await client.close();
    });

    test('McpWebSocketClient without authToken fails', () async {
      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        heartbeatTimeout: null,
      );

      await expectLater(() => client.connect(), throwsA(anything));

      await client.close();
    });

    test('GET /sse without auth returns 401', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/sse'),
      );
      final res = await req.close();

      expect(res.statusCode, 401);
      await res.drain<void>();
    });

    test('DELETE /mcp without auth returns 401', () async {
      final req = await httpClient.deleteUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers.set('Mcp-Session-Id', 'fake-session');
      final res = await req.close();

      expect(res.statusCode, 401);
      await res.drain<void>();
    });
  });
}
