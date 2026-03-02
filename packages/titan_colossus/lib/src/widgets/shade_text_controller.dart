import 'package:flutter/widgets.dart';

import '../recording/shade.dart';

// ---------------------------------------------------------------------------
// ShadeTextController — Auto-tracking TextEditingController
// ---------------------------------------------------------------------------

/// **ShadeTextController** — a [TextEditingController] that automatically
/// records text changes to [Shade].
///
/// Drop-in replacement for [TextEditingController]. When [Shade] is
/// recording, every text or cursor change is captured as a
/// [ImprintType.textInput] event. During [Phantom] replay, these
/// events reproduce the exact text input sequence.
///
/// ## Usage
///
/// ```dart
/// final shade = Colossus.instance.shade;
///
/// final nameController = ShadeTextController(
///   shade: shade,
///   fieldId: 'hero_name',
///   text: 'Kael',
/// );
///
/// TextField(controller: nameController)
/// ```
///
/// ## How It Works
///
/// [ShadeTextController] listens to its own value changes and
/// records each change as an [Imprint] with the full text editing
/// state (text, selection, composing region). The [fieldId] links
/// the recording to a specific text field for replay targeting.
///
/// ## Lifecycle
///
/// Dispose the controller normally — the listener is removed
/// automatically:
///
/// ```dart
/// @override
/// void dispose() {
///   nameController.dispose();
///   super.dispose();
/// }
/// ```
class ShadeTextController extends TextEditingController {
  /// The [Shade] recorder to report text changes to.
  final Shade _shade;

  /// An identifier for this text field.
  ///
  /// Used during replay to target the correct field.
  final String? fieldId;

  /// Whether to suppress recording (e.g. during programmatic updates).
  bool _suppressed = false;

  /// Creates a [ShadeTextController] that records changes to [shade].
  ///
  /// The [fieldId] helps identify this field during replay.
  /// When [fieldId] is provided, the controller auto-registers with
  /// [Shade]'s text controller registry, allowing [Phantom] to
  /// directly set text during replay without opening the keyboard.
  /// Pass [text] for the initial value.
  ShadeTextController({required Shade shade, this.fieldId, super.text})
    : _shade = shade {
    addListener(_onValueChanged);
    if (fieldId != null) {
      _shade.registerTextController(fieldId!, this);
    }
  }

  /// The previous text value, used to detect actual changes.
  String _previousText = '';

  void _onValueChanged() {
    if (_suppressed) return;

    // Only record if text actually changed (not just cursor movement)
    if (value.text != _previousText) {
      _previousText = value.text;
      _shade.recordTextChange(value, fieldId: fieldId);
    }
  }

  /// Update the text value without recording an imprint.
  ///
  /// Use this during replay or programmatic updates to avoid
  /// creating duplicate recordings.
  void setTextSilently(String newText) {
    _suppressed = true;
    text = newText;
    _previousText = newText;
    _suppressed = false;
  }

  /// Update the full editing value without recording an imprint.
  void setValueSilently(TextEditingValue newValue) {
    _suppressed = true;
    value = newValue;
    _previousText = newValue.text;
    _suppressed = false;
  }

  @override
  void dispose() {
    removeListener(_onValueChanged);
    if (fieldId != null) {
      _shade.unregisterTextController(fieldId!);
    }
    super.dispose();
  }
}
