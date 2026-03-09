// ignore_for_file: avoid_print
@Tags(['benchmark'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_atlas/titan_atlas.dart';

// =============================================================================
// Titan Atlas Benchmarks
// =============================================================================
//
// Run with: flutter test benchmark/benchmark_atlas.dart
//
// Covers:
//  1. RouteTrie — Insert and match performance (the hottest path)
//  2. Cartograph — Named route build + deep link registration
// =============================================================================

void main() {
  test('Atlas benchmarks', () async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('  TITAN ATLAS BENCHMARKS');
    print('═══════════════════════════════════════════════════════');
    print('');

    _benchRouteTrieInsert();
    _benchRouteTrieMatchStatic();
    _benchRouteTrieMatchDynamic();
    _benchRouteTrieMatchWildcard();
    _benchRouteTrieMatchMiss();
    _benchCartograph();

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  ALL ATLAS BENCHMARKS COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

// ---------------------------------------------------------------------------
// 1. RouteTrie — Insert at scale
// ---------------------------------------------------------------------------

void _benchRouteTrieInsert() {
  print('┌─ 1. RouteTrie.insert() ──────────────────────────────');

  for (final count in [100, 1000, 10000]) {
    final sw = Stopwatch()..start();
    final trie = RouteTrie<int>();
    for (var i = 0; i < count; i++) {
      trie.insert('/api/v1/resource$i', i);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  Insert ${_pad(count)} static routes: ${_ms(sw)}'
      '  ($perOp µs/route)',
    );
  }

  // Dynamic routes
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    final trie = RouteTrie<int>();
    for (var i = 0; i < count; i++) {
      trie.insert('/users/:userId/posts/:postId/comments/$i', i);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  Insert $count dynamic routes: ${_ms(sw)}'
      '  ($perOp µs/route)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 2. RouteTrie — Match static routes
// ---------------------------------------------------------------------------

void _benchRouteTrieMatchStatic() {
  print('┌─ 2. RouteTrie.match() — Static ─────────────────────');

  for (final routeCount in [100, 1000, 5000]) {
    final trie = RouteTrie<int>();
    for (var i = 0; i < routeCount; i++) {
      trie.insert('/api/v1/resource$i', i);
    }

    const lookups = 10000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      trie.match('/api/v1/resource${i % routeCount}');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Match from $routeCount routes ($lookups): ${_ms(sw)}'
      '  ($perOp µs/match)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 3. RouteTrie — Match dynamic (parameterized) routes
// ---------------------------------------------------------------------------

void _benchRouteTrieMatchDynamic() {
  print('┌─ 3. RouteTrie.match() — Dynamic ────────────────────');

  // Single parameter
  {
    final trie = RouteTrie<int>();
    trie.insert('/users/:id', 1);
    trie.insert('/posts/:slug', 2);
    trie.insert('/categories/:catId', 3);
    trie.insert('/tags/:tag', 4);

    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      trie.match('/users/$i');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Single param ($lookups): ${_ms(sw)}'
      '  ($perOp µs/match)',
    );
  }

  // Multi-parameter
  {
    final trie = RouteTrie<int>();
    trie.insert('/users/:userId/posts/:postId', 1);
    trie.insert('/orgs/:orgId/teams/:teamId/members/:memberId', 2);

    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      trie.match('/users/user-$i/posts/post-$i');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Multi param ($lookups): ${_ms(sw)}'
      '  ($perOp µs/match)',
    );
  }

  // Deep nesting (8 segments, 3 dynamic)
  {
    final trie = RouteTrie<int>();
    trie.insert('/api/v2/orgs/:orgId/projects/:projId/tasks/:taskId/status', 1);

    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      trie.match('/api/v2/orgs/org-$i/projects/proj-1/tasks/task-99/status');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Deep nest (8 seg, $lookups): ${_ms(sw)}'
      '  ($perOp µs/match)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 4. RouteTrie — Match wildcard
// ---------------------------------------------------------------------------

void _benchRouteTrieMatchWildcard() {
  print('┌─ 4. RouteTrie.match() — Wildcard ───────────────────');

  final trie = RouteTrie<int>();
  trie.insert('/files/*', 1);
  trie.insert('/api/v1/docs/*', 2);

  const lookups = 100000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < lookups; i++) {
    trie.match('/files/images/photos/vacation/pic$i.jpg');
  }
  sw.stop();
  final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
  print(
    '│  Wildcard with long remaining ($lookups): ${_ms(sw)}'
    '  ($perOp µs/match)',
  );

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 5. RouteTrie — Match miss (no match)
// ---------------------------------------------------------------------------

void _benchRouteTrieMatchMiss() {
  print('┌─ 5. RouteTrie.match() — Miss ───────────────────────');

  final trie = RouteTrie<int>();
  for (var i = 0; i < 1000; i++) {
    trie.insert('/api/v1/resource$i', i);
  }

  const lookups = 100000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < lookups; i++) {
    trie.match('/nonexistent/path/$i');
  }
  sw.stop();
  final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
  print(
    '│  404 miss ($lookups, 1000 routes): ${_ms(sw)}'
    '  ($perOp µs/miss)',
  );

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 6. Cartograph — Named route build + registration
// ---------------------------------------------------------------------------

void _benchCartograph() {
  print('┌─ 6. Cartograph (Named Routes) ──────────────────────');

  Cartograph.reset();

  // a) Registration
  {
    const count = 1000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      Cartograph.name('route-$i', '/api/v1/resource/:id/sub$i');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  Register $count named routes: ${_ms(sw)}'
      '  ($perOp µs/route)',
    );
  }

  // b) Build URL from named route
  {
    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Cartograph.build('route-${i % 1000}', runes: {'id': '$i'});
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Build URL ($lookups): ${_ms(sw)}'
      '  ($perOp µs/build)',
    );
  }

  // c) Build with query params
  {
    const lookups = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Cartograph.build(
        'route-${i % 1000}',
        runes: {'id': '$i'},
        query: {'page': '1', 'limit': '20', 'sort': 'name'},
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  Build + query ($lookups): ${_ms(sw)}'
      '  ($perOp µs/build)',
    );
  }

  // d) hasName lookup
  {
    const lookups = 1000000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < lookups; i++) {
      Cartograph.hasName('route-${i % 1000}');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / lookups).toStringAsFixed(2);
    print(
      '│  hasName lookup ($lookups): ${_ms(sw)}'
      '  ($perOp µs/op)',
    );
  }

  Cartograph.reset();

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
