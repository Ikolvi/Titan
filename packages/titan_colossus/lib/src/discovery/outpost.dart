import '../recording/glyph.dart';
import '../recording/tableau.dart';
import 'march.dart';
import 'signet.dart';

// ---------------------------------------------------------------------------
// Outpost — A Discovered Screen
// ---------------------------------------------------------------------------

/// **Outpost** — a discovered screen in the app's flow graph.
///
/// Each Outpost represents a unique screen the [Scout] has observed,
/// identified by its [Signet]. Contains everything an AI agent needs
/// to know about what's on this screen and how to interact with it.
///
/// ## Why "Outpost"?
///
/// A fortified position in the Titan's territory. Each screen is an
/// Outpost with its garrison of elements, its exits, and its defenses.
///
/// ## Usage
///
/// ```dart
/// final outpost = terrain.outposts['/login'];
/// print(outpost?.displayName); // "Login Screen"
/// print(outpost?.interactiveElements.length); // 3
/// print(outpost?.exits.length); // 2
/// ```
class Outpost {
  /// Unique screen fingerprint.
  final Signet signet;

  /// Route pattern (e.g., `/login`, `/quest/:id`).
  final String routePattern;

  /// Human-readable screen name (auto-generated or user-assigned).
  ///
  /// Example: `"Login Screen"`, `"Quest Detail"`, `"Hero Profile"`
  String displayName;

  /// All interactive elements observed on this screen.
  ///
  /// Merged from multiple observations — if button "X" appeared in
  /// any observation, it's listed here.
  final List<OutpostElement> interactiveElements;

  /// All text/display (non-interactive) elements observed.
  final List<OutpostElement> displayElements;

  /// Whether this screen requires authentication.
  ///
  /// Determined by [Lineage] analysis: if every observed path to
  /// this screen passes through a login screen, `requiresAuth = true`.
  bool requiresAuth;

  /// Tags automatically assigned based on content analysis.
  ///
  /// Example: `["auth", "form"]` for login, `["list", "scrollable"]`
  /// for quest list.
  final List<String> tags;

  /// Number of times this screen has been observed.
  int observationCount;

  /// Outgoing transitions ([March]es) from this screen.
  final List<March> exits;

  /// Incoming transitions ([March]es) to this screen.
  final List<March> entrances;

  /// Screen width from last observation.
  double screenWidth;

  /// Screen height from last observation.
  double screenHeight;

  /// Creates an [Outpost] from its components.
  Outpost({
    required this.signet,
    required this.routePattern,
    required this.displayName,
    List<OutpostElement>? interactiveElements,
    List<OutpostElement>? displayElements,
    this.requiresAuth = false,
    List<String>? tags,
    this.observationCount = 0,
    List<March>? exits,
    List<March>? entrances,
    this.screenWidth = 0,
    this.screenHeight = 0,
  }) : interactiveElements = interactiveElements ?? [],
       displayElements = displayElements ?? [],
       tags = tags ?? [],
       exits = exits ?? [],
       entrances = entrances ?? [];

  /// Create an [Outpost] from a [Tableau] snapshot.
  ///
  /// Extracts all elements and auto-generates metadata.
  factory Outpost.fromTableau(Tableau tableau, {String? routePattern}) {
    final route = routePattern ?? tableau.route ?? '/';
    final signet = Signet.fromTableau(tableau, routePattern: route);

    final interactive = <OutpostElement>[];
    final display = <OutpostElement>[];

    for (final glyph in tableau.glyphs) {
      final elem = OutpostElement.fromGlyph(glyph);
      if (glyph.isInteractive) {
        interactive.add(elem);
      } else if (glyph.label != null) {
        display.add(elem);
      }
    }

    final tags = _autoTag(route, tableau.glyphs);
    final displayName = _generateDisplayName(route, tags);

    return Outpost(
      signet: signet,
      routePattern: route,
      displayName: displayName,
      interactiveElements: interactive,
      displayElements: display,
      tags: tags,
      observationCount: 1,
      screenWidth: tableau.screenWidth,
      screenHeight: tableau.screenHeight,
    );
  }

  /// Merge observations from another [Tableau] for the same screen.
  ///
  /// Updates element lists and increments observation count.
  void mergeObservation(Tableau tableau) {
    observationCount++;
    screenWidth = tableau.screenWidth;
    screenHeight = tableau.screenHeight;

    // Merge interactive elements
    for (final glyph in tableau.glyphs) {
      if (glyph.isInteractive) {
        _mergeElement(interactiveElements, OutpostElement.fromGlyph(glyph));
      } else if (glyph.label != null) {
        _mergeElement(displayElements, OutpostElement.fromGlyph(glyph));
      }
    }
  }

  // -----------------------------------------------------------------------
  // AI Output
  // -----------------------------------------------------------------------

  /// AI-readable summary of this screen.
  ///
  /// ```
  /// SCREEN: Login Screen (/login)
  /// AUTH: not required
  /// TAGS: auth, form
  /// OBSERVED: 8 times
  /// INTERACTIVE: TextField "Hero Name", ElevatedButton "Enter the Realm"
  /// DISPLAY: Text "Welcome to the Questboard"
  /// EXITS: → / (tap "Enter the Realm"), → /register (tap "Register")
  /// ENTRANCES: ← / (redirect)
  /// ```
  String toAiSummary() {
    final buffer = StringBuffer();
    buffer.writeln('SCREEN: $displayName ($routePattern)');
    buffer.writeln('AUTH: ${requiresAuth ? "required" : "not required"}');
    if (tags.isNotEmpty) buffer.writeln('TAGS: ${tags.join(", ")}');
    buffer.writeln('OBSERVED: $observationCount times');

    if (interactiveElements.isNotEmpty) {
      buffer.writeln(
        'INTERACTIVE: ${interactiveElements.map((e) => e.toShortString()).join(", ")}',
      );
    }

    if (displayElements.isNotEmpty) {
      final display = displayElements.take(10).map((e) => e.toShortString());
      buffer.write('DISPLAY: ${display.join(", ")}');
      if (displayElements.length > 10) buffer.write(', ...');
      buffer.writeln();
    }

    if (exits.isNotEmpty) {
      buffer.writeln(
        'EXITS: ${exits.map((m) => m.toShortString()).join(", ")}',
      );
    }

    if (entrances.isNotEmpty) {
      buffer.writeln(
        'ENTRANCES: ${entrances.map((m) => '← ${m.fromRoute} (${m.trigger.name})').join(", ")}',
      );
    }

    return buffer.toString().trimRight();
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'signet': signet.toJson(),
    'routePattern': routePattern,
    'displayName': displayName,
    'requiresAuth': requiresAuth,
    'tags': tags,
    'observationCount': observationCount,
    'screenWidth': screenWidth,
    'screenHeight': screenHeight,
    'interactiveElements': interactiveElements.map((e) => e.toJson()).toList(),
    'displayElements': displayElements.map((e) => e.toJson()).toList(),
    'exits': exits.map((m) => m.toJson()).toList(),
    'entrances': entrances.map((m) => m.toJson()).toList(),
  };

  /// Deserialize from JSON map.
  factory Outpost.fromJson(Map<String, dynamic> json) {
    return Outpost(
      signet: Signet.fromJson(json['signet'] as Map<String, dynamic>),
      routePattern: json['routePattern'] as String,
      displayName: json['displayName'] as String,
      requiresAuth: json['requiresAuth'] as bool? ?? false,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      observationCount: json['observationCount'] as int? ?? 0,
      screenWidth: (json['screenWidth'] as num?)?.toDouble() ?? 0,
      screenHeight: (json['screenHeight'] as num?)?.toDouble() ?? 0,
      interactiveElements:
          (json['interactiveElements'] as List?)
              ?.map((e) => OutpostElement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      displayElements:
          (json['displayElements'] as List?)
              ?.map((e) => OutpostElement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      exits:
          (json['exits'] as List?)
              ?.map((e) => March.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      entrances:
          (json['entrances'] as List?)
              ?.map((e) => March.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  String toString() =>
      'Outpost($displayName, $routePattern, '
      '${interactiveElements.length} interactive, '
      '${observationCount}x observed)';

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  /// Merge an element into a list, incrementing frequency if it exists.
  static void _mergeElement(List<OutpostElement> list, OutpostElement element) {
    final existing = list.cast<OutpostElement?>().firstWhere(
      (e) => e!.matches(element),
      orElse: () => null,
    );
    if (existing != null) {
      existing.frequency++;
      // Update value if changed
      if (element.lastKnownValue != null) {
        existing.lastKnownValue = element.lastKnownValue;
      }
    } else {
      list.add(element);
    }
  }

  /// Auto-generate tags from route and elements.
  static List<String> _autoTag(String route, List<Glyph> glyphs) {
    final tags = <String>[];

    // Route-based tags
    final lower = route.toLowerCase();
    if (lower.contains('login') || lower.contains('signin')) {
      tags.add('auth');
    }
    if (lower.contains('register') || lower.contains('signup')) {
      tags.add('registration');
    }
    if (lower.contains('profile') || lower.contains('account')) {
      tags.add('profile');
    }
    if (lower.contains('setting')) tags.add('settings');

    // Element-based tags
    final hasTextInput = glyphs.any((g) => g.interactionType == 'textInput');
    final hasSubmit = glyphs.any(
      (g) =>
          g.isInteractive &&
          g.interactionType == 'tap' &&
          _isSubmitLabel(g.label),
    );
    if (hasTextInput && hasSubmit) tags.add('form');
    if (hasTextInput && !hasSubmit) tags.add('input');

    final hasList = glyphs.any(
      (g) =>
          g.widgetType.contains('ListView') ||
          g.widgetType.contains('ListTile'),
    );
    if (hasList) tags.add('list');

    final hasScroll = glyphs.any(
      (g) => g.widgetType.contains('Scroll') || g.interactionType == 'scroll',
    );
    if (hasScroll) tags.add('scrollable');

    final hasNav = glyphs.any(
      (g) =>
          g.widgetType.contains('NavigationDestination') ||
          g.widgetType.contains('BottomNavigationBar') ||
          g.widgetType.contains('TabBar'),
    );
    if (hasNav) tags.add('navigation');

    final hasToggle = glyphs.any(
      (g) =>
          g.interactionType == 'toggle' ||
          g.interactionType == 'checkbox' ||
          g.interactionType == 'switch',
    );
    if (hasToggle) tags.add('toggles');

    return tags;
  }

  /// Generate a display name from route and tags.
  static String _generateDisplayName(String route, List<String> tags) {
    if (route == '/') return 'Home';

    // Clean route segments into Title Case
    final segments = route
        .replaceAll(RegExp(r'^/'), '')
        .split('/')
        .where((s) => !s.startsWith(':'))
        .map((s) {
          return s
              .replaceAll('_', ' ')
              .replaceAll('-', ' ')
              .split(' ')
              .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
              .join(' ');
        });

    final name = segments.join(' > ');
    if (name.isEmpty) return 'Screen';
    return name;
  }
}

// ---------------------------------------------------------------------------
// OutpostElement — An element observed on a screen
// ---------------------------------------------------------------------------

/// Whether a label looks like a submit button.
bool _isSubmitLabel(String? label) {
  if (label == null) return false;
  final lower = label.toLowerCase();
  return lower.contains('submit') ||
      lower.contains('login') ||
      lower.contains('sign') ||
      lower.contains('save') ||
      lower.contains('register') ||
      lower.contains('create') ||
      lower.contains('send') ||
      lower.contains('enter') ||
      lower.contains('confirm');
}

/// An element observed on an [Outpost] screen.
///
/// Aggregated across multiple observations to build a complete
/// picture of what exists on a given screen.
class OutpostElement {
  /// Flutter widget type (e.g., `"ElevatedButton"`, `"TextField"`).
  final String widgetType;

  /// Visible label text (may be null for unlabeled elements).
  final String? label;

  /// Interaction type: `"tap"`, `"textInput"`, `"scroll"`, etc.
  final String? interactionType;

  /// Semantic role: `"button"`, `"textField"`, `"header"`, etc.
  final String? semanticRole;

  /// Developer-assigned widget key.
  final String? key;

  /// Whether this element is interactive.
  final bool isInteractive;

  /// Whether the element was enabled last time observed.
  bool isEnabled;

  /// Last known value (for checkboxes, sliders, text fields, etc.).
  String? lastKnownValue;

  /// How many times this element appeared across observations.
  int frequency;

  /// Creates an [OutpostElement].
  OutpostElement({
    required this.widgetType,
    this.label,
    this.interactionType,
    this.semanticRole,
    this.key,
    this.isInteractive = false,
    this.isEnabled = true,
    this.lastKnownValue,
    this.frequency = 1,
  });

  /// Create from a [Glyph].
  factory OutpostElement.fromGlyph(Glyph glyph) {
    return OutpostElement(
      widgetType: glyph.widgetType,
      label: glyph.label,
      interactionType: glyph.interactionType,
      semanticRole: glyph.semanticRole,
      key: glyph.key,
      isInteractive: glyph.isInteractive,
      isEnabled: glyph.isEnabled,
      lastKnownValue: glyph.currentValue,
    );
  }

  /// Whether this element matches another (same identity).
  ///
  /// Matching is by key (most precise), then by widgetType + label.
  bool matches(OutpostElement other) {
    if (key != null && other.key != null) return key == other.key;
    return widgetType == other.widgetType && label == other.label;
  }

  /// Short string for AI summaries.
  ///
  /// Example: `'ElevatedButton "Login"'`, `'TextField "Email"'`
  String toShortString() {
    if (label != null) return '$widgetType "$label"';
    return widgetType;
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'widgetType': widgetType,
    if (label != null) 'label': label,
    if (interactionType != null) 'interactionType': interactionType,
    if (semanticRole != null) 'semanticRole': semanticRole,
    if (key != null) 'key': key,
    'isInteractive': isInteractive,
    'isEnabled': isEnabled,
    if (lastKnownValue != null) 'lastKnownValue': lastKnownValue,
    'frequency': frequency,
  };

  /// Deserialize from JSON map.
  factory OutpostElement.fromJson(Map<String, dynamic> json) {
    return OutpostElement(
      widgetType: json['widgetType'] as String,
      label: json['label'] as String?,
      interactionType: json['interactionType'] as String?,
      semanticRole: json['semanticRole'] as String?,
      key: json['key'] as String?,
      isInteractive: json['isInteractive'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      lastKnownValue: json['lastKnownValue'] as String?,
      frequency: json['frequency'] as int? ?? 1,
    );
  }

  @override
  String toString() =>
      'OutpostElement(${toShortString()}'
      '${isInteractive ? " [$interactionType]" : ""}'
      '${!isEnabled ? " [disabled]" : ""})';
}
