import 'package:test/test.dart';
import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

void main() {
  group('Moat', () {
    late Moat limiter;

    setUp(() {
      limiter = Moat(
        maxTokens: 5,
        refillRate: const Duration(milliseconds: 100),
        name: 'test',
      );
    });

    tearDown(() {
      limiter.dispose();
    });

    // -----------------------------------------------------------------------
    // Basic operations
    // -----------------------------------------------------------------------

    group('basic operations', () {
      test('starts with full tokens', () {
        expect(limiter.remainingTokens.value, 5);
        expect(limiter.hasTokens, isTrue);
        expect(limiter.isEmpty, isFalse);
      });

      test('tryConsume returns true and decrements tokens', () {
        expect(limiter.tryConsume(), isTrue);
        expect(limiter.remainingTokens.value, 4);
        expect(limiter.consumed.value, 1);
      });

      test('tryConsume returns false when empty', () {
        for (var i = 0; i < 5; i++) {
          expect(limiter.tryConsume(), isTrue);
        }
        expect(limiter.tryConsume(), isFalse);
        expect(limiter.remainingTokens.value, 0);
        expect(limiter.isEmpty, isTrue);
      });

      test('tryConsume with multiple tokens', () {
        expect(limiter.tryConsume(3), isTrue);
        expect(limiter.remainingTokens.value, 2);
        expect(limiter.consumed.value, 3);
      });

      test('tryConsume rejects when not enough tokens', () {
        expect(limiter.tryConsume(3), isTrue);
        expect(limiter.tryConsume(3), isFalse); // only 2 left
        expect(limiter.rejections.value, 1);
      });
    });

    // -----------------------------------------------------------------------
    // Reactive state
    // -----------------------------------------------------------------------

    group('reactive state', () {
      test('remainingTokens is reactive', () {
        expect(limiter.remainingTokens.value, 5);
        limiter.tryConsume();
        expect(limiter.remainingTokens.value, 4);
      });

      test('rejections tracks rejected requests', () {
        for (var i = 0; i < 5; i++) {
          limiter.tryConsume();
        }
        limiter.tryConsume(); // rejected
        limiter.tryConsume(); // rejected
        expect(limiter.rejections.value, 2);
      });

      test('consumed tracks total consumption', () {
        limiter.tryConsume();
        limiter.tryConsume(2);
        expect(limiter.consumed.value, 3);
      });

      test('fillPercentage calculates correctly', () {
        expect(limiter.fillPercentage, 100.0);
        limiter.tryConsume();
        expect(limiter.fillPercentage, 80.0);
        limiter.tryConsume(2);
        expect(limiter.fillPercentage, 40.0);
      });

      test('timeToNextToken returns zero when tokens available', () {
        expect(limiter.timeToNextToken, Duration.zero);
      });

      test('timeToNextToken returns refillRate when empty', () {
        for (var i = 0; i < 5; i++) {
          limiter.tryConsume();
        }
        expect(limiter.timeToNextToken, const Duration(milliseconds: 100));
      });
    });

    // -----------------------------------------------------------------------
    // Token refill
    // -----------------------------------------------------------------------

    group('token refill', () {
      test('tokens replenish after refill period', () async {
        for (var i = 0; i < 5; i++) {
          limiter.tryConsume();
        }
        expect(limiter.remainingTokens.value, 0);

        await Future<void>.delayed(const Duration(milliseconds: 250));

        // Should have replenished some tokens
        expect(limiter.remainingTokens.value, greaterThan(0));
      });

      test('tokens do not exceed maxTokens', () async {
        // Don't consume anything
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(limiter.remainingTokens.value, 5);
      });
    });

    // -----------------------------------------------------------------------
    // Callback
    // -----------------------------------------------------------------------

    group('callbacks', () {
      test('onReject called when rate limited', () {
        var rejectCount = 0;
        final callbackLimiter = Moat(
          maxTokens: 2,
          refillRate: const Duration(seconds: 60),
          onReject: () => rejectCount++,
          name: 'callback',
        );

        callbackLimiter.tryConsume();
        callbackLimiter.tryConsume();
        callbackLimiter.tryConsume(); // rejected
        callbackLimiter.tryConsume(); // rejected

        expect(rejectCount, 2);
        callbackLimiter.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Guard
    // -----------------------------------------------------------------------

    group('guard', () {
      test('guard executes action when tokens available', () async {
        final result = await limiter.guard(() async => 42);
        expect(result, 42);
        expect(limiter.consumed.value, 1);
      });

      test('guard returns null when rate limited', () async {
        for (var i = 0; i < 5; i++) {
          limiter.tryConsume();
        }
        final result = await limiter.guard<int>(() async => 42);
        expect(result, isNull);
      });

      test('guard calls onLimit when rate limited', () async {
        for (var i = 0; i < 5; i++) {
          limiter.tryConsume();
        }
        var limitCalled = false;
        await limiter.guard(() async => 42, onLimit: () => limitCalled = true);
        expect(limitCalled, isTrue);
      });
    });

    // -----------------------------------------------------------------------
    // Consume (blocking)
    // -----------------------------------------------------------------------

    group('consume', () {
      test('consume returns true immediately when tokens available', () async {
        final result = await limiter.consume();
        expect(result, isTrue);
        expect(limiter.consumed.value, 1);
      });

      test('consume waits and succeeds after refill', () async {
        for (var i = 0; i < 5; i++) {
          limiter.tryConsume();
        }

        final stopwatch = Stopwatch()..start();
        final result = await limiter.consume(
          timeout: const Duration(seconds: 1),
        );
        stopwatch.stop();

        expect(result, isTrue);
        expect(stopwatch.elapsedMilliseconds, greaterThan(50));
      });

      test('consume times out and returns false', () async {
        for (var i = 0; i < 5; i++) {
          limiter.tryConsume();
        }

        final verySlowLimiter = Moat(
          maxTokens: 5,
          refillRate: const Duration(seconds: 60),
          name: 'slow',
        );
        // Consume all tokens from the slow limiter
        for (var i = 0; i < 5; i++) {
          verySlowLimiter.tryConsume();
        }

        final result = await verySlowLimiter.consume(
          timeout: const Duration(milliseconds: 50),
        );
        expect(result, isFalse);
        verySlowLimiter.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Reset
    // -----------------------------------------------------------------------

    group('reset', () {
      test('reset restores full capacity and clears stats', () {
        limiter.tryConsume(3);
        limiter.tryConsume(3); // rejected
        limiter.reset();

        expect(limiter.remainingTokens.value, 5);
        expect(limiter.consumed.value, 0);
        expect(limiter.rejections.value, 0);
      });
    });

    // -----------------------------------------------------------------------
    // toString
    // -----------------------------------------------------------------------

    test('toString includes stats', () {
      limiter.tryConsume(2);
      final str = limiter.toString();
      expect(str, contains('Moat'));
      expect(str, contains('remaining: 3/5'));
      expect(str, contains('consumed: 2'));
    });
  });

  // ---------------------------------------------------------------------------
  // MoatPool
  // ---------------------------------------------------------------------------

  group('MoatPool', () {
    late MoatPool pool;

    setUp(() {
      pool = MoatPool(maxTokens: 3, refillRate: const Duration(seconds: 60));
    });

    tearDown(() {
      pool.dispose();
    });

    test('creates independent limiters per key', () {
      expect(pool.tryConsume('a'), isTrue);
      expect(pool.tryConsume('a'), isTrue);
      expect(pool.tryConsume('a'), isTrue);
      expect(pool.tryConsume('a'), isFalse); // 'a' exhausted

      // 'b' should still have all tokens
      expect(pool.tryConsume('b'), isTrue);
      expect(pool.tryConsume('b'), isTrue);
      expect(pool.tryConsume('b'), isTrue);
      expect(pool.tryConsume('b'), isFalse); // 'b' exhausted
    });

    test('operator [] returns a Moat for the key', () {
      final moat = pool['users'];
      expect(moat, isA<Moat>());
      expect(moat.maxTokens, 3);
    });

    test('activeCount tracks created limiters', () {
      pool.tryConsume('a');
      pool.tryConsume('b');
      expect(pool.activeCount, 2);
    });

    test('keys returns all active keys', () {
      pool.tryConsume('alpha');
      pool.tryConsume('beta');
      expect(pool.keys, containsAll(['alpha', 'beta']));
    });

    test('remove disposes a specific key', () {
      pool.tryConsume('temp');
      expect(pool.activeCount, 1);
      pool.remove('temp');
      expect(pool.activeCount, 0);
    });

    test('resetAll resets all limiters', () {
      pool.tryConsume('x');
      pool.tryConsume('x');
      pool.tryConsume('y');
      pool.resetAll();
      expect(pool['x'].remainingTokens.value, 3);
      expect(pool['y'].remainingTokens.value, 3);
    });

    test('onReject called with key', () {
      String? rejectedKey;
      final callbackPool = MoatPool(
        maxTokens: 1,
        refillRate: const Duration(seconds: 60),
        onReject: (key) => rejectedKey = key,
      );

      callbackPool.tryConsume('api');
      callbackPool.tryConsume('api'); // rejected
      expect(rejectedKey, 'api');
      callbackPool.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // Pillar integration
  // ---------------------------------------------------------------------------

  group('Pillar integration', () {
    test('moat() factory creates managed rate limiter', () {
      final pillar = _TestPillar();
      pillar.initialize();

      expect(pillar.apiLimiter.hasTokens, isTrue);
      expect(pillar.apiLimiter.tryConsume(), isTrue);

      pillar.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Test Pillar
// ---------------------------------------------------------------------------

class _TestPillar extends Pillar {
  late final apiLimiter = moat(
    maxTokens: 10,
    refillRate: const Duration(seconds: 1),
    name: 'test-api',
  );
}
