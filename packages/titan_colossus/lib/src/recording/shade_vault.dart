import 'dart:convert';
import 'dart:io';

import 'imprint.dart';

// ---------------------------------------------------------------------------
// ShadeVault — Session Persistence
// ---------------------------------------------------------------------------

/// **ShadeVault** — saves and loads [ShadeSession]s to disk.
///
/// ShadeVault provides persistent storage for recorded sessions,
/// enabling auto-replay on restart and session library management.
///
/// ## Why "Vault"?
///
/// The Titan's vault preserves recordings across lifetimes, storing
/// them safely until the Phantom needs them again.
///
/// ## Usage
///
/// ```dart
/// final vault = ShadeVault('/path/to/app/shade_sessions');
///
/// // Save a session
/// await vault.save(session);
///
/// // List saved sessions
/// final sessions = await vault.list();
///
/// // Load a specific session
/// final loaded = await vault.load('session_id');
///
/// // Delete a session
/// await vault.delete('session_id');
/// ```
class ShadeVault {
  /// The directory path where sessions are stored.
  final String storagePath;

  /// Creates a [ShadeVault] that persists sessions to [storagePath].
  ShadeVault(this.storagePath);

  Directory get _directory => Directory(storagePath);

  /// Save a [ShadeSession] to disk.
  ///
  /// Returns the file path where the session was saved.
  ///
  /// ```dart
  /// final path = await vault.save(session);
  /// print('Saved to: $path');
  /// ```
  Future<String> save(ShadeSession session) async {
    await _ensureDirectory();
    final file = File(_sessionPath(session.id));
    await file.writeAsString(session.toJson());
    return file.path;
  }

  /// Load a [ShadeSession] by its ID.
  ///
  /// Returns `null` if the session file doesn't exist.
  ///
  /// ```dart
  /// final session = await vault.load('checkout_flow_1234');
  /// if (session != null) {
  ///   await phantom.replay(session);
  /// }
  /// ```
  Future<ShadeSession?> load(String sessionId) async {
    final file = File(_sessionPath(sessionId));
    if (!file.existsSync()) return null;
    final json = await file.readAsString();
    return ShadeSession.fromJson(json);
  }

  /// List all saved sessions (metadata only — no imprints loaded).
  ///
  /// Returns summaries sorted by recording date (newest first).
  ///
  /// ```dart
  /// final sessions = await vault.list();
  /// for (final summary in sessions) {
  ///   print('${summary.name}: ${summary.eventCount} events');
  /// }
  /// ```
  Future<List<ShadeSessionSummary>> list() async {
    if (!_directory.existsSync()) return [];

    final summaries = <ShadeSessionSummary>[];

    await for (final entity in _directory.list()) {
      if (entity is File && entity.path.endsWith('.shade.json')) {
        try {
          final json = await entity.readAsString();
          final map = jsonDecode(json) as Map<String, dynamic>;
          summaries.add(
            ShadeSessionSummary(
              id: map['id'] as String,
              name: map['name'] as String,
              recordedAt: DateTime.parse(map['recordedAt'] as String),
              durationMs: (map['durationUs'] as int) ~/ 1000,
              eventCount: map['eventCount'] as int,
              description: map['description'] as String?,
            ),
          );
        } on Object {
          // Skip malformed files
        }
      }
    }

    summaries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return summaries;
  }

  /// Delete a saved session by ID.
  ///
  /// Returns `true` if the file was deleted.
  Future<bool> delete(String sessionId) async {
    final file = File(_sessionPath(sessionId));
    if (file.existsSync()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Delete all saved sessions.
  ///
  /// Returns the number of sessions deleted.
  Future<int> deleteAll() async {
    if (!_directory.existsSync()) return 0;

    var count = 0;
    await for (final entity in _directory.list()) {
      if (entity is File && entity.path.endsWith('.shade.json')) {
        await entity.delete();
        count++;
      }
    }
    return count;
  }

  /// Whether a session with the given ID exists.
  Future<bool> exists(String sessionId) async {
    return File(_sessionPath(sessionId)).existsSync();
  }

  /// The number of saved sessions.
  Future<int> get count async {
    if (!_directory.existsSync()) return 0;

    var n = 0;
    await for (final entity in _directory.list()) {
      if (entity is File && entity.path.endsWith('.shade.json')) {
        n++;
      }
    }
    return n;
  }

  // -----------------------------------------------------------------------
  // Auto-replay configuration
  // -----------------------------------------------------------------------

  /// Save the auto-replay configuration.
  ///
  /// When [enabled] is true and [sessionId] is set, the next
  /// app launch will automatically replay the specified session.
  ///
  /// ```dart
  /// await vault.setAutoReplay(
  ///   enabled: true,
  ///   sessionId: session.id,
  ///   speed: 2.0,
  /// );
  /// ```
  Future<void> setAutoReplay({
    required bool enabled,
    String? sessionId,
    double speed = 1.0,
  }) async {
    await _ensureDirectory();
    final configFile = File('$storagePath/.shade_config.json');
    final config = <String, dynamic>{'autoReplay': enabled, 'speed': speed};
    if (sessionId != null) {
      config['sessionId'] = sessionId;
    }
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
    );
  }

  /// Load the auto-replay configuration.
  ///
  /// Returns `null` if no configuration exists.
  Future<ShadeAutoReplayConfig?> getAutoReplayConfig() async {
    final configFile = File('$storagePath/.shade_config.json');
    if (!configFile.existsSync()) return null;

    try {
      final json = await configFile.readAsString();
      final map = jsonDecode(json) as Map<String, dynamic>;
      return ShadeAutoReplayConfig(
        enabled: map['autoReplay'] as bool? ?? false,
        sessionId: map['sessionId'] as String?,
        speed: (map['speed'] as num?)?.toDouble() ?? 1.0,
      );
    } on Object {
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------------

  static final _safeIdPattern = RegExp(r'[^\w\-.]');

  String _sessionPath(String sessionId) {
    // Sanitize ID for filesystem safety
    final safeId = sessionId.replaceAll(_safeIdPattern, '_');
    return '$storagePath/$safeId.shade.json';
  }

  Future<void> _ensureDirectory() async {
    if (!_directory.existsSync()) {
      await _directory.create(recursive: true);
    }
  }
}

// ---------------------------------------------------------------------------
// ShadeSessionSummary — lightweight session metadata
// ---------------------------------------------------------------------------

/// Lightweight summary of a saved session (no imprint data loaded).
///
/// Used for listing sessions without loading the full event data.
class ShadeSessionSummary {
  /// The session ID.
  final String id;

  /// The session name.
  final String name;

  /// When the session was recorded.
  final DateTime recordedAt;

  /// Duration in milliseconds.
  final int durationMs;

  /// Number of events in the session.
  final int eventCount;

  /// Optional description.
  final String? description;

  /// Creates a [ShadeSessionSummary].
  const ShadeSessionSummary({
    required this.id,
    required this.name,
    required this.recordedAt,
    required this.durationMs,
    required this.eventCount,
    this.description,
  });

  @override
  String toString() =>
      'ShadeSessionSummary($name, $eventCount events, ${durationMs}ms)';
}

// ---------------------------------------------------------------------------
// ShadeAutoReplayConfig — auto-replay settings
// ---------------------------------------------------------------------------

/// Configuration for auto-replay on app restart.
class ShadeAutoReplayConfig {
  /// Whether auto-replay is enabled.
  final bool enabled;

  /// The session ID to replay on startup.
  final String? sessionId;

  /// The replay speed multiplier.
  final double speed;

  /// Creates a [ShadeAutoReplayConfig].
  const ShadeAutoReplayConfig({
    required this.enabled,
    this.sessionId,
    this.speed = 1.0,
  });

  @override
  String toString() =>
      'ShadeAutoReplayConfig(enabled=$enabled, '
      'session=$sessionId, speed=${speed}x)';
}
