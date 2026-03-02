import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_bastion/titan_bastion.dart';

class _CounterPillar extends Pillar {
  late final count = core(0);
  void increment() => strike(() => count.value++);
}

void main() {
  tearDown(() => Titan.reset());

  group('AnimatedVestige', () {
    testWidgets('renders with Pillar from Beacon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [_CounterPillar.new],
            child: AnimatedVestige<_CounterPillar>(
              builder: (context, counter, animation) =>
                  Text('Count: ${counter.count.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('rebuilds when Core changes', (tester) async {
      late _CounterPillar pillar;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: AnimatedVestige<_CounterPillar>(
              builder: (context, counter, animation) =>
                  Text('Count: ${counter.count.value}'),
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      pillar.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
    });

    testWidgets('provides animation to builder', (tester) async {
      late _CounterPillar pillar;
      late Animation<double> capturedAnimation;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: AnimatedVestige<_CounterPillar>(
              duration: const Duration(milliseconds: 200),
              builder: (context, counter, animation) {
                capturedAnimation = animation;
                return Text('Count: ${counter.count.value}');
              },
            ),
          ),
        ),
      );

      // Initially at 1.0 (completed)
      expect(capturedAnimation.value, 1.0);

      // Trigger state change
      pillar.increment();
      await tester.pump();

      // Animation should start from 0.0
      expect(capturedAnimation.value, closeTo(0.0, 0.01));

      // Advance animation
      await tester.pump(const Duration(milliseconds: 200));
      expect(capturedAnimation.value, closeTo(1.0, 0.01));
    });

    testWidgets('finds Pillar from Titan global registry', (tester) async {
      final pillar = _CounterPillar();
      Titan.put(pillar);

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedVestige<_CounterPillar>(
            builder: (context, counter, animation) =>
                Text('Count: ${counter.count.value}'),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);
    });

    testWidgets('animateWhen prevents animation when false', (tester) async {
      late _CounterPillar pillar;
      late Animation<double> capturedAnimation;

      await tester.pumpWidget(
        MaterialApp(
          home: Beacon(
            pillars: [
              () {
                pillar = _CounterPillar();
                return pillar;
              },
            ],
            child: AnimatedVestige<_CounterPillar>(
              duration: const Duration(milliseconds: 200),
              animateWhen: (counter) => counter.count.value > 5,
              builder: (context, counter, animation) {
                capturedAnimation = animation;
                return Text('Count: ${counter.count.value}');
              },
            ),
          ),
        ),
      );

      // Trigger state change (count = 1, not > 5 → no animation)
      pillar.increment();
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
      // Animation should still be at 1.0 (not triggered)
      expect(capturedAnimation.value, 1.0);
    });
  });
}
