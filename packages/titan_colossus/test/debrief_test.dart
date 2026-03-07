import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Verdict makeVerdict(
    String name, {
    bool passed = true,
    List<VerdictStep> steps = const [],
  }) {
    return Verdict(
      stratagemName: name,
      executedAt: DateTime(2025, 1, 1),
      duration: const Duration(seconds: 1),
      passed: passed,
      steps: steps,
      summary: VerdictSummary(
        totalSteps: steps.length,
        passedSteps: steps.where((s) => s.status == VerdictStepStatus.passed).length,
        failedSteps: steps.where((s) => s.status == VerdictStepStatus.failed).length,
        skippedSteps: 0,
        successRate: passed ? 1.0 : 0.0,
        duration: const Duration(seconds: 1),
      ),
      performance: const VerdictPerformance(),
    );
  }

  VerdictStep failedStep({
    int stepId = 1,
    required VerdictFailureType type,
    String message = 'test failure',
    String? expected,
    String? actual,
    List<String> suggestions = const [],
    Tableau? tableau,
  }) {
    return VerdictStep(
      stepId: stepId,
      description: 'step $stepId',
      status: VerdictStepStatus.failed,
      duration: const Duration(milliseconds: 500),
      failure: VerdictFailure(
        type: type,
        message: message,
        expected: expected,
        actual: actual,
        suggestions: suggestions,
      ),
      tableau: tableau,
    );
  }

  VerdictStep passedStep({int stepId = 1}) {
    return VerdictStep.passed(
      stepId: stepId,
      description: 'step $stepId',
      duration: const Duration(milliseconds: 100),
    );
  }

  Terrain makeTerrain() => Terrain();

  /// Creates an isolated Scout–Terrain pair for test isolation.
  (Terrain, Scout) makeScoutPair() {
    final terrain = Terrain();
    return (terrain, Scout.withTerrain(terrain));
  }

  // =========================================================================
  // InsightType
  // =========================================================================

  group('InsightType', () {
    test('has 7 values', () {
      expect(InsightType.values, hasLength(7));
    });

    test('includes all expected types', () {
      expect(InsightType.values.map((v) => v.name), containsAll([
        'elementNotFound',
        'unexpectedNavigation',
        'missingPrerequisite',
        'wrongScreen',
        'performanceIssue',
        'stateCorruption',
        'general',
      ]));
    });
  });

  // =========================================================================
  // DebriefInsight
  // =========================================================================

  group('DebriefInsight', () {
    test('creates with required fields', () {
      const insight = DebriefInsight(
        type: InsightType.elementNotFound,
        message: 'Button not found',
        suggestion: 'Check label',
      );
      expect(insight.type, InsightType.elementNotFound);
      expect(insight.message, 'Button not found');
      expect(insight.actionable, false);
      expect(insight.fixSuggestion, isNull);
    });

    test('toJson includes all fields', () {
      const insight = DebriefInsight(
        type: InsightType.elementNotFound,
        message: 'Button not found',
        suggestion: 'Update label',
        actionable: true,
        fixSuggestion: 'Change to "Submit"',
      );

      final json = insight.toJson();
      expect(json['type'], 'elementNotFound');
      expect(json['message'], 'Button not found');
      expect(json['suggestion'], 'Update label');
      expect(json['actionable'], true);
      expect(json['fixSuggestion'], 'Change to "Submit"');
    });

    test('toJson omits null fixSuggestion', () {
      const insight = DebriefInsight(
        type: InsightType.general,
        message: 'test',
        suggestion: 'test',
      );
      expect(insight.toJson().containsKey('fixSuggestion'), false);
    });

    test('fromJson round-trip', () {
      const original = DebriefInsight(
        type: InsightType.performanceIssue,
        message: 'Slow step',
        suggestion: 'Increase timeout',
        actionable: true,
        fixSuggestion: 'Set to 5000ms',
      );

      final restored = DebriefInsight.fromJson(original.toJson());
      expect(restored.type, InsightType.performanceIssue);
      expect(restored.message, 'Slow step');
      expect(restored.suggestion, 'Increase timeout');
      expect(restored.actionable, true);
      expect(restored.fixSuggestion, 'Set to 5000ms');
    });

    test('fromJson with unknown type defaults to general', () {
      final json = {
        'type': 'futuristic_type',
        'message': 'test',
        'suggestion': 'test',
      };
      final insight = DebriefInsight.fromJson(json);
      expect(insight.type, InsightType.general);
    });

    test('toString includes type and message', () {
      const insight = DebriefInsight(
        type: InsightType.wrongScreen,
        message: 'Wrong screen detected',
        suggestion: 'Fix route',
      );
      expect(insight.toString(), contains('wrongScreen'));
      expect(insight.toString(), contains('Wrong screen'));
    });
  });

  // =========================================================================
  // DebriefReport
  // =========================================================================

  group('DebriefReport', () {
    test('computed properties', () {
      final report = DebriefReport(
        verdicts: [
          makeVerdict('a'),
          makeVerdict('b', passed: false),
          makeVerdict('c'),
        ],
        insights: const [],
        terrainUpdates: '',
        suggestedNextActions: const [],
      );

      expect(report.totalVerdicts, 3);
      expect(report.passedVerdicts, 2);
      expect(report.failedVerdicts, 1);
      expect(report.passRate, closeTo(0.666, 0.01));
      expect(report.allPassed, false);
    });

    test('passRate 1.0 for empty', () {
      final report = DebriefReport(
        verdicts: const [],
        insights: const [],
        terrainUpdates: '',
        suggestedNextActions: const [],
      );
      expect(report.passRate, 1.0);
      expect(report.allPassed, true);
    });

    test('allPassed true when all pass', () {
      final report = DebriefReport(
        verdicts: [makeVerdict('a'), makeVerdict('b')],
        insights: const [],
        terrainUpdates: '',
        suggestedNextActions: const [],
      );
      expect(report.allPassed, true);
    });

    test('toAiSummary contains key sections', () {
      final report = DebriefReport(
        verdicts: [makeVerdict('a')],
        insights: const [
          DebriefInsight(
            type: InsightType.elementNotFound,
            message: 'Button missing',
            suggestion: 'Update labels',
            fixSuggestion: 'Change label',
          ),
        ],
        terrainUpdates: '2 new screens discovered.',
        suggestedNextActions: ['UPDATE: Refresh targets'],
      );

      final summary = report.toAiSummary();
      expect(summary, contains('DEBRIEF REPORT'));
      expect(summary, contains('VERDICTS: 1'));
      expect(summary, contains('PASSED: 1/1'));
      expect(summary, contains('INSIGHTS: 1'));
      expect(summary, contains('ELEMENTNOTFOUND'));
      expect(summary, contains('Button missing'));
      expect(summary, contains('FIX: Change label'));
      expect(summary, contains('TERRAIN UPDATES:'));
      expect(summary, contains('2 new screens'));
      expect(summary, contains('SUGGESTED NEXT ACTIONS:'));
      expect(summary, contains('UPDATE: Refresh targets'));
    });

    test('toAiSummary omits empty terrain updates', () {
      final report = DebriefReport(
        verdicts: const [],
        insights: const [],
        terrainUpdates: '',
        suggestedNextActions: const [],
      );

      final summary = report.toAiSummary();
      expect(summary, isNot(contains('TERRAIN UPDATES:')));
    });

    test('toJson contains all fields', () {
      final report = DebriefReport(
        verdicts: [makeVerdict('a')],
        insights: const [
          DebriefInsight(
            type: InsightType.general,
            message: 'test',
            suggestion: 'test',
          ),
        ],
        terrainUpdates: 'Updates',
        suggestedNextActions: ['Action 1'],
      );

      final json = report.toJson();
      expect(json['totalVerdicts'], 1);
      expect(json['passedVerdicts'], 1);
      expect(json['failedVerdicts'], 0);
      expect(json['passRate'], 1.0);
      expect(json['insights'], hasLength(1));
      expect(json['terrainUpdates'], 'Updates');
      expect(json['suggestedNextActions'], ['Action 1']);
    });

    test('toString', () {
      final report = DebriefReport(
        verdicts: [makeVerdict('a')],
        insights: const [],
        terrainUpdates: '',
        suggestedNextActions: const [],
      );
      expect(report.toString(), contains('1 verdicts'));
      expect(report.toString(), contains('100.0%'));
    });
  });

  // =========================================================================
  // Debrief — Failure Analysis
  // =========================================================================

  group('Debrief failure analysis', () {
    test('targetNotFound → elementNotFound insight', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            type: VerdictFailureType.targetNotFound,
            message: 'Login button',
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final insight = report.insights.firstWhere(
        (i) => i.type == InsightType.elementNotFound,
      );
      expect(insight.message, contains('target not found'));
      expect(insight.actionable, true);
      expect(insight.fixSuggestion, isNotNull);
    });

    test('targetNotFound with visible elements in message', () {
      final tableau = Tableau(
        index: 0,
        timestamp: const Duration(seconds: 1),
        route: '/login',
        glyphs: [
          Glyph(
            widgetType: 'ElevatedButton',
            label: 'Sign In',
            isInteractive: true,
            interactionType: 'tap',
            isEnabled: true,
            left: 50,
            top: 150,
            width: 100,
            height: 100,
          ),
        ],
        screenWidth: 400,
        screenHeight: 800,
      );

      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            type: VerdictFailureType.targetNotFound,
            tableau: tableau,
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final insight = report.insights.firstWhere(
        (i) => i.type == InsightType.elementNotFound,
      );
      expect(insight.suggestion, contains('Sign In'));
    });

    test('wrongRoute → unexpectedNavigation insight', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            type: VerdictFailureType.wrongRoute,
            expected: '/dashboard',
            actual: '/login',
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final insight = report.insights.firstWhere(
        (i) => i.type == InsightType.unexpectedNavigation,
      );
      expect(insight.suggestion, contains('/dashboard'));
      expect(insight.suggestion, contains('/login'));
      expect(insight.actionable, true);
    });

    test('timeout → performanceIssue insight', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            type: VerdictFailureType.timeout,
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final insight = report.insights.firstWhere(
        (i) => i.type == InsightType.performanceIssue,
      );
      expect(insight.message, contains('timed out'));
      expect(insight.actionable, true);
      expect(insight.fixSuggestion, contains('ms'));
    });

    test('wrongState → stateCorruption insight', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            type: VerdictFailureType.wrongState,
            message: 'expected checked',
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final insight = report.insights.firstWhere(
        (i) => i.type == InsightType.stateCorruption,
      );
      expect(insight.suggestion, contains('expected checked'));
      expect(insight.actionable, false);
    });

    test('other failure type → general insight', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            type: VerdictFailureType.exception,
            message: 'null pointer',
            suggestions: ['Add null check'],
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final insight = report.insights.firstWhere(
        (i) => i.type == InsightType.general,
      );
      expect(insight.message, contains('null pointer'));
      expect(insight.suggestion, contains('Add null check'));
      expect(insight.fixSuggestion, 'Add null check');
    });

    test('general insight without suggestions', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            type: VerdictFailureType.apiError,
            message: 'network error',
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final insight = report.insights.firstWhere(
        (i) => i.type == InsightType.general,
      );
      expect(insight.suggestion, contains('Investigate'));
    });

    test('passing verdicts produce no failure insights', () {
      final verdict = makeVerdict('test', steps: [passedStep()]);

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      // Should have no failure insights (only patterns/actions)
      final failureInsights = report.insights.where(
        (i) => i.type != InsightType.missingPrerequisite &&
            i.type != InsightType.wrongScreen,
      );
      expect(failureInsights, isEmpty);
    });
  });

  // =========================================================================
  // Debrief — Pattern Detection
  // =========================================================================

  group('Debrief pattern detection', () {
    test('missing prerequisite when first failure is wrongRoute', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            stepId: 1,
            type: VerdictFailureType.wrongRoute,
          ),
          failedStep(
            stepId: 2,
            type: VerdictFailureType.targetNotFound,
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final prereqInsight = report.insights.firstWhere(
        (i) => i.type == InsightType.missingPrerequisite,
      );
      expect(prereqInsight.message, contains('route mismatch'));
      expect(prereqInsight.message, contains('cascading'));
      expect(prereqInsight.actionable, true);
    });

    test('no prerequisite pattern when first failure is not wrongRoute', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(
            stepId: 1,
            type: VerdictFailureType.targetNotFound,
          ),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final prereqs = report.insights.where(
        (i) => i.type == InsightType.missingPrerequisite,
      );
      expect(prereqs, isEmpty);
    });

    test('wrong screen when 3+ targetNotFound', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(stepId: 1, type: VerdictFailureType.targetNotFound),
          failedStep(stepId: 2, type: VerdictFailureType.targetNotFound),
          failedStep(stepId: 3, type: VerdictFailureType.targetNotFound),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final wrongScreen = report.insights.firstWhere(
        (i) => i.type == InsightType.wrongScreen,
      );
      expect(wrongScreen.message, contains('3'));
      expect(wrongScreen.message, contains('wrong screen'));
    });

    test('no wrong screen with fewer than 3 targetNotFound', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(stepId: 1, type: VerdictFailureType.targetNotFound),
          failedStep(stepId: 2, type: VerdictFailureType.targetNotFound),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      final wrongScreens = report.insights.where(
        (i) => i.type == InsightType.wrongScreen,
      );
      expect(wrongScreens, isEmpty);
    });

    test('both patterns detected when applicable', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(stepId: 1, type: VerdictFailureType.wrongRoute),
          failedStep(stepId: 2, type: VerdictFailureType.targetNotFound),
          failedStep(stepId: 3, type: VerdictFailureType.targetNotFound),
          failedStep(stepId: 4, type: VerdictFailureType.targetNotFound),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(
        report.insights.any((i) => i.type == InsightType.missingPrerequisite),
        true,
      );
      expect(
        report.insights.any((i) => i.type == InsightType.wrongScreen),
        true,
      );
    });
  });

  // =========================================================================
  // Debrief — Suggested Next Actions
  // =========================================================================

  group('Debrief suggested next actions', () {
    test('all passed → EXPAND suggestion', () {
      final verdict = makeVerdict('test', steps: [passedStep()]);

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(report.suggestedNextActions.length, 1);
      expect(report.suggestedNextActions.first, contains('EXPAND'));
    });

    test('missing prerequisite → RESOLVE action', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(type: VerdictFailureType.wrongRoute),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(
        report.suggestedNextActions.any((a) => a.contains('RESOLVE')),
        true,
      );
    });

    test('element not found → UPDATE action', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(type: VerdictFailureType.targetNotFound),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(
        report.suggestedNextActions.any((a) => a.contains('UPDATE')),
        true,
      );
    });

    test('timeout → TUNE action', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(type: VerdictFailureType.timeout),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(
        report.suggestedNextActions.any((a) => a.contains('TUNE')),
        true,
      );
    });

    test('state corruption → INVESTIGATE action', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(type: VerdictFailureType.wrongState),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(
        report.suggestedNextActions.any((a) => a.contains('INVESTIGATE')),
        true,
      );
    });

    test('multiple failure types → multiple actions', () {
      final verdict = makeVerdict(
        'test',
        passed: false,
        steps: [
          failedStep(stepId: 1, type: VerdictFailureType.targetNotFound),
          failedStep(stepId: 2, type: VerdictFailureType.timeout),
        ],
      );

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(report.suggestedNextActions.length, greaterThanOrEqualTo(2));
    });
  });

  // =========================================================================
  // Debrief — Terrain Updates
  // =========================================================================

  group('Debrief terrain updates', () {
    test('no updates when no new discoveries', () {
      final verdict = makeVerdict('test', steps: [passedStep()]);

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(report.terrainUpdates, contains('No new'));
    });

    test('reports new screens discovered', () {
      // Verdict with tableaux that will create new outposts
      final verdict = Verdict(
        stratagemName: 'discovery',
        executedAt: DateTime(2025),
        duration: const Duration(seconds: 1),
        passed: true,
        steps: const [],
        tableaux: [
          Tableau(
            index: 0,
            timestamp: const Duration(seconds: 1),
            route: '/new-screen',
            glyphs: [
              Glyph(
                widgetType: 'Text',
                label: 'Hello',
                isInteractive: false,
                isEnabled: true,
                left: 0,
                top: 0,
                width: 100,
                height: 50,
              ),
            ],
            screenWidth: 400,
            screenHeight: 800,
          ),
        ],
        summary: const VerdictSummary(
          totalSteps: 0,
          passedSteps: 0,
          failedSteps: 0,
          skippedSteps: 0,
          successRate: 1.0,
          duration: Duration(seconds: 1),
        ),
        performance: const VerdictPerformance(),
      );

      final terrain = Terrain();
      final scout = Scout.withTerrain(terrain);

      final debrief = Debrief(
        verdicts: [verdict],
        terrain: terrain,
        scout: scout,
      );

      final report = debrief.analyze();
      expect(report.terrainUpdates, contains('new screen'));
    });
  });

  // =========================================================================
  // Debrief — Multiple Verdicts
  // =========================================================================

  group('Debrief multiple verdicts', () {
    test('analyzes all verdicts', () {
      final verdicts = [
        makeVerdict('test1', passed: false, steps: [
          failedStep(type: VerdictFailureType.targetNotFound),
        ]),
        makeVerdict('test2', passed: false, steps: [
          failedStep(type: VerdictFailureType.timeout),
        ]),
        makeVerdict('test3'),
      ];

      final debrief = Debrief(
        verdicts: verdicts,
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(report.totalVerdicts, 3);
      expect(report.passedVerdicts, 1);
      expect(report.failedVerdicts, 2);
      expect(report.insights.length, greaterThanOrEqualTo(2));
    });

    test('empty verdicts produces clean report', () {
      final debrief = Debrief(
        verdicts: const [],
        terrain: makeTerrain(),
        scout: Scout.withTerrain(Terrain()),
      );

      final report = debrief.analyze();
      expect(report.totalVerdicts, 0);
      expect(report.insights, isEmpty);
      expect(report.suggestedNextActions, hasLength(1));
      expect(report.suggestedNextActions.first, contains('EXPAND'));
    });
  });

  // =========================================================================
  // DebriefReport JSON
  // =========================================================================

  group('DebriefReport serialization', () {
    test('fromJson round-trip', () {
      final report = DebriefReport(
        verdicts: [makeVerdict('a')],
        insights: const [
          DebriefInsight(
            type: InsightType.elementNotFound,
            message: 'Missing button',
            suggestion: 'Update label',
            actionable: true,
          ),
        ],
        terrainUpdates: '1 new screen.',
        suggestedNextActions: ['UPDATE: Refresh'],
      );

      final json = report.toJson();
      final restored = DebriefReport.fromJson(json, [makeVerdict('a')]);

      expect(restored.insights, hasLength(1));
      expect(restored.insights.first.type, InsightType.elementNotFound);
      expect(restored.terrainUpdates, '1 new screen.');
      expect(restored.suggestedNextActions, ['UPDATE: Refresh']);
    });
  });
}
