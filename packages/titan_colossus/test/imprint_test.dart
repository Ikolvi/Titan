import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Imprint — recorded event data
  // ---------------------------------------------------------

  group('Imprint', () {
    test('creates with required fields', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0,
        positionY: 200.0,
        timestamp: const Duration(milliseconds: 500),
      );

      expect(imprint.type, ImprintType.pointerDown);
      expect(imprint.positionX, 100.0);
      expect(imprint.positionY, 200.0);
      expect(imprint.timestamp, const Duration(milliseconds: 500));
      expect(imprint.pointer, 0);
      expect(imprint.deviceKind, 0);
      expect(imprint.buttons, 0);
      expect(imprint.deltaX, 0);
      expect(imprint.deltaY, 0);
      expect(imprint.scrollDeltaX, 0);
      expect(imprint.scrollDeltaY, 0);
      expect(imprint.pressure, 1.0);
    });

    test('creates with all fields', () {
      final imprint = Imprint(
        type: ImprintType.pointerMove,
        positionX: 150.0,
        positionY: 250.0,
        timestamp: const Duration(milliseconds: 1000),
        pointer: 2,
        deviceKind: 1,
        buttons: 1,
        deltaX: 5.0,
        deltaY: -3.0,
        scrollDeltaX: 0,
        scrollDeltaY: 10.0,
        pressure: 0.8,
      );

      expect(imprint.pointer, 2);
      expect(imprint.deviceKind, 1);
      expect(imprint.buttons, 1);
      expect(imprint.deltaX, 5.0);
      expect(imprint.deltaY, -3.0);
      expect(imprint.scrollDeltaY, 10.0);
      expect(imprint.pressure, 0.8);
    });

    test('toMap includes required fields', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0,
        positionY: 200.0,
        timestamp: const Duration(microseconds: 500000),
      );
      final map = imprint.toMap();

      expect(map['type'], 'pointerDown');
      expect(map['x'], 100.0);
      expect(map['y'], 200.0);
      expect(map['ts'], 500000);
      expect(map['pointer'], 0);
      expect(map['deviceKind'], 0);
      expect(map['buttons'], 0);
    });

    test('toMap omits zero deltas and default pressure', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0,
        positionY: 200.0,
        timestamp: const Duration(milliseconds: 500),
      );
      final map = imprint.toMap();

      expect(map.containsKey('dx'), false);
      expect(map.containsKey('dy'), false);
      expect(map.containsKey('sdx'), false);
      expect(map.containsKey('sdy'), false);
      expect(map.containsKey('pressure'), false);
    });

    test('toMap includes non-zero deltas and custom pressure', () {
      final imprint = Imprint(
        type: ImprintType.pointerMove,
        positionX: 100.0,
        positionY: 200.0,
        timestamp: const Duration(milliseconds: 500),
        deltaX: 3.0,
        deltaY: -2.0,
        scrollDeltaX: 1.0,
        scrollDeltaY: 5.0,
        pressure: 0.6,
      );
      final map = imprint.toMap();

      expect(map['dx'], 3.0);
      expect(map['dy'], -2.0);
      expect(map['sdx'], 1.0);
      expect(map['sdy'], 5.0);
      expect(map['pressure'], 0.6);
    });

    test('fromMap round-trips correctly', () {
      final original = Imprint(
        type: ImprintType.pointerScroll,
        positionX: 42.5,
        positionY: 99.3,
        timestamp: const Duration(microseconds: 123456),
        pointer: 3,
        deviceKind: 1,
        buttons: 2,
        deltaX: 1.5,
        deltaY: -2.5,
        scrollDeltaX: 0,
        scrollDeltaY: 120.0,
        pressure: 0.9,
      );

      final map = original.toMap();
      final restored = Imprint.fromMap(map);

      expect(restored.type, original.type);
      expect(restored.positionX, original.positionX);
      expect(restored.positionY, original.positionY);
      expect(restored.timestamp, original.timestamp);
      expect(restored.pointer, original.pointer);
      expect(restored.deviceKind, original.deviceKind);
      expect(restored.buttons, original.buttons);
      expect(restored.deltaX, original.deltaX);
      expect(restored.deltaY, original.deltaY);
      expect(restored.scrollDeltaY, original.scrollDeltaY);
      expect(restored.pressure, original.pressure);
    });

    test('fromMap handles missing optional fields gracefully', () {
      final map = {'type': 'pointerUp', 'x': 50.0, 'y': 75.0, 'ts': 1000};
      final imprint = Imprint.fromMap(map);

      expect(imprint.type, ImprintType.pointerUp);
      expect(imprint.positionX, 50.0);
      expect(imprint.positionY, 75.0);
      expect(imprint.pointer, 0);
      expect(imprint.deltaX, 0);
      expect(imprint.pressure, 1.0);
    });

    test('toString includes type, position, and timestamp', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 100.0,
        positionY: 200.0,
        timestamp: const Duration(milliseconds: 1234),
      );

      expect(imprint.toString(), contains('pointerDown'));
      expect(imprint.toString(), contains('100.0'));
      expect(imprint.toString(), contains('200.0'));
      expect(imprint.toString(), contains('1234ms'));
    });
  });

  // ---------------------------------------------------------
  // ImprintType — event type enum
  // ---------------------------------------------------------

  group('ImprintType', () {
    test('has all expected values', () {
      expect(ImprintType.values.length, 17);
      expect(ImprintType.values, contains(ImprintType.pointerDown));
      expect(ImprintType.values, contains(ImprintType.pointerMove));
      expect(ImprintType.values, contains(ImprintType.pointerUp));
      expect(ImprintType.values, contains(ImprintType.pointerCancel));
      expect(ImprintType.values, contains(ImprintType.pointerHover));
      expect(ImprintType.values, contains(ImprintType.pointerScroll));
      expect(ImprintType.values, contains(ImprintType.pointerPanZoomStart));
      expect(ImprintType.values, contains(ImprintType.pointerPanZoomUpdate));
      expect(ImprintType.values, contains(ImprintType.pointerPanZoomEnd));
      expect(ImprintType.values, contains(ImprintType.keyDown));
      expect(ImprintType.values, contains(ImprintType.keyUp));
      expect(ImprintType.values, contains(ImprintType.keyRepeat));
      expect(ImprintType.values, contains(ImprintType.textInput));
      expect(ImprintType.values, contains(ImprintType.textAction));
    });

    test('can be looked up by name', () {
      expect(ImprintType.values.byName('pointerDown'), ImprintType.pointerDown);
      expect(
        ImprintType.values.byName('pointerScroll'),
        ImprintType.pointerScroll,
      );
      expect(ImprintType.values.byName('keyDown'), ImprintType.keyDown);
      expect(ImprintType.values.byName('textInput'), ImprintType.textInput);
    });
  });

  // ---------------------------------------------------------
  // Key and text event fields
  // ---------------------------------------------------------

  group('Imprint key event fields', () {
    test('toMap includes key event fields when set', () {
      final imprint = Imprint(
        type: ImprintType.keyDown,
        positionX: 0,
        positionY: 0,
        timestamp: const Duration(milliseconds: 100),
        keyId: 0x00000061, // 'a'
        physicalKey: 0x00070004,
        character: 'a',
      );
      final map = imprint.toMap();

      expect(map['type'], 'keyDown');
      expect(map['keyId'], 0x00000061);
      expect(map['physicalKey'], 0x00070004);
      expect(map['char'], 'a');
    });

    test('toMap omits null key fields', () {
      final imprint = Imprint(
        type: ImprintType.pointerDown,
        positionX: 50,
        positionY: 75,
        timestamp: const Duration(milliseconds: 200),
      );
      final map = imprint.toMap();

      expect(map.containsKey('keyId'), false);
      expect(map.containsKey('physicalKey'), false);
      expect(map.containsKey('char'), false);
    });

    test('fromMap restores key event fields', () {
      final original = Imprint(
        type: ImprintType.keyUp,
        positionX: 0,
        positionY: 0,
        timestamp: const Duration(milliseconds: 300),
        keyId: 0x00000062,
        physicalKey: 0x00070005,
        character: 'b',
      );
      final restored = Imprint.fromMap(original.toMap());

      expect(restored.type, ImprintType.keyUp);
      expect(restored.keyId, 0x00000062);
      expect(restored.physicalKey, 0x00070005);
      expect(restored.character, 'b');
    });

    test('keyRepeat type round-trips', () {
      final imprint = Imprint(
        type: ImprintType.keyRepeat,
        positionX: 0,
        positionY: 0,
        timestamp: const Duration(milliseconds: 400),
        keyId: 0x00000063,
      );
      final restored = Imprint.fromMap(imprint.toMap());

      expect(restored.type, ImprintType.keyRepeat);
      expect(restored.keyId, 0x00000063);
    });
  });

  group('Imprint text input fields', () {
    test('toMap includes text fields when set', () {
      final imprint = Imprint(
        type: ImprintType.textInput,
        positionX: 0,
        positionY: 0,
        timestamp: const Duration(milliseconds: 500),
        text: 'hello world',
        selectionBase: 5,
        selectionExtent: 11,
        composingBase: -1,
        composingExtent: -1,
        fieldId: 'email',
      );
      final map = imprint.toMap();

      expect(map['type'], 'textInput');
      expect(map['text'], 'hello world');
      expect(map['selBase'], 5);
      expect(map['selExtent'], 11);
      expect(map['compBase'], -1);
      expect(map['compExtent'], -1);
      expect(map['fieldId'], 'email');
    });

    test('toMap omits null text fields', () {
      final imprint = Imprint(
        type: ImprintType.pointerMove,
        positionX: 100,
        positionY: 200,
        timestamp: const Duration(milliseconds: 600),
      );
      final map = imprint.toMap();

      expect(map.containsKey('text'), false);
      expect(map.containsKey('selBase'), false);
      expect(map.containsKey('selExtent'), false);
      expect(map.containsKey('fieldId'), false);
    });

    test('fromMap restores text input fields', () {
      final original = Imprint(
        type: ImprintType.textInput,
        positionX: 0,
        positionY: 0,
        timestamp: const Duration(milliseconds: 700),
        text: 'test input',
        selectionBase: 0,
        selectionExtent: 10,
        fieldId: 'password',
      );
      final restored = Imprint.fromMap(original.toMap());

      expect(restored.text, 'test input');
      expect(restored.selectionBase, 0);
      expect(restored.selectionExtent, 10);
      expect(restored.fieldId, 'password');
    });

    test('textAction type round-trips with action index', () {
      final imprint = Imprint(
        type: ImprintType.textAction,
        positionX: 0,
        positionY: 0,
        timestamp: const Duration(milliseconds: 800),
        textInputAction: 6, // TextInputAction.done.index
        fieldId: 'submit',
      );
      final restored = Imprint.fromMap(imprint.toMap());

      expect(restored.type, ImprintType.textAction);
      expect(restored.textInputAction, 6);
      expect(restored.fieldId, 'submit');
    });
  });

  // ---------------------------------------------------------
  // ShadeSession — recorded session
  // ---------------------------------------------------------

  group('ShadeSession', () {
    ShadeSession createSession({int eventCount = 3}) {
      return ShadeSession(
        id: 'test_session_1',
        name: 'test_session',
        recordedAt: DateTime(2025, 1, 15, 10, 30),
        duration: const Duration(seconds: 5),
        screenWidth: 375.0,
        screenHeight: 812.0,
        devicePixelRatio: 3.0,
        description: 'A test session',
        imprints: List.generate(
          eventCount,
          (i) => Imprint(
            type: ImprintType.pointerDown,
            positionX: i * 10.0,
            positionY: i * 20.0,
            timestamp: Duration(milliseconds: i * 100),
          ),
        ),
      );
    }

    test('creates with all fields', () {
      final session = createSession();

      expect(session.id, 'test_session_1');
      expect(session.name, 'test_session');
      expect(session.screenWidth, 375.0);
      expect(session.screenHeight, 812.0);
      expect(session.devicePixelRatio, 3.0);
      expect(session.description, 'A test session');
      expect(session.eventCount, 3);
    });

    test('eventCount returns imprints length', () {
      expect(createSession(eventCount: 0).eventCount, 0);
      expect(createSession(eventCount: 5).eventCount, 5);
      expect(createSession(eventCount: 100).eventCount, 100);
    });

    test('toMap includes all fields', () {
      final session = createSession();
      final map = session.toMap();

      expect(map['id'], 'test_session_1');
      expect(map['name'], 'test_session');
      expect(map['recordedAt'], '2025-01-15T10:30:00.000');
      expect(map['screenWidth'], 375.0);
      expect(map['screenHeight'], 812.0);
      expect(map['devicePixelRatio'], 3.0);
      expect(map['description'], 'A test session');
      expect(map['eventCount'], 3);
      expect(map['imprints'], isList);
      expect((map['imprints'] as List).length, 3);
    });

    test('toMap omits null description', () {
      final session = ShadeSession(
        id: 'no_desc',
        name: 'no_desc',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 1),
        screenWidth: 375.0,
        screenHeight: 812.0,
        devicePixelRatio: 2.0,
        imprints: [],
      );
      final map = session.toMap();

      expect(map.containsKey('description'), false);
      expect(map.containsKey('startRoute'), false);
    });

    test('toMap includes startRoute when set', () {
      final session = ShadeSession(
        id: 'route_test',
        name: 'route_test',
        recordedAt: DateTime(2025, 1, 1),
        duration: const Duration(seconds: 1),
        screenWidth: 375.0,
        screenHeight: 812.0,
        devicePixelRatio: 2.0,
        imprints: [],
        startRoute: '/home/settings',
      );
      final map = session.toMap();

      expect(map['startRoute'], '/home/settings');
    });

    test('fromMap restores startRoute', () {
      final map = {
        'id': 'route',
        'name': 'route',
        'recordedAt': '2025-01-15T10:00:00.000',
        'durationUs': 1000000,
        'screenWidth': 375.0,
        'screenHeight': 812.0,
        'devicePixelRatio': 2.0,
        'startRoute': '/login',
        'imprints': <Map<String, dynamic>>[],
      };
      final session = ShadeSession.fromMap(map);

      expect(session.startRoute, '/login');
    });

    test('startRoute round-trips through JSON', () {
      final original = ShadeSession(
        id: 'rt',
        name: 'rt',
        recordedAt: DateTime(2025, 6, 1),
        duration: const Duration(seconds: 2),
        screenWidth: 400,
        screenHeight: 800,
        devicePixelRatio: 2,
        imprints: [],
        startRoute: '/dashboard',
      );
      final restored = ShadeSession.fromJson(original.toJson());

      expect(restored.startRoute, '/dashboard');
    });

    test('toJson produces valid JSON', () {
      final session = createSession();
      final json = session.toJson();

      expect(() => jsonDecode(json), returnsNormally);
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['name'], 'test_session');
    });

    test('fromJson round-trips correctly', () {
      final original = createSession();
      final json = original.toJson();
      final restored = ShadeSession.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.screenWidth, original.screenWidth);
      expect(restored.screenHeight, original.screenHeight);
      expect(restored.devicePixelRatio, original.devicePixelRatio);
      expect(restored.description, original.description);
      expect(restored.eventCount, original.eventCount);
      expect(restored.imprints[0].positionX, original.imprints[0].positionX);
      expect(restored.imprints[1].type, original.imprints[1].type);
    });

    test('fromMap handles missing optional description', () {
      final map = {
        'id': 'test',
        'name': 'test',
        'recordedAt': '2025-01-15T10:00:00.000',
        'durationUs': 5000000,
        'screenWidth': 375.0,
        'screenHeight': 812.0,
        'devicePixelRatio': 2.0,
        'imprints': <Map<String, dynamic>>[],
      };
      final session = ShadeSession.fromMap(map);

      expect(session.description, isNull);
      expect(session.imprints, isEmpty);
    });

    test('toString includes name, event count, and duration', () {
      final session = createSession();
      final str = session.toString();

      expect(str, contains('test_session'));
      expect(str, contains('3 events'));
      expect(str, contains('5000ms'));
    });
  });
}
