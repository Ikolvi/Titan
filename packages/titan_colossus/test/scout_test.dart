import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Glyph createGlyph({
    String widgetType = 'ElevatedButton',
    String? label = 'Submit',
    double left = 10.0,
    double top = 20.0,
    double width = 100.0,
    double height = 48.0,
    bool isInteractive = true,
    String? interactionType = 'tap',
    String? key,
    String? semanticRole = 'button',
    bool isEnabled = true,
    String? currentValue,
    List<String> ancestors = const ['Scaffold', 'Column'],
    int depth = 5,
  }) {
    return Glyph(
      widgetType: widgetType,
      label: label,
      left: left,
      top: top,
      width: width,
      height: height,
      isInteractive: isInteractive,
      interactionType: interactionType,
      key: key,
      semanticRole: semanticRole,
      isEnabled: isEnabled,
      currentValue: currentValue,
      ancestors: ancestors,
      depth: depth,
    );
  }

  Tableau createTableau({
    int index = 0,
    Duration timestamp = Duration.zero,
    String? route = '/home',
    double screenWidth = 375.0,
    double screenHeight = 812.0,
    List<Glyph>? glyphs,
  }) {
    return Tableau(
      index: index,
      timestamp: timestamp,
      route: route,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      glyphs: glyphs ?? [],
    );
  }

  Imprint createImprint({
    ImprintType type = ImprintType.pointerUp,
    double x = 60.0,
    double y = 44.0,
    Duration timestamp = Duration.zero,
    int pointer = 0,
  }) {
    return Imprint(
      type: type,
      positionX: x,
      positionY: y,
      timestamp: timestamp,
      pointer: pointer,
      deviceKind: 0,
      buttons: 1,
      deltaX: 0,
      deltaY: 0,
      scrollDeltaX: 0,
      scrollDeltaY: 0,
      pressure: 1.0,
    );
  }

  ShadeSession createSession({
    List<Tableau>? tableaux,
    List<Imprint>? imprints,
    String name = 'test_session',
  }) {
    return ShadeSession(
      id: 'test-session-1',
      name: name,
      recordedAt: DateTime(2024, 1, 1),
      duration: const Duration(seconds: 30),
      screenWidth: 375,
      screenHeight: 812,
      devicePixelRatio: 3.0,
      imprints: imprints ?? [],
      tableaux: tableaux ?? [],
    );
  }

  VerdictStep createVerdictStep({
    int stepId = 1,
    String description = 'Test step',
    VerdictStepStatus status = VerdictStepStatus.passed,
    Duration duration = const Duration(milliseconds: 500),
    Tableau? tableau,
    VerdictFailure? failure,
  }) {
    return VerdictStep(
      stepId: stepId,
      description: description,
      status: status,
      duration: duration,
      tableau: tableau,
      failure: failure,
    );
  }

  Verdict createVerdict({
    String name = 'test_stratagem',
    List<VerdictStep>? steps,
    List<Tableau>? tableaux,
    bool passed = true,
  }) {
    final stepList = steps ?? [];
    return Verdict(
      stratagemName: name,
      executedAt: DateTime(2024, 1, 1),
      duration: const Duration(seconds: 10),
      passed: passed,
      steps: stepList,
      summary: VerdictSummary.fromSteps(stepList, const Duration(seconds: 10)),
      performance: const VerdictPerformance(
        averageFps: 60,
        minFps: 58,
        jankFrames: 0,
      ),
      tableaux: tableaux ?? [],
    );
  }

  // -------------------------------------------------------------------------
  // Scout — Flow Discovery Engine
  // -------------------------------------------------------------------------

  group('Scout', () {
    late Scout scout;

    setUp(() {
      Scout.reset();
      scout = Scout.instance;
    });

    tearDown(() {
      Scout.reset();
    });

    group('singleton', () {
      test('returns same instance', () {
        final a = Scout.instance;
        final b = Scout.instance;
        expect(identical(a, b), true);
      });

      test('reset creates new instance', () {
        final before = Scout.instance;
        Scout.reset();
        final after = Scout.instance;
        expect(identical(before, after), false);
      });
    });

    group('analyzeSession', () {
      test('no-op for empty session', () {
        scout.analyzeSession(createSession(tableaux: []));
        expect(scout.terrain.screenCount, 0);
        // Early return for empty session — counter NOT incremented
        expect(scout.terrain.sessionsAnalyzed, 0);
      });

      test('creates Outpost for single Tableau', () {
        final session = createSession(
          tableaux: [
            createTableau(
              index: 0,
              route: '/login',
              glyphs: [
                createGlyph(label: 'Login', widgetType: 'ElevatedButton'),
              ],
            ),
          ],
        );

        scout.analyzeSession(session);
        expect(scout.terrain.screenCount, 1);
        expect(scout.terrain.hasRoute('/login'), true);
      });

      test('creates multiple Outposts from 3 Tableaux', () {
        final session = createSession(
          tableaux: [
            createTableau(
              index: 0,
              route: '/login',
              timestamp: const Duration(seconds: 0),
            ),
            createTableau(
              index: 1,
              route: '/home',
              timestamp: const Duration(seconds: 2),
            ),
            createTableau(
              index: 2,
              route: '/settings',
              timestamp: const Duration(seconds: 5),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 4),
            ),
          ],
        );

        scout.analyzeSession(session);
        expect(scout.terrain.screenCount, 3);
        expect(scout.terrain.hasRoute('/login'), true);
        expect(scout.terrain.hasRoute('/home'), true);
        expect(scout.terrain.hasRoute('/settings'), true);
      });

      test('creates Marches from route transitions', () {
        final session = createSession(
          tableaux: [
            createTableau(index: 0, route: '/login', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/home',
              timestamp: const Duration(seconds: 2),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
          ],
        );

        scout.analyzeSession(session);
        final loginOutpost = scout.terrain.outposts['/login']!;
        expect(loginOutpost.exits, hasLength(1));
        expect(loginOutpost.exits.first.toRoute, '/home');
      });

      test('does not create March when route unchanged', () {
        final session = createSession(
          tableaux: [
            createTableau(index: 0, route: '/login', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/login',
              timestamp: const Duration(seconds: 2),
            ),
          ],
        );

        scout.analyzeSession(session);
        expect(scout.terrain.outposts['/login']!.exits, isEmpty);
      });

      test('merges duplicate screens into single Outpost', () {
        // Session that visits /home twice
        final session = createSession(
          tableaux: [
            createTableau(index: 0, route: '/home', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/settings',
              timestamp: const Duration(seconds: 2),
            ),
            createTableau(
              index: 2,
              route: '/home',
              timestamp: const Duration(seconds: 4),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 3),
            ),
          ],
        );

        scout.analyzeSession(session);
        expect(scout.terrain.screenCount, 2); // /home and /settings
        expect(scout.terrain.outposts['/home']!.observationCount, 2);
      });

      test('increments sessionsAnalyzed', () {
        scout.analyzeSession(
          createSession(tableaux: [createTableau(index: 0, route: '/a')]),
        );
        scout.analyzeSession(
          createSession(tableaux: [createTableau(index: 0, route: '/b')]),
        );
        expect(scout.terrain.sessionsAnalyzed, 2);
      });

      test('skips Tableaux with null routes', () {
        final session = createSession(
          tableaux: [createTableau(index: 0, route: null)],
        );
        scout.analyzeSession(session);
        expect(scout.terrain.screenCount, 0);
      });

      test('infers tap trigger from pointerUp Imprint', () {
        final session = createSession(
          tableaux: [
            createTableau(index: 0, route: '/a', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/b',
              timestamp: const Duration(seconds: 2),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
          ],
        );

        scout.analyzeSession(session);
        final march = scout.terrain.outposts['/a']!.exits.first;
        expect(march.trigger, MarchTrigger.tap);
      });

      test('infers redirect trigger when no Imprints between Tableaux', () {
        final session = createSession(
          tableaux: [
            createTableau(
              index: 0,
              route: '/protected',
              timestamp: Duration.zero,
            ),
            createTableau(
              index: 1,
              route: '/login',
              timestamp: const Duration(milliseconds: 100),
            ),
          ],
          imprints: [], // No user interaction — redirect
        );

        scout.analyzeSession(session);
        final march = scout.terrain.outposts['/protected']!.exits.first;
        expect(march.trigger, MarchTrigger.redirect);
      });

      test('infers formSubmit trigger from textInput + pointerUp', () {
        final session = createSession(
          tableaux: [
            createTableau(index: 0, route: '/login', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/home',
              timestamp: const Duration(seconds: 3),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.textInput,
              timestamp: const Duration(seconds: 1),
            ),
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 2),
            ),
          ],
        );

        scout.analyzeSession(session);
        final march = scout.terrain.outposts['/login']!.exits.first;
        expect(march.trigger, MarchTrigger.formSubmit);
      });

      test('parameterizes dynamic routes', () {
        // First visit /quest/42, then /quest/7
        final s1 = createSession(
          tableaux: [createTableau(index: 0, route: '/quest/42')],
        );
        final s2 = createSession(
          tableaux: [createTableau(index: 0, route: '/quest/7')],
        );

        scout.analyzeSession(s1);
        scout.analyzeSession(s2);

        // Both should map to /quest/:id
        expect(scout.terrain.hasRoute('/quest/:id'), true);
        expect(scout.terrain.screenCount, 1);
      });

      test('computes March duration from Tableaux timestamps', () {
        final session = createSession(
          tableaux: [
            createTableau(
              index: 0,
              route: '/a',
              timestamp: const Duration(seconds: 1),
            ),
            createTableau(
              index: 1,
              route: '/b',
              timestamp: const Duration(seconds: 4),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 2),
            ),
          ],
        );

        scout.analyzeSession(session);
        final march = scout.terrain.outposts['/a']!.exits.first;
        expect(march.averageDurationMs, 3000);
      });

      test('registers entrance March on destination Outpost', () {
        final session = createSession(
          tableaux: [
            createTableau(index: 0, route: '/login', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/home',
              timestamp: const Duration(seconds: 2),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
          ],
        );

        scout.analyzeSession(session);
        expect(scout.terrain.outposts['/home']!.entrances, hasLength(1));
        expect(
          scout.terrain.outposts['/home']!.entrances.first.fromRoute,
          '/login',
        );
      });
    });

    group('analyzeVerdict', () {
      test('registers Outposts from step tableaux', () {
        final verdict = createVerdict(
          steps: [
            createVerdictStep(
              stepId: 1,
              tableau: createTableau(route: '/login'),
            ),
            createVerdictStep(
              stepId: 2,
              tableau: createTableau(route: '/home'),
            ),
          ],
        );

        scout.analyzeVerdict(verdict);
        expect(scout.terrain.hasRoute('/login'), true);
        expect(scout.terrain.hasRoute('/home'), true);
      });

      test('creates March from route change between steps', () {
        final verdict = createVerdict(
          steps: [
            createVerdictStep(
              stepId: 1,
              tableau: createTableau(route: '/login'),
            ),
            createVerdictStep(
              stepId: 2,
              tableau: createTableau(route: '/home'),
            ),
          ],
        );

        scout.analyzeVerdict(verdict);
        expect(scout.terrain.outposts['/login']!.exits, hasLength(1));
        expect(scout.terrain.outposts['/login']!.exits.first.toRoute, '/home');
      });

      test('infers trigger from original Stratagem actions', () {
        final stratagem = const Stratagem(
          name: 'test',
          startRoute: '/login',
          steps: [
            StratagemStep(
              id: 1,
              action: StratagemAction.tap,
              description: 'Tap login',
            ),
            StratagemStep(
              id: 2,
              action: StratagemAction.verify,
              description: 'Verify home',
            ),
          ],
        );

        final verdict = createVerdict(
          steps: [
            createVerdictStep(
              stepId: 1,
              tableau: createTableau(route: '/login'),
            ),
            createVerdictStep(
              stepId: 2,
              tableau: createTableau(route: '/home'),
            ),
          ],
        );

        scout.analyzeVerdict(verdict, stratagem: stratagem);
        final march = scout.terrain.outposts['/login']!.exits.first;
        expect(march.trigger, MarchTrigger.tap);
      });

      test('uses unknown trigger without original Stratagem', () {
        final verdict = createVerdict(
          steps: [
            createVerdictStep(
              stepId: 1,
              tableau: createTableau(route: '/login'),
            ),
            createVerdictStep(
              stepId: 2,
              tableau: createTableau(route: '/home'),
            ),
          ],
        );

        scout.analyzeVerdict(verdict);
        final march = scout.terrain.outposts['/login']!.exits.first;
        expect(march.trigger, MarchTrigger.unknown);
      });

      test('registers Outposts from top-level tableaux', () {
        final verdict = createVerdict(
          tableaux: [
            createTableau(route: '/splash'),
            createTableau(route: '/onboarding'),
          ],
        );

        scout.analyzeVerdict(verdict);
        expect(scout.terrain.hasRoute('/splash'), true);
        expect(scout.terrain.hasRoute('/onboarding'), true);
      });

      test('increments stratagemExecutionsAnalyzed', () {
        scout.analyzeVerdict(createVerdict());
        scout.analyzeVerdict(createVerdict());
        expect(scout.terrain.stratagemExecutionsAnalyzed, 2);
      });

      test('skips steps without tableaux', () {
        final verdict = createVerdict(
          steps: [
            createVerdictStep(stepId: 1, tableau: null),
            createVerdictStep(stepId: 2, tableau: null),
          ],
        );

        scout.analyzeVerdict(verdict);
        expect(scout.terrain.screenCount, 0);
      });

      test('detects auth redirect from failed wrongRoute step', () {
        // First register the auth screen in Terrain
        scout.analyzeSession(
          createSession(
            tableaux: [
              createTableau(
                route: '/login',
                glyphs: [
                  createGlyph(
                    widgetType: 'TextField',
                    interactionType: 'textInput',
                    semanticRole: 'textField',
                  ),
                  createGlyph(label: 'Login', interactionType: 'tap'),
                ],
              ),
            ],
          ),
        );

        final verdict = createVerdict(
          passed: false,
          steps: [
            createVerdictStep(
              stepId: 1,
              status: VerdictStepStatus.failed,
              tableau: createTableau(route: '/login'),
              failure: const VerdictFailure(
                type: VerdictFailureType.wrongRoute,
                message: 'Expected /dashboard but got /login',
                expected: '/dashboard',
                actual: '/login',
              ),
            ),
          ],
        );

        // Register /dashboard too
        scout.analyzeSession(
          createSession(tableaux: [createTableau(route: '/dashboard')]),
        );

        scout.analyzeVerdict(verdict);
        expect(scout.terrain.outposts['/dashboard']?.requiresAuth, true);
      });
    });

    group('generateSortie', () {
      test('returns null for unknown route', () {
        expect(scout.generateSortie('/unknown'), isNull);
      });

      test('returns null when all elements are explored', () {
        // Create an outpost where every tap element has a corresponding exit
        final outpost = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
          interactiveElements: [
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Settings',
              interactionType: 'tap',
              isInteractive: true,
            ),
          ],
          exits: [
            March(
              fromRoute: '/home',
              toRoute: '/settings',
              trigger: MarchTrigger.tap,
              triggerElementLabel: 'Settings',
              triggerElementType: 'ElevatedButton',
            ),
          ],
        );
        scout.terrain.outposts['/home'] = outpost;

        expect(scout.generateSortie('/home'), isNull);
      });

      test('generates sortie for partially explored screen', () {
        final outpost = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
          interactiveElements: [
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Settings',
              interactionType: 'tap',
              isInteractive: true,
            ),
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Profile',
              interactionType: 'tap',
              isInteractive: true,
            ),
          ],
          exits: [
            // Only Settings has been explored
            March(
              fromRoute: '/home',
              toRoute: '/settings',
              trigger: MarchTrigger.tap,
              triggerElementLabel: 'Settings',
              triggerElementType: 'ElevatedButton',
            ),
          ],
        );
        scout.terrain.outposts['/home'] = outpost;

        final sortie = scout.generateSortie('/home');
        expect(sortie, isNotNull);
        expect(sortie!.name, contains('home'));
        expect(sortie.tags, contains('discovery'));
        expect(sortie.tags, contains('sortie'));
        expect(sortie.failurePolicy, StratagemFailurePolicy.continueAll);
      });

      test('sortie includes tap+back for each unexplored element', () {
        final outpost = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
          interactiveElements: [
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Unexplored A',
              interactionType: 'tap',
              isInteractive: true,
            ),
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Unexplored B',
              interactionType: 'tap',
              isInteractive: true,
            ),
          ],
        );
        scout.terrain.outposts['/home'] = outpost;

        final sortie = scout.generateSortie('/home')!;
        // 2 unexplored × 2 steps (tap + back) = 4 steps
        expect(sortie.steps, hasLength(4));
        expect(sortie.steps[0].action, StratagemAction.tap);
        expect(sortie.steps[1].action, StratagemAction.back);
        expect(sortie.steps[2].action, StratagemAction.tap);
        expect(sortie.steps[3].action, StratagemAction.back);
      });

      test('sortie targets elements by label and type', () {
        final outpost = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
          interactiveElements: [
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Profile',
              interactionType: 'tap',
              isInteractive: true,
              key: 'profile_btn',
            ),
          ],
        );
        scout.terrain.outposts['/home'] = outpost;

        final sortie = scout.generateSortie('/home')!;
        final tapStep = sortie.steps.first;
        expect(tapStep.target?.label, 'Profile');
        expect(tapStep.target?.type, 'ElevatedButton');
        expect(tapStep.target?.key, 'profile_btn');
      });

      test('skips non-tap interactive elements', () {
        final outpost = Outpost(
          signet: const Signet(
            routePattern: '/form',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'form',
          ),
          routePattern: '/form',
          displayName: 'Form',
          interactiveElements: [
            OutpostElement(
              widgetType: 'TextField',
              label: 'Name',
              interactionType: 'textInput', // Not a tap
              isInteractive: true,
            ),
          ],
        );
        scout.terrain.outposts['/form'] = outpost;

        // TextField has textInput, not tap — not sortie-able
        expect(scout.generateSortie('/form'), isNull);
      });

      test('sortie timeout scales with unexplored count', () {
        final outpost = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
          interactiveElements: [
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'A',
              interactionType: 'tap',
              isInteractive: true,
            ),
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'B',
              interactionType: 'tap',
              isInteractive: true,
            ),
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'C',
              interactionType: 'tap',
              isInteractive: true,
            ),
          ],
        );
        scout.terrain.outposts['/home'] = outpost;

        final sortie = scout.generateSortie('/home')!;
        // 3 unexplored × 10 seconds = 30 seconds
        expect(sortie.timeout, const Duration(seconds: 30));
      });
    });

    group('generateAllSorties', () {
      test('returns empty for fully explored Terrain', () {
        scout.terrain.outposts['/home'] = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
        );

        final sorties = scout.generateAllSorties();
        expect(sorties, isEmpty);
      });

      test('generates sorties for all partially-explored screens', () {
        final homeOutpost = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'abc',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
          interactiveElements: [
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Settings',
              interactionType: 'tap',
              isInteractive: true,
            ),
          ],
        );
        scout.terrain.outposts['/home'] = homeOutpost;

        final settingsOutpost = Outpost(
          signet: const Signet(
            routePattern: '/settings',
            interactiveDescriptors: [],
            hash: 'def',
            identity: 'settings',
          ),
          routePattern: '/settings',
          displayName: 'Settings',
          interactiveElements: [
            OutpostElement(
              widgetType: 'ElevatedButton',
              label: 'Theme',
              interactionType: 'tap',
              isInteractive: true,
            ),
          ],
        );
        scout.terrain.outposts['/settings'] = settingsOutpost;

        final sorties = scout.generateAllSorties();
        expect(sorties, hasLength(2));
      });
    });

    group('detectAuthPatterns', () {
      test('marks screen as requiresAuth when it redirects to login', () {
        final loginOutpost = Outpost(
          signet: const Signet(
            routePattern: '/login',
            interactiveDescriptors: [],
            hash: 'login',
            identity: 'login',
          ),
          routePattern: '/login',
          displayName: 'Login',
          tags: ['auth'],
        );
        final dashboardOutpost = Outpost(
          signet: const Signet(
            routePattern: '/dashboard',
            interactiveDescriptors: [],
            hash: 'dash',
            identity: 'dashboard',
          ),
          routePattern: '/dashboard',
          displayName: 'Dashboard',
        );

        // Dashboard redirects to login
        dashboardOutpost.exits.add(
          March(
            fromRoute: '/dashboard',
            toRoute: '/login',
            trigger: MarchTrigger.redirect,
          ),
        );

        scout.terrain.outposts['/login'] = loginOutpost;
        scout.terrain.outposts['/dashboard'] = dashboardOutpost;

        scout.detectAuthPatterns();
        expect(dashboardOutpost.requiresAuth, true);
      });

      test('does not mark screen when redirect is not to login', () {
        final homeOutpost = Outpost(
          signet: const Signet(
            routePattern: '/home',
            interactiveDescriptors: [],
            hash: 'home',
            identity: 'home',
          ),
          routePattern: '/home',
          displayName: 'Home',
        );
        final aboutOutpost = Outpost(
          signet: const Signet(
            routePattern: '/about',
            interactiveDescriptors: [],
            hash: 'about',
            identity: 'about',
          ),
          routePattern: '/about',
          displayName: 'About',
        );

        homeOutpost.exits.add(
          March(
            fromRoute: '/home',
            toRoute: '/about',
            trigger: MarchTrigger.redirect,
          ),
        );

        scout.terrain.outposts['/home'] = homeOutpost;
        scout.terrain.outposts['/about'] = aboutOutpost;

        scout.detectAuthPatterns();
        expect(homeOutpost.requiresAuth, false);
      });
    });

    group('withTerrain', () {
      test('uses provided Terrain', () {
        final terrain = Terrain();
        terrain.outposts['/preloaded'] = Outpost(
          signet: const Signet(
            routePattern: '/preloaded',
            interactiveDescriptors: [],
            hash: 'pre',
            identity: 'preloaded',
          ),
          routePattern: '/preloaded',
          displayName: 'Preloaded',
        );

        final custom = Scout.withTerrain(terrain);
        expect(custom.terrain.hasRoute('/preloaded'), true);
        expect(custom.terrain.screenCount, 1);
      });
    });

    group('route parameterization integration', () {
      test('parameterizes routes in Marches', () {
        final s1 = createSession(
          tableaux: [
            createTableau(index: 0, route: '/home', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/quest/42',
              timestamp: const Duration(seconds: 2),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
          ],
        );
        final s2 = createSession(
          tableaux: [
            createTableau(index: 0, route: '/home', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/quest/7',
              timestamp: const Duration(seconds: 2),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
          ],
        );

        scout.analyzeSession(s1);
        scout.analyzeSession(s2);

        // Both /quest/42 and /quest/7 should map to /quest/:id
        expect(scout.terrain.hasRoute('/quest/:id'), true);
      });
    });

    group('March merging', () {
      test('merges duplicate Marches across sessions', () {
        ShadeSession makeSession() => createSession(
          tableaux: [
            createTableau(index: 0, route: '/login', timestamp: Duration.zero),
            createTableau(
              index: 1,
              route: '/home',
              timestamp: const Duration(seconds: 2),
            ),
          ],
          imprints: [
            createImprint(
              type: ImprintType.pointerUp,
              timestamp: const Duration(seconds: 1),
            ),
          ],
        );

        scout.analyzeSession(makeSession());
        scout.analyzeSession(makeSession());

        final exits = scout.terrain.outposts['/login']!.exits;
        expect(exits, hasLength(1));
        expect(exits.first.observationCount, 2);
        expect(exits.first.isReliable, true);
      });
    });
  });
}
