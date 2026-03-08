import '../discovery/scout.dart';
import '../discovery/terrain.dart';
import 'verdict.dart';

// ---------------------------------------------------------------------------
// InsightType
// ---------------------------------------------------------------------------

/// Category of a [DebriefInsight].
///
/// ```dart
/// if (insight.type == InsightType.elementNotFound) {
///   print('Element missing: ${insight.message}');
/// }
/// ```
enum InsightType {
  /// Target element not found on screen.
  elementNotFound,

  /// Navigation went to an unexpected route.
  unexpectedNavigation,

  /// The flow is missing a prerequisite (likely auth).
  missingPrerequisite,

  /// Multiple elements are missing — possibly on the wrong screen.
  wrongScreen,

  /// Step timed out or performance was poor.
  performanceIssue,

  /// State corruption detected.
  stateCorruption,

  /// General / uncategorized insight.
  general,
}

// ---------------------------------------------------------------------------
// DebriefInsight
// ---------------------------------------------------------------------------

/// A single insight produced by the [Debrief] engine.
///
/// Insights classify failures and provide actionable suggestions for
/// the AI to improve subsequent [Campaign] runs.
///
/// ```dart
/// final insight = DebriefInsight(
///   type: InsightType.elementNotFound,
///   message: 'Button "Login" not found',
///   suggestion: 'Update target label',
///   actionable: true,
/// );
/// ```
class DebriefInsight {
  /// Category of this insight.
  final InsightType type;

  /// Human/AI-readable description.
  final String message;

  /// Contextual guidance for the AI.
  final String suggestion;

  /// Whether the AI can act on this automatically.
  final bool actionable;

  /// Optional concrete fix instruction.
  final String? fixSuggestion;

  /// Creates a [DebriefInsight].
  const DebriefInsight({
    required this.type,
    required this.message,
    required this.suggestion,
    this.actionable = false,
    this.fixSuggestion,
  });

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'message': message,
    'suggestion': suggestion,
    'actionable': actionable,
    if (fixSuggestion != null) 'fixSuggestion': fixSuggestion,
  };

  /// Deserialize from JSON.
  factory DebriefInsight.fromJson(Map<String, dynamic> json) {
    return DebriefInsight(
      type: InsightType.values.firstWhere(
        (v) => v.name == json['type'],
        orElse: () => InsightType.general,
      ),
      message: json['message'] as String,
      suggestion: json['suggestion'] as String,
      actionable: json['actionable'] as bool? ?? false,
      fixSuggestion: json['fixSuggestion'] as String?,
    );
  }

  @override
  String toString() => 'DebriefInsight(${type.name}: $message)';
}

// ---------------------------------------------------------------------------
// DebriefReport
// ---------------------------------------------------------------------------

/// The complete output of a [Debrief] analysis.
///
/// Contains verdicts, insights, terrain updates, and suggested next actions.
///
/// ```dart
/// final report = debrief.analyze();
/// print(report.toAiSummary());
/// ```
class DebriefReport {
  /// All verdicts that were analyzed.
  final List<Verdict> verdicts;

  /// Insights produced from failure analysis.
  final List<DebriefInsight> insights;

  /// Summary of Terrain updates applied.
  final String terrainUpdates;

  /// Suggested next actions for the AI.
  final List<String> suggestedNextActions;

  /// Creates a [DebriefReport].
  const DebriefReport({
    required this.verdicts,
    required this.insights,
    required this.terrainUpdates,
    required this.suggestedNextActions,
  });

  /// Total verdicts analyzed.
  int get totalVerdicts => verdicts.length;

  /// Number of verdicts that passed.
  int get passedVerdicts => verdicts.where((v) => v.passed).length;

  /// Number of verdicts that failed.
  int get failedVerdicts => verdicts.where((v) => !v.passed).length;

  /// Overall pass rate.
  double get passRate =>
      totalVerdicts == 0 ? 1.0 : passedVerdicts / totalVerdicts;

  /// Whether all verdicts passed.
  bool get allPassed => failedVerdicts == 0;

  /// Generate an AI-readable summary.
  ///
  /// This is the primary output for the AI learning loop:
  /// AI reads this, understands failures, and generates an improved Campaign.
  String toAiSummary() {
    final buf = StringBuffer()
      ..writeln('DEBRIEF REPORT')
      ..writeln('==============')
      ..writeln('VERDICTS: $totalVerdicts Stratagems executed')
      ..writeln('PASSED: $passedVerdicts/$totalVerdicts')
      ..writeln('INSIGHTS: ${insights.length}')
      ..writeln();

    for (final insight in insights) {
      buf.writeln('${insight.type.name.toUpperCase()}: ${insight.message}');
      buf.writeln('  → ${insight.suggestion}');
      if (insight.fixSuggestion != null) {
        buf.writeln('  FIX: ${insight.fixSuggestion}');
      }
      buf.writeln();
    }

    if (terrainUpdates.isNotEmpty) {
      buf.writeln('TERRAIN UPDATES:');
      buf.writeln(terrainUpdates);
      buf.writeln();
    }

    if (suggestedNextActions.isNotEmpty) {
      buf.writeln('SUGGESTED NEXT ACTIONS:');
      for (final action in suggestedNextActions) {
        buf.writeln('  • $action');
      }
    }

    return buf.toString();
  }

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => {
    'totalVerdicts': totalVerdicts,
    'passedVerdicts': passedVerdicts,
    'failedVerdicts': failedVerdicts,
    'passRate': passRate,
    'insights': insights.map((i) => i.toJson()).toList(),
    'terrainUpdates': terrainUpdates,
    'suggestedNextActions': suggestedNextActions,
  };

  /// Deserialize from JSON.
  factory DebriefReport.fromJson(
    Map<String, dynamic> json,
    List<Verdict> verdicts,
  ) {
    return DebriefReport(
      verdicts: verdicts,
      insights: (json['insights'] as List<dynamic>)
          .map((e) => DebriefInsight.fromJson(e as Map<String, dynamic>))
          .toList(),
      terrainUpdates: json['terrainUpdates'] as String? ?? '',
      suggestedNextActions:
          (json['suggestedNextActions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }

  @override
  String toString() =>
      'DebriefReport('
      '$totalVerdicts verdicts, '
      '${insights.length} insights, '
      'pass rate: ${(passRate * 100).toStringAsFixed(1)}%)';
}

// ---------------------------------------------------------------------------
// Debrief
// ---------------------------------------------------------------------------

/// **Debrief** — analyzes [Verdict] results and feeds insights back
/// to the [Terrain] and AI.
///
/// The Debrief engine sits in the feedback loop between execution and
/// planning. It classifies failures, detects patterns, updates the
/// Terrain with new discoveries, and produces actionable recommendations.
///
/// ```dart
/// final debrief = Debrief(
///   verdicts: [verdict1, verdict2],
///   terrain: terrain,
/// );
/// final report = debrief.analyze();
/// print(report.toAiSummary());
/// ```
class Debrief {
  /// The verdicts to analyze.
  final List<Verdict> verdicts;

  /// The [Terrain] to update with discoveries.
  final Terrain terrain;

  /// Optional [Scout] for analyzing verdicts. If null, uses singleton.
  final Scout? _scout;

  /// Creates a [Debrief].
  ///
  /// Provide a [scout] for testing; otherwise uses [Scout.instance].
  Debrief({required this.verdicts, required this.terrain, Scout? scout})
    : _scout = scout;

  /// Perform the full debrief analysis.
  ///
  /// 1. Feeds verdicts into Scout to update Terrain
  /// 2. Classifies each failed step into insights
  /// 3. Detects cross-step patterns
  /// 4. Generates suggested next actions
  ///
  /// Returns a [DebriefReport] with all findings.
  DebriefReport analyze() {
    final scout = _scout ?? Scout.instance;
    final insights = <DebriefInsight>[];
    final screensBefore = terrain.outposts.length;
    final marchesBefore = terrain.marches.length;

    // 1. Feed verdicts into Scout to update Terrain
    for (final verdict in verdicts) {
      scout.analyzeVerdict(verdict);
    }

    // 2. Analyze each failed step
    for (final verdict in verdicts) {
      if (verdict.passed) continue;
      for (final step in verdict.steps) {
        if (step.status == VerdictStepStatus.failed && step.failure != null) {
          insights.add(_analyzeFailure(step, verdict));
        }
      }
      // 3. Detect patterns across steps
      insights.addAll(_detectPatterns(verdict));
    }

    // 4. Summarize terrain updates
    final terrainUpdates = _summarizeTerrainUpdates(
      screensBefore,
      marchesBefore,
    );

    // 5. Generate next actions
    final nextActions = _suggestNextActions(insights);

    return DebriefReport(
      verdicts: verdicts,
      insights: insights,
      terrainUpdates: terrainUpdates,
      suggestedNextActions: nextActions,
    );
  }

  // -----------------------------------------------------------------------
  // Failure Analysis
  // -----------------------------------------------------------------------

  /// Classify a single failed step into an insight.
  DebriefInsight _analyzeFailure(VerdictStep step, Verdict verdict) {
    final failure = step.failure!;

    switch (failure.type) {
      case VerdictFailureType.targetNotFound:
        final visibleElements = <String>[];
        if (step.tableau != null) {
          for (final glyph in step.tableau!.glyphs) {
            if (glyph.isInteractive) {
              visibleElements.add(glyph.label ?? glyph.widgetType);
            }
          }
        }
        return DebriefInsight(
          type: InsightType.elementNotFound,
          message:
              'Step ${step.stepId} "${step.description}": target not found',
          suggestion: visibleElements.isNotEmpty
              ? 'Visible interactive elements: ${visibleElements.join(", ")}'
              : 'No interactive elements visible — screen may not have loaded',
          actionable: true,
          fixSuggestion:
              'Update target label to match one of the visible elements',
        );

      case VerdictFailureType.wrongRoute:
        return DebriefInsight(
          type: InsightType.unexpectedNavigation,
          message:
              'Step ${step.stepId}: expected route but navigated elsewhere',
          suggestion: failure.expected != null && failure.actual != null
              ? 'Expected: ${failure.expected}, Got: ${failure.actual}'
              : 'Check if auth prerequisite is needed',
          actionable: true,
          fixSuggestion: 'Add route prerequisite or update expected route',
        );

      case VerdictFailureType.timeout:
        return DebriefInsight(
          type: InsightType.performanceIssue,
          message:
              'Step ${step.stepId} timed out '
              '(${step.duration.inMilliseconds}ms)',
          suggestion: 'Increase timeout or add explicit wait step',
          actionable: true,
          fixSuggestion:
              'Set settleTimeout to ${step.duration.inMilliseconds * 2}ms',
        );

      case VerdictFailureType.wrongState:
        return DebriefInsight(
          type: InsightType.stateCorruption,
          message: 'Step ${step.stepId}: element in unexpected state',
          suggestion: failure.message,
          actionable: false,
        );

      default:
        return DebriefInsight(
          type: InsightType.general,
          message: 'Step ${step.stepId}: ${failure.message}',
          suggestion: failure.suggestions.isNotEmpty
              ? failure.suggestions.join('; ')
              : 'Investigate the failure manually',
          actionable: false,
          fixSuggestion: failure.suggestions.isNotEmpty
              ? failure.suggestions.first
              : null,
        );
    }
  }

  // -----------------------------------------------------------------------
  // Pattern Detection
  // -----------------------------------------------------------------------

  /// Detect cross-step patterns that indicate systemic issues.
  List<DebriefInsight> _detectPatterns(Verdict verdict) {
    final insights = <DebriefInsight>[];
    final failedSteps = verdict.steps.where(
      (s) => s.status == VerdictStepStatus.failed,
    );

    if (failedSteps.isEmpty) return insights;

    // Pattern 1: Missing prerequisite
    // First failed step has wrongRoute → likely auth/navigation issue
    final firstFailed = failedSteps.first;
    if (firstFailed.failure?.type == VerdictFailureType.wrongRoute) {
      insights.add(
        DebriefInsight(
          type: InsightType.missingPrerequisite,
          message:
              'First failure is a route mismatch in "${verdict.stratagemName}" '
              '— subsequent failures may be cascading',
          suggestion: 'Add prerequisite setup before this Stratagem',
          actionable: true,
          fixSuggestion:
              'Use Lineage.resolve() to inject navigation prerequisites',
        ),
      );
    }

    // Pattern 2: Wrong screen
    // 3+ steps fail with targetNotFound → probably on wrong screen
    final notFoundCount = failedSteps
        .where((s) => s.failure?.type == VerdictFailureType.targetNotFound)
        .length;
    if (notFoundCount >= 3) {
      insights.add(
        DebriefInsight(
          type: InsightType.wrongScreen,
          message:
              '$notFoundCount elements not found in "${verdict.stratagemName}" '
              '— possibly on the wrong screen',
          suggestion: 'Verify startRoute matches the expected screen',
          actionable: true,
          fixSuggestion: 'Check Scout.terrain for the correct route pattern',
        ),
      );
    }

    return insights;
  }

  // -----------------------------------------------------------------------
  // Terrain Updates
  // -----------------------------------------------------------------------

  /// Summarize what changed in the Terrain.
  String _summarizeTerrainUpdates(int screensBefore, int marchesBefore) {
    final screensAfter = terrain.outposts.length;
    final marchesAfter = terrain.marches.length;
    final newScreens = screensAfter - screensBefore;
    final newMarches = marchesAfter - marchesBefore;

    if (newScreens == 0 && newMarches == 0) {
      return 'No new screens or transitions discovered.';
    }

    final parts = <String>[];
    if (newScreens > 0) {
      parts.add('$newScreens new screen(s) discovered');
    }
    if (newMarches > 0) {
      parts.add('$newMarches new transition(s) discovered');
    }
    return '${parts.join(', ')}.';
  }

  // -----------------------------------------------------------------------
  // Next Actions
  // -----------------------------------------------------------------------

  /// Generate suggested next actions from insights.
  List<String> _suggestNextActions(List<DebriefInsight> insights) {
    if (insights.isEmpty) {
      return ['EXPAND: All tests passed — consider adding Gauntlet edge cases'];
    }

    final actions = <String>[];
    final types = insights.map((i) => i.type).toSet();

    if (types.contains(InsightType.missingPrerequisite)) {
      actions.add('RESOLVE: Add missing prerequisites (likely authentication)');
    }

    if (types.contains(InsightType.elementNotFound) ||
        types.contains(InsightType.wrongScreen)) {
      actions.add('UPDATE: Refresh element targets using getAiContext()');
    }

    if (types.contains(InsightType.performanceIssue)) {
      actions.add(
        'TUNE: Increase timeouts or add wait steps for slow operations',
      );
    }

    if (types.contains(InsightType.stateCorruption)) {
      actions.add(
        'INVESTIGATE: State corruption detected — manual debugging needed',
      );
    }

    if (types.contains(InsightType.general)) {
      actions.add('REVIEW: General failures require manual investigation');
    }

    return actions;
  }
}
