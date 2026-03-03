import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Tithe', () {
    // ─── Construction ─────────────────────────────────────────

    test('initial state is zero consumption', () {
      final t = Tithe(budget: 100);
      expect(t.consumed.value, 0);
      expect(t.remaining.value, 100);
      expect(t.exceeded.value, false);
      expect(t.ratio.value, 0.0);
      expect(t.breakdown.value, isEmpty);
      expect(t.budget, 100);
    });

    // ─── Consume ──────────────────────────────────────────────

    test('consume decrements remaining', () {
      final t = Tithe(budget: 100);
      t.consume(25);
      expect(t.consumed.value, 25);
      expect(t.remaining.value, 75);
      expect(t.ratio.value, 0.25);
      expect(t.exceeded.value, false);
    });

    test('consume accumulates', () {
      final t = Tithe(budget: 100);
      t.consume(30);
      t.consume(20);
      t.consume(10);
      expect(t.consumed.value, 60);
      expect(t.remaining.value, 40);
    });

    test('consume with key tracks in breakdown', () {
      final t = Tithe(budget: 100);
      t.consume(10, key: 'uploads');
      t.consume(5, key: 'downloads');
      t.consume(3, key: 'uploads');

      expect(t.consumed.value, 18);
      expect(t.breakdown.value, {'uploads': 13, 'downloads': 5});
    });

    test('consume without key does not affect breakdown', () {
      final t = Tithe(budget: 100);
      t.consume(50);
      expect(t.breakdown.value, isEmpty);
    });

    test('exceeded becomes true at budget', () {
      final t = Tithe(budget: 10);
      t.consume(10);
      expect(t.exceeded.value, true);
      expect(t.remaining.value, 0);
      expect(t.ratio.value, 1.0);
    });

    test('over-consumption allows negative remaining', () {
      final t = Tithe(budget: 10);
      t.consume(15);
      expect(t.consumed.value, 15);
      expect(t.remaining.value, -5);
      expect(t.exceeded.value, true);
      expect(t.ratio.value, 1.5);
    });

    // ─── tryConsume ───────────────────────────────────────────

    test('tryConsume returns true and consumes when within budget', () {
      final t = Tithe(budget: 100);
      expect(t.tryConsume(50), true);
      expect(t.consumed.value, 50);
    });

    test('tryConsume returns false when would exceed budget', () {
      final t = Tithe(budget: 100);
      t.consume(90);
      expect(t.tryConsume(20), false);
      expect(t.consumed.value, 90); // Unchanged
    });

    test('tryConsume with key tracks breakdown on success', () {
      final t = Tithe(budget: 100);
      expect(t.tryConsume(10, key: 'api'), true);
      expect(t.breakdown.value, {'api': 10});
    });

    test('tryConsume exact budget is allowed', () {
      final t = Tithe(budget: 100);
      t.consume(50);
      expect(t.tryConsume(50), true);
      expect(t.consumed.value, 100);
      expect(t.exceeded.value, true);
    });

    // ─── Reset ────────────────────────────────────────────────

    test('reset clears consumption and breakdown', () {
      final t = Tithe(budget: 100);
      t.consume(50, key: 'api');
      t.consume(20, key: 'storage');
      t.reset();
      expect(t.consumed.value, 0);
      expect(t.remaining.value, 100);
      expect(t.exceeded.value, false);
      expect(t.breakdown.value, isEmpty);
    });

    // ─── Threshold alerts ─────────────────────────────────────

    test('onThreshold fires at configured percent', () {
      final t = Tithe(budget: 100);
      var fired80 = false;
      var fired100 = false;
      t.onThreshold(0.8, () => fired80 = true);
      t.onThreshold(1.0, () => fired100 = true);

      t.consume(50);
      expect(fired80, false);

      t.consume(30); // 80% reached
      expect(fired80, true);
      expect(fired100, false);

      t.consume(20); // 100% reached
      expect(fired100, true);
    });

    test('threshold fires only once per period', () {
      final t = Tithe(budget: 100);
      var count = 0;
      t.onThreshold(0.5, () => count++);

      t.consume(50); // 50% — fires
      t.consume(10); // 60% — already fired
      t.consume(10); // 70% — already fired
      expect(count, 1);
    });

    test('threshold re-arms after reset', () {
      final t = Tithe(budget: 100);
      var count = 0;
      t.onThreshold(0.5, () => count++);

      t.consume(60);
      expect(count, 1);

      t.reset();
      t.consume(60);
      expect(count, 2);
    });

    // ─── Auto-reset ───────────────────────────────────────────

    test('resetInterval auto-resets consumption', () async {
      final t = Tithe(budget: 100, resetInterval: Duration(milliseconds: 100));
      t.consume(80);
      expect(t.consumed.value, 80);

      await Future<void>.delayed(Duration(milliseconds: 150));
      expect(t.consumed.value, 0);
      expect(t.remaining.value, 100);

      t.dispose();
    });

    // ─── Dispose ──────────────────────────────────────────────

    test('dispose cancels auto-reset timer', () async {
      final t = Tithe(budget: 100, resetInterval: Duration(milliseconds: 50));
      t.consume(60);
      t.dispose();

      await Future<void>.delayed(Duration(milliseconds: 100));
      expect(t.consumed.value, 60); // Timer didn't fire
    });

    test('double dispose is safe', () {
      final t = Tithe(budget: 100);
      t.dispose();
      t.dispose(); // No throw
    });

    // ─── Managed nodes ────────────────────────────────────────

    test('managedNodes exposes all reactive nodes', () {
      final t = Tithe(budget: 100);
      expect(t.managedNodes, hasLength(5));
    });

    // ─── Reactive signals update correctly ────────────────────

    test('derived signals update reactively', () {
      final t = Tithe(budget: 200);

      t.consume(199);
      expect(t.exceeded.value, false);

      t.consume(1);
      expect(t.exceeded.value, true);
      expect(t.ratio.value, 1.0);
      expect(t.remaining.value, 0);
    });

    // ─── Pillar Extension ─────────────────────────────────────

    test('multiple thresholds fire in order', () {
      final t = Tithe(budget: 100);
      final fired = <int>[];
      t.onThreshold(0.25, () => fired.add(25));
      t.onThreshold(0.50, () => fired.add(50));
      t.onThreshold(0.75, () => fired.add(75));
      t.onThreshold(1.0, () => fired.add(100));

      t.consume(100); // All thresholds in one go
      expect(fired, [25, 50, 75, 100]);
    });

    test('breakdown tracks multiple keys independently', () {
      final t = Tithe(budget: 1000);
      t.consume(10, key: 'read');
      t.consume(20, key: 'write');
      t.consume(5, key: 'read');
      t.consume(15, key: 'delete');
      t.consume(25); // No key

      expect(t.consumed.value, 75);
      expect(t.breakdown.value, {'read': 15, 'write': 20, 'delete': 15});
    });

    test('tryConsume returns false at exact zero remaining', () {
      final t = Tithe(budget: 10);
      t.consume(10);
      expect(t.tryConsume(1), false);
    });

    test('reset and re-consume works correctly', () {
      final t = Tithe(budget: 50);
      t.consume(40, key: 'a');
      t.reset();
      t.consume(10, key: 'b');

      expect(t.consumed.value, 10);
      expect(t.remaining.value, 40);
      expect(t.breakdown.value, {'b': 10});
    });

    // ─── Pillar Extension ─────────────────────────────────────

    test('Pillar extension creates lifecycle-managed Tithe', () {
      final pillar = _TestPillar();
      pillar.initialize();

      pillar.apiQuota.consume(10, key: 'search');
      expect(pillar.apiQuota.consumed.value, 10);
      expect(pillar.apiQuota.remaining.value, 90);
      expect(pillar.apiQuota.breakdown.value, {'search': 10});

      expect(pillar.apiQuota.tryConsume(100), false); // Would exceed
      expect(pillar.apiQuota.consumed.value, 10); // Unchanged

      pillar.dispose();
    });
  });
}

class _TestPillar extends Pillar {
  late final apiQuota = tithe(budget: 100, name: 'api_quota');
}
