import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Pyre', () {
    // -----------------------------------------------------------------------
    // Construction & defaults
    // -----------------------------------------------------------------------

    test('creates with default settings', () {
      final q = Pyre<int>();
      expect(q.status, PyreStatus.idle);
      expect(q.queueLength, 0);
      expect(q.runningCount, 0);
      expect(q.completedCount, 0);
      expect(q.failedCount, 0);
      expect(q.totalEnqueued, 0);
      expect(q.progress, 0.0);
      expect(q.hasPending, isFalse);
      expect(q.isProcessing, isFalse);
      expect(q.isDisposed, isFalse);
      expect(q.concurrency, 3);
      q.dispose();
    });

    test('creates with custom settings', () {
      final q = Pyre<int>(
        concurrency: 5,
        maxQueueSize: 100,
        maxRetries: 2,
        retryDelay: const Duration(seconds: 1),
        autoStart: false,
        name: 'test-queue',
      );
      expect(q.concurrency, 5);
      expect(q.name, 'test-queue');
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // PyrePriority
    // -----------------------------------------------------------------------

    test('PyrePriority has correct ordering', () {
      expect(PyrePriority.critical.rank, 0);
      expect(PyrePriority.high.rank, 1);
      expect(PyrePriority.normal.rank, 2);
      expect(PyrePriority.low.rank, 3);
      expect(PyrePriority.critical.compareTo(PyrePriority.low), lessThan(0));
      expect(PyrePriority.low.compareTo(PyrePriority.critical), greaterThan(0));
    });

    // -----------------------------------------------------------------------
    // Basic enqueue & execution
    // -----------------------------------------------------------------------

    test('enqueues and executes a single task', () async {
      final q = Pyre<int>(name: 'single');
      final result = await q.enqueue(() async => 42);
      expect(result, 42);
      expect(q.completedCount, 1);
      expect(q.totalEnqueued, 1);
      q.dispose();
    });

    test('enqueues multiple tasks', () async {
      final q = Pyre<int>(concurrency: 1, name: 'multi');
      final results = <int>[];
      final f1 = q.enqueue(() async => 1);
      final f2 = q.enqueue(() async => 2);
      final f3 = q.enqueue(() async => 3);
      results.addAll(await Future.wait([f1, f2, f3]));
      expect(results, containsAll([1, 2, 3]));
      expect(q.completedCount, 3);
      q.dispose();
    });

    test('respects concurrency limit', () async {
      var maxConcurrent = 0;
      var current = 0;
      final q = Pyre<int>(concurrency: 2, name: 'conc');

      Future<int> task(int id) async {
        current++;
        if (current > maxConcurrent) maxConcurrent = current;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        current--;
        return id;
      }

      final futures = [
        q.enqueue(() => task(1)),
        q.enqueue(() => task(2)),
        q.enqueue(() => task(3)),
        q.enqueue(() => task(4)),
      ];
      await Future.wait(futures);
      expect(maxConcurrent, lessThanOrEqualTo(2));
      expect(q.completedCount, 4);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Priority ordering
    // -----------------------------------------------------------------------

    test('executes tasks in priority order', () async {
      final order = <String>[];
      final q = Pyre<void>(concurrency: 1, autoStart: false, name: 'prio');

      q.enqueue(
        () async => order.add('low'),
        priority: PyrePriority.low,
        name: 'low',
      );
      q.enqueue(
        () async => order.add('critical'),
        priority: PyrePriority.critical,
        name: 'critical',
      );
      q.enqueue(
        () async => order.add('normal'),
        priority: PyrePriority.normal,
        name: 'normal',
      );
      q.enqueue(
        () async => order.add('high'),
        priority: PyrePriority.high,
        name: 'high',
      );

      q.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(order, ['critical', 'high', 'normal', 'low']);
      q.dispose();
    });

    test('FIFO within same priority', () async {
      final order = <int>[];
      final q = Pyre<void>(concurrency: 1, autoStart: false, name: 'fifo');

      for (var i = 1; i <= 5; i++) {
        final val = i;
        q.enqueue(() async => order.add(val));
      }

      q.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(order, [1, 2, 3, 4, 5]);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Backpressure
    // -----------------------------------------------------------------------

    test('throws on backpressure when queue is full', () {
      final q = Pyre<int>(
        concurrency: 1,
        maxQueueSize: 2,
        autoStart: false,
        name: 'bp',
      );

      q.enqueue(() async => 1);
      q.enqueue(() async => 2);
      expect(
        () => q.enqueue(() async => 3),
        throwsA(isA<PyreBackpressureException>()),
      );
      q.dispose();
    });

    test('PyreBackpressureException has correct message', () {
      const e = PyreBackpressureException(maxQueueSize: 10, currentSize: 10);
      expect(e.toString(), contains('queue full'));
      expect(e.toString(), contains('10/10'));
    });

    // -----------------------------------------------------------------------
    // Pause / Resume
    // -----------------------------------------------------------------------

    test('pause stops dequeuing new tasks', () async {
      final executed = <int>[];
      final q = Pyre<void>(concurrency: 1, name: 'pause');

      q.enqueue(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        executed.add(1);
      });
      q.enqueue(() async => executed.add(2));
      q.enqueue(() async => executed.add(3));

      // Let first task start
      await Future<void>.delayed(const Duration(milliseconds: 10));
      q.pause();
      expect(q.status, PyreStatus.paused);

      // Wait for first task to finish
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // Only task 1 should have run (was already in-flight)
      expect(executed, [1]);

      // Resume
      q.resume();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(executed, [1, 2, 3]);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Cancel
    // -----------------------------------------------------------------------

    test('cancels a specific pending task', () async {
      final q = Pyre<int>(concurrency: 1, autoStart: false, name: 'cancel');

      final f1 = q.enqueue(() async => 1, id: 'task-1');
      final f2 = q.enqueue(() async => 2, id: 'task-2');

      final cancelled = q.cancel('task-1');
      expect(cancelled, isTrue);
      expect(q.queueLength, 1);

      q.start();
      // f1 should error (cancelled)
      expect(f1, throwsA(isA<StateError>()));
      expect(await f2, 2);
      q.dispose();
    });

    test('cancel returns false for non-existent task', () {
      final q = Pyre<int>(name: 'cancel-ne');
      expect(q.cancel('nonexistent'), isFalse);
      q.dispose();
    });

    test('cancelAll cancels all pending tasks', () {
      final q = Pyre<int>(concurrency: 1, autoStart: false, name: 'cancel-all');

      q.enqueue(() async => 1);
      q.enqueue(() async => 2);
      q.enqueue(() async => 3);

      final count = q.cancelAll();
      expect(count, 3);
      expect(q.queueLength, 0);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Error handling
    // -----------------------------------------------------------------------

    test('handles task failures', () async {
      final q = Pyre<int>(name: 'fail');

      expect(
        q.enqueue(() async => throw Exception('boom')),
        throwsA(isA<Exception>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(q.failedCount, 1);
      q.dispose();
    });

    test('retries failed tasks', () async {
      var attempts = 0;
      final q = Pyre<int>(
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 10),
        name: 'retry',
      );

      final result = await q.enqueue(() async {
        attempts++;
        if (attempts < 3) throw Exception('retry me');
        return 42;
      });

      expect(result, 42);
      expect(attempts, 3); // 1 initial + 2 retries
      expect(q.completedCount, 1);
      q.dispose();
    });

    test('fails after exhausting retries', () async {
      final q = Pyre<int>(
        maxRetries: 1,
        retryDelay: const Duration(milliseconds: 10),
        name: 'exhaust',
      );

      expect(
        q.enqueue(() async => throw Exception('permanent')),
        throwsA(isA<Exception>()),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(q.failedCount, 1);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Callbacks
    // -----------------------------------------------------------------------

    test('calls onTaskComplete', () async {
      String? completedId;
      int? completedValue;
      final q = Pyre<int>(
        onTaskComplete: (id, value) {
          completedId = id;
          completedValue = value;
        },
        name: 'cb-complete',
      );

      await q.enqueue(() async => 99, id: 'my-task');
      expect(completedId, 'my-task');
      expect(completedValue, 99);
      q.dispose();
    });

    test('calls onTaskFailed', () async {
      String? failedId;
      Object? failedError;
      final q = Pyre<int>(
        onTaskFailed: (id, error) {
          failedId = id;
          failedError = error;
        },
        name: 'cb-fail',
      );

      try {
        await q.enqueue(() async => throw Exception('oops'), id: 'fail-task');
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(failedId, 'fail-task');
      expect(failedError, isA<Exception>());
      q.dispose();
    });

    test('calls onDrained when queue empties', () async {
      var drained = false;
      final q = Pyre<int>(onDrained: () => drained = true, name: 'cb-drain');

      await q.enqueue(() async => 1);
      await q.enqueue(() async => 2);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(drained, isTrue);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // autoStart: false
    // -----------------------------------------------------------------------

    test('does not start processing when autoStart is false', () async {
      final q = Pyre<int>(autoStart: false, name: 'no-auto');
      q.enqueue(() async => 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(q.status, PyreStatus.idle);
      expect(q.queueLength, 1);
      expect(q.completedCount, 0);

      q.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(q.completedCount, 1);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // enqueueAll
    // -----------------------------------------------------------------------

    test('enqueueAll enqueues multiple tasks', () async {
      final q = Pyre<int>(name: 'enq-all');
      final futures = q.enqueueAll([
        (execute: () async => 1, priority: PyrePriority.normal, name: 'a'),
        (execute: () async => 2, priority: PyrePriority.high, name: 'b'),
        (execute: () async => 3, priority: PyrePriority.low, name: 'c'),
      ]);

      final results = await Future.wait(futures);
      expect(results, containsAll([1, 2, 3]));
      expect(q.completedCount, 3);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Stop
    // -----------------------------------------------------------------------

    test('stop prevents new tasks', () async {
      final q = Pyre<int>(name: 'stop');
      await q.stop();
      expect(q.status, PyreStatus.stopped);
      expect(() => q.enqueue(() async => 1), throwsA(isA<StateError>()));
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Reset
    // -----------------------------------------------------------------------

    test('reset clears counts and returns to idle', () async {
      final q = Pyre<int>(name: 'reset');
      await q.enqueue(() async => 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(q.completedCount, 1);
      expect(q.totalEnqueued, 1);

      q.reset();
      expect(q.status, PyreStatus.idle);
      expect(q.completedCount, 0);
      expect(q.totalEnqueued, 0);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Peek
    // -----------------------------------------------------------------------

    test('peek returns next task ID without removing', () {
      final q = Pyre<int>(autoStart: false, name: 'peek');
      expect(q.peek(), isNull);

      q.enqueue(() async => 1, id: 'first');
      q.enqueue(() async => 2, id: 'second');

      expect(q.peek(), 'first');
      expect(q.queueLength, 2); // not removed
      q.dispose();
    });

    test('peek respects priority', () {
      final q = Pyre<int>(autoStart: false, name: 'peek-prio');
      q.enqueue(() async => 1, id: 'low', priority: PyrePriority.low);
      q.enqueue(() async => 2, id: 'high', priority: PyrePriority.high);

      expect(q.peek(), 'high');
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Progress
    // -----------------------------------------------------------------------

    test('progress reflects completion ratio', () async {
      final q = Pyre<int>(concurrency: 1, autoStart: false, name: 'progress');
      q.enqueue(() async => 1);
      q.enqueue(() async => 2);
      expect(q.progress, 0.0); // 0 / 2

      q.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(q.progress, 1.0); // 2 / 2
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Reactive state
    // -----------------------------------------------------------------------

    test('reactive state updates during processing', () async {
      final q = Pyre<int>(concurrency: 1, name: 'reactive');
      final statusHistory = <PyreStatus>[];

      q.enqueue(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return 1;
      });

      // Capture initial processing state
      await Future<void>.delayed(const Duration(milliseconds: 10));
      statusHistory.add(q.status);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      statusHistory.add(q.status);

      expect(statusHistory, contains(PyreStatus.processing));
      expect(statusHistory.last, PyreStatus.idle);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Drain
    // -----------------------------------------------------------------------

    test('drain cancels pending and waits for running', () async {
      final q = Pyre<int>(concurrency: 1, name: 'drain');

      q.enqueue(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return 1;
      });
      q.enqueue(() async => 2);
      q.enqueue(() async => 3);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      final results = await q.drain();
      // Should have cancelled 2 pending tasks
      expect(results.length, 2);
      expect(results.every((r) => r.isFailure), isTrue);
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Disposed state
    // -----------------------------------------------------------------------

    test('cannot use disposed Pyre', () {
      final q = Pyre<int>(name: 'disposed');
      q.dispose();
      expect(q.isDisposed, isTrue);
      expect(() => q.enqueue(() async => 1), throwsA(isA<StateError>()));
    });

    test('dispose is idempotent', () {
      final q = Pyre<int>(name: 'idempotent');
      q.dispose();
      q.dispose(); // no-op
      expect(q.isDisposed, isTrue);
    });

    // -----------------------------------------------------------------------
    // PyreResult
    // -----------------------------------------------------------------------

    test('PyreSuccess has correct properties', () {
      const s = PyreSuccess<int>(
        taskId: 't1',
        value: 42,
        duration: Duration(milliseconds: 100),
      );
      expect(s.isSuccess, isTrue);
      expect(s.isFailure, isFalse);
      expect(s.valueOrNull, 42);
      expect(s.errorOrNull, isNull);
      expect(s.toString(), contains('42'));
    });

    test('PyreFailure has correct properties', () {
      final f = PyreFailure<int>(
        taskId: 't2',
        error: Exception('fail'),
        stackTrace: StackTrace.current,
        duration: const Duration(milliseconds: 50),
      );
      expect(f.isSuccess, isFalse);
      expect(f.isFailure, isTrue);
      expect(f.valueOrNull, isNull);
      expect(f.errorOrNull, isA<Exception>());
      expect(f.toString(), contains('fail'));
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------

    test('toString includes state info', () {
      final q = Pyre<int>(name: 'debug');
      final str = q.toString();
      expect(str, contains('Pyre<int>'));
      expect(str, contains('debug'));
      expect(str, contains('idle'));
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    test('pyre factory works in Pillar', () async {
      final pillar = _TestPillar();
      // Force lazy init
      expect(pillar.taskQueue.status, PyreStatus.idle);

      final result = await pillar.taskQueue.enqueue(() async => 'done');
      expect(result, 'done');
      expect(pillar.taskQueue.completedCount, 1);

      pillar.dispose();
    });

    // -----------------------------------------------------------------------
    // Dynamic enqueue during processing
    // -----------------------------------------------------------------------

    test('allows dynamic enqueue while processing', () async {
      final order = <int>[];
      final q = Pyre<void>(concurrency: 1, name: 'dynamic');

      q.enqueue(() async {
        order.add(1);
        // Enqueue more while processing
        q.enqueue(() async => order.add(3), priority: PyrePriority.low);
        q.enqueue(() async => order.add(2), priority: PyrePriority.high);
      });

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(order, [1, 2, 3]); // high priority before low
      q.dispose();
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    test('handles empty queue gracefully', () async {
      final q = Pyre<int>(name: 'empty');
      q.start(); // no-op
      expect(q.status, PyreStatus.idle);
      q.dispose();
    });

    test('multiple pause/resume cycles', () async {
      final q = Pyre<int>(name: 'multi-pause');
      q.pause(); // no-op when idle
      expect(q.status, PyreStatus.idle);
      q.resume(); // no-op when not paused
      q.dispose();
    });
  });
}

class _TestPillar extends Pillar {
  late final taskQueue = pyre<String>(concurrency: 2, name: 'test-tasks');
}
