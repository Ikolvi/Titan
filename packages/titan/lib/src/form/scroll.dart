import 'dart:async';

import '../core/reactive.dart';
import '../core/state.dart';

// ---------------------------------------------------------------------------
// Scroll — Titan's Form Management Layer
// ---------------------------------------------------------------------------

/// **Scroll** — A form field with validation, dirty tracking, and reset.
///
/// A Scroll is a [Core] (reactive mutable value) enhanced with form
/// capabilities: validation, error tracking, dirty/pristine state,
/// and reset to initial value.
///
/// ## Why "Scroll"?
///
/// A scroll holds ancient text — structured, validated, readable.
/// Form fields are the modern equivalent: structured input that
/// must be validated before it can be trusted.
///
/// ## Usage
///
/// ```dart
/// class ProfilePillar extends Pillar {
///   late final name = scroll('', validator: (v) =>
///     v.isEmpty ? 'Name is required' : null,
///   );
///
///   late final email = scroll('', validator: (v) =>
///     v.contains('@') ? null : 'Invalid email',
///   );
///
///   bool get isFormValid => name.isValid && email.isValid;
///   bool get isFormDirty => name.isDirty || email.isDirty;
///
///   void submit() {
///     name.validate();
///     email.validate();
///     if (!isFormValid) return;
///     // Process form...
///   }
/// }
/// ```
class Scroll<T> extends TitanState<T> {
  final T _initialValue;
  final String? Function(T value)? _validator;
  final Future<String?> Function(T value)? _asyncValidator;

  /// The error state for this field. `null` means no error.
  ///
  /// This is a reactive [Core] — reading `.error` inside a [Derived]
  /// or [Vestige] auto-tracks it for rebuilds.
  final TitanState<String?> _error;

  /// Whether this field has been touched (focused and blurred).
  final TitanState<bool> _touched;

  /// Whether an async validation is currently in progress.
  final TitanState<bool> _isValidating;

  /// Creates a form field with an initial value and optional validator.
  ///
  /// - [validator] — Synchronous validator.
  /// - [asyncValidator] — Asynchronous validator (e.g., server-side checks).
  ///   Called after the sync validator passes. Results update [error] reactively.
  ///
  /// ```dart
  /// late final username = scroll('',
  ///   validator: (v) => v.length < 3 ? 'Too short' : null,
  ///   asyncValidator: (v) async {
  ///     final available = await api.checkUsername(v);
  ///     return available ? null : 'Username taken';
  ///   },
  ///   name: 'username',
  /// );
  /// ```
  Scroll(
    super.initialValue, {
    String? Function(T value)? validator,
    Future<String?> Function(T value)? asyncValidator,
    super.name,
    super.equals,
  }) : _initialValue = initialValue,
       _validator = validator,
       _asyncValidator = asyncValidator,
       _error = TitanState<String?>(
         null,
         name: name != null ? '${name}_error' : null,
       ),
       _touched = TitanState<bool>(
         false,
         name: name != null ? '${name}_touched' : null,
       ),
       _isValidating = TitanState<bool>(
         false,
         name: name != null ? '${name}_validating' : null,
       );

  // ---------------------------------------------------------------------------
  // Reactive getters — all auto-track in Derived/Vestige
  // ---------------------------------------------------------------------------

  /// The current validation error, or `null` if valid.
  ///
  /// Reading this inside a [Derived] or [Vestige] auto-tracks it.
  String? get error => _error.value;

  /// Whether this field has been touched.
  bool get isTouched => _touched.value;

  /// Whether the current value differs from the initial value.
  bool get isDirty => value != _initialValue;

  /// Whether the current value equals the initial value.
  bool get isPristine => !isDirty;

  /// Whether the field has no validation error.
  ///
  /// Note: this reflects the result of the last [validate()] call.
  /// Call [validate()] first to ensure freshness.
  bool get isValid => _error.value == null;

  /// Whether an async validation is currently in progress.
  ///
  /// Reading this inside a [Derived] or [Vestige] auto-tracks it.
  bool get isValidating => _isValidating.value;

  /// The initial value this field was created with.
  T get initialValue => _initialValue;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Run the synchronous validator against the current value and update [error].
  ///
  /// Returns `true` if valid, `false` if invalid.
  /// Does NOT run the async validator — use [validateAsync] for that.
  ///
  /// ```dart
  /// if (email.validate()) {
  ///   // Good to go
  /// }
  /// ```
  bool validate() {
    _error.value = _validator?.call(value);
    return _error.value == null;
  }

  /// Run both synchronous and asynchronous validators.
  ///
  /// The sync validator runs first. If it fails, the async validator
  /// is skipped. Returns `true` if all validations pass.
  ///
  /// ```dart
  /// if (await username.validateAsync()) {
  ///   // Username is valid and available
  /// }
  /// ```
  Future<bool> validateAsync() async {
    // Run sync validator first
    _error.value = _validator?.call(value);
    if (_error.value != null) return false;

    // Run async validator if provided
    if (_asyncValidator != null) {
      _isValidating.value = true;
      try {
        _error.value = await _asyncValidator(value);
      } catch (e) {
        _error.value = e.toString();
      } finally {
        _isValidating.value = false;
      }
    }
    return _error.value == null;
  }

  /// Mark this field as touched (e.g., when the user focuses and blurs it).
  void touch() {
    _touched.value = true;
  }

  /// Reset to the initial value and clear the error.
  void reset() {
    value = _initialValue;
    _error.value = null;
    _touched.value = false;
  }

  /// Set the error manually (e.g., from server-side validation).
  void setError(String? errorMessage) {
    _error.value = errorMessage;
  }

  /// Clear the error without re-validating.
  void clearError() {
    _error.value = null;
  }

  /// Returns all managed reactive nodes (for disposal by Pillar).
  List<ReactiveNode> get managedNodes => [_error, _touched, _isValidating];

  @override
  void dispose() {
    _error.dispose();
    _touched.dispose();
    _isValidating.dispose();
    super.dispose();
  }
}

/// **ScrollGroup** — Manages a collection of [Scroll] fields as a form.
///
/// Provides aggregate validation, dirty checking, and reset across
/// all registered fields.
///
/// ## Usage
///
/// ```dart
/// class RegistrationPillar extends Pillar {
///   late final name = scroll('', validator: (v) =>
///     v.isEmpty ? 'Required' : null,
///   );
///   late final email = scroll('', validator: (v) =>
///     v.contains('@') ? null : 'Invalid email',
///   );
///   late final age = scroll(0, validator: (v) =>
///     v >= 18 ? null : 'Must be 18+',
///   );
///
///   late final form = ScrollGroup([name, email, age]);
///
///   void submit() {
///     if (!form.validateAll()) return;
///     // All valid — process form
///   }
/// }
/// ```
class ScrollGroup {
  final List<Scroll<dynamic>> _fields;

  /// Creates a form group tracking the given fields.
  ScrollGroup(this._fields);

  /// Whether all fields are valid (based on last validation).
  bool get isValid => _fields.every((f) => f.isValid);

  /// Whether any field has been modified from its initial value.
  bool get isDirty => _fields.any((f) => f.isDirty);

  /// Whether all fields still have their initial values.
  bool get isPristine => !isDirty;

  /// Whether any field has been touched.
  bool get isTouched => _fields.any((f) => f.isTouched);

  /// Validate all fields synchronously. Returns `true` if all are valid.
  bool validateAll() {
    bool allValid = true;
    for (final field in _fields) {
      if (!field.validate()) {
        allValid = false;
      }
    }
    return allValid;
  }

  /// Validate all fields including async validators.
  ///
  /// Runs sync validators first, then async validators for all fields
  /// that passed sync validation. Returns `true` if all pass.
  ///
  /// ```dart
  /// void submit() async {
  ///   if (!await form.validateAllAsync()) return;
  ///   // All valid — process form
  /// }
  /// ```
  Future<bool> validateAllAsync() async {
    bool allValid = true;
    for (final field in _fields) {
      if (!await field.validateAsync()) {
        allValid = false;
      }
    }
    return allValid;
  }

  /// Reset all fields to their initial values and clear errors.
  void resetAll() {
    for (final field in _fields) {
      field.reset();
    }
  }

  /// Touch all fields.
  void touchAll() {
    for (final field in _fields) {
      field.touch();
    }
  }

  /// Clear all errors without re-validating.
  void clearAllErrors() {
    for (final field in _fields) {
      field.clearError();
    }
  }

  /// The list of fields that currently have errors.
  List<Scroll<dynamic>> get invalidFields =>
      _fields.where((f) => !f.isValid).toList();

  /// The number of fields in this form group.
  int get fieldCount => _fields.length;
}
