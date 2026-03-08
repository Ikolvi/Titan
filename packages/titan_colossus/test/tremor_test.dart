import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Tremor — performance alerts
  // ---------------------------------------------------------

  group('Tremor', () {
    // ---------------------------------------------------------
    // Factory constructors
    // ---------------------------------------------------------

    test('Tremor.fps creates FPS alert with default threshold', () {
      final tremor = Tremor.fps();

      expect(tremor.name, 'fps_low');
      expect(tremor.severity, TremorSeverity.warning);
    });

    test('Tremor.fps creates FPS alert with custom threshold', () {
      final tremor = Tremor.fps(threshold: 50.0);

      expect(tremor.name, 'fps_low');
    });

    test('Tremor.jankRate creates jank rate alert', () {
      final tremor = Tremor.jankRate();

      expect(tremor.name, 'jank_rate');
      expect(tremor.severity, TremorSeverity.warning);
    });

    test('Tremor.pageLoad creates page load alert', () {
      final tremor = Tremor.pageLoad();

      expect(tremor.name, 'page_load_slow');
      expect(tremor.severity, TremorSeverity.warning);
    });

    test('Tremor.memory creates memory alert', () {
      final tremor = Tremor.memory();

      expect(tremor.name, 'memory_high');
      expect(tremor.severity, TremorSeverity.warning);
    });

    test('Tremor.rebuilds creates rebuild alert', () {
      final tremor = Tremor.rebuilds(threshold: 100, widget: 'MyWidget');

      expect(tremor.name, 'excessive_rebuilds');
      expect(tremor.severity, TremorSeverity.warning);
    });

    test('Tremor.leaks creates leak detection alert', () {
      final tremor = Tremor.leaks();

      expect(tremor.name, 'leak_detected');
      expect(tremor.severity, TremorSeverity.error);
    });

    // ---------------------------------------------------------
    // Evaluation
    // ---------------------------------------------------------

    test('evaluates FPS tremor correctly', () {
      final tremor = Tremor.fps(threshold: 55.0);

      // FPS above threshold → no alert
      final goodContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(goodContext), false);

      // FPS below threshold → alert
      final badContext = TremorContext(
        fps: 45.0,
        jankRate: 10.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(badContext), true);
    });

    test('evaluates page load tremor correctly', () {
      final tremor = Tremor.pageLoad(
        threshold: const Duration(milliseconds: 500),
      );

      // No page load → no alert
      final noLoadContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(noLoadContext), false);

      // Fast page load → no alert
      final fastContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: PageLoadMark(
          path: '/home',
          duration: const Duration(milliseconds: 200),
        ),
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(fastContext), false);

      // Slow page load → alert
      final slowContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: PageLoadMark(
          path: '/home',
          duration: const Duration(milliseconds: 800),
        ),
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(slowContext), true);
    });

    test('evaluates memory tremor correctly', () {
      final tremor = Tremor.memory(maxPillars: 20);

      final okContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 10,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(okContext), false);

      final highContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 25,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(highContext), true);
    });

    test('evaluates leak tremor correctly', () {
      final tremor = Tremor.leaks();

      final cleanContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(cleanContext), false);

      final leakyContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 5,
        leakSuspects: [
          LeakSuspect(typeName: 'Stale', firstSeen: DateTime.now()),
        ],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );
      expect(tremor.evaluate(leakyContext), true);
    });

    test('evaluates rebuild tremor correctly', () {
      final tremor = Tremor.rebuilds(threshold: 50, widget: 'Widget1');

      final okContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {'Widget1': 20, 'Widget2': 30},
      );
      expect(tremor.evaluate(okContext), false);

      final excessiveContext = TremorContext(
        fps: 60.0,
        jankRate: 0.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {'Widget1': 60, 'Widget2': 30},
      );
      expect(tremor.evaluate(excessiveContext), true);
    });

    // ---------------------------------------------------------
    // Once vs recurring mode
    // ---------------------------------------------------------

    test('once mode fires only once', () {
      final tremor = Tremor.fps(threshold: 55.0, once: true);

      final badContext = TremorContext(
        fps: 40.0,
        jankRate: 20.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );

      expect(tremor.evaluate(badContext), true);
      expect(tremor.evaluate(badContext), false); // Already fired
    });

    test('recurring mode fires every time', () {
      final tremor = Tremor.fps(threshold: 55.0, once: false);

      final badContext = TremorContext(
        fps: 40.0,
        jankRate: 20.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );

      expect(tremor.evaluate(badContext), true);
      expect(tremor.evaluate(badContext), true);
    });

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------

    test('reset allows once-mode tremor to fire again', () {
      final tremor = Tremor.fps(threshold: 55.0, once: true);

      final badContext = TremorContext(
        fps: 40.0,
        jankRate: 20.0,
        pillarCount: 3,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );

      expect(tremor.evaluate(badContext), true);
      expect(tremor.evaluate(badContext), false);
      tremor.reset();
      expect(tremor.evaluate(badContext), true);
    });
  });

  // ---------------------------------------------------------
  // TremorSeverity
  // ---------------------------------------------------------

  group('TremorSeverity', () {
    test('has three levels', () {
      expect(TremorSeverity.values, hasLength(3));
      expect(TremorSeverity.values, contains(TremorSeverity.info));
      expect(TremorSeverity.values, contains(TremorSeverity.warning));
      expect(TremorSeverity.values, contains(TremorSeverity.error));
    });
  });

  // ---------------------------------------------------------
  // ColossusTremor event
  // ---------------------------------------------------------

  group('ColossusTremor', () {
    test('creates a Herald event', () {
      final tremor = Tremor.fps();
      final event = ColossusTremor(
        tremor: tremor,
        message: 'FPS dropped to 40',
      );

      expect(event.tremor, tremor);
      expect(event.message, 'FPS dropped to 40');
    });

    test('toMap serializes correctly', () {
      final tremor = Tremor.fps(severity: TremorSeverity.error);
      final now = DateTime(2025, 1, 15, 12, 0, 0);
      final event = ColossusTremor(
        tremor: tremor,
        message: 'FPS dropped to 40',
        timestamp: now,
      );

      final map = event.toMap();

      expect(map['name'], 'fps_low');
      expect(map['category'], 'frame');
      expect(map['severity'], 'error');
      expect(map['message'], 'FPS dropped to 40');
      expect(map['timestamp'], now.toIso8601String());
    });
  });
}
