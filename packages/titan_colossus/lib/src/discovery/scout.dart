import '../recording/glyph.dart';
import '../recording/imprint.dart';
import '../recording/tableau.dart';
import '../testing/stratagem.dart';
import '../testing/verdict.dart';
import 'march.dart';
import 'outpost.dart';
import 'route_parameterizer.dart';
import 'terrain.dart';

// ---------------------------------------------------------------------------
// Scout — Flow Discovery Engine
// ---------------------------------------------------------------------------

/// **Scout** — flow discovery engine.
///
/// Observes the app through [ShadeSession]s and [Verdict] results
/// to build a [Terrain] — a complete map of the app's screens
/// and transitions.
///
/// ## Why "Scout"?
///
/// Before the siege begins, a scout maps every corridor and gate.
/// The Scout silently observes the app and reports its structure
/// back to the AI strategist.
///
/// ## How It Works
///
/// 1. User (or AI) browses the app with Shade recording active
/// 2. Scout analyzes the [ShadeSession]'s [Tableau] sequence
/// 3. Each unique screen becomes an [Outpost]
/// 4. Each route change becomes a [March]
/// 5. The [Terrain] grows with each observation
///
/// ## Discovery Strategies
///
/// ### Passive Discovery (Default)
///
/// Scout watches Shade sessions silently, building the Terrain
/// from normal app usage.
///
/// ```dart
/// final session = await Shade.instance.stopRecording();
/// Scout.instance.analyzeSession(session);
/// ```
///
/// ### Active Discovery (AI-Directed)
///
/// Scout generates exploration Stratagems that systematically
/// navigate to each interactive element on each screen, chasing
/// untapped buttons and unexplored routes.
///
/// ```dart
/// final sortie = Scout.instance.generateSortie('/login');
/// if (sortie != null) {
///   final verdict = await Colossus.instance.executeStratagem(sortie);
///   Scout.instance.analyzeVerdict(verdict);
/// }
/// ```
class Scout {
  /// Singleton instance (managed by Colossus).
  static Scout? _instance;

  /// Access the Scout singleton.
  ///
  /// Creates a new instance if one doesn't exist.
  static Scout get instance => _instance ??= Scout._();

  /// The accumulated flow graph.
  final Terrain terrain;

  /// Route parameterizer for detecting patterns like `/quest/:id`.
  final RouteParameterizer parameterizer;

  Scout._()
      : terrain = Terrain(),
        parameterizer = RouteParameterizer();

  /// Create a Scout with an existing Terrain (for testing/restoration).
  Scout.withTerrain(this.terrain) : parameterizer = RouteParameterizer();

  /// Reset the singleton instance.
  ///
  /// Primarily for testing.
  static void reset() {
    _instance = null;
  }

  // -----------------------------------------------------------------------
  // Passive Discovery
  // -----------------------------------------------------------------------

  /// Analyze a completed Shade session to update the Terrain.
  ///
  /// Extracts [Outpost]s and [March]es from the session's [Tableau]
  /// sequence. Call this after every Shade recording completes.
  ///
  /// ```dart
  /// final session = await Shade.instance.stopRecording();
  /// Scout.instance.analyzeSession(session);
  /// print(Scout.instance.terrain.screenCount); // grows
  /// ```
  void analyzeSession(ShadeSession session) {
    final tableaux = session.tableaux;
    if (tableaux.isEmpty) return;

    for (var i = 0; i < tableaux.length; i++) {
      final tableau = tableaux[i];
      _registerOutpost(tableau);

      if (i > 0) {
        final prev = tableaux[i - 1];
        final prevRoute = prev.route;
        final currRoute = tableau.route;

        if (prevRoute != null && currRoute != null && prevRoute != currRoute) {
          final trigger = _inferTrigger(
            session.imprints,
            prev,
            tableau,
          );
          final triggerGlyph = _findTriggerGlyph(
            session.imprints,
            prev,
            tableau,
          );

          _registerMarch(
            fromRoute: parameterizer.parameterize(prevRoute),
            toRoute: parameterizer.parameterize(currRoute),
            trigger: trigger,
            triggerGlyph: triggerGlyph,
            durationMs: (tableau.timestamp - prev.timestamp).inMilliseconds,
          );
        }
      }
    }

    terrain.sessionsAnalyzed++;
    terrain.lastUpdated = DateTime.now();
    terrain.invalidateCache();
  }

  /// Analyze a [Verdict] to update the Terrain.
  ///
  /// Uses the Verdict's captured [Tableau]x and per-step tableaux
  /// to discover screens and transitions. Optionally accepts the
  /// original [Stratagem] to infer trigger types from actions.
  ///
  /// Failed steps reveal dead ends or gated routes.
  void analyzeVerdict(Verdict verdict, {Stratagem? stratagem}) {
    // Register outposts from all captured tableaux
    for (final tableau in verdict.tableaux) {
      _registerOutpost(tableau);
    }

    // Detect route transitions between consecutive steps
    for (var i = 0; i < verdict.steps.length; i++) {
      final step = verdict.steps[i];

      if (step.tableau != null) {
        _registerOutpost(step.tableau!);
      }

      // Find route change from previous step
      if (i > 0) {
        final prevStep = verdict.steps[i - 1];
        final prevRoute = prevStep.tableau?.route;
        final currRoute = step.tableau?.route;

        if (prevRoute != null &&
            currRoute != null &&
            prevRoute != currRoute) {
          // Infer trigger from the original Stratagem action if available
          final trigger = stratagem != null && i < stratagem.steps.length
              ? _inferTriggerFromAction(stratagem.steps[i - 1].action)
              : MarchTrigger.unknown;

          _registerMarch(
            fromRoute: parameterizer.parameterize(prevRoute),
            toRoute: parameterizer.parameterize(currRoute),
            trigger: trigger,
            durationMs: step.duration.inMilliseconds,
          );
        }
      }

      // Detect auth redirects from failed steps
      if (step.status == VerdictStepStatus.failed && step.failure != null) {
        _analyzeFailedStep(step);
      }
    }

    terrain.stratagemExecutionsAnalyzed++;
    terrain.lastUpdated = DateTime.now();
    terrain.invalidateCache();
  }

  // -----------------------------------------------------------------------
  // Active Discovery
  // -----------------------------------------------------------------------

  /// Generate an exploration Stratagem for a specific screen.
  ///
  /// Creates a Stratagem that navigates to the target screen
  /// and taps every untried interactive element, discovering
  /// new transitions.
  ///
  /// Returns null if the screen has been fully explored or
  /// doesn't exist in the Terrain.
  Stratagem? generateSortie(String routePattern) {
    final outpost = terrain.outposts[routePattern];
    if (outpost == null) return null;

    // Find elements that haven't been explored
    final unexplored = outpost.interactiveElements.where((e) {
      if (e.interactionType != 'tap') return false;
      return !outpost.exits.any(
        (m) =>
            m.triggerElementLabel == e.label &&
            m.triggerElementType == e.widgetType,
      );
    }).toList();

    if (unexplored.isEmpty) return null;

    final steps = <StratagemStep>[];
    var stepId = 1;

    for (final elem in unexplored) {
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.tap,
        description: 'Explore: tap ${elem.label ?? elem.widgetType}',
        target: StratagemTarget(
          label: elem.label,
          type: elem.widgetType,
          key: elem.key,
        ),
        waitAfter: const Duration(seconds: 1),
      ));
      // Navigate back after each exploration tap
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.back,
        description: 'Return to explore next element',
        waitAfter: const Duration(milliseconds: 500),
      ));
    }

    return Stratagem(
      name: 'sortie${routePattern.replaceAll("/", "_").replaceAll(":", "")}',
      description: 'Active discovery of $routePattern '
          '(${unexplored.length} unexplored elements)',
      tags: const ['discovery', 'sortie'],
      startRoute: routePattern,
      steps: steps,
      failurePolicy: StratagemFailurePolicy.continueAll,
      timeout: Duration(seconds: unexplored.length * 10),
    );
  }

  /// Generate Sorties for all partially-explored screens.
  ///
  /// Returns a list of Stratagems for screens that have untapped
  /// interactive elements.
  List<Stratagem> generateAllSorties() {
    return terrain.outposts.keys
        .map(generateSortie)
        .whereType<Stratagem>()
        .toList();
  }

  // -----------------------------------------------------------------------
  // Auth Detection
  // -----------------------------------------------------------------------

  /// Analyze the Terrain to detect authentication-protected screens.
  ///
  /// Marks Outposts as `requiresAuth = true` if:
  /// 1. Every observed path to them passes through a login screen
  /// 2. A redirect March from them leads to a login screen
  void detectAuthPatterns() {
    // Find login screens
    final loginScreens = terrain.outposts.values.where((o) {
      return o.tags.contains('auth') ||
          o.tags.contains('form') &&
              o.routePattern.toLowerCase().contains('login');
    }).toList();

    if (loginScreens.isEmpty) return;

    // Find screens that redirect to login (auth guard pattern)
    for (final outpost in terrain.outposts.values) {
      for (final exit in outpost.exits) {
        if (exit.trigger == MarchTrigger.redirect) {
          final target = terrain.outposts[exit.toRoute];
          if (target != null && loginScreens.contains(target)) {
            outpost.requiresAuth = true;
          }
        }
      }
    }

    // Find screens only reachable after login
    for (final loginScreen in loginScreens) {
      for (final exit in loginScreen.exits) {
        if (exit.trigger == MarchTrigger.formSubmit ||
            exit.trigger == MarchTrigger.tap) {
          final postLoginScreens = terrain.reachableFrom(exit.toRoute);
          for (final screen in postLoginScreens) {
            // Check if this screen is reachable without login
            final isPublic = terrain.entryPoints.any((entry) {
              if (loginScreens.any((l) => l.routePattern == entry.routePattern)) {
                return false;
              }
              final path = terrain.shortestPath(
                entry.routePattern,
                screen.routePattern,
              );
              if (path == null) return false;
              // Check if any March in the path passes through login
              return !path.any((m) =>
                  loginScreens.any((l) => l.routePattern == m.fromRoute));
            });

            if (!isPublic) {
              screen.requiresAuth = true;
            }
          }
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  /// Register an Outpost from a Tableau observation.
  void _registerOutpost(Tableau tableau) {
    if (tableau.route == null) return;

    final route = parameterizer.parameterize(tableau.route!);

    // Consolidate any existing outposts whose routes now map to this
    // pattern (happens when the parameterizer retroactively identifies
    // a pattern after seeing a second variation, e.g. /quest/42 becomes
    // /quest/:id once /quest/7 is observed).
    _consolidateOutposts(route);

    final existing = terrain.outposts[route];

    if (existing != null) {
      existing.mergeObservation(tableau);
    } else {
      terrain.outposts[route] = Outpost.fromTableau(
        tableau,
        routePattern: route,
      );
    }
  }

  /// Merge any outposts whose raw route now maps to [pattern] into a
  /// single outpost under [pattern].
  void _consolidateOutposts(String pattern) {
    final keysToRemove = <String>[];
    for (final key in terrain.outposts.keys) {
      if (key != pattern && parameterizer.patternFor(key) == pattern) {
        keysToRemove.add(key);
      }
    }

    for (final oldKey in keysToRemove) {
      final old = terrain.outposts.remove(oldKey)!;
      final target = terrain.outposts[pattern];
      if (target != null) {
        target.observationCount += old.observationCount;
      } else {
        terrain.outposts[pattern] = old;
      }
    }
  }

  /// Register a March transition.
  void _registerMarch({
    required String fromRoute,
    required String toRoute,
    required MarchTrigger trigger,
    Glyph? triggerGlyph,
    int? durationMs,
  }) {
    final march = March(
      fromRoute: fromRoute,
      toRoute: toRoute,
      trigger: trigger,
      triggerElementLabel: triggerGlyph?.label,
      triggerElementType: triggerGlyph?.widgetType,
      triggerElementKey: triggerGlyph?.key,
      averageDurationMs: durationMs ?? 0,
    );

    // Add to source outpost exits
    final source = terrain.outposts[fromRoute];
    March resolvedMarch = march;
    if (source != null) {
      final existing = source.exits.cast<March?>().firstWhere(
            (m) => m!.matches(march),
            orElse: () => null,
          );
      if (existing != null) {
        existing.mergeObservation(march, durationMs: durationMs);
        resolvedMarch = existing;
      } else {
        source.exits.add(march);
      }
    }

    // Add to destination outpost entrances.
    // Use resolvedMarch so the same object is shared between exit / entrance
    // lists — avoid double-merging.
    final dest = terrain.outposts[toRoute];
    if (dest != null) {
      final alreadyTracked = dest.entrances.cast<March?>().firstWhere(
            (m) => m!.matches(march),
            orElse: () => null,
          );
      if (alreadyTracked == null) {
        dest.entrances.add(resolvedMarch);
      }
    }
  }

  /// Infer the trigger type from Imprints between two Tableaux.
  MarchTrigger _inferTrigger(
    List<Imprint> imprints,
    Tableau before,
    Tableau after,
  ) {
    // Find Imprints between the two Tableaux
    final betweenImprints = imprints.where((imp) {
      return imp.timestamp >= before.timestamp &&
          imp.timestamp <= after.timestamp;
    }).toList();

    if (betweenImprints.isEmpty) return MarchTrigger.redirect;

    // Check for text input followed by a tap (form submit)
    final hasTextInput =
        betweenImprints.any((i) => i.type == ImprintType.textInput);
    final hasTap = betweenImprints
        .any((i) => i.type == ImprintType.pointerUp);
    if (hasTextInput && hasTap) return MarchTrigger.formSubmit;

    // Check for swipe
    final hasPointerDown =
        betweenImprints.any((i) => i.type == ImprintType.pointerDown);
    final hasPointerMove =
        betweenImprints.where((i) => i.type == ImprintType.pointerMove);
    if (hasPointerDown && hasPointerMove.length > 5) {
      return MarchTrigger.swipe;
    }

    // Simple tap
    if (hasTap) return MarchTrigger.tap;

    return MarchTrigger.unknown;
  }

  /// Find the Glyph that was interacted with to trigger a transition.
  Glyph? _findTriggerGlyph(
    List<Imprint> imprints,
    Tableau before,
    Tableau after,
  ) {
    // Find pointerUp Imprints between the two Tableaux
    final pointerUps = imprints.where((imp) {
      return imp.type == ImprintType.pointerUp &&
          imp.timestamp >= before.timestamp &&
          imp.timestamp <= after.timestamp;
    });

    if (pointerUps.isEmpty) return null;

    // Last pointerUp is most likely the trigger
    final lastTap = pointerUps.last;
    return before.glyphAt(lastTap.positionX, lastTap.positionY);
  }

  /// Infer trigger type from a Stratagem action.
  MarchTrigger _inferTriggerFromAction(StratagemAction action) {
    return switch (action) {
      StratagemAction.tap ||
      StratagemAction.doubleTap ||
      StratagemAction.longPress =>
        MarchTrigger.tap,
      StratagemAction.submitField => MarchTrigger.formSubmit,
      StratagemAction.navigate => MarchTrigger.programmatic,
      StratagemAction.back => MarchTrigger.back,
      StratagemAction.swipe => MarchTrigger.swipe,
      _ => MarchTrigger.unknown,
    };
  }

  /// Analyze a failed Verdict step for auth redirect patterns.
  void _analyzeFailedStep(VerdictStep step) {
    // Detect auth redirect: expected route X, got login screen
    if (step.failure?.type == VerdictFailureType.wrongRoute) {
      final expected = step.failure?.expected;
      final actual = step.failure?.actual;
      if (expected != null && actual != null) {
        final actualRoute = parameterizer.parameterize(actual);
        final actualOutpost = terrain.outposts[actualRoute];
        if (actualOutpost != null && actualOutpost.tags.contains('auth')) {
          // This is an auth redirect
          final expectedRoute = parameterizer.parameterize(expected);
          final expectedOutpost = terrain.outposts[expectedRoute];
          if (expectedOutpost != null) {
            expectedOutpost.requiresAuth = true;
            _registerMarch(
              fromRoute: expectedRoute,
              toRoute: actualRoute,
              trigger: MarchTrigger.redirect,
            );
          }
        }
      }
    }
  }
}
