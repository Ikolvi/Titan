// ignore_for_file: avoid_print
import 'dart:async';

import 'package:titan_basalt/titan_basalt.dart';

// =============================================================================
// Titan Basalt Benchmarks — Missing Components
// =============================================================================
//
// Run with: dart run benchmark/benchmark_basalt.dart
//
// Covers components not yet benchmarked in titan's benchmark_enterprise.dart:
//  1. Codex — Paginated data management
//  2. Quarry — Reactive data fetching with retry
//
// Note: 22 of 25 basalt components are already benchmarked in
// packages/titan/benchmark/benchmark_enterprise.dart.
// =============================================================================

void main() async {
  print('');
  print('═══════════════════════════════════════════════════════');
  print('  TITAN BASALT BENCHMARKS (SUPPLEMENTARY)');
  print('═══════════════════════════════════════════════════════');
  print('');

  await _benchCodex();
  await _benchQuarry();

  print('');
  print('═══════════════════════════════════════════════════════');
  print('  ALL BASALT SUPPLEMENTARY BENCHMARKS COMPLETE');
  print('═══════════════════════════════════════════════════════');
}

// ---------------------------------------------------------------------------
// 1. Codex — Paginated data management
// ---------------------------------------------------------------------------

Future<void> _benchCodex() async {
  print('┌─ 1. Codex (Pagination) ─────────────────────────────');

  // a) Creation throughput
  {
    for (final count in [100, 1000, 10000]) {
      final codexList = <Codex<int>>[];
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        codexList.add(
          Codex<int>(
            fetcher: (req) async =>
                CodexPage(items: List.generate(20, (j) => j), hasMore: true),
            pageSize: 20,
          ),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print(
        '│  Create ${_pad(count)} codex: ${_ms(sw)}'
        '  ($perOp µs/codex)',
      );

      for (final c in codexList) {
        c.dispose();
      }
    }
  }

  // b) Load first page
  {
    const iterations = 1000;
    final codex = Codex<int>(
      fetcher: (req) async => CodexPage(
        items: List.generate(20, (j) => req.page * 20 + j),
        hasMore: true,
      ),
      pageSize: 20,
    );

    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await codex.loadFirst();
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  loadFirst ($iterations): ${_ms(sw)}'
      '  ($perOp µs/load)',
    );

    codex.dispose();
  }

  // c) Accumulated page loads (loadNext)
  {
    final codex = Codex<int>(
      fetcher: (req) async => CodexPage(
        items: List.generate(50, (j) => req.page * 50 + j),
        hasMore: req.page < 99,
      ),
      pageSize: 50,
    );

    await codex.loadFirst();

    const pages = 50;
    final sw = Stopwatch()..start();
    for (var i = 0; i < pages; i++) {
      await codex.loadNext();
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / pages).toStringAsFixed(2);
    print(
      '│  loadNext ($pages pages): ${_ms(sw)}'
      '  ($perOp µs/page)',
    );
    print('│  Items accumulated: ${codex.itemCount}');

    codex.dispose();
  }

  // d) Client-side filter (where)
  {
    final codex = Codex<int>(
      fetcher: (req) async => CodexPage(
        items: List.generate(100, (j) => req.page * 100 + j),
        hasMore: false,
      ),
      pageSize: 100,
    );
    await codex.loadFirst();

    const iterations = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      codex.where((item) => item % 2 == 0);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  where() filter ($iterations, 100 items): ${_ms(sw)}'
      '  ($perOp µs/filter)',
    );

    codex.dispose();
  }

  // e) In-place item operations
  {
    final codex = Codex<int>(
      fetcher: (req) async =>
          CodexPage(items: List.generate(1000, (j) => j), hasMore: false),
      pageSize: 1000,
    );
    await codex.loadFirst();

    const iterations = 10000;

    // insertItem
    {
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        codex.insertItem(i, index: 0);
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
      print(
        '│  insertItem ($iterations): ${_ms(sw)}'
        '  ($perOp µs/insert)',
      );
    }

    // updateItemAt
    {
      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        codex.updateItemAt(i % codex.itemCount, (v) => v + 1);
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
      print(
        '│  updateItemAt ($iterations): ${_ms(sw)}'
        '  ($perOp µs/update)',
      );
    }

    codex.dispose();
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 2. Quarry — Reactive data fetching
// ---------------------------------------------------------------------------

Future<void> _benchQuarry() async {
  print('┌─ 2. Quarry (Data Fetching) ─────────────────────────');

  // a) Creation throughput
  {
    for (final count in [100, 1000, 10000]) {
      final quarries = <Quarry<int>>[];
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        quarries.add(
          Quarry<int>(
            fetcher: () async => i,
            staleTime: const Duration(minutes: 5),
          ),
        );
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
      print(
        '│  Create ${_pad(count)} quarries: ${_ms(sw)}'
        '  ($perOp µs/quarry)',
      );

      for (final q in quarries) {
        q.dispose();
      }
    }
  }

  // b) Fetch throughput (no retry)
  {
    const iterations = 1000;
    final quarry = Quarry<int>(fetcher: () async => 42);

    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      await quarry.refetch();
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  refetch ($iterations, no retry): ${_ms(sw)}'
      '  ($perOp µs/fetch)',
    );

    quarry.dispose();
  }

  // c) Stale check throughput
  {
    final quarry = Quarry<int>(
      fetcher: () async => 42,
      staleTime: const Duration(minutes: 5),
    );
    await quarry.fetch();

    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      quarry.isStale;
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  isStale check ($iterations): ${_ms(sw)}'
      '  ($perOp µs/check)',
    );

    quarry.dispose();
  }

  // d) Optimistic update (setData)
  {
    final quarry = Quarry<int>(fetcher: () async => 42);
    await quarry.fetch();

    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      quarry.setData(i);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  setData ($iterations): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );

    quarry.dispose();
  }

  // e) Invalidate + cancel cycle
  {
    final quarry = Quarry<int>(fetcher: () async => 42);
    await quarry.fetch();

    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      quarry.invalidate();
      quarry.cancel();
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  invalidate + cancel ($iterations): ${_ms(sw)}'
      '  ($perOp µs/cycle)',
    );

    quarry.dispose();
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Format stopwatch to ms string.
String _ms(Stopwatch sw) {
  if (sw.elapsedMilliseconds > 0) {
    return '${sw.elapsedMilliseconds} ms';
  }
  return '${sw.elapsedMicroseconds} µs';
}

/// Right-pad a number for alignment.
String _pad(int n) => n.toString().padLeft(6);
