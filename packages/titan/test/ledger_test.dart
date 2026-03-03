import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Ledger', () {
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------

    group('construction', () {
      test('creates with default settings', () {
        final l = Ledger();
        expect(l.activeCount, 0);
        expect(l.commitCount, 0);
        expect(l.rollbackCount, 0);
        expect(l.failCount, 0);
        expect(l.hasActive, false);
        expect(l.history, isEmpty);
        expect(l.isDisposed, false);
      });

      test('accepts name and maxHistory', () {
        final l = Ledger(name: 'test', maxHistory: 10);
        expect(l.name, 'test');
        expect(l.isDisposed, false);
      });
    });

    // -----------------------------------------------------------------------
    // Manual Transaction — begin/commit/rollback
    // -----------------------------------------------------------------------

    group('manual transaction', () {
      test('begin creates an active transaction', () {
        final l = Ledger();
        final tx = l.begin(name: 'tx1');
        expect(tx.isActive, true);
        expect(tx.status, LedgerStatus.active);
        expect(tx.name, 'tx1');
        expect(l.activeCount, 1);
        expect(l.hasActive, true);
        tx.commit();
      });

      test('commit finalizes the transaction', () {
        final l = Ledger();
        final a = TitanState(10);
        final b = TitanState(20);

        final tx = l.begin();
        tx.capture(a);
        tx.capture(b);
        a.value = 100;
        b.value = 200;
        tx.commit();

        expect(a.value, 100);
        expect(b.value, 200);
        expect(tx.status, LedgerStatus.committed);
        expect(tx.isActive, false);
        expect(l.activeCount, 0);
        expect(l.commitCount, 1);
        expect(l.hasActive, false);
      });

      test('rollback restores original values', () {
        final l = Ledger();
        final a = TitanState(10);
        final b = TitanState('hello');

        final tx = l.begin();
        tx.capture(a);
        tx.capture(b);
        a.value = 999;
        b.value = 'changed';

        // Values are live during transaction
        expect(a.value, 999);
        expect(b.value, 'changed');

        tx.rollback();

        // Restored
        expect(a.value, 10);
        expect(b.value, 'hello');
        expect(tx.status, LedgerStatus.rolledBack);
        expect(l.rollbackCount, 1);
        expect(l.activeCount, 0);
      });

      test('double capture is a no-op', () {
        final l = Ledger();
        final a = TitanState(42);

        final tx = l.begin();
        tx.capture(a);
        tx.capture(a); // no-op
        expect(tx.coreCount, 1);
        a.value = 100;
        tx.rollback();
        expect(a.value, 42);
      });

      test('commit after commit throws', () {
        final l = Ledger();
        final tx = l.begin();
        tx.commit();
        expect(() => tx.commit(), throwsStateError);
      });

      test('rollback after commit throws', () {
        final l = Ledger();
        final tx = l.begin();
        tx.commit();
        expect(() => tx.rollback(), throwsStateError);
      });

      test('capture after commit throws', () {
        final l = Ledger();
        final tx = l.begin();
        tx.commit();
        expect(() => tx.capture(TitanState(0)), throwsStateError);
      });

      test('multiple simultaneous transactions', () {
        final l = Ledger();
        final tx1 = l.begin(name: 'tx1');
        final tx2 = l.begin(name: 'tx2');

        expect(l.activeCount, 2);
        expect(l.activeTransactionIds, [tx1.id, tx2.id]);

        tx1.commit();
        expect(l.activeCount, 1);

        tx2.rollback();
        expect(l.activeCount, 0);
        expect(l.commitCount, 1);
        expect(l.rollbackCount, 1);
      });
    });

    // -----------------------------------------------------------------------
    // transact — auto commit/rollback
    // -----------------------------------------------------------------------

    group('transact (async)', () {
      test('auto-commits on success', () async {
        final l = Ledger();
        final a = TitanState(10);

        final result = await l.transact((tx) async {
          tx.capture(a);
          a.value = 50;
          return 'done';
        });

        expect(result, 'done');
        expect(a.value, 50);
        expect(l.commitCount, 1);
        expect(l.activeCount, 0);
      });

      test('auto-rolls back on exception', () async {
        final l = Ledger();
        final a = TitanState(10);
        final b = TitanState(20);

        await expectLater(
          l.transact((tx) async {
            tx.capture(a);
            tx.capture(b);
            a.value = 100;
            b.value = 200;
            throw Exception('payment failed');
          }),
          throwsA(isA<Exception>()),
        );

        // Values restored
        expect(a.value, 10);
        expect(b.value, 20);
        expect(l.failCount, 1);
        expect(l.commitCount, 0);
        expect(l.activeCount, 0);
      });

      test('passes transaction name to record', () async {
        final l = Ledger();
        await l.transact((tx) async {}, name: 'my-tx');
        expect(l.lastRecord?.name, 'my-tx');
      });
    });

    // -----------------------------------------------------------------------
    // transactSync — synchronous auto commit/rollback
    // -----------------------------------------------------------------------

    group('transactSync', () {
      test('auto-commits on success', () {
        final l = Ledger();
        final a = TitanState(5);

        final result = l.transactSync((tx) {
          tx.capture(a);
          a.value = 50;
          return 42;
        });

        expect(result, 42);
        expect(a.value, 50);
        expect(l.commitCount, 1);
      });

      test('auto-rolls back on exception', () {
        final l = Ledger();
        final a = TitanState(5);

        expect(
          () => l.transactSync((tx) {
            tx.capture(a);
            a.value = 999;
            throw StateError('oops');
          }),
          throwsStateError,
        );

        expect(a.value, 5);
        expect(l.failCount, 1);
      });
    });

    // -----------------------------------------------------------------------
    // Reactive Properties
    // -----------------------------------------------------------------------

    group('reactive state', () {
      test('activeCount is reactive', () {
        final l = Ledger();
        final activeLog = <int>[];

        final d = TitanComputed(() => l.activeCount);
        // Force initial evaluation so listener fires on change.
        expect(d.value, 0);
        d.addListener(() => activeLog.add(d.value));

        final tx = l.begin();
        expect(activeLog, [1]);
        tx.commit();
        expect(activeLog, [1, 0]);
      });

      test('commitCount is reactive', () {
        final l = Ledger();
        int commits = 0;

        final d = TitanComputed(() => l.commitCount);
        expect(d.value, 0);
        d.addListener(() => commits = d.value);

        final tx = l.begin();
        tx.commit();
        expect(commits, 1);
      });

      test('rollbackCount is reactive', () {
        final l = Ledger();
        int rollbacks = 0;

        final d = TitanComputed(() => l.rollbackCount);
        expect(d.value, 0);
        d.addListener(() => rollbacks = d.value);

        final tx = l.begin();
        tx.rollback();
        expect(rollbacks, 1);
      });

      test('hasActive is reactive computed', () {
        final l = Ledger();
        final hasActiveLog = <bool>[];

        final d = TitanComputed(() => l.hasActive);
        expect(d.value, false);
        d.addListener(() => hasActiveLog.add(d.value));

        final tx = l.begin();
        expect(hasActiveLog, [true]);
        tx.commit();
        expect(hasActiveLog, [true, false]);
      });
    });

    // -----------------------------------------------------------------------
    // History
    // -----------------------------------------------------------------------

    group('history', () {
      test('records commits and rollbacks', () {
        final l = Ledger();
        final a = TitanState(1);

        final tx1 = l.begin(name: 'first');
        tx1.capture(a);
        a.value = 2;
        tx1.commit();

        final tx2 = l.begin(name: 'second');
        tx2.capture(a);
        a.value = 3;
        tx2.rollback();

        expect(l.history.length, 2);
        expect(l.history[0].status, LedgerStatus.committed);
        expect(l.history[0].name, 'first');
        expect(l.history[0].coreCount, 1);
        expect(l.history[1].status, LedgerStatus.rolledBack);
        expect(l.history[1].name, 'second');
      });

      test('respects maxHistory', () {
        final l = Ledger(maxHistory: 3);

        for (var i = 0; i < 5; i++) {
          final tx = l.begin();
          tx.commit();
        }

        expect(l.history.length, 3);
        expect(l.history.first.id, 2); // oldest, first two evicted
        expect(l.history.last.id, 4);
      });

      test('lastRecord returns most recent', () {
        final l = Ledger();
        expect(l.lastRecord, isNull);

        final tx = l.begin(name: 'first');
        tx.commit();
        expect(l.lastRecord?.name, 'first');
        expect(l.lastRecord?.status, LedgerStatus.committed);
      });

      test('failed records include error', () async {
        final l = Ledger();
        try {
          await l.transact((tx) async {
            throw ArgumentError('bad input');
          });
        } catch (_) {}

        expect(l.lastRecord?.status, LedgerStatus.failed);
        expect(l.lastRecord?.error, isA<ArgumentError>());
      });
    });

    // -----------------------------------------------------------------------
    // Inspection
    // -----------------------------------------------------------------------

    group('inspection', () {
      test('activeTransactionIds lists open transactions', () {
        final l = Ledger();
        final tx1 = l.begin();
        final tx2 = l.begin();
        expect(l.activeTransactionIds, [tx1.id, tx2.id]);
        tx1.commit();
        expect(l.activeTransactionIds, [tx2.id]);
        tx2.commit();
        expect(l.activeTransactionIds, isEmpty);
      });

      test('totalStarted counts all transactions', () {
        final l = Ledger();
        l.begin().commit();
        l.begin().rollback();
        l.begin().commit();
        expect(l.totalStarted, 3);
      });

      test('transaction coreCount tracks captured cores', () {
        final l = Ledger();
        final tx = l.begin();
        tx.capture(TitanState(1));
        tx.capture(TitanState(2));
        tx.capture(TitanState(3));
        expect(tx.coreCount, 3);
        tx.commit();
      });

      test('transaction id is sequential', () {
        final l = Ledger();
        final tx1 = l.begin();
        final tx2 = l.begin();
        expect(tx2.id, tx1.id + 1);
        tx1.commit();
        tx2.commit();
      });
    });

    // -----------------------------------------------------------------------
    // Complex Scenarios
    // -----------------------------------------------------------------------

    group('complex scenarios', () {
      test('rollback with derived recomputes correctly', () {
        final a = TitanState(10);
        final b = TitanState(20);
        final sum = TitanComputed(() => a.value + b.value);

        expect(sum.value, 30);

        final l = Ledger();
        final tx = l.begin();
        tx.capture(a);
        tx.capture(b);
        a.value = 100;
        b.value = 200;

        expect(sum.value, 300);

        tx.rollback();
        expect(sum.value, 30);
      });

      test('nested transactions (independent)', () {
        final l = Ledger();
        final a = TitanState(1);
        final b = TitanState(2);

        // First transaction
        final tx1 = l.begin(name: 'outer');
        tx1.capture(a);
        a.value = 10;

        // Second transaction (independent)
        final tx2 = l.begin(name: 'inner');
        tx2.capture(b);
        b.value = 20;

        // Roll back inner
        tx2.rollback();
        expect(b.value, 2);
        expect(a.value, 10); // outer still intact

        // Commit outer
        tx1.commit();
        expect(a.value, 10);
        expect(l.commitCount, 1);
        expect(l.rollbackCount, 1);
      });

      test('multiple mutations to same Core within transaction', () {
        final l = Ledger();
        final a = TitanState(1);

        final tx = l.begin();
        tx.capture(a);
        a.value = 10;
        a.value = 20;
        a.value = 30;

        // Only the original value is captured
        tx.rollback();
        expect(a.value, 1);
      });

      test('rollback does not affect uncaptured Cores', () {
        final l = Ledger();
        final captured = TitanState(1);
        final uncaptured = TitanState(2);

        final tx = l.begin();
        tx.capture(captured);
        captured.value = 100;
        uncaptured.value = 200;

        tx.rollback();
        expect(captured.value, 1); // restored
        expect(uncaptured.value, 200); // unchanged — not captured
      });

      test('transaction with zero captures commits cleanly', () {
        final l = Ledger();
        final tx = l.begin();
        tx.commit();
        expect(l.commitCount, 1);
        expect(l.lastRecord?.coreCount, 0);
      });

      test('transactSync return value propagates', () {
        final l = Ledger();
        final result = l.transactSync((tx) {
          return 'computed-result';
        });
        expect(result, 'computed-result');
      });
    });

    // -----------------------------------------------------------------------
    // Conduit Interaction
    // -----------------------------------------------------------------------

    group('conduit interaction', () {
      test('rollback triggers conduit on restore', () {
        // When we rollback, we use .value = setter which runs conduits.
        // This is intentional — conduits should validate restored values too.
        final callLog = <String>[];
        final a = TitanState<int>(
          10,
          conduits: [
            ValidateConduit((_, next) {
              callLog.add('validate:$next');
              return null; // always valid
            }),
          ],
        );

        final l = Ledger();
        final tx = l.begin();
        tx.capture(a);
        a.value = 50;
        tx.rollback();

        // Should have called conduit for both the set and the restore
        expect(callLog, contains('validate:50'));
        expect(callLog, contains('validate:10'));
      });
    });

    // -----------------------------------------------------------------------
    // Disposal
    // -----------------------------------------------------------------------

    group('disposal', () {
      test('dispose cleans up', () {
        final l = Ledger();
        l.begin().commit();
        l.dispose();
        expect(l.isDisposed, true);
        expect(l.history, isEmpty);
      });

      test('throws on operations after dispose', () {
        final l = Ledger();
        l.dispose();
        expect(() => l.begin(), throwsStateError);
      });

      test('transact throws after dispose', () async {
        final l = Ledger();
        l.dispose();
        expect(() => l.transact((tx) async {}), throwsStateError);
      });

      test('transactSync throws after dispose', () {
        final l = Ledger();
        l.dispose();
        expect(() => l.transactSync((tx) {}), throwsStateError);
      });

      test('double dispose is safe', () {
        final l = Ledger();
        l.dispose();
        l.dispose(); // no-op
      });
    });

    // -----------------------------------------------------------------------
    // Pillar Integration
    // -----------------------------------------------------------------------

    group('Pillar integration', () {
      test('ledger() factory works', () {
        final p = _TestLedgerPillar();
        p.initialize();

        expect(p.txManager.activeCount, 0);
        expect(p.txManager.isDisposed, false);
      });

      test('transactSync through pillar', () {
        final p = _TestLedgerPillar();
        p.initialize();

        p.txManager.transactSync((tx) {
          tx.capture(p.balance);
          tx.capture(p.inventory);
          p.balance.value = 100.0;
          p.inventory.value = 5;
        });

        expect(p.balance.value, 100.0);
        expect(p.inventory.value, 5);
        expect(p.txManager.commitCount, 1);
      });

      test('rollback through pillar', () {
        final p = _TestLedgerPillar();
        p.initialize();

        final tx = p.txManager.begin();
        tx.capture(p.balance);
        p.balance.value = 999.0;
        tx.rollback();

        expect(p.balance.value, 0.0);
      });

      test('dispose pillar disposes ledger nodes', () {
        final p = _TestLedgerPillar();
        p.initialize();
        p.dispose();
        // Pillar auto-disposes managed nodes
        // Ledger internal state nodes should be disposed
      });
    });

    // -----------------------------------------------------------------------
    // LedgerRecord
    // -----------------------------------------------------------------------

    group('LedgerRecord', () {
      test('toString includes id and status', () {
        final r = LedgerRecord(
          id: 1,
          status: LedgerStatus.committed,
          coreCount: 3,
          timestamp: DateTime(2024, 1, 1),
          name: 'test',
        );
        expect(r.toString(), contains('#1'));
        expect(r.toString(), contains('committed'));
        expect(r.toString(), contains('cores: 3'));
        expect(r.toString(), contains('name: test'));
      });

      test('toString with error', () {
        final r = LedgerRecord(
          id: 2,
          status: LedgerStatus.failed,
          coreCount: 1,
          timestamp: DateTime(2024, 1, 1),
          error: 'boom',
        );
        expect(r.toString(), contains('error: boom'));
      });
    });

    // -----------------------------------------------------------------------
    // Ledger toString
    // -----------------------------------------------------------------------

    group('toString', () {
      test('includes name and counts', () {
        final l = Ledger(name: 'checkout');
        expect(l.toString(), contains('checkout'));
        expect(l.toString(), contains('active: 0'));
        expect(l.toString(), contains('commits: 0'));
      });

      test('unnamed ledger', () {
        final l = Ledger();
        expect(l.toString(), contains('unnamed'));
      });
    });

    // -----------------------------------------------------------------------
    // Edge Cases
    // -----------------------------------------------------------------------

    group('edge cases', () {
      test('capture same core in multiple transactions', () {
        final l = Ledger();
        final a = TitanState(1);

        final tx1 = l.begin();
        tx1.capture(a);
        a.value = 10;
        tx1.commit();

        // Original value was 1, now 10
        final tx2 = l.begin();
        tx2.capture(a);
        a.value = 20;
        tx2.rollback();

        // Should roll back to 10 (the value when tx2 captured)
        expect(a.value, 10);
      });

      test('transact with async delay preserves rollback', () async {
        final l = Ledger();
        final a = TitanState(42);

        await expectLater(
          l.transact((tx) async {
            tx.capture(a);
            a.value = 100;
            await Future<void>.delayed(const Duration(milliseconds: 10));
            throw Exception('late failure');
          }),
          throwsA(isA<Exception>()),
        );

        expect(a.value, 42);
      });

      test('large number of cores', () {
        final l = Ledger();
        final cores = List.generate(100, (i) => TitanState(i));

        l.transactSync((tx) {
          for (final core in cores) {
            tx.capture(core);
            core.value = core.peek() * 10;
          }
        });

        for (var i = 0; i < 100; i++) {
          expect(cores[i].value, i * 10);
        }
        expect(l.lastRecord?.coreCount, 100);
      });

      test('rollback large number of cores', () {
        final l = Ledger();
        final cores = List.generate(50, (i) => TitanState(i));

        expect(
          () => l.transactSync((tx) {
            for (final core in cores) {
              tx.capture(core);
              core.value = 999;
            }
            throw StateError('abort');
          }),
          throwsStateError,
        );

        for (var i = 0; i < 50; i++) {
          expect(cores[i].value, i);
        }
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test Pillar
// ---------------------------------------------------------------------------

class _TestLedgerPillar extends Pillar {
  late final balance = core(0.0);
  late final inventory = core(0);
  late final txManager = ledger(name: 'test-ledger');
}
