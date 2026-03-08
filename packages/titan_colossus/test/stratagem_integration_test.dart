import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/testing/stratagem.dart';
import 'package:titan_colossus/src/testing/verdict.dart';

void main() {
  // -------------------------------------------------------------------------
  // Integration: Stratagem JSON → Parse → Verdict pipeline
  // -------------------------------------------------------------------------
  group('Stratagem → Verdict pipeline', () {
    test('parse Stratagem JSON template', () {
      // The template itself should be parseable
      final template = Stratagem.template;
      expect(template, isA<Map<String, dynamic>>());
      expect(template[r'$schema'], 'titan://stratagem/v1');
      expect(template['name'], isNotNull);
      expect(template['steps'], isA<List>());
    });

    test('full JSON roundtrip — complex Stratagem', () {
      const json = '''
      {
        "\$schema": "titan://stratagem/v1",
        "name": "login_flow_happy_path",
        "description": "Verify successful login with valid credentials",
        "tags": ["auth", "critical", "smoke"],
        "startRoute": "/login",
        "testData": {
          "email": "admin@example.com",
          "password": "Secret123!"
        },
        "timeout": 60000,
        "failurePolicy": "abortOnFirst",
        "steps": [
          {
            "id": 1,
            "action": "verify",
            "description": "Login page is displayed",
            "expectations": {
              "route": "/login",
              "elementsPresent": [
                {"label": "Email", "type": "TextField"},
                {"label": "Password", "type": "TextField"},
                {"label": "Login", "type": "ElevatedButton"}
              ]
            }
          },
          {
            "id": 2,
            "action": "enterText",
            "description": "Enter email address",
            "target": {"label": "Email", "type": "TextField"},
            "value": "\${testData.email}",
            "clearFirst": true
          },
          {
            "id": 3,
            "action": "enterText",
            "description": "Enter password",
            "target": {"label": "Password", "type": "TextField"},
            "value": "\${testData.password}",
            "clearFirst": true
          },
          {
            "id": 4,
            "action": "tap",
            "description": "Tap login button",
            "target": {"label": "Login", "type": "ElevatedButton"},
            "waitAfter": 3000
          },
          {
            "id": 5,
            "action": "verify",
            "description": "Dashboard is displayed",
            "expectations": {
              "route": "/dashboard",
              "elementsPresent": [
                {"label": "Welcome"}
              ],
              "elementsAbsent": [
                {"label": "Login"}
              ]
            }
          }
        ]
      }
      ''';

      final parsed = Stratagem.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );

      expect(parsed.name, 'login_flow_happy_path');
      expect(parsed.description, contains('login'));
      expect(parsed.tags, contains('critical'));
      expect(parsed.startRoute, '/login');
      expect(parsed.testData?['email'], 'admin@example.com');
      expect(parsed.timeout, const Duration(seconds: 60));
      expect(parsed.failurePolicy, StratagemFailurePolicy.abortOnFirst);
      expect(parsed.steps.length, 5);

      // Step 1: verify
      expect(parsed.steps[0].action, StratagemAction.verify);
      expect(parsed.steps[0].expectations?.route, '/login');
      expect(parsed.steps[0].expectations?.elementsPresent?.length, 3);

      // Step 2: enterText with interpolation
      expect(parsed.steps[1].action, StratagemAction.enterText);
      expect(parsed.steps[1].value, r'${testData.email}');
      expect(parsed.steps[1].clearFirst, true);
      // Interpolation should resolve
      expect(parsed.interpolate(parsed.steps[1].value!), 'admin@example.com');

      // Step 4: tap with waitAfter
      expect(parsed.steps[3].action, StratagemAction.tap);
      expect(parsed.steps[3].waitAfter, const Duration(seconds: 3));

      // Step 5: verify with absent elements
      expect(parsed.steps[4].expectations?.elementsAbsent?.length, 1);

      // JSON roundtrip
      final reserialized = parsed.toJson();
      final reparsed = Stratagem.fromJson(reserialized);
      expect(reparsed.name, parsed.name);
      expect(reparsed.steps.length, parsed.steps.length);
      expect(reparsed.testData, parsed.testData);
    });

    test('Verdict serialization roundtrip with all fields', () {
      final verdict = Verdict.fromSteps(
        stratagemName: 'integration_test',
        executedAt: DateTime(2025, 6, 15, 14, 30),
        duration: const Duration(seconds: 5),
        performance: VerdictPerformance(
          averageFps: 59.8,
          minFps: 42.0,
          jankFrames: 2,
          startMemoryBytes: 50000000,
          endMemoryBytes: 52000000,
          settleTimes: const {
            1: Duration(milliseconds: 150),
            3: Duration(milliseconds: 400),
          },
          slowSteps: const [3],
        ),
        steps: [
          VerdictStep.passed(
            stepId: 1,
            description: 'Verify page',
            duration: const Duration(milliseconds: 100),
          ),
          VerdictStep.passed(
            stepId: 2,
            description: 'Enter text',
            duration: const Duration(milliseconds: 300),
          ),
          VerdictStep.failed(
            stepId: 3,
            description: 'Tap button',
            duration: const Duration(milliseconds: 800),
            failure: VerdictFailure(
              type: VerdictFailureType.targetNotFound,
              message: 'Could not find "Submit" button',
              expected: 'Submit',
              suggestions: VerdictFailure.generateSuggestions(
                type: VerdictFailureType.targetNotFound,
                target: const StratagemTarget(label: 'Submit'),
              ),
            ),
          ),
          VerdictStep.skipped(stepId: 4, description: 'Verify result'),
        ],
      );

      // Verify computed fields
      expect(verdict.passed, false);
      expect(verdict.summary.totalSteps, 4);
      expect(verdict.summary.passedSteps, 2);
      expect(verdict.summary.failedSteps, 1);
      expect(verdict.summary.skippedSteps, 1);
      expect(verdict.summary.successRate, closeTo(0.5, 0.01));

      // Performance
      expect(verdict.performance.averageFps, 59.8);
      expect(verdict.performance.memoryDelta, 2000000);
      expect(verdict.performance.slowSteps, [3]);

      // JSON roundtrip
      final json = verdict.toJson();
      final jsonStr = verdict.toJsonString();
      expect(jsonStr, contains('integration_test'));

      final restored = Verdict.fromJson(json);
      expect(restored.stratagemName, 'integration_test');
      expect(restored.passed, false);
      expect(restored.steps.length, 4);
      expect(
        restored.steps[2].failure?.type,
        VerdictFailureType.targetNotFound,
      );
      expect(restored.performance.averageFps, 59.8);
      expect(
        restored.performance.settleTimes[1],
        const Duration(milliseconds: 150),
      );
    });

    test('Verdict report and diagnostic output', () {
      final verdict = Verdict.fromSteps(
        stratagemName: 'output_test',
        executedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 2),
        performance: VerdictPerformance(jankFrames: 5, minFps: 30),
        steps: [
          VerdictStep.passed(
            stepId: 1,
            description: 'Step one',
            duration: const Duration(milliseconds: 500),
          ),
          VerdictStep.failed(
            stepId: 2,
            description: 'Step two',
            duration: const Duration(milliseconds: 1500),
            failure: const VerdictFailure(
              type: VerdictFailureType.wrongRoute,
              message: 'Expected /home',
              expected: '/home',
              actual: '/error',
            ),
          ),
        ],
      );

      // Human report
      final report = verdict.toReport();
      expect(report, contains('output_test'));
      expect(report, contains('Step one'));
      expect(report, contains('Step two'));
      expect(report, contains('FAILURE'));
      expect(report, contains('/home'));
      expect(report, contains('Jank frames: 5'));

      // AI diagnostic
      final diagnostic = verdict.toAiDiagnostic();
      expect(diagnostic, contains('RESULT: FAIL'));
      expect(diagnostic, contains('FAILED STEP 2'));
      expect(diagnostic, contains('wrongRoute'));
      expect(diagnostic, contains('PERFORMANCE ALERTS'));
    });

    test('Verdict file save and load roundtrip', () async {
      final dir = Directory.systemTemp.createTempSync('titan_verdict_test_');

      try {
        final verdict = Verdict.fromSteps(
          stratagemName: 'file_test',
          executedAt: DateTime(2025, 6, 1),
          duration: const Duration(seconds: 1),
          performance: VerdictPerformance(),
          steps: [
            VerdictStep.passed(
              stepId: 1,
              description: 'Only step',
              duration: const Duration(milliseconds: 100),
            ),
          ],
        );

        // Save
        await verdict.saveToFile(dir.path);
        final file = File('${dir.path}/file_test.verdict.json');
        expect(file.existsSync(), true);

        // Load
        final loaded = await Verdict.loadFromFile(
          'file_test',
          directory: dir.path,
        );
        expect(loaded, isNotNull);
        expect(loaded!.stratagemName, 'file_test');
        expect(loaded.passed, true);
        expect(loaded.steps.length, 1);

        // Load nonexistent
        final missing = await Verdict.loadFromFile(
          'nonexistent',
          directory: dir.path,
        );
        expect(missing, isNull);
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('templateDescription covers all action types', () {
      final desc = Stratagem.templateDescription.toLowerCase();
      // Key actions should be documented
      expect(desc, contains('tap'));
      expect(desc, contains('entertext'));
      expect(desc, contains('scroll'));
      expect(desc, contains('verify'));
      expect(desc, contains('wait'));
    });

    test('VerdictFailure suggestions are contextual', () {
      // targetNotFound with target
      final s1 = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.targetNotFound,
        target: const StratagemTarget(label: 'Submit', type: 'ElevatedButton'),
      );
      expect(s1, isNotEmpty);
      expect(s1.join(' ').toLowerCase(), contains('submit'));

      // notInteractive
      final s2 = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.notInteractive,
        target: const StratagemTarget(label: 'Title'),
      );
      expect(s2, isNotEmpty);

      // timeout
      final s3 = VerdictFailure.generateSuggestions(
        type: VerdictFailureType.timeout,
      );
      expect(s3, isNotEmpty);
    });

    test('complex Stratagem with all step types parses', () {
      final stratagem = Stratagem(
        name: 'all_actions',
        startRoute: '/',
        steps: [
          for (final action in StratagemAction.values)
            StratagemStep(
              id: action.index + 1,
              action: action,
              description: 'Test ${action.name}',
            ),
        ],
      );

      expect(stratagem.steps.length, StratagemAction.values.length);

      // Roundtrip
      final json = stratagem.toJson();
      final restored = Stratagem.fromJson(json);
      expect(restored.steps.length, stratagem.steps.length);

      for (var i = 0; i < stratagem.steps.length; i++) {
        expect(restored.steps[i].action, stratagem.steps[i].action);
      }
    });

    test('Verdict.fromSteps computes all summary fields', () {
      final verdict = Verdict.fromSteps(
        stratagemName: 'summary_test',
        executedAt: DateTime.now(),
        duration: const Duration(seconds: 10),
        performance: VerdictPerformance(),
        steps: [
          VerdictStep.passed(
            stepId: 1,
            description: 'Pass 1',
            duration: const Duration(seconds: 1),
          ),
          VerdictStep.passed(
            stepId: 2,
            description: 'Pass 2',
            duration: const Duration(seconds: 1),
          ),
          VerdictStep.passed(
            stepId: 3,
            description: 'Pass 3',
            duration: const Duration(seconds: 1),
          ),
          VerdictStep.failed(
            stepId: 4,
            description: 'Fail 1',
            duration: const Duration(seconds: 2),
            failure: const VerdictFailure(
              type: VerdictFailureType.elementMissing,
              message: 'Element X not found',
            ),
          ),
          VerdictStep.failed(
            stepId: 5,
            description: 'Fail 2',
            duration: const Duration(seconds: 2),
            failure: const VerdictFailure(
              type: VerdictFailureType.apiError,
              message: 'HTTP 500',
            ),
          ),
          VerdictStep.skipped(stepId: 6, description: 'Skipped'),
        ],
      );

      expect(verdict.passed, false);
      expect(verdict.summary.totalSteps, 6);
      expect(verdict.summary.passedSteps, 3);
      expect(verdict.summary.failedSteps, 2);
      expect(verdict.summary.skippedSteps, 1);
      expect(verdict.summary.successRate, closeTo(0.5, 0.01));
      expect(verdict.summary.missingElements, isNotEmpty);
      expect(verdict.summary.apiErrors, isNotEmpty);
      expect(verdict.summary.passed, false);

      // oneLiner should be informative
      expect(verdict.summary.oneLiner, contains('❌'));
    });
  });
}
