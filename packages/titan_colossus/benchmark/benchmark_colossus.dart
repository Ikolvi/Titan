// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';

// =============================================================================
// Colossus Performance Benchmarks — Core Suite
// =============================================================================
//
// Run with: cd packages/titan_colossus && flutter test benchmark/benchmark_colossus.dart
//
// Measures the performance overhead of the monitoring infrastructure.
// These benchmarks verify that the Colossus adds minimal overhead to
// the app it monitors — a tracker must be lighter than what it tracks.
//
// Benchmarks:
//   1.  Pulse.recordFrame() throughput
//   2.  Pulse rolling average computation
//   3.  FrameMark creation + isJank classification
//   4.  Stride.record() throughput
//   5.  Stride.avgPageLoad computation
//   6.  Tremor.evaluate() batch throughput
//   7.  Tremor factory creation overhead
//   8.  Colossus.recordRebuild() throughput (Echo hot path)
//   9.  Mark construction + toMap() serialization
//   10. Decree construction + toMap() + summary generation
//   11. Inscribe markdown/json/html export
//   12. Imprint creation + toMap/fromMap round-trip
//   13. ShadeSession toJson/fromJson serialization
//   14. Vessel snapshot with populated DI registry
// =============================================================================

void main() {
  test('Colossus Performance Benchmarks', () {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('  COLOSSUS PERFORMANCE BENCHMARKS');
    print('═══════════════════════════════════════════════════════');
    print('');

    _benchPulseRecordFrame();
    _benchPulseRollingAverage();
    _benchFrameMarkCreation();
    _benchStrideRecord();
    _benchStrideAvgPageLoad();
    _benchTremorEvaluate();
    _benchTremorFactory();
    _benchRecordRebuild();
    _benchMarkSerialization();
    _benchDecreeGeneration();
    _benchInscribeExport();
    _benchImprintRoundTrip();
    _benchSessionSerialization();
    _benchVesselSnapshot();

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  ALL COLOSSUS BENCHMARKS COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _ms(Stopwatch sw) {
  final ms = sw.elapsedMilliseconds;
  final us = sw.elapsedMicroseconds;
  if (ms > 0) return '${ms}ms';
  return '$usµs';
}

String _pad(int n) => n.toString().padLeft(7);

// ---------------------------------------------------------------------------
// 1. Pulse.recordFrame() throughput
// ---------------------------------------------------------------------------

void _benchPulseRecordFrame() {
  print('┌─ 1. Pulse.recordFrame() Throughput ───────────────────');

  for (final count in [1000, 10000, 100000]) {
    final pulse = Pulse(maxHistory: 300);
    final build = const Duration(microseconds: 4000);
    final raster = const Duration(microseconds: 3000);
    final total = const Duration(microseconds: 7000);

    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      pulse.recordFrame(
        buildDuration: build,
        rasterDuration: raster,
        totalDuration: total,
      );
    }
    sw.stop();

    final perFrame = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  ${_pad(count)} frames:  ${_ms(sw)}  ($perFrame µs/frame)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 2. Pulse rolling average computation (history full)
// ---------------------------------------------------------------------------

void _benchPulseRollingAverage() {
  print('┌─ 2. Pulse Rolling Average (300 history) ─────────────');

  final pulse = Pulse(maxHistory: 300);

  // Fill history to capacity
  for (var i = 0; i < 300; i++) {
    pulse.recordFrame(
      buildDuration: Duration(microseconds: 3000 + (i % 5) * 1000),
      rasterDuration: Duration(microseconds: 2000 + (i % 3) * 500),
      totalDuration: Duration(microseconds: 5000 + (i % 5) * 1500),
    );
  }

  // Now benchmark steady-state additions (history at capacity, triggers trim)
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

  final perFrame = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  final throughput = (count / sw.elapsedMicroseconds * 1e6).toStringAsFixed(0);
  print('│  $count frames (full history): ${_ms(sw)}');
  print('│  $perFrame µs/frame  ($throughput frames/sec)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 3. FrameMark creation + isJank classification
// ---------------------------------------------------------------------------

void _benchFrameMarkCreation() {
  print('┌─ 3. FrameMark Creation + isJank ──────────────────────');

  const count = 1000000;
  final sw = Stopwatch()..start();
  var jankCount = 0;
  for (var i = 0; i < count; i++) {
    final frame = FrameMark(
      buildDuration: Duration(microseconds: 4000 + (i % 20) * 1000),
      rasterDuration: Duration(microseconds: 3000 + (i % 10) * 500),
      totalDuration: Duration(microseconds: 7000 + (i % 20) * 1500),
    );
    if (frame.isJank) jankCount++;
  }
  sw.stop();

  final perMark = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
  print(
    '│  ${_pad(count)} marks:  ${_ms(sw)}  '
    '($perMark µs/mark, $jankCount jank)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 4. Stride.record() throughput
// ---------------------------------------------------------------------------

void _benchStrideRecord() {
  print('┌─ 4. Stride.record() Throughput ───────────────────────');

  for (final count in [1000, 10000, 100000]) {
    final stride = Stride(maxHistory: 100);

    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      stride.record(
        '/page/$i',
        Duration(milliseconds: 50 + (i % 200)),
        pattern: '/page/:id',
      );
    }
    sw.stop();

    final perRecord = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  ${_pad(count)} records: ${_ms(sw)}  ($perRecord µs/record)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 5. Stride.avgPageLoad computation
// ---------------------------------------------------------------------------

void _benchStrideAvgPageLoad() {
  print('┌─ 5. Stride.avgPageLoad Computation ───────────────────');

  for (final historySize in [10, 50, 100]) {
    final stride = Stride(maxHistory: historySize);
    for (var i = 0; i < historySize; i++) {
      stride.record('/page/$i', Duration(milliseconds: 50 + (i % 200)));
    }

    const reads = 100000;
    final sw = Stopwatch()..start();
    Duration? avg;
    for (var i = 0; i < reads; i++) {
      avg = stride.avgPageLoad;
    }
    sw.stop();

    final perRead = (sw.elapsedMicroseconds / reads).toStringAsFixed(3);
    print(
      '│  history=$historySize, $reads reads: ${_ms(sw)}  '
      '($perRead µs/read, avg=${avg?.inMilliseconds}ms)',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 6. Tremor.evaluate() batch throughput
// ---------------------------------------------------------------------------

void _benchTremorEvaluate() {
  print('┌─ 6. Tremor.evaluate() Batch Throughput ───────────────');

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
  var triggered = 0;
  for (var i = 0; i < iterations; i++) {
    for (final tremor in tremors) {
      if (tremor.evaluate(context)) triggered++;
      tremor.reset(); // reset 'once' flag for re-evaluation
    }
  }
  sw.stop();

  final totalEvals = iterations * tremors.length;
  final perEval = (sw.elapsedMicroseconds / totalEvals).toStringAsFixed(3);
  final throughput = (totalEvals / sw.elapsedMicroseconds * 1e6)
      .toStringAsFixed(0);
  print('│  ${tremors.length} tremors × $iterations iterations: ${_ms(sw)}');
  print('│  $perEval µs/eval  ($throughput evals/sec, $triggered triggered)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 7. Tremor factory creation overhead
// ---------------------------------------------------------------------------

void _benchTremorFactory() {
  print('┌─ 7. Tremor Factory Creation ──────────────────────────');

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

  final total = count * 6;
  final perFactory = (sw.elapsedMicroseconds / total).toStringAsFixed(3);
  print('│  $total factory calls: ${_ms(sw)}  ($perFactory µs/factory)');

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 8. recordRebuild() throughput (Echo hot path simulation)
// ---------------------------------------------------------------------------

void _benchRecordRebuild() {
  print('┌─ 8. recordRebuild() Throughput (Echo) ────────────────');

  // Simulate the map-increment pattern used by Colossus.recordRebuild
  final rebuildsPerWidget = <String, int>{};
  final labels = List.generate(50, (i) => 'Widget_$i');

  const iterations = 1000000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < iterations; i++) {
    final label = labels[i % labels.length];
    rebuildsPerWidget[label] = (rebuildsPerWidget[label] ?? 0) + 1;
  }
  sw.stop();

  final perRebuild = (sw.elapsedMicroseconds / iterations).toStringAsFixed(3);
  final throughput = (iterations / sw.elapsedMicroseconds * 1e6)
      .toStringAsFixed(0);
  print(
    '│  $iterations rebuilds (50 widgets): ${_ms(sw)}  '
    '($perRebuild µs/rebuild, $throughput rebuilds/sec)',
  );

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 9. Mark construction + toMap() serialization
// ---------------------------------------------------------------------------

void _benchMarkSerialization() {
  print('┌─ 9. Mark Serialization ───────────────────────────────');

  // FrameMark
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final mark = FrameMark(
        buildDuration: Duration(microseconds: 4000 + i),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: Duration(microseconds: 7000 + i),
      );
      mark.toMap();
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  FrameMark  (${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  // PageLoadMark
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final mark = PageLoadMark(
        path: '/page/$i',
        duration: Duration(milliseconds: 100 + i),
        pattern: '/page/:id',
      );
      mark.toMap();
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  PageLoad   (${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  // RebuildMark
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final mark = RebuildMark(label: 'Widget_$i', rebuildCount: i);
      mark.toMap();
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  RebuildMark(${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  // MemoryMark
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      final mark = MemoryMark(
        pillarCount: 15,
        totalInstances: 42,
        leakSuspects: const ['SomePillar'],
      );
      mark.toMap();
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  MemoryMark (${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 10. Decree construction + toMap() + summary generation
// ---------------------------------------------------------------------------

void _benchDecreeGeneration() {
  print('┌─ 10. Decree Generation ───────────────────────────────');

  final pageLoads = List.generate(
    20,
    (i) => PageLoadMark(
      path: '/page/$i',
      duration: Duration(milliseconds: 100 + i * 10),
    ),
  );
  final rebuilds = {for (var i = 0; i < 30; i++) 'Widget_$i': 10 + i * 3};
  final leaks = [LeakSuspect(typeName: 'OldPillar', firstSeen: DateTime.now())];

  // Construction
  {
    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Decree(
        sessionStart: DateTime.now(),
        totalFrames: 10000,
        jankFrames: 150,
        avgFps: 58.5,
        avgBuildTime: const Duration(microseconds: 4200),
        avgRasterTime: const Duration(microseconds: 3100),
        pageLoads: pageLoads,
        pillarCount: 15,
        totalInstances: 42,
        leakSuspects: leaks,
        rebuildsPerWidget: rebuilds,
      );
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  Construction (${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  // toMap()
  {
    final decree = Decree(
      sessionStart: DateTime.now(),
      totalFrames: 10000,
      jankFrames: 150,
      avgFps: 58.5,
      avgBuildTime: const Duration(microseconds: 4200),
      avgRasterTime: const Duration(microseconds: 3100),
      pageLoads: pageLoads,
      pillarCount: 15,
      totalInstances: 42,
      leakSuspects: leaks,
      rebuildsPerWidget: rebuilds,
    );

    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.toMap();
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  toMap()     (${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  // summary
  {
    final decree = Decree(
      sessionStart: DateTime.now(),
      totalFrames: 10000,
      jankFrames: 150,
      avgFps: 58.5,
      avgBuildTime: const Duration(microseconds: 4200),
      avgRasterTime: const Duration(microseconds: 3100),
      pageLoads: pageLoads,
      pillarCount: 15,
      totalInstances: 42,
      leakSuspects: leaks,
      rebuildsPerWidget: rebuilds,
    );

    const count = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.summary;
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  summary     (${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  // topRebuilders
  {
    final decree = Decree(
      sessionStart: DateTime.now(),
      totalFrames: 10000,
      jankFrames: 150,
      avgFps: 58.5,
      avgBuildTime: const Duration(microseconds: 4200),
      avgRasterTime: const Duration(microseconds: 3100),
      pageLoads: pageLoads,
      pillarCount: 15,
      totalInstances: 42,
      leakSuspects: leaks,
      rebuildsPerWidget: rebuilds,
    );

    const count = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      decree.topRebuilders();
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  topRebuilders(${_pad(count)}): ${_ms(sw)}  ($per µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 11. Inscribe export (markdown / json / html)
// ---------------------------------------------------------------------------

void _benchInscribeExport() {
  print('┌─ 11. Inscribe Export ─────────────────────────────────');

  final decree = Decree(
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

  for (final entry in [
    ('Markdown', () => Inscribe.markdown(decree)),
    ('JSON    ', () => Inscribe.json(decree)),
    ('HTML    ', () => Inscribe.html(decree)),
  ]) {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      entry.$2();
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(1);
    print('│  ${entry.$1} ($count): ${_ms(sw)}  ($per µs/export)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 12. Imprint creation + toMap/fromMap round-trip
// ---------------------------------------------------------------------------

void _benchImprintRoundTrip() {
  print('┌─ 12. Imprint Round-Trip ──────────────────────────────');

  // Creation
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
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  Creation   ($count): ${_ms(sw)}  ($per µs/imprint)');
  }

  // toMap
  {
    const count = 100000;
    final imprint = const Imprint(
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
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  toMap()    ($count):  ${_ms(sw)}  ($per µs/op)');
  }

  // fromMap
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
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  fromMap()  ($count):  ${_ms(sw)}  ($per µs/op)');
  }

  // Round-trip
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
      final map = imprint.toMap();
      Imprint.fromMap(map);
    }
    sw.stop();
    final per = (sw.elapsedMicroseconds / count).toStringAsFixed(3);
    print('│  Round-trip ($count):  ${_ms(sw)}  ($per µs/op)');
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 13. ShadeSession toJson/fromJson serialization
// ---------------------------------------------------------------------------

void _benchSessionSerialization() {
  print('┌─ 13. ShadeSession Serialization ──────────────────────');

  for (final eventCount in [100, 500, 2000]) {
    final imprints = List.generate(
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
    );

    final session = ShadeSession(
      id: 'bench-session',
      name: 'Benchmark Session',
      recordedAt: DateTime.now(),
      duration: Duration(milliseconds: eventCount * 16),
      screenWidth: 390,
      screenHeight: 844,
      devicePixelRatio: 3.0,
      imprints: imprints,
      startRoute: '/home',
    );

    // toJson
    const count = 100;
    final swTo = Stopwatch()..start();
    late String jsonStr;
    for (var i = 0; i < count; i++) {
      jsonStr = session.toJson();
    }
    swTo.stop();
    final perTo = (swTo.elapsedMicroseconds / count).toStringAsFixed(1);

    // fromJson
    final swFrom = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      ShadeSession.fromJson(jsonStr);
    }
    swFrom.stop();
    final perFrom = (swFrom.elapsedMicroseconds / count).toStringAsFixed(1);

    final jsonSize = (jsonStr.length / 1024).toStringAsFixed(1);
    print(
      '│  $eventCount events ($jsonSize KB):  '
      'toJson=$perToµs  fromJson=$perFromµs',
    );
  }

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// 14. Vessel snapshot with populated DI registry
// ---------------------------------------------------------------------------

void _benchVesselSnapshot() {
  print('┌─ 14. Vessel DI Scan ──────────────────────────────────');

  // Register a single Pillar to populate the DI registry
  Titan.reset();
  final p = _BenchPillar();
  Titan.put<_BenchPillar>(p);

  final vessel = Vessel(
    checkInterval: const Duration(hours: 1), // don't auto-check
  );

  const snapshots = 10000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < snapshots; i++) {
    vessel.snapshot();
  }
  sw.stop();

  final perSnap = (sw.elapsedMicroseconds / snapshots).toStringAsFixed(3);
  print(
    '│  1 pillar, $snapshots snapshots: ${_ms(sw)}  '
    '($perSnap µs/snapshot)',
  );

  vessel.dispose();
  Titan.reset();

  print('└───────────────────────────────────────────────────────');
  print('');
}

// ---------------------------------------------------------------------------
// Helper Pillar for Vessel benchmarks
// ---------------------------------------------------------------------------

class _BenchPillar extends Pillar {
  late final count = core(0);
}
