// ---------------------------------------------------------------------------
// Lineage — Prerequisite chain resolution for screen testing
// ---------------------------------------------------------------------------

import '../testing/stratagem.dart';
import 'march.dart';
import 'outpost.dart';
import 'terrain.dart';

// ---------------------------------------------------------------------------
// StratagemPrerequisite — A single step in a prerequisite chain
// ---------------------------------------------------------------------------

/// A single prerequisite in a [Lineage] chain.
///
/// Each prerequisite represents an action the test runner must complete
/// before the target screen can be reached (login, navigate, fill form, etc.).
///
/// ## Example
///
/// ```dart
/// final prereq = StratagemPrerequisite(
///   description: 'Log in with hero name',
///   stratagem: loginStratagem,
///   isAuthGate: true,
///   isFormGate: true,
/// );
/// print(prereq.estimatedDuration); // Duration(seconds: 2)
/// ```
class StratagemPrerequisite {
  /// Human-readable description.
  final String description;

  /// The [Stratagem] that satisfies this prerequisite.
  final Stratagem stratagem;

  /// Whether this is an authentication gate.
  final bool isAuthGate;

  /// Whether this is a form submission gate.
  final bool isFormGate;

  /// Estimated execution time.
  final Duration estimatedDuration;

  /// Creates a [StratagemPrerequisite].
  const StratagemPrerequisite({
    required this.description,
    required this.stratagem,
    this.isAuthGate = false,
    this.isFormGate = false,
    this.estimatedDuration = const Duration(seconds: 2),
  });

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'description': description,
    'isAuthGate': isAuthGate,
    'isFormGate': isFormGate,
    'estimatedDurationMs': estimatedDuration.inMilliseconds,
    'stratagem': stratagem.toJson(),
  };

  /// Parse from JSON map.
  factory StratagemPrerequisite.fromJson(Map<String, dynamic> json) {
    return StratagemPrerequisite(
      description: json['description'] as String,
      stratagem: Stratagem.fromJson(json['stratagem'] as Map<String, dynamic>),
      isAuthGate: json['isAuthGate'] as bool? ?? false,
      isFormGate: json['isFormGate'] as bool? ?? false,
      estimatedDuration: Duration(
        milliseconds: json['estimatedDurationMs'] as int? ?? 2000,
      ),
    );
  }

  @override
  String toString() =>
      'StratagemPrerequisite($description, auth=$isAuthGate, form=$isFormGate)';
}

// ---------------------------------------------------------------------------
// Lineage — Full prerequisite chain for reaching a screen
// ---------------------------------------------------------------------------

/// **Lineage** — Prerequisite chain for reaching a screen.
///
/// Tells AI what steps must be completed before a target screen
/// can be tested. Built automatically from the [Terrain] graph.
///
/// ## Example
///
/// ```dart
/// final lineage = Lineage.resolve(terrain, targetRoute: '/quest/42');
/// print(lineage.requiresAuth);         // true
/// print(lineage.prerequisites.length); // 2
///
/// // Generate a single setup Stratagem
/// final setup = lineage.toSetupStratagem();
/// await runner.execute(setup);
/// // Now on /quest/42, ready for real tests
/// ```
class Lineage {
  /// The target screen this Lineage leads to.
  final String targetRoute;

  /// Ordered prerequisite Stratagems (must execute in order).
  ///
  /// Each prerequisite is a complete [Stratagem] that sets up
  /// one part of the path to the target screen.
  final List<StratagemPrerequisite> prerequisites;

  /// The shortest path through the Terrain to reach the target.
  final List<March> path;

  /// Whether authentication is required anywhere in the chain.
  bool get requiresAuth => prerequisites.any((p) => p.isAuthGate);

  /// Total estimated time to execute all prerequisites.
  Duration get estimatedSetupTime =>
      prerequisites.fold(Duration.zero, (sum, p) => sum + p.estimatedDuration);

  /// Whether there are no prerequisites (target is directly reachable).
  bool get isEmpty => prerequisites.isEmpty;

  /// Whether prerequisites exist.
  bool get isNotEmpty => prerequisites.isNotEmpty;

  /// Number of hops from entry point to target.
  int get hopCount => path.length;

  /// Create a Lineage from its components.
  const Lineage._({
    required this.targetRoute,
    required this.prerequisites,
    required this.path,
  });

  // -----------------------------------------------------------------------
  // Resolution
  // -----------------------------------------------------------------------

  /// Resolve the prerequisite chain from a [Terrain].
  ///
  /// Finds the shortest path from any entry point to the target route,
  /// then converts each transition into a prerequisite [Stratagem].
  ///
  /// ```dart
  /// final terrain = Scout.instance.terrain;
  /// final lineage = Lineage.resolve(terrain, targetRoute: '/dashboard');
  /// print(lineage.prerequisites); // [login_prerequisite]
  /// ```
  factory Lineage.resolve(Terrain terrain, {required String targetRoute}) {
    // Target is an entry point — no prerequisites needed
    if (terrain.outposts.containsKey(targetRoute)) {
      final outpost = terrain.outposts[targetRoute]!;
      if (outpost.entrances.isEmpty) {
        return Lineage._(targetRoute: targetRoute, prerequisites: [], path: []);
      }
    }

    // Find shortest path from any entry point to target
    final entryPoints = terrain.entryPoints;
    List<March>? bestPath;

    for (final entry in entryPoints) {
      final path = terrain.shortestPath(entry.routePattern, targetRoute);
      if (path != null && (bestPath == null || path.length < bestPath.length)) {
        bestPath = path;
      }
    }

    if (bestPath == null) {
      return Lineage._(targetRoute: targetRoute, prerequisites: [], path: []);
    }

    // Convert path to prerequisite Stratagems
    final prerequisites = _buildPrerequisites(bestPath, terrain);

    return Lineage._(
      targetRoute: targetRoute,
      prerequisites: prerequisites,
      path: bestPath,
    );
  }

  // -----------------------------------------------------------------------
  // Setup Stratagem generation
  // -----------------------------------------------------------------------

  /// Generate a setup [Stratagem] that chains all prerequisites.
  ///
  /// Returns a single [Stratagem] that, when executed, will navigate
  /// from the app's initial state to the target screen, ready for testing.
  ///
  /// ```dart
  /// final setup = lineage.toSetupStratagem(testData: {'heroName': 'Thorin'});
  /// final verdict = await runner.execute(setup);
  /// // Now on the target screen
  /// ```
  Stratagem toSetupStratagem({Map<String, dynamic>? testData}) {
    final allSteps = <StratagemStep>[];
    var stepId = 1;

    for (final prereq in prerequisites) {
      for (final step in prereq.stratagem.steps) {
        allSteps.add(
          StratagemStep(
            id: stepId++,
            action: step.action,
            description: '[Setup] ${step.description}',
            target: step.target,
            value: step.value,
            clearFirst: step.clearFirst,
            expectations: step.expectations,
            waitAfter: step.waitAfter,
            navigateRoute: step.navigateRoute,
          ),
        );
      }
    }

    final startRoute = prerequisites.isNotEmpty
        ? prerequisites.first.stratagem.startRoute
        : targetRoute;

    return Stratagem(
      name: 'setup_for${targetRoute.replaceAll('/', '_')}',
      description: 'Auto-generated setup to reach $targetRoute',
      tags: const ['setup', 'auto-generated'],
      startRoute: startRoute,
      testData: testData,
      steps: allSteps,
      failurePolicy: StratagemFailurePolicy.abortOnFirst,
    );
  }

  // -----------------------------------------------------------------------
  // AI output
  // -----------------------------------------------------------------------

  /// AI-readable summary of the prerequisite chain.
  String toAiSummary() {
    final buffer = StringBuffer();
    buffer.writeln('LINEAGE: Reaching $targetRoute');
    buffer.writeln('AUTH REQUIRED: $requiresAuth');
    buffer.writeln('ESTIMATED SETUP: ${estimatedSetupTime.inSeconds}s');
    buffer.writeln('PREREQUISITES (${prerequisites.length}):');
    for (var i = 0; i < prerequisites.length; i++) {
      buffer.writeln('  ${i + 1}. ${prerequisites[i].description}');
    }
    if (path.isNotEmpty) {
      buffer.writeln(
        'PATH: ${path.map((m) => '${m.fromRoute} → ${m.toRoute}').join(' → ')}',
      );
    }
    return buffer.toString();
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    r'$schema': 'titan://lineage/v1',
    'targetRoute': targetRoute,
    'requiresAuth': requiresAuth,
    'estimatedSetupMs': estimatedSetupTime.inMilliseconds,
    'hopCount': hopCount,
    'path': path
        .map(
          (m) => {
            'from': m.fromRoute,
            'to': m.toRoute,
            'trigger': m.trigger.name,
          },
        )
        .toList(),
    'prerequisites': prerequisites.map((p) => p.toJson()).toList(),
  };

  /// Parse from JSON map.
  factory Lineage.fromJson(Map<String, dynamic> json) {
    return Lineage._(
      targetRoute: json['targetRoute'] as String,
      prerequisites: (json['prerequisites'] as List)
          .map((e) => StratagemPrerequisite.fromJson(e as Map<String, dynamic>))
          .toList(),
      path: (json['path'] as List)
          .map(
            (e) => March(
              fromRoute: (e as Map<String, dynamic>)['from'] as String,
              toRoute: e['to'] as String,
              trigger: MarchTrigger.values.firstWhere(
                (t) => t.name == e['trigger'],
                orElse: () => MarchTrigger.unknown,
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  String toString() =>
      'Lineage($targetRoute, ${prerequisites.length} prerequisites, '
      '${path.length} hops)';

  // -----------------------------------------------------------------------
  // Internal — prerequisite building
  // -----------------------------------------------------------------------

  /// Build prerequisite Stratagems from a path of Marches.
  static List<StratagemPrerequisite> _buildPrerequisites(
    List<March> path,
    Terrain terrain,
  ) {
    final prerequisites = <StratagemPrerequisite>[];

    for (final march in path) {
      final sourceOutpost = terrain.outposts[march.fromRoute];
      final isAuth = _isAuthGate(sourceOutpost, march);
      final isForm = _isFormGate(sourceOutpost, march);

      final steps = _buildStepsForMarch(
        march,
        sourceOutpost,
        isAuth: isAuth,
        isForm: isForm,
      );

      final description = _describePrerequisite(
        march,
        isAuth: isAuth,
        isForm: isForm,
      );

      final estimatedMs = _estimateDuration(march, isForm: isForm);

      prerequisites.add(
        StratagemPrerequisite(
          description: description,
          stratagem: Stratagem(
            name: _prerequisiteName(march, isAuth: isAuth),
            description: description,
            tags: ['prerequisite', if (isAuth) 'auth', if (isForm) 'form'],
            startRoute: march.fromRoute,
            steps: steps,
            failurePolicy: StratagemFailurePolicy.abortOnFirst,
          ),
          isAuthGate: isAuth,
          isFormGate: isForm,
          estimatedDuration: Duration(milliseconds: estimatedMs),
        ),
      );
    }

    return prerequisites;
  }

  /// Determine if a March is an authentication gate.
  static bool _isAuthGate(Outpost? source, March march) {
    if (source == null) return false;

    // Check if source is tagged as auth / has form-submit trigger
    if (source.tags.contains('auth') &&
        march.trigger == MarchTrigger.formSubmit) {
      return true;
    }

    // Check for redirect pattern (march trigger is redirect)
    if (march.trigger == MarchTrigger.redirect) {
      return true;
    }

    // Check if source has password-like fields
    return _hasPasswordField(source);
  }

  /// Determine if a March is a form submission gate.
  static bool _isFormGate(Outpost? source, March march) {
    if (source == null) return false;
    if (march.trigger == MarchTrigger.formSubmit) return true;
    return source.tags.contains('form');
  }

  /// Check if an Outpost has a password-like field.
  static bool _hasPasswordField(Outpost outpost) {
    for (final element in outpost.interactiveElements) {
      final label = element.label?.toLowerCase() ?? '';
      if (label.contains('password') ||
          label.contains('secret') ||
          label.contains('pin')) {
        return true;
      }
    }
    return false;
  }

  /// Build Stratagem steps for a single March transition.
  static List<StratagemStep> _buildStepsForMarch(
    March march,
    Outpost? source, {
    required bool isAuth,
    required bool isForm,
  }) {
    final steps = <StratagemStep>[];
    var stepId = 1;

    if (isForm && source != null) {
      // Add steps for each form field
      for (final element in source.interactiveElements) {
        if (element.widgetType == 'TextField' ||
            element.widgetType == 'TextFormField') {
          steps.add(
            StratagemStep(
              id: stepId++,
              action: StratagemAction.enterText,
              description: 'Enter ${element.label ?? "text"}',
              target: StratagemTarget(
                label: element.label,
                type: element.widgetType,
                key: element.key,
              ),
              value: _testDataPlaceholder(element.label),
              clearFirst: true,
            ),
          );
        }
      }
    }

    // Add the transition action
    switch (march.trigger) {
      case MarchTrigger.tap:
      case MarchTrigger.formSubmit:
        steps.add(
          StratagemStep(
            id: stepId++,
            action: StratagemAction.tap,
            description: march.triggerElementLabel != null
                ? 'Tap "${march.triggerElementLabel}"'
                : 'Tap to navigate to ${march.toRoute}',
            target: StratagemTarget(
              label: march.triggerElementLabel,
              type: march.triggerElementType,
              key: march.triggerElementKey,
            ),
            expectations: StratagemExpectations(route: march.toRoute),
          ),
        );
      case MarchTrigger.back:
        steps.add(
          StratagemStep(
            id: stepId++,
            action: StratagemAction.back,
            description: 'Navigate back to ${march.toRoute}',
            expectations: StratagemExpectations(route: march.toRoute),
          ),
        );
      case MarchTrigger.swipe:
        steps.add(
          StratagemStep(
            id: stepId++,
            action: StratagemAction.swipe,
            description: 'Swipe to ${march.toRoute}',
            swipeDirection: 'left',
            expectations: StratagemExpectations(route: march.toRoute),
          ),
        );
      case MarchTrigger.deepLink:
      case MarchTrigger.programmatic:
      case MarchTrigger.redirect:
      case MarchTrigger.unknown:
        steps.add(
          StratagemStep(
            id: stepId++,
            action: StratagemAction.navigate,
            description: 'Navigate to ${march.toRoute}',
            navigateRoute: march.toRoute,
            expectations: StratagemExpectations(route: march.toRoute),
          ),
        );
    }

    return steps;
  }

  /// Generate a testData placeholder for a form field.
  static String _testDataPlaceholder(String? label) {
    if (label == null) return r'${testData.value}';
    final key = label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '\${testData.$key}';
  }

  /// Generate a human-readable description for a prerequisite.
  static String _describePrerequisite(
    March march, {
    required bool isAuth,
    required bool isForm,
  }) {
    if (isAuth) {
      return 'Authenticate on ${march.fromRoute}';
    }
    if (isForm) {
      return 'Submit form on ${march.fromRoute}';
    }
    if (march.triggerElementLabel != null) {
      return 'Tap "${march.triggerElementLabel}" on ${march.fromRoute}';
    }
    return 'Navigate from ${march.fromRoute} to ${march.toRoute}';
  }

  /// Generate a unique prerequisite name.
  static String _prerequisiteName(March march, {required bool isAuth}) {
    final from = march.fromRoute.replaceAll('/', '_').replaceAll(':', '');
    final to = march.toRoute.replaceAll('/', '_').replaceAll(':', '');
    if (isAuth) return 'auth_prereq$from';
    return 'prereq${from}_to$to';
  }

  /// Estimate execution duration (milliseconds).
  static int _estimateDuration(March march, {required bool isForm}) {
    // Form submissions take longer (typing + submit)
    if (isForm) return 3000;
    // Other transitions based on observed average or default
    if (march.averageDurationMs > 0) return march.averageDurationMs;
    return 1500;
  }
}
