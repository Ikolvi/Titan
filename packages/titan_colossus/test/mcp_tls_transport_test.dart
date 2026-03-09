@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/mcp/mcp_ws_client.dart';

/// Integration tests for TLS/SSL support on the MCP server transports.
///
/// Generates a self-signed certificate, starts the server with
/// `--tls-cert` and `--tls-key`, and verifies that:
/// - HTTPS health endpoint works
/// - WSS WebSocket connections work
/// - McpWebSocketClient connects over WSS with `trustSelfSigned`
void main() {
  const port = 18646; // Non-conflicting port for TLS tests

  late Process serverProcess;
  late Directory tempDir;
  late String certPath;
  late String keyPath;

  setUpAll(() async {
    // Create a temporary directory for the self-signed cert
    tempDir = await Directory.systemTemp.createTemp('mcp_tls_test_');
    certPath = '${tempDir.path}/cert.pem';
    keyPath = '${tempDir.path}/key.pem';

    // Generate a self-signed certificate using openssl
    final genResult = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-keyout',
      keyPath,
      '-out',
      certPath,
      '-days',
      '1',
      '-nodes',
      '-subj',
      '/CN=localhost',
    ]);

    if (genResult.exitCode != 0) {
      throw StateError(
        'Failed to generate self-signed cert:\n${genResult.stderr}',
      );
    }

    // Start the MCP server in WebSocket mode with TLS
    serverProcess = await Process.start('dart', [
      'run',
      'titan_colossus:blueprint_mcp_server',
      '--transport',
      'ws',
      '--ws-port',
      '$port',
      '--tls-cert',
      certPath,
      '--tls-key',
      keyPath,
    ], workingDirectory: Directory.current.path);

    // Wait for server to be ready (poll /health over HTTPS)
    final httpClient = HttpClient()..badCertificateCallback = (_, _, _) => true;

    var ready = false;
    for (var i = 0; i < 30; i++) {
      try {
        final req = await httpClient.getUrl(
          Uri.parse('https://127.0.0.1:$port/health'),
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

    httpClient.close(force: true);

    if (!ready) {
      throw StateError('MCP TLS server failed to start on port $port');
    }
  });

  tearDownAll(() async {
    serverProcess.kill();
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  group('MCP TLS Transport', () {
    test('HTTPS health endpoint returns 200', () async {
      final httpClient = HttpClient()
        ..badCertificateCallback = (_, _, _) => true;

      final req = await httpClient.getUrl(
        Uri.parse('https://127.0.0.1:$port/health'),
      );
      final res = await req.close();
      final body = await utf8.decodeStream(res);
      final data = jsonDecode(body) as Map<String, dynamic>;

      expect(res.statusCode, 200);
      expect(data['status'], 'ok');
      expect(data['transport'], 'ws');

      httpClient.close(force: true);
    });

    test('plain HTTP connection is rejected', () async {
      final httpClient = HttpClient();

      await expectLater(() async {
        final req = await httpClient.getUrl(
          Uri.parse('http://127.0.0.1:$port/health'),
        );
        await req.close();
      }, throwsA(anything));

      httpClient.close(force: true);
    });

    test('WSS WebSocket connection works', () async {
      final ws = await WebSocket.connect(
        'wss://127.0.0.1:$port/ws',
        customClient: HttpClient()..badCertificateCallback = (_, _, _) => true,
      );

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
            'clientInfo': {'name': 'tls-test', 'version': '1.0.0'},
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

      await ws.close();
    });

    test('McpWebSocketClient connects over WSS with trustSelfSigned', () async {
      final client = McpWebSocketClient(
        Uri.parse('wss://127.0.0.1:$port/ws'),
        trustSelfSigned: true,
        heartbeatTimeout: null,
      );

      await client.connect();
      expect(client.isConnected, isTrue);

      final response = await client.request(
        'initialize',
        params: {
          'protocolVersion': '2024-11-05',
          'capabilities': {},
          'clientInfo': {'name': 'tls-client-test', 'version': '1.0.0'},
        },
      );

      expect(response['result'], isNotNull);
      final result = response['result'] as Map<String, dynamic>;
      expect(result['protocolVersion'], '2024-11-05');

      await client.close();
    });

    test(
      'McpWebSocketClient without trustSelfSigned fails on self-signed cert',
      () async {
        final client = McpWebSocketClient(
          Uri.parse('wss://127.0.0.1:$port/ws'),
          trustSelfSigned: false,
          heartbeatTimeout: null,
        );

        await expectLater(() => client.connect(), throwsA(anything));

        await client.close();
      },
    );
  });
}
