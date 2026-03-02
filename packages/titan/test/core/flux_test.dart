import 'dart:async';

import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('Flux — Stream operators', () {
    // -----------------------------------------------------------------------
    // Debounce
    // -----------------------------------------------------------------------

    group('DebouncedState', () {
      test('delays value propagation', () async {
        final source = TitanState<String>('');
        final debounced = source.debounce(const Duration(milliseconds: 50));

        source.value = 'h';
        source.value = 'he';
        source.value = 'hel';
        source.value = 'hell';
        source.value = 'hello';

        // Immediately, debounced still has initial value
        expect(debounced.peek(), '');

        // Wait for debounce to settle
        await Future.delayed(const Duration(milliseconds: 100));

        expect(debounced.peek(), 'hello');

        debounced.dispose();
        source.dispose();
      });

      test('resets timer on each change', () async {
        final source = TitanState<int>(0);
        final debounced = source.debounce(const Duration(milliseconds: 80));

        source.value = 1;
        await Future.delayed(const Duration(milliseconds: 40));

        source.value = 2; // resets the 80ms timer
        await Future.delayed(const Duration(milliseconds: 40));

        // Only 40ms since last change — should NOT have updated yet
        expect(debounced.peek(), 0);

        await Future.delayed(const Duration(milliseconds: 60));

        // Now 100ms since last change — should have updated
        expect(debounced.peek(), 2);

        debounced.dispose();
        source.dispose();
      });

      test('notifies listeners', () async {
        final source = TitanState<int>(0);
        final debounced = source.debounce(const Duration(milliseconds: 30));

        final values = <int>[];
        debounced.listen((v) => values.add(v));

        source.value = 1;
        source.value = 2;
        source.value = 3;

        await Future.delayed(const Duration(milliseconds: 80));

        expect(values, [3]);

        debounced.dispose();
        source.dispose();
      });

      test('throws on direct value set', () {
        final source = TitanState<int>(0);
        final debounced = source.debounce(const Duration(milliseconds: 50));

        expect(() => debounced.value = 5, throwsUnsupportedError);

        debounced.dispose();
        source.dispose();
      });

      test('stops on dispose', () async {
        final source = TitanState<int>(0);
        final debounced = source.debounce(const Duration(milliseconds: 30));

        source.value = 1;
        debounced.dispose();

        await Future.delayed(const Duration(milliseconds: 80));
        // Should not crash
        expect(debounced.isDisposed, isTrue);

        source.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // Throttle
    // -----------------------------------------------------------------------

    group('ThrottledState', () {
      test('limits update frequency', () async {
        final source = TitanState<int>(0);
        final throttled = source.throttle(const Duration(milliseconds: 50));

        source.value = 1;
        source.value = 2;
        source.value = 3;

        // Immediately — first change schedules a timer
        expect(throttled.peek(), 0);

        // Wait for first throttle window
        await Future.delayed(const Duration(milliseconds: 80));

        // Should have the latest value from that window
        expect(throttled.peek(), 3);

        throttled.dispose();
        source.dispose();
      });

      test('allows next update after window', () async {
        final source = TitanState<int>(0);
        final throttled = source.throttle(const Duration(milliseconds: 30));

        source.value = 1;
        await Future.delayed(const Duration(milliseconds: 50));
        expect(throttled.peek(), 1);

        source.value = 2;
        await Future.delayed(const Duration(milliseconds: 50));
        expect(throttled.peek(), 2);

        throttled.dispose();
        source.dispose();
      });

      test('throws on direct value set', () {
        final source = TitanState<int>(0);
        final throttled = source.throttle(const Duration(milliseconds: 50));

        expect(() => throttled.value = 5, throwsUnsupportedError);

        throttled.dispose();
        source.dispose();
      });

      test('stops on dispose', () async {
        final source = TitanState<int>(0);
        final throttled = source.throttle(const Duration(milliseconds: 30));

        source.value = 1;
        throttled.dispose();

        await Future.delayed(const Duration(milliseconds: 80));
        expect(throttled.isDisposed, isTrue);

        source.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // asStream
    // -----------------------------------------------------------------------

    group('asStream', () {
      test('emits values on change', () async {
        final state = TitanState<int>(0);
        final stream = state.asStream();
        final values = <int>[];

        final sub = stream.listen((v) => values.add(v));

        state.value = 1;
        state.value = 2;
        state.value = 3;

        await Future.delayed(const Duration(milliseconds: 10));

        expect(values, [1, 2, 3]);

        await sub.cancel();
        state.dispose();
      });

      test('does not emit initial value', () async {
        final state = TitanState<int>(42);
        final stream = state.asStream();
        final values = <int>[];

        final sub = stream.listen((v) => values.add(v));
        await Future.delayed(const Duration(milliseconds: 10));

        expect(values, isEmpty);

        await sub.cancel();
        state.dispose();
      });

      test('stops after cancel', () async {
        final state = TitanState<int>(0);
        final stream = state.asStream();
        final values = <int>[];

        final sub = stream.listen((v) => values.add(v));
        state.value = 1;
        await sub.cancel();

        state.value = 2;
        await Future.delayed(const Duration(milliseconds: 10));

        expect(values, [1]);
        state.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // onChange
    // -----------------------------------------------------------------------

    group('onChange', () {
      test('emits on every ReactiveNode change', () async {
        final state = TitanState<int>(0);
        final changes = <void>[];

        final sub = state.onChange.listen((_) => changes.add(null));

        state.value = 1;
        state.value = 2;

        await Future.delayed(const Duration(milliseconds: 10));
        expect(changes.length, 2);

        await sub.cancel();
        state.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // TitanState.stream getter
    // -----------------------------------------------------------------------

    group('TitanState.stream', () {
      test('is equivalent to asStream()', () async {
        final state = TitanState<int>(0);
        final values = <int>[];

        final sub = state.stream.listen((v) => values.add(v));

        state.value = 1;
        state.value = 2;
        await Future.delayed(const Duration(milliseconds: 10));

        expect(values, [1, 2]);

        await sub.cancel();
        state.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // TitanComputed.asStream / stream
    // -----------------------------------------------------------------------

    group('TitanComputed.asStream', () {
      test('emits on recomputation', () async {
        final a = TitanState(1);
        final b = TitanState(2);
        final sum = TitanComputed(() => a.value + b.value);
        sum.value; // force initial

        final values = <int>[];
        final sub = sum.asStream().listen((v) => values.add(v));

        a.value = 10;
        await Future.delayed(const Duration(milliseconds: 10));

        b.value = 20;
        await Future.delayed(const Duration(milliseconds: 10));

        expect(values, [12, 30]);

        await sub.cancel();
        sum.dispose();
        a.dispose();
        b.dispose();
      });

      test('does not emit when computed value stays equal', () async {
        final state = TitanState(0);
        final clamped = TitanComputed(() => state.value.clamp(0, 10));
        clamped.value; // force initial

        final values = <int>[];
        final sub = clamped.asStream().listen((v) => values.add(v));

        state.value = 5;
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, [5]);

        // Still clamped to 10
        state.value = 100;
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, [5, 10]);

        // 200 clamps to 10 — same as before, no emission
        state.value = 200;
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, [5, 10]);

        await sub.cancel();
        clamped.dispose();
        state.dispose();
      });

      test('stops after cancel', () async {
        final state = TitanState(0);
        final computed = TitanComputed(() => state.value * 2);
        computed.value; // force initial

        final values = <int>[];
        final sub = computed.asStream().listen((v) => values.add(v));

        state.value = 1;
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, [2]);

        await sub.cancel();

        state.value = 5;
        await Future.delayed(const Duration(milliseconds: 10));
        expect(values, [2]); // no new emissions

        computed.dispose();
        state.dispose();
      });
    });

    group('TitanComputed.stream', () {
      test('is equivalent to asStream()', () async {
        final state = TitanState(0);
        final computed = TitanComputed(() => state.value + 1);
        computed.value; // force initial

        final values = <int>[];
        final sub = computed.stream.listen((v) => values.add(v));

        state.value = 10;
        await Future.delayed(const Duration(milliseconds: 10));

        expect(values, [11]);

        await sub.cancel();
        computed.dispose();
        state.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // TitanState.map / where
    // -----------------------------------------------------------------------

    group('TitanState.map', () {
      test('creates a Derived from a mapped Core', () {
        final count = TitanState(3);
        final label = count.map((v) => 'Count: $v');

        expect(label.value, 'Count: 3');

        count.value = 10;
        expect(label.value, 'Count: 10');

        label.dispose();
        count.dispose();
      });
    });

    group('TitanState.where', () {
      test('creates a Derived<bool> from a predicate', () {
        final count = TitanState(3);
        final isHigh = count.where((v) => v > 5);

        expect(isHigh.value, false);

        count.value = 10;
        expect(isHigh.value, true);

        isHigh.dispose();
        count.dispose();
      });
    });

    // -----------------------------------------------------------------------
    // TitanComputed.map / where
    // -----------------------------------------------------------------------

    group('TitanComputed.map', () {
      test('chains transformation on a Derived', () {
        final a = TitanState(2);
        final b = TitanState(3);
        final sum = TitanComputed(() => a.value + b.value);
        final label = sum.map((v) => 'Sum=$v');

        expect(label.value, 'Sum=5');

        a.value = 10;
        expect(label.value, 'Sum=13');

        label.dispose();
        sum.dispose();
        a.dispose();
        b.dispose();
      });
    });

    group('TitanComputed.where', () {
      test('creates a predicate Derived from a Derived', () {
        final count = TitanState(0);
        final doubled = TitanComputed(() => count.value * 2);
        final isHigh = doubled.where((v) => v > 10);

        expect(isHigh.value, false);

        count.value = 6;
        expect(isHigh.value, true);

        isHigh.dispose();
        doubled.dispose();
        count.dispose();
      });
    });
  });
}
