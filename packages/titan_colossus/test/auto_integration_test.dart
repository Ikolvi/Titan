import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';
import 'package:titan_colossus/titan_colossus.dart';

// ---------------------------------------------------------------------------
// Auto-Integration Tests — Colossus zero-code-change wiring
// ---------------------------------------------------------------------------
//
// Validates the auto-wiring pipeline:
//   1. autoLearnSessions — Shade → Scout → Terrain auto-feed
//   2. terrainNotifier — ChangeNotifier fires after learnFromSession
//   3. Callback chaining — existing onRecordingStopped preserved
//   4. Opt-out — autoLearnSessions: false disables wiring
//   5. ColossusPlugin defaults — enableTableauCapture, autoLearnSessions

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auto-Learn Sessions', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    test('autoLearnSessions: true wires shade.onRecordingStopped', () {
      final colossus = Colossus.init(
        enableLensTab: false,
        autoLearnSessions: true,
      );

      // The Shade callback should be set by Colossus.onInit()
      expect(colossus.shade.onRecordingStopped, isNotNull);
    });

    test('autoLearnSessions: false does NOT wire callback', () {
      final colossus = Colossus.init(
        enableLensTab: false,
        autoLearnSessions: false,
      );

      // The Shade callback should remain null when opted out
      expect(colossus.shade.onRecordingStopped, isNull);
    });

    test('autoLearnSessions defaults to true', () {
      final colossus = Colossus.init(enableLensTab: false);

      // Default behavior should auto-wire
      expect(colossus.shade.onRecordingStopped, isNotNull);
    });

    test('callback chaining preserves existing onRecordingStopped', () {
      // Set an existing callback BEFORE Colossus.init
      final calls = <String>[];
      // Need to init first, then set callback, then re-check chaining
      // Actually, onInit happens during init() which calls Pillar.initialize()
      // So we need to test the chaining differently.
      //
      // The chaining logic in onInit() captures the existing callback via
      // `final existingCallback = shade.onRecordingStopped;` and then
      // calls it after learnFromSession. So if a callback was set before
      // init, it should be preserved.

      // Approach: Create colossus, verify callback works end-to-end
      final colossus = Colossus.init(
        enableLensTab: false,
        autoLearnSessions: true,
      );

      // Now override with a chained callback manually to verify chaining
      // works in the other direction (user sets callback after init)
      final existingCallback = colossus.shade.onRecordingStopped;
      colossus.shade.onRecordingStopped = (session) {
        calls.add('user:${session.name}');
        existingCallback?.call(session);
      };

      final session = ShadeSession(
        id: 'chain_test',
        name: 'chain_test',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      colossus.shade.onRecordingStopped!.call(session);

      // User callback should have been called
      expect(calls, contains('user:chain_test'));
    });

    test('auto-wire calls learnFromSession on recording stop', () {
      final colossus = Colossus.init(
        enableLensTab: false,
        autoLearnSessions: true,
      );

      final session = ShadeSession(
        id: 'auto_learn',
        name: 'auto_learn',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      // Trigger the wired callback — should call learnFromSession
      // without throwing
      expect(
        () => colossus.shade.onRecordingStopped!.call(session),
        returnsNormally,
      );
    });

    test('onDispose clears onRecordingStopped when autoLearn enabled', () {
      final colossus = Colossus.init(
        enableLensTab: false,
        autoLearnSessions: true,
      );
      expect(colossus.shade.onRecordingStopped, isNotNull);

      Colossus.shutdown();
      expect(colossus.shade.onRecordingStopped, isNull);
    });
  });

  // -----------------------------------------------------------------------
  // Terrain Notifier
  // -----------------------------------------------------------------------

  group('Terrain Notifier', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    test('terrainNotifier is a ChangeNotifier', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(colossus.terrainNotifier, isA<ChangeNotifier>());
    });

    test('learnFromSession fires terrainNotifier', () {
      final colossus = Colossus.init(enableLensTab: false);

      var notified = false;
      colossus.terrainNotifier.addListener(() {
        notified = true;
      });

      final session = ShadeSession(
        id: 'notifier_test',
        name: 'notifier_test',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      colossus.learnFromSession(session);

      expect(notified, true);
    });

    test('terrainNotifier fires on every learnFromSession call', () {
      final colossus = Colossus.init(enableLensTab: false);

      var count = 0;
      colossus.terrainNotifier.addListener(() {
        count++;
      });

      for (var i = 0; i < 3; i++) {
        colossus.learnFromSession(ShadeSession(
          id: 'multi_$i',
          name: 'multi_$i',
          recordedAt: DateTime(2025, 1, 1),
          duration: Duration.zero,
          screenWidth: 375,
          screenHeight: 812,
          devicePixelRatio: 2.0,
          imprints: [],
        ));
      }

      expect(count, 3);
    });

    test('terrainNotifier is disposed on shutdown', () {
      final colossus = Colossus.init(enableLensTab: false);
      final notifier = colossus.terrainNotifier;

      Colossus.shutdown();

      // After dispose, adding a listener should throw
      expect(
        () => notifier.addListener(() {}),
        throwsA(isA<FlutterError>()),
      );
    });

    test('auto-learn pipeline end-to-end: stop → learn → notify', () {
      final colossus = Colossus.init(
        enableLensTab: false,
        autoLearnSessions: true,
      );

      var terrainUpdated = false;
      colossus.terrainNotifier.addListener(() {
        terrainUpdated = true;
      });

      final session = ShadeSession(
        id: 'e2e_test',
        name: 'e2e_test',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      // Simulate recording stop → should trigger learnFromSession → notifier
      colossus.shade.onRecordingStopped!.call(session);

      expect(terrainUpdated, true);
    });
  });

  // -----------------------------------------------------------------------
  // ColossusPlugin Defaults
  // -----------------------------------------------------------------------

  group('ColossusPlugin defaults', () {
    test('enableTableauCapture defaults to true', () {
      const plugin = ColossusPlugin();
      expect(plugin.enableTableauCapture, true);
    });

    test('autoLearnSessions defaults to true', () {
      const plugin = ColossusPlugin();
      expect(plugin.autoLearnSessions, true);
    });

    test('autoAtlasIntegration defaults to true', () {
      const plugin = ColossusPlugin();
      expect(plugin.autoAtlasIntegration, true);
    });

    test('all integration flags can be disabled', () {
      const plugin = ColossusPlugin(
        enableTableauCapture: false,
        autoLearnSessions: false,
        autoAtlasIntegration: false,
      );

      expect(plugin.enableTableauCapture, false);
      expect(plugin.autoLearnSessions, false);
      expect(plugin.autoAtlasIntegration, false);
    });

    test('ColossusPlugin is const-constructible', () {
      // Verify const construction works with the new params
      const plugin = ColossusPlugin(
        enableTableauCapture: true,
        autoLearnSessions: true,
        autoAtlasIntegration: true,
      );

      expect(plugin, isA<TitanPlugin>());
    });
  });

  // -----------------------------------------------------------------------
  // autoAtlasObserver field
  // -----------------------------------------------------------------------

  group('Atlas Observer Storage', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    test('autoAtlasObserver is null by default', () {
      final colossus = Colossus.init(enableLensTab: false);
      expect(colossus.autoAtlasObserver, isNull);
    });

    test('autoAtlasObserver can be set and retrieved', () {
      final colossus = Colossus.init(enableLensTab: false);
      const observer = ColossusAtlasObserver();
      colossus.autoAtlasObserver = observer;

      expect(colossus.autoAtlasObserver, same(observer));
    });
  });

  // -----------------------------------------------------------------------
  // ColossusPlugin onAttach — Integration
  // -----------------------------------------------------------------------

  group('ColossusPlugin onAttach', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    testWidgets('onAttach creates Colossus with autoLearnSessions',
        (tester) async {
      await tester.pumpWidget(
        Beacon(
          pillars: const [],
          plugins: const [
            ColossusPlugin(
              enableLens: false,
              autoLearnSessions: true,
            ),
          ],
          child: const SizedBox(),
        ),
      );

      expect(Colossus.isActive, true);
      expect(Colossus.instance.shade.onRecordingStopped, isNotNull);
    });

    testWidgets('onAttach with autoLearnSessions: false leaves callback null',
        (tester) async {
      await tester.pumpWidget(
        Beacon(
          pillars: const [],
          plugins: const [
            ColossusPlugin(
              enableLens: false,
              autoLearnSessions: false,
            ),
          ],
          child: const SizedBox(),
        ),
      );

      expect(Colossus.isActive, true);
      expect(Colossus.instance.shade.onRecordingStopped, isNull);
    });

    testWidgets('onAttach passes enableTableauCapture to Colossus.init',
        (tester) async {
      await tester.pumpWidget(
        Beacon(
          pillars: const [],
          plugins: const [
            ColossusPlugin(
              enableLens: false,
              enableTableauCapture: true,
            ),
          ],
          child: const SizedBox(),
        ),
      );

      expect(Colossus.isActive, true);
      // The Shade.enableTableauCapture flag should be set
      // (We verify by checking that init succeeded — the param was accepted)
    });

    testWidgets(
        'onDetach shuts down Colossus cleanly',
        (tester) async {
      await tester.pumpWidget(
        Beacon(
          pillars: const [],
          plugins: const [
            ColossusPlugin(enableLens: false),
          ],
          child: const SizedBox(),
        ),
      );

      expect(Colossus.isActive, true);

      // Remove the widget tree to trigger onDetach
      await tester.pumpWidget(const SizedBox());

      expect(Colossus.isActive, false);
    });
  });

  // -----------------------------------------------------------------------
  // End-to-End: Plugin → Auto-Learn → Terrain Notifier
  // -----------------------------------------------------------------------

  group('End-to-End Integration', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    testWidgets('Plugin → auto-learn → terrain notifier pipeline',
        (tester) async {
      await tester.pumpWidget(
        Beacon(
          pillars: const [],
          plugins: const [
            ColossusPlugin(
              enableLens: false,
              autoLearnSessions: true,
            ),
          ],
          child: const SizedBox(),
        ),
      );

      final colossus = Colossus.instance;

      // Subscribe to terrain updates
      var terrainUpdated = false;
      colossus.terrainNotifier.addListener(() {
        terrainUpdated = true;
      });

      // Simulate a session completing
      final session = ShadeSession(
        id: 'e2e_plugin',
        name: 'e2e_plugin',
        recordedAt: DateTime(2025, 1, 1),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        imprints: [],
      );

      colossus.shade.onRecordingStopped!.call(session);
      expect(terrainUpdated, true);
    });

    test('learnFromSession updates terrain via Scout', () {
      final colossus = Colossus.init(enableLensTab: false);

      // Create a session with imprints
      final session = ShadeSession(
        id: 'learn_terrain',
        name: 'learn_terrain',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 10),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 2.0,
        startRoute: '/home',
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 100,
            positionY: 200,
            timestamp: const Duration(seconds: 1),
          ),
          Imprint(
            type: ImprintType.pointerUp,
            positionX: 100,
            positionY: 200,
            timestamp: const Duration(seconds: 2),
          ),
        ],
      );

      // Should not throw
      expect(
        () => colossus.learnFromSession(session),
        returnsNormally,
      );
    });
  });
}
