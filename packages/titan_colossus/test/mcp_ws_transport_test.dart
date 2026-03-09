@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Integration tests for the MCP WebSocket transport.
///
/// Spawns the MCP server with `--transport ws` and verifies that:
/// - `GET /health` returns 200 with transport info
/// - `GET /ws` upgrades to a WebSocket connection
/// - JSON-RPC initialize works over WebSocket
/// - JSON-RPC tools/list works over WebSocket
/// - Invalid JSON returns a parse error via WebSocket
/// - CORS headers are present
/// - Unknown routes return 404
void main() {
  const port = 18643; // Non-conflicting port for tests

  late Process serverProcess;
  late HttpClient httpClient;

  setUpAll(() async {
    // Start the MCP server in WebSocket mode
    serverProcess = await Process.start('dart', [
      'run',
      'titan_colossus:blueprint_mcp_server',
      '--transport',
      'ws',
      '--ws-port',
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
      throw StateError('MCP WebSocket server failed to start on port $port');
    }
  });

  tearDownAll(() {
    serverProcess.kill();
    httpClient.close(force: true);
  });

  group('MCP WebSocket Transport', () {
    test('GET /health returns 200 with transport info', () async {
      final req = await httpClient.getUrl(
        Uri.parse('http://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final data = jsonDecode(body) as Map<String, dynamic>;

      expect(res.statusCode, 200);
      expect(data['status'], 'ok');
      expect(data['transport'], 'ws');
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
        contains('GET'),
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

    test('WebSocket connection and JSON-RPC initialize', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws');

      final completer = Completer<Map<String, dynamic>>();

      ws.listen((data) {
        if (data is String && !completer.isCompleted) {
          completer.complete(jsonDecode(data) as Map<String, dynamic>);
        }
      });

      // Send JSON-RPC initialize
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
      final result = response['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2024-11-05');
      expect(result['serverInfo'], isNotNull);
      final serverInfo = result['serverInfo'] as Map<String, dynamic>;
      expect(serverInfo['name'], 'titan-blueprint');

      await ws.close();
    });

    test('WebSocket JSON-RPC tools/list returns tools', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws');

      final responses = <Map<String, dynamic>>[];
      final toolsCompleter = Completer<Map<String, dynamic>>();

      ws.listen((data) {
        if (data is String) {
          final parsed = jsonDecode(data) as Map<String, dynamic>;
          responses.add(parsed);
          if (parsed['id'] == 2 && !toolsCompleter.isCompleted) {
            toolsCompleter.complete(parsed);
          }
        }
      });

      // Initialize first (required before tools/list)
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

      // Wait briefly for initialize to process
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Request tools/list
      ws.add(jsonEncode({'jsonrpc': '2.0', 'method': 'tools/list', 'id': 2}));

      final toolsResponse = await toolsCompleter.future.timeout(
        const Duration(seconds: 10),
      );

      expect(toolsResponse['jsonrpc'], '2.0');
      expect(toolsResponse['id'], 2);
      final result = toolsResponse['result'] as Map<String, dynamic>;
      final tools = result['tools'] as List;
      expect(tools.length, greaterThanOrEqualTo(40));

      // Verify at least some key tools are present
      final toolNames = tools
          .cast<Map<String, dynamic>>()
          .map((t) => t['name'] as String)
          .toSet();
      expect(toolNames, contains('get_terrain'));
      expect(toolNames, contains('get_stratagems'));
      expect(toolNames, contains('scry'));
      expect(toolNames, contains('generate_campaign'));
      expect(toolNames, contains('relay_status'));

      await ws.close();
    });

    test('WebSocket invalid JSON returns parse error', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws');

      final completer = Completer<Map<String, dynamic>>();

      ws.listen((data) {
        if (data is String && !completer.isCompleted) {
          completer.complete(jsonDecode(data) as Map<String, dynamic>);
        }
      });

      // Send invalid JSON
      ws.add('not valid json');

      final response = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      expect(response['jsonrpc'], '2.0');
      expect(response['error'], isNotNull);
      final error = response['error'] as Map<String, dynamic>;
      expect(error['code'], -32700);
      expect(error['message'], contains('Parse error'));
      expect(response['id'], isNull);

      await ws.close();
    });

    test(
      'WebSocket bidirectional: multiple requests on same connection',
      () async {
        final ws = await WebSocket.connect('ws://127.0.0.1:$port/ws');

        final responses = <int, Map<String, dynamic>>{};
        final allDone = Completer<void>();

        ws.listen((data) {
          if (data is String) {
            final parsed = jsonDecode(data) as Map<String, dynamic>;
            final id = parsed['id'] as int?;
            if (id != null) {
              responses[id] = parsed;
            }
            // We expect responses for ids 1 and 3
            if (responses.containsKey(1) &&
                responses.containsKey(3) &&
                !allDone.isCompleted) {
              allDone.complete();
            }
          }
        });

        // Send initialize (id: 1)
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

        // Send shutdown (id: 3) — no-op but exercises the handler
        ws.add(jsonEncode({'jsonrpc': '2.0', 'method': 'shutdown', 'id': 3}));

        await allDone.future.timeout(const Duration(seconds: 5));

        expect(responses[1]!['result'], isNotNull);
        expect(responses[3]!['result'], isNull); // shutdown returns null result

        await ws.close();
      },
    );
  });
}
