import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Lattice', () {
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    group('construction', () {
      test('creates empty lattice', () {
        final l = Lattice();
        expect(l.nodeCount, 0);
        expect(l.nodeIds, isEmpty);
        expect(l.status.value, LatticeStatus.idle);
      });

      test('creates with name', () {
        final l = Lattice(name: 'startup');
        expect(l.name, 'startup');
        expect(l.toString(), contains('startup'));
      });
    });

    // -----------------------------------------------------------------------
    // Node registration
    // -----------------------------------------------------------------------

    group('node registration', () {
      test('registers nodes', () {
        final l = Lattice();
        l.node('a', (_) async => 1);
        l.node('b', (_) async => 2);
        expect(l.nodeCount, 2);
        expect(l.nodeIds, containsAll(['a', 'b']));
      });

      test('registers nodes with dependencies', () {
        final l = Lattice();
        l.node('a', (_) async => 1);
        l.node('b', (_) async => 2, dependsOn: ['a']);
        expect(l.dependenciesOf('b'), ['a']);
        expect(l.dependenciesOf('a'), isEmpty);
      });

      test('dependenciesOf returns empty for unknown node', () {
        final l = Lattice();
        expect(l.dependenciesOf('nonexistent'), isEmpty);
      });

      test('cannot add nodes while executing', () async {
        final completer = Completer<void>();
        final l = Lattice();
        l.node('slow', (_) => completer.future);

        // Start execution but don't await
        final future = l.execute();

        expect(() => l.node('late', (_) async => null), throwsStateError);

        completer.complete();
        await future;
      });
    });

    // -----------------------------------------------------------------------
    // Execution — basic
    // -----------------------------------------------------------------------

    group('execution', () {
      test('executes empty graph', () async {
        final l = Lattice();
        final result = await l.execute();
        expect(result.succeeded, true);
        expect(result.values, isEmpty);
        expect(result.executionOrder, isEmpty);
        expect(l.status.value, LatticeStatus.completed);
      });

      test('executes single node', () async {
        final l = Lattice();
        l.node('a', (_) async => 42);
        final result = await l.execute();
        expect(result.succeeded, true);
        expect(result.values['a'], 42);
        expect(result.executionOrder, ['a']);
      });

      test('executes linear chain', () async {
        final order = <String>[];
        final l = Lattice();

        l.node('a', (_) async {
          order.add('a');
          return 'configData';
        });
        l.node('b', (r) async {
          order.add('b');
          return '${r['a']}-authenticated';
        }, dependsOn: ['a']);
        l.node('c', (r) async {
          order.add('c');
          return '${r['b']}-loaded';
        }, dependsOn: ['b']);

        final result = await l.execute();

        expect(result.succeeded, true);
        expect(order, ['a', 'b', 'c']);
        expect(result.values['c'], 'configData-authenticated-loaded');
      });

      test('executes parallel independent nodes', () async {
        final running = <String>{};
        var maxParallel = 0;
        final l = Lattice();

        Future<String> tracked(String id) async {
          running.add(id);
          if (running.length > maxParallel) {
            maxParallel = running.length;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          running.remove(id);
          return id;
        }

        l.node('a', (_) => tracked('a'));
        l.node('b', (_) => tracked('b'));
        l.node('c', (_) => tracked('c'));

        final result = await l.execute();

        expect(result.succeeded, true);
        // All three should have run in parallel
        expect(maxParallel, 3);
      });

      test('executes diamond dependency graph', () async {
        // a → b, a → c, b+c → d
        final order = <String>[];
        final l = Lattice();

        l.node('a', (_) async {
          order.add('a');
          return 1;
        });
        l.node('b', (_) async {
          order.add('b');
          return 2;
        }, dependsOn: ['a']);
        l.node('c', (_) async {
          order.add('c');
          return 3;
        }, dependsOn: ['a']);
        l.node('d', (r) async {
          order.add('d');
          return (r['b'] as int) + (r['c'] as int);
        }, dependsOn: ['b', 'c']);

        final result = await l.execute();

        expect(result.succeeded, true);
        expect(order.first, 'a');
        expect(order.last, 'd');
        // b and c can be in either order
        expect(order.sublist(1, 3), containsAll(['b', 'c']));
        expect(result.values['d'], 5);
      });

      test('passes upstream results to tasks', () async {
        final l = Lattice();
        l.node('config', (_) async => {'host': 'api.example.com'});
        l.node('auth', (r) async {
          final config = r['config'] as Map<String, String>;
          return 'token-for-${config['host']}';
        }, dependsOn: ['config']);

        final result = await l.execute();

        expect(result.values['auth'], 'token-for-api.example.com');
      });
    });

    // -----------------------------------------------------------------------
    // Error handling
    // -----------------------------------------------------------------------

    group('error handling', () {
      test('captures task errors', () async {
        final l = Lattice();
        l.node('ok', (_) async => 'fine');
        l.node('fail', (_) async => throw Exception('boom'));

        final result = await l.execute();

        expect(result.succeeded, false);
        expect(result.errors.containsKey('fail'), true);
        expect(result.errors['fail'].toString(), contains('boom'));
        expect(l.status.value, LatticeStatus.failed);
      });

      test('fail-fast stops remaining tasks', () async {
        final executed = <String>[];
        final l = Lattice();

        l.node('a', (_) async {
          executed.add('a');
          throw Exception('fail');
        });
        l.node('b', (_) async {
          executed.add('b');
          return 'ok';
        }, dependsOn: ['a']);

        final result = await l.execute();

        expect(result.succeeded, false);
        expect(executed, ['a']);
        // b should not have executed because a failed
        expect(executed.contains('b'), false);
      });

      test('throws on missing dependency', () async {
        final l = Lattice();
        l.node('a', (_) async => 1, dependsOn: ['nonexistent']);

        expect(() => l.execute(), throwsStateError);
      });

      test('throws on cycle', () async {
        final l = Lattice();
        l.node('a', (_) async => 1, dependsOn: ['b']);
        l.node('b', (_) async => 2, dependsOn: ['a']);

        expect(() => l.execute(), throwsStateError);
      });

      test('throws on already executing', () async {
        final completer = Completer<void>();
        final l = Lattice();
        l.node('slow', (_) => completer.future);

        final future = l.execute();
        expect(() => l.execute(), throwsStateError);

        completer.complete();
        await future;
      });
    });

    // -----------------------------------------------------------------------
    // Cycle detection
    // -----------------------------------------------------------------------

    group('cycle detection', () {
      test('hasCycle returns false for acyclic graph', () {
        final l = Lattice();
        l.node('a', (_) async => 1);
        l.node('b', (_) async => 2, dependsOn: ['a']);
        l.node('c', (_) async => 3, dependsOn: ['b']);
        expect(l.hasCycle, false);
      });

      test('hasCycle returns true for cyclic graph', () {
        final l = Lattice();
        l.node('a', (_) async => 1, dependsOn: ['c']);
        l.node('b', (_) async => 2, dependsOn: ['a']);
        l.node('c', (_) async => 3, dependsOn: ['b']);
        expect(l.hasCycle, true);
      });

      test('hasCycle returns false for empty graph', () {
        final l = Lattice();
        expect(l.hasCycle, false);
      });

      test('hasCycle returns true for self-cycle', () {
        final l = Lattice();
        l.node('a', (_) async => 1, dependsOn: ['a']);
        expect(l.hasCycle, true);
      });
    });

    // -----------------------------------------------------------------------
    // Reactive state
    // -----------------------------------------------------------------------

    group('reactive state', () {
      test('status transitions: idle → running → completed', () async {
        final statuses = <LatticeStatus>[];
        final l = Lattice();
        l.node('a', (_) async {
          statuses.add(l.status.value);
          return 1;
        });

        statuses.add(l.status.value);
        await l.execute();
        statuses.add(l.status.value);

        expect(statuses, [
          LatticeStatus.idle,
          LatticeStatus.running,
          LatticeStatus.completed,
        ]);
      });

      test('progress tracks completion', () async {
        final progressValues = <double>[];
        final completers = <String, Completer<int>>{};

        final l = Lattice();

        for (final id in ['a', 'b', 'c', 'd']) {
          final c = Completer<int>();
          completers[id] = c;
          l.node(id, (_) => c.future);
        }

        progressValues.add(l.progress.value);

        final future = l.execute();

        // Complete nodes one at a time
        completers['a']!.complete(1);
        await Future<void>.delayed(Duration.zero);
        progressValues.add(l.progress.value);

        completers['b']!.complete(2);
        await Future<void>.delayed(Duration.zero);
        progressValues.add(l.progress.value);

        completers['c']!.complete(3);
        await Future<void>.delayed(Duration.zero);
        progressValues.add(l.progress.value);

        completers['d']!.complete(4);
        await future;
        progressValues.add(l.progress.value);

        expect(progressValues, [
          0.0, // 0/4 nodes completed
          0.25,
          0.5,
          0.75,
          1.0,
        ]);
      });

      test('completedCount increments', () async {
        final l = Lattice();
        l.node('a', (_) async => 1);
        l.node('b', (_) async => 2);

        expect(l.completedCount.value, 0);
        await l.execute();
        expect(l.completedCount.value, 2);
      });
    });

    // -----------------------------------------------------------------------
    // Reset
    // -----------------------------------------------------------------------

    group('reset', () {
      test('reset returns to idle', () async {
        final l = Lattice();
        l.node('a', (_) async => 1);

        await l.execute();
        expect(l.status.value, LatticeStatus.completed);

        l.reset();
        expect(l.status.value, LatticeStatus.idle);
        expect(l.completedCount.value, 0);
      });

      test('allows re-execution after reset', () async {
        var callCount = 0;
        final l = Lattice();
        l.node('a', (_) async {
          callCount++;
          return callCount;
        });

        var result = await l.execute();
        expect(result.values['a'], 1);

        l.reset();
        result = await l.execute();
        expect(result.values['a'], 2);
      });
    });

    // -----------------------------------------------------------------------
    // LatticeResult
    // -----------------------------------------------------------------------

    group('LatticeResult', () {
      test('succeeded is true when no errors', () {
        const result = LatticeResult(
          values: {'a': 1},
          errors: {},
          elapsed: Duration.zero,
          executionOrder: ['a'],
        );
        expect(result.succeeded, true);
      });

      test('succeeded is false when errors exist', () {
        final result = LatticeResult(
          values: {},
          errors: {'a': Exception('fail')},
          elapsed: Duration.zero,
          executionOrder: [],
        );
        expect(result.succeeded, false);
      });

      test('toString shows summary', () {
        const result = LatticeResult(
          values: {'a': 1, 'b': 2},
          errors: {},
          elapsed: Duration(milliseconds: 42),
          executionOrder: ['a', 'b'],
        );
        expect(
          result.toString(),
          'LatticeResult(2 succeeded, 0 failed, 42 ms)',
        );
      });

      test('elapsed tracks wall-clock time', () async {
        final l = Lattice();
        l.node('slow', (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'done';
        });

        final result = await l.execute();
        expect(result.elapsed.inMilliseconds, greaterThanOrEqualTo(40));
      });
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------

    group('Pillar integration', () {
      test('managedNodes contains reactive nodes', () {
        final l = Lattice();
        final nodes = l.managedNodes.toList();
        // status, completed, progress
        expect(nodes.length, 3);
      });

      test('lattice() extension creates managed instance', () async {
        final pillar = _TestPillar();
        pillar.setupStartup();

        final result = await pillar.startup.execute();
        expect(result.succeeded, true);
        expect(result.values['config'], 'cfg');
        expect(result.values['auth'], 'cfg-auth');

        pillar.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    group('edge cases', () {
      test('large graph executes correctly', () async {
        final l = Lattice();
        // Chain of 100 nodes
        l.node('n0', (_) async => 0);
        for (var i = 1; i < 100; i++) {
          l.node(
            'n$i',
            (r) async => (r['n${i - 1}'] as int) + 1,
            dependsOn: ['n${i - 1}'],
          );
        }

        final result = await l.execute();
        expect(result.succeeded, true);
        expect(result.values['n99'], 99);
      });

      test('wide graph maximizes parallelism', () async {
        final l = Lattice();
        // 50 independent nodes
        for (var i = 0; i < 50; i++) {
          l.node('n$i', (_) async => i);
        }

        final result = await l.execute();
        expect(result.succeeded, true);
        expect(result.values.length, 50);
      });

      test('toString reports status', () {
        final l = Lattice(name: 'init');
        l.node('a', (_) async => 1);
        expect(l.toString(), 'Lattice "init"(1 nodes, idle)');
      });

      test('complex diamond pattern', () async {
        //    a
        //   / \
        //  b   c
        //  |   |
        //  d   e
        //   \ /
        //    f
        final l = Lattice();
        l.node('a', (_) async => 1);
        l.node('b', (_) async => 2, dependsOn: ['a']);
        l.node('c', (_) async => 3, dependsOn: ['a']);
        l.node('d', (_) async => 4, dependsOn: ['b']);
        l.node('e', (_) async => 5, dependsOn: ['c']);
        l.node('f', (r) async {
          return (r['d'] as int) + (r['e'] as int);
        }, dependsOn: ['d', 'e']);

        final result = await l.execute();
        expect(result.succeeded, true);
        expect(result.values['f'], 9); // 4 + 5
        expect(result.executionOrder.first, 'a');
        expect(result.executionOrder.last, 'f');
      });
    });
  });
}

// Test Pillar for integration testing
class _TestPillar extends Pillar {
  late final startup = lattice(name: 'startup');

  void setupStartup() {
    startup
      ..node('config', (_) async => 'cfg')
      ..node('auth', (r) async => '${r['config']}-auth', dependsOn: ['config']);
  }
}
