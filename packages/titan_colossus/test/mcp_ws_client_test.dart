@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/mcp/mcp_ws_client.dart';

/// Tests for [McpWebSocketClient] — auto-reconnect, heartbeat, and
/// exponential backoff.
///
/// Uses a lightweight test server (not the full MCP server) so that
/// we can control restarts, delays, and heartbeat timing precisely.
void main() {
  group('McpWebSocketClient', () {
    late HttpServer server;
    late int port;

    Future<HttpServer> startEchoServer({
      bool sendPings = false,
      Duration pingInterval = const Duration(seconds: 1),
    }) async {
      final s = await HttpServer.bind('127.0.0.1', 0);
      s.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((ws) {
            Timer? pingTimer;
            if (sendPings) {
              pingTimer = Timer.periodic(pingInterval, (_) {
                try {
                  ws.add(jsonEncode({'jsonrpc': '2.0', 'method': 'ping'}));
                } catch (_) {}
              });
            }

            ws.listen(
              (data) {
                if (data is String) {
                  try {
                    final parsed = jsonDecode(data) as Map<String, dynamic>;
                    final method = parsed['method'] as String?;
                    final id = parsed['id'];

                    // Skip pong notifications
                    if (method == 'pong') return;

                    // Echo back responses for requests with an id
                    if (id != null) {
                      ws.add(
                        jsonEncode({
                          'jsonrpc': '2.0',
                          'id': id,
                          'result': {'echo': method},
                        }),
                      );
                    }
                  } catch (_) {}
                }
              },
              onDone: () => pingTimer?.cancel(),
              onError: (_) => pingTimer?.cancel(),
            );
          });
        } else if (request.uri.path == '/health') {
          request.response
            ..statusCode = 200
            ..write('ok')
            ..close();
        } else {
          request.response
            ..statusCode = 404
            ..close();
        }
      });
      return s;
    }

    setUp(() async {
      server = await startEchoServer();
      port = server.port;
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('connects and sends a JSON-RPC request', () async {
      final client = McpWebSocketClient(Uri.parse('ws://127.0.0.1:$port/ws'));

      await client.connect();
      expect(client.isConnected, isTrue);

      final response = await client.request('initialize');
      expect(response['id'], isNotNull);
      expect(response['result'], isNotNull);
      final result = response['result'] as Map<String, dynamic>;
      expect(result['echo'], 'initialize');

      await client.close();
      expect(client.isConnected, isFalse);
    });

    test('sends notifications without expecting a response', () async {
      final client = McpWebSocketClient(Uri.parse('ws://127.0.0.1:$port/ws'));

      await client.connect();

      // Notifications don't throw and don't block
      client.notify('notifications/initialized');

      await client.close();
    });

    test('emits status transitions on connect and close', () async {
      final client = McpWebSocketClient(Uri.parse('ws://127.0.0.1:$port/ws'));

      final statuses = <McpConnectionStatus>[];
      client.status.listen(statuses.add);

      await client.connect();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await client.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(statuses, contains(McpConnectionStatus.connecting));
      expect(statuses, contains(McpConnectionStatus.connected));
      expect(statuses, contains(McpConnectionStatus.closed));
    });

    test('auto-reconnects when server closes the connection', () async {
      // Custom server where we control server-side WebSocket closure
      await server.close(force: true);

      WebSocket? firstWs;
      var phase = 0; // 0 = initial, 1 = reconnection

      server = await HttpServer.bind('127.0.0.1', port);
      server.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((ws) {
            if (phase == 0) {
              // Initial connection — store so we can close it
              firstWs = ws;
              ws.listen((_) {});
            } else {
              // Reconnected — respond with marker
              ws.listen((data) {
                if (data is String) {
                  try {
                    final parsed = jsonDecode(data) as Map<String, dynamic>;
                    final id = parsed['id'];
                    if (id != null) {
                      ws.add(
                        jsonEncode({
                          'jsonrpc': '2.0',
                          'id': id,
                          'result': {'reconnected': true},
                        }),
                      );
                    }
                  } catch (_) {}
                }
              });
            }
          });
        }
      });

      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        baseDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(milliseconds: 500),
        heartbeatTimeout: null,
      );

      final statuses = <McpConnectionStatus>[];
      final reconnected = Completer<void>();
      var sawDisconnect = false;
      client.status.listen((s) {
        statuses.add(s);
        if (s == McpConnectionStatus.disconnected) sawDisconnect = true;
        if (s == McpConnectionStatus.connected &&
            sawDisconnect &&
            !reconnected.isCompleted) {
          reconnected.complete();
        }
      });

      await client.connect();
      expect(client.isConnected, isTrue);

      // Switch to reconnection phase and close the WebSocket
      phase = 1;
      await firstWs!.close();

      // Wait for the client to reconnect to the same server
      await reconnected.future.timeout(const Duration(seconds: 10));

      expect(client.isConnected, isTrue);

      // Verify we can send a request after reconnection
      final response = await client.request('test');
      final result = response['result'] as Map<String, dynamic>;
      expect(result['reconnected'], isTrue);

      expect(statuses, contains(McpConnectionStatus.disconnected));
      expect(statuses, contains(McpConnectionStatus.reconnecting));

      await client.close();
    });

    test(
      'queues messages during disconnection and flushes on reconnect',
      () async {
        // Custom server where we control server-side WebSocket closure
        await server.close(force: true);

        WebSocket? firstWs;
        var phase = 0;

        server = await HttpServer.bind('127.0.0.1', port);
        server.listen((request) {
          if (request.uri.path == '/ws') {
            WebSocketTransformer.upgrade(request).then((ws) {
              if (phase == 0) {
                firstWs = ws;
                ws.listen((_) {});
              } else {
                ws.listen((data) {
                  if (data is String) {
                    try {
                      final parsed = jsonDecode(data) as Map<String, dynamic>;
                      final id = parsed['id'];
                      if (id != null) {
                        ws.add(
                          jsonEncode({
                            'jsonrpc': '2.0',
                            'id': id,
                            'result': {'flushed': true},
                          }),
                        );
                      }
                    } catch (_) {}
                  }
                });
              }
            });
          }
        });

        final client = McpWebSocketClient(
          Uri.parse('ws://127.0.0.1:$port/ws'),
          baseDelay: const Duration(milliseconds: 100),
          maxDelay: const Duration(milliseconds: 500),
          heartbeatTimeout: null,
        );

        await client.connect();

        // Switch to reconnection phase and close the WebSocket
        phase = 1;
        await firstWs!.close();

        // Small delay to let the client detect the disconnect
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Send a request while disconnected — it should be queued
        final responseFuture = client.request(
          'queued_request',
          timeout: const Duration(seconds: 15),
        );

        final response = await responseFuture;
        final result = response['result'] as Map<String, dynamic>;
        expect(result['flushed'], isTrue);

        await client.close();
      },
    );

    test('fails after max retries', () async {
      // Stop the server so connection always fails
      await server.close(force: true);

      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        maxRetries: 2,
        baseDelay: const Duration(milliseconds: 50),
        maxDelay: const Duration(milliseconds: 100),
        heartbeatTimeout: null,
      );

      // First connection should throw
      await expectLater(
        () => client.connect(),
        throwsA(isA<SocketException>()),
      );

      await client.close();
    });

    test('responds to server heartbeat pings with pong', () async {
      await server.close(force: true);

      // Start a server that sends pings and captures pong responses
      final pongReceived = Completer<bool>();

      server = await HttpServer.bind('127.0.0.1', port);
      server.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((ws) {
            // Send a ping immediately
            ws.add(jsonEncode({'jsonrpc': '2.0', 'method': 'ping'}));

            ws.listen((data) {
              if (data is String) {
                try {
                  final parsed = jsonDecode(data) as Map<String, dynamic>;
                  if (parsed['method'] == 'pong' && !pongReceived.isCompleted) {
                    pongReceived.complete(true);
                  }
                } catch (_) {}
              }
            });
          });
        }
      });

      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        heartbeatTimeout: null,
      );

      await client.connect();

      final gotPong = await pongReceived.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      expect(gotPong, isTrue);

      await client.close();
    });

    test('request times out when no response', () async {
      await server.close(force: true);

      // Start a server that never responds
      server = await HttpServer.bind('127.0.0.1', port);
      server.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((ws) {
            ws.listen((_) {
              // Intentionally don't respond
            });
          });
        }
      });

      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        heartbeatTimeout: null,
      );

      await client.connect();

      await expectLater(
        () =>
            client.request('test', timeout: const Duration(milliseconds: 500)),
        throwsA(isA<TimeoutException>()),
      );

      await client.close();
    });

    test('close completes pending requests with error', () async {
      await server.close(force: true);

      // Server that never responds
      server = await HttpServer.bind('127.0.0.1', port);
      server.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((ws) {
            ws.listen((_) {});
          });
        }
      });

      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        heartbeatTimeout: null,
      );

      await client.connect();

      final requestFuture = client.request(
        'never_responds',
        timeout: const Duration(seconds: 30),
      );

      // Set up the expectation BEFORE closing so the future error is caught
      final expectFuture = expectLater(
        requestFuture,
        throwsA(isA<StateError>()),
      );

      // Close while the request is pending
      await client.close();

      await expectFuture;
    });

    test('messages stream receives server notifications', () async {
      await server.close(force: true);

      // Server that sends a notification after connection
      server = await HttpServer.bind('127.0.0.1', port);
      server.listen((request) {
        if (request.uri.path == '/ws') {
          WebSocketTransformer.upgrade(request).then((ws) {
            // Send a server-initiated notification
            ws.add(
              jsonEncode({
                'jsonrpc': '2.0',
                'method': 'server/notification',
                'params': {'data': 'hello'},
              }),
            );

            ws.listen((_) {});
          });
        }
      });

      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        heartbeatTimeout: null,
      );

      final notificationCompleter = Completer<Map<String, dynamic>>();
      client.messages.listen((msg) {
        if (msg['method'] == 'server/notification' &&
            !notificationCompleter.isCompleted) {
          notificationCompleter.complete(msg);
        }
      });

      await client.connect();

      final notification = await notificationCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      expect(notification['method'], 'server/notification');
      final params = notification['params'] as Map<String, dynamic>;
      expect(params['data'], 'hello');

      await client.close();
    });

    test('sendRaw forwards raw JSON strings', () async {
      final client = McpWebSocketClient(
        Uri.parse('ws://127.0.0.1:$port/ws'),
        heartbeatTimeout: null,
      );

      await client.connect();

      final completer = Completer<Map<String, dynamic>>();
      client.messages.listen((msg) {
        if (msg['id'] == 99 && !completer.isCompleted) {
          completer.complete(msg);
        }
      });

      client.sendRaw(
        jsonEncode({'jsonrpc': '2.0', 'method': 'ping', 'id': 99}),
      );

      final response = await completer.future.timeout(
        const Duration(seconds: 5),
      );

      expect(response['id'], 99);

      await client.close();
    });
  });
}
