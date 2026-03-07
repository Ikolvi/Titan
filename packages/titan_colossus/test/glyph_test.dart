import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Glyph — UI element descriptor
  // ---------------------------------------------------------

  group('Glyph', () {
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

    test('creates with required fields', () {
      final glyph = Glyph(
        widgetType: 'Text',
        left: 0,
        top: 0,
        width: 50,
        height: 20,
        depth: 3,
      );

      expect(glyph.widgetType, 'Text');
      expect(glyph.label, isNull);
      expect(glyph.left, 0);
      expect(glyph.top, 0);
      expect(glyph.width, 50);
      expect(glyph.height, 20);
      expect(glyph.isInteractive, false);
      expect(glyph.interactionType, isNull);
      expect(glyph.fieldId, isNull);
      expect(glyph.key, isNull);
      expect(glyph.semanticRole, isNull);
      expect(glyph.isEnabled, true);
      expect(glyph.currentValue, isNull);
      expect(glyph.ancestors, isEmpty);
      expect(glyph.depth, 3);
    });

    test('creates with all fields', () {
      final glyph = createGlyph(
        fieldId: 'email_field',
        key: 'email_key',
        currentValue: 'test@example.com',
      );

      expect(glyph.widgetType, 'ElevatedButton');
      expect(glyph.label, 'Submit');
      expect(glyph.left, 10.0);
      expect(glyph.top, 20.0);
      expect(glyph.width, 100.0);
      expect(glyph.height, 48.0);
      expect(glyph.isInteractive, true);
      expect(glyph.interactionType, 'tap');
      expect(glyph.fieldId, 'email_field');
      expect(glyph.key, 'email_key');
      expect(glyph.semanticRole, 'button');
      expect(glyph.isEnabled, true);
      expect(glyph.currentValue, 'test@example.com');
      expect(glyph.ancestors, ['Scaffold', 'Column']);
      expect(glyph.depth, 5);
    });

    // -------------------------------------------------------
    // Computed properties
    // -------------------------------------------------------

    group('computed properties', () {
      test('centerX returns horizontal center', () {
        final glyph = createGlyph(left: 10, width: 100);
        expect(glyph.centerX, 60.0);
      });

      test('centerY returns vertical center', () {
        final glyph = createGlyph(top: 20, height: 48);
        expect(glyph.centerY, 44.0);
      });

      test('containsPoint returns true for point inside bounds', () {
        final glyph = createGlyph(
          left: 10,
          top: 20,
          width: 100,
          height: 48,
        );
        expect(glyph.containsPoint(50, 40), true);
      });

      test('containsPoint returns true for point on edge', () {
        final glyph = createGlyph(
          left: 10,
          top: 20,
          width: 100,
          height: 48,
        );
        expect(glyph.containsPoint(10, 20), true);
        expect(glyph.containsPoint(110, 68), true);
      });

      test('containsPoint returns false for point outside bounds', () {
        final glyph = createGlyph(
          left: 10,
          top: 20,
          width: 100,
          height: 48,
        );
        expect(glyph.containsPoint(5, 40), false);
        expect(glyph.containsPoint(111, 40), false);
        expect(glyph.containsPoint(50, 19), false);
        expect(glyph.containsPoint(50, 69), false);
      });
    });

    // -------------------------------------------------------
    // Serialization
    // -------------------------------------------------------

    group('serialization', () {
      test('toMap includes all non-null fields', () {
        final glyph = createGlyph(
          fieldId: 'email',
          key: 'email_key',
          currentValue: 'a@b.com',
        );
        final map = glyph.toMap();

        expect(map['wt'], 'ElevatedButton');
        expect(map['l'], 'Submit');
        expect(map['x'], 10.0);
        expect(map['y'], 20.0);
        expect(map['w'], 100.0);
        expect(map['h'], 48.0);
        expect(map['ia'], true); // included because isInteractive=true
        expect(map['it'], 'tap');
        expect(map['fid'], 'email');
        expect(map['k'], 'email_key');
        expect(map['sr'], 'button');
        expect(map.containsKey('en'), false); // omitted because isEnabled=true (default)
        expect(map['cv'], 'a@b.com');
        expect(map['anc'], ['Scaffold', 'Column']);
        expect(map['d'], 5);
      });

      test('toMap omits null fields', () {
        final glyph = Glyph(
          widgetType: 'Text',
          left: 0,
          top: 0,
          width: 50,
          height: 20,
          depth: 2,
        );
        final map = glyph.toMap();

        expect(map.containsKey('l'), false);
        expect(map.containsKey('it'), false);
        expect(map.containsKey('fid'), false);
        expect(map.containsKey('k'), false);
        expect(map.containsKey('sr'), false);
        expect(map.containsKey('cv'), false);
        expect(map.containsKey('ia'), false); // omitted because isInteractive=false (default)
        expect(map.containsKey('en'), false); // omitted because isEnabled=true (default)
      });

      test('fromMap round-trips all fields', () {
        final original = createGlyph(
          fieldId: 'password',
          key: 'pw_key',
          currentValue: '••••',
        );
        final restored = Glyph.fromMap(original.toMap());

        expect(restored.widgetType, original.widgetType);
        expect(restored.label, original.label);
        expect(restored.left, original.left);
        expect(restored.top, original.top);
        expect(restored.width, original.width);
        expect(restored.height, original.height);
        expect(restored.isInteractive, original.isInteractive);
        expect(restored.interactionType, original.interactionType);
        expect(restored.fieldId, original.fieldId);
        expect(restored.key, original.key);
        expect(restored.semanticRole, original.semanticRole);
        expect(restored.isEnabled, original.isEnabled);
        expect(restored.currentValue, original.currentValue);
        expect(restored.ancestors, original.ancestors);
        expect(restored.depth, original.depth);
      });

      test('fromMap round-trips minimal Glyph', () {
        final original = Glyph(
          widgetType: 'Icon',
          left: 5,
          top: 10,
          width: 24,
          height: 24,
          depth: 7,
        );
        final restored = Glyph.fromMap(original.toMap());

        expect(restored.widgetType, 'Icon');
        expect(restored.label, isNull);
        expect(restored.isInteractive, false);
        expect(restored.depth, 7);
        expect(restored, original);
      });

      test('fromMap handles integer coordinates', () {
        final map = {
          'wt': 'Text',
          'x': 10,
          'y': 20,
          'w': 50,
          'h': 16,
          'd': 3,
        };
        final glyph = Glyph.fromMap(map);
        expect(glyph.left, 10.0);
        expect(glyph.top, 20.0);
        expect(glyph.width, 50.0);
        expect(glyph.height, 16.0);
      });
    });

    // -------------------------------------------------------
    // copyWith
    // -------------------------------------------------------

    group('copyWith', () {
      test('copies with changed fields', () {
        final original = createGlyph();
        final copy = original.copyWith(
          label: 'Cancel',
          isEnabled: false,
        );

        expect(copy.label, 'Cancel');
        expect(copy.isEnabled, false);
        // Unchanged fields
        expect(copy.widgetType, original.widgetType);
        expect(copy.left, original.left);
        expect(copy.top, original.top);
        expect(copy.isInteractive, original.isInteractive);
      });

      test('copyWith with no arguments returns identical copy', () {
        final original = createGlyph();
        final copy = original.copyWith();
        expect(copy, original);
      });
    });

    // -------------------------------------------------------
    // Equality
    // -------------------------------------------------------

    group('equality', () {
      test('equal Glyphs are equal', () {
        final a = createGlyph();
        final b = createGlyph();
        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('different label makes Glyphs unequal', () {
        final a = createGlyph(label: 'Submit');
        final b = createGlyph(label: 'Cancel');
        expect(a, isNot(b));
      });

      test('different position makes Glyphs unequal', () {
        final a = createGlyph(left: 10);
        final b = createGlyph(left: 20);
        expect(a, isNot(b));
      });

      test('different widgetType makes Glyphs unequal', () {
        final a = createGlyph(widgetType: 'ElevatedButton');
        final b = createGlyph(widgetType: 'TextButton');
        expect(a, isNot(b));
      });
    });

    // -------------------------------------------------------
    // toString
    // -------------------------------------------------------

    test('toString produces readable output', () {
      final glyph = createGlyph();
      final str = glyph.toString();
      expect(str, contains('Glyph'));
      expect(str, contains('ElevatedButton'));
      expect(str, contains('Submit'));
    });

    // -------------------------------------------------------
    // maxLabelLength
    // -------------------------------------------------------

    test('maxLabelLength constant is 100', () {
      expect(Glyph.maxLabelLength, 100);
    });
  });
}
