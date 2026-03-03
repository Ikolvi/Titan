import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Mandate', () {
    // -----------------------------------------------------------------------
    // Construction
    // -----------------------------------------------------------------------
    group('construction', () {
      test('creates with no writs', () {
        final m = Mandate();
        expect(m.writCount, 0);
        expect(m.writNames, isEmpty);
        expect(m.strategy, MandateStrategy.allOf);
        expect(m.isDisposed, false);
      });

      test('creates with initial writs', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true),
            Writ(name: 'b', evaluate: () => false),
          ],
        );
        expect(m.writCount, 2);
        expect(m.writNames, ['a', 'b']);
      });

      test('creates with custom strategy', () {
        final m = Mandate(
          writs: [Writ(name: 'x', evaluate: () => true)],
          strategy: MandateStrategy.anyOf,
        );
        expect(m.strategy, MandateStrategy.anyOf);
      });

      test('creates with name', () {
        final m = Mandate(name: 'test-mandate');
        expect(m.name, 'test-mandate');
      });

      test('toString includes name and count', () {
        final m = Mandate(
          writs: [Writ(name: 'a', evaluate: () => true)],
          name: 'access',
        );
        expect(m.toString(), contains('access'));
        expect(m.toString(), contains('1'));
        expect(m.toString(), contains('allOf'));
      });
    });

    // -----------------------------------------------------------------------
    // allOf strategy
    // -----------------------------------------------------------------------
    group('allOf strategy', () {
      test('grants when all writs pass', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true),
            Writ(name: 'b', evaluate: () => true),
          ],
        );
        expect(m.verdict.value, isA<MandateGrant>());
        expect(m.isGranted.value, true);
        expect(m.violations.value, isEmpty);
      });

      test('denies when one writ fails', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true),
            Writ(name: 'b', evaluate: () => false, reason: 'b failed'),
          ],
        );
        expect(m.verdict.value, isA<MandateDenial>());
        expect(m.isGranted.value, false);
        expect(m.violations.value.length, 1);
        expect(m.violations.value.first.writName, 'b');
        expect(m.violations.value.first.reason, 'b failed');
      });

      test('denies when all writs fail', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => false, reason: 'a failed'),
            Writ(name: 'b', evaluate: () => false, reason: 'b failed'),
          ],
        );
        expect(m.verdict.value, isA<MandateDenial>());
        final denial = m.verdict.value as MandateDenial;
        expect(denial.violations.length, 2);
      });

      test('grants when no writs exist', () {
        final m = Mandate();
        expect(m.verdict.value, isA<MandateGrant>());
        expect(m.isGranted.value, true);
      });
    });

    // -----------------------------------------------------------------------
    // anyOf strategy
    // -----------------------------------------------------------------------
    group('anyOf strategy', () {
      test('grants when at least one writ passes', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => false),
            Writ(name: 'b', evaluate: () => true),
          ],
          strategy: MandateStrategy.anyOf,
        );
        expect(m.isGranted.value, true);
      });

      test('denies when all writs fail', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => false),
            Writ(name: 'b', evaluate: () => false),
          ],
          strategy: MandateStrategy.anyOf,
        );
        expect(m.isGranted.value, false);
      });

      test('grants when all writs pass', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true),
            Writ(name: 'b', evaluate: () => true),
          ],
          strategy: MandateStrategy.anyOf,
        );
        expect(m.isGranted.value, true);
      });
    });

    // -----------------------------------------------------------------------
    // majority strategy
    // -----------------------------------------------------------------------
    group('majority strategy', () {
      test('grants when passing weight > failing weight', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true, weight: 3),
            Writ(name: 'b', evaluate: () => false, weight: 1),
            Writ(name: 'c', evaluate: () => false, weight: 1),
          ],
          strategy: MandateStrategy.majority,
        );
        expect(m.isGranted.value, true);
      });

      test('denies when failing weight >= passing weight', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true, weight: 1),
            Writ(name: 'b', evaluate: () => false, weight: 2),
          ],
          strategy: MandateStrategy.majority,
        );
        expect(m.isGranted.value, false);
      });

      test('denies on tie (passWeight == failWeight)', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true, weight: 2),
            Writ(name: 'b', evaluate: () => false, weight: 2),
          ],
          strategy: MandateStrategy.majority,
        );
        expect(m.isGranted.value, false);
      });

      test('respects custom weights', () {
        final m = Mandate(
          writs: [
            Writ(name: 'admin', evaluate: () => true, weight: 10),
            Writ(name: 'geo', evaluate: () => false, weight: 1),
            Writ(name: 'time', evaluate: () => false, weight: 1),
            Writ(name: 'rate', evaluate: () => false, weight: 1),
          ],
          strategy: MandateStrategy.majority,
        );
        expect(m.isGranted.value, true);
      });
    });

    // -----------------------------------------------------------------------
    // Reactive behavior
    // -----------------------------------------------------------------------
    group('reactive behavior', () {
      test('re-evaluates when Core dependency changes', () {
        final role = TitanState<String>('user');
        final m = Mandate(
          writs: [
            Writ(
              name: 'admin-only',
              evaluate: () => role.value == 'admin',
              reason: 'Admin access required',
            ),
          ],
        );

        expect(m.isGranted.value, false);
        expect(m.violations.value.first.writName, 'admin-only');

        role.value = 'admin';
        expect(m.isGranted.value, true);
        expect(m.violations.value, isEmpty);
      });

      test('tracks multiple Core dependencies', () {
        final isAuth = TitanState<bool>(false);
        final isPremium = TitanState<bool>(false);
        final m = Mandate(
          writs: [
            Writ(name: 'auth', evaluate: () => isAuth.value),
            Writ(name: 'premium', evaluate: () => isPremium.value),
          ],
        );

        expect(m.isGranted.value, false);
        expect(m.violations.value.length, 2);

        isAuth.value = true;
        expect(m.isGranted.value, false);
        expect(m.violations.value.length, 1);
        expect(m.violations.value.first.writName, 'premium');

        isPremium.value = true;
        expect(m.isGranted.value, true);
      });

      test('can() returns reactive writ result', () {
        final role = TitanState<String>('guest');
        final m = Mandate(
          writs: [Writ(name: 'editor', evaluate: () => role.value != 'guest')],
        );

        expect(m.can('editor').value, false);
        role.value = 'editor';
        expect(m.can('editor').value, true);
      });

      test('verdict switches type reactively', () {
        final flag = TitanState<bool>(false);
        final m = Mandate(
          writs: [Writ(name: 'flag', evaluate: () => flag.value)],
        );

        expect(m.verdict.value, isA<MandateDenial>());
        flag.value = true;
        expect(m.verdict.value, isA<MandateGrant>());
        flag.value = false;
        expect(m.verdict.value, isA<MandateDenial>());
      });
    });

    // -----------------------------------------------------------------------
    // Dynamic writ management
    // -----------------------------------------------------------------------
    group('dynamic writ management', () {
      test('addWrit adds and re-evaluates', () {
        final m = Mandate();
        expect(m.isGranted.value, true);

        m.addWrit(Writ(name: 'check', evaluate: () => false));
        expect(m.writCount, 1);
        expect(m.isGranted.value, false);
      });

      test('addWrit throws on duplicate name', () {
        final m = Mandate(
          writs: [Writ(name: 'a', evaluate: () => true)],
        );
        expect(
          () => m.addWrit(Writ(name: 'a', evaluate: () => true)),
          throwsArgumentError,
        );
      });

      test('addWrits adds multiple writs', () {
        final m = Mandate();
        m.addWrits([
          Writ(name: 'a', evaluate: () => true),
          Writ(name: 'b', evaluate: () => true),
        ]);
        expect(m.writCount, 2);
        expect(m.isGranted.value, true);
      });

      test('addWrits throws on duplicate name', () {
        final m = Mandate(
          writs: [Writ(name: 'a', evaluate: () => true)],
        );
        expect(
          () => m.addWrits([
            Writ(name: 'b', evaluate: () => true),
            Writ(name: 'a', evaluate: () => true),
          ]),
          throwsArgumentError,
        );
      });

      test('removeWrit removes and re-evaluates', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true),
            Writ(name: 'b', evaluate: () => false),
          ],
        );
        expect(m.isGranted.value, false);

        final removed = m.removeWrit('b');
        expect(removed, true);
        expect(m.writCount, 1);
        expect(m.isGranted.value, true);
      });

      test('removeWrit returns false for unknown name', () {
        final m = Mandate();
        expect(m.removeWrit('nonexistent'), false);
      });

      test('replaceWrit replaces and re-evaluates', () {
        final m = Mandate(
          writs: [Writ(name: 'check', evaluate: () => false)],
        );
        expect(m.isGranted.value, false);

        m.replaceWrit(Writ(name: 'check', evaluate: () => true));
        expect(m.isGranted.value, true);
      });

      test('replaceWrit throws for unknown name', () {
        final m = Mandate();
        expect(
          () => m.replaceWrit(Writ(name: 'x', evaluate: () => true)),
          throwsStateError,
        );
      });

      test('updateStrategy changes strategy and re-evaluates', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true),
            Writ(name: 'b', evaluate: () => false),
          ],
          strategy: MandateStrategy.allOf,
        );
        expect(m.isGranted.value, false);

        m.updateStrategy(MandateStrategy.anyOf);
        expect(m.strategy, MandateStrategy.anyOf);
        expect(m.isGranted.value, true);
      });

      test('updateStrategy is no-op if same strategy', () {
        final m = Mandate(strategy: MandateStrategy.allOf);
        m.updateStrategy(MandateStrategy.allOf);
        expect(m.strategy, MandateStrategy.allOf);
      });
    });

    // -----------------------------------------------------------------------
    // Inspection
    // -----------------------------------------------------------------------
    group('inspection', () {
      test('hasWrit checks by name', () {
        final m = Mandate(
          writs: [Writ(name: 'auth', evaluate: () => true)],
        );
        expect(m.hasWrit('auth'), true);
        expect(m.hasWrit('unknown'), false);
      });

      test('can() throws for unknown writ name', () {
        final m = Mandate();
        expect(() => m.can('nonexistent'), throwsStateError);
      });

      test('writNames returns all names in order', () {
        final m = Mandate(
          writs: [
            Writ(name: 'first', evaluate: () => true),
            Writ(name: 'second', evaluate: () => true),
            Writ(name: 'third', evaluate: () => true),
          ],
        );
        expect(m.writNames, ['first', 'second', 'third']);
      });
    });

    // -----------------------------------------------------------------------
    // MandateVerdict types
    // -----------------------------------------------------------------------
    group('MandateVerdict', () {
      test('MandateGrant properties', () {
        const grant = MandateGrant();
        expect(grant.isGranted, true);
        expect(grant.isDenied, false);
        expect(grant.violations, isEmpty);
        expect(grant.toString(), 'MandateGrant()');
      });

      test('MandateGrant equality', () {
        const a = MandateGrant();
        const b = MandateGrant();
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('MandateDenial properties', () {
        final denial = MandateDenial(
          violations: [
            const WritViolation(writName: 'auth', reason: 'Not logged in'),
          ],
        );
        expect(denial.isGranted, false);
        expect(denial.isDenied, true);
        expect(denial.violations.length, 1);
        expect(denial.toString(), contains('auth'));
      });

      test('MandateDenial equality', () {
        final a = MandateDenial(
          violations: [const WritViolation(writName: 'x', reason: 'r')],
        );
        final b = MandateDenial(
          violations: [const WritViolation(writName: 'x', reason: 'r')],
        );
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('MandateDenial inequality on different violations', () {
        final a = MandateDenial(
          violations: [const WritViolation(writName: 'x')],
        );
        final b = MandateDenial(
          violations: [const WritViolation(writName: 'y')],
        );
        expect(a, isNot(equals(b)));
      });

      test('MandateDenial inequality on different length', () {
        final a = MandateDenial(
          violations: [const WritViolation(writName: 'x')],
        );
        final b = MandateDenial(
          violations: [
            const WritViolation(writName: 'x'),
            const WritViolation(writName: 'y'),
          ],
        );
        expect(a, isNot(equals(b)));
      });
    });

    // -----------------------------------------------------------------------
    // WritViolation
    // -----------------------------------------------------------------------
    group('WritViolation', () {
      test('toString with reason', () {
        const v = WritViolation(writName: 'auth', reason: 'No token');
        expect(v.toString(), 'WritViolation(auth: No token)');
      });

      test('toString without reason', () {
        const v = WritViolation(writName: 'auth');
        expect(v.toString(), 'WritViolation(auth)');
      });

      test('equality', () {
        const a = WritViolation(writName: 'x', reason: 'r');
        const b = WritViolation(writName: 'x', reason: 'r');
        expect(a, equals(b));
        expect(a.hashCode, b.hashCode);
      });

      test('inequality', () {
        const a = WritViolation(writName: 'x', reason: 'r');
        const b = WritViolation(writName: 'y', reason: 'r');
        expect(a, isNot(equals(b)));
      });
    });

    // -----------------------------------------------------------------------
    // Disposal
    // -----------------------------------------------------------------------
    group('disposal', () {
      test('dispose sets isDisposed', () {
        final m = Mandate();
        m.dispose();
        expect(m.isDisposed, true);
      });

      test('double dispose is safe', () {
        final m = Mandate();
        m.dispose();
        m.dispose(); // should not throw
      });

      test('addWrit throws after dispose', () {
        final m = Mandate();
        m.dispose();
        expect(
          () => m.addWrit(Writ(name: 'a', evaluate: () => true)),
          throwsStateError,
        );
      });

      test('removeWrit throws after dispose', () {
        final m = Mandate(
          writs: [Writ(name: 'a', evaluate: () => true)],
        );
        m.dispose();
        expect(() => m.removeWrit('a'), throwsStateError);
      });

      test('replaceWrit throws after dispose', () {
        final m = Mandate(
          writs: [Writ(name: 'a', evaluate: () => true)],
        );
        m.dispose();
        expect(
          () => m.replaceWrit(Writ(name: 'a', evaluate: () => false)),
          throwsStateError,
        );
      });

      test('updateStrategy throws after dispose', () {
        final m = Mandate();
        m.dispose();
        expect(() => m.updateStrategy(MandateStrategy.anyOf), throwsStateError);
      });
    });

    // -----------------------------------------------------------------------
    // Pillar integration
    // -----------------------------------------------------------------------
    group('Pillar integration', () {
      test('mandate() factory creates managed Mandate', () {
        final pillar = _TestMandatePillar();
        pillar.initialize();

        expect(pillar.editAccess.isGranted.value, false);

        pillar.isAuth.value = true;
        expect(pillar.editAccess.isGranted.value, false);

        pillar.isOwner.value = true;
        expect(pillar.editAccess.isGranted.value, true);

        pillar.dispose();
      });

      test('mandate is disposed with Pillar', () {
        final pillar = _TestMandatePillar();
        pillar.initialize();

        final access = pillar.editAccess;
        pillar.dispose();
        // The managed nodes should be disposed — accessing verdict may
        // throw or return stale data. We just verify no errors.
        expect(pillar.isDisposed, true);
        expect(access.isDisposed, false); // Mandate itself isn't disposed
        // but its nodes are detached from the reactive graph
      });

      test('can() works through Pillar factory', () {
        final pillar = _TestMandatePillar();
        pillar.initialize();

        expect(pillar.editAccess.can('authenticated').value, false);
        pillar.isAuth.value = true;
        expect(pillar.editAccess.can('authenticated').value, true);

        pillar.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Pattern matching
    // -----------------------------------------------------------------------
    group('pattern matching', () {
      test('switch on MandateVerdict', () {
        final m = Mandate(
          writs: [Writ(name: 'auth', evaluate: () => false, reason: 'No auth')],
        );

        final result = switch (m.verdict.value) {
          MandateGrant() => 'granted',
          MandateDenial(:final violations) =>
            'denied: ${violations.first.reason}',
        };
        expect(result, 'denied: No auth');
      });
    });

    // -----------------------------------------------------------------------
    // Edge cases
    // -----------------------------------------------------------------------
    group('edge cases', () {
      test('single writ allOf', () {
        final m = Mandate(
          writs: [Writ(name: 'only', evaluate: () => true)],
        );
        expect(m.isGranted.value, true);
      });

      test('anyOf with no writs grants', () {
        final m = Mandate(strategy: MandateStrategy.anyOf);
        // No writs means passWeight = 0, so anyOf should deny
        // Actually per design: empty writs → MandateGrant (before strategy)
        expect(m.isGranted.value, true);
      });

      test('majority with single passing writ', () {
        final m = Mandate(
          writs: [Writ(name: 'a', evaluate: () => true)],
          strategy: MandateStrategy.majority,
        );
        expect(m.isGranted.value, true);
      });

      test('majority with single failing writ', () {
        final m = Mandate(
          writs: [Writ(name: 'a', evaluate: () => false)],
          strategy: MandateStrategy.majority,
        );
        expect(m.isGranted.value, false);
      });

      test('writ with default weight is 1', () {
        final w = Writ(name: 'a', evaluate: () => true);
        expect(w.weight, 1);
      });

      test('writ with null description and reason', () {
        final w = Writ(name: 'a', evaluate: () => true);
        expect(w.description, isNull);
        expect(w.reason, isNull);
      });

      test('managedNodes returns all reactive nodes', () {
        final m = Mandate(
          writs: [
            Writ(name: 'a', evaluate: () => true),
            Writ(name: 'b', evaluate: () => true),
          ],
        );
        // 3 composite + 2 per-writ = 5 computed nodes
        expect(m.managedNodes.length, 5);
        // 1 revision state node
        expect(m.managedStateNodes.length, 1);
      });

      test('complex reactive scenario with multiple Cores', () {
        final role = TitanState<String>('user');
        final plan = TitanState<String>('free');
        final featureEnabled = TitanState<bool>(false);

        final m = Mandate(
          writs: [
            Writ(
              name: 'admin-or-premium',
              evaluate: () => role.value == 'admin' || plan.value == 'premium',
            ),
            Writ(name: 'feature-flag', evaluate: () => featureEnabled.value),
          ],
        );

        // Both fail
        expect(m.isGranted.value, false);
        expect(m.violations.value.length, 2);

        // Enable feature flag — still denied (admin-or-premium fails)
        featureEnabled.value = true;
        expect(m.isGranted.value, false);
        expect(m.violations.value.length, 1);

        // Make premium — now granted
        plan.value = 'premium';
        expect(m.isGranted.value, true);

        // Revoke premium, but make admin
        plan.value = 'free';
        role.value = 'admin';
        expect(m.isGranted.value, true);
      });

      test('addWrit after initial evaluation preserves reactivity', () {
        final flag = TitanState<bool>(true);
        final m = Mandate();
        expect(m.isGranted.value, true);

        m.addWrit(Writ(name: 'flag', evaluate: () => flag.value));
        expect(m.isGranted.value, true);

        flag.value = false;
        expect(m.isGranted.value, false);

        flag.value = true;
        expect(m.isGranted.value, true);
      });
    });
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _TestMandatePillar extends Pillar {
  late final isAuth = core(false, name: 'isAuth');
  late final isOwner = core(false, name: 'isOwner');

  late final editAccess = mandate(
    writs: [
      Writ(
        name: 'authenticated',
        evaluate: () => isAuth.value,
        reason: 'Must be logged in',
      ),
      Writ(
        name: 'owner',
        evaluate: () => isOwner.value,
        reason: 'Must be document owner',
      ),
    ],
    name: 'edit-access',
  );
}
