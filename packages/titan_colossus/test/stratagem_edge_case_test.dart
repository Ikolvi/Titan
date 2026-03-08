import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/recording/glyph.dart';
import 'package:titan_colossus/src/recording/tableau.dart';
import 'package:titan_colossus/src/testing/stratagem.dart';

void main() {
  // -------------------------------------------------------------------------
  // Stratagem.interpolate() edge cases
  // -------------------------------------------------------------------------
  group('Stratagem — interpolate edge cases', () {
    test('empty testData map returns original string', () {
      const s = Stratagem(
        name: 'test',
        startRoute: '/',
        testData: {},
        steps: [],
      );
      expect(s.interpolate(r'${testData.email}'), r'${testData.email}');
    });

    test('mixed known + unknown variables resolve correctly', () {
      const s = Stratagem(
        name: 'test',
        startRoute: '/',
        testData: {'user': 'Alice'},
        steps: [],
      );
      final result = s.interpolate(
        r'Hello ${testData.user}, ${testData.missing}!',
      );
      expect(result, r'Hello Alice, ${testData.missing}!');
    });

    test('keys with underscores and digits resolve', () {
      const s = Stratagem(
        name: 'test',
        startRoute: '/',
        testData: {'user_name_2': 'Bob'},
        steps: [],
      );
      expect(s.interpolate(r'${testData.user_name_2}'), 'Bob');
    });

    test('no interpolation markers returns string unchanged', () {
      const s = Stratagem(
        name: 'test',
        startRoute: '/',
        testData: {'x': 'y'},
        steps: [],
      );
      expect(s.interpolate('plain text'), 'plain text');
    });

    test('null testData returns original string', () {
      const s = Stratagem(name: 'test', startRoute: '/', steps: []);
      expect(s.interpolate(r'${testData.any}'), r'${testData.any}');
    });
  });

  // -------------------------------------------------------------------------
  // Stratagem.toJson() conditional fields
  // -------------------------------------------------------------------------
  group('Stratagem — toJson conditional fields', () {
    test('empty description is omitted from JSON', () {
      const s = Stratagem(
        name: 'test',
        startRoute: '/',
        description: '',
        steps: [],
      );
      final json = s.toJson();
      expect(json.containsKey('description'), isFalse);
    });

    test('empty tags list is omitted from JSON', () {
      const s = Stratagem(name: 'test', startRoute: '/', tags: [], steps: []);
      final json = s.toJson();
      expect(json.containsKey('tags'), isFalse);
    });

    test('preconditions is included when non-null', () {
      const s = Stratagem(
        name: 'test',
        startRoute: '/',
        preconditions: {'authenticated': false},
        steps: [],
      );
      final json = s.toJson();
      expect(json['preconditions'], {'authenticated': false});
    });

    test('preconditions round-trips through JSON', () {
      const s = Stratagem(
        name: 'test',
        startRoute: '/',
        preconditions: {'lang': 'en', 'darkMode': true},
        testData: {'user': 'Alice'},
        steps: [],
      );
      final rebuilt = Stratagem.fromJson(s.toJson());
      expect(rebuilt.preconditions, {'lang': 'en', 'darkMode': true});
      expect(rebuilt.testData, {'user': 'Alice'});
    });
  });

  // -------------------------------------------------------------------------
  // Stratagem.fromJson() edge cases
  // -------------------------------------------------------------------------
  group('Stratagem — fromJson edge cases', () {
    test('missing steps key defaults to empty list', () {
      final json = {
        r'$schema': 'titan://stratagem/v1',
        'name': 'test',
        'startRoute': '/',
      };
      final s = Stratagem.fromJson(json);
      expect(s.steps, isEmpty);
    });

    test('unknown failurePolicy string defaults to abortOnFirst', () {
      final json = {
        r'$schema': 'titan://stratagem/v1',
        'name': 'test',
        'startRoute': '/',
        'failurePolicy': 'someInvalidPolicy',
        'steps': [],
      };
      final s = Stratagem.fromJson(json);
      expect(s.failurePolicy, StratagemFailurePolicy.abortOnFirst);
    });
  });

  // -------------------------------------------------------------------------
  // StratagemStep — field roundtrips
  // -------------------------------------------------------------------------
  group('StratagemStep — untested field roundtrips', () {
    test('repeatCount survives serialization', () {
      const step = StratagemStep(
        id: 1,
        action: StratagemAction.scroll,
        repeatCount: 5,
      );
      final json = step.toJson();
      final rebuilt = StratagemStep.fromJson(json);
      expect(rebuilt.repeatCount, 5);
    });

    test('keyId survives serialization', () {
      const step = StratagemStep(
        id: 1,
        action: StratagemAction.pressKey,
        keyId: 'enter',
      );
      final json = step.toJson();
      final rebuilt = StratagemStep.fromJson(json);
      expect(rebuilt.keyId, 'enter');
    });

    test('step-level timeout survives serialization as ms', () {
      const step = StratagemStep(
        id: 1,
        action: StratagemAction.wait,
        timeout: Duration(seconds: 5),
      );
      final json = step.toJson();
      expect(json['timeout'], 5000);
      final rebuilt = StratagemStep.fromJson(json);
      expect(rebuilt.timeout, const Duration(seconds: 5));
    });
  });

  // -------------------------------------------------------------------------
  // StratagemStep._actionFromName()
  // -------------------------------------------------------------------------
  group('StratagemStep — _actionFromName', () {
    test('invalid action string throws FormatException', () {
      final json = {'id': 1, 'action': 'fly', 'description': ''};
      expect(
        () => StratagemStep.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('FormatException message lists valid actions', () {
      final json = {'id': 1, 'action': 'teleport', 'description': ''};
      try {
        StratagemStep.fromJson(json);
        fail('Should have thrown');
      } on FormatException catch (e) {
        expect(e.message, contains('teleport'));
        expect(e.message, contains('tap'));
        expect(e.message, contains('enterText'));
      }
    });
  });

  // -------------------------------------------------------------------------
  // StratagemTarget.resolve() edge cases
  // -------------------------------------------------------------------------
  group('StratagemTarget — resolve edge cases', () {
    Tableau makeTableau([List<Glyph>? glyphs]) {
      return Tableau(
        index: 0,
        timestamp: Duration.zero,
        glyphs: glyphs ?? [],
        route: '/test',
        screenWidth: 400,
        screenHeight: 800,
      );
    }

    test('empty tableau returns null', () {
      const target = StratagemTarget(label: 'OK');
      expect(target.resolve(makeTableau()), isNull);
    });

    test('index out of bounds returns null', () {
      const target = StratagemTarget(label: 'OK', index: 5);
      final tableau = makeTableau([
        Glyph(
          label: 'OK',
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
      ]);
      expect(target.resolve(tableau), isNull);
    });

    test('ancestor mismatch returns null', () {
      const target = StratagemTarget(label: 'OK', ancestor: 'Dialog');
      final tableau = makeTableau([
        Glyph(
          label: 'OK',
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const ['Scaffold', 'Column'],
          isInteractive: false,
          isEnabled: true,
        ),
      ]);
      expect(target.resolve(tableau), isNull);
    });

    test('ancestor match returns glyph', () {
      const target = StratagemTarget(label: 'OK', ancestor: 'Column');
      final tableau = makeTableau([
        Glyph(
          label: 'OK',
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const ['Scaffold', 'Column'],
          isInteractive: false,
          isEnabled: true,
        ),
      ]);
      final result = target.resolve(tableau);
      expect(result, isNotNull);
      expect(result!.label, 'OK');
    });

    test('all filter criteria combined narrows to target', () {
      const target = StratagemTarget(
        label: 'Submit',
        type: 'ElevatedButton',
        key: 'submitBtn',
        semanticRole: 'button',
        ancestor: 'Form',
        index: 0,
      );
      final glyph = Glyph(
        label: 'Submit',
        widgetType: 'ElevatedButton',
        key: 'submitBtn',
        semanticRole: 'button',
        left: 50,
        top: 200,
        width: 200,
        height: 60,
        ancestors: const ['Scaffold', 'Form'],
        isInteractive: true,
        isEnabled: true,
      );
      final tableau = makeTableau([
        // Decoy
        Glyph(
          label: 'Submit',
          widgetType: 'TextButton',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const ['Scaffold'],
          isInteractive: true,
          isEnabled: true,
        ),
        glyph,
      ]);
      final result = target.resolve(tableau);
      expect(result, isNotNull);
      expect(result!.key, 'submitBtn');
    });
  });

  // -------------------------------------------------------------------------
  // StratagemTarget.fuzzyResolve() edge cases
  // -------------------------------------------------------------------------
  group('StratagemTarget — fuzzyResolve edge cases', () {
    Tableau makeTableau([List<Glyph>? glyphs]) {
      return Tableau(
        index: 0,
        timestamp: Duration.zero,
        glyphs: glyphs ?? [],
        route: '/test',
        screenWidth: 400,
        screenHeight: 800,
      );
    }

    test('fuzzy with index picks correct match', () {
      const target = StratagemTarget(label: 'Item', index: 1);
      final tableau = makeTableau([
        Glyph(
          label: 'Item Alpha',
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
        Glyph(
          label: 'Item Beta',
          widgetType: 'Text',
          left: 0,
          top: 60,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
      ]);
      final result = target.fuzzyResolve(tableau);
      expect(result, isNotNull);
      expect(result!.label, 'Item Beta');
    });

    test('fuzzy with index out of bounds returns null', () {
      const target = StratagemTarget(label: 'Item', index: 5);
      final tableau = makeTableau([
        Glyph(
          label: 'Item one',
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
      ]);
      expect(target.fuzzyResolve(tableau), isNull);
    });

    test('fuzzy with null label and type-only fails gracefully', () {
      const target = StratagemTarget(type: 'Switch');
      final tableau = makeTableau([
        Glyph(
          label: 'Toggle',
          widgetType: 'Switch',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: true,
          isEnabled: true,
        ),
      ]);
      // fuzzy match requires label for partial matching; type-only
      // falls through to exact resolve, which also needs label match.
      // Since target.label is null, exact resolve skips label check.
      final result = target.fuzzyResolve(tableau);
      // With type match only, exact resolve should find it
      expect(result, isNotNull);
      expect(result!.widgetType, 'Switch');
    });

    test('multiple fuzzy matches without index returns first', () {
      const target = StratagemTarget(label: 'Opt');
      final tableau = makeTableau([
        Glyph(
          label: 'Option A',
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
        Glyph(
          label: 'Option B',
          widgetType: 'Text',
          left: 0,
          top: 60,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
      ]);
      final result = target.fuzzyResolve(tableau);
      expect(result, isNotNull);
      expect(result!.label, 'Option A');
    });
  });

  // -------------------------------------------------------------------------
  // StratagemTarget — interactive-preference ranking
  // -------------------------------------------------------------------------
  group('StratagemTarget — interactive preference', () {
    Tableau makeTableau([List<Glyph>? glyphs]) {
      return Tableau(
        index: 0,
        timestamp: Duration.zero,
        glyphs: glyphs ?? [],
        route: '/test',
        screenWidth: 400,
        screenHeight: 800,
      );
    }

    test(
      'resolve prefers interactive glyph over non-interactive (label-only)',
      () {
        // Simulates NavigationBar scenario: Text("Hero") appears before
        // GestureDetector("Hero") in the glyph list.
        const target = StratagemTarget(label: 'Hero');
        final tableau = makeTableau([
          Glyph(
            label: 'Hero',
            widgetType: 'Text',
            left: 100,
            top: 500,
            width: 60,
            height: 20,
            ancestors: const ['NavigationDestination'],
            isInteractive: false,
            isEnabled: true,
          ),
          Glyph(
            label: 'Hero',
            widgetType: 'GestureDetector',
            left: 100,
            top: 490,
            width: 80,
            height: 40,
            ancestors: const ['NavigationBar'],
            isInteractive: true,
            isEnabled: true,
          ),
        ]);
        final result = target.resolve(tableau);
        expect(result, isNotNull);
        expect(result!.widgetType, 'GestureDetector');
        expect(result.isInteractive, isTrue);
      },
    );

    test('resolve with explicit type ignores interactive ranking', () {
      const target = StratagemTarget(label: 'Hero', type: 'Text');
      final tableau = makeTableau([
        Glyph(
          label: 'Hero',
          widgetType: 'Text',
          left: 100,
          top: 500,
          width: 60,
          height: 20,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
        Glyph(
          label: 'Hero',
          widgetType: 'GestureDetector',
          left: 100,
          top: 490,
          width: 80,
          height: 40,
          ancestors: const [],
          isInteractive: true,
          isEnabled: true,
        ),
      ]);
      final result = target.resolve(tableau);
      expect(result, isNotNull);
      expect(result!.widgetType, 'Text');
    });

    test('resolve with preferInteractive: false returns first match', () {
      const target = StratagemTarget(label: 'Hero');
      final tableau = makeTableau([
        Glyph(
          label: 'Hero',
          widgetType: 'Text',
          left: 100,
          top: 500,
          width: 60,
          height: 20,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
        Glyph(
          label: 'Hero',
          widgetType: 'GestureDetector',
          left: 100,
          top: 490,
          width: 80,
          height: 40,
          ancestors: const [],
          isInteractive: true,
          isEnabled: true,
        ),
      ]);
      final result = target.resolve(tableau, preferInteractive: false);
      expect(result, isNotNull);
      expect(result!.widgetType, 'Text');
      expect(result.isInteractive, isFalse);
    });

    test('fuzzyResolve prefers interactive in partial label match', () {
      // AI writes "Sign" to match "Sign Out" — should prefer IconButton
      const target = StratagemTarget(label: 'Sign');
      final tableau = makeTableau([
        Glyph(
          label: 'Sign Out',
          widgetType: 'Text',
          left: 700,
          top: 10,
          width: 60,
          height: 20,
          ancestors: const ['AppBar'],
          isInteractive: false,
          isEnabled: true,
        ),
        Glyph(
          label: 'Sign Out',
          widgetType: 'IconButton',
          left: 700,
          top: 5,
          width: 40,
          height: 40,
          ancestors: const ['AppBar'],
          isInteractive: true,
          isEnabled: true,
        ),
      ]);
      final result = target.fuzzyResolve(tableau);
      expect(result, isNotNull);
      expect(result!.widgetType, 'IconButton');
      expect(result.isInteractive, isTrue);
    });

    test('resolve with single candidate does not sort', () {
      const target = StratagemTarget(label: 'Submit');
      final tableau = makeTableau([
        Glyph(
          label: 'Submit',
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
      ]);
      final result = target.resolve(tableau);
      expect(result, isNotNull);
      expect(result!.widgetType, 'Text');
    });

    test('all candidates interactive preserves original order', () {
      const target = StratagemTarget(label: 'OK');
      final tableau = makeTableau([
        Glyph(
          label: 'OK',
          widgetType: 'ElevatedButton',
          left: 0,
          top: 0,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: true,
          isEnabled: true,
        ),
        Glyph(
          label: 'OK',
          widgetType: 'TextButton',
          left: 0,
          top: 60,
          width: 100,
          height: 50,
          ancestors: const [],
          isInteractive: true,
          isEnabled: true,
        ),
      ]);
      final result = target.resolve(tableau);
      expect(result, isNotNull);
      expect(result!.widgetType, 'ElevatedButton');
    });

    test('index overrides interactive ranking', () {
      // Even with interactive-preference, explicit index=1 picks second
      const target = StratagemTarget(label: 'Hero', index: 1);
      final tableau = makeTableau([
        Glyph(
          label: 'Hero',
          widgetType: 'Text',
          left: 100,
          top: 500,
          width: 60,
          height: 20,
          ancestors: const [],
          isInteractive: false,
          isEnabled: true,
        ),
        Glyph(
          label: 'Hero',
          widgetType: 'GestureDetector',
          left: 100,
          top: 490,
          width: 80,
          height: 40,
          ancestors: const [],
          isInteractive: true,
          isEnabled: true,
        ),
      ]);
      // After sorting: [GestureDetector(ia), Text(non-ia)]
      // Index 1 → Text (non-interactive)
      final result = target.resolve(tableau);
      expect(result, isNotNull);
      expect(result!.widgetType, 'Text');
      expect(result.isInteractive, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // StratagemExpectations — toString edge cases
  // -------------------------------------------------------------------------
  group('StratagemExpectations — toString', () {
    test('all fields null returns minimal string', () {
      const e = StratagemExpectations();
      final s = e.toString();
      expect(s, contains('Expectations'));
    });

    test('with route shows route in toString', () {
      const e = StratagemExpectations(route: '/home');
      final s = e.toString();
      expect(s, contains('/home'));
    });
  });

  // -------------------------------------------------------------------------
  // StratagemElementState — toString edge cases
  // -------------------------------------------------------------------------
  group('StratagemElementState — toString', () {
    test('with value shows value in output', () {
      const state = StratagemElementState(label: 'Slider', value: '50');
      final s = state.toString();
      expect(s, contains('Slider'));
      expect(s, contains('50'));
    });

    test('with type shows type in output', () {
      const state = StratagemElementState(label: 'OK', type: 'Button');
      final s = state.toString();
      expect(s, contains('OK'));
      expect(s, contains('Button'));
    });
  });
}
