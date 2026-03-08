import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // ShadeVault — session persistence
  // ---------------------------------------------------------

  group('ShadeVault', () {
    late Directory tempDir;
    late ShadeVault vault;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('shade_vault_test_');
      vault = ShadeVault(tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    ShadeSession createSession({
      String id = 'test_id',
      String name = 'test_session',
      int eventCount = 3,
    }) {
      return ShadeSession(
        id: id,
        name: name,
        recordedAt: DateTime(2025, 6, 15, 10, 30),
        duration: const Duration(seconds: 5),
        screenWidth: 375.0,
        screenHeight: 812.0,
        devicePixelRatio: 3.0,
        description: 'A test session',
        imprints: List.generate(
          eventCount,
          (i) => Imprint(
            type: ImprintType.pointerDown,
            positionX: i * 10.0,
            positionY: i * 20.0,
            timestamp: Duration(milliseconds: i * 100),
          ),
        ),
      );
    }

    // ---------------------------------------------------------
    // Save & Load
    // ---------------------------------------------------------

    test('save creates a file and returns path', () async {
      final session = createSession();
      final path = await vault.save(session);

      expect(path, isNotEmpty);
      expect(File(path).existsSync(), true);
    });

    test('load returns saved session', () async {
      final session = createSession();
      await vault.save(session);

      final loaded = await vault.load('test_id');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'test_id');
      expect(loaded.name, 'test_session');
      expect(loaded.eventCount, 3);
      expect(loaded.description, 'A test session');
    });

    test('load returns null for non-existent session', () async {
      final loaded = await vault.load('non_existent');
      expect(loaded, isNull);
    });

    test('save overwrites existing session', () async {
      await vault.save(createSession(eventCount: 3));
      await vault.save(createSession(eventCount: 5));

      final loaded = await vault.load('test_id');
      expect(loaded!.eventCount, 5);
    });

    // ---------------------------------------------------------
    // List
    // ---------------------------------------------------------

    test('list returns empty for empty vault', () async {
      final sessions = await vault.list();
      expect(sessions, isEmpty);
    });

    test('list returns summaries for saved sessions', () async {
      await vault.save(createSession(id: 'a', name: 'session_a'));
      await vault.save(createSession(id: 'b', name: 'session_b'));

      final sessions = await vault.list();
      expect(sessions.length, 2);

      final names = sessions.map((s) => s.name).toSet();
      expect(names, containsAll(['session_a', 'session_b']));
    });

    test('list summaries contain correct metadata', () async {
      await vault.save(createSession(eventCount: 7));

      final sessions = await vault.list();
      expect(sessions.length, 1);

      final summary = sessions.first;
      expect(summary.id, 'test_id');
      expect(summary.name, 'test_session');
      expect(summary.eventCount, 7);
      expect(summary.description, 'A test session');
      expect(summary.durationMs, 5000);
    });

    // ---------------------------------------------------------
    // Delete
    // ---------------------------------------------------------

    test('delete removes a session', () async {
      await vault.save(createSession());
      expect(await vault.exists('test_id'), true);

      final deleted = await vault.delete('test_id');
      expect(deleted, true);
      expect(await vault.exists('test_id'), false);
    });

    test('delete returns false for non-existent session', () async {
      final deleted = await vault.delete('non_existent');
      expect(deleted, false);
    });

    test('deleteAll removes all sessions', () async {
      await vault.save(createSession(id: 'a'));
      await vault.save(createSession(id: 'b'));
      await vault.save(createSession(id: 'c'));

      final count = await vault.deleteAll();
      expect(count, 3);
      expect(await vault.count, 0);
    });

    test('deleteAll returns 0 for empty vault', () async {
      final count = await vault.deleteAll();
      expect(count, 0);
    });

    // ---------------------------------------------------------
    // Exists & Count
    // ---------------------------------------------------------

    test('exists returns true for saved session', () async {
      await vault.save(createSession());
      expect(await vault.exists('test_id'), true);
    });

    test('exists returns false for missing session', () async {
      expect(await vault.exists('missing'), false);
    });

    test('count returns number of sessions', () async {
      expect(await vault.count, 0);
      await vault.save(createSession(id: 'a'));
      expect(await vault.count, 1);
      await vault.save(createSession(id: 'b'));
      expect(await vault.count, 2);
    });

    // ---------------------------------------------------------
    // Auto-replay config
    // ---------------------------------------------------------

    test('setAutoReplay creates config file', () async {
      await vault.setAutoReplay(
        enabled: true,
        sessionId: 'login_flow',
        speed: 2.0,
      );

      final config = await vault.getAutoReplayConfig();
      expect(config, isNotNull);
      expect(config!.enabled, true);
      expect(config.sessionId, 'login_flow');
      expect(config.speed, 2.0);
    });

    test('setAutoReplay can disable', () async {
      await vault.setAutoReplay(enabled: true, sessionId: 'test');
      await vault.setAutoReplay(enabled: false);

      final config = await vault.getAutoReplayConfig();
      expect(config, isNotNull);
      expect(config!.enabled, false);
    });

    test('getAutoReplayConfig returns null when no config', () async {
      final config = await vault.getAutoReplayConfig();
      expect(config, isNull);
    });

    test('setAutoReplay defaults speed to 1.0', () async {
      await vault.setAutoReplay(enabled: true, sessionId: 's1');

      final config = await vault.getAutoReplayConfig();
      expect(config!.speed, 1.0);
    });

    // ---------------------------------------------------------
    // Path sanitization
    // ---------------------------------------------------------

    test('handles session IDs with special characters', () async {
      final session = createSession(id: 'test/id@with#special');
      await vault.save(session);

      final loaded = await vault.load('test/id@with#special');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'test/id@with#special');
    });
  });

  // ---------------------------------------------------------
  // ShadeSessionSummary
  // ---------------------------------------------------------

  group('ShadeSessionSummary', () {
    test('toString includes name, count, and duration', () {
      final summary = ShadeSessionSummary(
        id: 'test',
        name: 'login_flow',
        recordedAt: DateTime(2025, 1, 1),
        durationMs: 3500,
        eventCount: 42,
      );

      expect(summary.toString(), contains('login_flow'));
      expect(summary.toString(), contains('42'));
      expect(summary.toString(), contains('3500ms'));
    });

    test('toMap serializes all fields', () {
      final now = DateTime(2025, 1, 15, 12, 0, 0);
      final summary = ShadeSessionSummary(
        id: 'sess_123',
        name: 'checkout_flow',
        recordedAt: now,
        durationMs: 5000,
        eventCount: 75,
        description: 'Full checkout test',
      );

      final map = summary.toMap();

      expect(map['id'], 'sess_123');
      expect(map['name'], 'checkout_flow');
      expect(map['recordedAt'], now.toIso8601String());
      expect(map['durationMs'], 5000);
      expect(map['eventCount'], 75);
      expect(map['description'], 'Full checkout test');
    });

    test('toMap omits null description', () {
      final summary = ShadeSessionSummary(
        id: 'test',
        name: 'flow',
        recordedAt: DateTime(2025),
        durationMs: 100,
        eventCount: 5,
      );

      final map = summary.toMap();

      expect(map.containsKey('description'), false);
    });
  });

  // ---------------------------------------------------------
  // ShadeAutoReplayConfig
  // ---------------------------------------------------------

  group('ShadeAutoReplayConfig', () {
    test('toString includes all fields', () {
      const config = ShadeAutoReplayConfig(
        enabled: true,
        sessionId: 'checkout',
        speed: 2.5,
      );

      expect(config.toString(), contains('enabled=true'));
      expect(config.toString(), contains('checkout'));
      expect(config.toString(), contains('2.5x'));
    });

    test('defaults speed to 1.0', () {
      const config = ShadeAutoReplayConfig(enabled: false);
      expect(config.speed, 1.0);
    });

    test('sessionId defaults to null', () {
      const config = ShadeAutoReplayConfig(enabled: true);
      expect(config.sessionId, isNull);
    });
  });
}
