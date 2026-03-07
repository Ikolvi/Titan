import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../recording/glyph.dart';
import '../recording/tableau.dart';
import 'stratagem.dart';

// ---------------------------------------------------------------------------
// Verdict — Execution Report
// ---------------------------------------------------------------------------

/// **Verdict** — the judgment after executing a [Stratagem].
///
/// Contains per-step results, failure details, performance metrics,
/// and captured Tableaux (screen snapshots). Serializes to JSON for
/// AI consumption.
///
/// ## Why "Verdict"?
///
/// After the Colossus marches through every screen following the
/// Stratagem's orders, it delivers its Verdict — carved in stone
/// for all to read.
///
/// ## Usage
///
/// ```dart
/// final verdict = await Colossus.instance.executeStratagem(stratagem);
/// if (verdict.passed) {
///   print('All ${verdict.summary.totalSteps} steps passed!');
/// } else {
///   print(verdict.toReport());
///   // Or send to AI for diagnosis:
///   print(verdict.toAiDiagnostic());
/// }
/// ```
class Verdict {
  /// The Stratagem name that was executed.
  final String stratagemName;

  /// When execution started.
  final DateTime executedAt;

  /// Total execution time.
  final Duration duration;

  /// Overall pass/fail.
  final bool passed;

  /// Per-step results.
  final List<VerdictStep> steps;

  /// Aggregate failure summary.
  final VerdictSummary summary;

  /// Performance metrics collected during execution.
  final VerdictPerformance performance;

  /// [Tableau]x captured at each step (screen state evidence).
  final List<Tableau> tableaux;

  /// Creates a [Verdict] from execution results.
  const Verdict({
    required this.stratagemName,
    required this.executedAt,
    required this.duration,
    required this.passed,
    required this.steps,
    required this.summary,
    required this.performance,
    this.tableaux = const [],
  });

  /// Build a Verdict from completed step results.
  factory Verdict.fromSteps({
    required String stratagemName,
    required DateTime executedAt,
    required Duration duration,
    required List<VerdictStep> steps,
    required VerdictPerformance performance,
    List<Tableau> tableaux = const [],
  }) {
    final passed = steps.every((s) => s.status == VerdictStepStatus.passed);
    final summary = VerdictSummary.fromSteps(steps, duration);
    return Verdict(
      stratagemName: stratagemName,
      executedAt: executedAt,
      duration: duration,
      passed: passed,
      steps: steps,
      summary: summary,
      performance: performance,
      tableaux: tableaux,
    );
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map for AI consumption.
  Map<String, dynamic> toJson() => {
    'stratagemName': stratagemName,
    'executedAt': executedAt.toIso8601String(),
    'duration': duration.inMilliseconds,
    'passed': passed,
    'summary': summary.toJson(),
    'steps': steps.map((s) => s.toJson()).toList(),
    'performance': performance.toJson(),
    if (tableaux.isNotEmpty)
      'tableaux': tableaux.map((t) => t.toMap()).toList(),
  };

  /// Parse from JSON map.
  factory Verdict.fromJson(Map<String, dynamic> json) {
    return Verdict(
      stratagemName: json['stratagemName'] as String,
      executedAt: DateTime.parse(json['executedAt'] as String),
      duration: Duration(milliseconds: json['duration'] as int),
      passed: json['passed'] as bool,
      steps: (json['steps'] as List)
          .map((e) => VerdictStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: VerdictSummary.fromJson(json['summary'] as Map<String, dynamic>),
      performance: VerdictPerformance.fromJson(
        json['performance'] as Map<String, dynamic>,
      ),
      tableaux:
          (json['tableaux'] as List?)
              ?.map((e) => Tableau.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Serialize to JSON string.
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Save this Verdict to a `.verdict.json` file.
  ///
  /// The file is written to `[directory]/[stratagemName].verdict.json`.
  /// Creates the directory if it doesn't exist.
  ///
  /// ```dart
  /// await verdict.saveToFile('/tmp/verdicts');
  /// // Creates /tmp/verdicts/login_flow.verdict.json
  /// ```
  Future<void> saveToFile(String directory) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    final file = File('$directory/$stratagemName.verdict.json');
    await file.writeAsString(toJsonString());
  }

  /// Load a Verdict from a `.verdict.json` file.
  ///
  /// Returns `null` if the file doesn't exist.
  static Future<Verdict?> loadFromFile(
    String name, {
    required String directory,
  }) async {
    final file = File('$directory/$name.verdict.json');
    if (!file.existsSync()) return null;
    final content = await file.readAsString();
    final json = jsonDecode(content) as Map<String, dynamic>;
    return Verdict.fromJson(json);
  }

  // -----------------------------------------------------------------------
  // Reports
  // -----------------------------------------------------------------------

  /// Generate a human-readable report.
  ///
  /// ```dart
  /// print(verdict.toReport());
  /// // ═══ Verdict: login_flow_happy_path ═══
  /// // Result: ❌ FAILED (4/6 steps passed — 67%)
  /// // Duration: 8.4s
  /// // ...
  /// ```
  String toReport() {
    final buffer = StringBuffer();
    buffer.writeln('═══ Verdict: $stratagemName ═══');
    buffer.writeln(summary.oneLiner);
    buffer.writeln(
      'Duration: ${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
    );
    buffer.writeln();

    for (final step in steps) {
      final icon = switch (step.status) {
        VerdictStepStatus.passed => '✅',
        VerdictStepStatus.failed => '❌',
        VerdictStepStatus.skipped => '⏭️',
      };
      buffer.writeln(
        '$icon Step ${step.stepId}: ${step.description} '
        '(${step.duration.inMilliseconds}ms)',
      );

      if (step.resolvedTarget != null) {
        final t = step.resolvedTarget!;
        buffer.writeln(
          '   Target: ${t.widgetType} "${t.label ?? "?"}" '
          'at (${t.centerX.round()}, ${t.centerY.round()})',
        );
      }

      if (step.failure != null) {
        final f = step.failure!;
        buffer.writeln('   FAILURE: ${f.message}');
        if (f.expected != null) buffer.writeln('   Expected: ${f.expected}');
        if (f.actual != null) buffer.writeln('   Actual: ${f.actual}');
        if (f.suggestions.isNotEmpty) {
          buffer.writeln('   Suggestions:');
          for (final s in f.suggestions) {
            buffer.writeln('     • $s');
          }
        }
      }
    }

    // Performance summary
    buffer.writeln();
    buffer.writeln('═══ Performance ═══');
    buffer.writeln('Average FPS: ${performance.averageFps.toStringAsFixed(1)}');
    if (performance.minFps > 0) {
      buffer.writeln('Min FPS: ${performance.minFps.toStringAsFixed(1)}');
    }
    if (performance.jankFrames > 0) {
      buffer.writeln('Jank frames: ${performance.jankFrames}');
    }
    if (performance.slowSteps.isNotEmpty) {
      buffer.writeln('Slow steps: ${performance.slowSteps.join(", ")}');
    }

    return buffer.toString().trimRight();
  }

  /// Generate an AI-optimized diagnostic (concise, structured).
  ///
  /// Returns a focused summary that AI agents can parse quickly
  /// to diagnose failures and suggest corrections.
  String toAiDiagnostic() {
    final buffer = StringBuffer();
    buffer.writeln('VERDICT: $stratagemName');
    buffer.writeln(
      'RESULT: ${passed ? "PASSED" : "FAILED"} '
      '(${summary.passedSteps}/${summary.totalSteps} steps, '
      '${(summary.successRate * 100).toStringAsFixed(0)}%)',
    );
    buffer.writeln(
      'DURATION: ${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s',
    );

    // Only detail failures
    final failedSteps = steps.where(
      (s) => s.status == VerdictStepStatus.failed,
    );
    for (final step in failedSteps) {
      buffer.writeln();
      buffer.writeln('FAILED STEP ${step.stepId}: ${step.description}');
      if (step.failure != null) {
        buffer.writeln('  TYPE: ${step.failure!.type.name}');
        buffer.writeln('  MESSAGE: ${step.failure!.message}');
        if (step.failure!.expected != null) {
          buffer.writeln('  EXPECTED: ${step.failure!.expected}');
        }
        if (step.failure!.actual != null) {
          buffer.writeln('  ACTUAL: ${step.failure!.actual}');
        }
        if (step.failure!.suggestions.isNotEmpty) {
          buffer.writeln('  SUGGESTIONS:');
          for (final s in step.failure!.suggestions) {
            buffer.writeln('    - $s');
          }
        }
      }

      // Show post-step screen state for context
      if (step.tableau != null) {
        buffer.writeln(
          '  SCREEN: route=${step.tableau!.route ?? "?"}, '
          '${step.tableau!.glyphs.length} elements',
        );
        final labels = step.tableau!.glyphs
            .where((g) => g.label != null)
            .take(10)
            .map((g) => '"${g.label}"')
            .join(', ');
        if (labels.isNotEmpty) {
          buffer.writeln('  VISIBLE: $labels');
        }
      }
    }

    // Performance alerts
    if (performance.jankFrames > 0 || performance.slowSteps.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('PERFORMANCE ALERTS:');
      if (performance.jankFrames > 0) {
        buffer.writeln(
          '  Jank: ${performance.jankFrames} frames, '
          'min FPS: ${performance.minFps.toStringAsFixed(1)}',
        );
      }
      if (performance.slowSteps.isNotEmpty) {
        buffer.writeln('  Slow steps: ${performance.slowSteps.join(", ")}');
      }
    }

    return buffer.toString().trimRight();
  }

  @override
  String toString() =>
      'Verdict($stratagemName, '
      '${passed ? "PASSED" : "FAILED"}, '
      '${summary.passedSteps}/${summary.totalSteps} steps)';
}

// ---------------------------------------------------------------------------
// VerdictStep — Result of executing one Stratagem step
// ---------------------------------------------------------------------------

/// Result of executing one [StratagemStep].
class VerdictStep {
  /// Step ID from the Stratagem.
  final int stepId;

  /// What this step tried to do.
  final String description;

  /// Pass, fail, or skip.
  final VerdictStepStatus status;

  /// Time taken for this step.
  final Duration duration;

  /// The [Tableau] captured after this step executed.
  final Tableau? tableau;

  /// The [Glyph] that was resolved as the target (if applicable).
  final Glyph? resolvedTarget;

  /// Failure details (null if passed).
  final VerdictFailure? failure;

  /// Screenshot at this step (if screenshots enabled).
  final Uint8List? fresco;

  /// Creates a [VerdictStep].
  const VerdictStep({
    required this.stepId,
    required this.description,
    required this.status,
    required this.duration,
    this.tableau,
    this.resolvedTarget,
    this.failure,
    this.fresco,
  });

  /// Create a passed step.
  factory VerdictStep.passed({
    required int stepId,
    required String description,
    required Duration duration,
    Tableau? tableau,
    Glyph? resolvedTarget,
  }) {
    return VerdictStep(
      stepId: stepId,
      description: description,
      status: VerdictStepStatus.passed,
      duration: duration,
      tableau: tableau,
      resolvedTarget: resolvedTarget,
    );
  }

  /// Create a failed step.
  factory VerdictStep.failed({
    required int stepId,
    required String description,
    required Duration duration,
    required VerdictFailure failure,
    Tableau? tableau,
    Glyph? resolvedTarget,
  }) {
    return VerdictStep(
      stepId: stepId,
      description: description,
      status: VerdictStepStatus.failed,
      duration: duration,
      tableau: tableau,
      resolvedTarget: resolvedTarget,
      failure: failure,
    );
  }

  /// Create a skipped step.
  factory VerdictStep.skipped({
    required int stepId,
    required String description,
  }) {
    return VerdictStep(
      stepId: stepId,
      description: description,
      status: VerdictStepStatus.skipped,
      duration: Duration.zero,
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'stepId': stepId,
    'description': description,
    'status': status.name,
    'duration': duration.inMilliseconds,
    if (tableau != null) 'tableau': tableau!.toMap(),
    if (resolvedTarget != null) 'resolvedTarget': resolvedTarget!.toMap(),
    if (failure != null) 'failure': failure!.toJson(),
    if (fresco != null) 'fresco': base64Encode(fresco!),
  };

  /// Parse from JSON map.
  factory VerdictStep.fromJson(Map<String, dynamic> json) {
    return VerdictStep(
      stepId: json['stepId'] as int,
      description: json['description'] as String,
      status: _stepStatusFromName(json['status'] as String),
      duration: Duration(milliseconds: json['duration'] as int),
      tableau: json['tableau'] != null
          ? Tableau.fromMap(json['tableau'] as Map<String, dynamic>)
          : null,
      resolvedTarget: json['resolvedTarget'] != null
          ? Glyph.fromMap(json['resolvedTarget'] as Map<String, dynamic>)
          : null,
      failure: json['failure'] != null
          ? VerdictFailure.fromJson(json['failure'] as Map<String, dynamic>)
          : null,
      fresco: json['fresco'] != null
          ? base64Decode(json['fresco'] as String)
          : null,
    );
  }

  @override
  String toString() =>
      'VerdictStep(#$stepId, ${status.name}, '
      '${duration.inMilliseconds}ms)';

  static VerdictStepStatus _stepStatusFromName(String name) {
    return switch (name) {
      'failed' => VerdictStepStatus.failed,
      'skipped' => VerdictStepStatus.skipped,
      _ => VerdictStepStatus.passed,
    };
  }
}

// ---------------------------------------------------------------------------
// VerdictFailure — Failure details for a step
// ---------------------------------------------------------------------------

/// Failure details for a [VerdictStep].
class VerdictFailure {
  /// Category of failure.
  final VerdictFailureType type;

  /// Human-readable failure message.
  final String message;

  /// What was expected.
  final String? expected;

  /// What was actually found.
  final String? actual;

  /// Auto-generated suggestions for fixing.
  final List<String> suggestions;

  /// Creates a [VerdictFailure].
  const VerdictFailure({
    required this.type,
    required this.message,
    this.expected,
    this.actual,
    this.suggestions = const [],
  });

  /// Generate failure suggestions based on [type] and context.
  static List<String> generateSuggestions({
    required VerdictFailureType type,
    Tableau? tableau,
    StratagemTarget? target,
    String? expectedRoute,
  }) {
    final suggestions = <String>[];

    switch (type) {
      case VerdictFailureType.targetNotFound:
        if (target?.label != null) {
          suggestions.add(
            'No element with label "${target!.label}" found on screen',
          );
        }
        if (tableau != null) {
          final labels = tableau.glyphs
              .where((g) => g.label != null)
              .take(10)
              .map((g) => '"${g.label}"')
              .join(', ');
          if (labels.isNotEmpty) {
            suggestions.add('Elements found: $labels');
          }
          if (tableau.route != null) {
            suggestions.add('Current route: ${tableau.route}');
          }
        }
        suggestions.add(
          'Try using a different label, key, or check if element is visible',
        );

      case VerdictFailureType.wrongRoute:
        if (expectedRoute != null && tableau?.route != null) {
          suggestions.add(
            'Expected route "$expectedRoute" but found "${tableau!.route}"',
          );
          suggestions.add(
            'Update the Stratagem to expect "${tableau.route}" '
            'or check the navigation logic',
          );
        }

      case VerdictFailureType.elementMissing:
        suggestions.add(
          'Expected element is not visible on the current screen',
        );
        suggestions.add(
          'Check if the element requires scrolling to become visible',
        );

      case VerdictFailureType.elementUnexpected:
        suggestions.add('An element that should be absent is still visible');

      case VerdictFailureType.wrongState:
        suggestions.add('Element found but in an unexpected state');

      case VerdictFailureType.timeout:
        suggestions.add('Step took too long — increase timeout or wait time');
        suggestions.add(
          'Check if an async operation (API call, animation) is slow',
        );

      case VerdictFailureType.notInteractive:
        suggestions.add(
          'Element found but is not interactive (e.g., disabled button)',
        );

      case VerdictFailureType.apiError:
      case VerdictFailureType.exception:
      case VerdictFailureType.pageLoadFailure:
      case VerdictFailureType.expectationFailed:
        suggestions.add('Check the app logs for error details');
    }

    return suggestions;
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'type': type.name,
    'message': message,
    if (expected != null) 'expected': expected,
    if (actual != null) 'actual': actual,
    if (suggestions.isNotEmpty) 'suggestions': suggestions,
  };

  /// Parse from JSON map.
  factory VerdictFailure.fromJson(Map<String, dynamic> json) {
    return VerdictFailure(
      type: _failureTypeFromName(json['type'] as String),
      message: json['message'] as String,
      expected: json['expected'] as String?,
      actual: json['actual'] as String?,
      suggestions: (json['suggestions'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  String toString() => 'VerdictFailure(${type.name}: $message)';

  static VerdictFailureType _failureTypeFromName(String name) {
    for (final t in VerdictFailureType.values) {
      if (t.name == name) return t;
    }
    return VerdictFailureType.exception;
  }
}

// ---------------------------------------------------------------------------
// VerdictFailureType — Categories of failures
// ---------------------------------------------------------------------------

/// Types of failures the [Verdict] can report.
enum VerdictFailureType {
  /// Target element not found on screen.
  targetNotFound,

  /// Expected element present but missing.
  elementMissing,

  /// Expected element absent but present.
  elementUnexpected,

  /// Navigation went to wrong route.
  wrongRoute,

  /// Element found but in wrong state.
  wrongState,

  /// Step timed out waiting for settle.
  timeout,

  /// API/network error detected during step.
  apiError,

  /// Exception thrown during step execution.
  exception,

  /// Element found but not interactive.
  notInteractive,

  /// Page failed to load.
  pageLoadFailure,

  /// Assertion in expectations failed.
  expectationFailed,
}

// ---------------------------------------------------------------------------
// VerdictStepStatus — Status of a single verdict step
// ---------------------------------------------------------------------------

/// Status of a single [VerdictStep].
enum VerdictStepStatus {
  /// Step completed successfully.
  passed,

  /// Step failed.
  failed,

  /// Step was skipped (e.g., depends on failed step).
  skipped,
}

// ---------------------------------------------------------------------------
// VerdictSummary — Aggregate failure summary
// ---------------------------------------------------------------------------

/// Aggregate summary of all [VerdictStep] results.
class VerdictSummary {
  /// Total number of steps.
  final int totalSteps;

  /// Number of steps that passed.
  final int passedSteps;

  /// Number of steps that failed.
  final int failedSteps;

  /// Number of steps that were skipped.
  final int skippedSteps;

  /// Routes where failures occurred.
  final List<String> failedRoutes;

  /// Labels of elements that were not found.
  final List<String> missingElements;

  /// API errors encountered.
  final List<String> apiErrors;

  /// Unexpected routes navigated to.
  final List<String> unexpectedRoutes;

  /// Success rate (0.0 to 1.0).
  final double successRate;

  /// Total execution duration.
  final Duration duration;

  /// Creates a [VerdictSummary].
  const VerdictSummary({
    required this.totalSteps,
    required this.passedSteps,
    required this.failedSteps,
    required this.skippedSteps,
    this.failedRoutes = const [],
    this.missingElements = const [],
    this.apiErrors = const [],
    this.unexpectedRoutes = const [],
    required this.successRate,
    required this.duration,
  });

  /// Build a summary from a list of completed steps.
  factory VerdictSummary.fromSteps(List<VerdictStep> steps, Duration duration) {
    final passed = steps
        .where((s) => s.status == VerdictStepStatus.passed)
        .length;
    final failed = steps
        .where((s) => s.status == VerdictStepStatus.failed)
        .length;
    final skipped = steps
        .where((s) => s.status == VerdictStepStatus.skipped)
        .length;

    final failedRoutes = <String>[];
    final missingElements = <String>[];
    final apiErrors = <String>[];
    final unexpectedRoutes = <String>[];

    for (final step in steps) {
      if (step.failure == null) continue;
      final f = step.failure!;

      if (f.type == VerdictFailureType.wrongRoute && f.actual != null) {
        unexpectedRoutes.add(f.actual!);
      }
      if (f.type == VerdictFailureType.targetNotFound ||
          f.type == VerdictFailureType.elementMissing) {
        missingElements.add(f.message);
      }
      if (f.type == VerdictFailureType.apiError) {
        apiErrors.add(f.message);
      }
      if (step.tableau?.route != null) {
        failedRoutes.add(step.tableau!.route!);
      }
    }

    return VerdictSummary(
      totalSteps: steps.length,
      passedSteps: passed,
      failedSteps: failed,
      skippedSteps: skipped,
      failedRoutes: failedRoutes,
      missingElements: missingElements,
      apiErrors: apiErrors,
      unexpectedRoutes: unexpectedRoutes,
      successRate: steps.isEmpty ? 1.0 : passed / steps.length,
      duration: duration,
    );
  }

  /// One-line summary for quick display.
  String get oneLiner {
    if (failedSteps == 0) {
      return '✅ All $totalSteps steps passed in '
          '${duration.inMilliseconds}ms';
    }
    return '❌ $failedSteps/$totalSteps steps failed'
        '${missingElements.isNotEmpty ? ": ${missingElements.join(", ")}" : ""}';
  }

  /// Whether all steps passed.
  bool get passed => failedSteps == 0;

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'totalSteps': totalSteps,
    'passedSteps': passedSteps,
    'failedSteps': failedSteps,
    'skippedSteps': skippedSteps,
    'successRate': successRate,
    'duration': duration.inMilliseconds,
    if (failedRoutes.isNotEmpty) 'failedRoutes': failedRoutes,
    if (missingElements.isNotEmpty) 'missingElements': missingElements,
    if (apiErrors.isNotEmpty) 'apiErrors': apiErrors,
    if (unexpectedRoutes.isNotEmpty) 'unexpectedRoutes': unexpectedRoutes,
  };

  /// Parse from JSON map.
  factory VerdictSummary.fromJson(Map<String, dynamic> json) {
    return VerdictSummary(
      totalSteps: json['totalSteps'] as int,
      passedSteps: json['passedSteps'] as int,
      failedSteps: json['failedSteps'] as int,
      skippedSteps: json['skippedSteps'] as int,
      successRate: (json['successRate'] as num).toDouble(),
      duration: Duration(milliseconds: json['duration'] as int),
      failedRoutes: (json['failedRoutes'] as List?)?.cast<String>() ?? const [],
      missingElements:
          (json['missingElements'] as List?)?.cast<String>() ?? const [],
      apiErrors: (json['apiErrors'] as List?)?.cast<String>() ?? const [],
      unexpectedRoutes:
          (json['unexpectedRoutes'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  String toString() =>
      'VerdictSummary('
      '$passedSteps/$totalSteps passed, '
      '${(successRate * 100).toStringAsFixed(0)}%)';
}

// ---------------------------------------------------------------------------
// VerdictPerformance — Performance metrics during execution
// ---------------------------------------------------------------------------

/// Performance metrics captured during [Stratagem] execution.
class VerdictPerformance {
  /// Average FPS during execution.
  final double averageFps;

  /// Minimum FPS (worst frame).
  final double minFps;

  /// Number of jank frames (>16ms).
  final int jankFrames;

  /// Memory usage at start (bytes).
  final int startMemoryBytes;

  /// Memory usage at end (bytes).
  final int endMemoryBytes;

  /// Settle times per step (step ID → duration).
  final Map<int, Duration> settleTimes;

  /// Steps that took longer than expected.
  final List<int> slowSteps;

  /// Creates a [VerdictPerformance].
  const VerdictPerformance({
    this.averageFps = 0,
    this.minFps = 0,
    this.jankFrames = 0,
    this.startMemoryBytes = 0,
    this.endMemoryBytes = 0,
    this.settleTimes = const {},
    this.slowSteps = const [],
  });

  /// Memory delta in bytes.
  int get memoryDelta => endMemoryBytes - startMemoryBytes;

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'averageFps': averageFps,
    'minFps': minFps,
    'jankFrames': jankFrames,
    'startMemoryBytes': startMemoryBytes,
    'endMemoryBytes': endMemoryBytes,
    if (settleTimes.isNotEmpty)
      'settleTimes': settleTimes.map(
        (k, v) => MapEntry(k.toString(), v.inMilliseconds),
      ),
    if (slowSteps.isNotEmpty) 'slowSteps': slowSteps,
  };

  /// Parse from JSON map.
  factory VerdictPerformance.fromJson(Map<String, dynamic> json) {
    return VerdictPerformance(
      averageFps: (json['averageFps'] as num?)?.toDouble() ?? 0,
      minFps: (json['minFps'] as num?)?.toDouble() ?? 0,
      jankFrames: json['jankFrames'] as int? ?? 0,
      startMemoryBytes: json['startMemoryBytes'] as int? ?? 0,
      endMemoryBytes: json['endMemoryBytes'] as int? ?? 0,
      settleTimes:
          (json['settleTimes'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(int.parse(k), Duration(milliseconds: v as int)),
          ) ??
          const {},
      slowSteps: (json['slowSteps'] as List?)?.cast<int>() ?? const [],
    );
  }

  @override
  String toString() =>
      'VerdictPerformance('
      'fps: ${averageFps.toStringAsFixed(1)}, '
      'jank: $jankFrames)';
}
