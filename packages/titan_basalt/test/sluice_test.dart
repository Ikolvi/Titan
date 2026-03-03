import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Sluice', () {
    group('basic flow', () {
      test('single stage processes item', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'double', process: (n) => n * 2)],
          onComplete: results.add,
        );

        s.feed(5);
        await s.flush();

        expect(results, [10]);
        expect(s.fed.value, 1);
        expect(s.completed.value, 1);
        expect(s.failed.value, 0);
        s.dispose();
      });

      test('multi-stage processes through all stages', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'add10', process: (n) => n + 10),
            SluiceStage(name: 'double', process: (n) => n * 2),
          ],
          onComplete: results.add,
        );

        s.feed(5);
        await s.flush();

        expect(results, [30]); // (5+10)*2
        expect(s.completed.value, 1);
        s.dispose();
      });

      test('multiple items processed in order', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
          onComplete: results.add,
        );

        s.feedAll([1, 2, 3]);
        await s.flush();

        expect(results, [1, 2, 3]);
        expect(s.fed.value, 3);
        expect(s.completed.value, 3);
        s.dispose();
      });

      test('feedAll returns count of accepted items', () {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
          bufferSize: 2,
        );

        final accepted = s.feedAll([1, 2, 3, 4, 5]);
        expect(accepted, 2); // Only 2 fit in buffer.
        s.dispose();
      });
    });

    group('filtering', () {
      test('null return filters item out', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'even', process: (n) => n.isEven ? n : null),
          ],
          onComplete: results.add,
        );

        s.feedAll([1, 2, 3, 4, 5]);
        await s.flush();

        expect(results, [2, 4]);
        expect(s.completed.value, 2);
        expect(s.fed.value, 5);
        expect(s.stage('even').filtered.value, 3);
        s.dispose();
      });

      test('filter in middle stage stops further processing', () async {
        final results = <String>[];
        final s = Sluice<String>(
          stages: [
            SluiceStage(
              name: 'validate',
              process: (s) => s.isNotEmpty ? s : null,
            ),
            SluiceStage(name: 'upper', process: (s) => s.toUpperCase()),
          ],
          onComplete: results.add,
        );

        s.feedAll(['hello', '', 'world']);
        await s.flush();

        expect(results, ['HELLO', 'WORLD']);
        expect(s.stage('validate').filtered.value, 1);
        expect(s.stage('upper').processed.value, 2);
        s.dispose();
      });
    });

    group('error handling', () {
      test('stage error increments failed count', () async {
        final errors = <String>[];
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'fail', process: (n) => throw Exception('boom')),
          ],
          onError: (item, error, stage) => errors.add('$item@$stage'),
        );

        s.feed(42);
        await s.flush();

        expect(s.failed.value, 1);
        expect(s.completed.value, 0);
        expect(s.stage('fail').errors.value, 1);
        expect(errors, ['42@fail']);
        s.dispose();
      });

      test('per-stage onError callback fires', () async {
        final stageErrors = <String>[];
        final s = Sluice<int>(
          stages: [
            SluiceStage(
              name: 'fail',
              process: (n) => throw Exception('boom'),
              onError: (item, error) => stageErrors.add('$item'),
            ),
          ],
        );

        s.feed(7);
        await s.flush();

        expect(stageErrors, ['7']);
        s.dispose();
      });

      test('error at second stage does not affect first', () async {
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'ok', process: (n) => n * 2),
            SluiceStage(name: 'fail', process: (n) => throw Exception('boom')),
          ],
        );

        s.feed(5);
        await s.flush();

        expect(s.stage('ok').processed.value, 1);
        expect(s.stage('ok').errors.value, 0);
        expect(s.stage('fail').errors.value, 1);
        expect(s.failed.value, 1);
        s.dispose();
      });

      test('errorRate tracks ratio', () async {
        final s = Sluice<int>(
          stages: [
            SluiceStage(
              name: 'maybe',
              process: (n) {
                if (n.isOdd) throw Exception('odd');
                return n;
              },
            ),
          ],
        );

        s.feedAll([1, 2, 3, 4]);
        await s.flush();

        expect(s.fed.value, 4);
        expect(s.failed.value, 2);
        expect(s.completed.value, 2);
        expect(s.errorRate.value, 0.5);
        s.dispose();
      });
    });

    group('retry', () {
      test('retries failed stage up to maxRetries', () async {
        var attempts = 0;
        final s = Sluice<int>(
          stages: [
            SluiceStage(
              name: 'flaky',
              maxRetries: 2,
              process: (n) {
                attempts++;
                if (attempts < 3) throw Exception('not yet');
                return n * 10;
              },
            ),
          ],
        );

        s.feed(1);
        await s.flush();

        expect(attempts, 3); // 1 initial + 2 retries.
        expect(s.completed.value, 1);
        expect(s.failed.value, 0);
        s.dispose();
      });

      test('fails permanently after all retries exhausted', () async {
        var attempts = 0;
        final s = Sluice<int>(
          stages: [
            SluiceStage(
              name: 'alwaysFail',
              maxRetries: 1,
              process: (n) {
                attempts++;
                throw Exception('nope');
              },
            ),
          ],
        );

        s.feed(1);
        await s.flush();

        expect(attempts, 2); // 1 initial + 1 retry.
        expect(s.failed.value, 1);
        expect(s.completed.value, 0);
        s.dispose();
      });
    });

    group('timeout', () {
      test('stage times out and fails item', () async {
        final s = Sluice<int>(
          stages: [
            SluiceStage(
              name: 'slow',
              timeout: const Duration(milliseconds: 50),
              process: (n) async {
                await Future<void>.delayed(const Duration(milliseconds: 200));
                return n;
              },
            ),
          ],
        );

        s.feed(1);
        await s.flush();

        expect(s.failed.value, 1);
        expect(s.stage('slow').errors.value, 1);
        s.dispose();
      });
    });

    group('overflow', () {
      test('backpressure rejects when buffer full', () {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
          bufferSize: 2,
          overflow: SluiceOverflow.backpressure,
        );

        expect(s.feed(1), true);
        expect(s.feed(2), true);
        expect(s.feed(3), false); // Buffer full.
        expect(s.fed.value, 2);
        s.dispose();
      });

      test('dropNewest rejects new item when buffer full', () {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
          bufferSize: 2,
          overflow: SluiceOverflow.dropNewest,
        );

        expect(s.feed(1), true);
        expect(s.feed(2), true);
        expect(s.feed(3), false); // Newest dropped.
        s.dispose();
      });

      test('dropOldest accepts new item by removing oldest', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
          bufferSize: 2,
          overflow: SluiceOverflow.dropOldest,
          onComplete: results.add,
        );

        expect(s.feed(1), true);
        expect(s.feed(2), true);
        expect(s.feed(3), true); // 1 dropped, 3 accepted.
        await s.flush();

        // Item 1 was dropped — 2 and 3 should complete.
        expect(results, containsAll([2, 3]));
        s.dispose();
      });
    });

    group('pause and resume', () {
      test('paused pipeline stops processing', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [
            SluiceStage(
              name: 'slow',
              process: (n) async {
                await Future<void>.delayed(const Duration(milliseconds: 10));
                return n;
              },
            ),
          ],
          onComplete: results.add,
        );

        s.feed(1);
        s.pause();
        // Give time for pause to take effect.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(s.status.value, SluiceStatus.paused);

        s.resume();
        await s.flush();
        // After resume, item should complete.
        expect(s.status.value, SluiceStatus.idle);
        s.dispose();
      });
    });

    group('reactive state', () {
      test('status transitions idle → processing → idle', () async {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
        );

        expect(s.status.value, SluiceStatus.idle);
        expect(s.isIdle.value, true);

        s.feed(1);
        await s.flush();

        expect(s.status.value, SluiceStatus.idle);
        expect(s.isIdle.value, true);
        expect(s.inFlight.value, 0);
        s.dispose();
      });

      test('inFlight tracks items inside pipeline', () async {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
        );

        s.feed(1);
        s.feed(2);
        // Before flush, items are in-flight.
        expect(s.inFlight.value, 2);

        await s.flush();
        expect(s.inFlight.value, 0);
        s.dispose();
      });
    });

    group('per-stage metrics', () {
      test('stage() returns metrics for named stage', () async {
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'a', process: (n) => n),
            SluiceStage(name: 'b', process: (n) => n),
          ],
        );

        s.feed(1);
        await s.flush();

        expect(s.stage('a').processed.value, 1);
        expect(s.stage('b').processed.value, 1);
        expect(s.stage('a').isIdle.value, true);
        s.dispose();
      });

      test('stage() throws for unknown name', () {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'a', process: (n) => n)],
        );

        expect(() => s.stage('unknown'), throwsArgumentError);
        s.dispose();
      });

      test('stageNames returns ordered list', () {
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'first', process: (n) => n),
            SluiceStage(name: 'second', process: (n) => n),
            SluiceStage(name: 'third', process: (n) => n),
          ],
        );

        expect(s.stageNames, ['first', 'second', 'third']);
        s.dispose();
      });
    });

    group('dispose', () {
      test('disposed pipeline rejects new items', () {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
        );

        s.dispose();
        expect(s.feed(1), false);
        expect(s.status.value, SluiceStatus.disposed);
      });

      test('flush after dispose returns immediately', () async {
        final s = Sluice<int>(
          stages: [SluiceStage(name: 'pass', process: (n) => n)],
        );

        s.dispose();
        // Should not throw or hang.
        await s.flush();
      });

      test('managedNodes contains all reactive nodes', () {
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'a', process: (n) => n),
            SluiceStage(name: 'b', process: (n) => n),
          ],
        );

        // 7 pipeline nodes + 5 per stage * 2 stages = 17.
        expect(s.managedNodes.length, 17);
        s.dispose();
      });
    });

    group('async processing', () {
      test('async stage processes correctly', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [
            SluiceStage(
              name: 'async',
              process: (n) async {
                await Future<void>.delayed(const Duration(milliseconds: 5));
                return n * 3;
              },
            ),
          ],
          onComplete: results.add,
        );

        s.feedAll([1, 2, 3]);
        await s.flush();

        expect(results, [3, 6, 9]);
        s.dispose();
      });

      test('mixed sync and async stages', () async {
        final results = <int>[];
        final s = Sluice<int>(
          stages: [
            SluiceStage(name: 'sync', process: (n) => n + 1),
            SluiceStage(
              name: 'async',
              process: (n) async {
                await Future<void>.delayed(const Duration(milliseconds: 1));
                return n * 2;
              },
            ),
          ],
          onComplete: results.add,
        );

        s.feed(4);
        await s.flush();

        expect(results, [10]); // (4+1)*2
        s.dispose();
      });
    });

    group('Pillar integration', () {
      test('sluice() factory registers managed nodes', () {
        final p = _TestPillar();
        p.initialize();
        expect(p.pipeline.stageNames, ['a', 'b']);
        expect(p.pipeline.status.value, SluiceStatus.idle);
        p.dispose();
      });
    });
  });
}

class _TestPillar extends Pillar {
  late final pipeline = sluice<int>(
    stages: [
      SluiceStage(name: 'a', process: (n) => n + 1),
      SluiceStage(name: 'b', process: (n) => n * 2),
    ],
    name: 'test',
  );
}
