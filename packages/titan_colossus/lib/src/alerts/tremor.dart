import 'package:titan/titan.dart';

import '../metrics/mark.dart';

// ---------------------------------------------------------------------------
// Tremor — Performance Alerts
// ---------------------------------------------------------------------------

/// **Tremor** — a performance alert that fires when a threshold is breached.
///
/// Tremors are configurable thresholds that emit [Herald] events when
/// performance degrades past acceptable limits.
///
/// ## Why "Tremor"?
///
/// The earth trembles when the Colossus detects danger. Each Tremor is
/// a seismic warning of performance degradation.
///
/// ```dart
/// Colossus.init(
///   tremors: [
///     Tremor.fps(threshold: 50),        // Alert when FPS < 50
///     Tremor.jankRate(threshold: 5),     // Alert when jank > 5%
///     Tremor.pageLoad(threshold: Duration(seconds: 1)),
///     Tremor.memory(maxPillars: 50),     // Alert when > 50 Pillars
///     Tremor.rebuilds(threshold: 100, widget: 'QuestList'),
///   ],
/// );
/// ```
class Tremor {
  /// Human-readable name for this tremor.
  final String name;

  /// The category of metric this tremor watches.
  final MarkCategory category;

  /// The check function — returns `true` when the threshold is breached.
  final bool Function(TremorContext context) _check;

  /// The severity of this tremor alert.
  final TremorSeverity severity;

  /// Whether this tremor alerts only once, or on every check cycle.
  final bool once;

  bool _hasFired = false;

  /// Creates a custom [Tremor].
  Tremor({
    required this.name,
    required this.category,
    required bool Function(TremorContext context) check,
    this.severity = TremorSeverity.warning,
    this.once = false,
  }) : _check = check;

  /// Evaluate the tremor against the current context.
  ///
  /// Returns `true` if the threshold is breached and an alert should fire.
  bool evaluate(TremorContext context) {
    if (once && _hasFired) return false;
    final breached = _check(context);
    if (breached) _hasFired = true;
    return breached;
  }

  /// Reset the fired state (for recurring checks).
  void reset() => _hasFired = false;

  // -----------------------------------------------------------------------
  // Factory constructors for common thresholds
  // -----------------------------------------------------------------------

  /// Alert when FPS drops below [threshold] (default: 50).
  ///
  /// ```dart
  /// Tremor.fps(threshold: 55) // Alert when FPS < 55
  /// ```
  factory Tremor.fps({
    double threshold = 50,
    TremorSeverity severity = TremorSeverity.warning,
    bool once = false,
  }) {
    return Tremor(
      name: 'fps_low',
      category: MarkCategory.frame,
      severity: severity,
      once: once,
      check: (ctx) => ctx.fps > 0 && ctx.fps < threshold,
    );
  }

  /// Alert when jank rate exceeds [threshold] percent (default: 5%).
  ///
  /// ```dart
  /// Tremor.jankRate(threshold: 10) // Alert when jank > 10%
  /// ```
  factory Tremor.jankRate({
    double threshold = 5,
    TremorSeverity severity = TremorSeverity.warning,
    bool once = false,
  }) {
    return Tremor(
      name: 'jank_rate',
      category: MarkCategory.frame,
      severity: severity,
      once: once,
      check: (ctx) => ctx.jankRate > threshold,
    );
  }

  /// Alert when page load exceeds [threshold] duration.
  ///
  /// ```dart
  /// Tremor.pageLoad(threshold: Duration(seconds: 1))
  /// ```
  factory Tremor.pageLoad({
    Duration threshold = const Duration(seconds: 1),
    TremorSeverity severity = TremorSeverity.warning,
    bool once = false,
  }) {
    return Tremor(
      name: 'page_load_slow',
      category: MarkCategory.pageLoad,
      severity: severity,
      once: once,
      check: (ctx) =>
          ctx.lastPageLoad != null && ctx.lastPageLoad!.duration > threshold,
    );
  }

  /// Alert when Pillar count exceeds [maxPillars].
  ///
  /// ```dart
  /// Tremor.memory(maxPillars: 30)
  /// ```
  factory Tremor.memory({
    int maxPillars = 50,
    TremorSeverity severity = TremorSeverity.warning,
    bool once = false,
  }) {
    return Tremor(
      name: 'memory_high',
      category: MarkCategory.memory,
      severity: severity,
      once: once,
      check: (ctx) => ctx.pillarCount > maxPillars,
    );
  }

  /// Alert when a specific widget exceeds [threshold] rebuilds.
  ///
  /// ```dart
  /// Tremor.rebuilds(threshold: 100, widget: 'QuestList')
  /// ```
  factory Tremor.rebuilds({
    required int threshold,
    required String widget,
    TremorSeverity severity = TremorSeverity.warning,
    bool once = false,
  }) {
    return Tremor(
      name: 'excessive_rebuilds',
      category: MarkCategory.rebuild,
      severity: severity,
      once: once,
      check: (ctx) => (ctx.rebuildsPerWidget[widget] ?? 0) > threshold,
    );
  }

  /// Alert when any leak suspects are detected.
  ///
  /// ```dart
  /// Tremor.leaks()
  /// ```
  factory Tremor.leaks({
    TremorSeverity severity = TremorSeverity.error,
    bool once = true,
  }) {
    return Tremor(
      name: 'leak_detected',
      category: MarkCategory.memory,
      severity: severity,
      once: once,
      check: (ctx) => ctx.leakSuspects.isNotEmpty,
    );
  }

  @override
  String toString() => 'Tremor($name, ${severity.name})';
}

/// Severity level for [Tremor] alerts.
enum TremorSeverity {
  /// Informational — threshold breached but not critical.
  info,

  /// Warning — performance is degraded.
  warning,

  /// Error — performance is severely impacted.
  error,
}

// ---------------------------------------------------------------------------
// TremorContext — Data passed to Tremor checks
// ---------------------------------------------------------------------------

/// Provides current performance data to [Tremor] check functions.
class TremorContext {
  /// Current frames per second.
  final double fps;

  /// Current jank rate (0.0–100.0).
  final double jankRate;

  /// Number of live Pillar instances.
  final int pillarCount;

  /// Current leak suspects.
  final List<LeakSuspect> leakSuspects;

  /// Most recent page load (if any).
  final PageLoadMark? lastPageLoad;

  /// Widget rebuild counts by label.
  final Map<String, int> rebuildsPerWidget;

  /// Creates a [TremorContext].
  const TremorContext({
    required this.fps,
    required this.jankRate,
    required this.pillarCount,
    required this.leakSuspects,
    required this.lastPageLoad,
    required this.rebuildsPerWidget,
  });
}

// ---------------------------------------------------------------------------
// Herald Events — Tremor alerts emitted via Herald
// ---------------------------------------------------------------------------

/// Herald event emitted when a [Tremor] fires.
///
/// Listen for these in any Pillar:
///
/// ```dart
/// listen<ColossusTremor>((event) {
///   log.warning('Tremor: ${event.tremor.name} — ${event.message}');
/// });
/// ```
class ColossusTremor {
  /// The tremor that fired.
  final Tremor tremor;

  /// Human-readable description of what triggered the alert.
  final String message;

  /// When the tremor fired.
  final DateTime timestamp;

  /// Creates a [ColossusTremor] event.
  ColossusTremor({
    required this.tremor,
    required this.message,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Serialize to JSON-safe map.
  Map<String, dynamic> toMap() => {
    'name': tremor.name,
    'category': tremor.category.name,
    'severity': tremor.severity.name,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  String toString() => 'ColossusTremor(${tremor.name}: $message)';
}
