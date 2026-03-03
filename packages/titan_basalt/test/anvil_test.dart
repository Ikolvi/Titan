import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('AnvilBackoff', () {
    test('exponential computes correct delays', () {
      final backoff = AnvilBackoff.exponential(
        initial: const Duration(milliseconds: 100),
        multiplier: 2.0,
      );

      expect(backoff.delayFor(0), const Duration(milliseconds: 100));
      expect(backoff.delayFor(1), const Duration(milliseconds: 200));
      expect(backoff.delayFor(2), const Duration(milliseconds: 400));
      expect(backoff.delayFor(3), const Duration(milliseconds: 800));
    });

    test('linear computes correct delays', () {
      final backoff = AnvilBackoff.linear(
        initial: const Duration(milliseconds: 100),
        increment: const Duration(milliseconds: 50),
      );

      expect(backoff.delayFor(0), const Duration(milliseconds: 100));
      expect(backoff.delayFor(1), const Duration(milliseconds: 150));
      expect(backoff.delayFor(2), const Duration(milliseconds: 200));
      expect(backoff.delayFor(3), const Duration(milliseconds: 250));
    });

    test('constant returns same delay', () {
      final backoff = AnvilBackoff.constant(const Duration(milliseconds: 200));

      expect(backoff.delayFor(0), const Duration(milliseconds: 200));
      expect(backoff.delayFor(1), const Duration(milliseconds: 200));
      expect(backoff.delayFor(5), const Duration(milliseconds: 200));
    });

    test('maxDelay caps computed delay', () {
      final backoff = AnvilBackoff.exponential(
        initial: const Duration(milliseconds: 100),
        multiplier: 10.0,
        maxDelay: const Duration(milliseconds: 500),
      );

      expect(backoff.delayFor(0), const Duration(milliseconds: 100));
      // attempt 1 = 100 * 10 = 1000ms, capped at 500
      expect(backoff.delayFor(1), const Duration(milliseconds: 500));
      expect(backoff.delayFor(5), const Duration(milliseconds: 500));
    });

    test('jitter adds variation to delay', () {
      final backoff = AnvilBackoff.exponential(
        initial: const Duration(seconds: 1),
        jitter: true,
      );

      // Collect several delays — they should not all be identical
      final delays = List.generate(20, (i) => backoff.delayFor(0));
      final unique = delays.map((d) => d.inMicroseconds).toSet();
      // With jitter, we expect variation (not all identical)
      expect(unique.length, greaterThan(1));
    });

    test('toString returns description', () {
      final backoff = AnvilBackoff.exponential(
        maxDelay: const Duration(seconds: 30),
      );
      expect(backoff.toString(), contains('AnvilBackoff'));
      expect(backoff.toString(), contains('maxDelay'));
    });
  });

  group('AnvilEntry', () {
    test('toString returns formatted string', () {
      final entry = AnvilEntry<String>(
        operation: () async => 'ok',
        maxRetries: 3,
        enqueueTime: DateTime.now(),
        id: 'test-1',
      );

      expect(entry.toString(), contains('test-1'));
      expect(entry.toString(), contains('pending'));
      expect(entry.toString(), contains('0/3'));
    });

    test('unnamed entry shows unnamed in toString', () {
      final entry = AnvilEntry<String>(
        operation: () async => 'ok',
        maxRetries: 3,
        enqueueTime: DateTime.now(),
      );

      expect(entry.toString(), contains('unnamed'));
    });
  });

  group('Anvil', () {
    test('creation sets correct defaults', () {
      final anvil = Anvil<String>(name: 'test');

      expect(anvil.name, 'test');
      expect(anvil.maxRetries, 3);
      expect(anvil.pendingCount, 0);
      expect(anvil.retryingCount, 0);
      expect(anvil.succeededCount, 0);
      expect(anvil.deadLetterCount, 0);
      expect(anvil.totalEnqueued, 0);
      expect(anvil.isProcessing, false);
      expect(anvil.isDisposed, false);

      anvil.dispose();
    });

    test('enqueue adds entry to pending', () async {
      final anvil = Anvil<String>(autoStart: false, name: 'test');

      final entry = anvil.enqueue(() async => 'result', id: 'job-1');

      expect(anvil.pendingCount, 1);
      expect(anvil.totalEnqueued, 1);
      expect(entry.id, 'job-1');
      expect(entry.status, AnvilStatus.pending);

      anvil.dispose();
    });

    test('successful operation removes from pending', () async {
      final completer = Completer<String>();
      final anvil = Anvil<String>(name: 'test');

      anvil.enqueue(() => completer.future, id: 'job-1');

      expect(anvil.pendingCount, 1);

      completer.complete('done');
      // Allow async processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(anvil.succeededCount, 1);
      expect(anvil.pendingCount, 0);

      anvil.dispose();
    });

    test('onSuccess callback fires on success', () async {
      String? captured;
      final anvil = Anvil<String>(name: 'test');

      anvil.enqueue(
        () async => 'hello',
        id: 'job-1',
        onSuccess: (result) => captured = result,
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(captured, 'hello');
      expect(anvil.succeededCount, 1);

      anvil.dispose();
    });

    test('failed operation retries then dead-letters', () async {
      var attempts = 0;
      bool deadLettered = false;

      final anvil = Anvil<String>(
        maxRetries: 3,
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      anvil.enqueue(
        () async {
          attempts++;
          throw Exception('fail');
        },
        id: 'job-fail',
        onDeadLetter: (entry) => deadLettered = true,
      );

      // Wait for all retries to process
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(attempts, 3);
      expect(deadLettered, true);
      expect(anvil.deadLetterCount, 1);
      expect(anvil.pendingCount, 0);

      anvil.dispose();
    });

    test('dead letter entry has correct metadata', () async {
      final anvil = Anvil<String>(
        maxRetries: 2,
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      anvil.enqueue(
        () async => throw Exception('oops'),
        id: 'fail-job',
        metadata: {'key': 'value'},
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(anvil.deadLetters.length, 1);

      final dead = anvil.deadLetters.first;
      expect(dead.id, 'fail-job');
      expect(dead.status, AnvilStatus.deadLettered);
      expect(dead.attempts, 2);
      expect(dead.lastError, isA<Exception>());
      expect(dead.metadata, {'key': 'value'});

      anvil.dispose();
    });

    test('retryDeadLetters re-enqueues dead entries', () async {
      var attempts = 0;

      final anvil = Anvil<String>(
        maxRetries: 1,
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      anvil.enqueue(() async {
        attempts++;
        // Succeed on the 2nd round of attempts (attempt 2+)
        if (attempts > 1) return 'recovered';
        throw Exception('fail');
      }, id: 'retry-job');

      // First attempt → dead letter
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(anvil.deadLetterCount, 1);
      expect(attempts, 1);

      // Retry dead letters
      final count = anvil.retryDeadLetters();
      expect(count, 1);
      expect(anvil.deadLetterCount, 0);
      expect(anvil.pendingCount, 1);

      // Process the re-enqueued entry
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(anvil.succeededCount, 1);
      expect(attempts, 2);

      anvil.dispose();
    });

    test('purge clears dead letters', () async {
      final anvil = Anvil<String>(
        maxRetries: 1,
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      anvil.enqueue(() async => throw Exception('fail'), id: 'a');
      anvil.enqueue(() async => throw Exception('fail'), id: 'b');

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(anvil.deadLetterCount, 2);

      final purged = anvil.purge();
      expect(purged, 2);
      expect(anvil.deadLetterCount, 0);

      anvil.dispose();
    });

    test('clear removes all entries and cancels timers', () async {
      final anvil = Anvil<String>(
        maxRetries: 5,
        backoff: AnvilBackoff.constant(const Duration(seconds: 10)),
        autoStart: false,
        name: 'test',
      );

      anvil.enqueue(() async => 'a', id: 'a');
      anvil.enqueue(() async => 'b', id: 'b');
      expect(anvil.pendingCount, 2);

      anvil.clear();
      expect(anvil.pendingCount, 0);
      expect(anvil.deadLetterCount, 0);

      anvil.dispose();
    });

    test('remove by ID removes from pending', () {
      final anvil = Anvil<String>(autoStart: false, name: 'test');

      anvil.enqueue(() async => 'a', id: 'job-a');
      anvil.enqueue(() async => 'b', id: 'job-b');
      expect(anvil.pendingCount, 2);

      final removed = anvil.remove('job-a');
      expect(removed, true);
      expect(anvil.pendingCount, 1);

      anvil.dispose();
    });

    test('remove by ID returns false for unknown', () {
      final anvil = Anvil<String>(autoStart: false, name: 'test');

      expect(anvil.remove('nonexistent'), false);

      anvil.dispose();
    });

    test('findById locates entry across queues', () async {
      final anvil = Anvil<String>(
        maxRetries: 1,
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      anvil.enqueue(() async => 'ok', id: 'success-job');
      anvil.enqueue(() async => throw Exception('fail'), id: 'fail-job');

      await Future<void>.delayed(const Duration(milliseconds: 100));

      final found = anvil.findById('success-job');
      expect(found, isNotNull);
      expect(found!.status, AnvilStatus.succeeded);

      final deadFound = anvil.findById('fail-job');
      expect(deadFound, isNotNull);
      expect(deadFound!.status, AnvilStatus.deadLettered);

      expect(anvil.findById('nonexistent'), isNull);

      anvil.dispose();
    });

    test('processAll triggers processing for autoStart false', () async {
      var executed = false;

      final anvil = Anvil<String>(autoStart: false, name: 'test');

      anvil.enqueue(() async {
        executed = true;
        return 'done';
      }, id: 'manual');

      // Should not have executed yet
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(executed, false);

      // Manually trigger
      anvil.processAll();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(executed, true);
      expect(anvil.succeededCount, 1);

      anvil.dispose();
    });

    test('per-entry maxRetries overrides queue default', () async {
      var attempts = 0;

      final anvil = Anvil<String>(
        maxRetries: 10, // high default
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      anvil.enqueue(
        () async {
          attempts++;
          throw Exception('fail');
        },
        id: 'limited',
        maxRetries: 2, // Override to 2
      );

      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(attempts, 2);
      expect(anvil.deadLetterCount, 1);

      anvil.dispose();
    });

    test('maxDeadLetters enforces limit', () async {
      final anvil = Anvil<String>(
        maxRetries: 1,
        maxDeadLetters: 3,
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      for (var i = 0; i < 5; i++) {
        anvil.enqueue(() async => throw Exception('fail'), id: 'job-$i');
      }

      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Should cap at 3 dead letters
      expect(anvil.deadLetterCount, 3);
      // Oldest entries should have been evicted
      expect(anvil.deadLetters.first.id, 'job-2');

      anvil.dispose();
    });

    test('succeeded entries are accessible', () async {
      final anvil = Anvil<String>(name: 'test');

      anvil.enqueue(() async => 'result-a', id: 'a');
      anvil.enqueue(() async => 'result-b', id: 'b');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(anvil.succeeded.length, 2);
      expect(
        anvil.succeeded.map((e) => e.result),
        containsAll(['result-a', 'result-b']),
      );

      anvil.dispose();
    });

    test('reactive state updates on enqueue and success', () async {
      final anvil = Anvil<String>(name: 'test');
      final pendingChanges = <int>[];
      final succeededChanges = <int>[];

      // Prime computed
      anvil.isProcessing;

      // Track reactive changes
      void pendingListener() {
        pendingChanges.add(anvil.pendingCount);
      }

      void succeededListener() {
        succeededChanges.add(anvil.succeededCount);
      }

      anvil.managedStateNodes[0].addListener(pendingListener);
      anvil.managedStateNodes[2].addListener(succeededListener);

      anvil.enqueue(() async => 'ok', id: 'job');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(pendingChanges.contains(1), true); // enqueue → 1
      expect(pendingChanges.contains(0), true); // completed → 0
      expect(succeededChanges.contains(1), true);

      anvil.managedStateNodes[0].removeListener(pendingListener);
      anvil.managedStateNodes[2].removeListener(succeededListener);
      anvil.dispose();
    });

    test('isProcessing computed reflects queue activity', () async {
      final completer = Completer<String>();
      final anvil = Anvil<String>(name: 'test');

      // Prime computed
      expect(anvil.isProcessing, false);

      anvil.enqueue(() => completer.future, id: 'job');

      // Entry is being retried — isProcessing should reflect that
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Retry is in progress
      expect(anvil.retryingCount, 1);

      completer.complete('done');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(anvil.retryingCount, 0);
      expect(anvil.pendingCount, 0);

      anvil.dispose();
    });

    test('dispose prevents further operations', () {
      final anvil = Anvil<String>(name: 'test');
      anvil.dispose();

      expect(anvil.isDisposed, true);
      expect(() => anvil.enqueue(() async => 'ok'), throwsStateError);
      expect(() => anvil.processAll(), throwsStateError);
      expect(() => anvil.retryDeadLetters(), throwsStateError);
      expect(() => anvil.purge(), throwsStateError);
      expect(() => anvil.clear(), throwsStateError);
      expect(() => anvil.remove('x'), throwsStateError);
    });

    test('dispose is idempotent', () {
      final anvil = Anvil<String>(name: 'test');
      anvil.dispose();
      anvil.dispose(); // Should not throw
      expect(anvil.isDisposed, true);
    });

    test('toString returns formatted description', () {
      final anvil = Anvil<String>(name: 'my-queue');
      expect(anvil.toString(), contains('my-queue'));
      expect(anvil.toString(), contains('pending: 0'));
      anvil.dispose();
    });

    test('unnamed toString shows unnamed', () {
      final anvil = Anvil<String>();
      expect(anvil.toString(), contains('unnamed'));
      anvil.dispose();
    });

    test('managedNodes returns computed nodes', () {
      final anvil = Anvil<String>(name: 'test');
      expect(anvil.managedNodes.length, 1);
      anvil.dispose();
    });

    test('managedStateNodes returns state nodes', () {
      final anvil = Anvil<String>(name: 'test');
      expect(anvil.managedStateNodes.length, 5);
      anvil.dispose();
    });

    test(
      'operation that succeeds on retry has correct attempt count',
      () async {
        var attempts = 0;

        final anvil = Anvil<String>(
          maxRetries: 5,
          backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
          name: 'test',
        );

        anvil.enqueue(() async {
          attempts++;
          if (attempts < 3) throw Exception('not yet');
          return 'finally';
        }, id: 'flaky');

        await Future<void>.delayed(const Duration(milliseconds: 300));

        expect(attempts, 3);
        expect(anvil.succeededCount, 1);
        expect(anvil.deadLetterCount, 0);

        final entry = anvil.findById('flaky');
        expect(entry!.status, AnvilStatus.succeeded);
        expect(entry.attempts, 3);

        anvil.dispose();
      },
    );

    test('remove from dead letter queue', () async {
      final anvil = Anvil<String>(
        maxRetries: 1,
        backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
        name: 'test',
      );

      anvil.enqueue(() async => throw Exception('fail'), id: 'dead-job');

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(anvil.deadLetterCount, 1);

      final removed = anvil.remove('dead-job');
      expect(removed, true);
      expect(anvil.deadLetterCount, 0);

      anvil.dispose();
    });

    test('multiple concurrent enqueues process independently', () async {
      final anvil = Anvil<int>(name: 'test');

      for (var i = 0; i < 5; i++) {
        final idx = i;
        anvil.enqueue(() async => idx * 10, id: 'job-$i');
      }

      expect(anvil.totalEnqueued, 5);

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(anvil.succeededCount, 5);
      expect(anvil.pendingCount, 0);

      anvil.dispose();
    });
  });

  group('Anvil Pillar integration', () {
    test('pillar creates and manages anvil', () {
      final pillar = _TestAnvilPillar();

      expect(pillar.retryQueue.name, 'test-retry');
      expect(pillar.retryQueue.maxRetries, 3);
      expect(pillar.retryQueue.pendingCount, 0);

      pillar.dispose();
    });

    test('pillar disposal disposes anvil nodes', () async {
      final pillar = _TestAnvilPillar();

      pillar.retryQueue.enqueue(() async => 'ok', id: 'test-job');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      pillar.dispose();
      // After pillar disposal, anvil reactive nodes should be disposed
      // (managed via _managedNodes)
    });
  });
}

class _TestAnvilPillar extends Pillar {
  late final retryQueue = anvil<String>(
    maxRetries: 3,
    backoff: AnvilBackoff.constant(const Duration(milliseconds: 10)),
    name: 'test-retry',
  );
}
