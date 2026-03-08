import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/recording/glyph.dart';
import 'package:titan_colossus/src/recording/tableau.dart';
import 'package:titan_colossus/src/testing/stratagem.dart';
import 'package:titan_colossus/src/testing/verdict.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Tableau makeTableau({String? route, List<Glyph>? glyphs}) {
  return Tableau(
    index: 0,
    timestamp: Duration.zero,
    glyphs: glyphs ?? [],
    route: route ?? '/test',
    screenWidth: 400,
    screenHeight: 800,
  );
}

VerdictStep makeStep({
  int id = 1,
  VerdictStepStatus status = VerdictStepStatus.passed,
  Duration duration = const Duration(milliseconds: 100),
  VerdictFailure? failure,
  Tableau? tableau,
  Glyph? resolvedTarget,
  Uint8List? fresco,
}) {
  return VerdictStep(
    stepId: id,
    description: 'Step $id',
    status: status,
    duration: duration,
    failure: failure,
    tableau: tableau,
    resolvedTarget: resolvedTarget,
    fresco: fresco,
  );
}

Verdict makeVerdict({
  List<VerdictStep>? steps,
  VerdictPerformance performance = const VerdictPerformance(),
}) {
  final s = steps ?? [makeStep()];
  return Verdict.fromSteps(
    stratagemName: 'test_flow',
    executedAt: DateTime(2025, 1, 15),
    duration: const Duration(seconds: 3),
    steps: s,
    performance: performance,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // Verdict — toString
  // -------------------------------------------------------------------------
  group('Verdict — toString', () {
    test('contains stratagem name', () {
      final v = makeVerdict();
      expect(v.toString(), contains('test_flow'));
    });

    test('shows PASSED for all-passing steps', () {
      final v = makeVerdict();
      expect(v.toString(), contains('PASSED'));
    });

    test('shows FAILED when a step fails', () {
      final v = makeVerdict(
        steps: [
          makeStep(
            status: VerdictStepStatus.failed,
            failure: const VerdictFailure(
              type: VerdictFailureType.timeout,
              message: 'timed out',
            ),
          ),
        ],
      );
      expect(v.toString(), contains('FAILED'));
    });

    test('shows step counts', () {
      final v = makeVerdict(steps: [makeStep(id: 1), makeStep(id: 2)]);
      expect(v.toString(), contains('2/2'));
    });
  });

  // -------------------------------------------------------------------------
  // Verdict — fromSteps edge cases
  // -------------------------------------------------------------------------
  group('Verdict — fromSteps edge cases', () {
    test('empty steps list results in passed=true', () {
      final v = makeVerdict(steps: []);
      expect(v.passed, isTrue);
      expect(v.summary.successRate, 1.0);
      expect(v.summary.totalSteps, 0);
    });
  });

  // -------------------------------------------------------------------------
  // VerdictStep — toString
  // -------------------------------------------------------------------------
  group('VerdictStep — toString', () {
    test('contains step ID and status', () {
      final step = makeStep(id: 7, duration: const Duration(milliseconds: 250));
      final s = step.toString();
      expect(s, contains('7'));
      expect(s, contains('passed'));
      expect(s, contains('250'));
    });
  });

  // -------------------------------------------------------------------------
  // VerdictStep — fresco serialization
  // -------------------------------------------------------------------------
  group('VerdictStep — fresco Base64 roundtrip', () {
    test('fresco bytes survive toJson/fromJson', () {
      final bytes = Uint8List.fromList([0, 1, 2, 255, 128, 64]);
      final step = makeStep(fresco: bytes);
      final json = step.toJson();
      expect(json.containsKey('fresco'), isTrue);
      expect(json['fresco'], base64Encode(bytes));

      final rebuilt = VerdictStep.fromJson(json);
      expect(rebuilt.fresco, isNotNull);
      expect(rebuilt.fresco, equals(bytes));
    });

    test('null fresco omitted from JSON', () {
      final step = makeStep();
      final json = step.toJson();
      expect(json.containsKey('fresco'), isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // VerdictStep — _stepStatusFromName
  // -------------------------------------------------------------------------
  group('VerdictStep — unknown status defaults to passed', () {
    test('unknown status string defaults to passed', () {
      final json = {
        'stepId': 1,
        'description': 'test',
        'status': 'wizard',
        'duration': 100,
      };
      final step = VerdictStep.fromJson(json);
      expect(step.status, VerdictStepStatus.passed);
    });
  });

  // -------------------------------------------------------------------------
  // VerdictFailure — toString
  // -------------------------------------------------------------------------
  group('VerdictFailure — toString', () {
    test('contains type and message', () {
      const f = VerdictFailure(
        type: VerdictFailureType.timeout,
        message: 'step timed out',
      );
      final s = f.toString();
      expect(s, contains('timeout'));
      expect(s, contains('step timed out'));
    });
  });

  // -------------------------------------------------------------------------
  // VerdictFailure — _failureTypeFromName
  // -------------------------------------------------------------------------
  group('VerdictFailure — unknown type defaults to exception', () {
    test('unknown type string defaults to exception', () {
      final json = {'type': 'cosmicRay', 'message': 'bit flip'};
      final f = VerdictFailure.fromJson(json);
      expect(f.type, VerdictFailureType.exception);
    });
  });

  // -------------------------------------------------------------------------
  // VerdictFailure.generateSuggestions — all types
  // -------------------------------------------------------------------------
  group('VerdictFailure.generateSuggestions — all types', () {
    test('elementUnexpected suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.elementUnexpected,
      );
      expect(s, contains('An element that should be absent is still visible'));
    });

    test('wrongState suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.wrongState,
      );
      expect(s, contains('Element found but in an unexpected state'));
    });

    test('apiError suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.apiError,
      );
      expect(s, contains('Check the app logs for error details'));
    });

    test('exception suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.exception,
      );
      expect(s, contains('Check the app logs for error details'));
    });

    test('pageLoadFailure suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.pageLoadFailure,
      );
      expect(s, contains('Check the app logs for error details'));
    });

    test('expectationFailed suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.expectationFailed,
      );
      expect(s, contains('Check the app logs for error details'));
    });

    test('timeout suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.timeout,
      );
      expect(s.any((x) => x.contains('timeout') || x.contains('long')), isTrue);
    });

    test('notInteractive suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.notInteractive,
      );
      expect(
        s,
        contains(
          'Element found but is not interactive '
          '(e.g., disabled button)',
        ),
      );
    });

    test('targetNotFound with tableau shows elements found', () {
      final tableau = makeTableau(
        glyphs: [
          Glyph(
            label: 'Alpha',
            widgetType: 'Text',
            left: 0,
            top: 0,
            width: 100,
            height: 50,
            ancestors: const [],
            isInteractive: false,
            isEnabled: true,
          ),
        ],
      );
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.targetNotFound,
        tableau: tableau,
        target: const StratagemTarget(label: 'Beta'),
      );
      expect(s.any((x) => x.contains('"Alpha"')), isTrue);
      expect(s.any((x) => x.contains('/test')), isTrue);
    });

    test('wrongRoute with expectedRoute and tableau', () {
      final tableau = makeTableau(route: '/actual');
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.wrongRoute,
        expectedRoute: '/expected',
        tableau: tableau,
      );
      expect(s.any((x) => x.contains('/expected')), isTrue);
      expect(s.any((x) => x.contains('/actual')), isTrue);
    });

    test('elementMissing suggestion', () {
      final s = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.elementMissing,
      );
      expect(
        s,
        contains('Expected element is not visible on the current screen'),
      );
      expect(
        s,
        contains('Check if the element requires scrolling to become visible'),
      );
    });
  });

  // -------------------------------------------------------------------------
  // VerdictSummary — toString
  // -------------------------------------------------------------------------
  group('VerdictSummary — toString', () {
    test('contains pass count and percentage', () {
      final summary = VerdictSummary.fromSteps([
        makeStep(id: 1),
        makeStep(
          id: 2,
          status: VerdictStepStatus.failed,
          failure: const VerdictFailure(
            type: VerdictFailureType.timeout,
            message: 'slow',
          ),
        ),
      ], const Duration(seconds: 2));
      final s = summary.toString();
      expect(s, contains('1/2'));
      expect(s, contains('50%'));
    });
  });

  // -------------------------------------------------------------------------
  // VerdictSummary — fromSteps edge cases
  // -------------------------------------------------------------------------
  group('VerdictSummary — fromSteps edge cases', () {
    test('empty steps yields 100% success rate', () {
      final summary = VerdictSummary.fromSteps([], const Duration(seconds: 1));
      expect(summary.successRate, 1.0);
      expect(summary.totalSteps, 0);
      expect(summary.failedRoutes, isEmpty);
    });

    test('oneLiner with missingElements shows element info', () {
      final summary = VerdictSummary.fromSteps([
        makeStep(
          id: 1,
          status: VerdictStepStatus.failed,
          failure: const VerdictFailure(
            type: VerdictFailureType.elementMissing,
            message: 'Expected "Submit Button" not found',
          ),
        ),
      ], const Duration(seconds: 1));
      final line = summary.oneLiner;
      expect(line, contains('❌'));
      expect(line, contains('Submit Button'));
    });

    test('failedRoutes populated from step.tableau.route', () {
      final summary = VerdictSummary.fromSteps([
        makeStep(
          id: 1,
          status: VerdictStepStatus.failed,
          tableau: makeTableau(route: '/login'),
          failure: const VerdictFailure(
            type: VerdictFailureType.timeout,
            message: 'slow',
          ),
        ),
      ], const Duration(seconds: 1));
      expect(summary.failedRoutes, contains('/login'));
    });

    test('unexpectedRoutes populated from wrongRoute failure', () {
      final summary = VerdictSummary.fromSteps([
        makeStep(
          id: 1,
          status: VerdictStepStatus.failed,
          failure: const VerdictFailure(
            type: VerdictFailureType.wrongRoute,
            message: 'wrong route',
            expected: '/home',
            actual: '/error',
          ),
        ),
      ], const Duration(seconds: 1));
      expect(summary.unexpectedRoutes, contains('/error'));
    });
  });

  // -------------------------------------------------------------------------
  // VerdictPerformance — edge cases
  // -------------------------------------------------------------------------
  group('VerdictPerformance — edge cases', () {
    test('toString contains fps and jank', () {
      const p = VerdictPerformance(averageFps: 58.5, jankFrames: 3);
      final s = p.toString();
      expect(s, contains('58.5'));
      expect(s, contains('3'));
    });

    test('negative memoryDelta when end < start', () {
      const p = VerdictPerformance(startMemoryBytes: 1000, endMemoryBytes: 500);
      expect(p.memoryDelta, -500);
    });

    test('settleTimes roundtrip through JSON', () {
      const p = VerdictPerformance(
        settleTimes: {1: Duration(milliseconds: 100), 2: Duration(seconds: 1)},
      );
      final json = p.toJson();
      final rebuilt = VerdictPerformance.fromJson(json);
      expect(rebuilt.settleTimes[1], const Duration(milliseconds: 100));
      expect(rebuilt.settleTimes[2], const Duration(seconds: 1));
    });

    test('slowSteps roundtrip through JSON', () {
      const p = VerdictPerformance(slowSteps: [3, 7]);
      final json = p.toJson();
      final rebuilt = VerdictPerformance.fromJson(json);
      expect(rebuilt.slowSteps, [3, 7]);
    });
  });

  // -------------------------------------------------------------------------
  // Verdict.toReport() edge cases
  // -------------------------------------------------------------------------
  group('Verdict.toReport — edge cases', () {
    test('skipped step shows skip icon', () {
      final v = makeVerdict(
        steps: [VerdictStep.skipped(stepId: 1, description: 'skipped step')],
      );
      final report = v.toReport();
      expect(report, contains('⏭️'));
    });

    test('step with resolvedTarget shows target info', () {
      final target = Glyph(
        label: 'Login',
        widgetType: 'ElevatedButton',
        left: 100,
        top: 200,
        width: 200,
        height: 60,
        ancestors: const [],
        isInteractive: true,
        isEnabled: true,
      );
      final v = makeVerdict(steps: [makeStep(resolvedTarget: target)]);
      final report = v.toReport();
      expect(report, contains('Target:'));
      expect(report, contains('Login'));
    });

    test('step with failure suggestions shows bullets', () {
      final v = makeVerdict(
        steps: [
          makeStep(
            status: VerdictStepStatus.failed,
            failure: const VerdictFailure(
              type: VerdictFailureType.timeout,
              message: 'timed out',
              suggestions: ['Increase timeout', 'Check network'],
            ),
          ),
        ],
      );
      final report = v.toReport();
      expect(report, contains('• Increase timeout'));
      expect(report, contains('• Check network'));
    });

    test('step with expected/actual shows both', () {
      final v = makeVerdict(
        steps: [
          makeStep(
            status: VerdictStepStatus.failed,
            failure: const VerdictFailure(
              type: VerdictFailureType.wrongRoute,
              message: 'wrong route',
              expected: '/home',
              actual: '/error',
            ),
          ),
        ],
      );
      final report = v.toReport();
      expect(report, contains('Expected: /home'));
      expect(report, contains('Actual: /error'));
    });

    test('performance with minFps=0 omits Min FPS line', () {
      final v = makeVerdict(
        performance: const VerdictPerformance(averageFps: 60, minFps: 0),
      );
      final report = v.toReport();
      expect(report, isNot(contains('Min FPS:')));
    });

    test('performance with minFps>0 includes Min FPS line', () {
      final v = makeVerdict(
        performance: const VerdictPerformance(averageFps: 60, minFps: 45),
      );
      final report = v.toReport();
      expect(report, contains('Min FPS: 45.0'));
    });

    test('performance with jankFrames>0 shows jank count', () {
      final v = makeVerdict(
        performance: const VerdictPerformance(jankFrames: 5),
      );
      final report = v.toReport();
      expect(report, contains('Jank frames: 5'));
    });

    test('performance with slowSteps shows them', () {
      final v = makeVerdict(
        performance: const VerdictPerformance(slowSteps: [3, 7]),
      );
      final report = v.toReport();
      expect(report, contains('Slow steps: 3, 7'));
    });
  });

  // -------------------------------------------------------------------------
  // Verdict.toAiDiagnostic() edge cases
  // -------------------------------------------------------------------------
  group('Verdict.toAiDiagnostic — edge cases', () {
    test('passing verdict has no FAILED STEP sections', () {
      final v = makeVerdict(steps: [makeStep(), makeStep(id: 2)]);
      final diag = v.toAiDiagnostic();
      expect(diag, contains('PASSED'));
      expect(diag, isNot(contains('FAILED STEP')));
    });

    test('failed step with tableau shows SCREEN line', () {
      final v = makeVerdict(
        steps: [
          makeStep(
            status: VerdictStepStatus.failed,
            tableau: makeTableau(
              route: '/login',
              glyphs: [
                Glyph(
                  label: 'Email',
                  widgetType: 'TextField',
                  left: 0,
                  top: 0,
                  width: 100,
                  height: 50,
                  ancestors: const [],
                  isInteractive: true,
                  isEnabled: true,
                ),
              ],
            ),
            failure: const VerdictFailure(
              type: VerdictFailureType.targetNotFound,
              message: 'not found',
            ),
          ),
        ],
      );
      final diag = v.toAiDiagnostic();
      expect(diag, contains('SCREEN:'));
      expect(diag, contains('/login'));
      expect(diag, contains('VISIBLE:'));
      expect(diag, contains('"Email"'));
    });

    test('failed step with tableau no labelled glyphs omits VISIBLE', () {
      final v = makeVerdict(
        steps: [
          makeStep(
            status: VerdictStepStatus.failed,
            tableau: makeTableau(
              route: '/empty',
              glyphs: [
                Glyph(
                  widgetType: 'Container',
                  left: 0,
                  top: 0,
                  width: 100,
                  height: 50,
                  ancestors: const [],
                  isInteractive: false,
                  isEnabled: true,
                ),
              ],
            ),
            failure: const VerdictFailure(
              type: VerdictFailureType.timeout,
              message: 'timed out',
            ),
          ),
        ],
      );
      final diag = v.toAiDiagnostic();
      expect(diag, contains('SCREEN:'));
      expect(diag, isNot(contains('VISIBLE:')));
    });

    test('failed step with null route shows route=?', () {
      final v = makeVerdict(
        steps: [
          VerdictStep(
            stepId: 1,
            description: 'Step 1',
            status: VerdictStepStatus.failed,
            duration: const Duration(milliseconds: 100),
            tableau: Tableau(
              index: 0,
              timestamp: Duration.zero,
              glyphs: const [],
              screenWidth: 400,
              screenHeight: 800,
            ),
            failure: const VerdictFailure(
              type: VerdictFailureType.timeout,
              message: 'timed out',
            ),
          ),
        ],
      );
      final diag = v.toAiDiagnostic();
      expect(diag, contains('route=?'));
    });

    test('failed step with suggestions shows SUGGESTIONS section', () {
      final v = makeVerdict(
        steps: [
          makeStep(
            status: VerdictStepStatus.failed,
            failure: const VerdictFailure(
              type: VerdictFailureType.timeout,
              message: 'timed out',
              suggestions: ['Try waiting longer'],
            ),
          ),
        ],
      );
      final diag = v.toAiDiagnostic();
      expect(diag, contains('SUGGESTIONS:'));
      expect(diag, contains('Try waiting longer'));
    });

    test('performance with jank shows PERFORMANCE ALERTS', () {
      final v = makeVerdict(
        steps: [makeStep()],
        performance: const VerdictPerformance(jankFrames: 10, minFps: 30),
      );
      final diag = v.toAiDiagnostic();
      expect(diag, contains('PERFORMANCE ALERTS:'));
      expect(diag, contains('Jank: 10'));
    });

    test('performance without jank or slowSteps omits alerts', () {
      final v = makeVerdict(
        steps: [makeStep()],
        performance: const VerdictPerformance(averageFps: 60, jankFrames: 0),
      );
      final diag = v.toAiDiagnostic();
      expect(diag, isNot(contains('PERFORMANCE ALERTS:')));
    });

    test('performance with slowSteps but no jank', () {
      final v = makeVerdict(
        steps: [makeStep()],
        performance: const VerdictPerformance(jankFrames: 0, slowSteps: [2, 5]),
      );
      final diag = v.toAiDiagnostic();
      expect(diag, contains('PERFORMANCE ALERTS:'));
      expect(diag, contains('Slow steps: 2, 5'));
      expect(diag, isNot(contains('Jank:')));
    });
  });
}
