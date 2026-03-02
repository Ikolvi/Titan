import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // ShadeTextController — auto-tracking TextEditingController
  // ---------------------------------------------------------

  group('ShadeTextController', () {
    late Shade shade;

    setUp(() {
      shade = Shade();
    });

    test('creates with shade and optional fieldId', () {
      final controller = ShadeTextController(shade: shade, fieldId: 'email');
      expect(controller.fieldId, 'email');
      // Should be auto-registered
      expect(shade.getTextController('email'), same(controller));
      controller.dispose();
    });

    test('creates without fieldId', () {
      final controller = ShadeTextController(shade: shade);
      expect(controller.fieldId, isNull);
      // Should NOT be registered
      expect(shade.textControllers.isEmpty, true);
      controller.dispose();
    });

    test('records text changes when shade is recording', () {
      shade.startRecording(name: 'text_test', screenSize: const Size(375, 812));

      final controller = ShadeTextController(shade: shade, fieldId: 'username');

      controller.text = 'hello';
      expect(shade.currentEventCount, 1);

      controller.text = 'hello world';
      expect(shade.currentEventCount, 2);

      final session = shade.stopRecording();
      expect(session.imprints[0].type, ImprintType.textInput);
      expect(session.imprints[0].text, 'hello');
      expect(session.imprints[0].fieldId, 'username');
      expect(session.imprints[1].text, 'hello world');

      controller.dispose();
    });

    test('does not record when shade is not recording', () {
      final controller = ShadeTextController(shade: shade);
      controller.text = 'test';

      // No recording active, so event count stays at 0
      expect(shade.currentEventCount, 0);
      controller.dispose();
    });

    test('ignores cursor-only changes', () {
      shade.startRecording(name: 'cursor', screenSize: const Size(375, 812));

      final controller = ShadeTextController(shade: shade);
      controller.text = 'hello';
      expect(shade.currentEventCount, 1);

      // Select text (same text, different selection)
      controller.value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection(baseOffset: 0, extentOffset: 5),
      );
      // Should NOT record since text didn't change
      expect(shade.currentEventCount, 1);

      shade.stopRecording();
      controller.dispose();
    });

    test('setTextSilently does not record', () {
      shade.startRecording(name: 'silent', screenSize: const Size(375, 812));

      final controller = ShadeTextController(shade: shade);
      controller.setTextSilently('injected');

      expect(shade.currentEventCount, 0);
      expect(controller.text, 'injected');

      shade.stopRecording();
      controller.dispose();
    });

    test('setValueSilently does not record', () {
      shade.startRecording(name: 'silent_v', screenSize: const Size(375, 812));

      final controller = ShadeTextController(shade: shade);
      controller.setValueSilently(const TextEditingValue(text: 'injected'));

      expect(shade.currentEventCount, 0);
      expect(controller.text, 'injected');

      shade.stopRecording();
      controller.dispose();
    });

    test('records after setTextSilently followed by real change', () {
      shade.startRecording(name: 'mixed', screenSize: const Size(375, 812));

      final controller = ShadeTextController(shade: shade);
      controller.setTextSilently('base');
      expect(shade.currentEventCount, 0);

      controller.text = 'base updated';
      expect(shade.currentEventCount, 1);

      shade.stopRecording();
      controller.dispose();
    });

    test('dispose removes listener cleanly', () {
      shade.startRecording(name: 'dispose', screenSize: const Size(375, 812));

      final controller = ShadeTextController(shade: shade, fieldId: 'test');
      controller.text = 'before';
      expect(shade.currentEventCount, 1);

      // Should unregister from shade
      expect(shade.getTextController('test'), same(controller));
      controller.dispose();
      expect(shade.getTextController('test'), isNull);

      // After dispose, no more recordings should happen
      shade.stopRecording();
    });

    test('auto-registers with shade on creation', () {
      final c1 = ShadeTextController(shade: shade, fieldId: 'f1');
      final c2 = ShadeTextController(shade: shade, fieldId: 'f2');

      expect(shade.textControllers.length, 2);
      expect(shade.getTextController('f1'), same(c1));
      expect(shade.getTextController('f2'), same(c2));

      c1.dispose();
      expect(shade.textControllers.length, 1);
      expect(shade.getTextController('f1'), isNull);

      c2.dispose();
      expect(shade.textControllers.isEmpty, true);
    });
  });
}
