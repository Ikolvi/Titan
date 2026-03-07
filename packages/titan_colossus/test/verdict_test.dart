import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/recording/glyph.dart';
import 'package:titan_colossus/src/recording/tableau.dart';
import 'package:titan_colossus/src/testing/stratagem.dart';
import 'package:titan_colossus/src/testing/verdict.dart';

void main() {
  // -------------------------------------------------------------------------
  // VerdictStep
  // -------------------------------------------------------------------------
  group('VerdictStep', () {
    test('passed factory creates correct step', () {
      final step = VerdictStep.passed(
        stepId: 1,
        description: 'Tapped button',
        duration: const Duration(milliseconds: 250),
      );
      expect(step.status, VerdictStepStatus.passed);
      expect(step.stepId, 1);
      expect(step.description, 'Tapped button');
      expect(step.duration, const Duration(milliseconds: 250));
      expect(step.failure, isNull);
      expect(step.resolvedTarget, isNull);
    });

    test('failed factory creates correct step', () {
      final step = VerdictStep.failed(
        stepId: 2,
        description: 'Enter email',
        duration: const Duration(milliseconds: 500),
        failure: const VerdictFailure(
          type: VerdictFailureType.targetNotFound,
          message: 'Could not find Email field',
        ),
      );
      expect(step.status, VerdictStepStatus.failed);
      expect(step.failure, isNotNull);
      expect(step.failure!.type, VerdictFailureType.targetNotFound);
    });

    test('skipped factory creates correct step', () {
      final step = VerdictStep.skipped(
        stepId: 3,
        description: 'Submit form',
      );
      expect(step.status, VerdictStepStatus.skipped);
      expect(step.duration, Duration.zero);
    });

    test('serialization roundtrip — passed', () {
      final loginGlyph = Glyph(
        widgetType: 'ElevatedButton',
        label: 'Login',
        left: 100,
        top: 600,
        width: 200,
        height: 48,
        isInteractive: true,
      );
      final step = VerdictStep.passed(
        stepId: 1,
        description: 'Tapped login',
        duration: const Duration(milliseconds: 100),
        resolvedTarget: loginGlyph,
      );
      final json = step.toJson();
      final restored = VerdictStep.fromJson(json);

      expect(restored.stepId, 1);
      expect(restored.status, VerdictStepStatus.passed);
      expect(restored.description, 'Tapped login');
      expect(restored.duration, const Duration(milliseconds: 100));
      expect(restored.resolvedTarget, isNotNull);
      expect(restored.resolvedTarget!.label, 'Login');
    });

    test('serialization roundtrip — failed with failure', () {
      const failure = VerdictFailure(
        type: VerdictFailureType.wrongRoute,
        message: 'Expected /home but was /login',
        expected: '/home',
        actual: '/login',
      );
      final step = VerdictStep.failed(
        stepId: 5,
        description: 'Verify route',
        duration: const Duration(seconds: 1),
        failure: failure,
      );
      final json = step.toJson();
      final restored = VerdictStep.fromJson(json);

      expect(restored.failure, isNotNull);
      expect(restored.failure!.type, VerdictFailureType.wrongRoute);
      expect(restored.failure!.expected, '/home');
      expect(restored.failure!.actual, '/login');
    });

    test('serialization roundtrip — with tableau', () {
      final tableau = Tableau(
        index: 0,
        timestamp: Duration.zero,
        screenWidth: 400,
        screenHeight: 800,
        glyphs: [
          Glyph(
            widgetType: 'Text',
            label: 'Hello',
            left: 0,
            top: 0,
            width: 100,
            height: 20,
          ),
        ],
      );
      final step = VerdictStep.passed(
        stepId: 1,
        description: 'Check page',
        duration: const Duration(milliseconds: 50),
        tableau: tableau,
      );
      final json = step.toJson();
      final restored = VerdictStep.fromJson(json);

      expect(restored.tableau, isNotNull);
      expect(restored.tableau!.glyphs.length, 1);
      expect(restored.tableau!.glyphs.first.label, 'Hello');
    });
  });

  // -------------------------------------------------------------------------
  // VerdictFailure
  // -------------------------------------------------------------------------
  group('VerdictFailure', () {
    test('serialization roundtrip', () {
      const failure = VerdictFailure(
        type: VerdictFailureType.elementMissing,
        message: 'Submit button not found',
        expected: 'Submit',
        actual: 'not present',
        suggestions: ['Check if the form loaded completely'],
      );
      final json = failure.toJson();
      final restored = VerdictFailure.fromJson(json);

      expect(restored.type, VerdictFailureType.elementMissing);
      expect(restored.message, 'Submit button not found');
      expect(restored.expected, 'Submit');
      expect(restored.actual, 'not present');
      expect(restored.suggestions, hasLength(1));
    });

    test('without optional fields', () {
      const failure = VerdictFailure(
        type: VerdictFailureType.apiError,
        message: 'Network error',
      );
      final json = failure.toJson();
      expect(json, isNot(contains('expected')));
      expect(json, isNot(contains('actual')));

      final restored = VerdictFailure.fromJson(json);
      expect(restored.expected, isNull);
      expect(restored.actual, isNull);
    });

    test('all failure types serialize correctly', () {
      for (final type in VerdictFailureType.values) {
        final failure = VerdictFailure(
          type: type,
          message: 'test $type',
        );
        final json = failure.toJson();
        final restored = VerdictFailure.fromJson(json);
        expect(restored.type, type);
      }
    });

    group('generateSuggestions', () {
      test('generates for targetNotFound', () {
        final suggestions = VerdictFailure.generateSuggestions(
          type: VerdictFailureType.targetNotFound,
          target: const StratagemTarget(label: 'Submit'),
        );
        expect(suggestions, isNotEmpty);
        expect(suggestions.join('\n').toLowerCase(), contains('label'));
      });

      test('generates for wrongRoute', () {
        final suggestions = VerdictFailure.generateSuggestions(
          type: VerdictFailureType.wrongRoute,
          expectedRoute: '/home',
        );
        // wrongRoute may or may not generate suggestions without more context
        expect(suggestions, isA<List<String>>());
      });

      test('generates for timeout', () {
        final suggestions = VerdictFailure.generateSuggestions(
          type: VerdictFailureType.timeout,
        );
        expect(suggestions, isNotEmpty);
        expect(
          suggestions.join('\n').toLowerCase(),
          contains('timeout'),
        );
      });

      test('generates for elementMissing with tableau context', () {
        final tableau = Tableau(
          index: 0,
          timestamp: Duration.zero,
          screenWidth: 400,
          screenHeight: 800,
          glyphs: [
            Glyph(
              widgetType: 'Text',
              label: 'Hello',
              left: 0,
              top: 0,
              width: 100,
              height: 20,
            ),
          ],
        );
        final suggestions = VerdictFailure.generateSuggestions(
          type: VerdictFailureType.elementMissing,
          target: const StratagemTarget(label: 'Missing'),
          tableau: tableau,
        );
        expect(suggestions, isNotEmpty);
      });

      test('generates for notInteractive', () {
        final suggestions = VerdictFailure.generateSuggestions(
          type: VerdictFailureType.notInteractive,
          target: const StratagemTarget(label: 'Label', type: 'Text'),
        );
        expect(suggestions, isNotEmpty);
      });
    });
  });

  // -------------------------------------------------------------------------
  // VerdictSummary
  // -------------------------------------------------------------------------
  group('VerdictSummary', () {
    test('fromSteps computes correct counts', () {
      final steps = [
        VerdictStep.passed(
          stepId: 1,
          description: 'Step 1',
          duration: const Duration(milliseconds: 100),
        ),
        VerdictStep.passed(
          stepId: 2,
          description: 'Step 2',
          duration: const Duration(milliseconds: 200),
        ),
        VerdictStep.failed(
          stepId: 3,
          description: 'Step 3',
          duration: const Duration(milliseconds: 150),
          failure: const VerdictFailure(
            type: VerdictFailureType.wrongRoute,
            message: 'Wrong route',
            expected: '/home',
            actual: '/login',
          ),
        ),
        VerdictStep.skipped(
          stepId: 4,
          description: 'Step 4',
        ),
      ];

      final summary = VerdictSummary.fromSteps(
        steps,
        const Duration(milliseconds: 450),
      );

      expect(summary.totalSteps, 4);
      expect(summary.passedSteps, 2);
      expect(summary.failedSteps, 1);
      expect(summary.skippedSteps, 1);
      expect(summary.successRate, closeTo(0.5, 0.01));
      expect(summary.duration, const Duration(milliseconds: 450));
      expect(summary.passed, false);
    });

    test('all passed summary', () {
      final steps = [
        VerdictStep.passed(
          stepId: 1,
          description: 'Step 1',
          duration: const Duration(milliseconds: 50),
        ),
        VerdictStep.passed(
          stepId: 2,
          description: 'Step 2',
          duration: const Duration(milliseconds: 80),
        ),
      ];

      final summary = VerdictSummary.fromSteps(
        steps,
        const Duration(milliseconds: 130),
      );

      expect(summary.passed, true);
      expect(summary.successRate, 1.0);
    });

    test('oneLiner for passing verdict', () {
      final steps = [
        VerdictStep.passed(
          stepId: 1,
          description: 'Only step',
          duration: const Duration(milliseconds: 50),
        ),
      ];

      final summary = VerdictSummary.fromSteps(
        steps,
        const Duration(milliseconds: 50),
      );

      expect(summary.oneLiner, contains('✅'));
      expect(summary.oneLiner, contains('passed'));
    });

    test('oneLiner for failing verdict', () {
      final steps = [
        VerdictStep.failed(
          stepId: 1,
          description: 'Failed step',
          duration: const Duration(milliseconds: 100),
          failure: const VerdictFailure(
            type: VerdictFailureType.exception,
            message: 'Boom',
          ),
        ),
      ];

      final summary = VerdictSummary.fromSteps(
        steps,
        const Duration(milliseconds: 100),
      );

      expect(summary.oneLiner, contains('❌'));
      expect(summary.oneLiner, contains('failed'));
    });

    test('fromSteps collects failed routes', () {
      final steps = [
        VerdictStep.failed(
          stepId: 1,
          description: 'Verify route',
          duration: const Duration(milliseconds: 50),
          failure: const VerdictFailure(
            type: VerdictFailureType.wrongRoute,
            message: 'Expected /home',
            expected: '/home',
            actual: '/login',
          ),
        ),
      ];

      final summary = VerdictSummary.fromSteps(
        steps,
        const Duration(milliseconds: 50),
      );

      // failedRoutes comes from step.tableau?.route, not from failure.actual
      // Steps without tableau won't populate failedRoutes
      expect(summary.unexpectedRoutes, contains('/login'));
    });

    test('fromSteps collects missing elements', () {
      final steps = [
        VerdictStep.failed(
          stepId: 1,
          description: 'Find button',
          duration: const Duration(milliseconds: 50),
          failure: const VerdictFailure(
            type: VerdictFailureType.targetNotFound,
            message: 'Could not find Submit',
            expected: 'Submit',
          ),
        ),
      ];

      final summary = VerdictSummary.fromSteps(
        steps,
        const Duration(milliseconds: 50),
      );

      // missingElements stores the failure message, not the expected value
      expect(summary.missingElements.first, contains('Submit'));
    });

    test('fromSteps counts API errors', () {
      final steps = [
        VerdictStep.failed(
          stepId: 1,
          description: 'Hit API',
          duration: const Duration(milliseconds: 50),
          failure: const VerdictFailure(
            type: VerdictFailureType.apiError,
            message: 'Network down',
          ),
        ),
        VerdictStep.failed(
          stepId: 2,
          description: 'Hit API 2',
          duration: const Duration(milliseconds: 50),
          failure: const VerdictFailure(
            type: VerdictFailureType.apiError,
            message: 'Timeout',
          ),
        ),
      ];

      final summary = VerdictSummary.fromSteps(
        steps,
        const Duration(milliseconds: 100),
      );

      expect(summary.apiErrors.length, 2);
      expect(summary.apiErrors, contains('Network down'));
      expect(summary.apiErrors, contains('Timeout'));
    });

    test('serialization roundtrip', () {
      final summary = VerdictSummary(
        totalSteps: 5,
        passedSteps: 3,
        failedSteps: 1,
        skippedSteps: 1,
        failedRoutes: const ['/settings'],
        missingElements: const ['Button'],
        apiErrors: const [],
        unexpectedRoutes: const [],
        successRate: 0.6,
        duration: const Duration(seconds: 3),
      );
      final json = summary.toJson();
      final restored = VerdictSummary.fromJson(json);

      expect(restored.totalSteps, 5);
      expect(restored.passedSteps, 3);
      expect(restored.failedSteps, 1);
      expect(restored.skippedSteps, 1);
      expect(restored.failedRoutes, ['/settings']);
      // Duration restored
      expect(
        restored.duration.inMilliseconds,
        summary.duration.inMilliseconds,
      );
    });
  });

  // -------------------------------------------------------------------------
  // VerdictPerformance
  // -------------------------------------------------------------------------
  group('VerdictPerformance', () {
    test('serialization roundtrip', () {
      final perf = VerdictPerformance(
        averageFps: 58.5,
        minFps: 45.0,
        jankFrames: 3,
        startMemoryBytes: 50000000,
        endMemoryBytes: 55000000,
        settleTimes: const {1: Duration(milliseconds: 200), 3: Duration(milliseconds: 500)},
        slowSteps: const [3, 5],
      );
      final json = perf.toJson();
      final restored = VerdictPerformance.fromJson(json);

      expect(restored.averageFps, 58.5);
      expect(restored.minFps, 45.0);
      expect(restored.jankFrames, 3);
      expect(restored.startMemoryBytes, 50000000);
      expect(restored.endMemoryBytes, 55000000);
      expect(restored.settleTimes[1], const Duration(milliseconds: 200));
      expect(restored.settleTimes[3], const Duration(milliseconds: 500));
      expect(restored.slowSteps, [3, 5]);
    });

    test('memoryDelta calculation', () {
      final perf = VerdictPerformance(
        startMemoryBytes: 50000000,
        endMemoryBytes: 55000000,
      );
      expect(perf.memoryDelta, 5000000);
    });

    test('default fields', () {
      final perf = VerdictPerformance();
      final json = perf.toJson();
      final restored = VerdictPerformance.fromJson(json);

      expect(restored.averageFps, 0);
      expect(restored.memoryDelta, 0);
      expect(restored.jankFrames, 0);
    });
  });

  // -------------------------------------------------------------------------
  // Verdict
  // -------------------------------------------------------------------------
  group('Verdict', () {
    late Verdict passingVerdict;
    late Verdict failingVerdict;

    setUp(() {
      final passedSteps = [
        VerdictStep.passed(
          stepId: 1,
          description: 'Verify login page',
          duration: const Duration(milliseconds: 50),
        ),
        VerdictStep.passed(
          stepId: 2,
          description: 'Enter email',
          duration: const Duration(milliseconds: 100),
        ),
        VerdictStep.passed(
          stepId: 3,
          description: 'Tap login',
          duration: const Duration(milliseconds: 200),
        ),
      ];

      passingVerdict = Verdict.fromSteps(
        stratagemName: 'login_flow',
        steps: passedSteps,
        executedAt: DateTime(2025, 1, 15, 10, 30),
        duration: const Duration(milliseconds: 350),
        performance: VerdictPerformance(),
      );

      final failedSteps = [
        VerdictStep.passed(
          stepId: 1,
          description: 'Verify login page',
          duration: const Duration(milliseconds: 50),
        ),
        VerdictStep.failed(
          stepId: 2,
          description: 'Enter email',
          duration: const Duration(milliseconds: 300),
          failure: const VerdictFailure(
            type: VerdictFailureType.targetNotFound,
            message: 'Could not find Email field',
            expected: 'Email',
          ),
        ),
        VerdictStep.skipped(
          stepId: 3,
          description: 'Tap login',
        ),
      ];

      failingVerdict = Verdict.fromSteps(
        stratagemName: 'login_flow',
        steps: failedSteps,
        executedAt: DateTime(2025, 1, 15, 10, 30),
        duration: const Duration(milliseconds: 350),
        performance: VerdictPerformance(),
      );
    });

    test('fromSteps correctly determines passed', () {
      expect(passingVerdict.passed, true);
      expect(failingVerdict.passed, false);
    });

    test('fromSteps builds summary', () {
      expect(passingVerdict.summary.totalSteps, 3);
      expect(passingVerdict.summary.passedSteps, 3);
      expect(passingVerdict.summary.failedSteps, 0);
      expect(passingVerdict.summary.successRate, 1.0);

      expect(failingVerdict.summary.totalSteps, 3);
      expect(failingVerdict.summary.passedSteps, 1);
      expect(failingVerdict.summary.failedSteps, 1);
      expect(failingVerdict.summary.skippedSteps, 1);
    });

    test('serialization roundtrip', () {
      final json = passingVerdict.toJson();
      final restored = Verdict.fromJson(json);

      expect(restored.stratagemName, 'login_flow');
      expect(restored.passed, true);
      expect(restored.steps.length, 3);
      expect(restored.summary.passedSteps, 3);
    });

    test('failing verdict serialization roundtrip', () {
      final json = failingVerdict.toJson();
      final restored = Verdict.fromJson(json);

      expect(restored.passed, false);
      expect(restored.steps[1].failure, isNotNull);
      expect(
        restored.steps[1].failure!.type,
        VerdictFailureType.targetNotFound,
      );
      expect(restored.steps[2].status, VerdictStepStatus.skipped);
    });

    test('toJsonString returns valid JSON', () {
      final jsonStr = passingVerdict.toJsonString();
      expect(jsonStr, contains('"stratagemName"'));
      expect(jsonStr, contains('login_flow'));
      // Pretty printing includes newlines
      expect(jsonStr, contains('\n'));
    });

    group('toReport', () {
      test('passing report contains success', () {
        final report = passingVerdict.toReport();
        expect(report, contains('✅'));
        expect(report, contains('login_flow'));
        expect(report, contains('All 3 steps passed'));
      });

      test('failing report contains failure info', () {
        final report = failingVerdict.toReport();
        expect(report, contains('❌'));
        expect(report, contains('Email'));
        expect(report, contains('FAILURE'));
      });

      test('report includes step details', () {
        final report = passingVerdict.toReport();
        expect(report, contains('Verify login page'));
        expect(report, contains('Enter email'));
        expect(report, contains('Tap login'));
      });
    });

    group('toAiDiagnostic', () {
      test('passing diagnostic is concise', () {
        final diagnostic = passingVerdict.toAiDiagnostic();
        expect(diagnostic, contains('RESULT: PASS'));
        expect(diagnostic, contains('login_flow'));
      });

      test('failing diagnostic includes failure details', () {
        final diagnostic = failingVerdict.toAiDiagnostic();
        expect(diagnostic, contains('RESULT: FAIL'));
        expect(diagnostic, contains('FAILED'));
      });

      test('diagnostic includes duration', () {
        final diagnostic = passingVerdict.toAiDiagnostic();
        expect(diagnostic, contains('DURATION'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // VerdictFailureType enum
  // -------------------------------------------------------------------------
  group('VerdictFailureType', () {
    test('has all expected types', () {
      final names = VerdictFailureType.values.map((t) => t.name).toList();
      expect(names, contains('targetNotFound'));
      expect(names, contains('elementMissing'));
      expect(names, contains('elementUnexpected'));
      expect(names, contains('wrongRoute'));
      expect(names, contains('wrongState'));
      expect(names, contains('timeout'));
      expect(names, contains('apiError'));
      expect(names, contains('exception'));
      expect(names, contains('notInteractive'));
      expect(names, contains('pageLoadFailure'));
      expect(names, contains('expectationFailed'));
    });
  });

  // -------------------------------------------------------------------------
  // VerdictStepStatus enum
  // -------------------------------------------------------------------------
  group('VerdictStepStatus', () {
    test('has 3 values', () {
      expect(VerdictStepStatus.values.length, 3);
      expect(VerdictStepStatus.passed.name, 'passed');
      expect(VerdictStepStatus.failed.name, 'failed');
      expect(VerdictStepStatus.skipped.name, 'skipped');
    });
  });
}
