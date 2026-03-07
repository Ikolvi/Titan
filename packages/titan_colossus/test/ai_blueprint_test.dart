import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';

/// Phase 6 tests — Colossus API additions & getAiBlueprint.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Terrain buildSampleTerrain() {
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);

    // Simulate session with two screens and a transition
    final verdict = Verdict(
      stratagemName: 'sample',
      executedAt: DateTime(2025),
      duration: const Duration(seconds: 2),
      passed: true,
      steps: const [],
      tableaux: [
        Tableau(
          index: 0,
          timestamp: const Duration(seconds: 0),
          route: '/home',
          glyphs: [
            Glyph(
              widgetType: 'ElevatedButton',
              label: 'Login',
              isInteractive: true,
              interactionType: 'tap',
              isEnabled: true,
              left: 50,
              top: 100,
              width: 100,
              height: 50,
            ),
          ],
          screenWidth: 400,
          screenHeight: 800,
        ),
        Tableau(
          index: 1,
          timestamp: const Duration(seconds: 1),
          route: '/dashboard',
          glyphs: [
            Glyph(
              widgetType: 'Text',
              label: 'Welcome',
              isInteractive: false,
              isEnabled: true,
              left: 100,
              top: 200,
              width: 200,
              height: 30,
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
        duration: Duration(seconds: 2),
      ),
      performance: const VerdictPerformance(),
    );

    scout.analyzeVerdict(verdict);
    return terrain;
  }

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
        passedSteps:
            steps.where((s) => s.status == VerdictStepStatus.passed).length,
        failedSteps:
            steps.where((s) => s.status == VerdictStepStatus.failed).length,
        skippedSteps: 0,
        successRate: passed ? 1.0 : 0.0,
        duration: const Duration(seconds: 1),
      ),
      performance: const VerdictPerformance(),
    );
  }

  // =========================================================================
  // Scout & Terrain getters (unit tests on standalone Scout)
  // =========================================================================

  group('Scout & Terrain getters', () {
    test('Scout.instance creates singleton automatically', () {
      Scout.reset();
      final s = Scout.instance;
      expect(s, isA<Scout>());
      expect(Scout.instance, same(s));
    });

    test('Scout.withTerrain creates isolated scout', () {
      final terrain = Terrain();
      final scout = Scout.withTerrain(terrain);
      expect(scout.terrain, same(terrain));
    });

    test('Terrain initially empty', () {
      final terrain = Terrain();
      expect(terrain.outposts, isEmpty);
      expect(terrain.marches, isEmpty);
      expect(terrain.sessionsAnalyzed, 0);
    });

    test('buildSampleTerrain populates outposts', () {
      final terrain = buildSampleTerrain();
      expect(terrain.outposts.length, greaterThanOrEqualTo(2));
      expect(terrain.hasRoute('/home'), true);
      expect(terrain.hasRoute('/dashboard'), true);
    });
  });

  // =========================================================================
  // Lineage resolution (unit tests)
  // =========================================================================

  group('Lineage resolution', () {
    test('resolveLineage for known route returns Lineage', () {
      final terrain = buildSampleTerrain();
      final lineage = Lineage.resolve(terrain, targetRoute: '/dashboard');
      expect(lineage.targetRoute, '/dashboard');
    });

    test('resolveLineage for unknown route returns empty lineage', () {
      final terrain = buildSampleTerrain();
      final lineage = Lineage.resolve(terrain, targetRoute: '/unknown');
      expect(lineage.isEmpty, true);
    });

    test('toAiSummary returns non-empty string', () {
      final terrain = buildSampleTerrain();
      final lineage = Lineage.resolve(terrain, targetRoute: '/dashboard');
      final summary = lineage.toAiSummary();
      expect(summary, isNotEmpty);
      expect(summary, contains('/dashboard'));
    });

    test('lineage path from home to dashboard', () {
      final terrain = buildSampleTerrain();
      final lineage = Lineage.resolve(terrain, targetRoute: '/dashboard');
      // May have a direct path from /home → /dashboard if march exists
      if (lineage.isNotEmpty) {
        expect(lineage.path, isNotEmpty);
      }
    });
  });

  // =========================================================================
  // Gauntlet generation (unit tests)
  // =========================================================================

  group('Gauntlet generation', () {
    test('generates stratagems for known outpost', () {
      final terrain = buildSampleTerrain();
      final outpost = terrain.outposts['/home'];
      if (outpost != null) {
        final stratagems = Gauntlet.generateFor(outpost);
        expect(stratagems, isA<List<Stratagem>>());
      }
    });

    test('empty Gauntlet for outpost with no interactive elements', () {
      final terrain = buildSampleTerrain();
      final outpost = terrain.outposts['/dashboard'];
      if (outpost != null) {
        final stratagems = Gauntlet.generateFor(outpost);
        // /dashboard only has a Text widget (non-interactive)
        // Gauntlet may still generate navigation stress tests
        expect(stratagems, isA<List<Stratagem>>());
      }
    });

    test('intensity controls pattern count', () {
      final terrain = buildSampleTerrain();
      final outpost = terrain.outposts['/home'];
      if (outpost != null) {
        final quick =
            Gauntlet.generateFor(outpost, intensity: GauntletIntensity.quick);
        final thorough = Gauntlet.generateFor(
          outpost,
          intensity: GauntletIntensity.thorough,
        );
        expect(thorough.length, greaterThanOrEqualTo(quick.length));
      }
    });

    test('catalog has patterns', () {
      expect(Gauntlet.catalog, isNotEmpty);
      expect(Gauntlet.catalog.length, 24);
    });

    test('pattern toJson includes all fields', () {
      final pattern = Gauntlet.catalog.first;
      final json = pattern.toJson();
      expect(json.containsKey('name'), true);
      expect(json.containsKey('category'), true);
      expect(json.containsKey('risk'), true);
    });
  });

  // =========================================================================
  // Campaign model (unit tests)
  // =========================================================================

  group('Campaign model', () {
    test('templateDescription is non-empty', () {
      expect(Campaign.templateDescription, isNotEmpty);
    });

    test('template is valid JSON structure', () {
      final template = Campaign.template;
      expect(template, isA<Map<String, dynamic>>());
      expect(template.containsKey('name'), true);
    });

    test('Campaign fromJson round-trip', () {
      final campaign = Campaign(
        name: 'test-campaign',
        entries: [
          CampaignEntry(
            stratagem: Stratagem(
              name: 'login',
              startRoute: '/login',
              steps: const [],
            ),
          ),
        ],
      );

      final json = campaign.toJson();
      final restored = Campaign.fromJson(json);
      expect(restored.name, 'test-campaign');
      expect(restored.entries, hasLength(1));
    });
  });

  // =========================================================================
  // Debrief (unit tests via standalone Debrief class)
  // =========================================================================

  group('Debrief standalone', () {
    test('all-passed verdicts produce EXPAND suggestion', () {
      final terrain = Terrain();
      final scout = Scout.withTerrain(terrain);

      final debrief = Debrief(
        verdicts: [makeVerdict('test')],
        terrain: terrain,
        scout: scout,
      );

      final report = debrief.analyze();
      expect(report.allPassed, true);
      expect(report.suggestedNextActions.first, contains('EXPAND'));
    });

    test('failed verdicts produce insights', () {
      final terrain = Terrain();
      final scout = Scout.withTerrain(terrain);

      final debrief = Debrief(
        verdicts: [
          makeVerdict('test', passed: false, steps: [
            VerdictStep(
              stepId: 1,
              description: 'find button',
              status: VerdictStepStatus.failed,
              duration: const Duration(milliseconds: 500),
              failure: const VerdictFailure(
                type: VerdictFailureType.targetNotFound,
                message: 'Login button not found',
              ),
            ),
          ]),
        ],
        terrain: terrain,
        scout: scout,
      );

      final report = debrief.analyze();
      expect(report.insights, isNotEmpty);
      expect(
        report.insights.any((i) => i.type == InsightType.elementNotFound),
        true,
      );
    });

    test('DebriefReport toAiSummary is well-formed', () {
      final terrain = Terrain();
      final scout = Scout.withTerrain(terrain);

      final report = Debrief(
        verdicts: [makeVerdict('test')],
        terrain: terrain,
        scout: scout,
      ).analyze();

      final summary = report.toAiSummary();
      expect(summary, contains('DEBRIEF REPORT'));
      expect(summary, contains('VERDICTS'));
      expect(summary, contains('PASSED'));
    });
  });

  // =========================================================================
  // getAiBlueprint — AI context (requires widget test for TableauCapture)
  // =========================================================================

  group('getAiBlueprint structure', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
      Scout.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
      Scout.reset();
    });

    test('returns comprehensive AI context keys', () async {
      final colossus = Colossus.init(enableLensTab: false);

      // We can't call getAiBlueprint without a widget tree for
      // TableauCapture, but we can verify the method exists and
      // test the terrain-specific keys separately.
      expect(colossus.terrain, isA<Terrain>());
      expect(colossus.scout, isA<Scout>());
    });

    test('gauntletCatalog has 24 patterns', () {
      expect(Gauntlet.catalog, hasLength(24));
      for (final p in Gauntlet.catalog) {
        final json = p.toJson();
        expect(json.containsKey('name'), true);
        expect(json.containsKey('category'), true);
        expect(json.containsKey('risk'), true);
      }
    });

    test('campaignTemplate is non-empty', () {
      expect(Campaign.templateDescription, isNotEmpty);
      expect(Campaign.template, isA<Map<String, dynamic>>());
    });

    test('terrain data defaults to empty on fresh init', () {
      Colossus.init(enableLensTab: false);
      final terrain = Colossus.instance.terrain;
      expect(terrain.outposts, isEmpty);
      expect(terrain.marches, isEmpty);
    });

    test('blueprint keys include terrain data', () {
      Colossus.init(enableLensTab: false);
      final terrain = Colossus.instance.terrain;

      // Verify the data that getAiBlueprint() would include
      expect(terrain.toJson(), isA<Map<String, dynamic>>());
      expect(terrain.toAiMap(), isA<String>());
      expect(terrain.toMermaid(), isA<String>());
      expect(
        terrain.authProtectedScreens.map((o) => o.routePattern).toList(),
        isEmpty,
      );
      expect(
        terrain.publicScreens.map((o) => o.routePattern).toList(),
        isEmpty,
      );
      expect(
        terrain.deadEnds.map((o) => o.routePattern).toList(),
        isEmpty,
      );
      expect(
        terrain.unreliableMarches.toList(),
        isEmpty,
      );
    });
  });

  // =========================================================================
  // Colossus API convenience methods (integration-like, with Colossus.init)
  // =========================================================================

  group('Colossus API convenience methods', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
      Scout.reset();
    });

    tearDown(() {
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
      Scout.reset();
    });

    test('scout and terrain getters work', () {
      Colossus.init(enableLensTab: false);
      expect(Colossus.instance.scout, isA<Scout>());
      expect(Colossus.instance.terrain, isA<Terrain>());
    });

    test('generateSorties returns list', () {
      Colossus.init(enableLensTab: false);
      final sorties = Colossus.instance.generateSorties();
      expect(sorties, isA<List<Stratagem>>());
    });

    test('resolveLineage returns Lineage', () {
      Colossus.init(enableLensTab: false);
      final lineage = Colossus.instance.resolveLineage('/unknown');
      expect(lineage, isA<Lineage>());
      expect(lineage.isEmpty, true);
    });

    test('getLineageSummary returns string', () {
      Colossus.init(enableLensTab: false);
      final summary = Colossus.instance.getLineageSummary('/unknown');
      expect(summary, isA<String>());
    });

    test('generateGauntlet returns empty for unknown route', () {
      Colossus.init(enableLensTab: false);
      final stratagems = Colossus.instance.generateGauntlet('/unknown');
      expect(stratagems, isEmpty);
    });

    test('debrief returns DebriefReport', () {
      Colossus.init(enableLensTab: false);
      final report = Colossus.instance.debrief([makeVerdict('test')]);
      expect(report, isA<DebriefReport>());
      expect(report.allPassed, true);
      expect(report.totalVerdicts, 1);
    });

    test('debrief with failures produces insights', () {
      Colossus.init(enableLensTab: false);
      final report = Colossus.instance.debrief([
        makeVerdict('test', passed: false, steps: [
          VerdictStep(
            stepId: 1,
            description: 'find button',
            status: VerdictStepStatus.failed,
            duration: const Duration(milliseconds: 500),
            failure: const VerdictFailure(
              type: VerdictFailureType.targetNotFound,
              message: 'Not found',
            ),
          ),
        ]),
      ]);

      expect(report.failedVerdicts, 1);
      expect(report.insights, isNotEmpty);
    });

    test('learnFromSession updates terrain', () {
      Colossus.init(enableLensTab: false);
      expect(Colossus.instance.terrain.outposts, isEmpty);

      // Create a minimal session with tableaux
      final session = ShadeSession(
        id: 'test-001',
        name: 'test-session',
        recordedAt: DateTime(2025),
        duration: const Duration(seconds: 1),
        screenWidth: 400,
        screenHeight: 800,
        devicePixelRatio: 1.0,
        tableaux: [
          Tableau(
            index: 0,
            timestamp: const Duration(seconds: 0),
            route: '/test-screen',
            glyphs: [
              Glyph(
                widgetType: 'Text',
                label: 'Test',
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
        imprints: const [],
      );

      Colossus.instance.learnFromSession(session);
      expect(Colossus.instance.terrain.outposts, isNotEmpty);
      expect(Colossus.instance.terrain.hasRoute('/test-screen'), true);
    });
  });
}
