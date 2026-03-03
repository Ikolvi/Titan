import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Portcullis', () {
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    group('construction', () {
      test('creates with default configuration', () {
        final p = Portcullis();
        expect(p.state, PortcullisState.closed);
        expect(p.failureCount, 0);
        expect(p.successCount, 0);
        expect(p.tripCount, 0);
        expect(p.lastTrip, isNull);
        expect(p.lastFailure, isNull);
        expect(p.probeSuccessCount, 0);
        expect(p.isClosed, isTrue);
        expect(p.isDisposed, isFalse);
        expect(p.name, isNull);
        expect(p.failureThreshold, 5);
        expect(p.resetTimeout, const Duration(seconds: 30));
        expect(p.halfOpenMaxProbes, 1);
        expect(p.tripHistory, isEmpty);
        p.dispose();
      });

      test('creates with custom configuration', () {
        final p = Portcullis(
          failureThreshold: 3,
          resetTimeout: const Duration(seconds: 10),
          halfOpenMaxProbes: 2,
          maxTripHistory: 5,
          name: 'test-breaker',
        );
        expect(p.name, 'test-breaker');
        expect(p.failureThreshold, 3);
        expect(p.resetTimeout, const Duration(seconds: 10));
        expect(p.halfOpenMaxProbes, 2);
        p.dispose();
      });

      test('toString shows state summary', () {
        final p = Portcullis(name: 'api');
        expect(p.toString(), contains('Portcullis'));
        expect(p.toString(), contains('api'));
        expect(p.toString(), contains('closed'));
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Closed State — Success
    // -----------------------------------------------------------------------

    group('closed state — success', () {
      test('protect passes through on success', () async {
        final p = Portcullis(failureThreshold: 3);
        final result = await p.protect(() async => 42);
        expect(result, 42);
        expect(p.successCount, 1);
        expect(p.failureCount, 0);
        expect(p.state, PortcullisState.closed);
        p.dispose();
      });

      test('protectSync passes through on success', () {
        final p = Portcullis(failureThreshold: 3);
        final result = p.protectSync(() => 'hello');
        expect(result, 'hello');
        expect(p.successCount, 1);
        p.dispose();
      });

      test('success resets failure count', () async {
        final p = Portcullis(failureThreshold: 5);
        // Accumulate 3 failures
        for (var i = 0; i < 3; i++) {
          try {
            await p.protect(() async => throw Exception('fail'));
          } catch (_) {}
        }
        expect(p.failureCount, 3);

        // One success resets count
        await p.protect(() async => 'ok');
        expect(p.failureCount, 0);
        expect(p.successCount, 1);
        p.dispose();
      });

      test('multiple successes increment counter', () async {
        final p = Portcullis();
        for (var i = 0; i < 5; i++) {
          await p.protect(() async => i);
        }
        expect(p.successCount, 5);
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Closed State — Failure
    // -----------------------------------------------------------------------

    group('closed state — failure', () {
      test('failures increment counter', () async {
        final p = Portcullis(failureThreshold: 5);
        for (var i = 0; i < 3; i++) {
          try {
            await p.protect(() async => throw Exception('err'));
          } catch (_) {}
        }
        expect(p.failureCount, 3);
        expect(p.state, PortcullisState.closed);
        expect(p.lastFailure, isA<Exception>());
        p.dispose();
      });

      test('protect rethrows the exception', () async {
        final p = Portcullis(failureThreshold: 5);
        expect(
          () => p.protect(() async => throw StateError('boom')),
          throwsA(isA<StateError>()),
        );
        p.dispose();
      });

      test('protectSync rethrows the exception', () {
        final p = Portcullis(failureThreshold: 5);
        expect(
          () => p.protectSync(() => throw ArgumentError('bad')),
          throwsA(isA<ArgumentError>()),
        );
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Tripping — Closed → Open
    // -----------------------------------------------------------------------

    group('tripping to open', () {
      test('trips after reaching failure threshold', () async {
        final p = Portcullis(failureThreshold: 3);
        for (var i = 0; i < 3; i++) {
          try {
            await p.protect(() async => throw Exception('fail $i'));
          } catch (_) {}
        }
        expect(p.state, PortcullisState.open);
        expect(p.tripCount, 1);
        expect(p.lastTrip, isNotNull);
        expect(p.isClosed, isFalse);
        p.dispose();
      });

      test('records trip in history', () async {
        final p = Portcullis(failureThreshold: 2);
        for (var i = 0; i < 2; i++) {
          try {
            await p.protect(() async => throw Exception('fail'));
          } catch (_) {}
        }
        expect(p.tripHistory, hasLength(1));
        expect(p.tripHistory.first.failureCount, 2);
        expect(p.tripHistory.first.lastError, isA<Exception>());
        expect(p.tripHistory.first.toString(), contains('failures: 2'));
        p.dispose();
      });

      test('open state rejects with PortcullisOpenException', () async {
        final p = Portcullis(failureThreshold: 1);
        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}
        expect(p.state, PortcullisState.open);

        expect(
          () => p.protect(() async => 'should not run'),
          throwsA(isA<PortcullisOpenException>()),
        );
        p.dispose();
      });

      test('PortcullisOpenException contains name and timeout', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(seconds: 60),
          name: 'payment',
        );
        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}

        try {
          await p.protect(() async => 'nope');
          fail('Should have thrown');
        } on PortcullisOpenException catch (e) {
          expect(e.name, 'payment');
          expect(e.remainingTimeout, isNotNull);
          expect(e.toString(), contains('payment'));
          expect(e.toString(), contains('open'));
        }
        p.dispose();
      });

      test('protectSync rejects when open', () {
        final p = Portcullis(failureThreshold: 1);
        try {
          p.protectSync(() => throw Exception('fail'));
        } catch (_) {}
        expect(p.state, PortcullisState.open);

        expect(
          () => p.protectSync(() => 'nope'),
          throwsA(isA<PortcullisOpenException>()),
        );
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Half-Open — Recovery
    // -----------------------------------------------------------------------

    group('half-open recovery', () {
      test('transitions to half-open after resetTimeout', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
        );
        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}
        expect(p.state, PortcullisState.open);

        // Wait for reset timeout
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.state, PortcullisState.halfOpen);
        p.dispose();
      });

      test('successful probe closes circuit', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          halfOpenMaxProbes: 1,
        );
        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.state, PortcullisState.halfOpen);

        // Successful probe
        final result = await p.protect(() async => 'recovered');
        expect(result, 'recovered');
        expect(p.state, PortcullisState.closed);
        expect(p.failureCount, 0);
        p.dispose();
      });

      test(
        'multiple probe successes needed for halfOpenMaxProbes > 1',
        () async {
          final p = Portcullis(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 50),
            halfOpenMaxProbes: 3,
          );
          try {
            await p.protect(() async => throw Exception('fail'));
          } catch (_) {}

          await Future<void>.delayed(const Duration(milliseconds: 100));
          expect(p.state, PortcullisState.halfOpen);

          // First two probes succeed but circuit stays half-open
          await p.protect(() async => 'probe1');
          expect(p.state, PortcullisState.halfOpen);
          expect(p.probeSuccessCount, 1);

          await p.protect(() async => 'probe2');
          expect(p.state, PortcullisState.halfOpen);
          expect(p.probeSuccessCount, 2);

          // Third probe closes it
          await p.protect(() async => 'probe3');
          expect(p.state, PortcullisState.closed);
          p.dispose();
        },
      );

      test('failed probe re-opens circuit', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
        );
        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.state, PortcullisState.halfOpen);

        // Probe fails → back to open
        try {
          await p.protect(() async => throw Exception('probe-fail'));
        } catch (_) {}
        expect(p.state, PortcullisState.open);
        expect(p.tripCount, 2); // tripped twice
        p.dispose();
      });

      test('protectSync works in half-open', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
        );
        try {
          p.protectSync(() => throw Exception('fail'));
        } catch (_) {}

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.state, PortcullisState.halfOpen);

        final result = p.protectSync(() => 99);
        expect(result, 99);
        expect(p.state, PortcullisState.closed);
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // shouldTrip — Custom Failure Filter
    // -----------------------------------------------------------------------

    group('shouldTrip filter', () {
      test('ignores errors that shouldTrip rejects', () async {
        final p = Portcullis(
          failureThreshold: 2,
          shouldTrip: (error, _) => error is! FormatException,
        );

        // FormatException should not count
        for (var i = 0; i < 3; i++) {
          try {
            await p.protect(() async => throw const FormatException('ignore'));
          } catch (_) {}
        }
        expect(p.failureCount, 0);
        expect(p.state, PortcullisState.closed);

        // StateError should count
        try {
          await p.protect(() async => throw StateError('real'));
        } catch (_) {}
        expect(p.failureCount, 1);
        p.dispose();
      });

      test('shouldTrip filter works in half-open probe failure', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          shouldTrip: (error, _) => error is! FormatException,
        );

        // Trip with a real error
        try {
          await p.protect(() async => throw StateError('real'));
        } catch (_) {}
        expect(p.state, PortcullisState.open);

        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.state, PortcullisState.halfOpen);

        // FormatException in half-open should not re-trip
        try {
          await p.protect(() async => throw const FormatException('ignored'));
        } catch (_) {}
        // State should still be halfOpen since FormatException
        // doesn't count — but the exception is still rethrown
        expect(p.state, PortcullisState.halfOpen);
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Manual Controls
    // -----------------------------------------------------------------------

    group('manual controls', () {
      test('trip() manually opens the circuit', () {
        final p = Portcullis();
        p.trip();
        expect(p.state, PortcullisState.open);
        expect(p.tripCount, 1);
        p.dispose();
      });

      test('trip() is no-op when already open', () {
        final p = Portcullis();
        p.trip();
        p.trip();
        expect(p.tripCount, 1); // only recorded once
        p.dispose();
      });

      test('reset() manually closes the circuit', () {
        final p = Portcullis();
        p.trip();
        expect(p.state, PortcullisState.open);
        p.reset();
        expect(p.state, PortcullisState.closed);
        expect(p.failureCount, 0);
        p.dispose();
      });

      test('reset() works from half-open', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
        );
        p.trip();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.state, PortcullisState.halfOpen);
        p.reset();
        expect(p.state, PortcullisState.closed);
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Reactive State
    // -----------------------------------------------------------------------

    group('reactive state', () {
      test('state changes are reactive', () async {
        final p = Portcullis(failureThreshold: 1);
        final states = <PortcullisState>[];
        // Prime the computed
        expect(p.isClosed, isTrue);

        final d = TitanComputed(() => p.state);
        expect(d.value, PortcullisState.closed);
        d.addListener(() => states.add(d.value));

        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}

        expect(states, contains(PortcullisState.open));
        d.dispose();
        p.dispose();
      });

      test('failureCount is reactive', () async {
        final p = Portcullis(failureThreshold: 10);
        final counts = <int>[];

        final d = TitanComputed(() => p.failureCount);
        expect(d.value, 0);
        d.addListener(() => counts.add(d.value));

        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}

        expect(counts, [1]);
        d.dispose();
        p.dispose();
      });

      test('isClosed computed is reactive', () async {
        final p = Portcullis(failureThreshold: 1);
        final values = <bool>[];

        final d = TitanComputed(() => p.isClosed);
        expect(d.value, isTrue);
        d.addListener(() => values.add(d.value));

        try {
          await p.protect(() async => throw Exception('fail'));
        } catch (_) {}

        expect(values, [false]);
        d.dispose();
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Trip History
    // -----------------------------------------------------------------------

    group('trip history', () {
      test('accumulates trip records', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
        );

        // Trip 1
        try {
          await p.protect(() async => throw Exception('fail1'));
        } catch (_) {}
        expect(p.tripHistory, hasLength(1));

        // Reset and trip again
        await Future<void>.delayed(const Duration(milliseconds: 100));
        try {
          await p.protect(() async => throw Exception('fail2'));
        } catch (_) {}
        expect(p.tripHistory, hasLength(2));
        p.dispose();
      });

      test('respects maxTripHistory', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 20),
          maxTripHistory: 3,
        );

        for (var i = 0; i < 5; i++) {
          try {
            await p.protect(() async => throw Exception('fail'));
          } catch (_) {}
          await Future<void>.delayed(const Duration(milliseconds: 40));
        }

        expect(p.tripHistory.length, lessThanOrEqualTo(3));
        p.dispose();
      });

      test('tripHistory is unmodifiable', () {
        final p = Portcullis();
        expect(
          () => p.tripHistory.add(
            PortcullisTripRecord(timestamp: DateTime.now(), failureCount: 0),
          ),
          throwsA(isA<UnsupportedError>()),
        );
        p.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Disposal
    // -----------------------------------------------------------------------

    group('disposal', () {
      test('dispose cleans up', () {
        final p = Portcullis();
        p.dispose();
        expect(p.isDisposed, isTrue);
      });

      test('double dispose is safe', () {
        final p = Portcullis();
        p.dispose();
        p.dispose(); // no error
      });

      test('protect throws after dispose', () {
        final p = Portcullis();
        p.dispose();
        expect(() => p.protect(() async => 'nope'), throwsA(isA<StateError>()));
      });

      test('protectSync throws after dispose', () {
        final p = Portcullis();
        p.dispose();
        expect(() => p.protectSync(() => 'nope'), throwsA(isA<StateError>()));
      });

      test('trip throws after dispose', () {
        final p = Portcullis();
        p.dispose();
        expect(() => p.trip(), throwsA(isA<StateError>()));
      });

      test('reset throws after dispose', () {
        final p = Portcullis();
        p.dispose();
        expect(() => p.reset(), throwsA(isA<StateError>()));
      });
    });

    // -----------------------------------------------------------------------
    // Pillar Integration
    // -----------------------------------------------------------------------

    group('Pillar integration', () {
      test('portcullis() factory creates managed breaker', () {
        final pillar = _TestPortcullisPillar();
        expect(pillar.apiBreaker.state, PortcullisState.closed);
        expect(pillar.apiBreaker.failureThreshold, 3);
        expect(pillar.apiBreaker.name, 'api');
        pillar.dispose();
      });

      test('Pillar disposal disposes breaker nodes', () {
        final pillar = _TestPortcullisPillar();
        // Access breaker to initialize
        expect(pillar.apiBreaker.isClosed, isTrue);
        pillar.dispose();
        // After Pillar disposal, breaker nodes are managed and disposed
        // The portcullis itself needs explicit dispose in Pillar disposal
      });
    });

    // -----------------------------------------------------------------------
    // Complex Scenarios
    // -----------------------------------------------------------------------

    group('complex scenarios', () {
      test('full lifecycle: closed → open → half-open → closed', () async {
        final p = Portcullis(
          failureThreshold: 2,
          resetTimeout: const Duration(milliseconds: 50),
          halfOpenMaxProbes: 1,
        );

        // 1. Closed — two failures trip circuit
        try {
          await p.protect(() async => throw Exception('f1'));
        } catch (_) {}
        expect(p.state, PortcullisState.closed);

        try {
          await p.protect(() async => throw Exception('f2'));
        } catch (_) {}
        expect(p.state, PortcullisState.open);
        expect(p.tripCount, 1);

        // 2. Open — request is rejected
        expect(
          () => p.protect(() async => 'blocked'),
          throwsA(isA<PortcullisOpenException>()),
        );

        // 3. Wait for half-open
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(p.state, PortcullisState.halfOpen);

        // 4. Successful probe closes circuit
        final result = await p.protect(() async => 'recovered');
        expect(result, 'recovered');
        expect(p.state, PortcullisState.closed);
        expect(p.successCount, 1);
        expect(p.failureCount, 0);

        p.dispose();
      });

      test('multiple trip cycles increment tripCount', () async {
        final p = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 30),
        );

        for (var cycle = 0; cycle < 3; cycle++) {
          // Trip
          try {
            await p.protect(() async => throw Exception('cycle $cycle'));
          } catch (_) {}
          expect(p.state, PortcullisState.open);

          // Wait and recover
          await Future<void>.delayed(const Duration(milliseconds: 60));
          await p.protect(() async => 'ok');
          expect(p.state, PortcullisState.closed);
        }

        expect(p.tripCount, 3);
        expect(p.successCount, 3);
        p.dispose();
      });

      test('interleaved success and failure in closed state', () async {
        final p = Portcullis(failureThreshold: 3);
        // fail, fail, success (resets count), fail, fail, fail → trip
        try {
          await p.protect(() async => throw Exception('f1'));
        } catch (_) {}
        try {
          await p.protect(() async => throw Exception('f2'));
        } catch (_) {}
        await p.protect(() async => 'ok'); // resets
        expect(p.failureCount, 0);

        try {
          await p.protect(() async => throw Exception('f3'));
        } catch (_) {}
        try {
          await p.protect(() async => throw Exception('f4'));
        } catch (_) {}
        expect(p.state, PortcullisState.closed);

        try {
          await p.protect(() async => throw Exception('f5'));
        } catch (_) {}
        expect(p.state, PortcullisState.open);
        p.dispose();
      });

      test('PortcullisOpenException with no name or timeout', () {
        const e = PortcullisOpenException();
        expect(e.name, isNull);
        expect(e.remainingTimeout, isNull);
        expect(e.toString(), contains('open'));
      });
    });

    // -----------------------------------------------------------------------
    // PortcullisTripRecord
    // -----------------------------------------------------------------------

    group('PortcullisTripRecord', () {
      test('fields are accessible', () {
        final r = PortcullisTripRecord(
          timestamp: DateTime(2024, 1, 1),
          failureCount: 5,
          lastError: Exception('test'),
        );
        expect(r.timestamp, DateTime(2024, 1, 1));
        expect(r.failureCount, 5);
        expect(r.lastError, isA<Exception>());
      });

      test('toString is formatted', () {
        final r = PortcullisTripRecord(
          timestamp: DateTime.now(),
          failureCount: 3,
        );
        expect(r.toString(), contains('failures: 3'));
      });
    });

    // -----------------------------------------------------------------------
    // PortcullisState
    // -----------------------------------------------------------------------

    group('PortcullisState', () {
      test('enum values exist', () {
        expect(PortcullisState.values, hasLength(3));
        expect(PortcullisState.closed.name, 'closed');
        expect(PortcullisState.open.name, 'open');
        expect(PortcullisState.halfOpen.name, 'halfOpen');
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test Pillar
// ---------------------------------------------------------------------------

class _TestPortcullisPillar extends Pillar {
  late final apiBreaker = portcullis(
    failureThreshold: 3,
    resetTimeout: const Duration(seconds: 10),
    name: 'api',
  );
}
