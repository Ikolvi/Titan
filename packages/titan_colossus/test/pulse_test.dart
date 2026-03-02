import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Pulse — frame metrics
  // ---------------------------------------------------------

  group('Pulse', () {
    late Pulse pulse;

    setUp(() {
      pulse = Pulse();
    });

    // ---------------------------------------------------------
    // Initial state
    // ---------------------------------------------------------

    test('starts with zero metrics', () {
      expect(pulse.fps, 0.0);
      expect(pulse.totalFrames, 0);
      expect(pulse.jankFrames, 0);
      expect(pulse.jankRate, 0.0);
      expect(pulse.avgBuildTime, Duration.zero);
      expect(pulse.avgRasterTime, Duration.zero);
      expect(pulse.history, isEmpty);
    });

    // ---------------------------------------------------------
    // Frame recording
    // ---------------------------------------------------------

    test('records a frame and updates metrics', () {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );

      expect(pulse.totalFrames, 1);
      expect(pulse.history, hasLength(1));
      expect(pulse.jankFrames, 0);
      expect(pulse.avgBuildTime, const Duration(microseconds: 4000));
      expect(pulse.avgRasterTime, const Duration(microseconds: 3000));
    });

    test('detects jank frames over 16ms', () {
      pulse.recordFrame(
        buildDuration: const Duration(milliseconds: 12),
        rasterDuration: const Duration(milliseconds: 10),
        totalDuration: const Duration(milliseconds: 22),
      );

      expect(pulse.totalFrames, 1);
      expect(pulse.jankFrames, 1);
      expect(pulse.history.first.isJank, true);
    });

    test('computes jank rate correctly', () {
      // Record 9 smooth frames + 1 janky frame = 10% jank rate
      for (var i = 0; i < 9; i++) {
        pulse.recordFrame(
          buildDuration: const Duration(microseconds: 4000),
          rasterDuration: const Duration(microseconds: 3000),
          totalDuration: const Duration(microseconds: 7000),
        );
      }
      pulse.recordFrame(
        buildDuration: const Duration(milliseconds: 12),
        rasterDuration: const Duration(milliseconds: 10),
        totalDuration: const Duration(milliseconds: 22),
      );

      expect(pulse.totalFrames, 10);
      expect(pulse.jankFrames, 1);
      expect(pulse.jankRate, closeTo(10.0, 0.01));
    });

    test('computes rolling average build time', () {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 2000),
        rasterDuration: const Duration(microseconds: 1000),
        totalDuration: const Duration(microseconds: 3000),
      );
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 6000),
        rasterDuration: const Duration(microseconds: 5000),
        totalDuration: const Duration(microseconds: 11000),
      );

      // Average of 2000 and 6000 = 4000
      expect(pulse.avgBuildTime.inMicroseconds, 4000);
      // Average of 1000 and 5000 = 3000
      expect(pulse.avgRasterTime.inMicroseconds, 3000);
    });

    // ---------------------------------------------------------
    // History bounds
    // ---------------------------------------------------------

    test('respects maxHistory limit', () {
      final bounded = Pulse(maxHistory: 10);

      for (var i = 0; i < 20; i++) {
        bounded.recordFrame(
          buildDuration: const Duration(microseconds: 4000),
          rasterDuration: const Duration(microseconds: 3000),
          totalDuration: const Duration(microseconds: 7000),
        );
      }

      expect(bounded.history, hasLength(10));
      expect(bounded.totalFrames, 20);
    });

    // ---------------------------------------------------------
    // Callback
    // ---------------------------------------------------------

    test('calls onUpdate when a frame is recorded', () {
      var called = false;
      pulse.onUpdate = () => called = true;

      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );

      expect(called, true);
    });

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------

    test('reset clears all metrics', () {
      pulse.recordFrame(
        buildDuration: const Duration(milliseconds: 10),
        rasterDuration: const Duration(milliseconds: 10),
        totalDuration: const Duration(milliseconds: 20),
      );

      pulse.reset();

      expect(pulse.fps, 0.0);
      expect(pulse.totalFrames, 0);
      expect(pulse.jankFrames, 0);
      expect(pulse.history, isEmpty);
      expect(pulse.avgBuildTime, Duration.zero);
      expect(pulse.avgRasterTime, Duration.zero);
    });
  });
}
