// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';

// =============================================================================
// Colossus Benchmark Tracker
// =============================================================================
//
// Run with:
//   cd packages/titan_colossus && flutter test benchmark/benchmark_track.dart
//
// Unified benchmark runner that:
//   1. Runs all 26 Colossus benchmarks (monitor + recording + export + overhead)
//   2. Saves results to benchmark/results/
//   3. Compares against previous run and flags regressions
//
// =============================================================================

final _results = <String, _BenchResult>{};
var _isWarmup = false;

void main() {
  test('Colossus Benchmark Tracker', () {
    const samples = 3;
    const threshold = 10.0;
    const noiseFloor = 0.100;

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  COLOSSUS BENCHMARK TRACKER');
    print('═══════════════════════════════════════════════════════');
    print('');

    // JIT Warmup: run all benchmarks once without recording
    print('── Warmup ─────────────────────────────────────────────');
    final warmupSw = Stopwatch()..start();
    _isWarmup = true;
    _runMonitorBenchmarks();
    _runRecordingBenchmarks();
    _runExportBenchmarks();
    _runOverheadBenchmarks();
    _isWarmup = false;
    _results.clear();
    warmupSw.stop();
    print('   ✓ Warmup complete (${warmupSw.elapsedMilliseconds}ms)');
    print('');

    // Multi-sample collection
    final allSamples = <String, List<_BenchResult>>{};

    print('── Benchmarks ─────────────────────────────────────────');
    for (var sample = 0; sample < samples; sample++) {
      _results.clear();
      _runMonitorBenchmarks();
      _runRecordingBenchmarks();
      _runExportBenchmarks();
      _runOverheadBenchmarks();
      for (final entry in _results.entries) {
        allSamples.putIfAbsent(entry.key, () => []).add(entry.value);
      }
      print('   ✓ Sample ${sample + 1}/$samples collected');
    }

    // Take medians
    _results.clear();
    for (final entry in allSamples.entries) {
      final values = entry.value.map((r) => r.value).toList()..sort();
      final mid = values.length ~/ 2;
      final median = values.length.isOdd
          ? values[mid]
          : (values[mid - 1] + values[mid]) / 2;
      _results[entry.key] = _BenchResult(
        value: median,
        unit: entry.value.first.unit,
        suite: entry.value.first.suite,
      );
    }

    print('   ✓ Medians computed from $samples samples');
    print('');

    // Load version from pubspec
    final version = _readVersion();

    // Build result payload
    final payload = {
      'version': version,
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'dartVersion': Platform.version.split(' ').first,
      'benchmarks': _results.map(
        (k, v) =>
            MapEntry(k, {'value': v.value, 'unit': v.unit, 'suite': v.suite}),
      ),
    };

    // Load previous results for comparison
    Map<String, dynamic>? previous;
    final latestFile = File('benchmark/results/latest.json');
    if (latestFile.existsSync()) {
      previous =
          jsonDecode(latestFile.readAsStringSync()) as Map<String, dynamic>;
    }

    // Print comparison report
    _printReport(previous, threshold, noiseFloor);

    // Save results
    final resultsDir = Directory('benchmark/results');
    final historyDir = Directory('benchmark/results/history');
    if (!resultsDir.existsSync()) resultsDir.createSync(recursive: true);
    if (!historyDir.existsSync()) historyDir.createSync(recursive: true);

    final jsonOutput = const JsonEncoder.withIndent('  ').convert(payload);

    File('benchmark/results/latest.json').writeAsStringSync(jsonOutput);

    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    File(
      'benchmark/results/history/${version}_$ts.json',
    ).writeAsStringSync(jsonOutput);

    print('');
    print('📁 Results saved:');
    print('   benchmark/results/latest.json');
    print('   benchmark/results/history/${version}_$ts.json');

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  TRACKING COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

// =============================================================================
// Monitor Benchmarks (1–8)
// =============================================================================

void _runMonitorBenchmarks() {
  // 1. Pulse.recordFrame()
  {
    final pulse = Pulse(maxHistory: 300);
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    sw.stop();
    _record(
      'Pulse recordFrame (100K)',
      sw.elapsedMicroseconds / count,
      'µs/frame',
      'monitor',
    );
  }

  // 2. Pulse steady-state (full history, rolling average)
  {
    final pulse = Pulse(maxHistory: 300);
    for (var i = 0; i < 300; i++) {
      pulse.recordFrame(
        buildDuration: Duration(microseconds: 3000 + (i % 5) * 1000),
        rasterDuration: Duration(microseconds: 2000 + (i % 3) * 500),
        totalDuration: Duration(microseconds: 5000 + (i % 5) * 1500),
      );
    }
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    sw.stop();
    _record(
      'Pulse Steady-State (100K)',
      sw.elapsedMicroseconds / count,
      'µs/frame',
      'monitor',
    );
  }

  // 3. FrameMark creation + isJank
  {
    const count = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final frame = FrameMark(
        buildDuration: Duration(microseconds: 4000 + (i % 20) * 1000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: Duration(microseconds: 7000 + (i % 20) * 1500),
      );
      frame.isJank;
    }
    sw.stop();
    _record(
      'FrameMark Create+Jank (1M)',
      sw.elapsedMicroseconds / count,
      'µs/mark',
      'monitor',
    );
  }

  // 4. Stride.record()
  {
    final stride = Stride(maxHistory: 100);
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      stride.record(
        '/page/$i',
        Duration(milliseconds: 50 + (i % 200)),
        pattern: '/page/:id',
      );
    }
    sw.stop();
    _record(
      'Stride record (100K)',
      sw.elapsedMicroseconds / count,
      'µs/record',
      'monitor',
    );
  }

  // 5. Stride.avgPageLoad
  {
    final stride = Stride(maxHistory: 100);
    for (var i = 0; i < 100; i++) {
      stride.record('/page/$i', Duration(milliseconds: 50 + (i % 200)));
    }
    const reads = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < reads; i++) {
      stride.avgPageLoad;
    }
    sw.stop();
    _record(
      'Stride avgPageLoad (100K)',
      sw.elapsedMicroseconds / reads,
      'µs/read',
      'monitor',
    );
  }

  // 6. Tremor.evaluate() batch
  {
    final tremors = [
      Tremor.fps(threshold: 50),
      Tremor.jankRate(threshold: 5),
      Tremor.pageLoad(threshold: const Duration(seconds: 1)),
      Tremor.memory(maxPillars: 50),
      Tremor.rebuilds(threshold: 100, widget: 'HeroCard'),
      Tremor.leaks(),
    ];
    final context = TremorContext(
      fps: 58.0,
      jankRate: 3.2,
      pillarCount: 12,
      leakSuspects: const [],
      lastPageLoad: PageLoadMark(
        path: '/home',
        duration: const Duration(milliseconds: 200),
      ),
      rebuildsPerWidget: {'HeroCard': 45, 'QuestList': 22},
    );
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      for (final tremor in tremors) {
        tremor.evaluate(context);
        tremor.reset();
      }
    }
    sw.stop();
    _record(
      'Tremor Evaluate (6x1M)',
      sw.elapsedMicroseconds / (iterations * tremors.length),
      'µs/eval',
      'monitor',
    );
  }

  // 7. recordRebuild (Echo hot path)
  {
    final rebuildsPerWidget = <String, int>{};
    final labels = List.generate(50, (i) => 'Widget_$i');
    const iterations = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      final label = labels[i % labels.length];
      rebuildsPerWidget[label] = (rebuildsPerWidget[label] ?? 0) + 1;
    }
    sw.stop();
    _record(
      'recordRebuild (1M, 50 widgets)',
      iterations / sw.elapsedMicroseconds * 1e6,
      'rebuilds/sec',
      'monitor',
    );
  }

  // 8. Vessel snapshot
  {
    Titan.reset();
    final p = _BenchPillar();
    Titan.put<_BenchPillar>(p);

    final vessel = Vessel(checkInterval: const Duration(hours: 1));
    const snapshots = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < snapshots; i++) {
      vessel.snapshot();
    }
    sw.stop();
    _record(
      'Vessel Snapshot (1 pillar)',
      sw.elapsedMicroseconds / snapshots,
      'µs/snapshot',
      'monitor',
    );
    vessel.dispose();
    Titan.reset();
  }
}

// =============================================================================
// Recording Benchmarks (9–15)
// =============================================================================

void _runRecordingBenchmarks() {
  // 9. Imprint creation
  {
    const count = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0 + i,
        positionY: 200.0,
        timestamp: Duration(milliseconds: i),
        pointer: 1,
        buttons: 1,
        pressure: 1.0,
      );
    }
    sw.stop();
    _record(
      'Imprint Creation (1M)',
      sw.elapsedMicroseconds / count,
      'µs/imprint',
      'recording',
    );
  }

  // 10. Imprint toMap
  {
    const count = 100000;
    const imprint = Imprint(
      type: ImprintType.pointerDown,
      positionX: 100.0,
      positionY: 200.0,
      timestamp: Duration(milliseconds: 500),
      pointer: 1,
      buttons: 1,
      pressure: 1.0,
    );
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      imprint.toMap();
    }
    sw.stop();
    _record(
      'Imprint toMap (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 11. Imprint fromMap
  {
    const count = 100000;
    final map = const Imprint(
      type: ImprintType.pointerDown,
      positionX: 100.0,
      positionY: 200.0,
      timestamp: Duration(milliseconds: 500),
      pointer: 1,
      buttons: 1,
      pressure: 1.0,
    ).toMap();
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Imprint.fromMap(map);
    }
    sw.stop();
    _record(
      'Imprint fromMap (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 12. ShadeSession toJson (500 events)
  {
    final session = _makeSession(500);
    const count = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      session.toJson();
    }
    sw.stop();
    _record(
      'Session toJson (500 events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 13. ShadeSession fromJson (500 events)
  {
    final jsonStr = _makeSession(500).toJson();
    const count = 100;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      ShadeSession.fromJson(jsonStr);
    }
    sw.stop();
    _record(
      'Session fromJson (500 events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 14. ShadeSession toJson (2000 events)
  {
    final session = _makeSession(2000);
    const count = 50;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      session.toJson();
    }
    sw.stop();
    _record(
      'Session toJson (2K events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }

  // 15. ShadeSession fromJson (2000 events)
  {
    final jsonStr = _makeSession(2000).toJson();
    const count = 50;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      ShadeSession.fromJson(jsonStr);
    }
    sw.stop();
    _record(
      'Session fromJson (2K events)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'recording',
    );
  }
}

// =============================================================================
// Export Benchmarks (16–21)
// =============================================================================

void _runExportBenchmarks() {
  final decree = _makeDecree();

  // 16. Decree toMap
  {
    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.toMap();
    }
    sw.stop();
    _record(
      'Decree toMap (10K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'export',
    );
  }

  // 17. Decree summary
  {
    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.summary;
    }
    sw.stop();
    _record(
      'Decree summary (10K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'export',
    );
  }

  // 18. Decree topRebuilders
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.topRebuilders();
    }
    sw.stop();
    _record(
      'Decree topRebuilders (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'export',
    );
  }

  // 19. Inscribe markdown
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Inscribe.markdown(decree);
    }
    sw.stop();
    _record(
      'Inscribe Markdown (1K)',
      sw.elapsedMicroseconds / count,
      'µs/export',
      'export',
    );
  }

  // 20. Inscribe json
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Inscribe.json(decree);
    }
    sw.stop();
    _record(
      'Inscribe JSON (1K)',
      sw.elapsedMicroseconds / count,
      'µs/export',
      'export',
    );
  }

  // 21. Inscribe html
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Inscribe.html(decree);
    }
    sw.stop();
    _record(
      'Inscribe HTML (1K)',
      sw.elapsedMicroseconds / count,
      'µs/export',
      'export',
    );
  }
}

// =============================================================================
// Overhead & Stress Benchmarks (22–26)
// =============================================================================

void _runOverheadBenchmarks() {
  // 22. FrameMark serialization
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      FrameMark(
        buildDuration: Duration(microseconds: 4000 + i),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: Duration(microseconds: 7000 + i),
      ).toMap();
    }
    sw.stop();
    _record(
      'FrameMark Create+Serialize (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'overhead',
    );
  }

  // 23. MemoryMark serialization
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      MemoryMark(
        pillarCount: 15,
        totalInstances: 42,
        leakSuspects: const ['SomePillar'],
      ).toMap();
    }
    sw.stop();
    _record(
      'MemoryMark Create+Serialize (100K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'overhead',
    );
  }

  // 24. Pulse history trim (small maxHistory = more frequent trims)
  {
    final pulse = Pulse(maxHistory: 50);
    for (var i = 0; i < 50; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pulse.recordFrame(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
    }
    sw.stop();
    _record(
      'Pulse Trim (maxHistory=50, 100K)',
      sw.elapsedMicroseconds / count,
      'µs/frame',
      'overhead',
    );
  }

  // 25. Tremor factory creation
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Tremor.fps(threshold: 50);
      Tremor.jankRate(threshold: 5);
      Tremor.pageLoad(threshold: const Duration(seconds: 1));
      Tremor.memory(maxPillars: 50);
      Tremor.rebuilds(threshold: 100, widget: 'W$i');
      Tremor.leaks();
    }
    sw.stop();
    _record(
      'Tremor Factory (600K)',
      sw.elapsedMicroseconds / (count * 6),
      'µs/factory',
      'overhead',
    );
  }

  // 26. Imprint round-trip (create -> toMap -> fromMap)
  {
    const count = 50000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0 + i,
        positionY: 200.0,
        timestamp: Duration(milliseconds: i),
        pointer: 1,
        buttons: 1,
      );
      Imprint.fromMap(imprint.toMap());
    }
    sw.stop();
    _record(
      'Imprint Round-Trip (50K)',
      sw.elapsedMicroseconds / count,
      'µs/op',
      'overhead',
    );
  }
}

// =============================================================================
// Helpers
// =============================================================================

ShadeSession _makeSession(int eventCount) {
  return ShadeSession(
    id: 'bench-session',
    name: 'Benchmark Session',
    recordedAt: DateTime.now(),
    duration: Duration(milliseconds: eventCount * 16),
    screenWidth: 390,
    screenHeight: 844,
    devicePixelRatio: 3.0,
    imprints: List.generate(
      eventCount,
      (i) => Imprint(
        type: i % 3 == 0
            ? ImprintType.pointerDown
            : i % 3 == 1
            ? ImprintType.pointerMove
            : ImprintType.pointerUp,
        positionX: 100.0 + i * 0.5,
        positionY: 200.0 + i * 0.3,
        timestamp: Duration(milliseconds: i * 16),
        pointer: 1,
        buttons: i % 3 == 2 ? 0 : 1,
        pressure: 1.0,
      ),
    ),
    startRoute: '/home',
  );
}

Decree _makeDecree() {
  return Decree(
    sessionStart: DateTime.now(),
    totalFrames: 10000,
    jankFrames: 150,
    avgFps: 58.5,
    avgBuildTime: const Duration(microseconds: 4200),
    avgRasterTime: const Duration(microseconds: 3100),
    pageLoads: List.generate(
      20,
      (i) => PageLoadMark(
        path: '/page/$i',
        duration: Duration(milliseconds: 100 + i * 10),
      ),
    ),
    pillarCount: 15,
    totalInstances: 42,
    leakSuspects: [
      LeakSuspect(typeName: 'OldPillar', firstSeen: DateTime.now()),
    ],
    rebuildsPerWidget: {for (var i = 0; i < 30; i++) 'Widget_$i': 10 + i * 3},
  );
}

void _record(String name, double value, String unit, String suite) {
  if (_isWarmup) return;
  _results[name] = _BenchResult(value: value, unit: unit, suite: suite);
}

String _readVersion() {
  try {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'version:\s*(.+)').firstMatch(pubspec);
    return match?.group(1)?.trim() ?? 'unknown';
  } catch (_) {
    return 'unknown';
  }
}

void _printReport(
  Map<String, dynamic>? previous,
  double threshold,
  double noiseFloor,
) {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  RESULTS');
  print('═══════════════════════════════════════════════════════');

  final prevBenchmarks = previous?['benchmarks'] as Map<String, dynamic>?;

  // Group by suite
  final suites = <String, List<String>>{};
  for (final entry in _results.entries) {
    suites.putIfAbsent(entry.value.suite, () => []).add(entry.key);
  }

  for (final suite in suites.entries) {
    print('');
    print('── ${suite.key.toUpperCase()} ──');

    for (final name in suite.value) {
      final result = _results[name]!;
      final valueStr = result.value >= 1000
          ? result.value.toStringAsFixed(0)
          : result.value.toStringAsFixed(3);

      String flag = '';
      if (prevBenchmarks != null && prevBenchmarks.containsKey(name)) {
        final prevValue =
            (prevBenchmarks[name] as Map<String, dynamic>)['value'] as num;
        final prevUnit =
            (prevBenchmarks[name] as Map<String, dynamic>)['unit'] as String;

        // For throughput metrics (higher is better), invert the comparison
        final isHigherBetter = prevUnit.contains('/sec') || prevUnit == 'x';

        final pctChange = ((result.value - prevValue) / prevValue * 100);

        final isRegression = isHigherBetter
            ? pctChange < -threshold
            : pctChange > threshold;
        final isImprovement = isHigherBetter
            ? pctChange > threshold
            : pctChange < -threshold;

        // Skip noise-floor items
        final absValue = isHigherBetter
            ? 1.0 / result.value * 1e6
            : result.value;
        if (absValue < noiseFloor && isRegression) {
          flag = ' (noise)';
        } else if (isRegression) {
          flag = pctChange.abs() > 20
              ? ' 🔴 ${pctChange.toStringAsFixed(1)}%'
              : ' 🟡 ${pctChange.toStringAsFixed(1)}%';
        } else if (isImprovement) {
          flag = pctChange.abs() > 20
              ? ' 💚 ${pctChange.toStringAsFixed(1)}%'
              : ' 🟢 ${pctChange.toStringAsFixed(1)}%';
        }
      } else if (prevBenchmarks != null) {
        flag = ' 🆕';
      }

      print('  ${name.padRight(38)} $valueStr ${result.unit}$flag');
    }
  }

  // Check for removed metrics
  if (prevBenchmarks != null) {
    for (final name in prevBenchmarks.keys) {
      if (!_results.containsKey(name)) {
        print('  ${name.padRight(38)} ❌ removed');
      }
    }
  }
}

class _BenchResult {
  final double value;
  final String unit;
  final String suite;
  _BenchResult({required this.value, required this.unit, required this.suite});
}

class _BenchPillar extends Pillar {
  late final count = core(0);
}
