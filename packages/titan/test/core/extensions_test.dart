import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('CoreBoolExtensions', () {
    test('toggle() flips true to false', () {
      final flag = TitanState(true);
      flag.toggle();
      expect(flag.value, false);
      flag.dispose();
    });

    test('toggle() flips false to true', () {
      final flag = TitanState(false);
      flag.toggle();
      expect(flag.value, true);
      flag.dispose();
    });

    test('toggle() notifies listeners', () {
      final flag = TitanState(false);
      int changes = 0;
      flag.addListener(() => changes++);

      flag.toggle();
      expect(changes, 1);
      expect(flag.value, true);

      flag.toggle();
      expect(changes, 2);
      expect(flag.value, false);

      flag.dispose();
    });
  });

  group('CoreIntExtensions', () {
    test('increment() adds 1 by default', () {
      final count = TitanState(0);
      count.increment();
      expect(count.value, 1);
      count.dispose();
    });

    test('increment(5) adds 5', () {
      final count = TitanState(10);
      count.increment(5);
      expect(count.value, 15);
      count.dispose();
    });

    test('decrement() subtracts 1 by default', () {
      final count = TitanState(10);
      count.decrement();
      expect(count.value, 9);
      count.dispose();
    });

    test('decrement(3) subtracts 3', () {
      final count = TitanState(10);
      count.decrement(3);
      expect(count.value, 7);
      count.dispose();
    });
  });

  group('CoreDoubleExtensions', () {
    test('increment() adds 1.0 by default', () {
      final val = TitanState(0.5);
      val.increment();
      expect(val.value, 1.5);
      val.dispose();
    });

    test('decrement(0.3) subtracts 0.3', () {
      final val = TitanState(1.0);
      val.decrement(0.3);
      expect(val.value, closeTo(0.7, 0.001));
      val.dispose();
    });
  });

  group('CoreListExtensions', () {
    test('add() appends item', () {
      final items = TitanState<List<String>>([]);
      items.add('a');
      expect(items.value, ['a']);
      items.add('b');
      expect(items.value, ['a', 'b']);
      items.dispose();
    });

    test('addAll() appends multiple items', () {
      final items = TitanState<List<int>>([1]);
      items.addAll([2, 3, 4]);
      expect(items.value, [1, 2, 3, 4]);
      items.dispose();
    });

    test('removeWhere() removes matching items', () {
      final items = TitanState<List<String>>(['a', 'b', 'c', 'b']);
      items.removeWhere((i) => i == 'b');
      expect(items.value, ['a', 'c']);
      items.dispose();
    });

    test('removeAt() removes by index', () {
      final items = TitanState<List<String>>(['x', 'y', 'z']);
      items.removeAt(1);
      expect(items.value, ['x', 'z']);
      items.dispose();
    });

    test('insert() inserts at index', () {
      final items = TitanState<List<String>>(['a', 'c']);
      items.insert(1, 'b');
      expect(items.value, ['a', 'b', 'c']);
      items.dispose();
    });

    test('clear() empties the list', () {
      final items = TitanState<List<int>>([1, 2, 3]);
      items.clear();
      expect(items.value, isEmpty);
      items.dispose();
    });

    test('operations produce immutable updates (new list identity)', () {
      final items = TitanState<List<int>>([1, 2, 3]);
      final before = items.value;
      items.add(4);
      expect(identical(before, items.value), false);
      items.dispose();
    });
  });

  group('CoreMapExtensions', () {
    test('set() adds a key-value pair', () {
      final map = TitanState<Map<String, int>>({});
      map.set('a', 1);
      expect(map.value, {'a': 1});
      map.set('b', 2);
      expect(map.value, {'a': 1, 'b': 2});
      map.dispose();
    });

    test('remove() removes a key', () {
      final map = TitanState<Map<String, int>>({'a': 1, 'b': 2});
      map.remove('a');
      expect(map.value, {'b': 2});
      map.dispose();
    });

    test('clear() empties the map', () {
      final map = TitanState<Map<String, int>>({'a': 1});
      map.clear();
      expect(map.value, isEmpty);
      map.dispose();
    });
  });
}
