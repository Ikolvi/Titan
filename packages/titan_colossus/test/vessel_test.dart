import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';

// Test Pillar for leak detection
class _TestPillar extends Pillar {
  late final count = core(0);
}

void main() {
  setUp(() {
    Titan.reset();
  });

  tearDown(() {
    Titan.reset();
  });

  // ---------------------------------------------------------
  // Vessel — memory monitoring
  // ---------------------------------------------------------

  group('Vessel', () {
    late Vessel vessel;

    setUp(() {
      vessel = Vessel(
        checkInterval: const Duration(seconds: 10),
        leakThreshold: const Duration(seconds: 1),
      );
    });

    tearDown(() {
      vessel.dispose();
    });

    // ---------------------------------------------------------
    // Initial state
    // ---------------------------------------------------------

    test('starts with zero counts', () {
      expect(vessel.pillarCount, 0);
      expect(vessel.totalInstances, 0);
      expect(vessel.leakSuspects, isEmpty);
    });

    // ---------------------------------------------------------
    // Instance counting
    // ---------------------------------------------------------

    test('counts Pillar instances registered in Titan', () {
      final pillar = _TestPillar();
      Titan.put(pillar);

      // Manually trigger a check via snapshot
      final mark = vessel.snapshot();

      expect(mark.pillarCount, greaterThanOrEqualTo(1));
      expect(mark.totalInstances, greaterThanOrEqualTo(1));
    });

    // ---------------------------------------------------------
    // Exemption
    // ---------------------------------------------------------

    test('exempt adds type to exempt list', () {
      vessel.exempt('_TestPillar');
      expect(vessel.exemptTypes, contains('_TestPillar'));
    });

    // ---------------------------------------------------------
    // Snapshot
    // ---------------------------------------------------------

    test('snapshot returns a MemoryMark', () {
      final mark = vessel.snapshot();

      expect(mark, isA<MemoryMark>());
      expect(mark.category, MarkCategory.memory);
    });

    // ---------------------------------------------------------
    // Callback
    // ---------------------------------------------------------

    test('calls onUpdate when data changes', () {
      var callCount = 0;
      vessel.onUpdate = () => callCount++;

      // Start triggers initial check → callback
      vessel.start();

      expect(callCount, greaterThanOrEqualTo(1));
      vessel.stop();
    });

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------

    test('reset clears all tracking data', () {
      Titan.put(_TestPillar());
      vessel.snapshot(); // Populate data

      vessel.reset();

      expect(vessel.pillarCount, 0);
      expect(vessel.totalInstances, 0);
      expect(vessel.leakSuspects, isEmpty);
    });

    // ---------------------------------------------------------
    // Dispose
    // ---------------------------------------------------------

    test('dispose stops monitoring and resets', () {
      vessel.start();
      vessel.dispose();

      expect(vessel.pillarCount, 0);
      expect(vessel.totalInstances, 0);
      expect(vessel.leakSuspects, isEmpty);
    });
  });
}
