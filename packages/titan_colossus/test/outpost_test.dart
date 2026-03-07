import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Glyph createGlyph({
    String widgetType = 'ElevatedButton',
    String? label = 'Submit',
    double left = 10.0,
    double top = 20.0,
    double width = 100.0,
    double height = 48.0,
    bool isInteractive = true,
    String? interactionType = 'tap',
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
  }) {
    return Tableau(
      index: index,
      timestamp: timestamp,
      route: route,
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      glyphs: glyphs ?? [],
    );
  }

  // -------------------------------------------------------------------------
  // OutpostElement
  // -------------------------------------------------------------------------

  group('OutpostElement', () {
    group('fromGlyph', () {
      test('creates from interactive Glyph', () {
        final glyph = createGlyph(
          widgetType: 'ElevatedButton',
          label: 'Login',
          interactionType: 'tap',
          semanticRole: 'button',
          key: 'login_btn',
        );

        final elem = OutpostElement.fromGlyph(glyph);
        expect(elem.widgetType, 'ElevatedButton');
        expect(elem.label, 'Login');
        expect(elem.interactionType, 'tap');
        expect(elem.semanticRole, 'button');
        expect(elem.key, 'login_btn');
        expect(elem.isInteractive, true);
        expect(elem.isEnabled, true);
        expect(elem.frequency, 1);
      });

      test('captures currentValue as lastKnownValue', () {
        final glyph = createGlyph(
          widgetType: 'Checkbox',
          interactionType: 'toggle',
          currentValue: 'true',
        );

        final elem = OutpostElement.fromGlyph(glyph);
        expect(elem.lastKnownValue, 'true');
      });

      test('captures disabled state', () {
        final glyph = createGlyph(isEnabled: false);
        final elem = OutpostElement.fromGlyph(glyph);
        expect(elem.isEnabled, false);
      });
    });

    group('matches', () {
      test('matches by key when both have keys', () {
        final a = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'A',
          key: 'btn',
        );
        final b = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'B',
          key: 'btn',
        );
        expect(a.matches(b), true);
      });

      test('does not match different keys', () {
        final a = OutpostElement(
          widgetType: 'ElevatedButton',
          key: 'btn1',
        );
        final b = OutpostElement(
          widgetType: 'ElevatedButton',
          key: 'btn2',
        );
        expect(a.matches(b), false);
      });

      test('matches by widgetType + label when no keys', () {
        final a = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'Login',
        );
        final b = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'Login',
        );
        expect(a.matches(b), true);
      });

      test('no match when type differs', () {
        final a = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'Login',
        );
        final b = OutpostElement(
          widgetType: 'TextButton',
          label: 'Login',
        );
        expect(a.matches(b), false);
      });

      test('no match when label differs', () {
        final a = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'Login',
        );
        final b = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'Register',
        );
        expect(a.matches(b), false);
      });
    });

    group('toShortString', () {
      test('includes label when present', () {
        final elem = OutpostElement(
          widgetType: 'ElevatedButton',
          label: 'Login',
        );
        expect(elem.toShortString(), 'ElevatedButton "Login"');
      });

      test('shows just widget type without label', () {
        final elem = OutpostElement(widgetType: 'IconButton');
        expect(elem.toShortString(), 'IconButton');
      });
    });

    group('serialization', () {
      test('round-trips through JSON', () {
        final elem = OutpostElement(
          widgetType: 'TextField',
          label: 'Email',
          interactionType: 'textInput',
          semanticRole: 'textField',
          key: 'email_field',
          isInteractive: true,
          isEnabled: true,
          lastKnownValue: 'test@example.com',
          frequency: 3,
        );

        final json = elem.toJson();
        final restored = OutpostElement.fromJson(json);

        expect(restored.widgetType, elem.widgetType);
        expect(restored.label, elem.label);
        expect(restored.interactionType, elem.interactionType);
        expect(restored.semanticRole, elem.semanticRole);
        expect(restored.key, elem.key);
        expect(restored.isInteractive, elem.isInteractive);
        expect(restored.isEnabled, elem.isEnabled);
        expect(restored.lastKnownValue, elem.lastKnownValue);
        expect(restored.frequency, elem.frequency);
      });

      test('omits null optional fields', () {
        final elem = OutpostElement(widgetType: 'Text');
        final json = elem.toJson();

        expect(json.containsKey('label'), false);
        expect(json.containsKey('interactionType'), false);
        expect(json.containsKey('key'), false);
        expect(json.containsKey('lastKnownValue'), false);
      });
    });

    test('toString includes key info', () {
      final elem = OutpostElement(
        widgetType: 'ElevatedButton',
        label: 'Login',
        isInteractive: true,
        interactionType: 'tap',
      );
      final str = elem.toString();
      expect(str, contains('ElevatedButton'));
      expect(str, contains('Login'));
      expect(str, contains('tap'));
    });
  });

  // -------------------------------------------------------------------------
  // Outpost — A Discovered Screen
  // -------------------------------------------------------------------------

  group('Outpost', () {
    group('fromTableau', () {
      test('creates from login Tableau', () {
        final tableau = createTableau(
          route: '/login',
          glyphs: [
            createGlyph(
              widgetType: 'TextField',
              label: 'Email',
              interactionType: 'textInput',
              semanticRole: 'textField',
            ),
            createGlyph(
              widgetType: 'TextField',
              label: 'Password',
              interactionType: 'textInput',
              semanticRole: 'textField',
            ),
            createGlyph(
              widgetType: 'ElevatedButton',
              label: 'Login',
              interactionType: 'tap',
              semanticRole: 'button',
            ),
            createGlyph(
              widgetType: 'Text',
              label: 'Welcome',
              isInteractive: false,
              interactionType: null,
              semanticRole: null,
            ),
          ],
        );

        final outpost = Outpost.fromTableau(tableau);

        expect(outpost.routePattern, '/login');
        expect(outpost.interactiveElements, hasLength(3));
        expect(outpost.displayElements, hasLength(1));
        expect(outpost.observationCount, 1);
        expect(outpost.requiresAuth, false);
        expect(outpost.signet, isNotNull);
        expect(outpost.screenWidth, 375.0);
        expect(outpost.screenHeight, 812.0);
      });

      test('uses routePattern parameter when provided', () {
        final tableau = createTableau(route: '/quest/42');
        final outpost = Outpost.fromTableau(
          tableau,
          routePattern: '/quest/:id',
        );
        expect(outpost.routePattern, '/quest/:id');
      });

      test('auto-tags auth routes', () {
        final tableau = createTableau(route: '/login', glyphs: [
          createGlyph(
            widgetType: 'TextField',
            interactionType: 'textInput',
            semanticRole: 'textField',
          ),
          createGlyph(
            widgetType: 'ElevatedButton',
            label: 'Login',
            interactionType: 'tap',
          ),
        ]);
        final outpost = Outpost.fromTableau(tableau);
        expect(outpost.tags, contains('auth'));
        expect(outpost.tags, contains('form'));
      });

      test('auto-tags list screens', () {
        final tableau = createTableau(route: '/quests', glyphs: [
          createGlyph(
            widgetType: 'ListView',
            isInteractive: false,
            interactionType: null,
            semanticRole: null,
          ),
          createGlyph(
            widgetType: 'ListTile',
            label: 'Quest 1',
            isInteractive: true,
            interactionType: 'tap',
          ),
        ]);
        final outpost = Outpost.fromTableau(tableau);
        expect(outpost.tags, contains('list'));
      });

      test('auto-tags navigation screens', () {
        final tableau = createTableau(route: '/main', glyphs: [
          createGlyph(
            widgetType: 'BottomNavigationBar',
            isInteractive: true,
            interactionType: 'tap',
          ),
        ]);
        final outpost = Outpost.fromTableau(tableau);
        expect(outpost.tags, contains('navigation'));
      });

      test('generates display name from route', () {
        final tableau = createTableau(route: '/quest-detail', glyphs: []);
        final outpost = Outpost.fromTableau(tableau);
        expect(outpost.displayName, isNotEmpty);
      });

      test('generates Home for root route', () {
        final tableau = createTableau(route: '/', glyphs: []);
        final outpost = Outpost.fromTableau(tableau);
        expect(outpost.displayName, 'Home');
      });
    });

    group('mergeObservation', () {
      test('increments observation count', () {
        final tableau = createTableau(route: '/home', glyphs: [
          createGlyph(label: 'OK'),
        ]);
        final outpost = Outpost.fromTableau(tableau);
        expect(outpost.observationCount, 1);

        outpost.mergeObservation(tableau);
        expect(outpost.observationCount, 2);

        outpost.mergeObservation(tableau);
        expect(outpost.observationCount, 3);
      });

      test('merges new interactive elements', () {
        final t1 = createTableau(route: '/page', glyphs: [
          createGlyph(label: 'Button A', key: 'a'),
        ]);
        final outpost = Outpost.fromTableau(t1);
        expect(outpost.interactiveElements, hasLength(1));

        final t2 = createTableau(route: '/page', glyphs: [
          createGlyph(label: 'Button A', key: 'a'),
          createGlyph(label: 'Button B', key: 'b'),
        ]);
        outpost.mergeObservation(t2);
        expect(outpost.interactiveElements, hasLength(2));
      });

      test('increments frequency of existing elements', () {
        final t1 = createTableau(route: '/page', glyphs: [
          createGlyph(label: 'OK', key: 'ok_btn'),
        ]);
        final outpost = Outpost.fromTableau(t1);
        expect(outpost.interactiveElements.first.frequency, 1);

        outpost.mergeObservation(t1);
        expect(outpost.interactiveElements.first.frequency, 2);
      });

      test('updates screen dimensions', () {
        final t1 = createTableau(
          route: '/page',
          screenWidth: 375,
          screenHeight: 812,
        );
        final outpost = Outpost.fromTableau(t1);

        final t2 = createTableau(
          route: '/page',
          screenWidth: 414,
          screenHeight: 896,
        );
        outpost.mergeObservation(t2);

        expect(outpost.screenWidth, 414);
        expect(outpost.screenHeight, 896);
      });

      test('updates lastKnownValue', () {
        final t1 = createTableau(route: '/page', glyphs: [
          createGlyph(
            widgetType: 'TextField',
            label: 'Name',
            key: 'name_field',
            interactionType: 'textInput',
            currentValue: 'Alice',
          ),
        ]);
        final outpost = Outpost.fromTableau(t1);
        expect(
          outpost.interactiveElements.first.lastKnownValue,
          'Alice',
        );

        final t2 = createTableau(route: '/page', glyphs: [
          createGlyph(
            widgetType: 'TextField',
            label: 'Name',
            key: 'name_field',
            interactionType: 'textInput',
            currentValue: 'Bob',
          ),
        ]);
        outpost.mergeObservation(t2);
        expect(outpost.interactiveElements.first.lastKnownValue, 'Bob');
      });
    });

    group('toAiSummary', () {
      test('includes screen name and route', () {
        final outpost = Outpost.fromTableau(
          createTableau(route: '/login', glyphs: []),
        );
        final summary = outpost.toAiSummary();
        expect(summary, contains('SCREEN:'));
        expect(summary, contains('/login'));
      });

      test('includes auth status', () {
        final outpost = Outpost.fromTableau(
          createTableau(route: '/dashboard', glyphs: []),
        );
        outpost.requiresAuth = true;
        final summary = outpost.toAiSummary();
        expect(summary, contains('required'));
      });

      test('includes interactive elements', () {
        final outpost = Outpost.fromTableau(
          createTableau(route: '/page', glyphs: [
            createGlyph(label: 'Login', widgetType: 'ElevatedButton'),
          ]),
        );
        final summary = outpost.toAiSummary();
        expect(summary, contains('INTERACTIVE:'));
        expect(summary, contains('ElevatedButton'));
        expect(summary, contains('Login'));
      });

      test('includes exits', () {
        final outpost = Outpost.fromTableau(
          createTableau(route: '/login', glyphs: []),
        );
        outpost.exits.add(March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.formSubmit,
          triggerElementLabel: 'Login',
        ));
        final summary = outpost.toAiSummary();
        expect(summary, contains('EXITS:'));
        expect(summary, contains('/home'));
      });

      test('includes entrances', () {
        final outpost = Outpost.fromTableau(
          createTableau(route: '/login', glyphs: []),
        );
        outpost.entrances.add(March(
          fromRoute: '/dashboard',
          toRoute: '/login',
          trigger: MarchTrigger.redirect,
        ));
        final summary = outpost.toAiSummary();
        expect(summary, contains('ENTRANCES:'));
        expect(summary, contains('/dashboard'));
      });

      test('includes tags', () {
        final outpost = Outpost.fromTableau(
          createTableau(route: '/login', glyphs: [
            createGlyph(
              widgetType: 'TextField',
              interactionType: 'textInput',
              semanticRole: 'textField',
            ),
            createGlyph(
              widgetType: 'ElevatedButton',
              label: 'Login',
              interactionType: 'tap',
            ),
          ]),
        );
        final summary = outpost.toAiSummary();
        expect(summary, contains('TAGS:'));
        expect(summary, contains('auth'));
      });
    });

    group('serialization', () {
      test('round-trips through JSON', () {
        final outpost = Outpost.fromTableau(
          createTableau(route: '/login', glyphs: [
            createGlyph(label: 'Login', key: 'login_btn'),
            createGlyph(
              widgetType: 'Text',
              label: 'Welcome',
              isInteractive: false,
              interactionType: null,
              semanticRole: null,
            ),
          ]),
        );
        outpost.requiresAuth = true;
        outpost.exits.add(March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.formSubmit,
        ));

        final json = outpost.toJson();
        final restored = Outpost.fromJson(json);

        expect(restored.routePattern, outpost.routePattern);
        expect(restored.displayName, outpost.displayName);
        expect(restored.requiresAuth, true);
        expect(restored.observationCount, outpost.observationCount);
        expect(
          restored.interactiveElements.length,
          outpost.interactiveElements.length,
        );
        expect(
          restored.displayElements.length,
          outpost.displayElements.length,
        );
        expect(restored.exits.length, 1);
        expect(restored.signet.hash, outpost.signet.hash);
      });

      test('handles empty collections in JSON', () {
        final json = {
          'signet': {
            'routePattern': '/test',
            'interactiveDescriptors': <String>[],
            'hash': 'abc',
            'identity': 'test',
          },
          'routePattern': '/test',
          'displayName': 'Test',
        };

        final outpost = Outpost.fromJson(json);
        expect(outpost.interactiveElements, isEmpty);
        expect(outpost.displayElements, isEmpty);
        expect(outpost.exits, isEmpty);
        expect(outpost.entrances, isEmpty);
      });
    });

    test('toString includes key info', () {
      final outpost = Outpost.fromTableau(
        createTableau(route: '/login', glyphs: [
          createGlyph(label: 'Login'),
        ]),
      );
      final str = outpost.toString();
      expect(str, contains('/login'));
      expect(str, contains('1 interactive'));
    });
  });
}
