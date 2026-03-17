// End-to-end test replicating the SplitDa AmountKeypad structure.
// Verifies that TableauCapture captures all keypad glyphs and
// Scry.observe correctly classifies them as buttons.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/src/recording/tableau_capture.dart';
import 'package:titan_colossus/src/testing/scry.dart';

void main() {
  const scry = Scry();

  group('Keypad detection — SplitDa AmountKeypad structure', () {
    // Build a minimal replica of SplitDa's AmountKeypad _buildKey method.
    Widget buildKey(String key, {bool isIcon = false, IconData? iconData}) {
      String semanticLabel(String k) {
        return switch (k) {
          'backspace' => 'Delete last digit',
          '+' => 'Add',
          '-' => 'Subtract',
          '.' => 'Decimal point',
          _ => k,
        };
      }

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Semantics(
            label: semanticLabel(key),
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('keypad_$key'),
                onTap: () {},
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: isIcon
                        ? Icon(iconData ?? Icons.backspace_outlined, size: 26)
                        : Text(key, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildKeypad() {
      return MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // Operator row
              Row(
                children: [
                  buildKey('-', isIcon: true, iconData: Icons.remove_rounded),
                  buildKey('+', isIcon: true, iconData: Icons.add_rounded),
                ],
              ),
              // Number rows
              Row(children: [buildKey('1'), buildKey('2'), buildKey('3')]),
              Row(children: [buildKey('4'), buildKey('5'), buildKey('6')]),
              Row(children: [buildKey('7'), buildKey('8'), buildKey('9')]),
              Row(
                children: [
                  buildKey('.'),
                  buildKey('0'),
                  buildKey('backspace', isIcon: true),
                ],
              ),
              // Done button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Semantics(
                    label: 'Done entering amount',
                    button: true,
                    child: FilledButton(
                      key: const ValueKey('keypad_done'),
                      onPressed: () {},
                      child: const Text('Done'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('TableauCapture captures all 16 keypad elements', (
      tester,
    ) async {
      await tester.pumpWidget(buildKeypad());

      final tableau = await TableauCapture.capture(index: 0);

      // All InkWell buttons (10 digits + dot + 3 icons = 14)
      final inkWells = tableau.glyphs
          .where((g) => g.widgetType == 'InkWell')
          .toList();
      expect(inkWells.length, 14);

      // All must be interactive
      expect(inkWells.every((g) => g.isInteractive), isTrue);

      // Digit buttons have their digit as label
      for (final d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        final digit = inkWells.firstWhere(
          (g) => g.key == 'keypad_$d',
          orElse: () => throw StateError('Missing keypad digit $d'),
        );
        expect(digit.label, d, reason: 'Digit $d should have label "$d"');
      }

      // Dot button — uses child Text "." (not icon, so visible text preferred)
      final dot = inkWells.firstWhere((g) => g.key == 'keypad_.');
      expect(dot.label, '.');

      // Operator buttons should use Semantics ancestor label
      final add = inkWells.firstWhere((g) => g.key == 'keypad_+');
      expect(add.label, 'Add');

      final subtract = inkWells.firstWhere((g) => g.key == 'keypad_-');
      expect(subtract.label, 'Subtract');

      final backspace = inkWells.firstWhere((g) => g.key == 'keypad_backspace');
      expect(backspace.label, 'Delete last digit');

      // Done button (FilledButton)
      final done = tableau.glyphs.firstWhere(
        (g) => g.widgetType == 'FilledButton',
      );
      expect(done.label, 'Done');
      expect(done.isInteractive, isTrue);
    });

    testWidgets('Scry.observe classifies all keypad buttons correctly', (
      tester,
    ) async {
      await tester.pumpWidget(buildKeypad());

      final tableau = await TableauCapture.capture(index: 0);

      // Convert glyphs to JSON maps as Scry.observe expects
      final glyphMaps = tableau.glyphs.map((g) => g.toMap()).toList();

      final gaze = scry.observe(glyphMaps);

      // All 10 digit keys + dot + Add + Subtract + Delete + Done = 15
      // (dot label "Decimal point" is merged with content "." via dedup)
      final keypadButtons = gaze.buttons.where(
        (b) =>
            b.key != null && b.key!.startsWith('keypad_') ||
            [
              '0',
              '1',
              '2',
              '3',
              '4',
              '5',
              '6',
              '7',
              '8',
              '9',
            ].contains(b.label) ||
            b.label == 'Done' ||
            b.label == 'Add' ||
            b.label == 'Subtract' ||
            b.label == 'Delete last digit' ||
            b.label == 'Decimal point' ||
            b.label == '.',
      );

      // At minimum we expect digits + operators + Done
      expect(
        keypadButtons.length,
        greaterThanOrEqualTo(14),
        reason: 'All keypad buttons should be detected by Scry',
      );

      // Digits are buttons (not content)
      for (final d in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']) {
        final digitButton = gaze.buttons.where((b) => b.label == d);
        expect(
          digitButton,
          isNotEmpty,
          reason: 'Digit "$d" should be classified as a button',
        );
      }

      // Operators are buttons
      expect(
        gaze.buttons.where((b) => b.label == 'Add'),
        isNotEmpty,
        reason: 'Add operator should be a button',
      );
      expect(
        gaze.buttons.where((b) => b.label == 'Subtract'),
        isNotEmpty,
        reason: 'Subtract operator should be a button',
      );
      expect(
        gaze.buttons.where((b) => b.label == 'Delete last digit'),
        isNotEmpty,
        reason: 'Backspace should be a button',
      );

      // Done is a button
      expect(
        gaze.buttons.where((b) => b.label == 'Done'),
        isNotEmpty,
        reason: 'Done should be a button',
      );
    });

    testWidgets('formatGaze includes keypad buttons in Buttons section', (
      tester,
    ) async {
      await tester.pumpWidget(buildKeypad());

      final tableau = await TableauCapture.capture(index: 0);
      final glyphMaps = tableau.glyphs.map((g) => g.toMap()).toList();
      final gaze = scry.observe(glyphMaps);
      final md = scry.formatGaze(gaze);

      // Buttons section should mention digit buttons
      expect(md, contains('🔘'));
      expect(md, contains('Done'));
      expect(md, contains('Add'));
      expect(md, contains('Subtract'));
    });
  });
}
