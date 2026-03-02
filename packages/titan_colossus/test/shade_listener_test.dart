import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // ShadeListener — global gesture capture & indicator overlay
  // ---------------------------------------------------------

  group('ShadeListener', () {
    late Shade shade;

    setUp(() {
      shade = Shade();
    });

    // ---------------------------------------------------------
    // Basic rendering
    // ---------------------------------------------------------

    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(shade: shade, child: const Text('Hello')),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('passes pointer events to Shade', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(
            shade: shade,
            child: const SizedBox(width: 200, height: 200),
          ),
        ),
      );

      shade.startRecording(name: 'test', screenSize: const Size(375, 812));

      await tester.tapAt(const Offset(100, 100));
      await tester.pump();

      // pointerDown + pointerUp = 2+ events
      expect(shade.currentEventCount, greaterThanOrEqualTo(2));

      shade.stopRecording();
    });

    // ---------------------------------------------------------
    // Recording indicator
    // ---------------------------------------------------------

    testWidgets('shows red recording indicator when Shade is recording', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(shade: shade, child: const Text('app')),
        ),
      );

      // No indicator initially
      expect(find.text('0 events'), findsNothing);
      expect(find.byIcon(Icons.fiber_manual_record), findsNothing);

      // Start recording
      shade.startRecording(name: 'test', screenSize: const Size(375, 812));

      // Wait for indicator polling (500ms interval)
      await tester.pump(const Duration(milliseconds: 600));

      // Red recording pill should appear
      expect(find.text('0 events'), findsOneWidget);
      expect(find.byIcon(Icons.fiber_manual_record), findsOneWidget);

      shade.stopRecording();
    });

    testWidgets('shows teal replaying indicator when Shade is replaying', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(shade: shade, child: const Text('app')),
        ),
      );

      // Simulate replaying state
      shade.isReplaying = true;

      // Wait for indicator polling
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Replaying...'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);

      shade.isReplaying = false;
    });

    testWidgets('hides indicator when showIndicator is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(
            shade: shade,
            showIndicator: false,
            child: const Text('app'),
          ),
        ),
      );

      shade.startRecording(name: 'test', screenSize: const Size(375, 812));

      await tester.pump(const Duration(milliseconds: 600));

      // No indicator should appear when disabled
      expect(find.text('0 events'), findsNothing);
      expect(find.byIcon(Icons.fiber_manual_record), findsNothing);

      shade.stopRecording();
    });

    testWidgets('no indicator when idle (not recording or replaying)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(shade: shade, child: const Text('app')),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));

      // No indicators should be visible when idle
      expect(find.byIcon(Icons.fiber_manual_record), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    // ---------------------------------------------------------
    // Indicator wrapping (IgnorePointer)
    // ---------------------------------------------------------

    testWidgets('indicator is wrapped in IgnorePointer', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(shade: shade, child: const Text('app')),
        ),
      );

      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      await tester.pump(const Duration(milliseconds: 600));

      // Verify an actively-ignoring IgnorePointer is in the tree
      final ignoring = tester.widgetList<IgnorePointer>(
        find.byType(IgnorePointer),
      );
      final activelyIgnoring = ignoring.where((w) => w.ignoring).toList();
      expect(activelyIgnoring, isNotEmpty);

      shade.stopRecording();
    });

    // ---------------------------------------------------------
    // Lifecycle
    // ---------------------------------------------------------

    testWidgets('disposes indicator timer cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(shade: shade, child: const Text('app')),
        ),
      );

      // Navigate away to trigger dispose
      await tester.pumpWidget(const MaterialApp(home: Text('other')));

      // Should not throw
      expect(find.text('other'), findsOneWidget);
    });

    testWidgets('updates indicator polling when showIndicator changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(
            shade: shade,
            showIndicator: false,
            child: const Text('app'),
          ),
        ),
      );

      shade.startRecording(name: 'test', screenSize: const Size(375, 812));

      // No indicator with showIndicator: false
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('0 events'), findsNothing);

      // Rebuild with showIndicator: true
      await tester.pumpWidget(
        MaterialApp(
          home: ShadeListener(
            shade: shade,
            showIndicator: true,
            child: const Text('app'),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 600));
      expect(find.textContaining('events'), findsOneWidget);

      shade.stopRecording();
    });
  });
}
