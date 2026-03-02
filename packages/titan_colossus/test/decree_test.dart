import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Decree — performance report
  // ---------------------------------------------------------

  group('Decree', () {
    // ---------------------------------------------------------
    // Construction
    // ---------------------------------------------------------

    test('creates with all metrics', () {
      final decree = Decree(
        sessionStart: DateTime(2025, 1, 1),
        totalFrames: 1000,
        jankFrames: 50,
        avgFps: 58.5,
        avgBuildTime: const Duration(microseconds: 4200),
        avgRasterTime: const Duration(microseconds: 3100),
        pageLoads: [
          PageLoadMark(
            path: '/home',
            duration: const Duration(milliseconds: 120),
          ),
        ],
        pillarCount: 5,
        totalInstances: 12,
        leakSuspects: [],
        rebuildsPerWidget: {'Widget1': 30, 'Widget2': 60},
      );

      expect(decree.totalFrames, 1000);
      expect(decree.jankFrames, 50);
      expect(decree.avgFps, 58.5);
      expect(decree.pageLoads, hasLength(1));
      expect(decree.pillarCount, 5);
      expect(decree.rebuildsPerWidget, hasLength(2));
    });

    // ---------------------------------------------------------
    // Jank rate
    // ---------------------------------------------------------

    test('computes jank rate correctly', () {
      final decree = Decree(
        sessionStart: DateTime.now(),
        totalFrames: 200,
        jankFrames: 10,
        avgFps: 55.0,
        avgBuildTime: Duration.zero,
        avgRasterTime: Duration.zero,
        pageLoads: [],
        pillarCount: 0,
        totalInstances: 0,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );

      expect(decree.jankRate, closeTo(5.0, 0.01));
    });

    test('handles zero frames for jank rate', () {
      final decree = Decree(
        sessionStart: DateTime.now(),
        totalFrames: 0,
        jankFrames: 0,
        avgFps: 0.0,
        avgBuildTime: Duration.zero,
        avgRasterTime: Duration.zero,
        pageLoads: [],
        pillarCount: 0,
        totalInstances: 0,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );

      expect(decree.jankRate, 0.0);
    });

    // ---------------------------------------------------------
    // Health verdict
    // ---------------------------------------------------------

    test('reports good health for smooth performance', () {
      final decree = Decree(
        sessionStart: DateTime.now(),
        totalFrames: 1000,
        jankFrames: 10, // 1% jank
        avgFps: 59.5,
        avgBuildTime: const Duration(microseconds: 4000),
        avgRasterTime: const Duration(microseconds: 3000),
        pageLoads: [],
        pillarCount: 5,
        totalInstances: 10,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );

      expect(decree.health, PerformanceHealth.good);
    });

    test('reports poor health for bad performance', () {
      final decree = Decree(
        sessionStart: DateTime.now(),
        totalFrames: 100,
        jankFrames: 30, // 30% jank
        avgFps: 25.0,
        avgBuildTime: const Duration(milliseconds: 20),
        avgRasterTime: const Duration(milliseconds: 15),
        pageLoads: [],
        pillarCount: 50,
        totalInstances: 100,
        leakSuspects: [LeakSuspect(typeName: 'A', firstSeen: DateTime.now())],
        rebuildsPerWidget: {},
      );

      expect(decree.health, PerformanceHealth.poor);
    });

    // ---------------------------------------------------------
    // Top rebuilders
    // ---------------------------------------------------------

    test('topRebuilders returns sorted by count', () {
      final decree = Decree(
        sessionStart: DateTime.now(),
        totalFrames: 100,
        jankFrames: 0,
        avgFps: 60.0,
        avgBuildTime: Duration.zero,
        avgRasterTime: Duration.zero,
        pageLoads: [],
        pillarCount: 0,
        totalInstances: 0,
        leakSuspects: [],
        rebuildsPerWidget: {'A': 10, 'B': 50, 'C': 30},
      );

      final top = decree.topRebuilders(2);
      expect(top, hasLength(2));
      expect(top.first.key, 'B');
      expect(top.last.key, 'C');
    });

    // ---------------------------------------------------------
    // Slowest page load
    // ---------------------------------------------------------

    test('slowestPageLoad returns the slowest', () {
      final decree = Decree(
        sessionStart: DateTime.now(),
        totalFrames: 100,
        jankFrames: 0,
        avgFps: 60.0,
        avgBuildTime: Duration.zero,
        avgRasterTime: Duration.zero,
        pageLoads: [
          PageLoadMark(
            path: '/fast',
            duration: const Duration(milliseconds: 50),
          ),
          PageLoadMark(
            path: '/slow',
            duration: const Duration(milliseconds: 800),
          ),
          PageLoadMark(
            path: '/medium',
            duration: const Duration(milliseconds: 200),
          ),
        ],
        pillarCount: 0,
        totalInstances: 0,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );

      expect(decree.slowestPageLoad, isNotNull);
      expect(decree.slowestPageLoad!.path, '/slow');
    });

    test('slowestPageLoad returns null when empty', () {
      final decree = Decree(
        sessionStart: DateTime.now(),
        totalFrames: 100,
        jankFrames: 0,
        avgFps: 60.0,
        avgBuildTime: Duration.zero,
        avgRasterTime: Duration.zero,
        pageLoads: [],
        pillarCount: 0,
        totalInstances: 0,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );

      expect(decree.slowestPageLoad, isNull);
    });

    // ---------------------------------------------------------
    // Summary
    // ---------------------------------------------------------

    test('summary produces readable output', () {
      final decree = Decree(
        sessionStart: DateTime(2025, 6, 15, 10, 0),
        totalFrames: 500,
        jankFrames: 25,
        avgFps: 56.0,
        avgBuildTime: const Duration(microseconds: 5000),
        avgRasterTime: const Duration(microseconds: 4000),
        pageLoads: [
          PageLoadMark(
            path: '/home',
            duration: const Duration(milliseconds: 120),
          ),
        ],
        pillarCount: 8,
        totalInstances: 20,
        leakSuspects: [],
        rebuildsPerWidget: {'MyWidget': 42},
      );

      final summary = decree.summary;

      expect(summary, contains('Colossus Performance Decree'));
      expect(summary, contains('Pulse'));
      expect(summary, contains('Stride'));
      expect(summary, contains('Vessel'));
      expect(summary, contains('Echo'));
    });
  });

  // ---------------------------------------------------------
  // PerformanceHealth enum
  // ---------------------------------------------------------

  group('PerformanceHealth', () {
    test('has three values', () {
      expect(PerformanceHealth.values, hasLength(3));
      expect(PerformanceHealth.values, contains(PerformanceHealth.good));
      expect(PerformanceHealth.values, contains(PerformanceHealth.fair));
      expect(PerformanceHealth.values, contains(PerformanceHealth.poor));
    });
  });
}
