import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Signet createSignet({String route = '/test'}) {
    return Signet(
      routePattern: route,
      interactiveDescriptors: const [],
      hash: 'abc123',
      identity: 'test_screen',
    );
  }

  Outpost createOutpost({
    String route = '/test',
    bool requiresAuth = false,
    List<String>? tags,
    List<OutpostElement>? interactive,
    List<March>? exits,
    List<March>? entrances,
  }) {
    return Outpost(
      signet: createSignet(route: route),
      routePattern: route,
      displayName: route.replaceAll('/', ' ').trim(),
      tags: tags,
      requiresAuth: requiresAuth,
      interactiveElements: interactive,
      exits: exits,
      entrances: entrances,
    );
  }

  Terrain createTerrain(Map<String, Outpost> outposts) {
    return Terrain(outposts: outposts);
  }

  March createMarch({
    required String from,
    required String to,
    MarchTrigger trigger = MarchTrigger.tap,
    String? triggerLabel,
    String? triggerType,
    String? triggerKey,
    int durationMs = 1000,
  }) {
    return March(
      fromRoute: from,
      toRoute: to,
      trigger: trigger,
      triggerElementLabel: triggerLabel,
      triggerElementType: triggerType,
      triggerElementKey: triggerKey,
      averageDurationMs: durationMs,
    );
  }

  /// Build a linear graph: a → b → c → ...
  Terrain buildLinearGraph(List<String> routes, {
    List<MarchTrigger>? triggers,
    List<bool>? authFlags,
    List<List<String>>? tagSets,
    List<List<OutpostElement>>? elements,
  }) {
    final outposts = <String, Outpost>{};

    for (var i = 0; i < routes.length; i++) {
      outposts[routes[i]] = createOutpost(
        route: routes[i],
        requiresAuth: authFlags != null && i < authFlags.length
            ? authFlags[i]
            : false,
        tags: tagSets != null && i < tagSets.length ? tagSets[i] : null,
        interactive:
            elements != null && i < elements.length ? elements[i] : null,
      );
    }

    // Wire up marches
    for (var i = 0; i < routes.length - 1; i++) {
      final trigger = triggers != null && i < triggers.length
          ? triggers[i]
          : MarchTrigger.tap;
      final march = createMarch(
        from: routes[i],
        to: routes[i + 1],
        trigger: trigger,
      );
      outposts[routes[i]]!.exits.add(march);
      outposts[routes[i + 1]]!.entrances.add(march);
    }

    return createTerrain(outposts);
  }

  // -------------------------------------------------------------------------
  // StratagemPrerequisite
  // -------------------------------------------------------------------------

  group('StratagemPrerequisite', () {
    test('basic construction', () {
      final prereq = StratagemPrerequisite(
        description: 'Log in',
        stratagem: const Stratagem(
          name: 'login',
          startRoute: '/login',
          steps: [],
        ),
        isAuthGate: true,
        isFormGate: true,
        estimatedDuration: const Duration(seconds: 3),
      );

      expect(prereq.description, 'Log in');
      expect(prereq.isAuthGate, true);
      expect(prereq.isFormGate, true);
      expect(prereq.estimatedDuration.inSeconds, 3);
      expect(prereq.stratagem.name, 'login');
    });

    test('defaults for optional fields', () {
      final prereq = StratagemPrerequisite(
        description: 'Navigate',
        stratagem: const Stratagem(
          name: 'nav',
          startRoute: '/',
          steps: [],
        ),
      );

      expect(prereq.isAuthGate, false);
      expect(prereq.isFormGate, false);
      expect(prereq.estimatedDuration.inSeconds, 2);
    });

    test('toJson round-trip', () {
      final prereq = StratagemPrerequisite(
        description: 'Log in',
        stratagem: const Stratagem(
          name: 'login',
          startRoute: '/login',
          steps: [],
        ),
        isAuthGate: true,
        isFormGate: true,
        estimatedDuration: const Duration(seconds: 3),
      );

      final json = prereq.toJson();
      expect(json['description'], 'Log in');
      expect(json['isAuthGate'], true);
      expect(json['isFormGate'], true);
      expect(json['estimatedDurationMs'], 3000);
      expect(json['stratagem'], isA<Map<String, dynamic>>());

      final restored = StratagemPrerequisite.fromJson(json);
      expect(restored.description, prereq.description);
      expect(restored.isAuthGate, prereq.isAuthGate);
      expect(restored.isFormGate, prereq.isFormGate);
      expect(
        restored.estimatedDuration.inMilliseconds,
        prereq.estimatedDuration.inMilliseconds,
      );
      expect(restored.stratagem.name, prereq.stratagem.name);
    });

    test('fromJson with missing optional fields', () {
      final json = <String, dynamic>{
        'description': 'Minimal',
        'stratagem': const Stratagem(
          name: 'min',
          startRoute: '/',
          steps: [],
        ).toJson(),
      };

      final prereq = StratagemPrerequisite.fromJson(json);
      expect(prereq.isAuthGate, false);
      expect(prereq.isFormGate, false);
      expect(prereq.estimatedDuration.inMilliseconds, 2000);
    });

    test('toString', () {
      final prereq = StratagemPrerequisite(
        description: 'Log in',
        stratagem: const Stratagem(
          name: 'login',
          startRoute: '/login',
          steps: [],
        ),
        isAuthGate: true,
      );

      expect(prereq.toString(), contains('Log in'));
      expect(prereq.toString(), contains('auth=true'));
    });
  });

  // -------------------------------------------------------------------------
  // Lineage — resolve
  // -------------------------------------------------------------------------

  group('Lineage', () {
    group('resolve', () {
      test('empty lineage for entry-point target', () {
        final terrain = buildLinearGraph(['/home', '/settings']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );

        expect(lineage.targetRoute, '/home');
        expect(lineage.prerequisites, isEmpty);
        expect(lineage.path, isEmpty);
        expect(lineage.isEmpty, true);
        expect(lineage.isNotEmpty, false);
        expect(lineage.hopCount, 0);
        expect(lineage.requiresAuth, false);
      });

      test('empty lineage for unreachable route', () {
        final terrain = buildLinearGraph(['/a', '/b']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/unknown',
        );

        expect(lineage.prerequisites, isEmpty);
        expect(lineage.path, isEmpty);
      });

      test('single-hop prerequisite', () {
        final terrain = buildLinearGraph(['/login', '/home']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );

        expect(lineage.prerequisites, hasLength(1));
        expect(lineage.path, hasLength(1));
        expect(lineage.hopCount, 1);
        expect(lineage.path.first.fromRoute, '/login');
        expect(lineage.path.first.toRoute, '/home');
      });

      test('multi-hop prerequisite chain', () {
        final terrain = buildLinearGraph(
          ['/login', '/', '/quest/list', '/quest/42'],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/quest/42',
        );

        expect(lineage.prerequisites, hasLength(3));
        expect(lineage.path, hasLength(3));
        expect(lineage.hopCount, 3);
        expect(lineage.path[0].fromRoute, '/login');
        expect(lineage.path[0].toRoute, '/');
        expect(lineage.path[1].fromRoute, '/');
        expect(lineage.path[1].toRoute, '/quest/list');
        expect(lineage.path[2].fromRoute, '/quest/list');
        expect(lineage.path[2].toRoute, '/quest/42');
      });

      test('detects auth gate from auth tag + formSubmit', () {
        final terrain = buildLinearGraph(
          ['/login', '/home'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['auth']],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );

        expect(lineage.requiresAuth, true);
        expect(lineage.prerequisites.first.isAuthGate, true);
      });

      test('detects auth gate from redirect trigger', () {
        final terrain = buildLinearGraph(
          ['/home', '/login'],
          triggers: [MarchTrigger.redirect],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/login',
        );

        expect(lineage.prerequisites.first.isAuthGate, true);
      });

      test('detects auth gate from password field', () {
        final terrain = buildLinearGraph(
          ['/login', '/home'],
          triggers: [MarchTrigger.tap],
          elements: [
            [
              OutpostElement(
                widgetType: 'TextField',
                label: 'Password',
                isInteractive: true,
              ),
              OutpostElement(
                widgetType: 'ElevatedButton',
                label: 'Login',
                isInteractive: true,
              ),
            ],
          ],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );

        expect(lineage.requiresAuth, true);
        expect(lineage.prerequisites.first.isAuthGate, true);
      });

      test('detects form gate from formSubmit trigger', () {
        final terrain = buildLinearGraph(
          ['/register', '/welcome'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['form']],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/welcome',
        );

        expect(lineage.prerequisites.first.isFormGate, true);
      });

      test('detects form gate from form tag', () {
        final terrain = buildLinearGraph(
          ['/profile', '/saved'],
          triggers: [MarchTrigger.tap],
          tagSets: [['form']],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/saved',
        );

        expect(lineage.prerequisites.first.isFormGate, true);
      });

      test('picks shortest path when multiple exist', () {
        // Graph:
        //   /a → /b → /c → /target   (length 3)
        //   /a → /target              (length 1) ← shortest
        final outposts = <String, Outpost>{
          '/a': createOutpost(route: '/a'),
          '/b': createOutpost(route: '/b'),
          '/c': createOutpost(route: '/c'),
          '/target': createOutpost(route: '/target'),
        };

        final aToDirect = createMarch(from: '/a', to: '/target');
        final aToB = createMarch(from: '/a', to: '/b');
        final bToC = createMarch(from: '/b', to: '/c');
        final cToTarget = createMarch(from: '/c', to: '/target');

        outposts['/a']!.exits.addAll([aToDirect, aToB]);
        outposts['/b']!.exits.add(bToC);
        outposts['/c']!.exits.add(cToTarget);
        outposts['/b']!.entrances.add(aToB);
        outposts['/c']!.entrances.add(bToC);
        outposts['/target']!.entrances.addAll([aToDirect, cToTarget]);

        final terrain = createTerrain(outposts);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/target',
        );

        expect(lineage.path, hasLength(1));
        expect(lineage.prerequisites, hasLength(1));
      });

      test('handles single-node terrain (target is the only node)', () {
        final terrain = createTerrain({
          '/only': createOutpost(route: '/only'),
        });
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/only',
        );

        expect(lineage.prerequisites, isEmpty);
        expect(lineage.path, isEmpty);
      });

      test('handles route not in terrain at all', () {
        final terrain = buildLinearGraph(['/a', '/b']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/z',
        );

        expect(lineage.isEmpty, true);
      });

      test('target same as entry point returns empty', () {
        final terrain = buildLinearGraph(['/root']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/root',
        );

        expect(lineage.isEmpty, true);
      });
    });

    // -----------------------------------------------------------------------
    // Computed properties
    // -----------------------------------------------------------------------

    group('properties', () {
      test('requiresAuth false when no auth gates', () {
        final terrain = buildLinearGraph(['/a', '/b', '/c']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/c',
        );

        expect(lineage.requiresAuth, false);
      });

      test('requiresAuth true when auth gate exists', () {
        final terrain = buildLinearGraph(
          ['/login', '/home', '/settings'],
          triggers: [MarchTrigger.formSubmit, MarchTrigger.tap],
          tagSets: [['auth'], []],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/settings',
        );

        expect(lineage.requiresAuth, true);
      });

      test('estimatedSetupTime sums all prerequisites', () {
        final terrain = buildLinearGraph(
          ['/a', '/b', '/c', '/d'],
          triggers: [
            MarchTrigger.formSubmit,
            MarchTrigger.tap,
            MarchTrigger.tap,
          ],
          tagSets: [['form'], [], []],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/d',
        );

        expect(lineage.prerequisites, hasLength(3));
        expect(lineage.estimatedSetupTime.inMilliseconds, greaterThan(0));
      });

      test('hopCount matches path length', () {
        final terrain = buildLinearGraph(
          ['/a', '/b', '/c', '/d', '/e'],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/e',
        );

        expect(lineage.hopCount, 4);
        expect(lineage.path.length, lineage.hopCount);
      });
    });

    // -----------------------------------------------------------------------
    // toSetupStratagem
    // -----------------------------------------------------------------------

    group('toSetupStratagem', () {
      test('generates empty Stratagem for empty lineage', () {
        final terrain = buildLinearGraph(['/home']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );
        final setup = lineage.toSetupStratagem();

        expect(setup.steps, isEmpty);
        expect(setup.name, contains('home'));
        expect(setup.tags, contains('setup'));
        expect(setup.tags, contains('auto-generated'));
      });

      test('chains all prerequisite steps', () {
        final terrain = buildLinearGraph(
          ['/a', '/b', '/c'],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/c',
        );
        final setup = lineage.toSetupStratagem();

        expect(setup.steps.length, greaterThanOrEqualTo(2));
        expect(setup.startRoute, '/a');
        // Step IDs are sequential
        for (var i = 0; i < setup.steps.length; i++) {
          expect(setup.steps[i].id, i + 1);
        }
      });

      test('prefixes step descriptions with [Setup]', () {
        final terrain = buildLinearGraph(['/a', '/b']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        for (final step in setup.steps) {
          expect(step.description, startsWith('[Setup]'));
        }
      });

      test('forwards testData', () {
        final terrain = buildLinearGraph(['/a', '/b']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final testData = {'heroName': 'Thorin'};
        final setup = lineage.toSetupStratagem(testData: testData);

        expect(setup.testData, testData);
      });

      test('uses abortOnFirst failure policy', () {
        final terrain = buildLinearGraph(['/a', '/b']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        expect(setup.failurePolicy, StratagemFailurePolicy.abortOnFirst);
      });

      test('generates form field steps for form gate', () {
        final terrain = buildLinearGraph(
          ['/login', '/home'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['auth', 'form']],
          elements: [
            [
              OutpostElement(
                widgetType: 'TextField',
                label: 'Hero Name',
                isInteractive: true,
              ),
              OutpostElement(
                widgetType: 'ElevatedButton',
                label: 'Enter',
                isInteractive: true,
              ),
            ],
          ],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );
        final setup = lineage.toSetupStratagem();

        // Should have enterText + tap steps
        expect(setup.steps.length, greaterThanOrEqualTo(2));
        final enterStep = setup.steps.firstWhere(
          (s) => s.action == StratagemAction.enterText,
        );
        expect(enterStep.target?.label, 'Hero Name');
        expect(enterStep.clearFirst, true);
      });

      test('generates back step for back trigger', () {
        final terrain = buildLinearGraph(
          ['/detail', '/list'],
          triggers: [MarchTrigger.back],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/list',
        );
        final setup = lineage.toSetupStratagem();

        final backStep = setup.steps.firstWhere(
          (s) => s.action == StratagemAction.back,
        );
        expect(backStep, isNotNull);
      });

      test('generates navigate step for programmatic trigger', () {
        final terrain = buildLinearGraph(
          ['/a', '/b'],
          triggers: [MarchTrigger.programmatic],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        final navStep = setup.steps.firstWhere(
          (s) => s.action == StratagemAction.navigate,
        );
        expect(navStep.navigateRoute, '/b');
      });

      test('generates swipe step for swipe trigger', () {
        final terrain = buildLinearGraph(
          ['/page1', '/page2'],
          triggers: [MarchTrigger.swipe],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/page2',
        );
        final setup = lineage.toSetupStratagem();

        final swipeStep = setup.steps.firstWhere(
          (s) => s.action == StratagemAction.swipe,
        );
        expect(swipeStep, isNotNull);
      });
    });

    // -----------------------------------------------------------------------
    // AI output
    // -----------------------------------------------------------------------

    group('toAiSummary', () {
      test('includes target route', () {
        final terrain = buildLinearGraph(['/a', '/b']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );

        expect(lineage.toAiSummary(), contains('/b'));
      });

      test('includes auth status', () {
        final terrain = buildLinearGraph(
          ['/login', '/home'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['auth']],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );
        final summary = lineage.toAiSummary();

        expect(summary, contains('AUTH REQUIRED: true'));
      });

      test('lists prerequisites', () {
        final terrain = buildLinearGraph(['/a', '/b', '/c']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/c',
        );
        final summary = lineage.toAiSummary();

        expect(summary, contains('PREREQUISITES (2)'));
      });

      test('includes path description', () {
        final terrain = buildLinearGraph(['/a', '/b', '/c']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/c',
        );
        final summary = lineage.toAiSummary();

        expect(summary, contains('/a'));
        expect(summary, contains('/b'));
        expect(summary, contains('/c'));
      });

      test('empty path not printed', () {
        final terrain = buildLinearGraph(['/home']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );
        final summary = lineage.toAiSummary();

        expect(summary, isNot(contains('PATH:')));
      });
    });

    // -----------------------------------------------------------------------
    // Serialization
    // -----------------------------------------------------------------------

    group('serialization', () {
      test('toJson includes schema', () {
        final terrain = buildLinearGraph(['/a', '/b']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final json = lineage.toJson();

        expect(json[r'$schema'], 'titan://lineage/v1');
      });

      test('toJson round-trip', () {
        final terrain = buildLinearGraph(
          ['/login', '/home', '/settings'],
          triggers: [MarchTrigger.formSubmit, MarchTrigger.tap],
          tagSets: [['auth'], []],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/settings',
        );

        final json = lineage.toJson();
        final restored = Lineage.fromJson(json);

        expect(restored.targetRoute, lineage.targetRoute);
        expect(restored.requiresAuth, lineage.requiresAuth);
        expect(restored.path.length, lineage.path.length);
        expect(
          restored.prerequisites.length,
          lineage.prerequisites.length,
        );
      });

      test('toJson includes all path entries', () {
        final terrain = buildLinearGraph(['/a', '/b', '/c']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/c',
        );
        final json = lineage.toJson();

        final pathEntries = json['path'] as List;
        expect(pathEntries, hasLength(2));
        expect(pathEntries[0]['from'], '/a');
        expect(pathEntries[0]['to'], '/b');
        expect(pathEntries[1]['from'], '/b');
        expect(pathEntries[1]['to'], '/c');
      });

      test('toJson includes hop count', () {
        final terrain = buildLinearGraph(['/a', '/b', '/c']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/c',
        );

        expect(lineage.toJson()['hopCount'], 2);
      });

      test('fromJson restores trigger types', () {
        final json = <String, dynamic>{
          'targetRoute': '/target',
          'path': [
            {'from': '/a', 'to': '/b', 'trigger': 'formSubmit'},
            {'from': '/b', 'to': '/target', 'trigger': 'tap'},
          ],
          'prerequisites': <dynamic>[],
        };

        final lineage = Lineage.fromJson(json);
        expect(lineage.path[0].trigger, MarchTrigger.formSubmit);
        expect(lineage.path[1].trigger, MarchTrigger.tap);
      });

      test('fromJson handles unknown trigger gracefully', () {
        final json = <String, dynamic>{
          'targetRoute': '/target',
          'path': [
            {'from': '/a', 'to': '/b', 'trigger': 'nonexistent'},
          ],
          'prerequisites': <dynamic>[],
        };

        final lineage = Lineage.fromJson(json);
        expect(lineage.path[0].trigger, MarchTrigger.unknown);
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------

    group('edge cases', () {
      test('self-loop route (target has exit to itself)', () {
        final outposts = <String, Outpost>{
          '/a': createOutpost(route: '/a'),
          '/b': createOutpost(route: '/b'),
        };
        final selfLoop = createMarch(from: '/b', to: '/b');
        final aToB = createMarch(from: '/a', to: '/b');
        outposts['/a']!.exits.add(aToB);
        outposts['/b']!.exits.add(selfLoop);
        outposts['/b']!.entrances.addAll([aToB, selfLoop]);

        final terrain = createTerrain(outposts);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );

        expect(lineage.path, hasLength(1));
      });

      test('diamond graph resolves to shortest', () {
        // /start → /left → /end   (length 2)
        // /start → /right → /end  (length 2)
        final outposts = <String, Outpost>{
          '/start': createOutpost(route: '/start'),
          '/left': createOutpost(route: '/left'),
          '/right': createOutpost(route: '/right'),
          '/end': createOutpost(route: '/end'),
        };

        final sToL = createMarch(from: '/start', to: '/left');
        final sToR = createMarch(from: '/start', to: '/right');
        final lToE = createMarch(from: '/left', to: '/end');
        final rToE = createMarch(from: '/right', to: '/end');

        outposts['/start']!.exits.addAll([sToL, sToR]);
        outposts['/left']!.exits.add(lToE);
        outposts['/left']!.entrances.add(sToL);
        outposts['/right']!.exits.add(rToE);
        outposts['/right']!.entrances.add(sToR);
        outposts['/end']!.entrances.addAll([lToE, rToE]);

        final terrain = createTerrain(outposts);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/end',
        );

        // Either path is length 2
        expect(lineage.path, hasLength(2));
      });

      test('multiple entry points — picks shortest path', () {
        // /a → /target  (1 hop)     ← entry point
        // /b → /c → /target  (2 hops)  ← entry point
        final outposts = <String, Outpost>{
          '/a': createOutpost(route: '/a'),
          '/b': createOutpost(route: '/b'),
          '/c': createOutpost(route: '/c'),
          '/target': createOutpost(route: '/target'),
        };

        final aToT = createMarch(from: '/a', to: '/target');
        final bToC = createMarch(from: '/b', to: '/c');
        final cToT = createMarch(from: '/c', to: '/target');

        outposts['/a']!.exits.add(aToT);
        outposts['/b']!.exits.add(bToC);
        outposts['/c']!.exits.add(cToT);
        outposts['/c']!.entrances.add(bToC);
        outposts['/target']!.entrances.addAll([aToT, cToT]);

        final terrain = createTerrain(outposts);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/target',
        );

        expect(lineage.path, hasLength(1));
        expect(lineage.path.first.fromRoute, '/a');
      });

      test('deep chain produces correct order', () {
        final routes = ['/1', '/2', '/3', '/4', '/5', '/6'];
        final terrain = buildLinearGraph(routes);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/6',
        );

        expect(lineage.prerequisites, hasLength(5));
        expect(lineage.path, hasLength(5));

        // Verify order
        for (var i = 0; i < lineage.path.length; i++) {
          expect(lineage.path[i].fromRoute, routes[i]);
          expect(lineage.path[i].toRoute, routes[i + 1]);
        }
      });

      test('auth + form combined gate', () {
        final terrain = buildLinearGraph(
          ['/login', '/home'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['auth', 'form']],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );

        expect(lineage.prerequisites.first.isAuthGate, true);
        expect(lineage.prerequisites.first.isFormGate, true);
      });

      test('mixed gate types in chain', () {
        final terrain = buildLinearGraph(
          ['/login', '/', '/register'],
          triggers: [MarchTrigger.formSubmit, MarchTrigger.tap],
          tagSets: [['auth'], []],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/register',
        );

        expect(lineage.prerequisites[0].isAuthGate, true);
        expect(lineage.prerequisites[1].isAuthGate, false);
      });

      test('trigger label preserved in generated steps', () {
        final outposts = <String, Outpost>{
          '/a': createOutpost(route: '/a'),
          '/b': createOutpost(route: '/b'),
        };
        final march = createMarch(
          from: '/a',
          to: '/b',
          trigger: MarchTrigger.tap,
          triggerLabel: 'Continue',
          triggerType: 'ElevatedButton',
        );
        outposts['/a']!.exits.add(march);
        outposts['/b']!.entrances.add(march);

        final terrain = createTerrain(outposts);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        final tapStep = setup.steps.firstWhere(
          (s) => s.action == StratagemAction.tap,
        );
        expect(tapStep.target?.label, 'Continue');
        expect(tapStep.target?.type, 'ElevatedButton');
      });

      test('deep-link trigger generates navigate step', () {
        final terrain = buildLinearGraph(
          ['/splash', '/deep'],
          triggers: [MarchTrigger.deepLink],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/deep',
        );
        final setup = lineage.toSetupStratagem();

        expect(
          setup.steps.any((s) => s.action == StratagemAction.navigate),
          true,
        );
      });

      test('unknown trigger generates navigate step', () {
        final terrain = buildLinearGraph(
          ['/a', '/b'],
          triggers: [MarchTrigger.unknown],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        expect(
          setup.steps.any((s) => s.action == StratagemAction.navigate),
          true,
        );
      });
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------

    group('toString', () {
      test('includes target route and counts', () {
        final terrain = buildLinearGraph(['/a', '/b', '/c']);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/c',
        );

        final str = lineage.toString();
        expect(str, contains('/c'));
        expect(str, contains('2 prerequisites'));
        expect(str, contains('2 hops'));
      });
    });

    // -----------------------------------------------------------------------
    // Step generation detail
    // -----------------------------------------------------------------------

    group('step generation', () {
      test('text field steps have testData placeholders', () {
        final terrain = buildLinearGraph(
          ['/form', '/done'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['form']],
          elements: [
            [
              OutpostElement(
                widgetType: 'TextField',
                label: 'Email Address',
                isInteractive: true,
              ),
              OutpostElement(
                widgetType: 'TextField',
                label: 'Phone Number',
                isInteractive: true,
              ),
            ],
          ],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/done',
        );
        final setup = lineage.toSetupStratagem();

        final textSteps = setup.steps
            .where((s) => s.action == StratagemAction.enterText)
            .toList();
        expect(textSteps, hasLength(2));
        expect(textSteps[0].value, contains(r'testData'));
        expect(textSteps[1].value, contains(r'testData'));
      });

      test('each step in setup has unique sequential ID', () {
        final terrain = buildLinearGraph(
          ['/a', '/b', '/c', '/d'],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/d',
        );
        final setup = lineage.toSetupStratagem();

        final ids = setup.steps.map((s) => s.id).toList();
        for (var i = 0; i < ids.length; i++) {
          expect(ids[i], i + 1);
        }
      });

      test('non-tap march with trigger label still generates tap', () {
        final outposts = <String, Outpost>{
          '/a': createOutpost(route: '/a'),
          '/b': createOutpost(route: '/b'),
        };
        final march = createMarch(
          from: '/a',
          to: '/b',
          trigger: MarchTrigger.tap,
          triggerLabel: 'Next',
        );
        outposts['/a']!.exits.add(march);
        outposts['/b']!.entrances.add(march);

        final terrain = createTerrain(outposts);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        expect(
          setup.steps.any((s) =>
              s.action == StratagemAction.tap &&
              s.target?.label == 'Next'),
          true,
        );
      });

      test('tap step has route expectation', () {
        final terrain = buildLinearGraph(
          ['/a', '/b'],
          triggers: [MarchTrigger.tap],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        final tapStep = setup.steps.firstWhere(
          (s) => s.action == StratagemAction.tap,
        );
        expect(tapStep.expectations?.route, '/b');
      });

      test('navigate step targets correct route', () {
        final terrain = buildLinearGraph(
          ['/a', '/b'],
          triggers: [MarchTrigger.programmatic],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );
        final setup = lineage.toSetupStratagem();

        final navStep = setup.steps.firstWhere(
          (s) => s.action == StratagemAction.navigate,
        );
        expect(navStep.navigateRoute, '/b');
        expect(navStep.expectations?.route, '/b');
      });

      test('observed duration used in estimate', () {
        final outposts = <String, Outpost>{
          '/a': createOutpost(route: '/a'),
          '/b': createOutpost(route: '/b'),
        };
        final march = createMarch(
          from: '/a',
          to: '/b',
          durationMs: 5000,
        );
        outposts['/a']!.exits.add(march);
        outposts['/b']!.entrances.add(march);

        final terrain = createTerrain(outposts);
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/b',
        );

        expect(
          lineage.prerequisites.first.estimatedDuration.inMilliseconds,
          5000,
        );
      });

      test('form gate estimated duration is 3000ms', () {
        final terrain = buildLinearGraph(
          ['/form', '/done'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['form']],
        );
        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/done',
        );

        expect(
          lineage.prerequisites.first.estimatedDuration.inMilliseconds,
          3000,
        );
      });
    });

    // -----------------------------------------------------------------------
    // Integration: auth prerequisites
    // -----------------------------------------------------------------------

    group('integration', () {
      test('auth-protected multi-hop produces auth-first chain', () {
        final terrain = buildLinearGraph(
          ['/login', '/', '/dashboard', '/report'],
          triggers: [
            MarchTrigger.formSubmit,
            MarchTrigger.tap,
            MarchTrigger.tap,
          ],
          tagSets: [['auth', 'form'], [], []],
          elements: [
            [
              OutpostElement(
                widgetType: 'TextField',
                label: 'Username',
                isInteractive: true,
              ),
              OutpostElement(
                widgetType: 'TextField',
                label: 'Password',
                isInteractive: true,
              ),
              OutpostElement(
                widgetType: 'ElevatedButton',
                label: 'Sign In',
                isInteractive: true,
              ),
            ],
          ],
        );

        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/report',
        );

        expect(lineage.requiresAuth, true);
        expect(lineage.prerequisites, hasLength(3));

        // First prerequisite is auth/form
        expect(lineage.prerequisites[0].isAuthGate, true);
        expect(lineage.prerequisites[0].isFormGate, true);

        // Setup Stratagem includes text entry steps
        final setup = lineage.toSetupStratagem(
          testData: {'username': 'admin', 'password': 'secret'},
        );
        expect(
          setup.steps.where((s) => s.action == StratagemAction.enterText),
          hasLength(2),
        );
        expect(
          setup.steps.any((s) => s.action == StratagemAction.tap),
          true,
        );
      });

      test('public route has no auth prerequisites', () {
        final terrain = buildLinearGraph(
          ['/welcome', '/features'],
          triggers: [MarchTrigger.tap],
        );

        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/features',
        );

        expect(lineage.requiresAuth, false);
        expect(
          lineage.prerequisites.every((p) => !p.isAuthGate),
          true,
        );
      });

      test('toSetupStratagem round-trip through JSON', () {
        final terrain = buildLinearGraph(
          ['/login', '/home'],
          triggers: [MarchTrigger.formSubmit],
          tagSets: [['auth', 'form']],
          elements: [
            [
              OutpostElement(
                widgetType: 'TextField',
                label: 'Name',
                isInteractive: true,
              ),
            ],
          ],
        );

        final lineage = Lineage.resolve(
          terrain,
          targetRoute: '/home',
        );

        final setup = lineage.toSetupStratagem();
        final json = setup.toJson();
        final restored = Stratagem.fromJson(json);

        expect(restored.name, setup.name);
        expect(restored.steps.length, setup.steps.length);
        expect(restored.startRoute, setup.startRoute);
      });
    });
  });
}
