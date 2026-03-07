import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // RouteParameterizer — Route pattern detection
  // -------------------------------------------------------------------------

  group('RouteParameterizer', () {
    late RouteParameterizer parameterizer;

    setUp(() {
      parameterizer = RouteParameterizer();
    });

    group('parameterize', () {
      test('returns route as-is when only one route observed', () {
        expect(parameterizer.parameterize('/quest/42'), '/quest/42');
      });

      test('detects numeric ID parameter with two observations', () {
        parameterizer.parameterize('/quest/42');
        final result = parameterizer.parameterize('/quest/7');
        expect(result, '/quest/:id');
      });

      test('maps original routes to detected pattern', () {
        parameterizer.parameterize('/quest/42');
        parameterizer.parameterize('/quest/7');

        expect(parameterizer.patternFor('/quest/42'), '/quest/:id');
        expect(parameterizer.patternFor('/quest/7'), '/quest/:id');
      });

      test('handles UUID-like IDs', () {
        parameterizer.parameterize('/user/a1b2c3d4e5f6');
        final result =
            parameterizer.parameterize('/user/f6e5d4c3b2a1');
        expect(result, '/user/:id');
      });

      test('mixed constant and variable segments', () {
        parameterizer.parameterize('/user/42/posts');
        final result = parameterizer.parameterize('/user/7/posts');
        expect(result, '/user/:id/posts');
      });

      test('multiple parameter segments', () {
        parameterizer.parameterize('/user/42/post/100');
        final result = parameterizer.parameterize('/user/7/post/200');
        // Both segments are numeric IDs
        expect(result, '/user/:id/post/:id');
      });

      test('preserves constant routes without IDs', () {
        parameterizer.parameterize('/login');
        parameterizer.parameterize('/register');
        // Same segment count but no constant anchor to establish pattern
        expect(parameterizer.patternFor('/login'), '/login');
        expect(parameterizer.patternFor('/register'), '/register');
      });

      test('non-ID varying segments use :paramN', () {
        parameterizer.parameterize('/category/electronics');
        final result = parameterizer.parameterize('/category/clothing');
        expect(result, '/category/:param2');
      });

      test('handles root route', () {
        expect(parameterizer.parameterize('/'), '/');
      });

      test('returns cached pattern for already-seen route', () {
        parameterizer.parameterize('/quest/42');
        parameterizer.parameterize('/quest/7');

        // Third observation of same pattern should use cache
        final result = parameterizer.parameterize('/quest/99');
        expect(result, '/quest/:id');
      });

      test('handles deep nested routes', () {
        parameterizer.parameterize('/api/v1/users/42/comments/5');
        final result =
            parameterizer.parameterize('/api/v1/users/7/comments/3');
        expect(result, '/api/v1/users/:id/comments/:id');
      });

      test('different segment counts are independent', () {
        parameterizer.parameterize('/quest');
        parameterizer.parameterize('/quest/42');
        parameterizer.parameterize('/quest/7');

        expect(parameterizer.patternFor('/quest'), '/quest');
        expect(parameterizer.patternFor('/quest/42'), '/quest/:id');
      });
    });

    group('registerPattern', () {
      test('uses registered pattern for matching routes', () {
        parameterizer.registerPattern('/quest/:id');
        final result = parameterizer.parameterize('/quest/42');
        expect(result, '/quest/:id');
      });

      test('registered pattern takes precedence over detection', () {
        parameterizer.registerPattern('/user/:userId/post/:postId');
        final result = parameterizer.parameterize('/user/42/post/100');
        expect(result, '/user/:userId/post/:postId');
      });

      test('does not match routes with different segment count', () {
        parameterizer.registerPattern('/quest/:id');
        final result = parameterizer.parameterize('/quest/42/comments');
        // Different segment count, no match
        expect(result, '/quest/42/comments');
      });
    });

    group('patternFor', () {
      test('returns null for unknown route', () {
        expect(parameterizer.patternFor('/unknown'), isNull);
      });

      test('returns pattern after parameterization', () {
        parameterizer.parameterize('/home');
        expect(parameterizer.patternFor('/home'), '/home');
      });
    });

    group('observedRoutes', () {
      test('tracks all observed routes', () {
        parameterizer.parameterize('/a');
        parameterizer.parameterize('/b');
        parameterizer.parameterize('/c');

        expect(parameterizer.observedRoutes, containsAll(['/a', '/b', '/c']));
        expect(parameterizer.observedRoutes, hasLength(3));
      });

      test('returns unmodifiable set', () {
        parameterizer.parameterize('/a');
        expect(
          () => parameterizer.observedRoutes.add('/x'),
          throwsUnsupportedError,
        );
      });
    });

    group('patterns', () {
      test('returns unmodifiable map', () {
        parameterizer.parameterize('/a');
        expect(
          () => (parameterizer.patterns as Map)['x'] = 'y',
          throwsUnsupportedError,
        );
      });
    });

    group('reset', () {
      test('clears all state', () {
        parameterizer.parameterize('/quest/42');
        parameterizer.parameterize('/quest/7');
        parameterizer.reset();

        expect(parameterizer.observedRoutes, isEmpty);
        expect(parameterizer.patterns, isEmpty);
        expect(parameterizer.patternFor('/quest/42'), isNull);
      });
    });

    group('edge cases', () {
      test('empty segments are handled', () {
        // Routes like "/quest/42/" have trailing empty segment
        parameterizer.parameterize('/quest/42/');
        parameterizer.parameterize('/quest/7/');
        final result = parameterizer.patternFor('/quest/42/');
        expect(result, '/quest/:id/');
      });

      test('single segment routes with IDs stay separate without anchor', () {
        parameterizer.parameterize('/42');
        final result = parameterizer.parameterize('/7');
        // No constant anchor segment → treated as separate routes
        expect(result, '/7');
      });
    });
  });
}
