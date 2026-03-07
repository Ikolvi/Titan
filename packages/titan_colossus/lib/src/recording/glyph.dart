// ---------------------------------------------------------------------------
// Glyph — UI Element Descriptor
// ---------------------------------------------------------------------------

/// **Glyph** — a carved symbol describing one UI element on screen.
///
/// Contains everything an AI agent needs to understand what this
/// element is, where it is, what it does, and what it says.
///
/// Glyphs are captured automatically by Colossus during [Shade]
/// recording — no developer annotations required. They are
/// extracted from Flutter's existing [Element] tree, [RenderObject]
/// bounds, and [Semantics] tree.
///
/// ## Why "Glyph"?
///
/// Carved symbols on a Titan monument. Each Glyph preserves a
/// UI element's identity for future readers (AI agents) to decipher.
///
/// ## Structure
///
/// ```dart
/// final glyph = Glyph(
///   widgetType: 'ElevatedButton',
///   label: 'Submit Order',
///   left: 120.0,
///   top: 640.0,
///   width: 160.0,
///   height: 48.0,
///   isInteractive: true,
///   interactionType: 'tap',
/// );
/// ```
///
/// ## AI Usage
///
/// An AI reading a [Tableau] can inspect each Glyph to understand
/// what the user saw and what they could interact with:
///
/// ```dart
/// final interactiveGlyphs = tableau.glyphs
///     .where((g) => g.isInteractive)
///     .toList();
/// for (final glyph in interactiveGlyphs) {
///   print('${glyph.widgetType}: "${glyph.label}" at '
///         '(${glyph.centerX}, ${glyph.centerY})');
/// }
/// ```
class Glyph {
  /// Widget runtime type: `'ElevatedButton'`, `'TextField'`, `'Text'`, etc.
  final String widgetType;

  /// Human-readable label extracted automatically:
  ///
  /// - Buttons → child [Text] widget (`"Submit Order"`)
  /// - Text fields → hint text or label (`"Enter address"`)
  /// - Text → the displayed text (truncated to [maxLabelLength] chars)
  /// - Icons → tooltip or semantic label
  /// - Images → semantic label
  ///
  /// May be `null` for layout widgets without visible text.
  final String? label;

  /// Left edge of the bounding box in logical pixels.
  final double left;

  /// Top edge of the bounding box in logical pixels.
  final double top;

  /// Width of the bounding box in logical pixels.
  final double width;

  /// Height of the bounding box in logical pixels.
  final double height;

  /// Whether this element accepts user interaction.
  final bool isInteractive;

  /// Interaction type: `'tap'`, `'longPress'`, `'textInput'`, `'scroll'`,
  /// `'toggle'`, `'slider'`, `'dropdown'`, `'checkbox'`, `'radio'`,
  /// `'switch'`.
  final String? interactionType;

  /// [ShadeTextController] field ID (if applicable).
  ///
  /// Links this Glyph to [Shade]'s text recording automatically.
  final String? fieldId;

  /// Widget key (if set by developer via [Key] or [ValueKey]).
  final String? key;

  /// Semantic role from Flutter's [Semantics] tree:
  /// `'button'`, `'textField'`, `'header'`, `'image'`, `'link'`, etc.
  final String? semanticRole;

  /// Current enabled state. `false` when the widget is disabled.
  final bool isEnabled;

  /// Current value for stateful widgets:
  ///
  /// - Checkboxes → `"true"` / `"false"`
  /// - Sliders → `"0.75"`
  /// - Switches → `"on"` / `"off"`
  /// - Text fields → current text content
  final String? currentValue;

  /// Nearest ancestor widget types (up to 5) for context.
  ///
  /// Example: `['Scaffold', 'Column', 'Card', 'Row', 'Padding']`
  final List<String> ancestors;

  /// Tree depth (for z-ordering in hit-test resolution).
  ///
  /// Deeper widgets are painted on top of shallower ones.
  final int depth;

  /// Maximum label length before truncation.
  static const int maxLabelLength = 100;

  /// Creates a [Glyph] from extracted widget properties.
  const Glyph({
    required this.widgetType,
    this.label,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.isInteractive = false,
    this.interactionType,
    this.fieldId,
    this.key,
    this.semanticRole,
    this.isEnabled = true,
    this.currentValue,
    this.ancestors = const [],
    this.depth = 0,
  });

  /// Center X coordinate (convenience for AI coordinate matching).
  double get centerX => left + width / 2;

  /// Center Y coordinate (convenience for AI coordinate matching).
  double get centerY => top + height / 2;

  /// Right edge of the bounding box.
  double get right => left + width;

  /// Bottom edge of the bounding box.
  double get bottom => top + height;

  /// Whether a point hits this Glyph's bounding box.
  bool containsPoint(double x, double y) =>
      x >= left && x <= right && y >= top && y <= bottom;

  // -----------------------------------------------------------------------
  // Serialization — compact keys matching Imprint style
  // -----------------------------------------------------------------------

  /// Converts this Glyph to a JSON-serializable map.
  ///
  /// Uses compact keys for minimal serialization size:
  /// - `'wt'` → widgetType
  /// - `'l'` → label
  /// - `'x'` / `'y'` / `'w'` / `'h'` → bounds
  /// - `'ia'` → isInteractive
  /// - `'it'` → interactionType
  /// - `'fid'` → fieldId
  /// - `'k'` → key
  /// - `'sr'` → semanticRole
  /// - `'en'` → isEnabled
  /// - `'cv'` → currentValue
  /// - `'anc'` → ancestors
  /// - `'d'` → depth
  Map<String, dynamic> toMap() => {
    'wt': widgetType,
    if (label != null) 'l': label,
    'x': left,
    'y': top,
    'w': width,
    'h': height,
    if (isInteractive) 'ia': true,
    if (interactionType != null) 'it': interactionType,
    if (fieldId != null) 'fid': fieldId,
    if (key != null) 'k': key,
    if (semanticRole != null) 'sr': semanticRole,
    if (!isEnabled) 'en': false,
    if (currentValue != null) 'cv': currentValue,
    if (ancestors.isNotEmpty) 'anc': ancestors,
    if (depth != 0) 'd': depth,
  };

  /// Creates a [Glyph] from a deserialized map.
  factory Glyph.fromMap(Map<String, dynamic> map) {
    return Glyph(
      widgetType: map['wt'] as String,
      label: map['l'] as String?,
      left: (map['x'] as num).toDouble(),
      top: (map['y'] as num).toDouble(),
      width: (map['w'] as num).toDouble(),
      height: (map['h'] as num).toDouble(),
      isInteractive: map['ia'] as bool? ?? false,
      interactionType: map['it'] as String?,
      fieldId: map['fid'] as String?,
      key: map['k'] as String?,
      semanticRole: map['sr'] as String?,
      isEnabled: map['en'] as bool? ?? true,
      currentValue: map['cv'] as String?,
      ancestors: (map['anc'] as List?)?.cast<String>() ?? const [],
      depth: map['d'] as int? ?? 0,
    );
  }

  /// Creates a copy of this Glyph with the given fields replaced.
  Glyph copyWith({
    String? widgetType,
    String? label,
    double? left,
    double? top,
    double? width,
    double? height,
    bool? isInteractive,
    String? interactionType,
    String? fieldId,
    String? key,
    String? semanticRole,
    bool? isEnabled,
    String? currentValue,
    List<String>? ancestors,
    int? depth,
  }) {
    return Glyph(
      widgetType: widgetType ?? this.widgetType,
      label: label ?? this.label,
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
      isInteractive: isInteractive ?? this.isInteractive,
      interactionType: interactionType ?? this.interactionType,
      fieldId: fieldId ?? this.fieldId,
      key: key ?? this.key,
      semanticRole: semanticRole ?? this.semanticRole,
      isEnabled: isEnabled ?? this.isEnabled,
      currentValue: currentValue ?? this.currentValue,
      ancestors: ancestors ?? this.ancestors,
      depth: depth ?? this.depth,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Glyph &&
          runtimeType == other.runtimeType &&
          widgetType == other.widgetType &&
          label == other.label &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height &&
          isInteractive == other.isInteractive &&
          interactionType == other.interactionType &&
          fieldId == other.fieldId &&
          key == other.key &&
          semanticRole == other.semanticRole &&
          isEnabled == other.isEnabled &&
          currentValue == other.currentValue &&
          depth == other.depth;

  @override
  int get hashCode => Object.hash(
    widgetType,
    label,
    left,
    top,
    width,
    height,
    isInteractive,
    interactionType,
    fieldId,
    key,
    semanticRole,
    isEnabled,
    currentValue,
    depth,
  );

  @override
  String toString() {
    final buffer = StringBuffer('Glyph($widgetType');
    if (label != null) buffer.write(': "$label"');
    buffer.write(' at ($left, $top)');
    if (isInteractive) buffer.write(' [${interactionType ?? "interactive"}]');
    if (!isEnabled) buffer.write(' [disabled]');
    buffer.write(')');
    return buffer.toString();
  }
}
