@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Integration tests for the MCP auto-detect transport.
///
/// Spawns the MCP server with `--transport auto` and verifies that all
/// transports (Streamable HTTP, WebSocket, legacy SSE) work on one port.
void main() {
  const port = 18645; // Non-conflicting port for tests

  late Process serverProcess;
  late HttpClient httpClient;

  setUpAll(() async {
    serverProcess = await Process.start('dart', [
      'run',
      'titan_colossus:blueprint_mcp_server',
      '--transport',
      'auto',
      '--port',
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
      throw StateError('MCP auto-detect server failed to start on port $port');
    }
  });

  tearDownAll(() {
    serverProcess.kill();
    httpClient.close(force: true);
  });

  group('MCP Auto-Detect Transport', () {
    // ── Health ──
    test('GET /health returns auto transport info', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final data = jsonDecode(body) as Map<String, dynamic>;

      expect(res.statusCode, 200);
      expect(data['status'], 'ok');
      expect(data['transport'], 'auto');
      expect(data['protocol'], '2025-03-26');
      expect(data['available'], containsAll(['streamable', 'ws', 'sse']));
    });

    test('GET /health includes CORS headers', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      await res.drain<void>();

      expect(res.headers.value('access-control-allow-origin'), '*');
      expect(
        res.headers.value('access-control-expose-headers'),
        contains('Mcp-Session-Id'),
      );
    });

    // ── Streamable HTTP on /mcp ──
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
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['jsonrpc'], '2.0');
      expect(data['id'], 1);
      expect(data['result'], isNotNull);

      final sessionId = res.headers.value('mcp-session-id');
      expect(sessionId, isNotNull);
    });

    test('POST /mcp notification returns 202', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');
      req.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
      );
      final res = await req.close();
      await res.drain<void>();

      expect(res.statusCode, 202);
    });

    test('DELETE /mcp terminates session', () async {
      // Initialize to get session
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
      final delReq = await httpClient.deleteUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      delReq.headers.set('Mcp-Session-Id', sessionId!);
      final delRes = await delReq.close();
      final delBody = await utf8.decodeStream(delRes);

      expect(delRes.statusCode, 200);
      expect(jsonDecode(delBody)['terminated'], isTrue);
    });

    // ── WebSocket on /ws ──
    test('WebSocket initialize via /ws', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws');

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
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 1,
        }),
      );

      final response = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      expect(response['jsonrpc'], '2.0');
      expect(response['id'], 1);
      expect(response['result'], isNotNull);

      await ws.close();
    });

    // ── Legacy SSE on /sse + /message ──
    test('GET /sse opens SSE stream with endpoint event', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/sse'),
      );
      final res = await req.close();

      expect(res.headers.contentType?.mimeType, 'text/event-stream');

      final completer = Completer<String>();
      final buffer = StringBuffer();
      final sub = res.transform(utf8.decoder).listen((chunk) {
        buffer.write(chunk);
        if (buffer.toString().contains('\n\n') && !completer.isCompleted) {
          completer.complete(buffer.toString());
        }
      });

      final event = await completer.future.timeout(const Duration(seconds: 5));
      expect(event, contains('event: endpoint'));
      expect(event, contains('/message'));

      await sub.cancel();
    });

    test('POST /message with initialize returns 202 + pushes SSE', () async {
      // Connect SSE
      final sseReq = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/sse'),
      );
      final sseRes = await sseReq.close();

      final completer = Completer<String>();
      final buffer = StringBuffer();
      final sub = sseRes.transform(utf8.decoder).listen((chunk) {
        buffer.write(chunk);
        final content = buffer.toString();
        if (content.contains('event: message')) {
          final match = RegExp(
            r'event: message\ndata: (.+)\n',
          ).firstMatch(content);
          if (match != null && !completer.isCompleted) {
            completer.complete(match.group(1));
          }
        }
      });

      await Future<void>.delayed(const Duration(milliseconds: 500));

      final postReq = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/message'),
      );
      postReq.headers.contentType = ContentType.json;
      postReq.write(
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
      final postRes = await postReq.close();
      await postRes.drain<void>();

      expect(postRes.statusCode, 202);

      final sseData = await completer.future.timeout(
        const Duration(seconds: 5),
      );
      final rpcResponse = jsonDecode(sseData) as Map<String, dynamic>;
      expect(rpcResponse['jsonrpc'], '2.0');
      expect(rpcResponse['id'], 1);

      await sub.cancel();
    });

    // ── Error handling ──
    test('GET /unknown returns 404', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/unknown'),
      );
      final res = await req.close();
      await res.drain<void>();

      expect(res.statusCode, 404);
    });

    test('POST /mcp with invalid JSON returns 400', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/mcp'),
      );
      req.headers
        ..contentType = ContentType.json
        ..set('Accept', 'application/json, text/event-stream');
      req.write('not json');
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 400);
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['error'], isNotNull);
    });
  });
}
