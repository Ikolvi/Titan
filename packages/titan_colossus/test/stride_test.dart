import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Stride — page load timing
  // ---------------------------------------------------------

  group('Stride', () {
    late Stride stride;

    setUp(() {
      stride = Stride();
    });

    // ---------------------------------------------------------
    // Initial state
    // ---------------------------------------------------------

    test('starts with empty history', () {
      expect(stride.history, isEmpty);
      expect(stride.lastPageLoad, isNull);
      expect(stride.avgPageLoad, Duration.zero);
    });

    // ---------------------------------------------------------
    // Manual recording
    // ---------------------------------------------------------

    test('records a page load mark', () {
      stride.record('/home', const Duration(milliseconds: 150));

      expect(stride.history, hasLength(1));
      expect(stride.lastPageLoad, isNotNull);
      expect(stride.lastPageLoad!.path, '/home');
      expect(stride.lastPageLoad!.duration.inMilliseconds, 150);
    });

    test('records with pattern', () {
      stride.record(
        '/quest/42',
        const Duration(milliseconds: 200),
        pattern: '/quest/:id',
      );

      expect(stride.lastPageLoad!.pattern, '/quest/:id');
    });

    test('computes average page load duration', () {
      stride.record('/page1', const Duration(milliseconds: 100));
      stride.record('/page2', const Duration(milliseconds: 300));

      expect(stride.avgPageLoad.inMilliseconds, 200);
    });

    // ---------------------------------------------------------
    // History bounds
    // ---------------------------------------------------------

    test('respects maxHistory limit', () {
      final bounded = Stride(maxHistory: 5);

      for (var i = 0; i < 10; i++) {
        bounded.record('/page$i', const Duration(milliseconds: 100));
      }

      expect(bounded.history, hasLength(5));
    });

    // ---------------------------------------------------------
    // Callback
    // ---------------------------------------------------------

    test('calls onPageLoad when a page is recorded', () {
      PageLoadMark? received;
      stride.onPageLoad = (mark) => received = mark;

      stride.record('/home', const Duration(milliseconds: 150));

      expect(received, isNotNull);
      expect(received!.path, '/home');
    });

    // ---------------------------------------------------------
    // Reset
    // ---------------------------------------------------------

    test('reset clears history and metrics', () {
      stride.record('/home', const Duration(milliseconds: 150));

      stride.reset();

      expect(stride.history, isEmpty);
      expect(stride.lastPageLoad, isNull);
      expect(stride.avgPageLoad, Duration.zero);
    });
  });
}
