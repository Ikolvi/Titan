// ---------------------------------------------------------------------------
// March — A Transition Between Screens
// ---------------------------------------------------------------------------

/// **March** — an observed transition between two [Outpost] screens.
///
/// Records how a user or automation moved from one screen to another,
/// including which element was interacted with to trigger the transition.
///
/// ## Why "March"?
///
/// Troops march from one outpost to another. Each March is a known
/// route between positions, observed during reconnaissance.
///
/// ## Usage
///
/// ```dart
/// final march = March(
///   fromRoute: '/login',
///   toRoute: '/',
///   trigger: MarchTrigger.formSubmit,
///   triggerElementLabel: 'Enter the Realm',
/// );
/// print(march.isReliable); // true if observed 2+ times
/// ```
class March {
  /// Source screen route pattern.
  final String fromRoute;

  /// Destination screen route pattern.
  final String toRoute;

  /// What triggered this transition.
  final MarchTrigger trigger;

  /// Label of the element that triggered the transition (if known).
  final String? triggerElementLabel;

  /// Widget type of the trigger element (if known).
  final String? triggerElementType;

  /// Key of the trigger element (if known).
  final String? triggerElementKey;

  /// Number of times this transition was observed.
  int observationCount;

  /// Whether this transition is reliable (observed 2+ times).
  bool get isReliable => observationCount >= 2;

  /// Average time taken for this transition (milliseconds).
  int averageDurationMs;

  /// Whether this transition requires specific preconditions.
  ///
  /// Example: navigating from /login to / requires valid credentials.
  String? preconditionNotes;

  /// Creates a [March].
  March({
    required this.fromRoute,
    required this.toRoute,
    required this.trigger,
    this.triggerElementLabel,
    this.triggerElementType,
    this.triggerElementKey,
    this.observationCount = 1,
    this.averageDurationMs = 0,
    this.preconditionNotes,
  });

  /// Whether this March matches another (same from/to/trigger element).
  bool matches(March other) {
    if (fromRoute != other.fromRoute || toRoute != other.toRoute) {
      return false;
    }
    // Same trigger element (by key or label)
    if (triggerElementKey != null && other.triggerElementKey != null) {
      return triggerElementKey == other.triggerElementKey;
    }
    return triggerElementLabel == other.triggerElementLabel &&
        triggerElementType == other.triggerElementType;
  }

  /// Merge another observation of the same transition.
  void mergeObservation(March other, {int? durationMs}) {
    final totalDuration =
        averageDurationMs * observationCount +
        (durationMs ?? other.averageDurationMs);
    observationCount++;
    averageDurationMs = totalDuration ~/ observationCount;
  }

  /// Short string for AI summaries.
  ///
  /// Example: `"→ / (tap "Enter the Realm")"`, `"← /login (redirect)"`
  String toShortString() {
    final triggerStr = triggerElementLabel != null
        ? '${trigger.name} "$triggerElementLabel"'
        : trigger.name;
    return '→ $toRoute ($triggerStr)';
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'fromRoute': fromRoute,
    'toRoute': toRoute,
    'trigger': trigger.name,
    if (triggerElementLabel != null) 'triggerElementLabel': triggerElementLabel,
    if (triggerElementType != null) 'triggerElementType': triggerElementType,
    if (triggerElementKey != null) 'triggerElementKey': triggerElementKey,
    'observationCount': observationCount,
    'averageDurationMs': averageDurationMs,
    if (preconditionNotes != null) 'preconditionNotes': preconditionNotes,
  };

  /// Deserialize from JSON map.
  factory March.fromJson(Map<String, dynamic> json) {
    return March(
      fromRoute: json['fromRoute'] as String,
      toRoute: json['toRoute'] as String,
      trigger: _triggerFromName(json['trigger'] as String),
      triggerElementLabel: json['triggerElementLabel'] as String?,
      triggerElementType: json['triggerElementType'] as String?,
      triggerElementKey: json['triggerElementKey'] as String?,
      observationCount: json['observationCount'] as int? ?? 1,
      averageDurationMs: json['averageDurationMs'] as int? ?? 0,
      preconditionNotes: json['preconditionNotes'] as String?,
    );
  }

  @override
  String toString() =>
      'March($fromRoute → $toRoute, ${trigger.name}, '
      '${observationCount}x observed)';

  static MarchTrigger _triggerFromName(String name) {
    for (final trigger in MarchTrigger.values) {
      if (trigger.name == name) return trigger;
    }
    return MarchTrigger.unknown;
  }
}

// ---------------------------------------------------------------------------
// MarchTrigger — What caused a transition
// ---------------------------------------------------------------------------

/// What triggered a [March] transition between screens.
enum MarchTrigger {
  /// User tapped a button/link.
  tap,

  /// User submitted a form (text input + button tap).
  formSubmit,

  /// Programmatic navigation (e.g., after async operation).
  programmatic,

  /// System redirect (e.g., auth guard).
  redirect,

  /// Back navigation (pop).
  back,

  /// Swipe gesture (e.g., dismissing a page).
  swipe,

  /// Deep link entry.
  deepLink,

  /// Unknown or unobserved trigger.
  unknown,
}
