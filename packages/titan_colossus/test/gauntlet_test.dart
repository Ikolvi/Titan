import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Outpost createOutpost({
    String route = '/test',
    String displayName = 'Test',
    List<OutpostElement>? interactive,
    List<String>? tags,
    List<March>? exits,
    List<March>? entrances,
    bool requiresAuth = false,
  }) {
    return Outpost(
      signet: Signet(
        routePattern: route,
        interactiveDescriptors: const [],
        hash: 'abc',
        identity: 'test',
      ),
      routePattern: route,
      displayName: displayName,
      interactiveElements: interactive,
      tags: tags,
      exits: exits,
      entrances: entrances,
      requiresAuth: requiresAuth,
    );
  }

  OutpostElement button({String? label, String? key}) => OutpostElement(
    widgetType: 'ElevatedButton',
    label: label ?? 'Submit',
    interactionType: 'tap',
    semanticRole: 'button',
    isInteractive: true,
    key: key,
  );

  OutpostElement textField({String? label, String? key}) => OutpostElement(
    widgetType: 'TextField',
    label: label ?? 'Email',
    interactionType: 'textInput',
    semanticRole: 'textField',
    isInteractive: true,
    key: key,
  );

  OutpostElement slider({String? label}) => OutpostElement(
    widgetType: 'Slider',
    label: label ?? 'Volume',
    interactionType: 'slider',
    isInteractive: true,
  );

  OutpostElement toggle({String? label}) => OutpostElement(
    widgetType: 'Switch',
    label: label ?? 'Dark Mode',
    interactionType: 'toggle',
    isInteractive: true,
  );

  OutpostElement dropdown({String? label}) => OutpostElement(
    widgetType: 'DropdownButton',
    label: label ?? 'Category',
    interactionType: 'dropdown',
    isInteractive: true,
  );

  March createMarch({
    String from = '/a',
    String to = '/b',
    MarchTrigger trigger = MarchTrigger.tap,
  }) {
    return March(fromRoute: from, toRoute: to, trigger: trigger);
  }

  // -------------------------------------------------------------------------
  // GauntletPattern catalog
  // -------------------------------------------------------------------------

  group('GauntletPattern catalog', () {
    test('has 24 patterns', () {
      expect(Gauntlet.catalog, hasLength(24));
    });

    test('all patterns have unique IDs', () {
      final ids = Gauntlet.catalog.map((p) => p.id).toSet();
      expect(ids.length, 24);
    });

    test('covers all 5 categories', () {
      final categories = Gauntlet.catalog.map((p) => p.category).toSet();
      expect(categories, containsAll(GauntletCategory.values));
    });

    test('interaction stress has 5 patterns', () {
      final patterns = Gauntlet.patternsForCategory(
        GauntletCategory.interactionStress,
      );
      expect(patterns, hasLength(5));
    });

    test('input boundaries has 7 patterns', () {
      final patterns = Gauntlet.patternsForCategory(
        GauntletCategory.inputBoundaries,
      );
      expect(patterns, hasLength(7));
    });

    test('navigation stress has 4 patterns', () {
      final patterns = Gauntlet.patternsForCategory(
        GauntletCategory.navigationStress,
      );
      expect(patterns, hasLength(4));
    });

    test('state integrity has 5 patterns', () {
      final patterns = Gauntlet.patternsForCategory(
        GauntletCategory.stateIntegrity,
      );
      expect(patterns, hasLength(5));
    });

    test('timing async has 3 patterns', () {
      final patterns = Gauntlet.patternsForCategory(
        GauntletCategory.timingAsync,
      );
      expect(patterns, hasLength(3));
    });

    test('critical risk patterns exist', () {
      final critical = Gauntlet.patternsForRisk(GauntletRisk.critical);
      expect(critical, isNotEmpty);
      expect(
        critical.map((p) => p.id),
        containsAll(['rapid_fire', 'double_submit']),
      );
    });

    test('pattern toJson round-trip', () {
      final pattern = Gauntlet.catalog.first;
      final json = pattern.toJson();

      expect(json['id'], pattern.id);
      expect(json['name'], pattern.name);
      expect(json['category'], pattern.category.name);
      expect(json['risk'], pattern.risk.name);
    });

    test('pattern toString', () {
      final pattern = Gauntlet.catalog.first;
      expect(pattern.toString(), contains(pattern.id));
    });

    test('all patterns have non-empty descriptions', () {
      for (final p in Gauntlet.catalog) {
        expect(
          p.description,
          isNotEmpty,
          reason: '${p.id} missing description',
        );
      }
    });

    test('all patterns have applicable interaction types', () {
      for (final p in Gauntlet.catalog) {
        expect(
          p.applicableInteractionTypes,
          isNotEmpty,
          reason: '${p.id} missing interaction types',
        );
      }
    });

    test('specific pattern IDs match spec', () {
      final ids = Gauntlet.catalog.map((p) => p.id).toSet();
      expect(
        ids,
        containsAll([
          'rapid_fire',
          'double_submit',
          'tab_storm',
          'mid_flight_tap',
          'retreat_under_fire',
          'hollow_strike',
          'overflow_scroll',
          'rune_injection',
          'glyph_storm',
          'phantom_text',
          'titan_count',
          'edge_of_range',
          'full_retreat',
          'ambush_arrival',
          'eternal_march',
          'bedrock_back',
          'switch_frenzy',
          'slider_tempest',
          'choice_reversal',
          'half_inscription',
          'forgotten_outpost',
          'patient_siege',
          'avalanche_scroll',
          'impatient_general',
        ]),
      );
    });
  });

  // -------------------------------------------------------------------------
  // Interaction Stress
  // -------------------------------------------------------------------------

  group('Gauntlet interaction stress', () {
    test('rapid_fire for each tap element', () {
      final outpost = createOutpost(
        interactive: [
          button(label: 'OK'),
          button(label: 'Cancel'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final rapidFires = results.where(
        (s) => s.name.startsWith('gauntlet_rapid_fire'),
      );
      expect(rapidFires, hasLength(2));
    });

    test('rapid_fire has 5 tap steps with 50ms wait', () {
      final outpost = createOutpost(interactive: [button(label: 'Go')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final rf = results.firstWhere(
        (s) => s.name.startsWith('gauntlet_rapid_fire'),
      );
      expect(rf.steps, hasLength(5));
      for (final step in rf.steps) {
        expect(step.action, StratagemAction.tap);
        expect(step.waitAfter?.inMilliseconds, 50);
      }
    });

    test('rapid_fire uses continueAll policy', () {
      final outpost = createOutpost(interactive: [button(label: 'X')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final rf = results.first;
      expect(rf.failurePolicy, StratagemFailurePolicy.continueAll);
    });

    test('double_submit when form + submit button', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Email'),
          button(label: 'Submit'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ds = results.where(
        (s) => s.name.startsWith('gauntlet_double_submit'),
      );
      expect(ds, hasLength(1));
      expect(ds.first.steps, hasLength(3));
    });

    test('no double_submit without text fields', () {
      final outpost = createOutpost(interactive: [button(label: 'Submit')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ds = results.where(
        (s) => s.name.startsWith('gauntlet_double_submit'),
      );
      expect(ds, isEmpty);
    });

    test('no double_submit without submit button', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Notes'),
          button(label: 'Info'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ds = results.where(
        (s) => s.name.startsWith('gauntlet_double_submit'),
      );
      expect(ds, isEmpty);
    });

    test('tab_storm with 2+ text fields', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'First'),
          textField(label: 'Last'),
          button(label: 'Save'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ts = results.where((s) => s.name.startsWith('gauntlet_tab_storm'));
      expect(ts, hasLength(1));
      expect(ts.first.steps, hasLength(2));
    });

    test('no tab_storm with single text field', () {
      final outpost = createOutpost(interactive: [textField(label: 'Solo')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ts = results.where((s) => s.name.startsWith('gauntlet_tab_storm'));
      expect(ts, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Input Boundaries
  // -------------------------------------------------------------------------

  group('Gauntlet input boundaries', () {
    test('hollow_strike if text fields + submit', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Name'),
          textField(label: 'Email'),
          button(label: 'Register'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final hs = results.where(
        (s) => s.name.startsWith('gauntlet_hollow_strike'),
      );
      expect(hs, hasLength(1));
      // 2 clearText + 1 tap
      expect(hs.first.steps, hasLength(3));
    });

    test('rune_injection per text field per special input', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Name'),
          button(label: 'Save'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ri = results.where(
        (s) => s.name.startsWith('gauntlet_rune_injection'),
      );
      // 7 special inputs × 1 field = 7
      expect(ri, hasLength(7));
    });

    test('rune_injection multiplied by field count', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'First'),
          textField(label: 'Last'),
          button(label: 'Save'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ri = results.where(
        (s) => s.name.startsWith('gauntlet_rune_injection'),
      );
      // 7 special inputs × 2 fields = 14
      expect(ri, hasLength(14));
    });

    test('rune_injection steps have clearFirst', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Email'),
          button(label: 'Submit'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final ri = results.firstWhere(
        (s) => s.name.startsWith('gauntlet_rune_injection'),
      );
      expect(ri.steps.first.clearFirst, true);
    });

    test('edge_of_range for sliders', () {
      final outpost = createOutpost(interactive: [slider(label: 'Volume')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final eor = results.where(
        (s) => s.name.startsWith('gauntlet_edge_of_range'),
      );
      expect(eor, hasLength(1));
      expect(eor.first.steps, hasLength(3)); // min, max, verify
    });

    test('no input boundary patterns without text/slider', () {
      final outpost = createOutpost(interactive: [button(label: 'OK')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final inputPatterns = results.where((s) => s.tags.contains('input'));
      expect(inputPatterns, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Navigation Stress
  // -------------------------------------------------------------------------

  group('Gauntlet navigation stress', () {
    test('full_retreat for screens with entrances', () {
      final march = createMarch(from: '/a', to: '/test');
      final outpost = createOutpost(route: '/test', entrances: [march]);
      final results = Gauntlet.generateFor(outpost);

      final fr = results.where(
        (s) => s.name.startsWith('gauntlet_full_retreat'),
      );
      expect(fr, hasLength(1));
      expect(fr.first.steps, hasLength(10));
    });

    test('bedrock_back for root screens (no entrances)', () {
      final outpost = createOutpost(route: '/home');
      final results = Gauntlet.generateFor(outpost);

      final bb = results.where(
        (s) => s.name.startsWith('gauntlet_bedrock_back'),
      );
      expect(bb, hasLength(1));
      expect(bb.first.steps, hasLength(2)); // back + verify
    });

    test('eternal_march for screens with exits', () {
      final march = createMarch(from: '/test', to: '/other');
      final outpost = createOutpost(exits: [march]);
      final results = Gauntlet.generateFor(outpost);

      final em = results.where(
        (s) => s.name.startsWith('gauntlet_eternal_march'),
      );
      expect(em, hasLength(1));
      // 5 cycles × 2 steps (navigate + back) = 10
      expect(em.first.steps, hasLength(10));
    });

    test('no navigation patterns at quick intensity', () {
      final march = createMarch(from: '/a', to: '/test');
      final outpost = createOutpost(
        entrances: [march],
        exits: [createMarch(from: '/test', to: '/b')],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final navPatterns = results.where((s) => s.tags.contains('navigation'));
      expect(navPatterns, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // State Integrity
  // -------------------------------------------------------------------------

  group('Gauntlet state integrity', () {
    test('switch_frenzy for toggles', () {
      final outpost = createOutpost(interactive: [toggle(label: 'Dark Mode')]);
      final results = Gauntlet.generateFor(outpost);

      final sf = results.where(
        (s) => s.name.startsWith('gauntlet_switch_frenzy'),
      );
      expect(sf, hasLength(1));
      expect(sf.first.steps, hasLength(10));
    });

    test('slider_tempest for sliders', () {
      final outpost = createOutpost(interactive: [slider(label: 'Volume')]);
      final results = Gauntlet.generateFor(outpost);

      final st = results.where(
        (s) => s.name.startsWith('gauntlet_slider_tempest'),
      );
      expect(st, hasLength(1));
      // 5 cycles × 2 (min + max) = 10
      expect(st.first.steps, hasLength(10));
    });

    test('choice_reversal for dropdowns', () {
      final outpost = createOutpost(interactive: [dropdown(label: 'Category')]);
      final results = Gauntlet.generateFor(outpost);

      final cr = results.where(
        (s) => s.name.startsWith('gauntlet_choice_reversal'),
      );
      expect(cr, hasLength(1));
      expect(cr.first.steps, hasLength(4)); // A, B, A, verify
    });

    test('half_inscription with 2+ text fields', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'First'),
          textField(label: 'Last'),
          button(label: 'Submit'),
        ],
      );
      final results = Gauntlet.generateFor(outpost);

      final hi = results.where(
        (s) => s.name.startsWith('gauntlet_half_inscription'),
      );
      expect(hi, hasLength(1));
      // enterText + tap submit + verify = 3
      expect(hi.first.steps, hasLength(3));
    });

    test('forgotten_outpost for screens with exits', () {
      final march = createMarch(from: '/test', to: '/other');
      final outpost = createOutpost(exits: [march]);
      final results = Gauntlet.generateFor(outpost);

      final fo = results.where(
        (s) => s.name.startsWith('gauntlet_forgotten_outpost'),
      );
      expect(fo, hasLength(1));
      expect(fo.first.steps, hasLength(3)); // navigate, back, verify
    });

    test('no state integrity patterns at quick intensity', () {
      final outpost = createOutpost(
        interactive: [toggle(), slider(), dropdown()],
        exits: [createMarch(from: '/test', to: '/b')],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final statePatterns = results.where((s) => s.tags.contains('state'));
      expect(statePatterns, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Timing & Async
  // -------------------------------------------------------------------------

  group('Gauntlet timing & async', () {
    test('patient_siege at thorough intensity', () {
      final outpost = createOutpost(interactive: [button(label: 'Action')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      final ps = results.where(
        (s) => s.name.startsWith('gauntlet_patient_siege'),
      );
      expect(ps, hasLength(1));
      expect(ps.first.steps.first.action, StratagemAction.longPress);
    });

    test('no timing patterns at standard intensity', () {
      final outpost = createOutpost(
        interactive: [button(label: 'Go')],
        tags: ['scrollable'],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.standard,
      );

      final timing = results.where((s) => s.tags.contains('timing'));
      expect(timing, isEmpty);
    });

    test('avalanche_scroll for scrollable screens', () {
      final outpost = createOutpost(
        interactive: [button(label: 'Action')],
        tags: ['scrollable'],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      final as_ = results.where(
        (s) => s.name.startsWith('gauntlet_avalanche_scroll'),
      );
      expect(as_, hasLength(1));
      // 10 cycles × 2 (down + up) = 20
      expect(as_.first.steps, hasLength(20));
    });

    test('no avalanche_scroll without scrollable tag', () {
      final outpost = createOutpost(interactive: [button(label: 'X')]);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      final as_ = results.where(
        (s) => s.name.startsWith('gauntlet_avalanche_scroll'),
      );
      expect(as_, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Intensity filtering
  // -------------------------------------------------------------------------

  group('Gauntlet intensity', () {
    test('quick generates fewest patterns', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Name'),
          button(label: 'Submit'),
          toggle(),
          slider(),
        ],
        tags: ['scrollable'],
        exits: [createMarch(from: '/test', to: '/b')],
        entrances: [createMarch(from: '/a', to: '/test')],
      );

      final quick = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );
      final standard = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.standard,
      );
      final thorough = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      expect(quick.length, lessThan(standard.length));
      expect(standard.length, lessThan(thorough.length));
    });

    test('quick includes interaction stress and input boundaries', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Email'),
          button(label: 'Login'),
        ],
      );
      final quick = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      expect(quick.any((s) => s.tags.contains('stress')), true);
      expect(quick.any((s) => s.tags.contains('input')), true);
    });

    test('standard adds navigation and state', () {
      final exit = createMarch(from: '/test', to: '/b');
      final outpost = createOutpost(interactive: [toggle()], exits: [exit]);
      final standard = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.standard,
      );

      expect(standard.any((s) => s.tags.contains('state')), true);
      expect(standard.any((s) => s.tags.contains('navigation')), true);
    });

    test('thorough adds timing patterns', () {
      final outpost = createOutpost(
        interactive: [button(label: 'Go')],
        tags: ['scrollable'],
      );
      final thorough = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      expect(thorough.any((s) => s.tags.contains('timing')), true);
    });
  });

  // -------------------------------------------------------------------------
  // Lineage integration
  // -------------------------------------------------------------------------

  group('Gauntlet lineage integration', () {
    test('attaches preconditions from lineage', () {
      final outpost = createOutpost(interactive: [button(label: 'Go')]);
      final terrain = Terrain(
        outposts: {
          '/login': createOutpost(route: '/login'),
          '/test': outpost,
        },
      );
      terrain.outposts['/login']!.exits.add(
        createMarch(from: '/login', to: '/test'),
      );
      terrain.outposts['/test']!.entrances.add(
        createMarch(from: '/login', to: '/test'),
      );

      final lineage = Lineage.resolve(terrain, targetRoute: '/test');
      final results = Gauntlet.generateFor(
        outpost,
        lineage: lineage,
        intensity: GauntletIntensity.quick,
      );

      expect(results, isNotEmpty);
      expect(results.first.preconditions?['setupStratagem'], isNotNull);
    });

    test('no preconditions when lineage is empty', () {
      final outpost = createOutpost(interactive: [button(label: 'Go')]);
      final terrain = Terrain(outposts: {'/home': outpost});
      final lineage = Lineage.resolve(terrain, targetRoute: '/home');
      final results = Gauntlet.generateFor(
        outpost,
        lineage: lineage,
        intensity: GauntletIntensity.quick,
      );

      expect(results, isNotEmpty);
      expect(results.first.preconditions, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // generateForElement
  // -------------------------------------------------------------------------

  group('Gauntlet generateForElement', () {
    test('tap element generates rapid_fire', () {
      final elem = button(label: 'Click');
      final outpost = createOutpost(interactive: [elem]);
      final results = Gauntlet.generateForElement(outpost, elem);

      expect(results, hasLength(1));
      expect(results.first.name, contains('rapid_fire'));
    });

    test('textInput element generates rune_injection variants', () {
      final elem = textField(label: 'Name');
      final outpost = createOutpost(interactive: [elem]);
      final results = Gauntlet.generateForElement(outpost, elem);

      expect(results, hasLength(7)); // 7 special inputs
    });

    test('slider element generates edge_of_range', () {
      final elem = slider(label: 'Brightness');
      final outpost = createOutpost(interactive: [elem]);
      final results = Gauntlet.generateForElement(outpost, elem);

      expect(results, hasLength(1));
      expect(results.first.name, contains('edge_of_range'));
    });

    test('toggle element generates switch_frenzy', () {
      final elem = toggle(label: 'Notifications');
      final outpost = createOutpost(interactive: [elem]);
      final results = Gauntlet.generateForElement(outpost, elem);

      expect(results, hasLength(1));
      expect(results.first.name, contains('switch_frenzy'));
    });

    test('dropdown element generates choice_reversal', () {
      final elem = dropdown(label: 'Size');
      final outpost = createOutpost(interactive: [elem]);
      final results = Gauntlet.generateForElement(outpost, elem);

      expect(results, hasLength(1));
      expect(results.first.name, contains('choice_reversal'));
    });
  });

  // -------------------------------------------------------------------------
  // Stratagem metadata
  // -------------------------------------------------------------------------

  group('Gauntlet Stratagem metadata', () {
    test('all generated Stratagems have gauntlet tag', () {
      final outpost = createOutpost(
        interactive: [
          textField(),
          button(label: 'Submit'),
          toggle(),
        ],
        exits: [createMarch(from: '/test', to: '/b')],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      for (final s in results) {
        expect(
          s.tags,
          contains('gauntlet'),
          reason: '${s.name} missing gauntlet tag',
        );
      }
    });

    test('all generated Stratagems use continueAll', () {
      final outpost = createOutpost(
        interactive: [
          textField(),
          button(label: 'Login'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      for (final s in results) {
        expect(
          s.failurePolicy,
          StratagemFailurePolicy.continueAll,
          reason: '${s.name} should use continueAll',
        );
      }
    });

    test('all generated Stratagems have startRoute', () {
      final outpost = createOutpost(route: '/login');
      final results = Gauntlet.generateFor(
        createOutpost(
          route: '/login',
          interactive: [button(label: 'Go')],
        ),
        intensity: GauntletIntensity.quick,
      );

      for (final s in results) {
        expect(
          s.startRoute,
          '/login',
          reason: '${s.name} has wrong startRoute',
        );
      }
    });

    test('step IDs are sequential per Stratagem', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'A'),
          textField(label: 'B'),
          button(label: 'Submit'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      for (final s in results) {
        for (var i = 0; i < s.steps.length; i++) {
          expect(
            s.steps[i].id,
            i + 1,
            reason: '${s.name} step ${i + 1} has wrong ID',
          );
        }
      }
    });
  });

  // -------------------------------------------------------------------------
  // Edge cases
  // -------------------------------------------------------------------------

  group('Gauntlet edge cases', () {
    test('empty outpost generates no Stratagems', () {
      final outpost = createOutpost(interactive: []);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      expect(results, isEmpty);
    });

    test('outpost with only display elements generates empty', () {
      // Display elements are not interactive
      final outpost = createOutpost(interactive: []);
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      // No interactive elements → no interaction/input/state patterns
      // Bedrock back only (root screen)
      expect(results.where((s) => !s.name.contains('bedrock_back')), isEmpty);
    });

    test('login screen generates many patterns', () {
      final outpost = createOutpost(
        route: '/login',
        displayName: 'Login Screen',
        interactive: [
          textField(label: 'Hero Name'),
          textField(label: 'Password'),
          button(label: 'Login'),
          button(label: 'Register'),
        ],
        tags: ['auth', 'form'],
        exits: [createMarch(from: '/login', to: '/')],
        entrances: [createMarch(from: '/', to: '/login')],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.standard,
      );

      // Should have many patterns for a complex form screen
      expect(results.length, greaterThanOrEqualTo(10));
    });

    test('submit-label detection works for various labels', () {
      for (final label in [
        'Submit',
        'Login',
        'Save',
        'Register',
        'Sign In',
        'Create Account',
        'Send Message',
        'Enter the Realm',
      ]) {
        final outpost = createOutpost(
          interactive: [
            textField(label: 'Data'),
            button(label: label),
          ],
        );
        final results = Gauntlet.generateFor(
          outpost,
          intensity: GauntletIntensity.quick,
        );

        final ds = results.where(
          (s) => s.name.startsWith('gauntlet_double_submit'),
        );
        expect(ds, hasLength(1), reason: '"$label" not detected as submit');
      }
    });

    test('key preserved in generated targets', () {
      final outpost = createOutpost(
        interactive: [button(label: 'Go', key: 'btn_go')],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      final rf = results.firstWhere(
        (s) => s.name.startsWith('gauntlet_rapid_fire'),
      );
      expect(rf.steps.first.target?.key, 'btn_go');
    });
  });

  // -------------------------------------------------------------------------
  // Integration
  // -------------------------------------------------------------------------

  group('Gauntlet integration', () {
    test('generated Stratagems serialize to JSON', () {
      final outpost = createOutpost(
        interactive: [
          textField(label: 'Email'),
          button(label: 'Submit'),
        ],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      for (final s in results) {
        final json = s.toJson();
        expect(json['name'], isNotNull);
        expect(json['steps'], isNotNull);

        // Round-trip
        final restored = Stratagem.fromJson(json);
        expect(restored.name, s.name);
        expect(restored.steps.length, s.steps.length);
      }
    });

    test('generated Stratagems have valid startRoute', () {
      final outpost = createOutpost(
        route: '/profile',
        interactive: [button(label: 'Edit')],
      );
      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.quick,
      );

      for (final s in results) {
        expect(s.startRoute, '/profile');
      }
    });

    test('full login screen at thorough generates all categories', () {
      final outpost = createOutpost(
        route: '/login',
        interactive: [
          textField(label: 'Username'),
          textField(label: 'Password'),
          button(label: 'Login'),
          toggle(label: 'Remember Me'),
        ],
        tags: ['auth', 'form', 'scrollable'],
        exits: [createMarch(from: '/login', to: '/')],
        entrances: [createMarch(from: '/', to: '/login')],
      );

      final results = Gauntlet.generateFor(
        outpost,
        intensity: GauntletIntensity.thorough,
      );

      // Should have patterns from all categories
      expect(results.any((s) => s.tags.contains('stress')), true);
      expect(results.any((s) => s.tags.contains('input')), true);
      expect(results.any((s) => s.tags.contains('navigation')), true);
      expect(results.any((s) => s.tags.contains('state')), true);
      expect(results.any((s) => s.tags.contains('timing')), true);
    });
  });
}
