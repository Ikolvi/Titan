import '../recording/glyph.dart';
import '../recording/tableau.dart';

// ---------------------------------------------------------------------------
// Signet — Screen Fingerprint
// ---------------------------------------------------------------------------

/// **Signet** — a unique fingerprint identifying a screen.
///
/// Two screens are "the same" if they have the same Signet,
/// even if displayed data differs (e.g., different user profiles
/// on `/profile` still have the same interactive layout).
///
/// ## Why "Signet"?
///
/// A signet ring stamps the same seal every time — this is the
/// unique seal of a screen's identity, regardless of content.
///
/// ## How It Works
///
/// The Signet hashes:
/// - Route pattern (parameterized: `/quest/:id` not `/quest/42`)
/// - Interactive widget types and their semantic roles
/// - Widget tree structure (ancestor chains)
///
/// It deliberately ignores:
/// - Text content (labels change with data)
/// - Positions (layout varies by device)
/// - Non-interactive decorations
///
/// ```dart
/// final signet = Signet.fromTableau(tableau);
/// print(signet.hash); // "a3f1...c8e2"
/// print(signet.identity); // "login_screen"
/// ```
class Signet {
  /// The route pattern this screen appears at.
  ///
  /// Parameterized: `/quest/:id` instead of `/quest/42`.
  final String routePattern;

  /// Sorted list of interactive element descriptors.
  ///
  /// Each descriptor: `"widgetType:semanticRole:interactionType"`
  ///
  /// Example: `["ElevatedButton:button:tap", "TextField:textField:textInput"]`
  final List<String> interactiveDescriptors;

  /// SHA-256 hash of the structural fingerprint.
  ///
  /// Computed from the route pattern and sorted
  /// [interactiveDescriptors] joined with `|`.
  final String hash;

  /// Human-readable screen identity.
  ///
  /// Auto-generated from route + element analysis.
  ///
  /// Example: `"login_screen"`, `"quest_detail"`, `"home"`
  final String identity;

  /// Creates a [Signet] from its components.
  const Signet({
    required this.routePattern,
    required this.interactiveDescriptors,
    required this.hash,
    required this.identity,
  });

  /// Create a [Signet] from a live [Tableau] snapshot.
  ///
  /// Extracts the interactive element structure and hashes it
  /// to produce a fingerprint. The [routePattern] should be the
  /// parameterized route (use [RouteParameterizer]).
  ///
  /// ```dart
  /// final signet = Signet.fromTableau(
  ///   tableau,
  ///   routePattern: '/login',
  /// );
  /// ```
  factory Signet.fromTableau(Tableau tableau, {String? routePattern}) {
    final route = routePattern ?? tableau.route ?? '/';

    // Extract interactive element descriptors
    final descriptors = <String>[];
    for (final glyph in tableau.glyphs) {
      if (glyph.isInteractive) {
        descriptors.add(_descriptor(glyph));
      }
    }
    descriptors.sort();

    // Compute hash
    final fingerprint = '$route|${descriptors.join('|')}';
    final hash = fingerprint.hashCode.toRadixString(16).padLeft(8, '0');

    // Generate identity
    final identity = _generateIdentity(route, tableau.glyphs);

    return Signet(
      routePattern: route,
      interactiveDescriptors: descriptors,
      hash: hash,
      identity: identity,
    );
  }

  /// Whether two Signets represent the same screen.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Signet && hash == other.hash;

  @override
  int get hashCode => hash.hashCode;

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'routePattern': routePattern,
    'interactiveDescriptors': interactiveDescriptors,
    'hash': hash,
    'identity': identity,
  };

  /// Deserialize from JSON map.
  factory Signet.fromJson(Map<String, dynamic> json) {
    return Signet(
      routePattern: json['routePattern'] as String,
      interactiveDescriptors:
          (json['interactiveDescriptors'] as List).cast<String>(),
      hash: json['hash'] as String,
      identity: json['identity'] as String,
    );
  }

  @override
  String toString() => 'Signet($identity, $routePattern, '
      '${interactiveDescriptors.length} interactive)';

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  /// Build a descriptor string from a [Glyph].
  static String _descriptor(Glyph glyph) {
    final role = glyph.semanticRole ?? 'none';
    final interaction = glyph.interactionType ?? 'unknown';
    return '${glyph.widgetType}:$role:$interaction';
  }

  /// Generate a human-readable identity from route and elements.
  static String _generateIdentity(String route, List<Glyph> glyphs) {
    // Clean route into a readable name
    final routeName = route == '/'
        ? 'home'
        : route
            .replaceAll(RegExp(r'^/'), '')
            .replaceAll(RegExp(r'/:?\w+'), '')
            .replaceAll('/', '_');

    // Detect screen type from elements
    final hasTextInput =
        glyphs.any((g) => g.interactionType == 'textInput');
    final hasSubmitButton = glyphs.any(
      (g) =>
          g.isInteractive &&
          g.interactionType == 'tap' &&
          _isSubmitLabel(g.label),
    );
    final isForm = hasTextInput && hasSubmitButton;
    final hasList = glyphs.any(
      (g) =>
          g.widgetType.contains('ListView') ||
          g.widgetType.contains('ListTile'),
    );
    final hasNav = glyphs.any(
      (g) => g.widgetType.contains('NavigationDestination') ||
          g.widgetType.contains('BottomNavigationBar'),
    );

    final suffix = isForm
        ? '_form'
        : hasList
            ? '_list'
            : hasNav
                ? '_nav'
                : '';

    final name = routeName.isEmpty ? 'screen' : routeName;
    return '$name$suffix'.replaceAll(RegExp(r'_+'), '_');
  }

  /// Whether a label looks like a submit button.
  static bool _isSubmitLabel(String? label) {
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
}
