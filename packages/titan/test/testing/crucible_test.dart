import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _CounterPillar extends Pillar {
  late final count = core(0);
  late final name = core('counter');

  void increment() => strike(() => count.value++);
  void decrement() => strike(() => count.value--);
  void setName(String n) => strike(() => name.value = n);
}

class _AsyncPillar extends Pillar {
  late final data = core<String?>(null);
  late final loading = core(false);

  Future<void> loadData() async {
    strike(() => loading.value = true);
    await Future<void>.delayed(Duration(milliseconds: 10));
    strike(() {
      data.value = 'loaded';
      loading.value = false;
    });
  }
}

void main() {
  setUp(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  tearDown(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  group('Crucible', () {
    test('creates and initializes Pillar', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      expect(crucible.pillar.isInitialized, isTrue);
      expect(crucible.pillar.isDisposed, isFalse);
      expect(crucible.isDisposed, isFalse);

      crucible.dispose();
    });

    test('.from() wraps existing Pillar', () {
      final pillar = _CounterPillar();
      final crucible = Crucible.from(pillar);

      expect(crucible.pillar, same(pillar));
      expect(pillar.isInitialized, isTrue);

      crucible.dispose();
    });

    test('expectCore() passes on match', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      crucible.expectCore(crucible.pillar.count, 0);
      crucible.pillar.increment();
      crucible.expectCore(crucible.pillar.count, 1);

      crucible.dispose();
    });

    test('expectCore() throws on mismatch', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      expect(
        () => crucible.expectCore(crucible.pillar.count, 42),
        throwsA(isA<AssertionError>()),
      );

      crucible.dispose();
    });

    test('expectStrikeSync() verifies before/after state', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);
      var beforeCalled = false;
      var afterCalled = false;

      crucible.expectStrikeSync(
        () => crucible.pillar.increment(),
        before: () {
          beforeCalled = true;
          expect(crucible.pillar.count.peek(), 0);
        },
        after: () {
          afterCalled = true;
          expect(crucible.pillar.count.peek(), 1);
        },
      );

      expect(beforeCalled, isTrue);
      expect(afterCalled, isTrue);

      crucible.dispose();
    });

    test('expectStrike() works with async actions', () async {
      final crucible = Crucible<_AsyncPillar>(_AsyncPillar.new);

      await crucible.expectStrike(
        () => crucible.pillar.loadData(),
        before: () {
          expect(crucible.pillar.data.peek(), isNull);
        },
        after: () {
          expect(crucible.pillar.data.peek(), 'loaded');
          expect(crucible.pillar.loading.peek(), isFalse);
        },
      );

      crucible.dispose();
    });

    test('track() and changesFor() record core changes', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      crucible.track(crucible.pillar.count);

      crucible.pillar.increment();
      crucible.pillar.increment();
      crucible.pillar.increment();

      final changes = crucible.changesFor(crucible.pillar.count);
      expect(changes, hasLength(3));
      expect(changes[0].value, 1);
      expect(changes[1].value, 2);
      expect(changes[2].value, 3);

      crucible.dispose();
    });

    test('valuesFor() returns value list', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      crucible.track(crucible.pillar.count);

      crucible.pillar.increment();
      crucible.pillar.increment();

      expect(crucible.valuesFor(crucible.pillar.count), [1, 2]);

      crucible.dispose();
    });

    test('track() records only tracked cores', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      crucible.track(crucible.pillar.count); // only track count

      crucible.pillar.increment();
      crucible.pillar.setName('test');

      // count changes recorded, name changes not
      expect(crucible.changes, hasLength(1));

      crucible.dispose();
    });

    test('clearChanges() resets recorded changes', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      crucible.track(crucible.pillar.count);
      crucible.pillar.increment();

      expect(crucible.changes, hasLength(1));
      crucible.clearChanges();
      expect(crucible.changes, isEmpty);

      crucible.dispose();
    });

    test('dispose() cleans up Pillar and listeners', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      crucible.track(crucible.pillar.count);
      crucible.pillar.increment();

      crucible.dispose();

      expect(crucible.isDisposed, isTrue);
      expect(crucible.pillar.isDisposed, isTrue);
      expect(crucible.changes, isEmpty);
    });

    test('double dispose is safe', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);
      crucible.dispose();
      crucible.dispose(); // no error
    });

    test('CoreChange toString is descriptive', () {
      final crucible = Crucible<_CounterPillar>(_CounterPillar.new);

      crucible.track(crucible.pillar.count);
      crucible.pillar.increment();

      final change = crucible.changes.first;
      expect(change.toString(), contains('CoreChange'));

      crucible.dispose();
    });
  });
}
