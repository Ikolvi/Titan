// ---------------------------------------------------------------------------
// Gauntlet — Edge-case pattern generator for stress & boundary testing
// ---------------------------------------------------------------------------

import 'dart:ui' show Offset;

import '../testing/stratagem.dart';
import 'lineage.dart';
import 'outpost.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Gauntlet test intensity — controls how many patterns are generated.
enum GauntletIntensity {
  /// Essential edge cases only (~5-10 per screen).
  quick,

  /// Standard coverage (~10-20 per screen).
  standard,

  /// Exhaustive stress testing (~20-40 per screen).
  thorough,
}

/// Categories of edge-case testing.
enum GauntletCategory {
  /// Rapid taps, double submits, mid-transition actions.
  interactionStress,

  /// Empty inputs, special characters, overflow, slider extremes.
  inputBoundaries,

  /// Rapid back, deep link, circular navigation.
  navigationStress,

  /// Toggle storms, slider dance, partial fills, stale screens.
  stateIntegrity,

  /// Long press, scroll spam, abandoned async.
  timingAsync,
}

/// Risk level of a Gauntlet pattern.
enum GauntletRisk {
  /// Could crash the app.
  critical,

  /// Could cause incorrect behavior.
  high,

  /// Could cause visual glitches.
  medium,

  /// Cosmetic or minor UX issue.
  low,
}

// ---------------------------------------------------------------------------
// GauntletPattern — Named edge-case pattern
// ---------------------------------------------------------------------------

/// A named edge-case pattern in the [Gauntlet] catalog.
///
/// Each pattern describes a specific stress test or boundary condition
/// and the element types it applies to.
///
/// ```dart
/// final catalog = Gauntlet.catalog;
/// for (final pattern in catalog) {
///   print('${pattern.id}: ${pattern.description}');
/// }
/// ```
class GauntletPattern {
  /// Pattern identifier (e.g., `"rapid_fire"`).
  final String id;

  /// Human-readable name (e.g., `"Rapid-Fire Tap"`).
  final String name;

  /// Description of what this pattern tests.
  final String description;

  /// Which element interaction types this pattern applies to.
  final List<String> applicableInteractionTypes;

  /// Edge-case category.
  final GauntletCategory category;

  /// Risk level being tested.
  final GauntletRisk risk;

  /// The minimum [GauntletIntensity] required to include this pattern.
  final GauntletIntensity minimumIntensity;

  /// Creates a [GauntletPattern].
  const GauntletPattern({
    required this.id,
    required this.name,
    required this.description,
    required this.applicableInteractionTypes,
    required this.category,
    required this.risk,
    this.minimumIntensity = GauntletIntensity.standard,
  });

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'applicableInteractionTypes': applicableInteractionTypes,
    'category': category.name,
    'risk': risk.name,
    'minimumIntensity': minimumIntensity.name,
  };

  @override
  String toString() => 'GauntletPattern($id, ${category.name}, ${risk.name})';
}

// ---------------------------------------------------------------------------
// Gauntlet — Static edge-case pattern generator
// ---------------------------------------------------------------------------

/// **Gauntlet** — Edge-case pattern generator.
///
/// Analyzes an [Outpost] and generates stress-test [Stratagem]s
/// based on the elements present on screen.
///
/// ## Philosophy
///
/// "A tester doesn't just verify the happy path — they hammer
/// every gate, pick every lock, and rattle every hinge."
///
/// ## Usage
///
/// ```dart
/// final outpost = terrain.outposts['/login']!;
/// final edgeCases = Gauntlet.generateFor(outpost);
/// print(edgeCases.length); // ~15 edge-case Stratagems
/// for (final s in edgeCases) {
///   print('${s.name}: ${s.description}');
/// }
/// ```
class Gauntlet {
  // Prevent instantiation.
  Gauntlet._();

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  /// Generate all applicable edge-case [Stratagem]s for a screen.
  ///
  /// Analyzes the [Outpost]'s elements and returns [Stratagem]s that
  /// test interaction stress, input boundaries, navigation stress,
  /// state integrity, and timing edge cases.
  ///
  /// Optionally provide a [Lineage] to auto-inject prerequisite
  /// setup into generated Stratagems.
  static List<Stratagem> generateFor(
    Outpost outpost, {
    Lineage? lineage,
    GauntletIntensity intensity = GauntletIntensity.standard,
  }) {
    final stratagems = <Stratagem>[];

    final preconditions = lineage != null && lineage.isNotEmpty
        ? <String, dynamic>{
            'setupStratagem': lineage.toSetupStratagem().name,
          }
        : null;

    // Category 1: Interaction Stress
    stratagems.addAll(_interactionStress(outpost, preconditions));

    // Category 2: Input Boundaries
    stratagems.addAll(_inputBoundaries(outpost, preconditions));

    // Category 3: Navigation Stress (standard+)
    if (intensity.index >= GauntletIntensity.standard.index) {
      stratagems.addAll(_navigationStress(outpost, preconditions));
    }

    // Category 4: State Integrity (standard+)
    if (intensity.index >= GauntletIntensity.standard.index) {
      stratagems.addAll(_stateIntegrity(outpost, preconditions));
    }

    // Category 5: Timing & Async (thorough only)
    if (intensity == GauntletIntensity.thorough) {
      stratagems.addAll(_timingEdgeCases(outpost, preconditions));
    }

    return stratagems;
  }

  /// Generate edge cases for a specific element on a screen.
  static List<Stratagem> generateForElement(
    Outpost outpost,
    OutpostElement element, {
    Lineage? lineage,
  }) {
    final preconditions = lineage != null && lineage.isNotEmpty
        ? <String, dynamic>{
            'setupStratagem': lineage.toSetupStratagem().name,
          }
        : null;

    final results = <Stratagem>[];

    switch (element.interactionType) {
      case 'tap':
        results.add(_rapidFireTap(outpost, element, preconditions));
      case 'textInput':
        results.addAll(_inputBoundariesForField(
          outpost,
          element,
          preconditions,
        ));
      case 'slider':
        results.add(_sliderExtremes(outpost, element, preconditions));
      case 'toggle':
        results.add(_switchFrenzy(outpost, element, preconditions));
      case 'dropdown':
        results.add(_choiceReversal(outpost, element, preconditions));
      default:
        break;
    }

    return results;
  }

  /// Get the full catalog of available patterns.
  static List<GauntletPattern> get catalog => _catalog;

  /// Get patterns filtered by category.
  static List<GauntletPattern> patternsForCategory(GauntletCategory cat) =>
      _catalog.where((p) => p.category == cat).toList();

  /// Get patterns filtered by risk level.
  static List<GauntletPattern> patternsForRisk(GauntletRisk risk) =>
      _catalog.where((p) => p.risk == risk).toList();

  // -----------------------------------------------------------------------
  // Category 1: Interaction Stress
  // -----------------------------------------------------------------------

  static List<Stratagem> _interactionStress(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    final results = <Stratagem>[];

    final tappables = outpost.interactiveElements
        .where((e) => e.interactionType == 'tap')
        .toList();

    // rapid_fire — for each button
    for (final elem in tappables) {
      results.add(_rapidFireTap(outpost, elem, preconditions));
    }

    // double_submit — if form + submit
    final hasTextInput = outpost.interactiveElements.any(
      (e) => e.interactionType == 'textInput',
    );
    final submitBtn = _findSubmitButton(outpost);
    if (hasTextInput && submitBtn != null) {
      results.add(_doubleSubmit(outpost, submitBtn, preconditions));
    }

    // tab_storm — if 2+ text fields
    final textFields = outpost.interactiveElements
        .where((e) => e.interactionType == 'textInput')
        .toList();
    if (textFields.length >= 2) {
      results.add(_tabStorm(outpost, textFields, preconditions));
    }

    return results;
  }

  static Stratagem _rapidFireTap(
    Outpost outpost,
    OutpostElement element,
    Map<String, dynamic>? preconditions,
  ) {
    const tapCount = 5;
    return Stratagem(
      name:
          'gauntlet_rapid_fire_${_slugify(element.label ?? element.widgetType)}',
      description:
          'Rapid-fire tap ${element.label ?? element.widgetType} $tapCount times',
      tags: const ['gauntlet', 'stress', 'rapid-tap'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: List.generate(
        tapCount,
        (i) => StratagemStep(
          id: i + 1,
          action: StratagemAction.tap,
          description: 'Rapid tap #${i + 1}',
          target: StratagemTarget(
            label: element.label,
            type: element.widgetType,
            key: element.key,
          ),
          waitAfter: const Duration(milliseconds: 50),
        ),
      ),
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _doubleSubmit(
    Outpost outpost,
    OutpostElement submitBtn,
    Map<String, dynamic>? preconditions,
  ) {
    return Stratagem(
      name: 'gauntlet_double_submit_${_slugify(outpost.routePattern)}',
      description: 'Submit form twice rapidly on ${outpost.displayName}',
      tags: const ['gauntlet', 'stress', 'double-submit'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        StratagemStep(
          id: 1,
          action: StratagemAction.tap,
          description: 'First submit',
          target: StratagemTarget(
            label: submitBtn.label,
            type: submitBtn.widgetType,
          ),
          waitAfter: const Duration(milliseconds: 50),
        ),
        StratagemStep(
          id: 2,
          action: StratagemAction.tap,
          description: 'Second submit (rapid double-tap)',
          target: StratagemTarget(
            label: submitBtn.label,
            type: submitBtn.widgetType,
          ),
          waitAfter: const Duration(seconds: 2),
        ),
        const StratagemStep(
          id: 3,
          action: StratagemAction.verify,
          description: 'Verify no crash or double-action',
          expectations: StratagemExpectations(
            settleTimeout: Duration(seconds: 3),
          ),
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _tabStorm(
    Outpost outpost,
    List<OutpostElement> textFields,
    Map<String, dynamic>? preconditions,
  ) {
    return Stratagem(
      name: 'gauntlet_tab_storm_${_slugify(outpost.routePattern)}',
      description: 'Rapidly tab through ${textFields.length} text fields',
      tags: const ['gauntlet', 'stress', 'tab-storm'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        ...textFields.asMap().entries.map(
              (e) => StratagemStep(
                id: e.key + 1,
                action: StratagemAction.tap,
                description: 'Focus ${e.value.label ?? "field ${e.key + 1}"}',
                target: StratagemTarget(
                  label: e.value.label,
                  type: e.value.widgetType,
                  key: e.value.key,
                ),
                waitAfter: const Duration(milliseconds: 50),
              ),
            ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  // -----------------------------------------------------------------------
  // Category 2: Input Boundaries
  // -----------------------------------------------------------------------

  static List<Stratagem> _inputBoundaries(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    final results = <Stratagem>[];

    final textFields = outpost.interactiveElements
        .where((e) => e.interactionType == 'textInput')
        .toList();

    if (textFields.isNotEmpty) {
      // hollow_strike — empty submit
      final submitBtn = _findSubmitButton(outpost);
      if (submitBtn != null) {
        results.add(_hollowStrike(outpost, textFields, submitBtn,
            preconditions));
      }

      // rune_injection — special chars per field
      for (final field in textFields) {
        results.addAll(_inputBoundariesForField(
          outpost,
          field,
          preconditions,
        ));
      }
    }

    // edge_of_range — slider extremes
    final sliders = outpost.interactiveElements
        .where((e) => e.interactionType == 'slider')
        .toList();
    for (final slider in sliders) {
      results.add(_sliderExtremes(outpost, slider, preconditions));
    }

    return results;
  }

  static List<Stratagem> _inputBoundariesForField(
    Outpost outpost,
    OutpostElement field,
    Map<String, dynamic>? preconditions,
  ) {
    final results = <Stratagem>[];
    final fieldSlug = _slugify(field.label ?? 'field');

    // Special character inputs
    final specialInputs = <String, String>{
      'xss': '<script>alert("xss")</script>',
      'emoji': '🔥💀🎭€£¥',
      'rtl': 'مرحبا بالعالم',
      'whitespace': '   \t\n   ',
      'overflow': 'A' * 10000,
      'sql': "Robert'); DROP TABLE Students;--",
      'path': '../../../etc/passwd',
    };

    for (final entry in specialInputs.entries) {
      results.add(Stratagem(
        name: 'gauntlet_rune_injection_${fieldSlug}_${entry.key}',
        description:
            'Enter ${entry.key} in ${field.label ?? "field"}',
        tags: const ['gauntlet', 'input', 'special-chars'],
        startRoute: outpost.routePattern,
        preconditions: preconditions,
        steps: [
          StratagemStep(
            id: 1,
            action: StratagemAction.enterText,
            description: 'Enter ${entry.key} text',
            target: StratagemTarget(
              label: field.label,
              type: field.widgetType,
              key: field.key,
            ),
            value: entry.value,
            clearFirst: true,
          ),
          const StratagemStep(
            id: 2,
            action: StratagemAction.verify,
            description: 'Verify no crash after special input',
          ),
        ],
        failurePolicy: StratagemFailurePolicy.continueAll,
      ));
    }

    return results;
  }

  static Stratagem _hollowStrike(
    Outpost outpost,
    List<OutpostElement> textFields,
    OutpostElement submitBtn,
    Map<String, dynamic>? preconditions,
  ) {
    var stepId = 1;
    return Stratagem(
      name: 'gauntlet_hollow_strike_${_slugify(outpost.routePattern)}',
      description: 'Submit form with all fields empty',
      tags: const ['gauntlet', 'input', 'empty-submit'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        ...textFields.map(
          (f) => StratagemStep(
            id: stepId++,
            action: StratagemAction.clearText,
            description: 'Clear ${f.label ?? "field"}',
            target: StratagemTarget(
              label: f.label,
              type: f.widgetType,
              key: f.key,
            ),
          ),
        ),
        StratagemStep(
          id: stepId,
          action: StratagemAction.tap,
          description: 'Submit empty form',
          target: StratagemTarget(
            label: submitBtn.label,
            type: submitBtn.widgetType,
          ),
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _sliderExtremes(
    Outpost outpost,
    OutpostElement slider,
    Map<String, dynamic>? preconditions,
  ) {
    return Stratagem(
      name:
          'gauntlet_edge_of_range_${_slugify(slider.label ?? "slider")}',
      description: 'Drag ${slider.label ?? "slider"} to extremes',
      tags: const ['gauntlet', 'input', 'slider-extremes'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        StratagemStep(
          id: 1,
          action: StratagemAction.adjustSlider,
          description: 'Drag to minimum',
          target: StratagemTarget(
            label: slider.label,
            type: slider.widgetType,
            key: slider.key,
          ),
          value: '0',
        ),
        StratagemStep(
          id: 2,
          action: StratagemAction.adjustSlider,
          description: 'Drag to maximum',
          target: StratagemTarget(
            label: slider.label,
            type: slider.widgetType,
            key: slider.key,
          ),
          value: '1',
        ),
        const StratagemStep(
          id: 3,
          action: StratagemAction.verify,
          description: 'Verify slider state after extremes',
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  // -----------------------------------------------------------------------
  // Category 3: Navigation Stress
  // -----------------------------------------------------------------------

  static List<Stratagem> _navigationStress(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    final results = <Stratagem>[];

    // full_retreat — rapid back presses
    if (outpost.entrances.isNotEmpty) {
      results.add(_fullRetreat(outpost, preconditions));
    }

    // bedrock_back — back from root
    if (outpost.entrances.isEmpty) {
      results.add(_bedrockBack(outpost, preconditions));
    }

    // eternal_march — circular navigation (if outpost has exits)
    if (outpost.exits.isNotEmpty) {
      results.add(_eternalMarch(outpost, preconditions));
    }

    return results;
  }

  static Stratagem _fullRetreat(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    const backCount = 10;
    return Stratagem(
      name: 'gauntlet_full_retreat_${_slugify(outpost.routePattern)}',
      description: 'Press back $backCount times rapidly',
      tags: const ['gauntlet', 'navigation', 'rapid-back'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: List.generate(
        backCount,
        (i) => StratagemStep(
          id: i + 1,
          action: StratagemAction.back,
          description: 'Back press #${i + 1}',
          waitAfter: const Duration(milliseconds: 100),
        ),
      ),
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _bedrockBack(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    return Stratagem(
      name: 'gauntlet_bedrock_back_${_slugify(outpost.routePattern)}',
      description: 'Press back from root screen ${outpost.displayName}',
      tags: const ['gauntlet', 'navigation', 'bedrock-back'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: const [
        StratagemStep(
          id: 1,
          action: StratagemAction.back,
          description: 'Back from root',
        ),
        StratagemStep(
          id: 2,
          action: StratagemAction.verify,
          description: 'Verify app did not crash',
          expectations: StratagemExpectations(
            settleTimeout: Duration(seconds: 2),
          ),
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _eternalMarch(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    const cycles = 5;
    final target = outpost.exits.first.toRoute;
    final steps = <StratagemStep>[];
    var stepId = 1;

    for (var i = 0; i < cycles; i++) {
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.navigate,
        description: 'Navigate to $target (cycle ${i + 1})',
        navigateRoute: target,
        waitAfter: const Duration(milliseconds: 200),
      ));
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.back,
        description: 'Back to ${outpost.routePattern} (cycle ${i + 1})',
        waitAfter: const Duration(milliseconds: 200),
      ));
    }

    return Stratagem(
      name: 'gauntlet_eternal_march_${_slugify(outpost.routePattern)}',
      description:
          'Circular navigation ${outpost.routePattern} ↔ $target ($cycles cycles)',
      tags: const ['gauntlet', 'navigation', 'circular'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: steps,
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  // -----------------------------------------------------------------------
  // Category 4: State Integrity
  // -----------------------------------------------------------------------

  static List<Stratagem> _stateIntegrity(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    final results = <Stratagem>[];

    // switch_frenzy — for each toggle
    for (final elem in outpost.interactiveElements) {
      if (elem.interactionType == 'toggle') {
        results.add(_switchFrenzy(outpost, elem, preconditions));
      }
    }

    // slider_tempest — for each slider
    for (final elem in outpost.interactiveElements) {
      if (elem.interactionType == 'slider') {
        results.add(_sliderTempest(outpost, elem, preconditions));
      }
    }

    // choice_reversal — for each dropdown
    for (final elem in outpost.interactiveElements) {
      if (elem.interactionType == 'dropdown') {
        results.add(_choiceReversal(outpost, elem, preconditions));
      }
    }

    // half_inscription — if 2+ text fields
    final textFields = outpost.interactiveElements
        .where((e) => e.interactionType == 'textInput')
        .toList();
    if (textFields.length >= 2) {
      results.add(_halfInscription(outpost, textFields, preconditions));
    }

    // forgotten_outpost — if screen has exits (can navigate away and back)
    if (outpost.exits.isNotEmpty) {
      results.add(_forgottenOutpost(outpost, preconditions));
    }

    return results;
  }

  static Stratagem _switchFrenzy(
    Outpost outpost,
    OutpostElement element,
    Map<String, dynamic>? preconditions,
  ) {
    const toggleCount = 10;
    return Stratagem(
      name:
          'gauntlet_switch_frenzy_${_slugify(element.label ?? element.widgetType)}',
      description:
          'Toggle ${element.label ?? element.widgetType} $toggleCount times',
      tags: const ['gauntlet', 'state', 'toggle-storm'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: List.generate(
        toggleCount,
        (i) => StratagemStep(
          id: i + 1,
          action: StratagemAction.toggleSwitch,
          description: 'Toggle #${i + 1}',
          target: StratagemTarget(
            label: element.label,
            type: element.widgetType,
            key: element.key,
          ),
          waitAfter: const Duration(milliseconds: 50),
        ),
      ),
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _sliderTempest(
    Outpost outpost,
    OutpostElement slider,
    Map<String, dynamic>? preconditions,
  ) {
    const cycles = 5;
    final steps = <StratagemStep>[];
    var stepId = 1;

    for (var i = 0; i < cycles; i++) {
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.adjustSlider,
        description: 'Drag to min (cycle ${i + 1})',
        target: StratagemTarget(
          label: slider.label,
          type: slider.widgetType,
          key: slider.key,
        ),
        value: '0',
        waitAfter: const Duration(milliseconds: 50),
      ));
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.adjustSlider,
        description: 'Drag to max (cycle ${i + 1})',
        target: StratagemTarget(
          label: slider.label,
          type: slider.widgetType,
          key: slider.key,
        ),
        value: '1',
        waitAfter: const Duration(milliseconds: 50),
      ));
    }

    return Stratagem(
      name:
          'gauntlet_slider_tempest_${_slugify(slider.label ?? "slider")}',
      description:
          'Rapidly drag ${slider.label ?? "slider"} between extremes',
      tags: const ['gauntlet', 'state', 'slider-tempest'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: steps,
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _choiceReversal(
    Outpost outpost,
    OutpostElement dropdown,
    Map<String, dynamic>? preconditions,
  ) {
    return Stratagem(
      name:
          'gauntlet_choice_reversal_${_slugify(dropdown.label ?? "dropdown")}',
      description:
          'Select, change, and reselect ${dropdown.label ?? "dropdown"}',
      tags: const ['gauntlet', 'state', 'choice-reversal'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        StratagemStep(
          id: 1,
          action: StratagemAction.selectDropdown,
          description: 'Select first option',
          target: StratagemTarget(
            label: dropdown.label,
            type: dropdown.widgetType,
            key: dropdown.key,
          ),
          value: 'Option A',
        ),
        StratagemStep(
          id: 2,
          action: StratagemAction.selectDropdown,
          description: 'Change to second option',
          target: StratagemTarget(
            label: dropdown.label,
            type: dropdown.widgetType,
            key: dropdown.key,
          ),
          value: 'Option B',
        ),
        StratagemStep(
          id: 3,
          action: StratagemAction.selectDropdown,
          description: 'Reselect first option',
          target: StratagemTarget(
            label: dropdown.label,
            type: dropdown.widgetType,
            key: dropdown.key,
          ),
          value: 'Option A',
        ),
        const StratagemStep(
          id: 4,
          action: StratagemAction.verify,
          description: 'Verify state is consistent',
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _halfInscription(
    Outpost outpost,
    List<OutpostElement> textFields,
    Map<String, dynamic>? preconditions,
  ) {
    final steps = <StratagemStep>[];
    var stepId = 1;

    // Fill only the first field, leave rest empty
    steps.add(StratagemStep(
      id: stepId++,
      action: StratagemAction.enterText,
      description: 'Fill ${textFields.first.label ?? "first field"} only',
      target: StratagemTarget(
        label: textFields.first.label,
        type: textFields.first.widgetType,
        key: textFields.first.key,
      ),
      value: 'partial_data',
      clearFirst: true,
    ));

    // Tap submit if available
    final submitBtn = _findSubmitButton(outpost);
    if (submitBtn != null) {
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.tap,
        description: 'Submit partial form',
        target: StratagemTarget(
          label: submitBtn.label,
          type: submitBtn.widgetType,
        ),
      ));
    }

    steps.add(StratagemStep(
      id: stepId,
      action: StratagemAction.verify,
      description: 'Verify validation error displayed',
    ));

    return Stratagem(
      name: 'gauntlet_half_inscription_${_slugify(outpost.routePattern)}',
      description: 'Fill 1 of ${textFields.length} fields and submit',
      tags: const ['gauntlet', 'state', 'partial-fill'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: steps,
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _forgottenOutpost(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    final target = outpost.exits.first.toRoute;
    return Stratagem(
      name:
          'gauntlet_forgotten_outpost_${_slugify(outpost.routePattern)}',
      description:
          'Navigate away from ${outpost.displayName} and back, verify state',
      tags: const ['gauntlet', 'state', 'stale-screen'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        StratagemStep(
          id: 1,
          action: StratagemAction.navigate,
          description: 'Navigate away to $target',
          navigateRoute: target,
          waitAfter: const Duration(seconds: 1),
        ),
        const StratagemStep(
          id: 2,
          action: StratagemAction.back,
          description: 'Navigate back',
          waitAfter: Duration(seconds: 1),
        ),
        const StratagemStep(
          id: 3,
          action: StratagemAction.verify,
          description: 'Verify state persists after round-trip',
          expectations: StratagemExpectations(
            settleTimeout: Duration(seconds: 3),
          ),
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  // -----------------------------------------------------------------------
  // Category 5: Timing & Async
  // -----------------------------------------------------------------------

  static List<Stratagem> _timingEdgeCases(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    final results = <Stratagem>[];

    // patient_siege — long press each tappable
    final tappables = outpost.interactiveElements
        .where((e) => e.interactionType == 'tap')
        .toList();
    for (final elem in tappables) {
      results.add(_patientSiege(outpost, elem, preconditions));
    }

    // avalanche_scroll — if scrollable
    if (outpost.tags.contains('scrollable')) {
      results.add(_avalancheScroll(outpost, preconditions));
    }

    return results;
  }

  static Stratagem _patientSiege(
    Outpost outpost,
    OutpostElement element,
    Map<String, dynamic>? preconditions,
  ) {
    return Stratagem(
      name:
          'gauntlet_patient_siege_${_slugify(element.label ?? element.widgetType)}',
      description:
          'Long press ${element.label ?? element.widgetType} for 3 seconds',
      tags: const ['gauntlet', 'timing', 'long-press'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        StratagemStep(
          id: 1,
          action: StratagemAction.longPress,
          description: 'Long press ${element.label ?? "element"}',
          target: StratagemTarget(
            label: element.label,
            type: element.widgetType,
            key: element.key,
          ),
          waitAfter: const Duration(seconds: 3),
        ),
        const StratagemStep(
          id: 2,
          action: StratagemAction.verify,
          description: 'Verify no crash after long press',
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  static Stratagem _avalancheScroll(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    const cycles = 10;
    final steps = <StratagemStep>[];
    var stepId = 1;

    for (var i = 0; i < cycles; i++) {
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.scroll,
        description: 'Scroll down (cycle ${i + 1})',
        scrollDelta: const Offset(0, 500),
        waitAfter: const Duration(milliseconds: 50),
      ));
      steps.add(StratagemStep(
        id: stepId++,
        action: StratagemAction.scroll,
        description: 'Scroll up (cycle ${i + 1})',
        scrollDelta: const Offset(0, -500),
        waitAfter: const Duration(milliseconds: 50),
      ));
    }

    return Stratagem(
      name:
          'gauntlet_avalanche_scroll_${_slugify(outpost.routePattern)}',
      description: 'Rapidly scroll up and down $cycles times',
      tags: const ['gauntlet', 'timing', 'scroll-spam'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: steps,
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  /// Find the submit button on a screen.
  static OutpostElement? _findSubmitButton(Outpost outpost) {
    try {
      return outpost.interactiveElements.firstWhere(
        (e) => e.interactionType == 'tap' && _isSubmitLabel(e.label),
      );
    } catch (_) {
      return null;
    }
  }

  /// Whether a label indicates a submit action.
  static bool _isSubmitLabel(String? label) {
    if (label == null) return false;
    final lower = label.toLowerCase();
    return lower.contains('submit') ||
        lower.contains('login') ||
        lower.contains('save') ||
        lower.contains('register') ||
        lower.contains('sign') ||
        lower.contains('create') ||
        lower.contains('send') ||
        lower.contains('enter');
  }

  /// Slugify a string for use in Stratagem names.
  static String _slugify(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');

  // -----------------------------------------------------------------------
  // Pattern catalog (static)
  // -----------------------------------------------------------------------

  static const List<GauntletPattern> _catalog = [
    // Category 1: Interaction Stress
    GauntletPattern(
      id: 'rapid_fire',
      name: 'Rapid-Fire Tap',
      description: 'Tap same button 5 times quickly',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.interactionStress,
      risk: GauntletRisk.critical,
      minimumIntensity: GauntletIntensity.quick,
    ),
    GauntletPattern(
      id: 'double_submit',
      name: 'Double Submit',
      description: 'Submit form twice rapidly',
      applicableInteractionTypes: ['tap', 'textInput'],
      category: GauntletCategory.interactionStress,
      risk: GauntletRisk.critical,
      minimumIntensity: GauntletIntensity.quick,
    ),
    GauntletPattern(
      id: 'tab_storm',
      name: 'Tab Storm',
      description: 'Quickly tab through all form fields',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.interactionStress,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.quick,
    ),
    GauntletPattern(
      id: 'mid_flight_tap',
      name: 'Mid-Flight Tap',
      description: 'Tap button while page is transitioning',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.interactionStress,
      risk: GauntletRisk.high,
      minimumIntensity: GauntletIntensity.thorough,
    ),
    GauntletPattern(
      id: 'retreat_under_fire',
      name: 'Retreat Under Fire',
      description: 'Press back while async operation in progress',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.interactionStress,
      risk: GauntletRisk.high,
      minimumIntensity: GauntletIntensity.thorough,
    ),

    // Category 2: Input Boundaries
    GauntletPattern(
      id: 'hollow_strike',
      name: 'Hollow Strike',
      description: 'Submit form with all fields empty',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.inputBoundaries,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.quick,
    ),
    GauntletPattern(
      id: 'overflow_scroll',
      name: 'Overflow Scroll',
      description: 'Enter maximum-length text (10000 chars)',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.inputBoundaries,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'rune_injection',
      name: 'Rune Injection',
      description: 'Enter XSS, SQL injection, path traversal strings',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.inputBoundaries,
      risk: GauntletRisk.high,
      minimumIntensity: GauntletIntensity.quick,
    ),
    GauntletPattern(
      id: 'glyph_storm',
      name: 'Glyph Storm',
      description: 'Enter zalgo text, emoji sequences, CJK, RTL',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.inputBoundaries,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'phantom_text',
      name: 'Phantom Text',
      description: 'Enter only whitespace (spaces, tabs, newlines)',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.inputBoundaries,
      risk: GauntletRisk.low,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'titan_count',
      name: 'Titan Count',
      description: 'Enter very large/negative numbers',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.inputBoundaries,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'edge_of_range',
      name: 'Edge of Range',
      description: 'Drag slider to min, max, and beyond bounds',
      applicableInteractionTypes: ['slider'],
      category: GauntletCategory.inputBoundaries,
      risk: GauntletRisk.low,
      minimumIntensity: GauntletIntensity.quick,
    ),

    // Category 3: Navigation Stress
    GauntletPattern(
      id: 'full_retreat',
      name: 'Full Retreat',
      description: 'Press back 10 times rapidly',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.navigationStress,
      risk: GauntletRisk.high,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'ambush_arrival',
      name: 'Ambush Arrival',
      description: 'Navigate directly to deep route without setup',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.navigationStress,
      risk: GauntletRisk.high,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'eternal_march',
      name: 'Eternal March',
      description: 'Navigate A ↔ B repeatedly (5 cycles)',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.navigationStress,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'bedrock_back',
      name: 'Bedrock Back',
      description: 'Press back from root screen',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.navigationStress,
      risk: GauntletRisk.low,
      minimumIntensity: GauntletIntensity.standard,
    ),

    // Category 4: State Integrity
    GauntletPattern(
      id: 'switch_frenzy',
      name: 'Switch Frenzy',
      description: 'Toggle switch/checkbox 10 times in 500ms',
      applicableInteractionTypes: ['toggle'],
      category: GauntletCategory.stateIntegrity,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'slider_tempest',
      name: 'Slider Tempest',
      description: 'Drag slider min ↔ max 5 times rapidly',
      applicableInteractionTypes: ['slider'],
      category: GauntletCategory.stateIntegrity,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'choice_reversal',
      name: 'Choice Reversal',
      description: 'Select → change → reselect from dropdown',
      applicableInteractionTypes: ['dropdown'],
      category: GauntletCategory.stateIntegrity,
      risk: GauntletRisk.low,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'half_inscription',
      name: 'Half Inscription',
      description: 'Fill some fields, leave others, submit',
      applicableInteractionTypes: ['textInput'],
      category: GauntletCategory.stateIntegrity,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),
    GauntletPattern(
      id: 'forgotten_outpost',
      name: 'Forgotten Outpost',
      description: 'Navigate away and back — verify state persists',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.stateIntegrity,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.standard,
    ),

    // Category 5: Timing & Async
    GauntletPattern(
      id: 'patient_siege',
      name: 'Patient Siege',
      description: 'Long press 3s instead of tap',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.timingAsync,
      risk: GauntletRisk.low,
      minimumIntensity: GauntletIntensity.thorough,
    ),
    GauntletPattern(
      id: 'avalanche_scroll',
      name: 'Avalanche Scroll',
      description: 'Scroll rapidly in both directions 10 times',
      applicableInteractionTypes: ['scroll'],
      category: GauntletCategory.timingAsync,
      risk: GauntletRisk.medium,
      minimumIntensity: GauntletIntensity.thorough,
    ),
    GauntletPattern(
      id: 'impatient_general',
      name: 'Impatient General',
      description: 'Start async operation, navigate away immediately',
      applicableInteractionTypes: ['tap'],
      category: GauntletCategory.timingAsync,
      risk: GauntletRisk.high,
      minimumIntensity: GauntletIntensity.thorough,
    ),
  ];
}
