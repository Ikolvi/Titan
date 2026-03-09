import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// A WebSocket client for the Titan MCP server with auto-reconnect
/// and exponential backoff.
///
/// Connects to an MCP server running with `--transport ws` or
/// `--transport auto`, automatically reconnecting on disconnection:
///
/// ```dart
/// final client = McpWebSocketClient(
///   Uri.parse('ws://localhost:3001/ws'),
/// );
///
/// await client.connect();
///
/// // Send JSON-RPC requests
/// final response = await client.request('tools/list');
/// print(response);
///
/// // Listen for all incoming messages
/// client.messages.listen((msg) => print(msg));
///
/// await client.close();
/// ```
///
/// ## TLS / WSS
///
/// For TLS-secured connections, use a `wss://` URL:
///
/// ```dart
/// final client = McpWebSocketClient(
///   Uri.parse('wss://my-server.example.com:3001/ws'),
/// );
/// ```
///
/// For local development with self-signed certificates:
///
/// ```dart
/// final client = McpWebSocketClient(
///   Uri.parse('wss://localhost:3001/ws'),
///   trustSelfSigned: true, // DO NOT use in production
/// );
/// ```
///
/// ## Reconnection Strategy
///
/// On disconnect, the client waits with exponential backoff before
/// reconnecting. The delay doubles each attempt (with jitter) up to
/// [maxDelay]. After [maxRetries] consecutive failures, it stops.
///
/// ## Heartbeat
///
/// The server sends periodic `ping` notifications. The client responds
/// with a `pong` to keep the connection alive. If no ping is received
/// within [heartbeatTimeout], the client closes and reconnects.
class McpWebSocketClient {
  /// Creates an MCP WebSocket client targeting [url].
  ///
  /// - [maxRetries]: Max consecutive reconnect attempts (default: 10).
  /// - [baseDelay]: Initial delay before first retry (default: 500ms).
  /// - [maxDelay]: Maximum delay between retries (default: 30s).
  /// - [heartbeatTimeout]: Max time without a ping before reconnect
  ///   (default: 90s). Set to `null` to disable heartbeat monitoring.
  /// - [trustSelfSigned]: When `true`, accepts self-signed TLS certificates
  ///   for `wss://` connections. **Do not use in production.**
  McpWebSocketClient(
    this.url, {
    this.maxRetries = 10,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.heartbeatTimeout = const Duration(seconds: 90),
    this.trustSelfSigned = false,
  });

  /// The WebSocket URL to connect to.
  ///
  /// Use `ws://` for plain connections or `wss://` for TLS-secured
  /// connections (e.g., `wss://localhost:3001/ws`).
  final Uri url;

  /// Maximum number of consecutive reconnect attempts before giving up.
  final int maxRetries;

  /// Initial delay before the first retry attempt.
  final Duration baseDelay;

  /// Maximum delay between retry attempts (caps exponential backoff).
  final Duration maxDelay;

  /// If no heartbeat ping is received within this duration, the client
  /// reconnects. Set to `null` to disable heartbeat monitoring.
  final Duration? heartbeatTimeout;

  /// When `true`, accepts self-signed or untrusted TLS certificates
  /// for `wss://` connections. Useful for local development with
  /// self-signed certs. **Do not use in production.**
  final bool trustSelfSigned;

  WebSocket? _socket;
  int _retryCount = 0;
  int _nextId = 1;
  bool _closed = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<McpConnectionStatus>.broadcast();
  final _pendingRequests = <int, Completer<Map<String, dynamic>>>{};
  final _messageQueue = <String>[];

  /// Stream of all incoming JSON-RPC messages (responses, notifications).
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  /// Stream of connection status changes.
  Stream<McpConnectionStatus> get status => _statusController.stream;

  /// Whether the client is currently connected.
  bool get isConnected =>
      _socket != null && _socket!.readyState == WebSocket.open;

  /// Connects to the MCP server.
  ///
  /// Throws [WebSocketException] if the initial connection fails.
  /// Subsequent disconnects trigger automatic reconnection.
  Future<void> connect() async {
    _closed = false;
    await _connect();
  }

  /// Sends a JSON-RPC notification (no response expected).
  void notify(String method, [Map<String, dynamic>? params]) {
    final message = <String, dynamic>{'jsonrpc': '2.0', 'method': method};
    if (params != null) message['params'] = params;
    _send(jsonEncode(message));
  }

  /// Sends a JSON-RPC request and waits for the response.
  ///
  /// Returns the full JSON-RPC response object. Throws [TimeoutException]
  /// if no response is received within [timeout].
  Future<Map<String, dynamic>> request(
    String method, {
    Map<String, dynamic>? params,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final id = _nextId++;
    final message = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': method,
      'id': id,
    };
    if (params != null) message['params'] = params;

    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    _send(jsonEncode(message));

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException('MCP request "$method" timed out', timeout);
      },
    );
  }

  /// Sends a raw JSON-RPC message string.
  void sendRaw(String jsonRpcMessage) {
    _send(jsonRpcMessage);
  }

  /// Closes the connection and stops reconnection attempts.
  Future<void> close() async {
    _closed = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _messageQueue.clear();

    // Complete pending requests with an error
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('McpWebSocketClient closed'));
      }
    }
    _pendingRequests.clear();

    final socket = _socket;
    _socket = null;
    if (socket != null) {
      await socket.close();
    }
    _statusController.add(McpConnectionStatus.closed);
  }

  // ── Private ──

  Future<void> _connect() async {
    try {
      _statusController.add(McpConnectionStatus.connecting);

      if (trustSelfSigned && url.scheme == 'wss') {
        // Create a custom HttpClient that accepts self-signed certificates
        final httpClient = HttpClient()
          ..badCertificateCallback = (_, _, _) => true;
        _socket = await WebSocket.connect(
          url.toString(),
          customClient: httpClient,
        );
      } else {
        _socket = await WebSocket.connect(url.toString());
      }

      _retryCount = 0;
      _statusController.add(McpConnectionStatus.connected);
      _resetHeartbeat();

      // Flush queued messages
      for (final msg in _messageQueue) {
        _socket!.add(msg);
      }
      _messageQueue.clear();

      _socket!.listen(
        _onData,
        onDone: _onDisconnect,
        onError: (Object error) {
          _statusController.add(McpConnectionStatus.error);
          _onDisconnect();
        },
      );
    } catch (e) {
      _statusController.add(McpConnectionStatus.error);
      if (_retryCount == 0) {
        // First connection attempt — propagate the error
        rethrow;
      }
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    if (data is! String) return;

    _resetHeartbeat();

    try {
      final parsed = jsonDecode(data) as Map<String, dynamic>;

      // Handle server heartbeat pings
      if (parsed['method'] == 'ping') {
        // Respond with pong (notification, no id expected)
        _send(jsonEncode({'jsonrpc': '2.0', 'method': 'pong'}));
        return;
      }

      // Route responses to pending requests
      final id = parsed['id'];
      if (id != null && id is int && _pendingRequests.containsKey(id)) {
        final completer = _pendingRequests.remove(id)!;
        if (!completer.isCompleted) {
          completer.complete(parsed);
        }
        return;
      }

      // Broadcast to message stream
      _messageController.add(parsed);
    } catch (_) {
      // Ignore malformed messages
    }
  }

  void _onDisconnect() {
    _socket = null;
    _heartbeatTimer?.cancel();

    if (_closed) return;

    _statusController.add(McpConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_closed || _retryCount >= maxRetries) {
      _statusController.add(McpConnectionStatus.failed);
      // Complete pending requests with error
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('Reconnection failed after $maxRetries attempts'),
          );
        }
      }
      _pendingRequests.clear();
      return;
    }

    _retryCount++;
    final delay = _calculateDelay();
    _statusController.add(McpConnectionStatus.reconnecting);

    _reconnectTimer = Timer(delay, () async {
      if (!_closed) {
        await _connect();
      }
    });
  }

  Duration _calculateDelay() {
    // Exponential backoff: baseDelay * 2^(retryCount-1) with jitter
    final exponential = baseDelay.inMilliseconds * pow(2, _retryCount - 1);
    final capped = min(exponential.toInt(), maxDelay.inMilliseconds);
    // Add ±25% jitter to prevent thundering herd
    final jitter = (capped * 0.25 * (Random().nextDouble() * 2 - 1)).toInt();
    return Duration(milliseconds: capped + jitter);
  }

  void _send(String message) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(message);
    } else {
      // Queue messages while disconnected
      _messageQueue.add(message);
    }
  }

  void _resetHeartbeat() {
    _heartbeatTimer?.cancel();
    final timeout = heartbeatTimeout;
    if (timeout == null) return;

    _heartbeatTimer = Timer(timeout, () {
      // No heartbeat received — force reconnect
      _socket?.close();
    });
  }
}

/// Connection status for [McpWebSocketClient].
enum McpConnectionStatus {
  /// Attempting to connect.
  connecting,

  /// Successfully connected.
  connected,

  /// Connection lost, will attempt to reconnect.
  disconnected,

  /// Waiting before next reconnect attempt.
  reconnecting,

  /// A connection error occurred.
  error,

  /// Reconnection failed after max retries.
  failed,

  /// Client was explicitly closed.
  closed,
}
