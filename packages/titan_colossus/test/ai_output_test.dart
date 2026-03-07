import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------

  Glyph createGlyph({
    String widgetType = 'ElevatedButton',
    String? label = 'Submit',
    double left = 10.0,
    double top = 20.0,
    double width = 100.0,
    double height = 48.0,
    bool isInteractive = true,
    String? interactionType = 'tap',
    String? fieldId,
    String? key,
    String? semanticRole = 'button',
    bool isEnabled = true,
    String? currentValue,
    List<String> ancestors = const [],
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
      fieldId: fieldId,
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
    String? route = '/home',
    List<Glyph>? glyphs,
  }) {
    return Tableau(
      index: index,
      timestamp: Duration.zero,
      route: route,
      screenWidth: 375,
      screenHeight: 812,
      glyphs: glyphs ??
          [
            createGlyph(
              label: 'Login',
              left: 100,
              top: 600,
              width: 175,
              height: 48,
            ),
            createGlyph(
              widgetType: 'TextField',
              label: 'Email',
              left: 50,
              top: 200,
              width: 275,
              height: 56,
              interactionType: 'textInput',
              fieldId: 'email',
              semanticRole: 'textField',
            ),
            createGlyph(
              widgetType: 'Text',
              label: 'Welcome Back',
              left: 100,
              top: 100,
              width: 175,
              height: 30,
              isInteractive: false,
              interactionType: null,
              semanticRole: null,
            ),
          ],
    );
  }

  ShadeSession createSession({
    List<Imprint>? imprints,
    List<Tableau>? tableaux,
  }) {
    return ShadeSession(
      id: 'test_session_123',
      name: 'test_flow',
      recordedAt: DateTime(2024, 6, 15),
      duration: const Duration(seconds: 5),
      screenWidth: 375,
      screenHeight: 812,
      devicePixelRatio: 3.0,
      startRoute: '/home',
      imprints: imprints ?? [],
      tableaux: tableaux ?? [],
    );
  }

  // ---------------------------------------------------------
  // Imprint.resolveTargetGlyph
  // ---------------------------------------------------------

  group('Imprint.resolveTargetGlyph', () {
    test('resolves interactive Glyph at tap position', () {
      final tableau = createTableau();
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 150.0, // Inside Login button (100-275, 600-648)
        positionY: 620.0,
        timestamp: const Duration(seconds: 1),
        tableauIndex: 0,
      );

      final glyph = imprint.resolveTargetGlyph(tableau);
      expect(glyph, isNotNull);
      expect(glyph!.label, 'Login');
      expect(glyph.isInteractive, true);
    });

    test('resolves non-interactive Glyph as fallback', () {
      final tableau = createTableau();
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 150.0, // Inside Welcome text (100-275, 100-130)
        positionY: 110.0,
        timestamp: const Duration(seconds: 1),
        tableauIndex: 0,
      );

      final glyph = imprint.resolveTargetGlyph(tableau);
      expect(glyph, isNotNull);
      expect(glyph!.label, 'Welcome Back');
    });

    test('returns null when no Glyph at position', () {
      final tableau = createTableau();
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 350.0, // Empty area
        positionY: 750.0,
        timestamp: const Duration(seconds: 1),
        tableauIndex: 0,
      );

      final glyph = imprint.resolveTargetGlyph(tableau);
      expect(glyph, isNull);
    });

    test('returns null for zero-position imprints (text/key)', () {
      final tableau = createTableau();
      final imprint = Imprint(
        type: ImprintType.textInput,
        positionX: 0,
        positionY: 0,
        timestamp: const Duration(seconds: 1),
        text: 'hello',
      );

      final glyph = imprint.resolveTargetGlyph(tableau);
      expect(glyph, isNull);
    });
  });

  // ---------------------------------------------------------
  // ShadeSession.generateFlowDescription
  // ---------------------------------------------------------

  group('ShadeSession.generateFlowDescription', () {
    test('includes session metadata', () {
      final session = createSession(
        tableaux: [createTableau()],
      );

      final desc = session.generateFlowDescription();

      expect(desc, contains('test_flow'));
      expect(desc, contains('5.0s'));
      expect(desc, contains('Start Route: /home'));
    });

    test('describes initial Tableau', () {
      final session = createSession(
        tableaux: [createTableau()],
      );

      final desc = session.generateFlowDescription();

      expect(desc, contains('Initial Screen'));
      expect(desc, contains('Route: /home'));
      expect(desc, contains('Login'));
      expect(desc, contains('Email'));
    });

    test('describes tap steps with resolved targets', () {
      final tableau = createTableau();
      final session = createSession(
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 150,
            positionY: 620,
            timestamp: const Duration(seconds: 2),
            tableauIndex: 0,
          ),
        ],
        tableaux: [tableau],
      );

      final desc = session.generateFlowDescription();

      expect(desc, contains('Step 1'));
      expect(desc, contains('Tap'));
      expect(desc, contains('Login'));
    });

    test('describes text input steps', () {
      final tableau = createTableau();
      final session = createSession(
        imprints: [
          Imprint(
            type: ImprintType.textInput,
            positionX: 0,
            positionY: 0,
            timestamp: const Duration(seconds: 1),
            text: 'user@example.com',
            fieldId: 'email',
            tableauIndex: 0,
          ),
        ],
        tableaux: [tableau],
      );

      final desc = session.generateFlowDescription();

      expect(desc, contains('Text Input'));
      expect(desc, contains('user@example.com'));
      expect(desc, contains('email'));
    });

    test('returns sensible output with no tableaux', () {
      final session = createSession(
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 100,
            positionY: 200,
            timestamp: const Duration(seconds: 1),
          ),
        ],
      );

      final desc = session.generateFlowDescription();

      expect(desc, contains('test_flow'));
      expect(desc, contains('Step 1'));
    });

    test('shows diff between tableaux', () {
      final before = createTableau(index: 0, glyphs: [
        createGlyph(label: 'Login', key: 'login_btn'),
      ]);
      final after = createTableau(index: 1, glyphs: [
        createGlyph(label: 'Login', key: 'login_btn', isEnabled: false),
      ]);

      final session = createSession(
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 150,
            positionY: 30,
            timestamp: const Duration(seconds: 1),
            tableauIndex: 0,
          ),
        ],
        tableaux: [before, after],
      );

      final desc = session.generateFlowDescription();
      expect(desc, contains('CHANGED'));
    });
  });

  // ---------------------------------------------------------
  // ShadeSession.toAiTestSpec
  // ---------------------------------------------------------

  group('ShadeSession.toAiTestSpec', () {
    test('includes session metadata', () {
      final session = createSession();
      final spec = session.toAiTestSpec();

      expect(spec['session'], isA<Map>());
      expect(spec['session']['name'], 'test_flow');
      expect(spec['session']['durationMs'], 5000);
      expect(spec['session']['startRoute'], '/home');
    });

    test('includes tableaux summaries', () {
      final session = createSession(
        tableaux: [createTableau()],
      );
      final spec = session.toAiTestSpec();

      expect(spec['tableaux'], isA<List>());
      expect(spec['tableaux'], hasLength(1));
      expect(spec['tableaux'][0]['route'], '/home');
      expect(spec['tableaux'][0]['summary'], isA<String>());
    });

    test('includes steps with resolved targets', () {
      final tableau = createTableau();
      final session = createSession(
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 150,
            positionY: 620,
            timestamp: const Duration(seconds: 2),
            tableauIndex: 0,
          ),
        ],
        tableaux: [tableau],
      );

      final spec = session.toAiTestSpec();

      expect(spec['steps'], hasLength(1));
      expect(spec['steps'][0]['action'], 'tap');
      expect(spec['steps'][0]['target'], isNotNull);
      expect(spec['steps'][0]['target']['label'], 'Login');
    });

    test('includes text input data', () {
      final session = createSession(
        imprints: [
          Imprint(
            type: ImprintType.textInput,
            positionX: 0,
            positionY: 0,
            timestamp: const Duration(seconds: 1),
            text: 'hello@world.com',
            fieldId: 'email',
            tableauIndex: 0,
          ),
        ],
        tableaux: [createTableau()],
      );

      final spec = session.toAiTestSpec();

      expect(spec['steps'][0]['action'], 'enterText');
      expect(spec['steps'][0]['text'], 'hello@world.com');
      expect(spec['steps'][0]['fieldId'], 'email');
    });

    test('filters out insignificant events', () {
      final session = createSession(
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 100,
            positionY: 200,
            timestamp: const Duration(milliseconds: 100),
          ),
          Imprint(
            type: ImprintType.pointerMove,
            positionX: 101,
            positionY: 201,
            timestamp: const Duration(milliseconds: 150),
          ),
          Imprint(
            type: ImprintType.pointerUp,
            positionX: 101,
            positionY: 201,
            timestamp: const Duration(milliseconds: 200),
          ),
        ],
      );

      final spec = session.toAiTestSpec();

      // Only pointerDown is significant — move and up are filtered
      expect(spec['steps'], hasLength(1));
      expect(spec['steps'][0]['action'], 'tap');
    });

    test('includes tableau diffs for subsequent tableaux', () {
      final t0 = createTableau(index: 0, glyphs: [
        createGlyph(label: 'A', key: 'a'),
      ]);
      final t1 = createTableau(index: 1, glyphs: [
        createGlyph(label: 'A', key: 'a'),
        createGlyph(label: 'B', key: 'b'),
      ]);

      final session = createSession(tableaux: [t0, t1]);
      final spec = session.toAiTestSpec();

      // First tableau has no diff, second does
      expect(spec['tableaux'][0].containsKey('diff'), false);
      expect(spec['tableaux'][1].containsKey('diff'), true);
    });
  });
}
