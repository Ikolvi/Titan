import 'dart:typed_data';

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
    Duration timestamp = Duration.zero,
    String? route = '/home',
    double screenWidth = 375.0,
    double screenHeight = 812.0,
    List<Glyph>? glyphs,
    int triggerImprintIndex = -1,
    Uint8List? fresco,
  }) {
    return Tableau(
      index: index,
      timestamp: timestamp,
      route: route,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      glyphs: glyphs ?? [
        createGlyph(label: 'Submit', left: 10, top: 20),
        createGlyph(
          widgetType: 'TextField',
          label: 'Email',
          left: 10,
          top: 80,
          interactionType: 'textInput',
          fieldId: 'email',
          semanticRole: 'textField',
        ),
        createGlyph(
          widgetType: 'Text',
          label: 'Welcome',
          left: 10,
          top: 5,
          isInteractive: false,
          interactionType: null,
          semanticRole: null,
        ),
      ],
      triggerImprintIndex: triggerImprintIndex,
      fresco: fresco,
    );
  }

  // ---------------------------------------------------------
  // Tableau — screen snapshot
  // ---------------------------------------------------------

  group('Tableau', () {
    test('creates with required fields', () {
      final tableau = createTableau();

      expect(tableau.index, 0);
      expect(tableau.timestamp, Duration.zero);
      expect(tableau.route, '/home');
      expect(tableau.screenWidth, 375.0);
      expect(tableau.screenHeight, 812.0);
      expect(tableau.glyphs, hasLength(3));
      expect(tableau.triggerImprintIndex, -1);
      expect(tableau.fresco, isNull);
    });

    // -------------------------------------------------------
    // Computed properties
    // -------------------------------------------------------

    group('interactiveGlyphs', () {
      test('filters to interactive Glyphs only', () {
        final tableau = createTableau();
        final interactive = tableau.interactiveGlyphs;

        expect(interactive, hasLength(2));
        expect(
          interactive.every((g) => g.isInteractive),
          true,
        );
      });
    });

    // -------------------------------------------------------
    // Hit-test methods
    // -------------------------------------------------------

    group('glyphAt', () {
      test('returns interactive Glyph at coordinates', () {
        final tableau = createTableau();
        final hit = tableau.glyphAt(50, 40);

        expect(hit, isNotNull);
        expect(hit!.label, 'Submit');
      });

      test('returns null when no interactive Glyph at coordinates', () {
        final tableau = createTableau();
        // Point inside the Text but not any interactive widget
        final hit = tableau.glyphAt(50, 10);

        expect(hit, isNull);
      });

      test('returns null for empty area', () {
        final tableau = createTableau();
        final hit = tableau.glyphAt(300, 600);

        expect(hit, isNull);
      });
    });

    group('anyGlyphAt', () {
      test('returns any Glyph at coordinates including non-interactive', () {
        final tableau = createTableau();
        // Point inside the Text (non-interactive)
        final hit = tableau.anyGlyphAt(50, 10);

        expect(hit, isNotNull);
        expect(hit!.label, 'Welcome');
      });
    });

    // -------------------------------------------------------
    // Find methods
    // -------------------------------------------------------

    group('findByLabel', () {
      test('finds Glyphs by label substring', () {
        final tableau = createTableau();
        final results = tableau.findByLabel('Sub');

        expect(results, hasLength(1));
        expect(results.first.label, 'Submit');
      });

      test('returns empty when no match', () {
        final tableau = createTableau();
        final results = tableau.findByLabel('NonExistentLabel');

        expect(results, isEmpty);
      });

      test('is case-insensitive', () {
        final tableau = createTableau();
        final results = tableau.findByLabel('submit');

        expect(results, hasLength(1));
      });
    });

    group('findByType', () {
      test('finds Glyph by widget type', () {
        final tableau = createTableau();
        final result = tableau.findByType('TextField');

        expect(result, isNotNull);
        expect(result!.fieldId, 'email');
      });

      test('returns null when type not found', () {
        final tableau = createTableau();
        final result = tableau.findByType('Slider');

        expect(result, isNull);
      });
    });

    group('findByKey', () {
      test('finds Glyph by key', () {
        final tableau = createTableau(
          glyphs: [
            createGlyph(key: 'submit_btn', label: 'Submit'),
          ],
        );
        final result = tableau.findByKey('submit_btn');

        expect(result, isNotNull);
        expect(result!.label, 'Submit');
      });

      test('returns null when key not found', () {
        final tableau = createTableau();
        final result = tableau.findByKey('nonexistent');

        expect(result, isNull);
      });
    });

    // -------------------------------------------------------
    // Summary
    // -------------------------------------------------------

    test('summary produces AI-readable text', () {
      final tableau = createTableau();
      final summary = tableau.summary;

      expect(summary, contains('Route: /home'));
      expect(summary, contains('2 interactive'));
      expect(summary, contains('3 visible'));
      expect(summary, contains('ElevatedButton'));
      expect(summary, contains('Submit'));
    });

    // -------------------------------------------------------
    // Structural equality
    // -------------------------------------------------------

    group('isStructurallyEqual', () {
      test('identical Glyphs are structurally equal', () {
        final a = createTableau();
        final b = createTableau();

        expect(a.isStructurallyEqual(b), true);
      });

      test('different routes are not structurally equal', () {
        final a = createTableau(route: '/home');
        final b = createTableau(route: '/settings');

        expect(a.isStructurallyEqual(b), false);
      });

      test('different Glyph count is not structurally equal', () {
        final a = createTableau(glyphs: [createGlyph()]);
        final b = createTableau(glyphs: [createGlyph(), createGlyph()]);

        expect(a.isStructurallyEqual(b), false);
      });

      test('same Glyphs different order is not structurally equal', () {
        final g1 = createGlyph(label: 'A');
        final g2 = createGlyph(label: 'B');
        final a = createTableau(glyphs: [g1, g2]);
        final b = createTableau(glyphs: [g2, g1]);

        expect(a.isStructurallyEqual(b), false);
      });
    });

    // -------------------------------------------------------
    // Serialization
    // -------------------------------------------------------

    group('serialization', () {
      test('toMap includes all fields', () {
        final tableau = createTableau(
          index: 2,
          timestamp: const Duration(seconds: 5),
          triggerImprintIndex: 12,
        );
        final map = tableau.toMap();

        expect(map['idx'], 2);
        expect(map['ts'], const Duration(seconds: 5).inMicroseconds);
        expect(map['route'], '/home');
        expect(map['sw'], 375.0);
        expect(map['sh'], 812.0);
        expect(map['trigger'], 12);
        expect(map['glyphs'], hasLength(3));
      });

      test('toMap omits null route', () {
        final tableau = createTableau(route: null);
        final map = tableau.toMap();

        expect(map.containsKey('route'), false);
      });

      test('toMap omits fresco when null', () {
        final tableau = createTableau();
        final map = tableau.toMap();

        expect(map.containsKey('fresco'), false);
      });

      test('fromMap round-trips all fields', () {
        final original = createTableau(
          index: 3,
          timestamp: const Duration(milliseconds: 2500),
          route: '/cart',
          triggerImprintIndex: 7,
        );
        final restored = Tableau.fromMap(original.toMap());

        expect(restored.index, original.index);
        expect(restored.timestamp, original.timestamp);
        expect(restored.route, original.route);
        expect(restored.screenWidth, original.screenWidth);
        expect(restored.screenHeight, original.screenHeight);
        expect(restored.triggerImprintIndex, original.triggerImprintIndex);
        expect(restored.glyphs.length, original.glyphs.length);

        for (var i = 0; i < original.glyphs.length; i++) {
          expect(restored.glyphs[i].widgetType, original.glyphs[i].widgetType);
          expect(restored.glyphs[i].label, original.glyphs[i].label);
        }
      });

      test('fromMap round-trips minimal Tableau', () {
        final original = Tableau(
          index: 0,
          timestamp: Duration.zero,
          screenWidth: 400,
          screenHeight: 800,
          glyphs: [],
        );
        final restored = Tableau.fromMap(original.toMap());

        expect(restored.index, 0);
        expect(restored.route, isNull);
        expect(restored.glyphs, isEmpty);
        expect(restored.fresco, isNull);
      });
    });

    // -------------------------------------------------------
    // copyWith
    // -------------------------------------------------------

    group('copyWith', () {
      test('copies with changed route', () {
        final original = createTableau(route: '/home');
        final copy = original.copyWith(route: '/settings');

        expect(copy.route, '/settings');
        expect(copy.index, original.index);
        expect(copy.glyphs, original.glyphs);
      });

      test('copies with changed index', () {
        final original = createTableau(index: 0);
        final copy = original.copyWith(index: 5);

        expect(copy.index, 5);
        expect(copy.route, original.route);
      });
    });

    // -------------------------------------------------------
    // toString
    // -------------------------------------------------------

    test('toString produces readable output', () {
      final tableau = createTableau();
      final str = tableau.toString();

      expect(str, contains('Tableau'));
      expect(str, contains('/home'));
      expect(str, contains('3 glyphs'));
    });
  });

  // ---------------------------------------------------------
  // TableauDiff — screen change detection
  // ---------------------------------------------------------

  group('TableauDiff', () {
    test('detects added Glyphs', () {
      final before = createTableau(glyphs: [
        createGlyph(label: 'A', widgetType: 'Text', depth: 3),
      ]);
      final after = createTableau(glyphs: [
        createGlyph(label: 'A', widgetType: 'Text', depth: 3),
        createGlyph(label: 'B', widgetType: 'Text', depth: 4),
      ]);

      final diff = before.diff(after);

      expect(diff.added, hasLength(1));
      expect(diff.added.first.label, 'B');
      expect(diff.removed, isEmpty);
    });

    test('detects removed Glyphs', () {
      final before = createTableau(glyphs: [
        createGlyph(label: 'A', widgetType: 'Text', depth: 3),
        createGlyph(label: 'B', widgetType: 'Text', depth: 4),
      ]);
      final after = createTableau(glyphs: [
        createGlyph(label: 'A', widgetType: 'Text', depth: 3),
      ]);

      final diff = before.diff(after);

      expect(diff.removed, hasLength(1));
      expect(diff.removed.first.label, 'B');
      expect(diff.added, isEmpty);
    });

    test('detects changed Glyphs', () {
      final before = createTableau(glyphs: [
        createGlyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          key: 'submit',
          isEnabled: true,
        ),
      ]);
      final after = createTableau(glyphs: [
        createGlyph(
          label: 'Submit',
          widgetType: 'ElevatedButton',
          key: 'submit',
          isEnabled: false,
        ),
      ]);

      final diff = before.diff(after);

      expect(diff.changed, hasLength(1));
      expect(diff.changed.first.enabledChanged, true);
      expect(diff.changed.first.previous.isEnabled, true);
      expect(diff.changed.first.current.isEnabled, false);
    });

    test('empty diff when Tableaux are identical', () {
      final a = createTableau();
      final b = createTableau();

      final diff = a.diff(b);

      expect(diff.added, isEmpty);
      expect(diff.removed, isEmpty);
      expect(diff.changed, isEmpty);
      expect(diff.hasChanges, false);
    });

    test('hasChanges returns true when there are changes', () {
      final a = createTableau(glyphs: []);
      final b = createTableau(glyphs: [createGlyph()]);

      final diff = a.diff(b);
      expect(diff.hasChanges, true);
    });

    test('toString produces readable output', () {
      final before = createTableau(glyphs: []);
      final after = createTableau(glyphs: [
        createGlyph(label: 'New Button'),
      ]);

      final diff = before.diff(after);
      final str = diff.toString();

      expect(str, contains('ADDED'));
    });
  });

  // ---------------------------------------------------------
  // GlyphChange — individual Glyph mutation
  // ---------------------------------------------------------

  group('GlyphChange', () {
    test('detects label change', () {
      final prev = createGlyph(label: 'Submit', key: 'btn');
      final curr = createGlyph(label: 'Submitting...', key: 'btn');

      final change = GlyphChange(previous: prev, current: curr);

      expect(change.labelChanged, true);
      expect(change.enabledChanged, false);
      expect(change.valueChanged, false);
    });

    test('detects value change', () {
      final prev = createGlyph(
        widgetType: 'Checkbox',
        key: 'agree',
        currentValue: 'false',
      );
      final curr = createGlyph(
        widgetType: 'Checkbox',
        key: 'agree',
        currentValue: 'true',
      );

      final change = GlyphChange(previous: prev, current: curr);

      expect(change.valueChanged, true);
      expect(change.labelChanged, false);
    });

    test('detects position change', () {
      final prev = createGlyph(left: 10, top: 20, key: 'btn');
      final curr = createGlyph(left: 10, top: 80, key: 'btn');

      final change = GlyphChange(previous: prev, current: curr);

      expect(change.positionChanged, true);
    });

    test('description summarizes changes', () {
      final prev = createGlyph(label: 'OK', isEnabled: true, key: 'btn');
      final curr = createGlyph(label: 'OK', isEnabled: false, key: 'btn');

      final change = GlyphChange(previous: prev, current: curr);

      expect(change.description, contains('enabled'));
    });
  });

  // ---------------------------------------------------------
  // Imprint tableauIndex field
  // ---------------------------------------------------------

  group('Imprint tableauIndex', () {
    test('defaults to null', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100,
        positionY: 200,
        timestamp: const Duration(milliseconds: 500),
      );

      expect(imprint.tableauIndex, isNull);
    });

    test('serializes when set', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100,
        positionY: 200,
        timestamp: const Duration(milliseconds: 500),
        tableauIndex: 3,
      );
      final map = imprint.toMap();

      expect(map['tIdx'], 3);
    });

    test('omits from map when null', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100,
        positionY: 200,
        timestamp: const Duration(milliseconds: 500),
      );
      final map = imprint.toMap();

      expect(map.containsKey('tIdx'), false);
    });

    test('round-trips through serialization', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100,
        positionY: 200,
        timestamp: const Duration(milliseconds: 500),
        tableauIndex: 7,
      );
      final restored = Imprint.fromMap(imprint.toMap());

      expect(restored.tableauIndex, 7);
    });
  });

  // ---------------------------------------------------------
  // ShadeSession tableaux field
  // ---------------------------------------------------------

  group('ShadeSession tableaux', () {
    ShadeSession createSession({
      List<Tableau>? tableaux,
    }) {
      return ShadeSession(
        id: 'test-session',
        name: 'Test Session',
        recordedAt: DateTime(2024, 1, 1),
        duration: const Duration(seconds: 10),
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 3.0,
        imprints: [
          Imprint(
            type: ImprintType.pointerDown,
            positionX: 50,
            positionY: 100,
            timestamp: const Duration(seconds: 1),
            tableauIndex: 0,
          ),
        ],
        tableaux: tableaux ?? [],
      );
    }

    test('defaults to empty list', () {
      final session = ShadeSession(
        id: 'id',
        name: 'name',
        recordedAt: DateTime(2024),
        duration: Duration.zero,
        screenWidth: 375,
        screenHeight: 812,
        devicePixelRatio: 3.0,
        imprints: [],
      );

      expect(session.tableaux, isEmpty);
    });

    test('serializes tableaux when non-empty', () {
      final session = createSession(
        tableaux: [createTableau()],
      );
      final map = session.toMap();

      expect(map.containsKey('tableaux'), true);
      expect(map['tableaux'], hasLength(1));
    });

    test('omits tableaux from map when empty', () {
      final session = createSession(tableaux: []);
      final map = session.toMap();

      expect(map.containsKey('tableaux'), false);
    });

    test('round-trips tableaux through serialization', () {
      final tableau = createTableau(
        index: 0,
        route: '/login',
        glyphs: [
          createGlyph(label: 'Login'),
          createGlyph(
            widgetType: 'TextField',
            label: 'Email',
            fieldId: 'email',
            interactionType: 'textInput',
          ),
        ],
      );
      final session = createSession(tableaux: [tableau]);
      final json = session.toJson();
      final restored = ShadeSession.fromJson(json);

      expect(restored.tableaux, hasLength(1));
      expect(restored.tableaux.first.route, '/login');
      expect(restored.tableaux.first.glyphs, hasLength(2));
      expect(restored.tableaux.first.glyphs.first.label, 'Login');
    });

    test('backward compatible with sessions without tableaux', () {
      // Simulate old session JSON without tableaux key
      final oldMap = {
        'id': 'old-session',
        'name': 'Old Session',
        'recordedAt': '2024-01-01T00:00:00.000',
        'durationUs': 10000000,
        'screenWidth': 375.0,
        'screenHeight': 812.0,
        'devicePixelRatio': 3.0,
        'eventCount': 0,
        'imprints': <Map<String, dynamic>>[],
      };
      final session = ShadeSession.fromMap(oldMap);

      expect(session.tableaux, isEmpty);
    });
  });
}
