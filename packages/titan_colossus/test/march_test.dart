import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // March — Transition between screens
  // -------------------------------------------------------------------------

  group('March', () {
    test('creates with required fields', () {
      final march = March(
        fromRoute: '/login',
        toRoute: '/home',
        trigger: MarchTrigger.tap,
      );

      expect(march.fromRoute, '/login');
      expect(march.toRoute, '/home');
      expect(march.trigger, MarchTrigger.tap);
      expect(march.triggerElementLabel, isNull);
      expect(march.triggerElementType, isNull);
      expect(march.triggerElementKey, isNull);
      expect(march.observationCount, 1);
      expect(march.averageDurationMs, 0);
      expect(march.preconditionNotes, isNull);
    });

    test('creates with all fields', () {
      final march = March(
        fromRoute: '/login',
        toRoute: '/home',
        trigger: MarchTrigger.formSubmit,
        triggerElementLabel: 'Login',
        triggerElementType: 'ElevatedButton',
        triggerElementKey: 'login_btn',
        observationCount: 5,
        averageDurationMs: 350,
        preconditionNotes: 'Requires valid credentials',
      );

      expect(march.triggerElementLabel, 'Login');
      expect(march.triggerElementType, 'ElevatedButton');
      expect(march.triggerElementKey, 'login_btn');
      expect(march.observationCount, 5);
      expect(march.averageDurationMs, 350);
      expect(march.preconditionNotes, 'Requires valid credentials');
    });

    group('isReliable', () {
      test('returns false for 1 observation', () {
        final march = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          observationCount: 1,
        );
        expect(march.isReliable, false);
      });

      test('returns true for 2 observations', () {
        final march = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          observationCount: 2,
        );
        expect(march.isReliable, true);
      });

      test('returns true for many observations', () {
        final march = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          observationCount: 100,
        );
        expect(march.isReliable, true);
      });
    });

    group('matches', () {
      test('matches by same from/to/label/type', () {
        final a = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
          triggerElementLabel: 'Login',
          triggerElementType: 'ElevatedButton',
        );
        final b = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
          triggerElementLabel: 'Login',
          triggerElementType: 'ElevatedButton',
        );
        expect(a.matches(b), true);
      });

      test('matches by key when both have keys', () {
        final a = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
          triggerElementKey: 'login_btn',
        );
        final b = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
          triggerElementKey: 'login_btn',
        );
        expect(a.matches(b), true);
      });

      test('does not match different keys', () {
        final a = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
          triggerElementKey: 'login_btn',
        );
        final b = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
          triggerElementKey: 'other_btn',
        );
        expect(a.matches(b), false);
      });

      test('does not match different routes', () {
        final a = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
        );
        final b = March(
          fromRoute: '/login',
          toRoute: '/settings',
          trigger: MarchTrigger.tap,
        );
        expect(a.matches(b), false);
      });

      test('does not match different from routes', () {
        final a = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
        );
        final b = March(
          fromRoute: '/register',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
        );
        expect(a.matches(b), false);
      });

      test('matches null labels/types', () {
        final a = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.redirect,
        );
        final b = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.redirect,
        );
        expect(a.matches(b), true);
      });
    });

    group('mergeObservation', () {
      test('increments observation count', () {
        final march = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          averageDurationMs: 100,
        );
        final other = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          averageDurationMs: 200,
        );
        march.mergeObservation(other);
        expect(march.observationCount, 2);
      });

      test('computes running average duration', () {
        final march = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          averageDurationMs: 100,
        );
        final other = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          averageDurationMs: 300,
        );
        march.mergeObservation(other);
        // (100 * 1 + 300) / 2 = 200
        expect(march.averageDurationMs, 200);
      });

      test('uses explicit durationMs when provided', () {
        final march = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
          averageDurationMs: 100,
        );
        final other = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
        );
        march.mergeObservation(other, durationMs: 500);
        // (100 * 1 + 500) / 2 = 300
        expect(march.averageDurationMs, 300);
      });
    });

    group('toShortString', () {
      test('includes label when present', () {
        final march = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.tap,
          triggerElementLabel: 'Login',
        );
        expect(march.toShortString(), '→ /home (tap "Login")');
      });

      test('shows only trigger name without label', () {
        final march = March(
          fromRoute: '/dashboard',
          toRoute: '/login',
          trigger: MarchTrigger.redirect,
        );
        expect(march.toShortString(), '→ /login (redirect)');
      });
    });

    group('serialization', () {
      test('round-trips through JSON', () {
        final march = March(
          fromRoute: '/login',
          toRoute: '/home',
          trigger: MarchTrigger.formSubmit,
          triggerElementLabel: 'Login',
          triggerElementType: 'ElevatedButton',
          triggerElementKey: 'login_btn',
          observationCount: 5,
          averageDurationMs: 350,
          preconditionNotes: 'Requires credentials',
        );

        final json = march.toJson();
        final restored = March.fromJson(json);

        expect(restored.fromRoute, march.fromRoute);
        expect(restored.toRoute, march.toRoute);
        expect(restored.trigger, march.trigger);
        expect(restored.triggerElementLabel, march.triggerElementLabel);
        expect(restored.triggerElementType, march.triggerElementType);
        expect(restored.triggerElementKey, march.triggerElementKey);
        expect(restored.observationCount, march.observationCount);
        expect(restored.averageDurationMs, march.averageDurationMs);
        expect(restored.preconditionNotes, march.preconditionNotes);
      });

      test('omits null optional fields from JSON', () {
        final march = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.redirect,
        );

        final json = march.toJson();
        expect(json.containsKey('triggerElementLabel'), false);
        expect(json.containsKey('triggerElementType'), false);
        expect(json.containsKey('triggerElementKey'), false);
        expect(json.containsKey('preconditionNotes'), false);
      });

      test('handles unknown trigger name gracefully', () {
        final json = {
          'fromRoute': '/a',
          'toRoute': '/b',
          'trigger': 'nonExistentTrigger',
        };
        final march = March.fromJson(json);
        expect(march.trigger, MarchTrigger.unknown);
      });
    });

    test('toString includes key information', () {
      final march = March(
        fromRoute: '/login',
        toRoute: '/home',
        trigger: MarchTrigger.tap,
        observationCount: 3,
      );
      final str = march.toString();
      expect(str, contains('/login'));
      expect(str, contains('/home'));
      expect(str, contains('tap'));
      expect(str, contains('3x'));
    });
  });

  // -------------------------------------------------------------------------
  // MarchTrigger
  // -------------------------------------------------------------------------

  group('MarchTrigger', () {
    test('has all expected values', () {
      expect(MarchTrigger.values, hasLength(8));
      expect(MarchTrigger.values, contains(MarchTrigger.tap));
      expect(MarchTrigger.values, contains(MarchTrigger.formSubmit));
      expect(MarchTrigger.values, contains(MarchTrigger.programmatic));
      expect(MarchTrigger.values, contains(MarchTrigger.redirect));
      expect(MarchTrigger.values, contains(MarchTrigger.back));
      expect(MarchTrigger.values, contains(MarchTrigger.swipe));
      expect(MarchTrigger.values, contains(MarchTrigger.deepLink));
      expect(MarchTrigger.values, contains(MarchTrigger.unknown));
    });
  });
}
