import 'package:test/test.dart';
import 'package:titan_colossus/src/testing/scry.dart';

void main() {
  const scry = Scry();

  // ----- Helper: build a glyph map -----
  Map<String, dynamic> glyph({
    required String label,
    String widgetType = 'Text',
    bool interactive = false,
    String? interactionType,
    String? semanticRole,
    String? fieldId,
    String? currentValue,
    bool enabled = true,
    List<String>? ancestors,
    double x = 0.0,
    double y = 0.0,
    double w = 100.0,
    double h = 40.0,
    int? depth,
    String? key,
  }) => {
    'wt': widgetType,
    'l': label,
    'ia': interactive,
    // ignore: use_null_aware_elements
    if (interactionType != null) 'it': interactionType,
    // ignore: use_null_aware_elements
    if (semanticRole != null) 'sr': semanticRole,
    // ignore: use_null_aware_elements
    if (fieldId != null) 'fid': fieldId,
    // ignore: use_null_aware_elements
    if (currentValue != null) 'cv': currentValue,
    if (!enabled) 'en': false,
    // ignore: use_null_aware_elements
    if (ancestors != null) 'anc': ancestors,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    // ignore: use_null_aware_elements
    if (depth != null) 'd': depth,
    // ignore: use_null_aware_elements
    if (key != null) 'k': key,
  };

  // ===================================================================
  // ScryElementKind
  // ===================================================================
  group('ScryElementKind', () {
    test('has all expected values', () {
      expect(ScryElementKind.values, hasLength(5));
      expect(ScryElementKind.values, contains(ScryElementKind.button));
      expect(ScryElementKind.values, contains(ScryElementKind.field));
      expect(ScryElementKind.values, contains(ScryElementKind.navigation));
      expect(ScryElementKind.values, contains(ScryElementKind.content));
      expect(ScryElementKind.values, contains(ScryElementKind.structural));
    });
  });

  // ===================================================================
  // ScryElement
  // ===================================================================
  group('ScryElement', () {
    test('toJson serializes all fields', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Sign Out',
        widgetType: 'IconButton',
        isInteractive: true,
        gated: true,
        semanticRole: 'button',
      );

      final json = element.toJson();

      expect(json['kind'], 'button');
      expect(json['label'], 'Sign Out');
      expect(json['widgetType'], 'IconButton');
      expect(json['isInteractive'], true);
      expect(json['gated'], true);
      expect(json['semanticRole'], 'button');
    });

    test('toJson omits default/null fields', () {
      const element = ScryElement(
        kind: ScryElementKind.content,
        label: 'Kael',
        widgetType: 'Text',
      );

      final json = element.toJson();

      expect(json.containsKey('isInteractive'), isFalse);
      expect(json.containsKey('fieldId'), isFalse);
      expect(json.containsKey('currentValue'), isFalse);
      expect(json.containsKey('gated'), isFalse);
      expect(json.containsKey('isEnabled'), isFalse);
    });

    test('toJson includes disabled state', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Submit',
        widgetType: 'ElevatedButton',
        isEnabled: false,
      );

      final json = element.toJson();

      expect(json['isEnabled'], false);
    });

    test('toJson includes fieldId for text fields', () {
      const element = ScryElement(
        kind: ScryElementKind.field,
        label: 'Hero Name',
        widgetType: 'TextField',
        fieldId: 'heroName',
        currentValue: 'Kael',
      );

      final json = element.toJson();

      expect(json['fieldId'], 'heroName');
      expect(json['currentValue'], 'Kael');
    });
  });

  // ===================================================================
  // ScryGaze
  // ===================================================================
  group('ScryGaze', () {
    test('categorizes elements by kind', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign Out',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Hero Name',
            widgetType: 'TextField',
          ),
          ScryElement(
            kind: ScryElementKind.navigation,
            label: 'Quests',
            widgetType: 'GestureDetector',
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Kael',
            widgetType: 'Text',
          ),
          ScryElement(
            kind: ScryElementKind.structural,
            label: 'Questboard',
            widgetType: 'AppBar',
          ),
        ],
        route: '/quests',
        glyphCount: 177,
      );

      expect(gaze.buttons, hasLength(1));
      expect(gaze.fields, hasLength(1));
      expect(gaze.navigation, hasLength(1));
      expect(gaze.content, hasLength(1));
      expect(gaze.structural, hasLength(1));
      expect(gaze.route, '/quests');
      expect(gaze.glyphCount, 177);
    });

    test('isAuthScreen detects login screens', () {
      const loginGaze = ScryGaze(
        screenType: ScryScreenType.login,
        elements: [
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Username',
            widgetType: 'TextField',
          ),
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Log In',
            widgetType: 'ElevatedButton',
            isInteractive: true,
          ),
        ],
      );

      expect(loginGaze.isAuthScreen, isTrue);
    });

    test('isAuthScreen false for non-login screens', () {
      const mainGaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign Out',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Kael',
            widgetType: 'Text',
          ),
        ],
      );

      expect(mainGaze.isAuthScreen, isFalse);
    });

    test('gated returns only gated elements', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Delete Account',
            widgetType: 'ElevatedButton',
            isInteractive: true,
            gated: true,
          ),
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Save',
            widgetType: 'ElevatedButton',
            isInteractive: true,
          ),
        ],
      );

      expect(gaze.gated, hasLength(1));
      expect(gaze.gated.first.label, 'Delete Account');
    });

    test('toJson includes counts and elements', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'OK',
            widgetType: 'Button',
          ),
        ],
        route: '/',
        glyphCount: 10,
      );

      final json = gaze.toJson();

      expect(json['route'], '/');
      expect(json['glyphCount'], 10);
      expect(json['buttonCount'], 1);
      expect(json['elements'], hasLength(1));
    });
  });

  // ===================================================================
  // Scry.observe — Element classification
  // ===================================================================
  group('Scry.observe', () {
    test('classifies interactive elements as buttons', () {
      final glyphs = [
        glyph(label: 'Sign Out', interactive: true, widgetType: 'IconButton'),
        glyph(label: 'About', interactive: true, widgetType: 'IconButton'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.buttons, hasLength(2));
      expect(gaze.buttons.map((e) => e.label), contains('Sign Out'));
      expect(gaze.buttons.map((e) => e.label), contains('About'));
    });

    test('classifies text fields', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          fieldId: 'heroName',
          semanticRole: 'textField',
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.fields, hasLength(1));
      expect(gaze.fields.first.label, 'Hero Name');
      expect(gaze.fields.first.fieldId, 'heroName');
    });

    test('classifies navigation elements by ancestor', () {
      final glyphs = [
        glyph(
          label: 'Quests',
          interactive: true,
          widgetType: 'GestureDetector',
          ancestors: [
            'DefaultSelectionStyle',
            'Builder',
            'MouseRegion',
            'Semantics',
          ],
        ),
        // Also include a non-interactive instance with nav ancestors
        glyph(
          label: 'Quests',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
      ];

      final gaze = scry.observe(glyphs);

      // "Quests" has a NavBar ancestor → navigation
      expect(gaze.navigation, hasLength(1));
      expect(gaze.navigation.first.label, 'Quests');
    });

    test('classifies NavigationBar widget type as navigation', () {
      final glyphs = [
        glyph(label: 'Quests', interactive: true, widgetType: 'NavigationBar'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.navigation, hasLength(1));
    });

    test('classifies AppBar children as structural', () {
      final glyphs = [
        glyph(
          label: 'Questboard',
          widgetType: 'Text',
          ancestors: ['_AppBarTitleBox', 'Semantics', 'DefaultTextStyle'],
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.structural, hasLength(1));
      expect(gaze.structural.first.label, 'Questboard');
    });

    test('classifies AppBar widget type as structural', () {
      final glyphs = [glyph(label: 'Questboard', widgetType: 'AppBar')];

      final gaze = scry.observe(glyphs);

      expect(gaze.structural, hasLength(1));
    });

    test('classifies plain Text as content', () {
      final glyphs = [
        glyph(label: 'Kael'),
        glyph(label: 'Slay the Bug Dragon'),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.content, hasLength(2));
      expect(gaze.content.map((e) => e.label), contains('Kael'));
    });

    test('deduplicates by label', () {
      final glyphs = [
        glyph(label: 'Kael', widgetType: 'Text'),
        glyph(label: 'Kael', widgetType: 'RichText'),
      ];

      final gaze = scry.observe(glyphs);

      // Only one "Kael" element
      expect(gaze.elements.where((e) => e.label == 'Kael'), hasLength(1));
    });

    test('excludes empty and short labels', () {
      final glyphs = [glyph(label: ''), glyph(label: 'A'), glyph(label: 'OK')];

      final gaze = scry.observe(glyphs);

      expect(gaze.elements, hasLength(1));
      expect(gaze.elements.first.label, 'OK');
    });

    test('excludes IconData labels', () {
      final glyphs = [glyph(label: 'IconData(U+0E15A)'), glyph(label: 'Kael')];

      final gaze = scry.observe(glyphs);

      expect(gaze.elements, hasLength(1));
      expect(gaze.elements.first.label, 'Kael');
    });

    test('marks destructive actions as gated', () {
      final glyphs = [
        glyph(
          label: 'Delete Account',
          interactive: true,
          widgetType: 'ElevatedButton',
        ),
        glyph(label: 'Save', interactive: true, widgetType: 'ElevatedButton'),
      ];

      final gaze = scry.observe(glyphs);

      final deleteBtn = gaze.buttons.firstWhere(
        (e) => e.label == 'Delete Account',
      );
      expect(deleteBtn.gated, isTrue);

      final saveBtn = gaze.buttons.firstWhere((e) => e.label == 'Save');
      expect(saveBtn.gated, isFalse);
    });

    test('marks common destructive patterns as gated', () {
      for (final label in [
        'Delete',
        'Remove Item',
        'Reset All',
        'Destroy',
        'Erase Data',
        'Clear All History',
        'Wipe',
        'Revoke Access',
        'Terminate Session',
        'Purge Cache',
      ]) {
        final glyphs = [glyph(label: label, interactive: true)];
        final gaze = scry.observe(glyphs);
        expect(
          gaze.buttons.first.gated,
          isTrue,
          reason: '"$label" should be gated',
        );
      }
    });

    test('non-interactive elements are not gated', () {
      // Even if label says "Delete", non-interactive labels aren't gated
      final glyphs = [glyph(label: 'Delete this file', interactive: false)];

      final gaze = scry.observe(glyphs);

      expect(gaze.content.first.gated, isFalse);
    });

    test('preserves route information', () {
      final gaze = scry.observe([glyph(label: 'OK')], route: '/quests');

      expect(gaze.route, '/quests');
    });

    test('tracks glyph count', () {
      final glyphs = [glyph(label: 'A'), glyph(label: 'B'), glyph(label: 'CC')];

      final gaze = scry.observe(glyphs);

      expect(gaze.glyphCount, 3);
    });

    test('promotes interactive to button even with nav ancestor label', () {
      // If "Hero" is interactive AND has a nav ancestor, it's navigation
      // (navigation takes precedence over generic button)
      final glyphs = [
        glyph(label: 'Hero', interactive: true, widgetType: 'GestureDetector'),
        glyph(
          label: 'Hero',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.navigation, hasLength(1));
      expect(gaze.navigation.first.label, 'Hero');
    });

    test('full Questboard main screen scenario', () {
      final glyphs = [
        // User data
        glyph(label: 'Kael'),
        glyph(label: '0 Glory \u2022 Novice'),
        // App bar title (structural)
        glyph(label: 'Questboard', ancestors: ['_AppBarTitleBox', 'Semantics']),
        glyph(label: 'Questboard', widgetType: 'AppBar'),
        // Buttons
        glyph(label: 'Sign Out', interactive: true, widgetType: 'IconButton'),
        glyph(label: 'Sign Out', widgetType: 'Tooltip'),
        glyph(label: 'About', interactive: true, widgetType: 'IconButton'),
        // Navigation tabs
        glyph(
          label: 'Quests',
          interactive: true,
          widgetType: 'GestureDetector',
        ),
        glyph(
          label: 'Quests',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
        glyph(label: 'Hero', interactive: true, widgetType: 'GestureDetector'),
        glyph(
          label: 'Hero',
          widgetType: 'Tooltip',
          ancestors: [
            'Stack',
            'Semantics',
            '_NavigationBarDestinationSemantics',
          ],
        ),
        // Quest items
        glyph(label: 'Slay the Bug Dragon'),
        glyph(label: 'Champion \u2022 50 glory'),
        glyph(
          label: 'Complete Quest',
          interactive: true,
          widgetType: 'IconButton',
        ),
      ];

      final gaze = scry.observe(glyphs, route: '/quests');

      // Structural: Questboard (AppBar ancestor)
      expect(gaze.structural.map((e) => e.label), contains('Questboard'));

      // Navigation: Quests, Hero (nav destination ancestors)
      expect(gaze.navigation.map((e) => e.label), contains('Quests'));
      expect(gaze.navigation.map((e) => e.label), contains('Hero'));

      // Buttons: Sign Out, About, Complete Quest
      expect(gaze.buttons.map((e) => e.label), contains('Sign Out'));
      expect(gaze.buttons.map((e) => e.label), contains('About'));
      expect(gaze.buttons.map((e) => e.label), contains('Complete Quest'));

      // Content: Kael, quest names/scores
      expect(gaze.content.map((e) => e.label), contains('Kael'));
      expect(gaze.content.map((e) => e.label), contains('Slay the Bug Dragon'));

      expect(gaze.route, '/quests');
      expect(gaze.isAuthScreen, isFalse);
    });

    test('login screen scenario', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          fieldId: 'heroName',
          semanticRole: 'textField',
        ),
        glyph(
          label: 'Enter the Questboard',
          interactive: true,
          widgetType: 'FilledButton',
        ),
        glyph(label: 'Sign in to continue to /'),
        glyph(label: 'Questboard'),
      ];

      final gaze = scry.observe(glyphs, route: '/login');

      expect(gaze.isAuthScreen, isTrue);
      expect(gaze.fields, hasLength(1));
      expect(gaze.fields.first.fieldId, 'heroName');
      expect(gaze.buttons, hasLength(1));
      expect(
        gaze.content.map((e) => e.label),
        contains('Sign in to continue to /'),
      );
    });

    test('TextField classified correctly even when RichText appears first', () {
      // In real apps, the RichText label inside a TextField's decoration
      // appears EARLIER in the glyph list than the TextField itself.
      // Scry must still classify "Hero Name" as a field, not a button.
      final glyphs = [
        // RichText label (appears first at higher depth)
        glyph(label: 'Hero Name', widgetType: 'RichText'),
        // Text label (also in decoration)
        glyph(label: 'Hero Name', widgetType: 'Text'),
        // The actual TextField (lower depth, interactive)
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          interactionType: 'textInput',
        ),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.fields, hasLength(1));
      expect(gaze.fields.first.label, 'Hero Name');
      expect(gaze.fields.first.widgetType, 'TextField');
      expect(gaze.buttons, isEmpty);
    });
  });

  // ===================================================================
  // Scry.formatGaze
  // ===================================================================
  group('Scry.formatGaze', () {
    test('includes route and glyph count in header', () {
      const gaze = ScryGaze(elements: [], route: '/quests', glyphCount: 177);

      final md = scry.formatGaze(gaze);

      expect(md, contains('# Current Screen'));
      expect(md, contains('/quests'));
      expect(md, contains('177 glyphs'));
    });

    test('marks login screen', () {
      const gaze = ScryGaze(
        screenType: ScryScreenType.login,
        elements: [
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Username',
            widgetType: 'TextField',
          ),
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign In',
            widgetType: 'ElevatedButton',
            isInteractive: true,
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Login screen detected'));
    });

    test('shows gated elements warning', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Delete All',
            widgetType: 'ElevatedButton',
            isInteractive: true,
            gated: true,
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Permission required'));
      expect(md, contains('Delete All'));
    });

    test('lists text fields with fieldId and usage hint', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.field,
            label: 'Hero Name',
            widgetType: 'TextField',
            fieldId: 'heroName',
            currentValue: 'Kael',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Text Fields'));
      expect(md, contains('Hero Name'));
      expect(md, contains('fieldId: heroName'));
      expect(md, contains('value: "Kael"'));
      expect(md, contains('enterText'));
      expect(md, contains('label'));
    });

    test('lists buttons', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Sign Out',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Buttons'));
      expect(md, contains('Sign Out'));
      expect(md, contains('IconButton'));
    });

    test('lists navigation tabs', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.navigation,
            label: 'Quests',
            widgetType: 'GestureDetector',
          ),
          ScryElement(
            kind: ScryElementKind.navigation,
            label: 'Hero',
            widgetType: 'GestureDetector',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Navigation'));
      expect(md, contains('Quests'));
      expect(md, contains('Hero'));
    });

    test('lists content', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Kael',
            widgetType: 'Text',
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Slay the Bug Dragon',
            widgetType: 'Text',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Content'));
      expect(md, contains('Kael'));
      expect(md, contains('Slay the Bug Dragon'));
    });

    test('includes available actions section', () {
      const gaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'OK',
            widgetType: 'Button',
          ),
        ],
      );

      final md = scry.formatGaze(gaze);

      expect(md, contains('Available Actions'));
      expect(md, contains('scry_act'));
      expect(md, contains('tap'));
    });
  });

  // ===================================================================
  // Scry.buildActionCampaign
  // ===================================================================
  group('Scry.buildActionCampaign', () {
    test('builds tap campaign', () {
      final campaign = scry.buildActionCampaign(
        action: 'tap',
        label: 'Sign Out',
      );

      expect(campaign['name'], '_scry_action');
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'tap');
      expect((step['target'] as Map)['label'], 'Sign Out');
    });

    test('builds enterText campaign with wait + dismiss', () {
      final campaign = scry.buildActionCampaign(
        action: 'enterText',
        label: 'Hero Name',
        value: 'Titan',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      // Step 1: waitForElement (auto-added for text actions)
      expect(steps, hasLength(3));
      final wait = steps[0] as Map<String, dynamic>;
      expect(wait['action'], 'waitForElement');
      expect((wait['target'] as Map)['label'], 'Hero Name');

      // Step 2: enterText
      final step = steps[1] as Map<String, dynamic>;
      expect(step['action'], 'enterText');
      expect((step['target'] as Map)['label'], 'Hero Name');
      expect(step['value'], 'Titan');
      expect(step['clearFirst'], isTrue);

      // Step 3: auto dismissKeyboard
      final dismiss = steps[2] as Map<String, dynamic>;
      expect(dismiss['action'], 'dismissKeyboard');
    });

    test('builds back campaign without target', () {
      final campaign = scry.buildActionCampaign(action: 'back');

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'back');
      expect(step.containsKey('target'), isFalse);
    });

    test('builds navigate campaign with route', () {
      final campaign = scry.buildActionCampaign(
        action: 'navigate',
        value: '/hero',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'navigate');
      expect((step['target'] as Map)['route'], '/hero');
    });

    test('builds waitForElement with timeout', () {
      final campaign = scry.buildActionCampaign(
        action: 'waitForElement',
        label: 'Sign Out',
        timeout: 3000,
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final step = steps[0] as Map<String, dynamic>;

      expect(step['action'], 'waitForElement');
      expect(step['timeout'], 3000);
    });

    test('campaign has correct structure', () {
      final campaign = scry.buildActionCampaign(action: 'tap', label: 'OK');

      // Must have these keys for Relay
      expect(campaign, contains('name'));
      expect(campaign, contains('entries'));
      final entries = campaign['entries'] as List;
      expect(entries, hasLength(1));
      final entry = entries[0] as Map;
      expect(entry, contains('stratagem'));
      final stratagem = entry['stratagem'] as Map;
      expect(stratagem, contains('name'));
      expect(stratagem, contains('startRoute'));
      expect(stratagem, contains('steps'));
    });

    test('clearText has wait + dismiss steps', () {
      final campaign = scry.buildActionCampaign(
        action: 'clearText',
        label: 'Hero Name',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(3));
      expect((steps[0] as Map)['action'], 'waitForElement');
      expect((steps[1] as Map)['action'], 'clearText');
      expect((steps[2] as Map)['action'], 'dismissKeyboard');
    });

    test('submitField has wait + dismiss steps', () {
      final campaign = scry.buildActionCampaign(
        action: 'submitField',
        label: 'Hero Name',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(3));
      expect((steps[0] as Map)['action'], 'waitForElement');
      expect((steps[1] as Map)['action'], 'submitField');
      expect((steps[2] as Map)['action'], 'dismissKeyboard');
    });

    test('tap does NOT auto-dismiss keyboard', () {
      final campaign = scry.buildActionCampaign(
        action: 'tap',
        label: 'Sign Out',
      );

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(1));
      expect((steps[0] as Map)['action'], 'tap');
    });
  });

  // ===================================================================
  // Scry.resolveFieldLabel
  // ===================================================================
  group('Scry.resolveFieldLabel', () {
    test('resolves fieldId to label', () {
      final glyphs = [
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'fid': 'heroName',
          'ia': true,
          'x': 0.0,
          'y': 0.0,
          'w': 200.0,
          'h': 40.0,
        },
        {
          'wt': 'Text',
          'l': 'Welcome',
          'x': 0.0,
          'y': 50.0,
          'w': 100.0,
          'h': 20.0,
        },
      ];

      expect(scry.resolveFieldLabel(glyphs, 'heroName'), 'Hero Name');
    });

    test('returns null for unknown fieldId', () {
      final glyphs = [
        {
          'wt': 'TextField',
          'l': 'Hero Name',
          'fid': 'heroName',
          'ia': true,
          'x': 0.0,
          'y': 0.0,
          'w': 200.0,
          'h': 40.0,
        },
      ];

      expect(scry.resolveFieldLabel(glyphs, 'email'), isNull);
    });

    test('returns null for empty glyphs', () {
      expect(scry.resolveFieldLabel([], 'heroName'), isNull);
    });
  });

  // ===================================================================
  // Scry.formatActionResult
  // ===================================================================
  group('Scry.formatActionResult', () {
    test('formats successful action', () {
      const newGaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Hero Page',
            widgetType: 'Text',
          ),
        ],
        route: '/hero',
        glyphCount: 50,
      );

      final md = scry.formatActionResult(
        action: 'tap',
        label: 'Hero',
        result: {'passRate': 1.0},
        newGaze: newGaze,
      );

      expect(md, contains('Action Succeeded'));
      expect(md, contains('tap'));
      expect(md, contains('"Hero"'));
      expect(md, contains('Current Screen'));
      expect(md, contains('Hero Page'));
    });

    test('formats failed action', () {
      const newGaze = ScryGaze(elements: [], glyphCount: 0);

      final md = scry.formatActionResult(
        action: 'tap',
        label: 'Missing Button',
        result: {
          'passRate': 0.0,
          'verdicts': [
            {
              'steps': [
                {
                  'passed': false,
                  'error': 'Target not found: "Missing Button"',
                },
              ],
            },
          ],
        },
        newGaze: newGaze,
      );

      expect(md, contains('Action Failed'));
      expect(md, contains('Target not found'));
    });

    test('formats enterText with value', () {
      const newGaze = ScryGaze(elements: [], glyphCount: 0);

      final md = scry.formatActionResult(
        action: 'enterText',
        label: 'Hero Name',
        value: 'Titan',
        result: {'passRate': 1.0},
        newGaze: newGaze,
      );

      expect(md, contains('enterText'));
      expect(md, contains('"Titan"'));
    });

    test('includes new screen state after action', () {
      const newGaze = ScryGaze(
        elements: [
          ScryElement(
            kind: ScryElementKind.button,
            label: 'Back',
            widgetType: 'IconButton',
            isInteractive: true,
          ),
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Welcome',
            widgetType: 'Text',
          ),
        ],
        route: '/welcome',
        glyphCount: 20,
      );

      final md = scry.formatActionResult(
        action: 'tap',
        label: 'Enter',
        result: {'passRate': 1.0},
        newGaze: newGaze,
      );

      // Should contain both the action result AND the new screen state
      expect(md, contains('Action Succeeded'));
      expect(md, contains('Current Screen'));
      expect(md, contains('/welcome'));
      expect(md, contains('Back'));
      expect(md, contains('Welcome'));
    });
  });

  // ===================================================================
  // Gated action detection
  // ===================================================================
  group('Gated actions', () {
    test('non-destructive actions are not gated', () {
      final glyphs = [
        glyph(label: 'Save', interactive: true),
        glyph(label: 'Submit', interactive: true),
        glyph(label: 'Sign Out', interactive: true),
        glyph(label: 'About', interactive: true),
      ];

      final gaze = scry.observe(glyphs);

      expect(gaze.gated, isEmpty);
    });

    test('disconnect is gated', () {
      final glyphs = [glyph(label: 'Disconnect', interactive: true)];

      final gaze = scry.observe(glyphs);

      expect(gaze.gated, hasLength(1));
    });
  });

  // ===================================================================
  // Scry.buildMultiActionCampaign
  // ===================================================================
  group('Scry.buildMultiActionCampaign', () {
    test('combines enterText + tap into one campaign', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'enterText', 'label': 'Hero Name', 'value': 'Kael'},
        {'action': 'tap', 'label': 'Enter the Questboard'},
      ]);

      expect(campaign['name'], '_scry_multi_action');
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      expect(stratagem['name'], '_scry_steps');
      expect(stratagem['startRoute'], '');

      final steps = stratagem['steps'] as List;
      // enterText: waitForElement + enterText + dismissKeyboard = 3
      // tap: 1
      // Total: 4
      expect(steps, hasLength(4));

      // Step 1: waitForElement for "Hero Name"
      expect(steps[0]['action'], 'waitForElement');
      expect(steps[0]['target']['label'], 'Hero Name');

      // Step 2: enterText "Kael" into "Hero Name"
      expect(steps[1]['action'], 'enterText');
      expect(steps[1]['target']['label'], 'Hero Name');
      expect(steps[1]['value'], 'Kael');
      expect(steps[1]['clearFirst'], true);

      // Step 3: dismissKeyboard
      expect(steps[2]['action'], 'dismissKeyboard');

      // Step 4: tap "Enter the Questboard"
      expect(steps[3]['action'], 'tap');
      expect(steps[3]['target']['label'], 'Enter the Questboard');
    });

    test('multiple text fields get individual pre/post steps', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'enterText', 'label': 'Username', 'value': 'alice'},
        {'action': 'enterText', 'label': 'Password', 'value': 'secret'},
        {'action': 'tap', 'label': 'Login'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      // 2 × (wait + enter + dismiss) + 1 tap = 7
      expect(steps, hasLength(7));

      expect(steps[0]['action'], 'waitForElement');
      expect(steps[1]['action'], 'enterText');
      expect(steps[1]['value'], 'alice');
      expect(steps[2]['action'], 'dismissKeyboard');

      expect(steps[3]['action'], 'waitForElement');
      expect(steps[4]['action'], 'enterText');
      expect(steps[4]['value'], 'secret');
      expect(steps[5]['action'], 'dismissKeyboard');

      expect(steps[6]['action'], 'tap');
      expect(steps[6]['target']['label'], 'Login');
    });

    test('step IDs are sequential', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'enterText', 'label': 'Name', 'value': 'X'},
        {'action': 'tap', 'label': 'Go'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      for (var i = 0; i < steps.length; i++) {
        expect(steps[i]['id'], i + 1);
      }
    });

    test('non-text actions have no pre/post steps', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'tap', 'label': 'Button A'},
        {'action': 'tap', 'label': 'Button B'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(2));
      expect(steps[0]['action'], 'tap');
      expect(steps[1]['action'], 'tap');
    });

    test('navigate action uses route target', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'navigate', 'value': '/quests'},
        {'action': 'tap', 'label': 'Refresh'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(2));
      expect(steps[0]['target']['route'], '/quests');
      expect(steps[1]['target']['label'], 'Refresh');
    });

    test('back action has no target', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'back'},
      ]);

      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;

      expect(steps, hasLength(1));
      expect(steps[0]['action'], 'back');
      expect(steps[0].containsKey('target'), isFalse);
    });
  });

  // ===================================================================
  // Scry.formatMultiActionResult
  // ===================================================================
  group('Scry.formatMultiActionResult', () {
    test('formats successful multi-action result', () {
      final gaze = ScryGaze(
        elements: const [
          ScryElement(
            kind: ScryElementKind.content,
            label: 'Welcome',
            widgetType: 'Text',
          ),
        ],
        route: '/home',
        glyphCount: 1,
      );

      final md = scry.formatMultiActionResult(
        actions: [
          {'action': 'enterText', 'label': 'Hero Name', 'value': 'Kael'},
          {'action': 'tap', 'label': 'Enter the Questboard'},
        ],
        result: {'passRate': 1.0},
        newGaze: gaze,
      );

      expect(md, contains('✅ All Actions Succeeded'));
      expect(md, contains('Actions performed'));
      expect(md, contains('`enterText` on "Hero Name" → "Kael"'));
      expect(md, contains('`tap` on "Enter the Questboard"'));
      expect(md, contains('Welcome'));
    });

    test('formats failed multi-action result with error', () {
      final gaze = ScryGaze(elements: const [], route: '/login', glyphCount: 0);

      final md = scry.formatMultiActionResult(
        actions: [
          {'action': 'enterText', 'label': 'Email', 'value': 'test@x.com'},
          {'action': 'tap', 'label': 'Submit'},
        ],
        result: {
          'passRate': 0.5,
          'verdicts': [
            {
              'steps': [
                {'id': 1, 'passed': true},
                {'id': 2, 'passed': false, 'error': 'Element not found'},
              ],
            },
          ],
        },
        newGaze: gaze,
      );

      expect(md, contains('❌ Actions Failed'));
      expect(md, contains('Element not found'));
      expect(md, contains('step 2'));
    });
  });

  // ===================================================================
  // ScryScreenType — Screen classification
  // ===================================================================
  group('ScryScreenType', () {
    test('has all expected values', () {
      expect(ScryScreenType.values, hasLength(9));
      expect(ScryScreenType.values, contains(ScryScreenType.login));
      expect(ScryScreenType.values, contains(ScryScreenType.form));
      expect(ScryScreenType.values, contains(ScryScreenType.list));
      expect(ScryScreenType.values, contains(ScryScreenType.detail));
      expect(ScryScreenType.values, contains(ScryScreenType.settings));
      expect(ScryScreenType.values, contains(ScryScreenType.empty));
      expect(ScryScreenType.values, contains(ScryScreenType.error));
      expect(ScryScreenType.values, contains(ScryScreenType.dashboard));
      expect(ScryScreenType.values, contains(ScryScreenType.unknown));
    });

    test('detects login screen (fields + login button)', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'username',
        ),
        glyph(
          label: 'Sign In',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.login);
    });

    test('detects login screen with "Enter" button', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'hero_name',
        ),
        glyph(
          label: 'Enter the Questboard',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.login);
    });

    test('detects form screen (multiple fields + submit)', () {
      final glyphs = [
        glyph(
          label: 'First Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'first',
        ),
        glyph(
          label: 'Last Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'last',
        ),
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'email',
        ),
        glyph(label: 'Save', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.form);
    });

    test('detects settings screen (toggles and switches)', () {
      final glyphs = [
        glyph(
          label: 'Dark Mode',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'switch',
          currentValue: 'on',
        ),
        glyph(
          label: 'Notifications',
          widgetType: 'Switch',
          interactive: true,
          interactionType: 'switch',
          currentValue: 'off',
        ),
        glyph(
          label: 'Sound',
          widgetType: 'Checkbox',
          interactive: true,
          interactionType: 'checkbox',
          currentValue: 'true',
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.settings);
    });

    test('detects list screen (many content items)', () {
      final glyphs = <Map<String, dynamic>>[];
      for (var i = 0; i < 7; i++) {
        glyphs.add(glyph(label: 'Item $i', widgetType: 'Text'));
      }
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.list);
    });

    test('detects empty screen (no content, no fields)', () {
      final glyphs = <Map<String, dynamic>>[];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.empty);
    });

    test('detects empty screen with just structural elements', () {
      final glyphs = [
        glyph(label: 'App Title', widgetType: 'Text', ancestors: ['AppBar']),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.empty);
    });

    test('returns unknown for ambiguous screens', () {
      final glyphs = [
        glyph(label: 'Some content'),
        glyph(label: 'More text'),
        glyph(
          label: 'A button',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.unknown);
    });
  });

  // ===================================================================
  // ScryAlert — Error / Loading / Notice detection
  // ===================================================================
  group('ScryAlert detection', () {
    test('detects loading indicators by widget type', () {
      final glyphs = [
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.loading);
      expect(gaze.alerts.first.message, contains('CircularProgressIndicator'));
    });

    test('detects loading indicator with label', () {
      final glyphs = [
        glyph(
          label: 'Loading quests...',
          widgetType: 'CircularProgressIndicator',
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.loading);
      expect(gaze.alerts.first.message, 'Loading quests...');
    });

    test('detects snackbar with error text as error', () {
      final glyphs = [
        glyph(
          label: 'Error: Could not load data',
          widgetType: 'Text',
          ancestors: ['SnackBar', 'Scaffold'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.error);
      expect(gaze.alerts.first.message, 'Error: Could not load data');
    });

    test('detects snackbar with normal text as info', () {
      final glyphs = [
        glyph(
          label: 'Quest completed!',
          widgetType: 'Text',
          ancestors: ['SnackBar', 'Scaffold'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.info);
      expect(gaze.alerts.first.message, 'Quest completed!');
    });

    test('detects MaterialBanner content', () {
      final glyphs = [
        glyph(
          label: 'New update available',
          widgetType: 'Text',
          ancestors: ['MaterialBanner'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.info);
    });

    test('detects error text content with keywords', () {
      final glyphs = [glyph(label: 'Could not load data. Please try again')];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, hasLength(1));
      expect(gaze.alerts.first.severity, ScryAlertSeverity.warning);
    });

    test('does not flag normal text as error', () {
      final glyphs = [
        glyph(label: 'Welcome to the app'),
        glyph(label: 'Your profile is complete'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.alerts, isEmpty);
    });

    test('isLoading returns true when loading alerts present', () {
      final glyphs = [glyph(label: '', widgetType: 'LinearProgressIndicator')];
      final gaze = scry.observe(glyphs);
      expect(gaze.isLoading, isTrue);
      expect(gaze.hasErrors, isFalse);
    });

    test('hasErrors returns true when error alerts present', () {
      final glyphs = [
        glyph(
          label: 'Error: Connection refused',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.hasErrors, isTrue);
      expect(gaze.isLoading, isFalse);
    });

    test('alert serializes to JSON', () {
      const alert = ScryAlert(
        severity: ScryAlertSeverity.error,
        message: 'Something broke',
        widgetType: 'SnackBar',
      );
      final json = alert.toJson();
      expect(json['severity'], 'error');
      expect(json['message'], 'Something broke');
      expect(json['widgetType'], 'SnackBar');
    });

    test('de-duplicates identical alert messages', () {
      // Two glyphs with the same text in a SnackBar
      final glyphs = [
        glyph(
          label: 'Duplicate alert',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
        glyph(
          label: 'Duplicate alert',
          widgetType: 'RichText',
          ancestors: ['SnackBar'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      // Should only have 1 alert, not 2
      expect(gaze.alerts, hasLength(1));
    });
  });

  // ===================================================================
  // ScryKeyValue — Key-value pair extraction
  // ===================================================================
  group('ScryKeyValue extraction', () {
    test('extracts inline "Key: Value" patterns', () {
      final glyphs = [
        glyph(label: 'Class: Scout'),
        glyph(label: 'Level: Novice'),
        glyph(label: 'Glory: 0'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, hasLength(3));
      expect(gaze.dataFields[0].key, 'Class');
      expect(gaze.dataFields[0].value, 'Scout');
      expect(gaze.dataFields[1].key, 'Level');
      expect(gaze.dataFields[1].value, 'Novice');
      expect(gaze.dataFields[2].key, 'Glory');
      expect(gaze.dataFields[2].value, '0');
    });

    test('skips interactive elements for KV extraction', () {
      final glyphs = [
        glyph(label: 'Name: Kael', widgetType: 'TextField', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, isEmpty);
    });

    test('skips long keys (> 30 chars)', () {
      final glyphs = [
        glyph(
          label: 'This is a very long label that should not be a key: value',
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, isEmpty);
    });

    test('extracts proximity-based pairs by Y alignment', () {
      // Two text labels on the same row, left one short
      final glyphs = [
        {
          'wt': 'Text',
          'l': 'Name:',
          'x': 16.0,
          'y': 100.0,
          'w': 60.0,
          'h': 20.0,
        },
        {
          'wt': 'Text',
          'l': 'Kael',
          'x': 80.0,
          'y': 100.0,
          'w': 50.0,
          'h': 20.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.dataFields, hasLength(1));
      expect(gaze.dataFields.first.key, 'Name');
      expect(gaze.dataFields.first.value, 'Kael');
    });

    test('does not pair labels on different rows', () {
      final glyphs = [
        {
          'wt': 'Text',
          'l': 'Status:',
          'x': 16.0,
          'y': 100.0,
          'w': 60.0,
          'h': 20.0,
        },
        {
          'wt': 'Text',
          'l': 'Active',
          'x': 16.0,
          'y': 150.0,
          'w': 50.0,
          'h': 20.0,
        },
      ];
      final gaze = scry.observe(glyphs);
      // "Status:" is an inline pattern that fails (no value after colon
      // in the proximity pairing), but it should not pair with "Active"
      // Since "Status:" by itself has no trailing value, the inline
      // pattern won't match. And proximity fails due to Y diff (50px).
      // Check no proximity pairs were created.
      expect(
        gaze.dataFields
            .where((d) => d.key == 'Status' && d.value == 'Active')
            .isEmpty,
        isTrue,
      );
    });

    test('KV pair serializes to JSON', () {
      const kv = ScryKeyValue(key: 'Role', value: 'Admin');
      final json = kv.toJson();
      expect(json['key'], 'Role');
      expect(json['value'], 'Admin');
    });
  });

  // ===================================================================
  // ScryDiff — State change detection
  // ===================================================================
  group('ScryDiff', () {
    test('detects appeared elements', () {
      final before = scry.observe([glyph(label: 'Hello')]);
      final after = scry.observe([
        glyph(label: 'Hello'),
        glyph(label: 'World'),
      ]);
      final diff = scry.diff(before, after);
      expect(diff.appeared, hasLength(1));
      expect(diff.appeared.first.label, 'World');
      expect(diff.disappeared, isEmpty);
      expect(diff.hasChanges, isTrue);
    });

    test('detects disappeared elements', () {
      final before = scry.observe([
        glyph(label: 'Hello'),
        glyph(label: 'World'),
      ]);
      final after = scry.observe([glyph(label: 'Hello')]);
      final diff = scry.diff(before, after);
      expect(diff.appeared, isEmpty);
      expect(diff.disappeared, hasLength(1));
      expect(diff.disappeared.first.label, 'World');
    });

    test('detects changed values', () {
      final before = scry.observe([
        glyph(label: 'Score', widgetType: 'Text', currentValue: '10'),
      ]);
      final after = scry.observe([
        glyph(label: 'Score', widgetType: 'Text', currentValue: '20'),
      ]);
      final diff = scry.diff(before, after);
      expect(diff.changedValues, hasLength(1));
      expect(diff.changedValues['Score']!['from'], '10');
      expect(diff.changedValues['Score']!['to'], '20');
    });

    test('detects route change', () {
      final before = scry.observe([glyph(label: 'Page A')], route: '/a');
      final after = scry.observe([glyph(label: 'Page B')], route: '/b');
      final diff = scry.diff(before, after);
      expect(diff.routeChanged, isTrue);
      expect(diff.previousRoute, '/a');
      expect(diff.currentRoute, '/b');
    });

    test('detects no route change when same', () {
      final before = scry.observe([glyph(label: 'Page A')], route: '/a');
      final after = scry.observe([glyph(label: 'Page A updated')], route: '/a');
      final diff = scry.diff(before, after);
      expect(diff.routeChanged, isFalse);
    });

    test('detects screen type change', () {
      // Login screen
      final before = scry.observe([
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'user',
        ),
        glyph(label: 'Log In', widgetType: 'ElevatedButton', interactive: true),
      ]);
      // After login: list screen
      final after = scry.observe([
        glyph(label: 'Item 1'),
        glyph(label: 'Item 2'),
        glyph(label: 'Item 3'),
        glyph(label: 'Item 4'),
        glyph(label: 'Item 5'),
      ]);
      final diff = scry.diff(before, after);
      expect(diff.screenTypeChanged, isTrue);
      expect(diff.previousScreenType, ScryScreenType.login);
      expect(diff.currentScreenType, ScryScreenType.list);
    });

    test('hasChanges is false when nothing changed', () {
      final glyphs = [glyph(label: 'Static content')];
      final before = scry.observe(glyphs, route: '/x');
      final after = scry.observe(glyphs, route: '/x');
      final diff = scry.diff(before, after);
      expect(diff.hasChanges, isFalse);
    });

    test('format produces readable markdown', () {
      final before = scry.observe([
        glyph(label: 'Old Button', interactive: true),
      ], route: '/old');
      final after = scry.observe([
        glyph(label: 'New Text'),
        glyph(label: 'New Button', interactive: true),
      ], route: '/new');
      final diff = scry.diff(before, after);
      final md = diff.format();
      expect(md, contains('What Changed'));
      expect(md, contains('/old'));
      expect(md, contains('/new'));
      expect(md, contains('Appeared'));
      expect(md, contains('Disappeared'));
      expect(md, contains('Old Button'));
      expect(md, contains('New Text'));
      expect(md, contains('New Button'));
    });

    test('format handles empty diff', () {
      final glyphs = [glyph(label: 'Static')];
      final before = scry.observe(glyphs);
      final after = scry.observe(glyphs);
      final diff = scry.diff(before, after);
      final md = diff.format();
      expect(md, contains('No visible changes'));
    });

    test('diff serializes to JSON', () {
      final before = scry.observe([glyph(label: 'AA')], route: '/a');
      final after = scry.observe([glyph(label: 'BB')], route: '/b');
      final diff = scry.diff(before, after);
      final json = diff.toJson();
      expect(json['routeChanged'], isTrue);
      expect(json['previousRoute'], '/a');
      expect(json['currentRoute'], '/b');
      expect(json['hasChanges'], isTrue);
      expect(json['appeared'], isA<List>());
      expect(json['disappeared'], isA<List>());
    });
  });

  // ===================================================================
  // Action suggestions
  // ===================================================================
  group('Action suggestions', () {
    test('suggests credentials on login screen', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'hero',
        ),
        glyph(
          label: 'Enter the Questboard',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions, isNotEmpty);
      expect(
        gaze.suggestions.any(
          (s) => s.contains('Hero Name') && s.contains('Enter the Questboard'),
        ),
        isTrue,
      );
    });

    test('suggests filling fields on form screen', () {
      final glyphs = [
        glyph(
          label: 'First Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'f',
        ),
        glyph(
          label: 'Last Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'l',
        ),
        glyph(label: 'Save', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions, isNotEmpty);
      expect(gaze.suggestions.any((s) => s.contains('Save')), isTrue);
    });

    test('suggests item tap on list screen', () {
      final glyphs = <Map<String, dynamic>>[];
      for (var i = 0; i < 6; i++) {
        glyphs.add(glyph(label: 'Quest $i'));
      }
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions.any((s) => s.contains('item')), isTrue);
    });

    test('warns about errors when error alerts present', () {
      final glyphs = [
        glyph(
          label: 'Error: Connection refused',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(
        gaze.suggestions.any((s) => s.toLowerCase().contains('error')),
        isTrue,
      );
    });

    test('warns about loading state', () {
      final glyphs = [
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
        glyph(label: 'Some content'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.suggestions.any((s) => s.contains('loading')), isTrue);
    });

    test('suggests navigation on dashboard screen', () {
      final glyphs = [
        glyph(label: 'Content 1'),
        glyph(label: 'Content 2'),
        glyph(label: 'Content 3'),
        glyph(
          label: 'Tab A',
          widgetType: 'Text',
          interactive: true,
          ancestors: ['NavigationBar'],
        ),
        glyph(
          label: 'Tab B',
          widgetType: 'Text',
          interactive: true,
          ancestors: ['NavigationBar'],
        ),
        glyph(label: 'Action', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.dashboard);
      expect(gaze.suggestions, isNotEmpty);
    });
  });

  // ===================================================================
  // Updated formatGaze — new sections
  // ===================================================================
  group('formatGaze — intelligence sections', () {
    test('includes screen type in header', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'u',
        ),
        glyph(label: 'Log In', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs, route: '/login');
      final md = scry.formatGaze(gaze);
      expect(md, contains('**Type**: login'));
    });

    test('includes alerts section', () {
      final glyphs = [
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('⏳'));
      expect(md, contains('loading'));
    });

    test('includes data fields section', () {
      final glyphs = [
        glyph(label: 'Class: Scout'),
        glyph(label: 'Level: Novice'),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('📊 Data'));
      expect(md, contains('**Class**: Scout'));
      expect(md, contains('**Level**: Novice'));
    });

    test('includes suggestions section', () {
      final glyphs = [
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'n',
        ),
        glyph(label: 'Submit', widgetType: 'ElevatedButton', interactive: true),
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'e',
        ),
      ];
      final gaze = scry.observe(glyphs);
      final md = scry.formatGaze(gaze);
      expect(md, contains('💡 Suggestions'));
    });

    test('ScryGaze toJson includes new fields', () {
      final glyphs = [
        glyph(label: 'Class: Scout'),
        glyph(label: '', widgetType: 'CircularProgressIndicator'),
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'n',
        ),
        glyph(label: 'Submit', widgetType: 'ElevatedButton', interactive: true),
        glyph(
          label: 'Other Field',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'o',
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json['screenType'], isA<String>());
      expect(json['alerts'], isA<List>());
      expect(json['dataFields'], isA<List>());
      expect(json['suggestions'], isA<List>());
    });
  });

  // ===================================================================
  // ScryAlertSeverity
  // ===================================================================
  group('ScryAlertSeverity', () {
    test('has all expected values', () {
      expect(ScryAlertSeverity.values, hasLength(4));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.error));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.warning));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.info));
      expect(ScryAlertSeverity.values, contains(ScryAlertSeverity.loading));
    });
  });

  // ===================================================================
  // Error screen type detection
  // ===================================================================
  group('ScryScreenType.error', () {
    test('error screen detected when snackbar has error', () {
      final glyphs = [
        glyph(
          label: 'Failed to load data',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
        glyph(label: 'Some content'),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.error);
    });

    test('error takes precedence over login', () {
      final glyphs = [
        glyph(
          label: 'Error: Invalid credentials',
          widgetType: 'Text',
          ancestors: ['SnackBar'],
        ),
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'u',
        ),
        glyph(
          label: 'Sign In',
          widgetType: 'ElevatedButton',
          interactive: true,
        ),
      ];
      final gaze = scry.observe(glyphs);
      // Error takes precedence over login detection
      expect(gaze.screenType, ScryScreenType.error);
    });
  });

  // ===================================================================
  // Detail screen type detection
  // ===================================================================
  group('ScryScreenType.detail', () {
    test('detected when data fields present with no input fields', () {
      final glyphs = [
        glyph(label: 'Name: Kael'),
        glyph(label: 'Class: Scout'),
        glyph(label: 'Level: Novice'),
        glyph(label: 'Edit', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.screenType, ScryScreenType.detail);
      expect(gaze.dataFields, hasLength(3));
    });
  });

  // ===================================================================
  // Spatial layout awareness
  // ===================================================================
  group('Spatial layout awareness', () {
    test('ScryElement stores x/y/w/h from glyphs', () {
      final glyphs = [
        glyph(
          label: 'Hero Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'heroName',
          x: 16.0,
          y: 200.0,
          w: 350.0,
          h: 56.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final field = gaze.elements.firstWhere((e) => e.label == 'Hero Name');
      expect(field.x, 16.0);
      expect(field.y, 200.0);
      expect(field.w, 350.0);
      expect(field.h, 56.0);
    });

    test('ScryElement stores depth from glyphs', () {
      final glyphs = [glyph(label: 'Title', depth: 12, y: 50.0)];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.depth, 12);
    });

    test('ScryElement toJson includes spatial data when present', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Tap Me',
        widgetType: 'ElevatedButton',
        x: 10.0,
        y: 200.0,
        w: 120.0,
        h: 48.0,
        depth: 5,
      );
      final json = element.toJson();
      expect(json['x'], 10.0);
      expect(json['y'], 200.0);
      expect(json['w'], 120.0);
      expect(json['h'], 48.0);
      expect(json['depth'], 5);
    });

    test('ScryElement toJson omits null spatial data', () {
      const element = ScryElement(
        kind: ScryElementKind.content,
        label: 'Hello',
        widgetType: 'Text',
      );
      final json = element.toJson();
      expect(json.containsKey('x'), isFalse);
      expect(json.containsKey('depth'), isFalse);
    });
  });

  // ===================================================================
  // Screen region inference
  // ===================================================================
  group('Screen region inference', () {
    test('AppBar ancestor → topBar region', () {
      final glyphs = [
        glyph(
          label: 'My App',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          y: 40.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'My App');
      expect(el.region, ScryScreenRegion.topBar);
    });

    test('NavigationBar ancestor → bottomNav region', () {
      final glyphs = [
        glyph(
          label: 'Home',
          widgetType: 'GestureDetector',
          interactive: true,
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'NavigationBar',
            'GestureDetector',
          ],
          y: 750.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Home');
      expect(el.region, ScryScreenRegion.bottomNav);
    });

    test('FAB ancestor → floating region', () {
      final glyphs = [
        glyph(
          label: 'Add',
          widgetType: 'FloatingActionButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'FloatingActionButton'],
          y: 600.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Add');
      expect(el.region, ScryScreenRegion.floating);
    });

    test('y < 100 without ancestor → topBar by position', () {
      final glyphs = [glyph(label: 'Title Text', y: 50.0)];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.region, ScryScreenRegion.topBar);
    });

    test('y > 700 without ancestor → bottomNav by position', () {
      final glyphs = [
        glyph(
          label: 'Tab Label',
          widgetType: 'GestureDetector',
          interactive: true,
          y: 750.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.region, ScryScreenRegion.bottomNav);
    });

    test('y between 100 and 700 → mainContent', () {
      final glyphs = [glyph(label: 'Content Text', y: 400.0)];
      final gaze = scry.observe(glyphs);
      expect(gaze.elements.first.region, ScryScreenRegion.mainContent);
    });

    test('ScryScreenRegion has all expected values', () {
      expect(ScryScreenRegion.values, hasLength(5));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.topBar));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.mainContent));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.bottomNav));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.floating));
      expect(ScryScreenRegion.values, contains(ScryScreenRegion.unknown));
    });
  });

  // ===================================================================
  // Key-based stable targeting
  // ===================================================================
  group('Key-based stable targeting', () {
    test('ScryElement stores key from glyph', () {
      final glyphs = [
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          key: "ValueKey('submit_btn')",
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Submit');
      expect(btn.key, "ValueKey('submit_btn')");
    });

    test('ScryElement toJson includes key when present', () {
      const element = ScryElement(
        kind: ScryElementKind.button,
        label: 'Submit',
        widgetType: 'ElevatedButton',
        key: "ValueKey('submit_btn')",
      );
      final json = element.toJson();
      expect(json['key'], "ValueKey('submit_btn')");
    });

    test('buildActionCampaign prefers key over label', () {
      final campaign = scry.buildActionCampaign(
        action: 'tap',
        label: 'Submit',
        key: "ValueKey('submit_btn')",
      );
      // Campaign has nested structure: entries[0].stratagem.steps
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final tapStep = steps.last as Map<String, dynamic>;
      expect(tapStep['action'], 'tap');
      final target = tapStep['target'] as Map<String, dynamic>;
      expect(target['key'], "ValueKey('submit_btn')");
    });

    test('buildActionCampaign works without key', () {
      final campaign = scry.buildActionCampaign(action: 'tap', label: 'Submit');
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final tapStep = steps.last as Map<String, dynamic>;
      final target = tapStep['target'] as Map<String, dynamic>;
      expect(target['label'], 'Submit');
      expect(target.containsKey('key'), isFalse);
    });

    test('buildMultiActionCampaign uses key from action map', () {
      final campaign = scry.buildMultiActionCampaign([
        {'action': 'tap', 'label': 'Delete', 'key': "ValueKey('del_0')"},
      ]);
      final entries = campaign['entries'] as List;
      final stratagem =
          (entries[0] as Map)['stratagem'] as Map<String, dynamic>;
      final steps = stratagem['steps'] as List;
      final tapStep = steps.last as Map<String, dynamic>;
      final target = tapStep['target'] as Map<String, dynamic>;
      expect(target['key'], "ValueKey('del_0')");
    });
  });

  // ===================================================================
  // Ancestor context annotation
  // ===================================================================
  group('Ancestor context annotation', () {
    test('Dialog ancestor sets context to Dialog', () {
      final glyphs = [
        glyph(
          label: 'Cancel',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'TextButton'],
          depth: 30,
          y: 400.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Cancel');
      expect(btn.context, 'Dialog');
    });

    test('BottomSheet ancestor sets context', () {
      final glyphs = [
        glyph(
          label: 'Close',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'BottomSheet', 'TextButton'],
          depth: 25,
          y: 500.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Close');
      expect(btn.context, 'BottomSheet');
    });

    test('Card ancestor sets context', () {
      final glyphs = [
        glyph(
          label: 'Card Title',
          ancestors: ['MaterialApp', 'Scaffold', 'Card', 'Text'],
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Card Title');
      expect(el.context, 'Card');
    });

    test('no recognized ancestor sets context to null', () {
      final glyphs = [
        glyph(
          label: 'Plain Text',
          ancestors: ['MaterialApp', 'Scaffold', 'Column', 'Text'],
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final el = gaze.elements.firstWhere((e) => e.label == 'Plain Text');
      expect(el.context, isNull);
    });

    test('formatGaze shows context for buttons', () {
      final glyphs = [
        glyph(
          label: 'Confirm',
          widgetType: 'ElevatedButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'ElevatedButton'],
          depth: 30,
          y: 400.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      expect(output, contains('Dialog'));
    });
  });

  // ===================================================================
  // Overlap / occlusion detection
  // ===================================================================
  group('Overlap / occlusion detection', () {
    test('background element behind dialog is marked obscured', () {
      final glyphs = [
        // Background button at depth 5
        glyph(
          label: 'Background Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 50.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        // Dialog content at depth 30
        glyph(
          label: 'Dialog Title',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 20.0,
          y: 200.0,
          w: 350.0,
          h: 400.0,
        ),
        glyph(
          label: 'OK',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'TextButton'],
          depth: 30,
          x: 150.0,
          y: 500.0,
          w: 60.0,
          h: 36.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      final bgBtn = gaze.elements.firstWhere(
        (e) => e.label == 'Background Button',
      );
      expect(bgBtn.obscured, isTrue);

      // Dialog elements should NOT be obscured
      final okBtn = gaze.elements.firstWhere((e) => e.label == 'OK');
      expect(okBtn.obscured, isFalse);
    });

    test('non-overlapping background element is not obscured', () {
      final glyphs = [
        // Background button far from dialog
        glyph(
          label: 'Far Away Button',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 50.0,
          y: 50.0,
          w: 100.0,
          h: 48.0,
        ),
        // Dialog in center of screen
        glyph(
          label: 'Dialog Content',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 100.0,
          y: 200.0,
          w: 200.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      final btn = gaze.elements.firstWhere((e) => e.label == 'Far Away Button');
      expect(btn.obscured, isFalse);
    });

    test('ScryGaze.obscured getter returns only obscured elements', () {
      final glyphs = [
        glyph(
          label: 'Hidden',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 100.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        glyph(
          label: 'Visible',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 50.0,
          y: 50.0,
          w: 80.0,
          h: 48.0,
        ),
        glyph(
          label: 'Dialog Text',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 80.0,
          y: 250.0,
          w: 250.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.obscured, hasLength(1));
      expect(gaze.obscured.first.label, 'Hidden');
    });

    test('no overlay means nothing is obscured', () {
      final glyphs = [
        glyph(
          label: 'Button A',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          y: 200.0,
        ),
        glyph(
          label: 'Button B',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.obscured, isEmpty);
    });

    test('ScryGaze toJson includes obscured count', () {
      final glyphs = [
        glyph(
          label: 'Blocked',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 100.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        glyph(
          label: 'Modal OK',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['Dialog'],
          depth: 30,
          x: 80.0,
          y: 250.0,
          w: 250.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json['obscuredCount'], 1);
    });

    test('formatGaze includes obscured warning section', () {
      final glyphs = [
        glyph(
          label: 'Hidden Btn',
          widgetType: 'ElevatedButton',
          interactive: true,
          depth: 5,
          x: 100.0,
          y: 300.0,
          w: 200.0,
          h: 48.0,
        ),
        glyph(
          label: 'Dialog OK',
          widgetType: 'TextButton',
          interactive: true,
          ancestors: ['Dialog'],
          depth: 30,
          x: 80.0,
          y: 250.0,
          w: 250.0,
          h: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      expect(output, contains('Obscured'));
      expect(output, contains('Hidden Btn'));
    });
  });

  // ===================================================================
  // Repeated-element multiplicity
  // ===================================================================
  group('Repeated-element multiplicity', () {
    test('multiple interactive buttons with same label get indices', () {
      final glyphs = [
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          y: 100.0,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          y: 200.0,
        ),
        glyph(
          label: 'Delete',
          widgetType: 'IconButton',
          interactive: true,
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      final deletes = gaze.elements.where((e) => e.label == 'Delete').toList();
      expect(deletes, hasLength(3));
      expect(deletes[0].occurrenceIndex, 0);
      expect(deletes[0].totalOccurrences, 3);
      expect(deletes[1].occurrenceIndex, 1);
      expect(deletes[2].occurrenceIndex, 2);
    });

    test('unique label has null occurrence fields', () {
      final glyphs = [
        glyph(label: 'Submit', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      final btn = gaze.elements.firstWhere((e) => e.label == 'Submit');
      expect(btn.occurrenceIndex, isNull);
      expect(btn.totalOccurrences, isNull);
    });

    test('non-interactive duplicates are still deduplicated', () {
      // Same label appearing as both GestureDetector and Tooltip
      // for the same UI element — should dedup, not multiply
      final glyphs = [
        glyph(
          label: 'Quests',
          widgetType: 'GestureDetector',
          interactive: true,
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'BottomNavigationBar',
            'GestureDetector',
          ],
        ),
        glyph(
          label: 'Quests',
          widgetType: 'Tooltip',
          interactive: false,
          ancestors: [
            'MaterialApp',
            'Scaffold',
            'BottomNavigationBar',
            'Tooltip',
          ],
        ),
      ];
      final gaze = scry.observe(glyphs);
      final quests = gaze.elements.where((e) => e.label == 'Quests').toList();
      // Should dedup to one element since only one is interactive
      expect(quests, hasLength(1));
      expect(quests.first.occurrenceIndex, isNull);
    });

    test('formatGaze shows multiplicity for repeated buttons', () {
      final glyphs = [
        glyph(
          label: 'Remove',
          widgetType: 'IconButton',
          interactive: true,
          y: 100.0,
        ),
        glyph(
          label: 'Remove',
          widgetType: 'IconButton',
          interactive: true,
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      // Should show occurrence count/index
      expect(output, contains('Remove'));
      expect(output, contains('×2'));
    });
  });

  // ===================================================================
  // Form validation awareness
  // ===================================================================
  group('Form validation awareness', () {
    test('detects empty and filled fields', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'username',
          currentValue: 'Kael',
          y: 100.0,
        ),
        glyph(
          label: 'Password',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'password',
          y: 200.0,
        ),
        glyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          interactive: true,
          y: 300.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.totalFields, 2);
      expect(gaze.formStatus!.filledFields, 1);
      expect(gaze.formStatus!.emptyFields, ['Password']);
      expect(gaze.formStatus!.isReady, isFalse);
    });

    test('all fields filled and no errors → isReady', () {
      final glyphs = [
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'name',
          currentValue: 'Kael',
          y: 100.0,
        ),
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'email',
          currentValue: 'kael@titan.io',
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.isReady, isTrue);
      expect(gaze.formStatus!.emptyFields, isEmpty);
      expect(gaze.formStatus!.validationErrors, isEmpty);
    });

    test('detects disabled fields', () {
      final glyphs = [
        glyph(
          label: 'Locked Field',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'locked',
          enabled: false,
          y: 100.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.disabledFields, ['Locked Field']);
    });

    test('detects validation errors near fields', () {
      final glyphs = [
        glyph(
          label: 'Email',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'email',
          currentValue: 'bad',
          x: 16.0,
          y: 100.0,
          w: 350.0,
          h: 56.0,
        ),
        // Error text directly below the field
        glyph(
          label: 'Please enter a valid email',
          x: 16.0,
          y: 130.0,
          w: 200.0,
          h: 16.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.validationErrors, hasLength(1));
      expect(gaze.formStatus!.validationErrors.first.fieldLabel, 'Email');
      expect(
        gaze.formStatus!.validationErrors.first.errorMessage,
        'Please enter a valid email',
      );
      expect(gaze.formStatus!.isReady, isFalse);
    });

    test('ignores error text too far from field', () {
      final glyphs = [
        glyph(
          label: 'Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'name',
          currentValue: 'Kael',
          x: 16.0,
          y: 100.0,
          w: 350.0,
          h: 56.0,
        ),
        // Error text far below — 200px gap
        glyph(
          label: 'This field is required',
          x: 16.0,
          y: 300.0,
          w: 200.0,
          h: 16.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.validationErrors, isEmpty);
    });

    test('no fields → null formStatus', () {
      final glyphs = [
        glyph(label: 'Welcome'),
        glyph(label: 'Start', widgetType: 'ElevatedButton', interactive: true),
      ];
      final gaze = scry.observe(glyphs);
      expect(gaze.formStatus, isNull);
    });

    test('ScryFormStatus serializes to JSON', () {
      const status = ScryFormStatus(
        totalFields: 3,
        filledFields: 2,
        emptyFields: ['Password'],
        validationErrors: [
          ScryFieldError(fieldLabel: 'Email', errorMessage: 'Invalid email'),
        ],
        disabledFields: [],
      );

      final json = status.toJson();
      expect(json['totalFields'], 3);
      expect(json['filledFields'], 2);
      expect(json['emptyFields'], ['Password']);
      expect(json['isReady'], isFalse);
      expect(json['validationErrors'], hasLength(1));
    });

    test('ScryFieldError serializes to JSON', () {
      const error = ScryFieldError(
        fieldLabel: 'Email',
        errorMessage: 'Invalid email',
      );
      final json = error.toJson();
      expect(json['fieldLabel'], 'Email');
      expect(json['errorMessage'], 'Invalid email');
    });

    test('ScryGaze toJson includes formStatus when present', () {
      final glyphs = [
        glyph(
          label: 'Field',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'f',
          y: 100.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final json = gaze.toJson();
      expect(json.containsKey('formStatus'), isTrue);
    });

    test('formatGaze includes form status section', () {
      final glyphs = [
        glyph(
          label: 'Username',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'username',
          currentValue: 'Kael',
          y: 100.0,
        ),
        glyph(
          label: 'Password',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'password',
          y: 200.0,
        ),
      ];
      final gaze = scry.observe(glyphs);
      final output = scry.formatGaze(gaze);
      expect(output, contains('Form Status'));
      expect(output, contains('filled'));
    });
  });

  // ===================================================================
  // Combined capabilities integration
  // ===================================================================
  group('Combined capabilities', () {
    test('observe produces full-featured elements', () {
      final glyphs = [
        // AppBar title
        glyph(
          label: 'Quest Log',
          ancestors: ['MaterialApp', 'Scaffold', 'AppBar', 'Text'],
          y: 40.0,
          depth: 10,
        ),
        // Form field with key
        glyph(
          label: 'Quest Name',
          widgetType: 'TextField',
          interactive: true,
          fieldId: 'questName',
          currentValue: 'Dragon Slayer',
          key: "ValueKey('quest_name')",
          y: 200.0,
          depth: 12,
        ),
        // Submit button in Card context
        glyph(
          label: 'Create Quest',
          widgetType: 'ElevatedButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Card', 'ElevatedButton'],
          y: 400.0,
          depth: 14,
        ),
      ];
      final gaze = scry.observe(glyphs);

      // AppBar title → topBar region
      final title = gaze.elements.firstWhere((e) => e.label == 'Quest Log');
      expect(title.region, ScryScreenRegion.topBar);

      // Field has key and is in main content
      final field = gaze.elements.firstWhere((e) => e.label == 'Quest Name');
      expect(field.key, "ValueKey('quest_name')");
      expect(field.region, ScryScreenRegion.mainContent);

      // Button has Card context
      final btn = gaze.elements.firstWhere((e) => e.label == 'Create Quest');
      expect(btn.context, 'Card');

      // Form status populated
      expect(gaze.formStatus, isNotNull);
      expect(gaze.formStatus!.filledFields, 1);
    });

    test('dialog overlays + multiplicity + key targeting together', () {
      final glyphs = [
        // Three "Edit" buttons in a list (background)
        glyph(
          label: 'Edit',
          widgetType: 'IconButton',
          interactive: true,
          depth: 5,
          x: 300.0,
          y: 100.0,
          w: 48.0,
          h: 48.0,
          key: "ValueKey('edit_0')",
        ),
        glyph(
          label: 'Edit',
          widgetType: 'IconButton',
          interactive: true,
          depth: 5,
          x: 300.0,
          y: 200.0,
          w: 48.0,
          h: 48.0,
          key: "ValueKey('edit_1')",
        ),
        glyph(
          label: 'Edit',
          widgetType: 'IconButton',
          interactive: true,
          depth: 5,
          x: 300.0,
          y: 300.0,
          w: 48.0,
          h: 48.0,
          key: "ValueKey('edit_2')",
        ),
        // Dialog overlay covering the middle area
        glyph(
          label: 'Confirm Edit',
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'Text'],
          depth: 30,
          x: 50.0,
          y: 150.0,
          w: 300.0,
          h: 300.0,
        ),
        glyph(
          label: 'Save',
          widgetType: 'ElevatedButton',
          interactive: true,
          ancestors: ['MaterialApp', 'Scaffold', 'Dialog', 'ElevatedButton'],
          depth: 30,
          x: 200.0,
          y: 400.0,
          w: 100.0,
          h: 48.0,
        ),
      ];
      final gaze = scry.observe(glyphs);

      // All 3 Edit buttons should have multiplicity
      final edits = gaze.elements.where((e) => e.label == 'Edit').toList();
      expect(edits, hasLength(3));
      expect(edits[0].totalOccurrences, 3);

      // Edit buttons 1 and 2 (y=200, y=300) overlap with dialog
      // Edit button 0 (y=100) is above the dialog
      final obscuredEdits = edits.where((e) => e.obscured).toList();
      expect(obscuredEdits, hasLength(2));

      // Keys are preserved even when obscured
      for (final e in edits) {
        expect(e.key, isNotNull);
      }

      // Dialog elements not obscured
      final save = gaze.elements.firstWhere((e) => e.label == 'Save');
      expect(save.obscured, isFalse);
      expect(save.context, 'Dialog');
    });
  });
}
