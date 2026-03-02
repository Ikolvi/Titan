import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Mark — base metric
  // ---------------------------------------------------------

  group('Mark', () {
    test('creates with required fields', () {
      final mark = Mark(
        name: 'test',
        category: MarkCategory.custom,
        duration: const Duration(milliseconds: 100),
      );

      expect(mark.name, 'test');
      expect(mark.category, MarkCategory.custom);
      expect(mark.duration.inMilliseconds, 100);
      expect(mark.timestamp, isA<DateTime>());
      expect(mark.metadata, isNull);
    });

    test('accepts optional timestamp and metadata', () {
      final ts = DateTime(2025, 1, 1);
      final mark = Mark(
        name: 'custom',
        category: MarkCategory.custom,
        duration: Duration.zero,
        timestamp: ts,
        metadata: {'key': 'value'},
      );

      expect(mark.timestamp, ts);
      expect(mark.metadata, {'key': 'value'});
    });

    test('toString includes name, category, and duration', () {
      final mark = Mark(
        name: 'api_call',
        category: MarkCategory.custom,
        duration: const Duration(microseconds: 500),
      );

      expect(mark.toString(), contains('api_call'));
      expect(mark.toString(), contains('500'));
    });
  });

  // ---------------------------------------------------------
  // FrameMark — frame timing
  // ---------------------------------------------------------

  group('FrameMark', () {
    test('computes isJank correctly', () {
      final smooth = FrameMark(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(milliseconds: 10),
      );
      expect(smooth.isJank, false);

      final janky = FrameMark(
        buildDuration: const Duration(milliseconds: 12),
        rasterDuration: const Duration(milliseconds: 10),
        totalDuration: const Duration(milliseconds: 22),
      );
      expect(janky.isJank, true);
      expect(janky.isSevereJank, false);
    });

    test('detects severe jank above 33ms', () {
      final severe = FrameMark(
        buildDuration: const Duration(milliseconds: 20),
        rasterDuration: const Duration(milliseconds: 20),
        totalDuration: const Duration(milliseconds: 40),
      );
      expect(severe.isSevereJank, true);
    });

    test('sets correct category and name', () {
      final frame = FrameMark(
        buildDuration: Duration.zero,
        rasterDuration: Duration.zero,
        totalDuration: Duration.zero,
      );
      expect(frame.category, MarkCategory.frame);
      expect(frame.name, 'frame');
    });
  });

  // ---------------------------------------------------------
  // PageLoadMark — page load timing
  // ---------------------------------------------------------

  group('PageLoadMark', () {
    test('creates with path and duration', () {
      final mark = PageLoadMark(
        path: '/quest/42',
        duration: const Duration(milliseconds: 120),
      );

      expect(mark.path, '/quest/42');
      expect(mark.duration.inMilliseconds, 120);
      expect(mark.pattern, isNull);
      expect(mark.category, MarkCategory.pageLoad);
    });

    test('includes pattern when provided', () {
      final mark = PageLoadMark(
        path: '/quest/42',
        duration: const Duration(milliseconds: 120),
        pattern: '/quest/:id',
      );

      expect(mark.pattern, '/quest/:id');
      expect(mark.metadata?['pattern'], '/quest/:id');
    });

    test('toString includes path and duration', () {
      final mark = PageLoadMark(
        path: '/home',
        duration: const Duration(milliseconds: 50),
      );
      expect(mark.toString(), contains('/home'));
      expect(mark.toString(), contains('50'));
    });
  });

  // ---------------------------------------------------------
  // RebuildMark — rebuild snapshot
  // ---------------------------------------------------------

  group('RebuildMark', () {
    test('captures label and count', () {
      final mark = RebuildMark(label: 'MyWidget', rebuildCount: 15);

      expect(mark.label, 'MyWidget');
      expect(mark.rebuildCount, 15);
      expect(mark.category, MarkCategory.rebuild);
      expect(mark.metadata?['label'], 'MyWidget');
      expect(mark.metadata?['count'], 15);
    });
  });

  // ---------------------------------------------------------
  // MemoryMark — memory snapshot
  // ---------------------------------------------------------

  group('MemoryMark', () {
    test('captures pillar count and instances', () {
      final mark = MemoryMark(pillarCount: 5, totalInstances: 12);

      expect(mark.pillarCount, 5);
      expect(mark.totalInstances, 12);
      expect(mark.leakSuspects, isEmpty);
      expect(mark.category, MarkCategory.memory);
    });

    test('includes leak suspects', () {
      final mark = MemoryMark(
        pillarCount: 3,
        totalInstances: 8,
        leakSuspects: ['AuthPillar', 'OldPillar'],
      );

      expect(mark.leakSuspects, hasLength(2));
      expect(mark.leakSuspects, contains('AuthPillar'));
    });
  });

  // ---------------------------------------------------------
  // LeakSuspect — suspected memory leak
  // ---------------------------------------------------------

  group('LeakSuspect', () {
    test('computes age from firstSeen', () {
      final suspect = LeakSuspect(
        typeName: 'StaleService',
        firstSeen: DateTime.now().subtract(const Duration(minutes: 3)),
      );

      expect(suspect.typeName, 'StaleService');
      expect(suspect.age.inMinutes, greaterThanOrEqualTo(2));
    });

    test('toString includes type and age', () {
      final suspect = LeakSuspect(
        typeName: 'LeakyPillar',
        firstSeen: DateTime.now().subtract(const Duration(seconds: 30)),
      );

      expect(suspect.toString(), contains('LeakyPillar'));
    });
  });

  // ---------------------------------------------------------
  // MarkCategory — enum values
  // ---------------------------------------------------------

  group('MarkCategory', () {
    test('has all expected categories', () {
      expect(MarkCategory.values, hasLength(5));
      expect(MarkCategory.values, contains(MarkCategory.frame));
      expect(MarkCategory.values, contains(MarkCategory.pageLoad));
      expect(MarkCategory.values, contains(MarkCategory.memory));
      expect(MarkCategory.values, contains(MarkCategory.rebuild));
      expect(MarkCategory.values, contains(MarkCategory.custom));
    });
  });
}
