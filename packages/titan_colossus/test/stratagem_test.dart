import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/recording/glyph.dart';
import 'package:titan_colossus/src/recording/tableau.dart';
import 'package:titan_colossus/src/testing/stratagem.dart';

void main() {
  // -------------------------------------------------------------------------
  // Stratagem
  // -------------------------------------------------------------------------
  group('Stratagem', () {
    late Stratagem stratagem;

    setUp(() {
      stratagem = Stratagem(
        name: 'login_flow',
        description: 'Test login with valid credentials',
        tags: const ['auth', 'critical'],
        startRoute: '/login',
        testData: const {'email': 'test@example.com', 'password': 'Secret123!'},
        timeout: const Duration(seconds: 60),
        failurePolicy: StratagemFailurePolicy.continueAll,
        steps: [
          const StratagemStep(
            id: 1,
            action: StratagemAction.verify,
            description: 'Verify login page',
            expectations: StratagemExpectations(
              route: '/login',
              elementsPresent: [
                StratagemTarget(label: 'Email', type: 'TextField'),
                StratagemTarget(label: 'Login', type: 'ElevatedButton'),
              ],
            ),
          ),
          const StratagemStep(
            id: 2,
            action: StratagemAction.enterText,
            description: 'Enter email',
            target: StratagemTarget(label: 'Email', type: 'TextField'),
            value: r'${testData.email}',
            clearFirst: true,
          ),
          const StratagemStep(
            id: 3,
            action: StratagemAction.tap,
            description: 'Tap login',
            target: StratagemTarget(label: 'Login', type: 'ElevatedButton'),
            waitAfter: Duration(seconds: 3),
          ),
        ],
      );
    });

    test('constructs with required fields', () {
      final simple = const Stratagem(name: 'test', startRoute: '/', steps: []);
      expect(simple.name, 'test');
      expect(simple.startRoute, '/');
      expect(simple.steps, isEmpty);
      expect(simple.description, '');
      expect(simple.tags, isEmpty);
      expect(simple.testData, isNull);
      expect(simple.preconditions, isNull);
      expect(simple.timeout, const Duration(seconds: 30));
      expect(simple.failurePolicy, StratagemFailurePolicy.abortOnFirst);
    });

    test('toString includes name and step count', () {
      expect(stratagem.toString(), contains('login_flow'));
      expect(stratagem.toString(), contains('3 steps'));
    });

    group('interpolation', () {
      test('interpolates testData variables', () {
        expect(stratagem.interpolate(r'${testData.email}'), 'test@example.com');
        expect(stratagem.interpolate(r'${testData.password}'), 'Secret123!');
      });

      test('preserves string without variables', () {
        expect(stratagem.interpolate('hello'), 'hello');
      });

      test('preserves unknown variables', () {
        expect(
          stratagem.interpolate(r'${testData.unknown}'),
          r'${testData.unknown}',
        );
      });

      test('handles null testData', () {
        const noData = Stratagem(name: 'test', startRoute: '/', steps: []);
        expect(noData.interpolate(r'${testData.email}'), r'${testData.email}');
      });

      test('interpolates multiple variables in one string', () {
        expect(
          stratagem.interpolate(
            r'user: ${testData.email}, pass: ${testData.password}',
          ),
          'user: test@example.com, pass: Secret123!',
        );
      });
    });

    group('serialization', () {
      test('toJson and fromJson roundtrip', () {
        final json = stratagem.toJson();
        final restored = Stratagem.fromJson(json);

        expect(restored.name, stratagem.name);
        expect(restored.description, stratagem.description);
        expect(restored.tags, stratagem.tags);
        expect(restored.startRoute, stratagem.startRoute);
        expect(restored.testData, stratagem.testData);
        expect(restored.timeout, stratagem.timeout);
        expect(restored.failurePolicy, stratagem.failurePolicy);
        expect(restored.steps.length, stratagem.steps.length);
      });

      test('toJson includes schema', () {
        final json = stratagem.toJson();
        expect(json[r'$schema'], 'titan://stratagem/v1');
      });

      test('fromJson handles missing optional fields', () {
        final minJson = {
          'name': 'minimal',
          'startRoute': '/',
          'steps': <Map<String, dynamic>>[],
        };
        final restored = Stratagem.fromJson(minJson);
        expect(restored.name, 'minimal');
        expect(restored.description, '');
        expect(restored.tags, isEmpty);
        expect(restored.testData, isNull);
        expect(restored.timeout, const Duration(seconds: 30));
        expect(restored.failurePolicy, StratagemFailurePolicy.abortOnFirst);
      });

      test('failure policy serialization', () {
        for (final policy in StratagemFailurePolicy.values) {
          final s = Stratagem(
            name: 'test',
            startRoute: '/',
            steps: const [],
            failurePolicy: policy,
          );
          final json = s.toJson();
          final restored = Stratagem.fromJson(json);
          expect(restored.failurePolicy, policy);
        }
      });
    });

    group('template', () {
      test('templateDescription is non-empty', () {
        expect(Stratagem.templateDescription, isNotEmpty);
        expect(Stratagem.templateDescription, contains('action'));
        expect(Stratagem.templateDescription, contains('target'));
        expect(Stratagem.templateDescription, contains('tap'));
      });

      test('template schema has required fields', () {
        final t = Stratagem.template;
        expect(t, containsPair(r'$schema', 'titan://stratagem/v1'));
        expect(t, contains('name'));
        expect(t, contains('startRoute'));
        expect(t, contains('steps'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // StratagemStep
  // -------------------------------------------------------------------------
  group('StratagemStep', () {
    test('serialization roundtrip — simple step', () {
      const step = StratagemStep(
        id: 1,
        action: StratagemAction.tap,
        description: 'Tap login',
        target: StratagemTarget(label: 'Login', type: 'ElevatedButton'),
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);

      expect(restored.id, 1);
      expect(restored.action, StratagemAction.tap);
      expect(restored.description, 'Tap login');
      expect(restored.target?.label, 'Login');
      expect(restored.target?.type, 'ElevatedButton');
    });

    test('serialization roundtrip — text input step', () {
      const step = StratagemStep(
        id: 2,
        action: StratagemAction.enterText,
        description: 'Enter email',
        target: StratagemTarget(label: 'Email'),
        value: 'test@example.com',
        clearFirst: true,
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);

      expect(restored.value, 'test@example.com');
      expect(restored.clearFirst, true);
    });

    test('serialization roundtrip — scroll step', () {
      const step = StratagemStep(
        id: 3,
        action: StratagemAction.scroll,
        scrollDelta: Offset(0, -300),
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);

      expect(restored.scrollDelta, const Offset(0, -300));
    });

    test('serialization roundtrip — swipe step', () {
      const step = StratagemStep(
        id: 4,
        action: StratagemAction.swipe,
        target: StratagemTarget(label: 'Item'),
        swipeDirection: 'left',
        swipeDistance: 200,
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);

      expect(restored.swipeDirection, 'left');
      expect(restored.swipeDistance, 200);
    });

    test('serialization roundtrip — with expectations', () {
      const step = StratagemStep(
        id: 5,
        action: StratagemAction.verify,
        expectations: StratagemExpectations(
          route: '/home',
          elementsPresent: [StratagemTarget(label: 'Welcome')],
          elementsAbsent: [StratagemTarget(label: 'Login')],
          elementStates: [
            StratagemElementState(label: 'Submit', enabled: true),
          ],
        ),
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);

      expect(restored.expectations?.route, '/home');
      expect(restored.expectations?.elementsPresent?.length, 1);
      expect(restored.expectations?.elementsAbsent?.length, 1);
      expect(restored.expectations?.elementStates?.length, 1);
      expect(restored.expectations?.elementStates?.first.label, 'Submit');
      expect(restored.expectations?.elementStates?.first.enabled, true);
    });

    test('serialization omits null fields', () {
      const step = StratagemStep(id: 1, action: StratagemAction.tap);
      final json = step.toJson();

      expect(json, isNot(contains('description')));
      expect(json, isNot(contains('target')));
      expect(json, isNot(contains('value')));
      expect(json, isNot(contains('scrollDelta')));
    });

    test('all action types serialize correctly', () {
      for (final action in StratagemAction.values) {
        final step = StratagemStep(id: 1, action: action);
        final json = step.toJson();
        final restored = StratagemStep.fromJson(json);
        expect(restored.action, action);
      }
    });

    test('navigate step preserves route', () {
      const step = StratagemStep(
        id: 1,
        action: StratagemAction.navigate,
        navigateRoute: '/settings',
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);
      expect(restored.navigateRoute, '/settings');
    });

    test('slider step preserves range', () {
      const step = StratagemStep(
        id: 1,
        action: StratagemAction.adjustSlider,
        target: StratagemTarget(label: 'Volume'),
        value: '75',
        sliderRange: {'min': 0, 'max': 100},
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);
      expect(restored.sliderRange?['min'], 0);
      expect(restored.sliderRange?['max'], 100);
    });

    test('drag step preserves from/to', () {
      const step = StratagemStep(
        id: 1,
        action: StratagemAction.drag,
        dragFrom: Offset(100, 200),
        dragTo: Offset(300, 400),
      );
      final json = step.toJson();
      final restored = StratagemStep.fromJson(json);
      expect(restored.dragFrom, const Offset(100, 200));
      expect(restored.dragTo, const Offset(300, 400));
    });

    test('toString includes id and action', () {
      const step = StratagemStep(
        id: 5,
        action: StratagemAction.tap,
        description: 'Tap button',
      );
      expect(step.toString(), contains('#5'));
      expect(step.toString(), contains('tap'));
    });
  });

  // -------------------------------------------------------------------------
  // StratagemTarget
  // -------------------------------------------------------------------------
  group('StratagemTarget', () {
    Tableau makeTableau(List<Glyph> glyphs) {
      return Tableau(
        index: 0,
        timestamp: Duration.zero,
        screenWidth: 400,
        screenHeight: 800,
        glyphs: glyphs,
      );
    }

    final loginButton = Glyph(
      widgetType: 'ElevatedButton',
      label: 'Login',
      left: 100,
      top: 600,
      width: 200,
      height: 48,
      isInteractive: true,
      interactionType: 'tap',
      key: 'login_btn',
      ancestors: const ['Scaffold', 'Column'],
    );

    final emailField = Glyph(
      widgetType: 'TextField',
      label: 'Email',
      left: 50,
      top: 200,
      width: 300,
      height: 56,
      isInteractive: true,
      interactionType: 'textInput',
      fieldId: 'email_field',
      semanticRole: 'textField',
    );

    final headerText = Glyph(
      widgetType: 'Text',
      label: 'Welcome to App',
      left: 100,
      top: 50,
      width: 200,
      height: 30,
    );

    final duplicateButton1 = Glyph(
      widgetType: 'ElevatedButton',
      label: 'Action',
      left: 100,
      top: 300,
      width: 100,
      height: 48,
      isInteractive: true,
    );

    final duplicateButton2 = Glyph(
      widgetType: 'ElevatedButton',
      label: 'Action',
      left: 100,
      top: 400,
      width: 100,
      height: 48,
      isInteractive: true,
    );

    group('resolve', () {
      test('finds by label', () {
        final tableau = makeTableau([loginButton, emailField, headerText]);
        const target = StratagemTarget(label: 'Login');
        final result = target.resolve(tableau);
        expect(result, loginButton);
      });

      test('finds by type', () {
        final tableau = makeTableau([loginButton, emailField, headerText]);
        const target = StratagemTarget(type: 'TextField');
        final result = target.resolve(tableau);
        expect(result, emailField);
      });

      test('finds by label + type', () {
        final tableau = makeTableau([loginButton, emailField, headerText]);
        const target = StratagemTarget(label: 'Login', type: 'ElevatedButton');
        final result = target.resolve(tableau);
        expect(result, loginButton);
      });

      test('finds by key', () {
        final tableau = makeTableau([loginButton, emailField]);
        const target = StratagemTarget(key: 'login_btn');
        final result = target.resolve(tableau);
        expect(result, loginButton);
      });

      test('finds by semanticRole', () {
        final tableau = makeTableau([loginButton, emailField]);
        const target = StratagemTarget(semanticRole: 'textField');
        final result = target.resolve(tableau);
        expect(result, emailField);
      });

      test('finds by ancestor', () {
        final tableau = makeTableau([loginButton, emailField]);
        const target = StratagemTarget(label: 'Login', ancestor: 'Scaffold');
        final result = target.resolve(tableau);
        expect(result, loginButton);
      });

      test('returns null when not found', () {
        final tableau = makeTableau([loginButton]);
        const target = StratagemTarget(label: 'Nonexistent');
        expect(target.resolve(tableau), isNull);
      });

      test('uses index for disambiguation', () {
        final tableau = makeTableau([duplicateButton1, duplicateButton2]);
        const target0 = StratagemTarget(label: 'Action', index: 0);
        const target1 = StratagemTarget(label: 'Action', index: 1);
        expect(target0.resolve(tableau), duplicateButton1);
        expect(target1.resolve(tableau), duplicateButton2);
      });

      test('type matching is substring-based', () {
        final tableau = makeTableau([loginButton]);
        const target = StratagemTarget(type: 'Elevated');
        final result = target.resolve(tableau);
        expect(result, loginButton);
      });
    });

    group('fuzzyResolve', () {
      test('exact match works', () {
        final tableau = makeTableau([loginButton]);
        const target = StratagemTarget(label: 'Login');
        expect(target.fuzzyResolve(tableau), loginButton);
      });

      test('partial label match — target contains label', () {
        final tableau = makeTableau([headerText]);
        const target = StratagemTarget(label: 'Welcome');
        expect(target.fuzzyResolve(tableau), headerText);
      });

      test('partial label match — label contains target', () {
        final tableau = makeTableau([headerText]);
        const target = StratagemTarget(label: 'Welcome to App and More');
        expect(target.fuzzyResolve(tableau), headerText);
      });

      test('case-insensitive matching', () {
        final tableau = makeTableau([loginButton]);
        const target = StratagemTarget(label: 'login');
        expect(target.fuzzyResolve(tableau), loginButton);
      });

      test('returns null when no match at all', () {
        final tableau = makeTableau([loginButton]);
        const target = StratagemTarget(label: 'Zzzzz');
        expect(target.fuzzyResolve(tableau), isNull);
      });

      test('fuzzy respects type filter', () {
        final tableau = makeTableau([loginButton, headerText]);
        // "Log" is partial match for both loginButton "Login" and
        // not contained in headerText
        const target = StratagemTarget(label: 'Log', type: 'Text');
        // Should NOT match loginButton (ElevatedButton), and "Log" is not in "Welcome to App"
        expect(target.fuzzyResolve(tableau), isNull);
      });
    });

    group('serialization', () {
      test('toJson and fromJson roundtrip', () {
        const target = StratagemTarget(
          label: 'Submit',
          type: 'ElevatedButton',
          key: 'submit_key',
          semanticRole: 'button',
          index: 2,
          ancestor: 'Form',
        );
        final json = target.toJson();
        final restored = StratagemTarget.fromJson(json);

        expect(restored.label, 'Submit');
        expect(restored.type, 'ElevatedButton');
        expect(restored.key, 'submit_key');
        expect(restored.semanticRole, 'button');
        expect(restored.index, 2);
        expect(restored.ancestor, 'Form');
      });

      test('omits null fields', () {
        const target = StratagemTarget(label: 'OK');
        final json = target.toJson();
        expect(json, contains('label'));
        expect(json, isNot(contains('type')));
        expect(json, isNot(contains('key')));
      });

      test('toString is readable', () {
        const target = StratagemTarget(label: 'Login', type: 'Button');
        expect(target.toString(), contains('Login'));
        expect(target.toString(), contains('Button'));
      });
    });
  });

  // -------------------------------------------------------------------------
  // StratagemExpectations
  // -------------------------------------------------------------------------
  group('StratagemExpectations', () {
    test('serialization roundtrip', () {
      const expectations = StratagemExpectations(
        route: '/home',
        elementsPresent: [
          StratagemTarget(label: 'Welcome'),
          StratagemTarget(label: 'Dashboard'),
        ],
        elementsAbsent: [StratagemTarget(label: 'Login')],
        elementStates: [
          StratagemElementState(
            label: 'Submit',
            type: 'ElevatedButton',
            enabled: true,
            value: 'Ready',
          ),
        ],
        settleTimeout: Duration(seconds: 5),
      );

      final json = expectations.toJson();
      final restored = StratagemExpectations.fromJson(json);

      expect(restored.route, '/home');
      expect(restored.elementsPresent?.length, 2);
      expect(restored.elementsAbsent?.length, 1);
      expect(restored.elementStates?.length, 1);
      expect(restored.settleTimeout, const Duration(seconds: 5));
    });

    test('omits null fields in JSON', () {
      const expectations = StratagemExpectations(route: '/home');
      final json = expectations.toJson();
      expect(json, contains('route'));
      expect(json, isNot(contains('elementsPresent')));
      expect(json, isNot(contains('elementsAbsent')));
    });

    test('toString is readable', () {
      const expectations = StratagemExpectations(
        route: '/home',
        elementsPresent: [StratagemTarget(label: 'X')],
      );
      expect(expectations.toString(), contains('route: /home'));
      expect(expectations.toString(), contains('present: 1'));
    });
  });

  // -------------------------------------------------------------------------
  // StratagemElementState
  // -------------------------------------------------------------------------
  group('StratagemElementState', () {
    test('serialization roundtrip', () {
      const state = StratagemElementState(
        label: 'Submit',
        type: 'ElevatedButton',
        enabled: true,
        value: 'Go',
        visible: true,
      );
      final json = state.toJson();
      final restored = StratagemElementState.fromJson(json);

      expect(restored.label, 'Submit');
      expect(restored.type, 'ElevatedButton');
      expect(restored.enabled, true);
      expect(restored.value, 'Go');
      expect(restored.visible, true);
    });

    test('toString includes relevant info', () {
      const state = StratagemElementState(label: 'OK', enabled: false);
      expect(state.toString(), contains('OK'));
      expect(state.toString(), contains('enabled: false'));
    });
  });

  // -------------------------------------------------------------------------
  // StratagemAction enum
  // -------------------------------------------------------------------------
  group('StratagemAction', () {
    test('has all expected actions', () {
      final names = StratagemAction.values.map((a) => a.name).toList();
      expect(names, contains('tap'));
      expect(names, contains('longPress'));
      expect(names, contains('doubleTap'));
      expect(names, contains('enterText'));
      expect(names, contains('clearText'));
      expect(names, contains('submitField'));
      expect(names, contains('scroll'));
      expect(names, contains('scrollUntilVisible'));
      expect(names, contains('swipe'));
      expect(names, contains('drag'));
      expect(names, contains('toggleSwitch'));
      expect(names, contains('toggleCheckbox'));
      expect(names, contains('selectRadio'));
      expect(names, contains('adjustSlider'));
      expect(names, contains('selectDropdown'));
      expect(names, contains('selectDate'));
      expect(names, contains('selectSegment'));
      expect(names, contains('navigate'));
      expect(names, contains('back'));
      expect(names, contains('wait'));
      expect(names, contains('waitForElement'));
      expect(names, contains('waitForElementGone'));
      expect(names, contains('verify'));
      expect(names, contains('dismissKeyboard'));
      expect(names, contains('pressKey'));
    });
  });

  // -------------------------------------------------------------------------
  // StratagemFailurePolicy enum
  // -------------------------------------------------------------------------
  group('StratagemFailurePolicy', () {
    test('has all expected policies', () {
      expect(StratagemFailurePolicy.values.length, 3);
      expect(StratagemFailurePolicy.abortOnFirst.name, 'abortOnFirst');
      expect(StratagemFailurePolicy.continueAll.name, 'continueAll');
      expect(StratagemFailurePolicy.skipDependents.name, 'skipDependents');
    });
  });
}
