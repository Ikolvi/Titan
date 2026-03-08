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
  // Signet — Screen Fingerprint
  // -------------------------------------------------------------------------

  group('Signet', () {
    group('fromTableau', () {
      test('creates from empty Tableau', () {
        final tableau = createTableau(route: '/home', glyphs: []);
        final signet = Signet.fromTableau(tableau);

        expect(signet.routePattern, '/home');
        expect(signet.interactiveDescriptors, isEmpty);
        expect(signet.hash, isNotEmpty);
        expect(signet.identity, isNotEmpty);
      });

      test('extracts interactive element descriptors', () {
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
              widgetType: 'ElevatedButton',
              label: 'Login',
              interactionType: 'tap',
              semanticRole: 'button',
            ),
            // Non-interactive element should be excluded
            createGlyph(
              widgetType: 'Text',
              label: 'Welcome',
              isInteractive: false,
              interactionType: null,
              semanticRole: null,
            ),
          ],
        );

        final signet = Signet.fromTableau(tableau);
        expect(signet.interactiveDescriptors, hasLength(2));
        expect(
          signet.interactiveDescriptors,
          contains('ElevatedButton:button:tap'),
        );
        expect(
          signet.interactiveDescriptors,
          contains('TextField:textField:textInput'),
        );
      });

      test('descriptors are sorted for determinism', () {
        final glyphs = [
          createGlyph(
            widgetType: 'ZButton',
            semanticRole: 'button',
            interactionType: 'tap',
          ),
          createGlyph(
            widgetType: 'ATextField',
            semanticRole: 'textField',
            interactionType: 'textInput',
          ),
        ];
        final tableau = createTableau(glyphs: glyphs);
        final signet = Signet.fromTableau(tableau);

        // Sorted alphabetically
        expect(signet.interactiveDescriptors[0], startsWith('ATextField:'));
        expect(signet.interactiveDescriptors[1], startsWith('ZButton:'));
      });

      test('uses routePattern parameter when provided', () {
        final tableau = createTableau(route: '/quest/42');
        final signet = Signet.fromTableau(tableau, routePattern: '/quest/:id');
        expect(signet.routePattern, '/quest/:id');
      });

      test('falls back to tableau route', () {
        final tableau = createTableau(route: '/login');
        final signet = Signet.fromTableau(tableau);
        expect(signet.routePattern, '/login');
      });

      test('defaults to "/" when route is null', () {
        final tableau = createTableau(route: null);
        final signet = Signet.fromTableau(tableau);
        expect(signet.routePattern, '/');
      });
    });

    group('identity', () {
      test('generates "home" for root route', () {
        final tableau = createTableau(route: '/', glyphs: []);
        final signet = Signet.fromTableau(tableau);
        expect(signet.identity, 'home');
      });

      test('generates form suffix for login screen', () {
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
              widgetType: 'ElevatedButton',
              label: 'Login',
              interactionType: 'tap',
              semanticRole: 'button',
            ),
          ],
        );
        final signet = Signet.fromTableau(tableau);
        expect(signet.identity, 'login_form');
      });

      test('generates list suffix for ListView screen', () {
        final tableau = createTableau(
          route: '/quests',
          glyphs: [
            createGlyph(
              widgetType: 'ListView',
              isInteractive: false,
              interactionType: null,
              semanticRole: null,
            ),
          ],
        );
        final signet = Signet.fromTableau(tableau);
        expect(signet.identity, 'quests_list');
      });

      test('generates nav suffix for navigation screen', () {
        final tableau = createTableau(
          route: '/main',
          glyphs: [
            createGlyph(
              widgetType: 'NavigationDestination',
              isInteractive: true,
              interactionType: 'tap',
              semanticRole: 'button',
            ),
          ],
        );
        final signet = Signet.fromTableau(tableau);
        expect(signet.identity, 'main_nav');
      });

      test('strips parameter segments from identity', () {
        final tableau = createTableau(route: '/quest/:id', glyphs: []);
        final signet = Signet.fromTableau(tableau);
        expect(signet.identity, contains('quest'));
        expect(signet.identity, isNot(contains(':id')));
      });
    });

    group('equality', () {
      test('same interactive structure produces same hash', () {
        final glyphs = [
          createGlyph(
            widgetType: 'ElevatedButton',
            label: 'Click',
            interactionType: 'tap',
            semanticRole: 'button',
          ),
        ];

        final t1 = createTableau(route: '/page', glyphs: glyphs);
        final t2 = createTableau(route: '/page', glyphs: glyphs);

        final s1 = Signet.fromTableau(t1);
        final s2 = Signet.fromTableau(t2);

        expect(s1, equals(s2));
        expect(s1.hash, s2.hash);
      });

      test('different content, same structure → same hash', () {
        final glyphs = [
          createGlyph(
            widgetType: 'ElevatedButton',
            interactionType: 'tap',
            semanticRole: 'button',
          ),
        ];

        // Same route and interactive structure, different label (non-interactive text)
        final t1 = createTableau(
          route: '/profile',
          glyphs: [
            ...glyphs,
            createGlyph(
              widgetType: 'Text',
              label: 'John',
              isInteractive: false,
              interactionType: null,
              semanticRole: null,
            ),
          ],
        );
        final t2 = createTableau(
          route: '/profile',
          glyphs: [
            ...glyphs,
            createGlyph(
              widgetType: 'Text',
              label: 'Jane',
              isInteractive: false,
              interactionType: null,
              semanticRole: null,
            ),
          ],
        );

        final s1 = Signet.fromTableau(t1);
        final s2 = Signet.fromTableau(t2);

        expect(s1.hash, s2.hash);
      });

      test('different interactive structure → different hash', () {
        final t1 = createTableau(
          route: '/page',
          glyphs: [
            createGlyph(
              widgetType: 'ElevatedButton',
              interactionType: 'tap',
              semanticRole: 'button',
            ),
          ],
        );
        final t2 = createTableau(
          route: '/page',
          glyphs: [
            createGlyph(
              widgetType: 'TextField',
              interactionType: 'textInput',
              semanticRole: 'textField',
            ),
          ],
        );

        final s1 = Signet.fromTableau(t1);
        final s2 = Signet.fromTableau(t2);

        expect(s1.hash, isNot(equals(s2.hash)));
      });

      test('different routes → different hash', () {
        final glyphs = [
          createGlyph(
            widgetType: 'ElevatedButton',
            interactionType: 'tap',
            semanticRole: 'button',
          ),
        ];

        final s1 = Signet.fromTableau(
          createTableau(route: '/a', glyphs: glyphs),
        );
        final s2 = Signet.fromTableau(
          createTableau(route: '/b', glyphs: glyphs),
        );

        expect(s1.hash, isNot(equals(s2.hash)));
      });
    });

    group('serialization', () {
      test('round-trips through JSON', () {
        final signet = Signet(
          routePattern: '/login',
          interactiveDescriptors: [
            'ElevatedButton:button:tap',
            'TextField:textField:textInput',
          ],
          hash: 'abc12345',
          identity: 'login_form',
        );

        final json = signet.toJson();
        final restored = Signet.fromJson(json);

        expect(restored.routePattern, signet.routePattern);
        expect(restored.interactiveDescriptors, signet.interactiveDescriptors);
        expect(restored.hash, signet.hash);
        expect(restored.identity, signet.identity);
      });

      test('JSON contains expected keys', () {
        final signet = Signet(
          routePattern: '/home',
          interactiveDescriptors: [],
          hash: '00000000',
          identity: 'home',
        );

        final json = signet.toJson();
        expect(json, containsPair('routePattern', '/home'));
        expect(json, containsPair('hash', '00000000'));
        expect(json, containsPair('identity', 'home'));
        expect(json, contains('interactiveDescriptors'));
      });
    });

    test('toString includes key info', () {
      final signet = Signet(
        routePattern: '/login',
        interactiveDescriptors: ['ElevatedButton:button:tap'],
        hash: 'abc',
        identity: 'login_form',
      );
      final str = signet.toString();
      expect(str, contains('login_form'));
      expect(str, contains('/login'));
      expect(str, contains('1 interactive'));
    });
  });
}
