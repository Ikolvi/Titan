@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Integration tests for the MCP SSE transport.
///
/// Spawns the MCP server with `--transport sse` and verifies that:
/// - `GET /health` returns 200 with transport info
/// - `GET /sse` opens an SSE stream with an `endpoint` event
/// - `POST /message` with JSON-RPC pushes a response via SSE
/// - CORS headers are present
/// - Invalid requests return appropriate errors
void main() {
  const port = 18642; // Use a non-conflicting port for tests

  late Process serverProcess;
  late HttpClient httpClient;

  setUpAll(() async {
    // Start the MCP server in SSE mode
    serverProcess = await Process.start('dart', [
      'run',
      'titan_colossus:blueprint_mcp_server',
      '--transport',
      'sse',
      '--sse-port',
      '$port',
    ], workingDirectory: Directory.current.path);

    httpClient = HttpClient();

    // Wait for server to be ready (poll /health)
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
      throw StateError('MCP SSE server failed to start on port $port');
    }
  });

  tearDownAll(() {
    serverProcess.kill();
    httpClient.close(force: true);
  });

  group('MCP SSE Transport', () {
    test('GET /health returns 200 with transport info', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final data = jsonDecode(body) as Map<String, dynamic>;

      expect(res.statusCode, 200);
      expect(data['status'], 'ok');
      expect(data['transport'], 'sse');
      expect(data['protocol'], '2024-11-05');
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
    });

    test('GET /unknown returns 404', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/unknown'),
      );
      final res = await req.close();
      await res.drain<void>();

      expect(res.statusCode, 404);
    });

    test('POST /message with invalid JSON returns 400', () async {
      final req = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/message'),
      );
      req.headers.contentType = ContentType.json;
      req.write('not json');
      final res = await req.close();
      final body = await utf8.decodeStream(res);

      expect(res.statusCode, 400);
      final data = jsonDecode(body) as Map<String, dynamic>;
      expect(data['error'], isNotNull);
    });

    test('GET /sse opens SSE stream with endpoint event', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/sse'),
      );
      final res = await req.close();

      expect(res.headers.contentType?.mimeType, 'text/event-stream');

      // Read the first SSE event (should be the endpoint event)
      final completer = Completer<String>();
      final buffer = StringBuffer();

      final sub = res.transform(utf8.decoder).listen((chunk) {
        buffer.write(chunk);
        final content = buffer.toString();
        if (content.contains('\n\n') && !completer.isCompleted) {
          completer.complete(content);
        }
      });

      final firstEvent = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      expect(firstEvent, contains('event: endpoint'));
      expect(firstEvent, contains('data: http://'));
      expect(firstEvent, contains('/message'));

      await sub.cancel();
    });

    test('POST /message with initialize returns 202 and pushes SSE', () async {
      // Connect SSE
      final sseReq = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/sse'),
      );
      final sseRes = await sseReq.close();

      final messageCompleter = Completer<String>();
      final buffer = StringBuffer();

      final sub = sseRes.transform(utf8.decoder).listen((chunk) {
        buffer.write(chunk);
        final content = buffer.toString();
        // Look for any 'event: message' after endpoint
        if (content.contains('event: message')) {
          final match = RegExp(
            r'event: message\ndata: (.+)\n',
          ).firstMatch(content);
          if (match != null && !messageCompleter.isCompleted) {
            messageCompleter.complete(match.group(1));
          }
        }
      });

      // Wait for SSE connection to establish
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Send JSON-RPC initialize
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
      final postBody = await utf8.decodeStream(postRes);

      // POST returns 202 Accepted
      expect(postRes.statusCode, 202);
      final postData = jsonDecode(postBody) as Map<String, dynamic>;
      expect(postData['accepted'], isTrue);
      expect(postData['id'], 1);

      // SSE receives the JSON-RPC response
      final sseData = await messageCompleter.future.timeout(
        const Duration(seconds: 5),
      );
      final rpcResponse = jsonDecode(sseData) as Map<String, dynamic>;
      expect(rpcResponse['jsonrpc'], '2.0');
      expect(rpcResponse['id'], 1);
      final result = rpcResponse['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2024-11-05');
      expect(result['serverInfo'], isNotNull);

      await sub.cancel();
    });

    test('tools/list request is accepted by SSE transport', () async {
      // Connect SSE to register as a client
      final sseReq = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/sse'),
      );
      final sseRes = await sseReq.close();
      final sub = sseRes.transform(utf8.decoder).listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Initialize first (required before tools/list)
      final initReq = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/message'),
      );
      initReq.headers.contentType = ContentType.json;
      initReq.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'method': 'initialize',
          'params': {
            'protocolVersion': '2024-11-05',
            'capabilities': {},
            'clientInfo': {'name': 'test', 'version': '1.0.0'},
          },
          'id': 10,
        }),
      );
      final initRes = await initReq.close();
      await initRes.drain<void>();
      expect(initRes.statusCode, 202);

      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Request tools/list — verify the POST is accepted
      final listReq = await httpClient.postUrl(
        Uri.parse('http://127.0.0.1:$port/message'),
      );
      listReq.headers.contentType = ContentType.json;
      listReq.write(
        jsonEncode({'jsonrpc': '2.0', 'method': 'tools/list', 'id': 11}),
      );
      final listRes = await listReq.close();
      final listBody = await utf8.decodeStream(listRes);
      final listData = jsonDecode(listBody) as Map<String, dynamic>;

      // POST returns 202 Accepted with the correct ID
      expect(listRes.statusCode, 202);
      expect(listData['accepted'], isTrue);
      expect(listData['id'], 11);

      await sub.cancel();
    });
  });
}
