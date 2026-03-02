/// Convenience extensions for common [Core] operations.
///
/// These extensions reduce boilerplate for the most frequent
/// reactive state mutations: toggling booleans, incrementing numbers,
/// and modifying lists.
///
/// ## Usage
///
/// ```dart
/// class SettingsPillar extends Pillar {
///   late final isDark = core(false);
///   late final count = core(0);
///   late final tags = core<List<String>>([]);
///
///   void toggleTheme() => isDark.toggle();
///   void bump() => count.increment();
///   void addTag(String t) => tags.add(t);
/// }
/// ```
library;

import 'state.dart';

// ---------------------------------------------------------------------------
// Bool Extensions
// ---------------------------------------------------------------------------

/// Convenience methods for `Core<bool>`.
extension CoreBoolExtensions on TitanState<bool> {
  /// Flips the boolean value.
  ///
  /// ```dart
  /// final isDark = Core(false);
  /// isDark.toggle(); // true
  /// isDark.toggle(); // false
  /// ```
  void toggle() => value = !peek();
}

// ---------------------------------------------------------------------------
// Num Extensions
// ---------------------------------------------------------------------------

/// Convenience methods for `Core<int>`.
extension CoreIntExtensions on TitanState<int> {
  /// Increments the value by [amount] (default: 1).
  ///
  /// ```dart
  /// final count = Core(0);
  /// count.increment();   // 1
  /// count.increment(5);  // 6
  /// ```
  void increment([int amount = 1]) => value = peek() + amount;

  /// Decrements the value by [amount] (default: 1).
  ///
  /// ```dart
  /// final count = Core(10);
  /// count.decrement();   // 9
  /// count.decrement(3);  // 6
  /// ```
  void decrement([int amount = 1]) => value = peek() - amount;
}

/// Convenience methods for `Core<double>`.
extension CoreDoubleExtensions on TitanState<double> {
  /// Increments the value by [amount] (default: 1.0).
  void increment([double amount = 1.0]) => value = peek() + amount;

  /// Decrements the value by [amount] (default: 1.0).
  void decrement([double amount = 1.0]) => value = peek() - amount;
}

// ---------------------------------------------------------------------------
// List Extensions
// ---------------------------------------------------------------------------

/// Convenience methods for `Core<List<T>>`.
extension CoreListExtensions<T> on TitanState<List<T>> {
  /// Appends an item to the list (immutable update).
  ///
  /// ```dart
  /// final items = Core<List<String>>([]);
  /// items.add('hello'); // ['hello']
  /// ```
  void add(T item) => value = [...peek(), item];

  /// Appends all items to the list (immutable update).
  ///
  /// ```dart
  /// final items = Core<List<int>>([1]);
  /// items.addAll([2, 3]); // [1, 2, 3]
  /// ```
  void addAll(Iterable<T> items) => value = [...peek(), ...items];

  /// Removes the first item matching [test] (immutable update).
  ///
  /// ```dart
  /// final items = Core<List<String>>(['a', 'b', 'c']);
  /// items.removeWhere((i) => i == 'b'); // ['a', 'c']
  /// ```
  void removeWhere(bool Function(T item) test) =>
      value = [...peek()]..removeWhere(test);

  /// Removes the item at [index] (immutable update).
  ///
  /// ```dart
  /// final items = Core<List<String>>(['a', 'b', 'c']);
  /// items.removeAt(1); // ['a', 'c']
  /// ```
  void removeAt(int index) => value = [...peek()]..removeAt(index);

  /// Inserts an item at [index] (immutable update).
  ///
  /// ```dart
  /// final items = Core<List<String>>(['a', 'c']);
  /// items.insert(1, 'b'); // ['a', 'b', 'c']
  /// ```
  void insert(int index, T item) => value = [...peek()]..insert(index, item);

  /// Clears all items.
  ///
  /// ```dart
  /// final items = Core<List<int>>([1, 2, 3]);
  /// items.clear(); // []
  /// ```
  void clear() => value = [];
}

// ---------------------------------------------------------------------------
// Map Extensions
// ---------------------------------------------------------------------------

/// Convenience methods for `Core<Map<K, V>>`.
extension CoreMapExtensions<K, V> on TitanState<Map<K, V>> {
  /// Sets a key-value pair (immutable update).
  ///
  /// ```dart
  /// final prefs = Core<Map<String, String>>({});
  /// prefs.set('theme', 'dark');
  /// ```
  void set(K key, V val) => value = {...peek(), key: val};

  /// Removes a key (immutable update).
  ///
  /// ```dart
  /// final prefs = Core<Map<String, String>>({'a': '1', 'b': '2'});
  /// prefs.remove('a'); // {'b': '2'}
  /// ```
  void remove(K key) => value = Map.from(peek())..remove(key);

  /// Clears all entries.
  void clear() => value = {};
}
