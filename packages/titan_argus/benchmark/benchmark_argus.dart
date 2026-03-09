// ignore_for_file: avoid_print
@Tags(['benchmark'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_argus/titan_argus.dart';

// =============================================================================
// Titan Argus Benchmarks
// =============================================================================
//
// Run with: flutter test benchmark/benchmark_argus.dart
//
// Covers:
//  1. Garrison.authGuard — Creation + evaluation throughput
//  2. Garrison.roleGuard — Role-based guard evaluation
//  3. Garrison.onboardingGuard — Onboarding guard evaluation
//  4. Garrison.composite — Composite guard evaluation
//  5. Sentinel evaluation overhead — appliesTo + evaluate
//  6. CoreRefresh — Reactive-to-Listenable bridge
// =============================================================================

void main() {
  test('Argus benchmarks', () async {
    print('');
    print('═══════════════════════════════════════════════════════');
    print('  TITAN ARGUS BENCHMARKS');
    print('═══════════════════════════════════════════════════════');
    print('');

    _benchAuthGuardCreation();
    _benchAuthGuardEvaluation();
    _benchRoleGuardEvaluation();
    _benchOnboardingGuardEvaluation();
    _benchCompositeGuardEvaluation();
    _benchSentinelAppliesTo();
    _benchCoreRefresh();

    print('');
    print('═══════════════════════════════════════════════════════');
    print('  ALL ARGUS BENCHMARKS COMPLETE');
    print('═══════════════════════════════════════════════════════');
  });
}

/// Dummy Waypoint for benchmark evaluation.
const _waypoint = Waypoint(path: '/dashboard', pattern: '/dashboard');

// ---------------------------------------------------------------------------
// 1. Garrison.authGuard — Creation throughput
// ---------------------------------------------------------------------------

void _benchAuthGuardCreation() {
  print('┌─ 1. Garrison.authGuard (Creation) ──────────────────');

  var loggedIn = true;

  for (final count in [100, 1000, 10000]) {
    final guards = <Sentinel>[];
    final sw = Stopwatch()..start();
    for (var i = 0; i < count; i++) {
      guards.add(
        Garrison.authGuard(
          isAuthenticated: () => loggedIn,
          loginPath: '/login',
          publicPaths: {'/about', '/terms', '/privacy'},
        ),
      );
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / count).toStringAsFixed(2);
    print(
      '│  Create ${_pad(count)} authGuards: ${_ms(sw)}'
      '  ($perOp µs/guard)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 2. Garrison.authGuard — Evaluation throughput
// ---------------------------------------------------------------------------

void _benchAuthGuardEvaluation() {
  print('┌─ 2. Garrison.authGuard (Evaluation) ────────────────');

  var loggedIn = true;
  final guard = Garrison.authGuard(
    isAuthenticated: () => loggedIn,
    loginPath: '/login',
    publicPaths: {'/about', '/terms', '/privacy'},
  );

  // a) Authenticated — should return null (allow)
  {
    const iterations = 100000;
    loggedIn = true;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/dashboard', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (auth=true, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  // b) Unauthenticated — should redirect
  {
    const iterations = 100000;
    loggedIn = false;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/dashboard', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (auth=false, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  // c) Public path — should always allow
  {
    const iterations = 100000;
    loggedIn = false;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/about', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (public path, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 3. Garrison.roleGuard — Role evaluation throughput
// ---------------------------------------------------------------------------

void _benchRoleGuardEvaluation() {
  print('┌─ 3. Garrison.roleGuard (Evaluation) ────────────────');

  var currentRole = 'admin';
  final guard = Garrison.roleGuard(
    getRole: () => currentRole,
    rules: {
      '/admin': {'admin'},
      '/editor': {'admin', 'editor'},
      '/viewer': {'admin', 'editor', 'viewer'},
      '/settings': {'admin'},
      '/reports': {'admin', 'editor'},
    },
    fallbackPath: '/unauthorized',
  );

  // a) Matching role
  {
    const iterations = 100000;
    currentRole = 'admin';
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/admin', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (role match, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  // b) Non-matching role
  {
    const iterations = 100000;
    currentRole = 'viewer';
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/admin', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (role denied, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  // c) Unguarded path (not in rules)
  {
    const iterations = 100000;
    currentRole = 'viewer';
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/public', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (unguarded, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 4. Garrison.onboardingGuard — Evaluation throughput
// ---------------------------------------------------------------------------

void _benchOnboardingGuardEvaluation() {
  print('┌─ 4. Garrison.onboardingGuard (Evaluation) ──────────');

  var onboarded = false;
  final guard = Garrison.onboardingGuard(
    isOnboarded: () => onboarded,
    onboardingPath: '/onboarding',
    exemptPaths: {'/login', '/register', '/onboarding'},
  );

  // a) Not onboarded, protected path
  {
    const iterations = 100000;
    onboarded = false;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/dashboard', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (not onboarded, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  // b) Onboarded, should pass
  {
    const iterations = 100000;
    onboarded = true;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      guard.evaluate('/dashboard', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  evaluate (onboarded, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 5. Garrison.composite — Multiple guards
// ---------------------------------------------------------------------------

void _benchCompositeGuardEvaluation() {
  print('┌─ 5. Garrison.composite (Multi-Guard) ───────────────');

  // Toggle to exercise both branches per iteration.
  var loggedIn = true;

  for (final guardCount in [2, 5, 10]) {
    final guards = <SentinelGuard>[];
    for (var i = 0; i < guardCount; i++) {
      if (i == 0) {
        guards.add((path, _) {
          loggedIn = !loggedIn;
          return loggedIn ? null : '/login';
        });
      } else {
        // No-op guards (pass-through)
        guards.add((path, _) => null);
      }
    }
    final composite = Garrison.composite(guards);

    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      composite.evaluate('/dashboard', _waypoint);
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  composite($guardCount guards, $iterations): ${_ms(sw)}'
      '  ($perOp µs/eval)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 6. Sentinel.appliesTo — Path matching
// ---------------------------------------------------------------------------

void _benchSentinelAppliesTo() {
  print('┌─ 6. Sentinel.appliesTo (Path Matching) ─────────────');

  // a) Sentinel.only — small set
  {
    final sentinel = Sentinel.only(
      paths: {'/settings', '/billing', '/profile'},
      guard: (p, _) => p.isEmpty ? '/x' : null,
    );
    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      sentinel.appliesTo('/settings');
      sentinel.appliesTo('/public');
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  appliesTo (only, 3 paths, $iterations): ${_ms(sw)}'
      '  ($perOp µs/2 checks)',
    );
  }

  // b) Sentinel.except — medium set
  {
    final sentinel = Sentinel.except(
      paths: {
        '/login',
        '/register',
        '/',
        '/about',
        '/terms',
        '/privacy',
        '/help',
        '/faq',
        '/contact',
        '/blog',
      },
      guard: (p, _) => p.isEmpty ? '/x' : null,
    );
    const iterations = 100000;
    final sw = Stopwatch()..start();
    for (var i = 0; i < iterations; i++) {
      sentinel.appliesTo('/dashboard'); // not excluded
      sentinel.appliesTo('/login'); // excluded
    }
    sw.stop();
    final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
    print(
      '│  appliesTo (except, 10 paths, $iterations): ${_ms(sw)}'
      '  ($perOp µs/2 checks)',
    );
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// 7. CoreRefresh — Reactive-to-Listenable bridge
// ---------------------------------------------------------------------------

void _benchCoreRefresh() {
  print('┌─ 7. CoreRefresh (Bridge) ────────────────────────────');

  // a) Creation with multiple cores
  {
    for (final coreCount in [1, 5, 10]) {
      final pillar = _BenchPillar(coreCount: coreCount);
      const iterations = 1000;
      final refreshes = <CoreRefresh>[];

      final sw = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        refreshes.add(CoreRefresh(pillar.cores));
      }
      sw.stop();
      final perOp = (sw.elapsedMicroseconds / iterations).toStringAsFixed(2);
      print(
        '│  Create ($coreCount cores, $iterations): ${_ms(sw)}'
        '  ($perOp µs/create)',
      );

      for (final r in refreshes) {
        r.dispose();
      }
      pillar.dispose();
    }
  }

  print('└───────────────────────────────────────────────────────');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A minimal Pillar subclass for benchmarking CoreRefresh.
class _BenchPillar extends Pillar {
  final List<Core<int>> cores = [];

  _BenchPillar({required int coreCount}) {
    for (var i = 0; i < coreCount; i++) {
      cores.add(core(0, name: 'bench_$i'));
    }
  }
}

/// Format stopwatch to ms string.
String _ms(Stopwatch sw) {
  if (sw.elapsedMilliseconds > 0) {
    return '${sw.elapsedMilliseconds} ms';
  }
  return '${sw.elapsedMicroseconds} µs';
}

/// Right-pad a number for alignment.
String _pad(int n) => n.toString().padLeft(6);
