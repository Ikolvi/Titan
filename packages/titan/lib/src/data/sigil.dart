/// Sigil — Reactive feature flag registry.
///
/// Sigil provides a centralized, reactive feature flag system backed by
/// [Core] state nodes. Flags update reactively — any [Vestige] or
/// [Derived] reading a flag automatically rebuilds when that flag changes.
///
/// ## Why "Sigil"?
///
/// A sigil is a magical symbol of authority and intent. Titan's Sigil
/// grants or revokes feature access with a single mark.
///
/// ## Usage
///
/// ```dart
/// // Register flags
/// Sigil.register('darkMode', true);
/// Sigil.register('betaFeatures', false);
///
/// // Read reactively
/// final isDark = Sigil.isEnabled('darkMode'); // true
///
/// // Toggle at runtime
/// Sigil.toggle('darkMode'); // now false
///
/// // Bulk load from remote config
/// Sigil.loadAll({'darkMode': true, 'betaFeatures': true});
///
/// // Override for testing
/// Sigil.override('betaFeatures', true);
/// ```
library;

import '../core/state.dart';

/// A centralized, reactive feature flag registry.
///
/// Each flag is backed by a [TitanState<bool>] Core, making it fully
/// reactive — widgets and computed values that read flags through
/// [isEnabled] will automatically update when flags change.
///
/// ```dart
/// Sigil.register('newCheckout', false);
///
/// // In a Vestige or Derived:
/// if (Sigil.isEnabled('newCheckout')) {
///   // show new checkout flow
/// }
///
/// // Toggle remotely:
/// Sigil.enable('newCheckout');
/// ```
class Sigil {
  Sigil._();

  /// Internal flag storage: flag name → reactive bool Core.
  static final Map<String, TitanState<bool>> _flags = {};

  /// All override values (for testing). Takes precedence over
  /// the underlying Core value when read via [isEnabled].
  static final Map<String, bool> _overrides = {};

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Register a new feature flag with an initial value.
  ///
  /// If a flag with [name] already exists, its value is updated
  /// to [initialValue].
  ///
  /// ```dart
  /// Sigil.register('darkMode', true);
  /// ```
  static void register(String name, bool initialValue) {
    if (_flags.containsKey(name)) {
      _flags[name]!.value = initialValue;
    } else {
      _flags[name] = TitanState<bool>(initialValue, name: 'sigil_$name');
    }
  }

  /// Bulk-register flags from a map.
  ///
  /// ```dart
  /// Sigil.loadAll({
  ///   'darkMode': true,
  ///   'betaFeatures': false,
  ///   'newOnboarding': true,
  /// });
  /// ```
  static void loadAll(Map<String, bool> flags) {
    for (final entry in flags.entries) {
      register(entry.key, entry.value);
    }
  }

  /// Unregister a flag, disposing its reactive Core.
  ///
  /// Returns `true` if the flag existed and was removed.
  static bool unregister(String name) {
    _overrides.remove(name);
    final core = _flags.remove(name);
    if (core != null) {
      core.dispose();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Reading
  // ---------------------------------------------------------------------------

  /// Whether a flag is enabled (reactive).
  ///
  /// If the flag has a test override (via [override]), returns the
  /// override value. Otherwise reads the reactive Core, establishing
  /// a dependency for automatic updates.
  ///
  /// Returns `false` for unregistered flags.
  ///
  /// ```dart
  /// if (Sigil.isEnabled('darkMode')) {
  ///   // render dark theme
  /// }
  /// ```
  static bool isEnabled(String name) {
    if (_overrides.containsKey(name)) return _overrides[name]!;
    return _flags[name]?.value ?? false;
  }

  /// Whether a flag is disabled (reactive).
  ///
  /// Convenience inverse of [isEnabled].
  static bool isDisabled(String name) => !isEnabled(name);

  /// Whether a flag has been registered.
  static bool has(String name) => _flags.containsKey(name);

  /// The names of all registered flags.
  static Set<String> get names => Set.unmodifiable(_flags.keys.toSet());

  /// Non-reactive peek at a flag's value.
  ///
  /// Does NOT establish a reactive dependency.
  static bool peek(String name) {
    if (_overrides.containsKey(name)) return _overrides[name]!;
    return _flags[name]?.peek() ?? false;
  }

  /// Get the underlying reactive Core for a flag.
  ///
  /// Returns `null` if the flag is not registered.
  static TitanState<bool>? coreOf(String name) => _flags[name];

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Enable a flag.
  ///
  /// Throws [StateError] if the flag is not registered.
  static void enable(String name) {
    _requireFlag(name).value = true;
  }

  /// Disable a flag.
  ///
  /// Throws [StateError] if the flag is not registered.
  static void disable(String name) {
    _requireFlag(name).value = false;
  }

  /// Toggle a flag's value.
  ///
  /// Returns the new value. Throws [StateError] if not registered.
  static bool toggle(String name) {
    final core = _requireFlag(name);
    core.value = !core.peek();
    return core.peek();
  }

  /// Set a flag to a specific value.
  ///
  /// Throws [StateError] if the flag is not registered.
  static void set(String name, bool value) {
    _requireFlag(name).value = value;
  }

  // ---------------------------------------------------------------------------
  // Test Overrides
  // ---------------------------------------------------------------------------

  /// Override a flag's value for testing.
  ///
  /// Overrides bypass the reactive Core — [isEnabled] returns
  /// the override value without reading the Core.
  ///
  /// ```dart
  /// Sigil.override('betaFeatures', true);
  /// expect(Sigil.isEnabled('betaFeatures'), isTrue);
  /// ```
  static void override(String name, bool value) {
    _overrides[name] = value;
  }

  /// Clear a specific override.
  static void clearOverride(String name) {
    _overrides.remove(name);
  }

  /// Clear all overrides.
  static void clearOverrides() {
    _overrides.clear();
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  /// Dispose all flags and clear all state.
  ///
  /// Call in test teardown or app shutdown.
  static void reset() {
    for (final core in _flags.values) {
      core.dispose();
    }
    _flags.clear();
    _overrides.clear();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  static TitanState<bool> _requireFlag(String name) {
    final core = _flags[name];
    if (core == null) {
      throw StateError('Sigil flag "$name" is not registered.');
    }
    return core;
  }
}
