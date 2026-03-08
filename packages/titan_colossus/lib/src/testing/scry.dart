// ---------------------------------------------------------------------------
// Scry — Real-Time AI Agent Interface
// ---------------------------------------------------------------------------
// "To scry" — to see distant events through magical means.
//
// Scry gives any AI assistant (via MCP) the ability to observe the live
// app screen and perform actions in real-time, without pre-recorded
// stratagems or campaigns. The AI sees → decides → acts → observes the
// result, forming an autonomous agent loop.
// ---------------------------------------------------------------------------

// =========================================================================
// ScryScreenType — Screen classification for AI context
// =========================================================================

/// The detected type of the current screen.
///
/// Helps the AI understand what kind of screen it's looking at,
/// enabling smarter action selection without detailed screen analysis.
///
/// ```dart
/// final gaze = scry.observe(glyphs);
/// if (gaze.screenType == ScryScreenType.login) {
///   // Enter credentials and tap login
/// }
/// ```
enum ScryScreenType {
  /// Login / authentication screen (fields + login button).
  login,

  /// Form screen (multiple fields + submit button).
  form,

  /// List screen (many similar content items, repeating patterns).
  list,

  /// Detail screen (single item with labels + values, back button).
  detail,

  /// Settings screen (toggles, switches, dropdowns).
  settings,

  /// Empty state (very few content elements, no data).
  empty,

  /// Error screen (error messages visible).
  error,

  /// Dashboard (mixed content types, stats, navigation).
  dashboard,

  /// Cannot be classified into a specific type.
  unknown,
}

// =========================================================================
// ScryAlert — Detected warnings, errors, and status indicators
// =========================================================================

/// The severity of a detected screen alert.
///
/// Used by [ScryAlert] to indicate how critical the detected
/// condition is, helping the AI prioritize its response.
enum ScryAlertSeverity {
  /// Error condition (red text, error icon, failure message).
  error,

  /// Warning condition (yellow text, warning icon).
  warning,

  /// Informational notice (snackbar, toast, banner).
  info,

  /// Loading / in-progress state (spinner, progress bar).
  loading,
}

/// A detected alert condition on the screen.
///
/// Represents errors, warnings, loading indicators, and
/// informational messages that the AI should know about.
///
/// ```dart
/// for (final alert in gaze.alerts) {
///   if (alert.severity == ScryAlertSeverity.error) {
///     print('Error detected: ${alert.message}');
///   }
/// }
/// ```
class ScryAlert {
  /// Creates a [ScryAlert].
  const ScryAlert({
    required this.severity,
    required this.message,
    this.widgetType,
  });

  /// The severity level of this alert.
  final ScryAlertSeverity severity;

  /// Human-readable description of the alert (or the visible text).
  final String message;

  /// The widget type that triggered this detection.
  final String? widgetType;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'severity': severity.name,
    'message': message,
    if (widgetType != null) 'widgetType': widgetType,
  };
}

// =========================================================================
// ScryKeyValue — Detected data pairs on screen
// =========================================================================

/// A key-value pair detected by proximity grouping.
///
/// When a content label appears near a data value (like "Class:" next
/// to "Scout"), Scry groups them into a [ScryKeyValue] for the AI
/// to understand structured data displays.
///
/// ```dart
/// for (final kv in gaze.dataFields) {
///   print('${kv.key}: ${kv.value}');
/// }
/// ```
class ScryKeyValue {
  /// Creates a [ScryKeyValue].
  const ScryKeyValue({required this.key, required this.value});

  /// The label / key text.
  final String key;

  /// The value text.
  final String value;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {'key': key, 'value': value};
}

// =========================================================================
// ScryDiff — State change detection between observations
// =========================================================================

/// The result of comparing two [ScryGaze] observations.
///
/// Used in the observe→act→observe loop to understand what
/// changed after an action was performed.
///
/// ```dart
/// final before = scry.observe(glyphsBefore);
/// // ... perform action ...
/// final after = scry.observe(glyphsAfter);
/// final diff = scry.diff(before, after);
///
/// if (diff.routeChanged) {
///   print('Navigated from ${diff.previousRoute} to ${diff.currentRoute}');
/// }
/// for (final e in diff.appeared) {
///   print('New: ${e.label}');
/// }
/// ```
class ScryDiff {
  /// Creates a [ScryDiff].
  const ScryDiff({
    required this.appeared,
    required this.disappeared,
    required this.changedValues,
    this.previousRoute,
    this.currentRoute,
    required this.previousScreenType,
    required this.currentScreenType,
  });

  /// Elements now visible that were not visible before.
  final List<ScryElement> appeared;

  /// Elements no longer visible that were visible before.
  final List<ScryElement> disappeared;

  /// Elements whose [ScryElement.currentValue] changed.
  ///
  /// Each entry maps the element label to `{'from': old, 'to': new}`.
  final Map<String, Map<String, String?>> changedValues;

  /// Route before the action.
  final String? previousRoute;

  /// Route after the action.
  final String? currentRoute;

  /// Screen type before the action.
  final ScryScreenType previousScreenType;

  /// Screen type after the action.
  final ScryScreenType currentScreenType;

  /// Whether the route changed.
  bool get routeChanged =>
      previousRoute != null &&
      currentRoute != null &&
      previousRoute != currentRoute;

  /// Whether the screen type changed.
  bool get screenTypeChanged => previousScreenType != currentScreenType;

  /// Whether anything changed at all.
  bool get hasChanges =>
      appeared.isNotEmpty ||
      disappeared.isNotEmpty ||
      changedValues.isNotEmpty ||
      routeChanged;

  /// Format as AI-readable markdown.
  String format() {
    final buf = StringBuffer();
    buf.writeln('## 🔄 What Changed');
    buf.writeln();

    if (!hasChanges) {
      buf.writeln('_No visible changes detected._');
      return buf.toString();
    }

    if (routeChanged) {
      buf.writeln('**Route**: `$previousRoute` → `$currentRoute`');
    }
    if (screenTypeChanged) {
      buf.writeln(
        '**Screen type**: ${previousScreenType.name}'
        ' → ${currentScreenType.name}',
      );
    }

    if (appeared.isNotEmpty) {
      buf.writeln();
      buf.writeln('### ➕ Appeared (${appeared.length})');
      for (final e in appeared) {
        final extra = <String>[];
        if (e.isInteractive) extra.add(e.kind.name);
        if (e.currentValue != null) extra.add('value: "${e.currentValue}"');
        final suffix = extra.isNotEmpty ? ' (${extra.join(', ')})' : '';
        buf.writeln('- **${e.label}**$suffix');
      }
    }

    if (disappeared.isNotEmpty) {
      buf.writeln();
      buf.writeln('### ➖ Disappeared (${disappeared.length})');
      for (final e in disappeared) {
        buf.writeln('- ~~${e.label}~~');
      }
    }

    if (changedValues.isNotEmpty) {
      buf.writeln();
      buf.writeln('### ✏️ Changed Values (${changedValues.length})');
      for (final entry in changedValues.entries) {
        final from = entry.value['from'] ?? '(empty)';
        final to = entry.value['to'] ?? '(empty)';
        buf.writeln('- **${entry.key}**: "$from" → "$to"');
      }
    }

    return buf.toString();
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    if (previousRoute != null) 'previousRoute': previousRoute,
    if (currentRoute != null) 'currentRoute': currentRoute,
    'routeChanged': routeChanged,
    'screenTypeChanged': screenTypeChanged,
    'previousScreenType': previousScreenType.name,
    'currentScreenType': currentScreenType.name,
    'appeared': appeared.map((e) => e.toJson()).toList(),
    'disappeared': disappeared.map((e) => e.toJson()).toList(),
    'changedValues': changedValues,
    'hasChanges': hasChanges,
  };
}

// =========================================================================
// ScryElementKind — Element classification
// =========================================================================

/// The kind of screen element detected from a glyph.
///
/// Used by [ScryElement] to categorize glyphs into groups that
/// are meaningful for an AI agent deciding what to do next.
///
/// ```dart
/// switch (element.kind) {
///   case ScryElementKind.button:
///     print('Can tap: ${element.label}');
///   case ScryElementKind.field:
///     print('Can type in: ${element.label}');
///   case ScryElementKind.navigation:
///     print('Can navigate to: ${element.label}');
///   case ScryElementKind.content:
///     print('Displays: ${element.label}');
///   case ScryElementKind.structural:
///     print('UI chrome: ${element.label}');
/// }
/// ```
enum ScryElementKind {
  /// Tappable button (ElevatedButton, IconButton, TextButton, etc.).
  button,

  /// Text input field (TextField, TextFormField).
  field,

  /// Navigation element (tab, drawer item, nav destination).
  navigation,

  /// Display-only content (Text, RichText not part of UI chrome).
  content,

  /// Structural UI chrome (AppBar title, toolbar label, tooltip).
  structural,
}

/// A single screen element observed by Scry.
///
/// Distills a raw glyph map into an AI-friendly element with
/// a clear [kind], [label], and optional metadata for targeting.
///
/// ```dart
/// final element = ScryElement(
///   kind: ScryElementKind.button,
///   label: 'Sign Out',
///   widgetType: 'IconButton',
///   isInteractive: true,
/// );
/// ```
class ScryElement {
  /// Creates a [ScryElement].
  const ScryElement({
    required this.kind,
    required this.label,
    required this.widgetType,
    this.isInteractive = false,
    this.fieldId,
    this.currentValue,
    this.semanticRole,
    this.interactionType,
    this.isEnabled = true,
    this.gated = false,
  });

  /// The categorized kind of this element.
  final ScryElementKind kind;

  /// The display label (text content or tooltip).
  final String label;

  /// The Flutter widget type (e.g., `'IconButton'`, `'Text'`).
  final String widgetType;

  /// Whether this element accepts user interaction.
  final bool isInteractive;

  /// The field ID for text input targeting (from ShadeTextController).
  final String? fieldId;

  /// Current value for stateful widgets (checkboxes, switches, sliders).
  final String? currentValue;

  /// Semantic role (button, textField, header, image, link, etc.).
  final String? semanticRole;

  /// Interaction type (tap, longPress, textInput, scroll, etc.).
  final String? interactionType;

  /// Whether the element is enabled.
  final bool isEnabled;

  /// Whether this element is "gated" — the AI should ask the user
  /// for permission before interacting with it.
  ///
  /// Elements are gated if they appear to be destructive or
  /// irreversible actions (delete, remove, reset, etc.).
  final bool gated;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'label': label,
    'widgetType': widgetType,
    if (isInteractive) 'isInteractive': true,
    if (fieldId != null) 'fieldId': fieldId,
    if (currentValue != null) 'currentValue': currentValue,
    if (semanticRole != null) 'semanticRole': semanticRole,
    if (interactionType != null) 'interactionType': interactionType,
    if (!isEnabled) 'isEnabled': false,
    if (gated) 'gated': true,
  };
}

/// The result of a Scry observation — a structured view of the
/// current app screen, optimized for AI decision-making.
///
/// A [ScryGaze] categorizes all visible elements into groups:
///
/// - [buttons] — tappable controls the AI can tap
/// - [fields] — text inputs the AI can type into
/// - [navigation] — tabs, nav items the AI can switch to
/// - [content] — display-only text (potential user data)
/// - [structural] — UI chrome (app title, toolbar labels)
///
/// ```dart
/// const scry = Scry();
/// final gaze = scry.observe(glyphs);
///
/// print('Buttons: ${gaze.buttons.map((e) => e.label)}');
/// print('Fields: ${gaze.fields.map((e) => e.label)}');
/// print('You can navigate to: ${gaze.navigation.map((e) => e.label)}');
/// ```
class ScryGaze {
  /// Creates a [ScryGaze].
  const ScryGaze({
    required this.elements,
    this.route,
    this.glyphCount = 0,
    this.screenType = ScryScreenType.unknown,
    this.alerts = const [],
    this.dataFields = const [],
    this.suggestions = const [],
  });

  /// All detected elements.
  final List<ScryElement> elements;

  /// Current route, if available.
  final String? route;

  /// Total number of raw glyphs analyzed.
  final int glyphCount;

  /// Detected screen type.
  final ScryScreenType screenType;

  /// Detected alerts (errors, warnings, loading indicators).
  final List<ScryAlert> alerts;

  /// Detected key-value data pairs on screen.
  final List<ScryKeyValue> dataFields;

  /// AI-generated action suggestions for the current screen.
  final List<String> suggestions;

  /// Interactive buttons (tappable, non-navigation).
  List<ScryElement> get buttons =>
      elements.where((e) => e.kind == ScryElementKind.button).toList();

  /// Text input fields.
  List<ScryElement> get fields =>
      elements.where((e) => e.kind == ScryElementKind.field).toList();

  /// Navigation elements (tabs, nav destinations).
  List<ScryElement> get navigation =>
      elements.where((e) => e.kind == ScryElementKind.navigation).toList();

  /// Display-only content labels.
  List<ScryElement> get content =>
      elements.where((e) => e.kind == ScryElementKind.content).toList();

  /// Structural UI chrome labels.
  List<ScryElement> get structural =>
      elements.where((e) => e.kind == ScryElementKind.structural).toList();

  /// Elements that require user permission before interacting.
  List<ScryElement> get gated => elements.where((e) => e.gated).toList();

  /// Whether this looks like an authentication/login screen.
  bool get isAuthScreen => screenType == ScryScreenType.login;

  static final _loginButtonPattern = RegExp(
    r'\b(log\s*in|sign\s*in|enter|submit|continue)\b',
  );

  /// Whether errors are present on screen.
  bool get hasErrors =>
      alerts.any((a) => a.severity == ScryAlertSeverity.error);

  /// Whether loading is in progress.
  bool get isLoading =>
      alerts.any((a) => a.severity == ScryAlertSeverity.loading);

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    if (route != null) 'route': route,
    'glyphCount': glyphCount,
    'screenType': screenType.name,
    'buttonCount': buttons.length,
    'fieldCount': fields.length,
    'navigationCount': navigation.length,
    'contentCount': content.length,
    if (alerts.isNotEmpty) 'alerts': alerts.map((a) => a.toJson()).toList(),
    if (dataFields.isNotEmpty)
      'dataFields': dataFields.map((d) => d.toJson()).toList(),
    if (suggestions.isNotEmpty) 'suggestions': suggestions,
    'elements': elements.map((e) => e.toJson()).toList(),
  };
}

/// **Scry** — real-time AI agent interface for observing and interacting
/// with a live Flutter app.
///
/// Scry parses raw glyph data (from Tableau/Relay) into a structured
/// [ScryGaze] that an AI assistant can reason about and act upon.
///
/// ## Core Loop
///
/// ```text
/// ┌─────────┐     ┌──────────┐     ┌─────────┐
/// │  Scry   │────▶│  Decide  │────▶│  Act    │
/// │ observe │     │ (AI)     │     │ scry_act│
/// └─────────┘     └──────────┘     └────┬────┘
///      ▲                                │
///      └────────────────────────────────┘
///              new screen state
/// ```
///
/// ## Usage
///
/// ```dart
/// const scry = Scry();
///
/// // Parse glyphs from Relay /blueprint
/// final gaze = scry.observe(glyphs, route: '/quests');
///
/// // Format for AI consumption
/// final markdown = scry.formatGaze(gaze);
/// print(markdown);
/// // # Current Screen
/// // **Route**: /quests | 177 glyphs
/// //
/// // ## 🔘 Buttons (3)
/// // - **Sign Out** (IconButton)
/// // - **About** (IconButton)
/// // - **Complete Quest** (IconButton, ×7)
/// // ...
/// ```
class Scry {
  /// Creates a const [Scry].
  const Scry();

  /// Labels that indicate destructive / irreversible actions.
  ///
  /// Elements matching these patterns are marked as [ScryElement.gated],
  /// signaling the AI to ask for user permission before interacting.
  static const gatedPatterns = [
    'delete',
    'remove',
    'reset',
    'destroy',
    'erase',
    'clear all',
    'wipe',
    'revoke',
    'unlink',
    'disconnect',
    'terminate',
    'purge',
  ];

  /// Observe the current screen by parsing raw glyph data.
  ///
  /// Categorizes each glyph into a [ScryElement] with a [ScryElementKind]
  /// based on:
  /// - Widget type and semantic role
  /// - Interactivity flag
  /// - Ancestor chain (structural detection)
  /// - Label content (gated action detection)
  ///
  /// [glyphs] — raw glyph maps from Relay `/blueprint`.
  /// [route] — current route (from Tableau metadata), if available.
  ///
  /// ```dart
  /// const scry = Scry();
  /// final gaze = scry.observe(glyphs, route: '/quests');
  /// print(gaze.buttons.length); // number of tappable buttons
  /// ```
  ScryGaze observe(List<dynamic> glyphs, {String? route}) {
    final seen = <String, ScryElement>{};
    final interactiveLabels = <String>{};
    final navigationLabels = <String>{};
    final structuralLabels = <String>{};
    final fieldIds = <String, String>{};
    final textInputLabels = <String>{};
    final preferredWidgetType = <String, String>{};
    final preferredInteractionType = <String, String>{};
    final preferredSemanticRole = <String, String>{};
    final preferredCurrentValue = <String, String>{};

    // --- Pass 1: Classify labels ---
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (label.startsWith('IconData(')) continue;
      // Skip PUA icons
      if (label.length == 1 && label.codeUnitAt(0) > 0xE000) continue;

      final isInteractive = glyph['ia'] == true;
      final wt = glyph['wt'] as String? ?? '';
      final wtLower = wt.toLowerCase();
      final fieldId = glyph['fid'] as String?;
      final ancestors = glyph['anc'] as List<dynamic>? ?? [];

      // Track interactive labels
      if (isInteractive) {
        interactiveLabels.add(label);
      }

      // Track field IDs
      if (fieldId != null && fieldId.isNotEmpty) {
        fieldIds[label] = fieldId;
      }

      // Track text input widgets — these take classification priority
      if (_isTextInputWidget(wt)) {
        textInputLabels.add(label);
        preferredWidgetType[label] = wt;
        final it = glyph['it'] as String?;
        if (it != null) preferredInteractionType[label] = it;
        final sr = glyph['sr'] as String?;
        if (sr != null) preferredSemanticRole[label] = sr;
        final cv = glyph['cv'] as String?;
        if (cv != null) preferredCurrentValue[label] = cv;
      }

      // Track interactive widgets as preferred (if no text input yet)
      if (isInteractive && !preferredWidgetType.containsKey(label)) {
        preferredWidgetType[label] = wt;
        final it = glyph['it'] as String?;
        if (it != null) preferredInteractionType[label] = it;
        final sr = glyph['sr'] as String?;
        if (sr != null) preferredSemanticRole[label] = sr;
      }

      // Detect navigation elements
      if (_isNavigationWidget(wtLower, ancestors)) {
        navigationLabels.add(label);
      }

      // Detect structural elements (AppBar, toolbar, etc.)
      if (_isStructuralWidget(wtLower, ancestors)) {
        structuralLabels.add(label);
      }
    }

    // --- Pass 2: Build unique elements ---
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (label.startsWith('IconData(')) continue;
      if (label.length == 1 && label.codeUnitAt(0) > 0xE000) continue;

      // Skip if already processed (dedup by label)
      if (seen.containsKey(label)) continue;

      // Use the preferred (most representative) widget type from Pass 1.
      // For example, if "Hero Name" appears as RichText, Text, and
      // TextField, we want "TextField" — the interactive text input.
      final wt = preferredWidgetType[label] ?? (glyph['wt'] as String? ?? '');
      final sr = preferredSemanticRole[label] ?? (glyph['sr'] as String?);
      final it = preferredInteractionType[label] ?? (glyph['it'] as String?);
      final cv = preferredCurrentValue[label] ?? (glyph['cv'] as String?);
      final isEnabled = glyph['en'] as bool? ?? true;
      final fieldId = fieldIds[label];
      final isTextField = textInputLabels.contains(label);

      // Determine element kind
      final kind = _classifyElement(
        label: label,
        widgetType: wt,
        semanticRole: sr,
        fieldId: fieldId,
        isInteractive: interactiveLabels.contains(label),
        isNavigation: navigationLabels.contains(label),
        isStructural: structuralLabels.contains(label),
        isTextField: isTextField,
      );

      // Check if this action is gated (destructive)
      final gated = interactiveLabels.contains(label) && _isGatedAction(label);

      seen[label] = ScryElement(
        kind: kind,
        label: label,
        widgetType: wt,
        isInteractive: interactiveLabels.contains(label),
        fieldId: fieldId,
        currentValue: cv,
        semanticRole: sr,
        interactionType: it,
        isEnabled: isEnabled,
        gated: gated,
      );
    }

    final elementList = seen.values.toList();

    // --- Pass 3: Intelligence layer ---
    final alerts = _detectAlerts(glyphs);
    final dataFields = _extractKeyValuePairs(glyphs);
    final screenType = _classifyScreen(elementList, alerts, dataFields);
    final suggestions = _generateSuggestions(elementList, screenType, alerts);

    return ScryGaze(
      elements: elementList,
      route: route,
      glyphCount: glyphs.length,
      screenType: screenType,
      alerts: alerts,
      dataFields: dataFields,
      suggestions: suggestions,
    );
  }

  /// Format a [ScryGaze] as AI-friendly markdown.
  ///
  /// Produces a structured document that tells the AI exactly:
  /// - What's visible on screen
  /// - What can be interacted with
  /// - What requires permission
  /// - What actions are available
  ///
  /// ```dart
  /// const scry = Scry();
  /// final gaze = scry.observe(glyphs, route: '/quests');
  /// final md = scry.formatGaze(gaze);
  /// // Returns markdown with sections for buttons, fields, nav, content
  /// ```
  String formatGaze(ScryGaze gaze) {
    final buf = StringBuffer();

    buf.writeln('# Current Screen');
    buf.writeln();

    // Header line with screen type
    final parts = <String>[];
    if (gaze.route != null) parts.add('**Route**: ${gaze.route}');
    parts.add('**Type**: ${gaze.screenType.name}');
    parts.add('${gaze.glyphCount} glyphs');
    buf.writeln(parts.join(' | '));

    if (gaze.isAuthScreen) {
      buf.writeln();
      buf.writeln(
        '> **Login screen detected** — '
        'this screen has text fields and a login button.',
      );
    }

    // --- Alerts (errors, warnings, loading) ---
    if (gaze.alerts.isNotEmpty) {
      buf.writeln();
      for (final alert in gaze.alerts) {
        final icon = switch (alert.severity) {
          ScryAlertSeverity.error => '🔴',
          ScryAlertSeverity.warning => '🟡',
          ScryAlertSeverity.info => '🔵',
          ScryAlertSeverity.loading => '⏳',
        };
        buf.writeln('> $icon **${alert.severity.name}**: ${alert.message}');
      }
    }

    // Gated elements warning
    if (gaze.gated.isNotEmpty) {
      buf.writeln();
      buf.writeln(
        '> ⚠️ **Permission required** — '
        '${gaze.gated.length} element(s) marked as potentially '
        'destructive. Ask the user before interacting:',
      );
      for (final e in gaze.gated) {
        buf.writeln('>   - "${e.label}"');
      }
    }

    buf.writeln();

    // --- Suggestions (context-aware) ---
    if (gaze.suggestions.isNotEmpty) {
      buf.writeln('## 💡 Suggestions');
      buf.writeln();
      for (final s in gaze.suggestions) {
        buf.writeln('- $s');
      }
      buf.writeln();
    }

    // --- Data Fields (key-value pairs) ---
    if (gaze.dataFields.isNotEmpty) {
      buf.writeln('## 📊 Data (${gaze.dataFields.length})');
      buf.writeln();
      for (final kv in gaze.dataFields) {
        buf.writeln('- **${kv.key}**: ${kv.value}');
      }
      buf.writeln();
    }

    // --- Fields (most important for input) ---
    if (gaze.fields.isNotEmpty) {
      buf.writeln('## 📝 Text Fields (${gaze.fields.length})');
      buf.writeln();
      buf.writeln(
        'Use `scry_act(action: "enterText", label: "<label>", '
        'value: "<text>")` to type into a field.',
      );
      buf.writeln();
      for (final f in gaze.fields) {
        final parts = <String>[f.widgetType];
        if (f.fieldId != null) parts.add('fieldId: ${f.fieldId}');
        if (f.currentValue != null) {
          parts.add('value: "${f.currentValue}"');
        }
        if (!f.isEnabled) parts.add('disabled');
        buf.writeln('- **${f.label}** (${parts.join(', ')})');
      }
      buf.writeln();
    }

    // --- Buttons ---
    if (gaze.buttons.isNotEmpty) {
      buf.writeln('## 🔘 Buttons (${gaze.buttons.length})');
      buf.writeln();
      for (final b in gaze.buttons) {
        final suffix = b.gated ? ' ⚠️ requires permission' : '';
        final disabled = !b.isEnabled ? ' [disabled]' : '';
        buf.writeln('- **${b.label}** (${b.widgetType})$disabled$suffix');
      }
      buf.writeln();
    }

    // --- Navigation ---
    if (gaze.navigation.isNotEmpty) {
      buf.writeln('## 🗂️ Navigation (${gaze.navigation.length})');
      buf.writeln();
      for (final n in gaze.navigation) {
        buf.writeln('- **${n.label}**');
      }
      buf.writeln();
    }

    // --- Content ---
    if (gaze.content.isNotEmpty) {
      buf.writeln('## 📄 Content (${gaze.content.length})');
      buf.writeln();
      for (final c in gaze.content) {
        buf.writeln('- ${c.label}');
      }
      buf.writeln();
    }

    // --- Available Actions ---
    buf.writeln('## Available Actions');
    buf.writeln();
    buf.writeln('Use `scry_act` with these action types:');
    buf.writeln();
    if (gaze.buttons.isNotEmpty) {
      buf.writeln('- `tap` — tap a button by label');
    }
    if (gaze.fields.isNotEmpty) {
      buf.writeln(
        '- `enterText` — type text into a field '
        '(use fieldId for targeting)',
      );
      buf.writeln('- `clearText` — clear a text field');
    }
    if (gaze.navigation.isNotEmpty) {
      buf.writeln('- `tap` — switch to a navigation tab by label');
    }
    buf.writeln('- `scroll` — scroll the page');
    buf.writeln('- `back` — navigate back');
    buf.writeln('- `waitForElement` — wait for an element to appear');

    return buf.toString();
  }

  /// Resolve a `fieldId` to its display label from live glyphs.
  ///
  /// When the AI targets a text field by `fieldId` (e.g.
  /// `scry_act(fieldId: 'hero_name')`), this method finds the
  /// matching glyph and returns its label for use in campaign
  /// targeting (since [StratagemTarget] resolves by label, not fieldId).
  ///
  /// Returns `null` if no glyph matches the given [fieldId].
  String? resolveFieldLabel(List<dynamic> glyphs, String fieldId) {
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      if (glyph['fid'] == fieldId) {
        return glyph['l'] as String?;
      }
    }
    return null;
  }

  /// Text-entry actions that require keyboard dismissal afterwards.
  static const _textActions = {'enterText', 'clearText', 'submitField'};

  /// Build a Campaign JSON from a single action request.
  ///
  /// Wraps the action in a minimal Campaign structure that the
  /// Relay's `POST /campaign` endpoint can execute. For text-entry
  /// actions (`enterText`, `clearText`, `submitField`), a
  /// `dismissKeyboard` step is automatically appended so the
  /// keyboard doesn't block the follow-up screen observation.
  ///
  /// [action] — one of: tap, enterText, clearText, scroll, back,
  ///   longPress, doubleTap, swipe, waitForElement, waitForElementGone,
  ///   navigate, pressKey, submitField, dismissKeyboard, etc.
  /// [label] — target element label (for tap, enterText, clearText, etc.)
  /// [value] — text to enter (for enterText) or navigation route
  ///   (for navigate)
  /// [timeout] — timeout in ms for wait actions (default: 5000)
  ///
  /// ```dart
  /// const scry = Scry();
  /// final campaign = scry.buildActionCampaign(
  ///   action: 'enterText',
  ///   label: 'Hero Name',
  ///   value: 'Kael',
  /// );
  /// // Produces a Campaign with enterText + dismissKeyboard steps
  /// ```
  Map<String, dynamic> buildActionCampaign({
    required String action,
    String? label,
    String? value,
    int timeout = 5000,
  }) {
    final target = <String, dynamic>{};
    if (label != null) target['label'] = label;

    // If no explicit target, use a dummy for navigation actions
    if (target.isEmpty && action != 'back' && action != 'navigate') {
      target['label'] = label ?? '';
    }

    var stepId = 1;

    final steps = <Map<String, dynamic>>[];

    // For text-entry actions, add a waitForElement step first to ensure
    // the target field is present and the screen has settled. This
    // prevents silent failures when the screen is mid-transition
    // (e.g. IgnorePointer blocking events during route animation).
    if (_textActions.contains(action) && target.isNotEmpty) {
      steps.add({
        'id': stepId++,
        'action': 'waitForElement',
        'target': Map<String, dynamic>.from(target),
        'timeout': timeout,
      });
    }

    final step = <String, dynamic>{
      'id': stepId++,
      'action': action,
      if (target.isNotEmpty) 'target': target,
      // ignore: use_null_aware_elements
      if (value != null) 'value': value,
      if (action == 'enterText') 'clearFirst': true,
      if (action == 'waitForElement' || action == 'waitForElementGone')
        'timeout': timeout,
    };

    // For back/navigate, add route
    if (action == 'navigate' && value != null) {
      step['target'] = {'route': value};
    }

    steps.add(step);

    // Auto-dismiss keyboard after text actions so observation isn't blocked
    if (_textActions.contains(action)) {
      steps.add({'id': stepId, 'action': 'dismissKeyboard'});
    }

    return {
      'name': '_scry_action',
      'entries': [
        {
          'stratagem': {'name': '_scry_step', 'startRoute': '', 'steps': steps},
        },
      ],
    };
  }

  /// Build a Campaign JSON from multiple action requests.
  ///
  /// Combines several actions into a single Campaign structure.
  /// Each action in [actions] is a map with:
  /// - `action` (required) — the action type
  /// - `label` (optional) — target element label
  /// - `value` (optional) — text value or route
  ///
  /// Text-entry actions automatically get `waitForElement` pre-steps
  /// and `dismissKeyboard` post-steps, just like [buildActionCampaign].
  ///
  /// ```dart
  /// const scry = Scry();
  /// final campaign = scry.buildMultiActionCampaign([
  ///   {'action': 'enterText', 'label': 'Hero Name', 'value': 'Kael'},
  ///   {'action': 'tap', 'label': 'Enter the Questboard'},
  /// ]);
  /// ```
  Map<String, dynamic> buildMultiActionCampaign(
    List<Map<String, dynamic>> actions, {
    int timeout = 5000,
  }) {
    var stepId = 1;
    final steps = <Map<String, dynamic>>[];

    for (final entry in actions) {
      final action = entry['action'] as String;
      final label = entry['label'] as String?;
      final value = entry['value'] as String?;

      final target = <String, dynamic>{};
      if (label != null) target['label'] = label;

      if (target.isEmpty && action != 'back' && action != 'navigate') {
        target['label'] = label ?? '';
      }

      // Pre-step: waitForElement for text actions
      if (_textActions.contains(action) && target.isNotEmpty) {
        steps.add({
          'id': stepId++,
          'action': 'waitForElement',
          'target': Map<String, dynamic>.from(target),
          'timeout': timeout,
        });
      }

      final step = <String, dynamic>{
        'id': stepId++,
        'action': action,
        if (target.isNotEmpty) 'target': target,
        // ignore: use_null_aware_elements
        if (value != null) 'value': value,
        if (action == 'enterText') 'clearFirst': true,
        if (action == 'waitForElement' || action == 'waitForElementGone')
          'timeout': timeout,
      };

      if (action == 'navigate' && value != null) {
        step['target'] = {'route': value};
      }

      steps.add(step);

      // Post-step: dismissKeyboard for text actions
      if (_textActions.contains(action)) {
        steps.add({'id': stepId++, 'action': 'dismissKeyboard'});
      }
    }

    return {
      'name': '_scry_multi_action',
      'entries': [
        {
          'stratagem': {
            'name': '_scry_steps',
            'startRoute': '',
            'steps': steps,
          },
        },
      ],
    };
  }

  /// Format the result of a `scry_act` execution.
  ///
  /// [action] — the action that was performed.
  /// [label] — the target element label.
  /// [result] — the raw campaign result from Relay.
  /// [newGaze] — the observed screen state after the action.
  ///
  /// Returns markdown summarizing the action result and new state.
  String formatActionResult({
    required String action,
    String? label,
    String? value,
    required Map<String, dynamic>? result,
    required ScryGaze newGaze,
  }) {
    final buf = StringBuffer();

    // Action result
    final passRate = result?['passRate'] as num?;
    final succeeded = passRate != null && passRate == 1.0;

    if (succeeded) {
      buf.writeln('# ✅ Action Succeeded');
    } else {
      buf.writeln('# ❌ Action Failed');
    }
    buf.writeln();

    // Describe what was done
    final target = label ?? value ?? '(no target)';
    buf.writeln('**Action**: `$action` on "$target"');
    if (value != null && action == 'enterText') {
      buf.writeln('**Value**: "$value"');
    }
    if (passRate != null) {
      buf.writeln('**Pass Rate**: $passRate');
    }

    // If failed, include error details
    if (!succeeded && result != null) {
      final verdicts = result['verdicts'] as List<dynamic>? ?? [];
      for (final v in verdicts) {
        final verdict = v as Map<String, dynamic>;
        final steps = verdict['steps'] as List<dynamic>? ?? [];
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          if (step['passed'] != true) {
            final error = step['error'] as String?;
            if (error != null) {
              buf.writeln('**Error**: $error');
            }
          }
        }
      }
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    // New screen state
    buf.write(formatGaze(newGaze));

    return buf.toString();
  }

  /// Format the result of a multi-action `scry_act` execution.
  ///
  /// Similar to [formatActionResult] but lists all actions performed.
  String formatMultiActionResult({
    required List<Map<String, dynamic>> actions,
    required Map<String, dynamic>? result,
    required ScryGaze newGaze,
  }) {
    final buf = StringBuffer();

    final passRate = result?['passRate'] as num?;
    final succeeded = passRate != null && passRate == 1.0;

    if (succeeded) {
      buf.writeln('# ✅ All Actions Succeeded');
    } else {
      buf.writeln('# ❌ Actions Failed');
    }
    buf.writeln();

    // List all actions
    buf.writeln('**Actions performed** (${actions.length}):');
    for (var i = 0; i < actions.length; i++) {
      final a = actions[i];
      final action = a['action'] as String;
      final label = a['label'] as String?;
      final value = a['value'] as String?;
      final target = label ?? value ?? '';
      final detail = value != null && action == 'enterText'
          ? ' → "$value"'
          : '';
      buf.writeln(
        '${i + 1}. `$action`'
        '${target.isNotEmpty ? ' on "$target"' : ''}'
        '$detail',
      );
    }
    buf.writeln();

    if (passRate != null) {
      buf.writeln('**Pass Rate**: $passRate');
    }

    // If failed, include error details
    if (!succeeded && result != null) {
      final verdicts = result['verdicts'] as List<dynamic>? ?? [];
      for (final v in verdicts) {
        final verdict = v as Map<String, dynamic>;
        final steps = verdict['steps'] as List<dynamic>? ?? [];
        for (final s in steps) {
          final step = s as Map<String, dynamic>;
          if (step['passed'] != true) {
            final error = step['error'] as String?;
            if (error != null) {
              buf.writeln('**Error** (step ${step['id']}): $error');
            }
          }
        }
      }
    }

    buf.writeln();
    buf.writeln('---');
    buf.writeln();

    buf.write(formatGaze(newGaze));

    return buf.toString();
  }

  // -----------------------------------------------------------------------
  // Diff — State change detection
  // -----------------------------------------------------------------------

  /// Compare two [ScryGaze] observations to detect changes.
  ///
  /// Returns a [ScryDiff] describing what appeared, disappeared,
  /// or changed between the [before] and [after] observations.
  ///
  /// This is the key enabler for the observe→act→observe agent loop:
  /// the AI performs an action, then diffs the before/after states
  /// to verify the action had the expected effect.
  ///
  /// ```dart
  /// const scry = Scry();
  /// final before = scry.observe(glyphsBefore);
  /// // ... perform action ...
  /// final after = scry.observe(glyphsAfter);
  /// final diff = scry.diff(before, after);
  ///
  /// if (diff.routeChanged) {
  ///   print('Navigation detected!');
  /// }
  /// ```
  ScryDiff diff(ScryGaze before, ScryGaze after) {
    final beforeLabels = <String, ScryElement>{
      for (final e in before.elements) e.label: e,
    };
    final afterLabels = <String, ScryElement>{
      for (final e in after.elements) e.label: e,
    };

    // Elements that appeared (in after, not in before)
    final appeared = <ScryElement>[
      for (final e in after.elements)
        if (!beforeLabels.containsKey(e.label)) e,
    ];

    // Elements that disappeared (in before, not in after)
    final disappeared = <ScryElement>[
      for (final e in before.elements)
        if (!afterLabels.containsKey(e.label)) e,
    ];

    // Values that changed (element exists in both, but value differs)
    final changedValues = <String, Map<String, String?>>{};
    for (final e in after.elements) {
      final prev = beforeLabels[e.label];
      if (prev != null && prev.currentValue != e.currentValue) {
        changedValues[e.label] = {
          'from': prev.currentValue,
          'to': e.currentValue,
        };
      }
    }

    return ScryDiff(
      appeared: appeared,
      disappeared: disappeared,
      changedValues: changedValues,
      previousRoute: before.route,
      currentRoute: after.route,
      previousScreenType: before.screenType,
      currentScreenType: after.screenType,
    );
  }

  // -----------------------------------------------------------------------
  // Private helpers
  // -----------------------------------------------------------------------

  /// Classify a label into a [ScryElementKind].
  ScryElementKind _classifyElement({
    required String label,
    required String widgetType,
    String? semanticRole,
    String? fieldId,
    required bool isInteractive,
    required bool isNavigation,
    required bool isStructural,
    bool isTextField = false,
  }) {
    // Fields first (text inputs) — includes labels that have a
    // text input widget anywhere in their glyph set, even if the
    // first glyph seen was a non-input (e.g. RichText label).
    if (isTextField ||
        semanticRole == 'textField' ||
        fieldId != null ||
        _isTextInputWidget(widgetType)) {
      return ScryElementKind.field;
    }

    // Navigation elements
    if (isNavigation) {
      return ScryElementKind.navigation;
    }

    // Structural (AppBar titles, tooltips in structural containers)
    if (isStructural && !isInteractive) {
      return ScryElementKind.structural;
    }

    // Interactive = buttons
    if (isInteractive) {
      return ScryElementKind.button;
    }

    // Everything else = content
    return ScryElementKind.content;
  }

  /// Check if widget type is a text input.
  bool _isTextInputWidget(String widgetType) {
    final lower = widgetType.toLowerCase();
    return lower.contains('textfield') ||
        lower.contains('textformfield') ||
        lower.contains('editabletext');
  }

  /// Check if this is a navigation widget (tab, nav destination).
  bool _isNavigationWidget(String wtLower, List<dynamic> ancestors) {
    if (wtLower == 'navigationbar' ||
        wtLower == 'bottomnavigationbar' ||
        wtLower == 'tabbar' ||
        wtLower == 'navigationrail') {
      return true;
    }

    if (ancestors.isNotEmpty) {
      final ancestorStr = ancestors.join(' ').toLowerCase();
      if (ancestorStr.contains('navigationbar') ||
          ancestorStr.contains('navigationdestination') ||
          ancestorStr.contains('bottomnavigationbar') ||
          ancestorStr.contains('tabbar') ||
          ancestorStr.contains('navigationrail')) {
        return true;
      }
    }

    return false;
  }

  /// Check if this is a structural UI element (AppBar, toolbar, etc.).
  bool _isStructuralWidget(String wtLower, List<dynamic> ancestors) {
    if (wtLower == 'appbar' ||
        wtLower == 'toolbar' ||
        wtLower == 'drawer' ||
        wtLower == 'bottomsheet') {
      return true;
    }

    if (ancestors.isNotEmpty) {
      final ancestorStr = ancestors.join(' ').toLowerCase();
      if (ancestorStr.contains('appbar') ||
          ancestorStr.contains('toolbar') ||
          ancestorStr.contains('drawer')) {
        return true;
      }
    }

    return false;
  }

  /// Check if a label indicates a destructive/gated action.
  bool _isGatedAction(String label) {
    final lower = label.toLowerCase();
    return gatedPatterns.any((p) => lower.contains(p));
  }

  // -----------------------------------------------------------------------
  // Intelligence: Screen type detection
  // -----------------------------------------------------------------------

  /// Regex patterns for error-like text content.
  static final _errorTextPattern = RegExp(
    r'\b(error|failed|failure|invalid|denied|unauthorized|forbidden'
    r'|not found|exception|could not|unable to|something went wrong'
    r'|oops|try again|cannot)\b',
    caseSensitive: false,
  );

  /// Regex patterns for loading indicator widget types.
  static final _loadingWidgetPattern = RegExp(
    r'CircularProgressIndicator|LinearProgressIndicator'
    r'|RefreshProgressIndicator|CupertinoActivityIndicator'
    r'|Shimmer|Skeleton',
    caseSensitive: false,
  );

  /// Regex patterns for snackbar / toast / banner widgets.
  static final _noticeWidgetPattern = RegExp(
    r'SnackBar|MaterialBanner|Toast|Notification',
    caseSensitive: false,
  );

  /// Classifications for the login button pattern.
  static final _submitButtonPattern = RegExp(
    r'\b(submit|save|confirm|apply|update|create|done|send'
    r'|register|sign up|next|finish|complete)\b',
    caseSensitive: false,
  );

  /// Classify the screen type from elements and context.
  ScryScreenType _classifyScreen(
    List<ScryElement> elements,
    List<ScryAlert> alerts,
    List<ScryKeyValue> dataFields,
  ) {
    final buttons = elements
        .where((e) => e.kind == ScryElementKind.button)
        .toList();
    final fields = elements
        .where((e) => e.kind == ScryElementKind.field)
        .toList();
    final nav = elements
        .where((e) => e.kind == ScryElementKind.navigation)
        .toList();
    final content = elements
        .where((e) => e.kind == ScryElementKind.content)
        .toList();

    // Error screen — error alerts present
    if (alerts.any((a) => a.severity == ScryAlertSeverity.error)) {
      return ScryScreenType.error;
    }

    // Login screen — fields + login button
    if (fields.isNotEmpty &&
        buttons.any(
          (b) => ScryGaze._loginButtonPattern.hasMatch(b.label.toLowerCase()),
        )) {
      return ScryScreenType.login;
    }

    // Settings screen — toggles, switches, dropdowns
    final toggleCount = elements.where((e) {
      final it = e.interactionType;
      return it == 'checkbox' ||
          it == 'radio' ||
          it == 'switch' ||
          it == 'slider' ||
          it == 'dropdown';
    }).length;
    if (toggleCount >= 2) {
      return ScryScreenType.settings;
    }

    // Form screen — multiple fields + submit/save button
    if (fields.length >= 2 &&
        buttons.any((b) => _submitButtonPattern.hasMatch(b.label))) {
      return ScryScreenType.form;
    }

    // Empty state — very few elements, no meaningful content
    if (content.isEmpty && fields.isEmpty && buttons.length <= 1) {
      return ScryScreenType.empty;
    }

    // List screen — many similar content items
    if (content.length >= 5 && fields.isEmpty && dataFields.isEmpty) {
      return ScryScreenType.list;
    }

    // Detail screen — data fields + limited buttons, possible back action
    if (dataFields.length >= 2 && fields.isEmpty) {
      return ScryScreenType.detail;
    }

    // Dashboard — mix of navigation, content, and buttons
    if (nav.length >= 2 && content.length >= 3 && buttons.isNotEmpty) {
      return ScryScreenType.dashboard;
    }

    return ScryScreenType.unknown;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Alert detection
  // -----------------------------------------------------------------------

  /// Detect errors, warnings, loading states, and notices from raw glyphs.
  List<ScryAlert> _detectAlerts(List<dynamic> glyphs) {
    final alerts = <ScryAlert>[];
    final seenMessages = <String>{};

    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final wt = glyph['wt'] as String? ?? '';
      final label = (glyph['l'] as String? ?? '').trim();
      final ancestors = glyph['anc'] as List<dynamic>? ?? [];
      final ancestorStr = ancestors.join(' ');

      // Loading indicators (by widget type)
      if (_loadingWidgetPattern.hasMatch(wt)) {
        final msg = label.isNotEmpty ? label : 'Loading indicator ($wt)';
        if (seenMessages.add(msg)) {
          alerts.add(
            ScryAlert(
              severity: ScryAlertSeverity.loading,
              message: msg,
              widgetType: wt,
            ),
          );
        }
        continue;
      }

      // Snackbar / MaterialBanner / Toast (by widget type or ancestor)
      if (_noticeWidgetPattern.hasMatch(wt) ||
          _noticeWidgetPattern.hasMatch(ancestorStr)) {
        if (label.isNotEmpty && seenMessages.add(label)) {
          // Classify as error if text contains error keywords
          final severity = _errorTextPattern.hasMatch(label)
              ? ScryAlertSeverity.error
              : ScryAlertSeverity.info;
          alerts.add(
            ScryAlert(severity: severity, message: label, widgetType: wt),
          );
        }
        continue;
      }

      // Error text detection (by content keywords)
      // Only if the text is short enough to be a message (not paragraphs)
      if (label.isNotEmpty &&
          label.length < 200 &&
          _errorTextPattern.hasMatch(label)) {
        // Only flag as error if it's clearly an error message, not
        // random content containing the word "error".
        final lower = label.toLowerCase();
        final isLikelyError =
            lower.startsWith('error') ||
            lower.startsWith('failed') ||
            lower.startsWith('invalid') ||
            lower.contains('try again') ||
            lower.contains('went wrong') ||
            lower.contains('could not') ||
            lower.contains('unable to');

        if (isLikelyError && seenMessages.add(label)) {
          alerts.add(
            ScryAlert(
              severity: ScryAlertSeverity.warning,
              message: label,
              widgetType: wt,
            ),
          );
        }
      }
    }

    return alerts;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Key-value pair extraction
  // -----------------------------------------------------------------------

  /// Pattern for labels that look like "Key: Value" pairs.
  static final _kvInlinePattern = RegExp(r'^(.+?):\s+(.+)$');

  /// Extract key-value pairs from raw glyphs using two strategies:
  ///
  /// 1. **Inline** — "Class: Scout" is a single label with ": " separator.
  /// 2. **Proximity** — "Class" at (x1, y1) and "Scout" at (x2, y2) where
  ///    they share the same Y band (same row) and x2 > x1.
  List<ScryKeyValue> _extractKeyValuePairs(List<dynamic> glyphs) {
    final pairs = <ScryKeyValue>[];
    final usedLabels = <String>{};

    // --- Strategy 1: Inline "Key: Value" patterns ---
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty) continue;

      // Only consider non-interactive, non-structural text
      if (glyph['ia'] == true) continue;

      final match = _kvInlinePattern.firstMatch(label);
      if (match != null) {
        final key = match.group(1)!.trim();
        final value = match.group(2)!.trim();
        // Skip if key is too long (probably not a label:value pair)
        if (key.length <= 30 && value.isNotEmpty) {
          pairs.add(ScryKeyValue(key: key, value: value));
          usedLabels.add(label);
        }
      }
    }

    // --- Strategy 2: Proximity-based pairing ---
    // Collect non-interactive text glyphs with positions
    final positioned = <({String label, double x, double y, double w})>[];
    for (final g in glyphs) {
      final glyph = g as Map<String, dynamic>;
      final label = (glyph['l'] as String? ?? '').trim();
      if (label.isEmpty || label.length < 2) continue;
      if (glyph['ia'] == true) continue;
      if (usedLabels.contains(label)) continue;

      final x = (glyph['x'] as num?)?.toDouble();
      final y = (glyph['y'] as num?)?.toDouble();
      final w = (glyph['w'] as num?)?.toDouble();
      if (x == null || y == null || w == null) continue;

      positioned.add((label: label, x: x, y: y, w: w));
    }

    // Sort by y (rows), then x (left to right)
    positioned.sort((a, b) {
      final dy = a.y.compareTo(b.y);
      return dy != 0 ? dy : a.x.compareTo(b.x);
    });

    // Find pairs where two labels share the same Y band
    // and the "key" label is short (< 25 chars) and ends with ":"
    for (var i = 0; i < positioned.length - 1; i++) {
      final left = positioned[i];
      final right = positioned[i + 1];

      // Same row? Y within 8 logical pixels
      if ((left.y - right.y).abs() > 8) continue;
      // Right is to the right of left?
      if (right.x <= left.x + left.w - 5) continue;

      // Key candidate: short, possibly ends with ":"
      final keyLabel = left.label;
      final valueLabel = right.label;

      if (keyLabel.length <= 25 &&
          !usedLabels.contains(keyLabel) &&
          !usedLabels.contains(valueLabel)) {
        // Strip trailing colon if present
        final cleanKey = keyLabel.endsWith(':')
            ? keyLabel.substring(0, keyLabel.length - 1).trim()
            : keyLabel;
        if (cleanKey.isNotEmpty && valueLabel.isNotEmpty) {
          pairs.add(ScryKeyValue(key: cleanKey, value: valueLabel));
          usedLabels
            ..add(keyLabel)
            ..add(valueLabel);
        }
      }
    }

    return pairs;
  }

  // -----------------------------------------------------------------------
  // Intelligence: Action suggestions
  // -----------------------------------------------------------------------

  /// Generate context-aware action suggestions.
  List<String> _generateSuggestions(
    List<ScryElement> elements,
    ScryScreenType screenType,
    List<ScryAlert> alerts,
  ) {
    final suggestions = <String>[];

    // Alert-driven suggestions
    if (alerts.any((a) => a.severity == ScryAlertSeverity.error)) {
      suggestions.add(
        'An error is visible — check the error message and '
        'consider navigating back or retrying the action.',
      );
    }
    if (alerts.any((a) => a.severity == ScryAlertSeverity.loading)) {
      suggestions.add(
        'The screen is loading — wait for the loading '
        'indicator to disappear before interacting.',
      );
    }

    final fields = elements
        .where((e) => e.kind == ScryElementKind.field)
        .toList();
    final buttons = elements
        .where((e) => e.kind == ScryElementKind.button)
        .toList();
    final nav = elements
        .where((e) => e.kind == ScryElementKind.navigation)
        .toList();

    switch (screenType) {
      case ScryScreenType.login:
        final loginField = fields.isNotEmpty ? fields.first.label : 'the field';
        final loginBtn = buttons
            .where(
              (b) =>
                  ScryGaze._loginButtonPattern.hasMatch(b.label.toLowerCase()),
            )
            .firstOrNull;
        suggestions.add(
          'Enter credentials in "$loginField" and tap '
          '"${loginBtn?.label ?? 'the login button'}".',
        );

      case ScryScreenType.form:
        final fieldNames = fields.map((f) => '"${f.label}"').join(', ');
        final submitBtn = buttons
            .where((b) => _submitButtonPattern.hasMatch(b.label))
            .firstOrNull;
        suggestions.add(
          'Fill in $fieldNames, then tap '
          '"${submitBtn?.label ?? 'Submit'}".',
        );

      case ScryScreenType.list:
        suggestions.add(
          'Tap an item to see its details, or use navigation '
          'tabs to switch sections.',
        );
        if (nav.isNotEmpty) {
          final tabNames = nav.map((n) => '"${n.label}"').join(', ');
          suggestions.add('Available tabs: $tabNames.');
        }

      case ScryScreenType.detail:
        suggestions.add(
          'Review the data displayed. Use the back button to '
          'return, or tap available actions.',
        );

      case ScryScreenType.settings:
        suggestions.add(
          'Toggle settings as needed. Changes may be applied '
          'immediately or require a save action.',
        );

      case ScryScreenType.empty:
        suggestions.add(
          'The screen appears empty. Try navigating to a '
          'different section or triggering an action.',
        );

      case ScryScreenType.error:
        suggestions.add(
          'The screen shows an error. Note the error message '
          'and navigate back or retry.',
        );

      case ScryScreenType.dashboard:
        if (nav.isNotEmpty) {
          final tabNames = nav.map((n) => '"${n.label}"').join(', ');
          suggestions.add('Navigate to: $tabNames.');
        }
        if (buttons.isNotEmpty) {
          suggestions.add(
            'Available actions: '
            '${buttons.map((b) => '"${b.label}"').take(5).join(', ')}.',
          );
        }

      case ScryScreenType.unknown:
        if (fields.isNotEmpty) {
          suggestions.add(
            'Text fields available: '
            '${fields.map((f) => '"${f.label}"').join(', ')}.',
          );
        }
        if (buttons.isNotEmpty) {
          suggestions.add(
            'Buttons available: '
            '${buttons.map((b) => '"${b.label}"').take(5).join(', ')}.',
          );
        }
        if (nav.isNotEmpty) {
          suggestions.add(
            'Navigation: '
            '${nav.map((n) => '"${n.label}"').join(', ')}.',
          );
        }
    }

    return suggestions;
  }
}
