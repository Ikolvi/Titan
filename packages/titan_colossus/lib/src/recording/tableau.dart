import 'dart:convert';
import 'dart:typed_data';

import 'glyph.dart';

// ---------------------------------------------------------------------------
// Tableau — Screen Snapshot
// ---------------------------------------------------------------------------

/// **Tableau** — a frozen scene capturing every visible [Glyph].
///
/// Captured automatically by Colossus at key moments during
/// [Shade] recording. The AI reads Tableaux to understand what
/// the user saw at each step of the flow.
///
/// ## Why "Tableau"?
///
/// A frozen dramatic scene — the screen at any moment is a
/// Tableau, a complete composition of Glyphs in a meaningful
/// layout.
///
/// ## Usage
///
/// ```dart
/// // Find what the user tapped
/// final glyph = tableau.glyphAt(187.5, 642.0);
/// print(glyph?.label); // "Submit Order"
///
/// // Get all interactive elements
/// final buttons = tableau.interactiveGlyphs;
///
/// // Compare two screen states
/// final diff = tableau.diff(previousTableau);
/// print(diff); // "ADDED: Dialog 'Confirm?', CHANGED: Button disabled→enabled"
/// ```
class Tableau {
  /// Index within the session's Tableau list.
  final int index;

  /// Time since recording start.
  final Duration timestamp;

  /// Route path at capture time (e.g., `'/cart'`).
  final String? route;

  /// Screen width in logical pixels at capture time.
  final double screenWidth;

  /// Screen height in logical pixels at capture time.
  final double screenHeight;

  /// All visible [Glyph]s, ordered by depth (deepest/frontmost first).
  final List<Glyph> glyphs;

  /// The [Imprint] index that triggered this capture.
  ///
  /// `-1` for the initial Tableau (recording start).
  final int triggerImprintIndex;

  /// Optional PNG screenshot bytes (only when `enableScreenCapture` is on).
  ///
  /// Stored externally by [ShadeVault] as separate PNG files to keep
  /// session JSON lean. This field is populated only when loading
  /// with screenshots or during a live capture.
  final Uint8List? fresco;

  /// Creates a [Tableau] from captured data.
  const Tableau({
    required this.index,
    required this.timestamp,
    this.route,
    required this.screenWidth,
    required this.screenHeight,
    required this.glyphs,
    this.triggerImprintIndex = -1,
    this.fresco,
  });

  // -----------------------------------------------------------------------
  // Queries
  // -----------------------------------------------------------------------

  /// All interactive [Glyph]s on this Tableau.
  List<Glyph> get interactiveGlyphs =>
      glyphs.where((g) => g.isInteractive).toList();

  /// Find the frontmost interactive [Glyph] at a given position.
  ///
  /// Used to resolve "what did the user tap?" from [Imprint] coordinates.
  /// Returns `null` if no interactive Glyph contains the point.
  ///
  /// Searches deepest (frontmost) first, so overlapping elements
  /// are resolved correctly.
  Glyph? glyphAt(double x, double y) {
    for (final glyph in glyphs) {
      if (glyph.containsPoint(x, y) && glyph.isInteractive) {
        return glyph;
      }
    }
    return null;
  }

  /// Find the frontmost [Glyph] at a given position, including
  /// non-interactive elements (text, images, etc.).
  Glyph? anyGlyphAt(double x, double y) {
    for (final glyph in glyphs) {
      if (glyph.containsPoint(x, y)) {
        return glyph;
      }
    }
    return null;
  }

  /// Find all [Glyph]s matching a label (case-insensitive).
  List<Glyph> findByLabel(String label) {
    final lower = label.toLowerCase();
    return glyphs.where((g) {
      final glyphLabel = g.label?.toLowerCase();
      return glyphLabel != null && glyphLabel.contains(lower);
    }).toList();
  }

  /// Find the first [Glyph] matching a widget type.
  Glyph? findByType(String widgetType) {
    for (final glyph in glyphs) {
      if (glyph.widgetType.contains(widgetType)) return glyph;
    }
    return null;
  }

  /// Find a [Glyph] by its [key].
  Glyph? findByKey(String key) {
    for (final glyph in glyphs) {
      if (glyph.key == key) return glyph;
    }
    return null;
  }

  // -----------------------------------------------------------------------
  // Summary
  // -----------------------------------------------------------------------

  /// Auto-generated summary for AI consumption.
  ///
  /// Example:
  /// ```
  /// "Route: /cart | 3 interactive, 8 visible | ElevatedButton: 'Checkout',
  ///  Text: '3 items', Text: 'Total: $117.97'"
  /// ```
  String get summary {
    final buffer = StringBuffer();
    if (route != null) buffer.write('Route: $route | ');
    buffer.write(
      '${interactiveGlyphs.length} interactive, '
      '${glyphs.length} visible',
    );

    final labeled = glyphs.where((g) => g.label != null).take(5);
    if (labeled.isNotEmpty) {
      buffer.write(' | ');
      buffer.write(
        labeled.map((g) => '${g.widgetType}: "${g.label}"').join(', '),
      );
      if (glyphs.where((g) => g.label != null).length > 5) {
        buffer.write(', ...');
      }
    }

    return buffer.toString();
  }

  // -----------------------------------------------------------------------
  // Diff
  // -----------------------------------------------------------------------

  /// Compute differences between `this` and [other].
  ///
  /// Returns a [TableauDiff] describing what changed from `this`
  /// (previous state) to [other] (current state). Used by AI to
  /// understand the effect of each user interaction.
  ///
  /// ```dart
  /// final diff = before.diff(after);
  /// // diff.added = elements in 'after' but not in 'before'
  /// ```
  TableauDiff diff(Tableau other) {
    return TableauDiff.compute(previous: this, current: other);
  }

  // -----------------------------------------------------------------------
  // Structural equality (for deduplication)
  // -----------------------------------------------------------------------

  /// Whether this Tableau is structurally identical to [other].
  ///
  /// Used by [Shade] to skip capturing redundant Tableaux when
  /// nothing visible changed after an interaction.
  bool isStructurallyEqual(Tableau other) {
    if (route != other.route) return false;
    if (glyphs.length != other.glyphs.length) return false;
    for (var i = 0; i < glyphs.length; i++) {
      if (glyphs[i] != other.glyphs[i]) return false;
    }
    return true;
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Converts this Tableau to a JSON-serializable map.
  ///
  /// Note: [fresco] (screenshot bytes) is NOT included in the map.
  /// Screenshots are stored separately by [ShadeVault] as PNG files
  /// to keep session JSON lean.
  Map<String, dynamic> toMap() => {
    'idx': index,
    'ts': timestamp.inMicroseconds,
    if (route != null) 'route': route,
    'sw': screenWidth,
    'sh': screenHeight,
    'trigger': triggerImprintIndex,
    'glyphs': List.generate(glyphs.length, (i) => glyphs[i].toMap()),
  };

  /// Creates a [Tableau] from a deserialized map.
  factory Tableau.fromMap(Map<String, dynamic> map) {
    return Tableau(
      index: map['idx'] as int,
      timestamp: Duration(microseconds: map['ts'] as int),
      route: map['route'] as String?,
      screenWidth: (map['sw'] as num).toDouble(),
      screenHeight: (map['sh'] as num).toDouble(),
      triggerImprintIndex: map['trigger'] as int? ?? -1,
      glyphs: (map['glyphs'] as List)
          .map((e) => Glyph.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Serializes this Tableau to a JSON string.
  String toJson() => jsonEncode(toMap());

  /// Creates a [Tableau] from a JSON string.
  factory Tableau.fromJson(String json) {
    return Tableau.fromMap(jsonDecode(json) as Map<String, dynamic>);
  }

  /// Creates a copy of this Tableau with the given fields replaced.
  Tableau copyWith({
    int? index,
    Duration? timestamp,
    String? route,
    double? screenWidth,
    double? screenHeight,
    List<Glyph>? glyphs,
    int? triggerImprintIndex,
    Uint8List? fresco,
  }) {
    return Tableau(
      index: index ?? this.index,
      timestamp: timestamp ?? this.timestamp,
      route: route ?? this.route,
      screenWidth: screenWidth ?? this.screenWidth,
      screenHeight: screenHeight ?? this.screenHeight,
      glyphs: glyphs ?? this.glyphs,
      triggerImprintIndex: triggerImprintIndex ?? this.triggerImprintIndex,
      fresco: fresco ?? this.fresco,
    );
  }

  @override
  String toString() =>
      'Tableau(#$index, ${route ?? "?"}, '
      '${glyphs.length} glyphs, '
      '${timestamp.inMilliseconds}ms)';
}

// ---------------------------------------------------------------------------
// TableauDiff — Change detection between screen states
// ---------------------------------------------------------------------------

/// Describes the differences between two [Tableau] snapshots.
///
/// Used by AI to understand the effect of each user interaction:
///
/// ```dart
/// final diff = currentTableau.diff(previousTableau);
/// print(diff);
/// // "Route: /cart → /checkout
/// //  ADDED: TextField 'Address'
/// //  REMOVED: ListTile 'Headphones'
/// //  CHANGED: Text '3 items' → '2 items'"
/// ```
class TableauDiff {
  /// Route change (null if unchanged).
  final ({String from, String to})? routeChange;

  /// Glyphs present in current but not in previous.
  final List<Glyph> added;

  /// Glyphs present in previous but not in current.
  final List<Glyph> removed;

  /// Glyphs that exist in both but with changes.
  final List<GlyphChange> changed;

  const TableauDiff({
    this.routeChange,
    this.added = const [],
    this.removed = const [],
    this.changed = const [],
  });

  /// Whether anything changed between the two Tableaux.
  bool get isEmpty =>
      routeChange == null &&
      added.isEmpty &&
      removed.isEmpty &&
      changed.isEmpty;

  /// Whether something changed.
  bool get isNotEmpty => !isEmpty;

  /// Whether something changed between the two Tableaux.
  ///
  /// Convenience alias for [isNotEmpty].
  bool get hasChanges => isNotEmpty;

  /// Compute the diff between two Tableaux.
  ///
  /// Matching is done by (widgetType + label) identity. If a Glyph
  /// exists in both but with different properties (e.g., label changed,
  /// enabled state changed), it appears in [changed].
  factory TableauDiff.compute({
    required Tableau previous,
    required Tableau current,
  }) {
    final routeChange =
        (previous.route != current.route &&
            previous.route != null &&
            current.route != null)
        ? (from: previous.route!, to: current.route!)
        : null;

    // Build identity maps: "WidgetType:Label" → Glyph
    final prevMap = <String, Glyph>{};
    for (final g in previous.glyphs) {
      final id = _glyphIdentity(g);
      prevMap[id] = g;
    }

    final currMap = <String, Glyph>{};
    for (final g in current.glyphs) {
      final id = _glyphIdentity(g);
      currMap[id] = g;
    }

    final added = <Glyph>[];
    final removed = <Glyph>[];
    final changed = <GlyphChange>[];

    // Find added and changed
    for (final entry in currMap.entries) {
      final prev = prevMap[entry.key];
      if (prev == null) {
        added.add(entry.value);
      } else if (prev != entry.value) {
        changed.add(GlyphChange(previous: prev, current: entry.value));
      }
    }

    // Find removed
    for (final entry in prevMap.entries) {
      if (!currMap.containsKey(entry.key)) {
        removed.add(entry.value);
      }
    }

    return TableauDiff(
      routeChange: routeChange,
      added: added,
      removed: removed,
      changed: changed,
    );
  }

  /// Generate a human-readable diff description for AI.
  @override
  String toString() {
    if (isEmpty) return 'No changes';

    final buffer = StringBuffer();
    if (routeChange != null) {
      buffer.writeln('Route: ${routeChange!.from} → ${routeChange!.to}');
    }
    for (final glyph in added) {
      buffer.writeln('ADDED: ${glyph.widgetType} "${glyph.label ?? "?"}"');
    }
    for (final glyph in removed) {
      buffer.writeln('REMOVED: ${glyph.widgetType} "${glyph.label ?? "?"}"');
    }
    for (final change in changed) {
      buffer.writeln('CHANGED: ${change.description}');
    }
    return buffer.toString().trimRight();
  }

  /// Identity key for diff matching.
  static String _glyphIdentity(Glyph g) {
    // Use key if available (most precise)
    if (g.key != null) return 'key:${g.key}';
    // Use fieldId for text fields
    if (g.fieldId != null) return 'field:${g.fieldId}';
    // Fall back to type + label + depth for uniqueness
    return '${g.widgetType}:${g.label ?? "?"}:${g.depth}';
  }
}

// ---------------------------------------------------------------------------
// GlyphChange — A single changed element
// ---------------------------------------------------------------------------

/// Represents a [Glyph] that exists in both Tableaux but has changed.
class GlyphChange {
  /// The Glyph in the previous Tableau.
  final Glyph previous;

  /// The Glyph in the current Tableau.
  final Glyph current;

  const GlyphChange({required this.previous, required this.current});

  /// Whether the label changed.
  bool get labelChanged => previous.label != current.label;

  /// Whether the enabled state changed.
  bool get enabledChanged => previous.isEnabled != current.isEnabled;

  /// Whether the current value changed.
  bool get valueChanged => previous.currentValue != current.currentValue;

  /// Whether the position moved.
  bool get positionChanged =>
      previous.left != current.left || previous.top != current.top;

  /// Human-readable description of the change.
  String get description {
    final parts = <String>[];
    final name = '${current.widgetType} "${current.label ?? "?"}"';

    if (labelChanged) {
      parts.add('"${previous.label}" → "${current.label}"');
    }
    if (enabledChanged) {
      parts.add(
        previous.isEnabled ? 'enabled → disabled' : 'disabled → enabled',
      );
    }
    if (valueChanged) {
      parts.add(
        'value: "${previous.currentValue}" → "${current.currentValue}"',
      );
    }
    if (positionChanged) {
      parts.add(
        'moved (${previous.left.round()},${previous.top.round()}) → '
        '(${current.left.round()},${current.top.round()})',
      );
    }

    return parts.isEmpty ? '$name (minor change)' : '$name ${parts.join(", ")}';
  }

  @override
  String toString() => 'GlyphChange($description)';
}
