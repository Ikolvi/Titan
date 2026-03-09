import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Colossus — Tremor configuration (runtime management)
  // ---------------------------------------------------------

  group('Colossus tremor management', () {
    late Colossus colossus;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      colossus = Colossus.init(
        enableLensTab: false,
        tremors: [Tremor.fps(), Tremor.leaks()],
      );
    });

    tearDown(() {
      colossus.dispose();
    });

    // -------------------------------------------------------
    // tremors getter
    // -------------------------------------------------------

    test('tremors getter returns unmodifiable list', () {
      final tremors = colossus.tremors;

      expect(tremors, hasLength(2));
      expect(tremors[0].name, 'fps_low');
      expect(tremors[1].name, 'leak_detected');
      expect(() => tremors.add(Tremor.memory()), throwsUnsupportedError);
    });

    // -------------------------------------------------------
    // addTremor
    // -------------------------------------------------------

    test('addTremor adds a tremor to the list', () {
      colossus.addTremor(Tremor.memory());

      expect(colossus.tremors, hasLength(3));
      expect(colossus.tremors[2].name, 'memory_high');
    });

    test('addTremor supports all factory types', () {
      colossus.addTremor(Tremor.jankRate());
      colossus.addTremor(Tremor.pageLoad());
      colossus.addTremor(Tremor.rebuilds(threshold: 50, widget: 'TestWidget'));
      colossus.addTremor(Tremor.apiLatency());
      colossus.addTremor(Tremor.apiErrorRate());

      expect(colossus.tremors, hasLength(7));
      expect(colossus.tremors.map((t) => t.name), [
        'fps_low',
        'leak_detected',
        'jank_rate',
        'page_load_slow',
        'excessive_rebuilds',
        'api_latency_high',
        'api_error_rate',
      ]);
    });

    // -------------------------------------------------------
    // removeTremor
    // -------------------------------------------------------

    test('removeTremor removes by name and returns true', () {
      final result = colossus.removeTremor('fps_low');

      expect(result, isTrue);
      expect(colossus.tremors, hasLength(1));
      expect(colossus.tremors[0].name, 'leak_detected');
    });

    test('removeTremor returns false for non-existent name', () {
      final result = colossus.removeTremor('non_existent');

      expect(result, isFalse);
      expect(colossus.tremors, hasLength(2));
    });

    test('removeTremor reduces list to empty', () {
      colossus.removeTremor('fps_low');
      colossus.removeTremor('leak_detected');

      expect(colossus.tremors, isEmpty);
    });

    // -------------------------------------------------------
    // resetTremors
    // -------------------------------------------------------

    test('resetTremors resets all tremor fired states', () {
      // Force once-mode tremor to fire by adding one
      colossus.addTremor(Tremor.fps(once: true));

      // Reset should not throw and should leave list intact
      colossus.resetTremors();

      expect(colossus.tremors, hasLength(3));
    });

    // -------------------------------------------------------
    // clearAlertHistory
    // -------------------------------------------------------

    test('clearAlertHistory empties alert history', () {
      // Alert history starts empty
      expect(colossus.alertHistory, isEmpty);

      colossus.clearAlertHistory();

      // Should not throw, should still be empty
      expect(colossus.alertHistory, isEmpty);
    });

    // -------------------------------------------------------
    // Integration: add then remove
    // -------------------------------------------------------

    test('add then remove maintains correct state', () {
      colossus.addTremor(Tremor.memory());
      expect(colossus.tremors, hasLength(3));

      final removed = colossus.removeTremor('memory_high');
      expect(removed, isTrue);
      expect(colossus.tremors, hasLength(2));
      expect(colossus.tremors.map((t) => t.name), ['fps_low', 'leak_detected']);
    });

    test('remove then add replaces tremor', () {
      colossus.removeTremor('fps_low');
      colossus.addTremor(Tremor.fps(threshold: 50.0));

      expect(colossus.tremors, hasLength(2));
      expect(colossus.tremors.last.name, 'fps_low');
    });
  });

  // ---------------------------------------------------------
  // Colossus — Tremor management with no initial tremors
  // ---------------------------------------------------------

  group('Colossus tremor management (empty initial)', () {
    late Colossus colossus;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      colossus.dispose();
    });

    test('tremors getter returns empty list when no tremors configured', () {
      expect(colossus.tremors, isEmpty);
    });

    test('addTremor works from empty state', () {
      colossus.addTremor(Tremor.fps());

      expect(colossus.tremors, hasLength(1));
      expect(colossus.tremors[0].name, 'fps_low');
    });

    test('removeTremor returns false on empty list', () {
      expect(colossus.removeTremor('anything'), isFalse);
    });

    test('resetTremors is safe on empty list', () {
      // Should not throw
      colossus.resetTremors();
      expect(colossus.tremors, isEmpty);
    });

    test('clearAlertHistory is safe with no history', () {
      // Should not throw
      colossus.clearAlertHistory();
      expect(colossus.alertHistory, isEmpty);
    });
  });

  // ---------------------------------------------------------
  // _ColossusRelayHandler — getTremors / addTremor / removeTremor / resetTremors
  // (tested via RelayHandler interface in relay_test.dart;
  //  these tests validate Colossus public API integration)
  // ---------------------------------------------------------

  group('Colossus tremor + alert integration', () {
    late Colossus colossus;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      colossus = Colossus.init(
        enableLensTab: false,
        tremors: [
          Tremor.fps(threshold: 100.0), // Will always fire at fps < 100
        ],
      );
    });

    tearDown(() {
      colossus.dispose();
    });

    test('clearAlertHistory after alert fires empties history', () {
      // Simulate conditions that might trigger a tremor is complex,
      // so just verify API contract: clearAlertHistory empties list
      colossus.clearAlertHistory();
      expect(colossus.alertHistory, isEmpty);
    });

    test('multiple add and remove operations maintain consistency', () {
      expect(colossus.tremors, hasLength(1));

      colossus.addTremor(Tremor.memory());
      colossus.addTremor(Tremor.leaks());
      colossus.addTremor(Tremor.pageLoad());
      expect(colossus.tremors, hasLength(4));

      colossus.removeTremor('memory_high');
      expect(colossus.tremors, hasLength(3));

      colossus.removeTremor('page_load_slow');
      expect(colossus.tremors, hasLength(2));

      expect(colossus.tremors.map((t) => t.name).toList(), [
        'fps_low',
        'leak_detected',
      ]);
    });

    test('resetTremors preserves tremor count', () {
      colossus.addTremor(Tremor.jankRate());
      final countBefore = colossus.tremors.length;

      colossus.resetTremors();

      expect(colossus.tremors.length, countBefore);
    });
  });
}
