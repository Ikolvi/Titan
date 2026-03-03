import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Clarion', () {
    group('basic scheduling', () {
      test('schedule creates a recurring job', () {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(seconds: 10), () async {});
        expect(c.jobCount.value, 1);
        expect(c.jobNames, ['job1']);
        c.dispose();
      });

      test('schedule with immediate triggers once right away', () async {
        var runs = 0;
        final c = Clarion(name: 'test');
        c.schedule(
          'job1',
          const Duration(seconds: 60),
          () async => runs++,
          immediate: true,
        );

        // Allow microtask to complete.
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(runs, 1);
        expect(c.totalRuns.value, 1);
        c.dispose();
      });

      test('scheduleOnce fires once and unregisters', () async {
        var runs = 0;
        final c = Clarion(name: 'test');
        c.scheduleOnce(
          'once',
          const Duration(milliseconds: 20),
          () async => runs++,
        );

        expect(c.jobCount.value, 1);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(runs, 1);
        expect(c.jobCount.value, 0);
        c.dispose();
      });

      test('unschedule removes and cancels a job', () {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(seconds: 10), () async {});
        expect(c.jobCount.value, 1);

        c.unschedule('job1');
        expect(c.jobCount.value, 0);
        c.dispose();
      });
    });

    group('trigger', () {
      test('trigger manually fires a job', () async {
        var runs = 0;
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async => runs++);

        c.trigger('job1');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(runs, 1);
        expect(c.totalRuns.value, 1);
        c.dispose();
      });

      test('trigger throws for unknown job', () {
        final c = Clarion(name: 'test');
        expect(() => c.trigger('unknown'), throwsArgumentError);
        c.dispose();
      });
    });

    group('concurrency policy', () {
      test('skipIfRunning skips overlapping execution', () async {
        var runs = 0;
        final completer = Completer<void>();
        final c = Clarion(name: 'test');
        c.schedule('slow', const Duration(hours: 1), () async {
          runs++;
          await completer.future;
        }, policy: ClarionPolicy.skipIfRunning);

        c.trigger('slow'); // First: starts running.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(c.job('slow').isRunning.value, true);

        c.trigger('slow'); // Second: should be skipped.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        completer.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(runs, 1); // Only first ran.
        c.dispose();
      });

      test('allowOverlap allows concurrent executions', () async {
        var concurrent = 0;
        var maxConcurrent = 0;
        final c = Clarion(name: 'test');
        c.schedule('overlap', const Duration(hours: 1), () async {
          concurrent++;
          if (concurrent > maxConcurrent) maxConcurrent = concurrent;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          concurrent--;
        }, policy: ClarionPolicy.allowOverlap);

        c.trigger('overlap');
        c.trigger('overlap');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(maxConcurrent, 2);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        c.dispose();
      });
    });

    group('error handling', () {
      test('failed job tracks error count', () async {
        final c = Clarion(name: 'test');
        c.schedule(
          'fail',
          const Duration(hours: 1),
          () async => throw Exception('boom'),
        );

        c.trigger('fail');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(c.totalRuns.value, 1);
        expect(c.totalErrors.value, 1);
        expect(c.job('fail').errorCount.value, 1);
        expect(c.job('fail').lastRun.value?.error, isNotNull);
        expect(c.job('fail').lastRun.value?.succeeded, false);
        c.dispose();
      });

      test('successRate reflects error ratio', () async {
        final c = Clarion(name: 'test');
        var shouldFail = false;
        c.schedule('mixed', const Duration(hours: 1), () async {
          if (shouldFail) throw Exception('fail');
        });

        // Run 1: success.
        c.trigger('mixed');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(c.successRate.value, 1.0);

        // Run 2: failure.
        shouldFail = true;
        c.trigger('mixed');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(c.successRate.value, 0.5); // 1 success / 2 runs.
        c.dispose();
      });
    });

    group('pause and resume', () {
      test('pause specific job prevents execution', () async {
        var runs = 0;
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async => runs++);

        c.pause('job1');
        c.trigger('job1'); // Should be ignored (paused).
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(runs, 0);
        c.dispose();
      });

      test('resume specific job allows execution again', () async {
        var runs = 0;
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async => runs++);

        c.pause('job1');
        c.resume('job1');
        c.trigger('job1');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(runs, 1);
        c.dispose();
      });

      test('pause all sets status to paused', () {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async {});

        c.pause();
        expect(c.status.value, ClarionStatus.paused);

        c.resume();
        expect(c.status.value, ClarionStatus.idle);
        c.dispose();
      });
    });

    group('reactive state', () {
      test('initial state is idle', () {
        final c = Clarion(name: 'test');
        expect(c.status.value, ClarionStatus.idle);
        expect(c.activeCount.value, 0);
        expect(c.totalRuns.value, 0);
        expect(c.totalErrors.value, 0);
        expect(c.isIdle.value, true);
        expect(c.jobCount.value, 0);
        expect(c.successRate.value, 1.0);
        c.dispose();
      });

      test('activeCount tracks running jobs', () async {
        final completer = Completer<void>();
        final c = Clarion(name: 'test');
        c.schedule(
          'slow',
          const Duration(hours: 1),
          () async => completer.future,
          policy: ClarionPolicy.allowOverlap,
        );

        c.trigger('slow');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(c.activeCount.value, 1);
        expect(c.status.value, ClarionStatus.running);

        completer.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(c.activeCount.value, 0);
        expect(c.status.value, ClarionStatus.idle);
        c.dispose();
      });

      test('per-job runCount tracks executions', () async {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async {});

        c.trigger('job1');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        c.trigger('job1');
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(c.job('job1').runCount.value, 2);
        c.dispose();
      });

      test('lastRun contains execution record', () async {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        });

        c.trigger('job1');
        await Future<void>.delayed(const Duration(milliseconds: 100));

        final lastRun = c.job('job1').lastRun.value;
        expect(lastRun, isNotNull);
        expect(lastRun!.succeeded, true);
        expect(lastRun.duration.inMilliseconds, greaterThan(0));
        c.dispose();
      });

      test('nextRun is set after scheduling', () {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async {});

        expect(c.job('job1').nextRun.value, isNotNull);
        c.dispose();
      });
    });

    group('dispose', () {
      test('dispose cancels all timers', () {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(seconds: 1), () async {});
        c.schedule('job2', const Duration(seconds: 1), () async {});

        c.dispose();
        expect(c.status.value, ClarionStatus.disposed);
      });

      test('schedule after dispose is ignored', () {
        final c = Clarion(name: 'test');
        c.dispose();
        c.schedule('job1', const Duration(seconds: 1), () async {});
        expect(c.jobCount.value, 0);
      });

      test('managedNodes contains all reactive nodes', () {
        final c = Clarion(name: 'test');
        // 7 aggregate nodes before any jobs.
        expect(c.managedNodes.length, 7);

        c.schedule('job1', const Duration(hours: 1), () async {});
        // 7 aggregate + 5 per-job nodes = 12.
        expect(c.managedNodes.length, 12);
        c.dispose();
      });
    });

    group('job lookup', () {
      test('job() returns per-job state', () {
        final c = Clarion(name: 'test');
        c.schedule('job1', const Duration(hours: 1), () async {});

        final state = c.job('job1');
        expect(state.isRunning.value, false);
        expect(state.runCount.value, 0);
        c.dispose();
      });

      test('job() throws for unknown name', () {
        final c = Clarion(name: 'test');
        expect(() => c.job('unknown'), throwsArgumentError);
        c.dispose();
      });

      test('jobNames returns all registered names', () {
        final c = Clarion(name: 'test');
        c.schedule('alpha', const Duration(hours: 1), () async {});
        c.schedule('beta', const Duration(hours: 1), () async {});
        expect(c.jobNames, containsAll(['alpha', 'beta']));
        expect(c.jobCount.value, 2);
        c.dispose();
      });
    });

    group('Pillar integration', () {
      test('clarion() factory registers managed nodes', () {
        final p = _TestPillar();
        p.initialize();
        expect(p.scheduler.status.value, ClarionStatus.idle);
        expect(p.scheduler.jobCount.value, 0);
        p.dispose();
      });
    });
  });
}

class _TestPillar extends Pillar {
  late final scheduler = clarion(name: 'test');
}
