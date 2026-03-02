import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Shade — gesture recording controller
  // ---------------------------------------------------------

  group('Shade', () {
    late Shade shade;

    setUp(() {
      shade = Shade();
    });

    // ---------------------------------------------------------
    // Initial state
    // ---------------------------------------------------------

    test('starts in non-recording state', () {
      expect(shade.isRecording, false);
      expect(shade.currentEventCount, 0);
      expect(shade.elapsed, Duration.zero);
    });

    // ---------------------------------------------------------
    // Recording lifecycle
    // ---------------------------------------------------------

    test('startRecording switches to recording state', () {
      shade.startRecording(
        name: 'test',
        screenSize: const Size(375, 812),
        devicePixelRatio: 3.0,
      );

      expect(shade.isRecording, true);
      expect(shade.currentEventCount, 0);
    });

    test('startRecording ignores duplicate calls', () {
      shade.startRecording(name: 'first', screenSize: const Size(375, 812));
      shade.startRecording(name: 'second', screenSize: const Size(375, 812));

      expect(shade.isRecording, true);
      // Still first session — second call was ignored
    });

    test('stopRecording returns session with recorded events', () {
      shade.startRecording(
        name: 'my_session',
        screenSize: const Size(375, 812),
        devicePixelRatio: 2.0,
      );

      // Record some mock pointer events
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(100, 200)),
      );
      shade.recordPointerEvent(
        const PointerMoveEvent(
          pointer: 1,
          position: Offset(110, 210),
          delta: Offset(10, 10),
        ),
      );
      shade.recordPointerEvent(
        const PointerUpEvent(pointer: 1, position: Offset(110, 210)),
      );

      final session = shade.stopRecording();

      expect(session.name, 'my_session');
      expect(session.eventCount, 3);
      expect(session.screenWidth, 375.0);
      expect(session.screenHeight, 812.0);
      expect(session.devicePixelRatio, 2.0);
      expect(session.imprints[0].type, ImprintType.pointerDown);
      expect(session.imprints[1].type, ImprintType.pointerMove);
      expect(session.imprints[2].type, ImprintType.pointerUp);
      expect(shade.isRecording, false);
    });

    test('stopRecording throws when not recording', () {
      expect(() => shade.stopRecording(), throwsStateError);
    });

    test('cancelRecording discards session without error', () {
      shade.startRecording(name: 'cancelled', screenSize: const Size(375, 812));
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(50, 50)),
      );

      shade.cancelRecording();

      expect(shade.isRecording, false);
      expect(shade.currentEventCount, 0);
    });

    test('cancelRecording does nothing when not recording', () {
      shade.cancelRecording(); // should not throw
      expect(shade.isRecording, false);
    });

    test('generates default session name with counter', () {
      shade.startRecording(screenSize: const Size(375, 812));
      final session1 = shade.stopRecording();
      expect(session1.name, 'session_1');

      shade.startRecording(screenSize: const Size(375, 812));
      final session2 = shade.stopRecording();
      expect(session2.name, 'session_2');
    });

    test('session includes description when provided', () {
      shade.startRecording(
        name: 'flow',
        description: 'Tests login flow',
        screenSize: const Size(375, 812),
      );
      final session = shade.stopRecording();

      expect(session.description, 'Tests login flow');
    });

    // ---------------------------------------------------------
    // Event recording
    // ---------------------------------------------------------

    test('records pointer down events', () {
      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      shade.recordPointerEvent(
        const PointerDownEvent(
          pointer: 1,
          position: Offset(100, 200),
          buttons: 1,
        ),
      );

      expect(shade.currentEventCount, 1);
      final session = shade.stopRecording();
      final imprint = session.imprints.first;

      expect(imprint.type, ImprintType.pointerDown);
      expect(imprint.positionX, 100.0);
      expect(imprint.positionY, 200.0);
      expect(imprint.pointer, 1);
    });

    test('records scroll events with scroll delta', () {
      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      shade.recordPointerEvent(
        const PointerScrollEvent(
          position: Offset(200, 300),
          scrollDelta: Offset(0, 120),
        ),
      );

      final session = shade.stopRecording();
      final imprint = session.imprints.first;

      expect(imprint.type, ImprintType.pointerScroll);
      expect(imprint.scrollDeltaX, 0);
      expect(imprint.scrollDeltaY, 120.0);
    });

    test('ignores pointer events when not recording', () {
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(100, 200)),
      );

      expect(shade.currentEventCount, 0);
    });

    test('records timestamps relative to session start', () {
      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(100, 200)),
      );

      final session = shade.stopRecording();

      // Timestamp should be a small positive duration
      expect(session.imprints.first.timestamp >= Duration.zero, true);
    });

    test('skips PointerEnterEvent and PointerExitEvent', () {
      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      // Enter/Exit events are synthesized — should be skipped
      shade.recordPointerEvent(
        const PointerEnterEvent(position: Offset(100, 200)),
      );
      shade.recordPointerEvent(
        const PointerExitEvent(position: Offset(100, 200)),
      );

      expect(shade.currentEventCount, 0);
    });

    // ---------------------------------------------------------
    // Callbacks
    // ---------------------------------------------------------

    test('calls onRecordingStarted when recording starts', () {
      var called = false;
      shade.onRecordingStarted = () => called = true;

      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      expect(called, true);
    });

    test('calls onRecordingStopped with session', () {
      ShadeSession? result;
      shade.onRecordingStopped = (session) => result = session;

      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      shade.stopRecording();

      expect(result, isNotNull);
      expect(result!.name, 'test');
    });

    test('calls onImprintCaptured for each event', () {
      final captured = <Imprint>[];
      shade.onImprintCaptured = (imprint) => captured.add(imprint);

      shade.startRecording(name: 'test', screenSize: const Size(375, 812));
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(100, 200)),
      );
      shade.recordPointerEvent(
        const PointerUpEvent(pointer: 1, position: Offset(100, 200)),
      );

      expect(captured.length, 2);
      expect(captured[0].type, ImprintType.pointerDown);
      expect(captured[1].type, ImprintType.pointerUp);
    });

    // ---------------------------------------------------------
    // Multiple sessions
    // ---------------------------------------------------------

    test('supports multiple sequential recording sessions', () {
      shade.startRecording(name: 'session_a', screenSize: const Size(375, 812));
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(10, 20)),
      );
      final s1 = shade.stopRecording();

      shade.startRecording(name: 'session_b', screenSize: const Size(375, 812));
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 2, position: Offset(30, 40)),
      );
      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 3, position: Offset(50, 60)),
      );
      final s2 = shade.stopRecording();

      expect(s1.name, 'session_a');
      expect(s1.eventCount, 1);
      expect(s2.name, 'session_b');
      expect(s2.eventCount, 2);
    });

    // ---------------------------------------------------------
    // Text change recording
    // ---------------------------------------------------------

    test('recordTextChange creates textInput imprint', () {
      shade.startRecording(name: 'text', screenSize: const Size(375, 812));
      shade.recordTextChange(
        const TextEditingValue(
          text: 'hello',
          selection: TextSelection.collapsed(offset: 5),
        ),
        fieldId: 'name_field',
      );

      final session = shade.stopRecording();
      expect(session.eventCount, 1);

      final imprint = session.imprints.first;
      expect(imprint.type, ImprintType.textInput);
      expect(imprint.text, 'hello');
      expect(imprint.selectionBase, 5);
      expect(imprint.selectionExtent, 5);
      expect(imprint.fieldId, 'name_field');
    });

    test('recordTextChange with selection range', () {
      shade.startRecording(name: 'sel', screenSize: const Size(375, 812));
      shade.recordTextChange(
        const TextEditingValue(
          text: 'world',
          selection: TextSelection(baseOffset: 0, extentOffset: 5),
          composing: TextRange(start: 0, end: 5),
        ),
      );

      final session = shade.stopRecording();
      final imprint = session.imprints.first;

      expect(imprint.selectionBase, 0);
      expect(imprint.selectionExtent, 5);
      expect(imprint.composingBase, 0);
      expect(imprint.composingExtent, 5);
    });

    test('recordTextChange ignores when not recording', () {
      shade.recordTextChange(const TextEditingValue(text: 'ignored'));
      expect(shade.currentEventCount, 0);
    });

    // ---------------------------------------------------------
    // Text action recording
    // ---------------------------------------------------------

    test('recordTextAction creates textAction imprint', () {
      shade.startRecording(name: 'action', screenSize: const Size(375, 812));
      shade.recordTextAction(TextInputAction.done, fieldId: 'email');

      final session = shade.stopRecording();
      expect(session.eventCount, 1);

      final imprint = session.imprints.first;
      expect(imprint.type, ImprintType.textAction);
      expect(imprint.textInputAction, TextInputAction.done.index);
      expect(imprint.fieldId, 'email');
    });

    test('recordTextAction ignores when not recording', () {
      shade.recordTextAction(TextInputAction.send);
      expect(shade.currentEventCount, 0);
    });

    // ---------------------------------------------------------
    // Mixed event recording
    // ---------------------------------------------------------

    test('records pointer, key, and text events together', () {
      shade.startRecording(name: 'mixed', screenSize: const Size(375, 812));

      shade.recordPointerEvent(
        const PointerDownEvent(pointer: 1, position: Offset(100, 200)),
      );
      shade.recordTextChange(
        const TextEditingValue(text: 'a'),
        fieldId: 'input',
      );
      shade.recordPointerEvent(
        const PointerUpEvent(pointer: 1, position: Offset(100, 200)),
      );
      shade.recordTextAction(TextInputAction.done, fieldId: 'input');

      final session = shade.stopRecording();
      expect(session.eventCount, 4);
      expect(session.imprints[0].type, ImprintType.pointerDown);
      expect(session.imprints[1].type, ImprintType.textInput);
      expect(session.imprints[2].type, ImprintType.pointerUp);
      expect(session.imprints[3].type, ImprintType.textAction);
    });

    // ---------------------------------------------------------
    // Text controller registry
    // ---------------------------------------------------------

    test('registers and retrieves a text controller', () {
      final controller = ShadeTextController(shade: shade, fieldId: 'email');

      expect(shade.getTextController('email'), same(controller));
      expect(shade.textControllers.length, 1);

      controller.dispose();
    });

    test('unregisters controller on dispose', () {
      final controller = ShadeTextController(shade: shade, fieldId: 'name');

      expect(shade.getTextController('name'), isNotNull);
      controller.dispose();
      expect(shade.getTextController('name'), isNull);
      expect(shade.textControllers.isEmpty, true);
    });

    test('does not register controller without fieldId', () {
      final controller = ShadeTextController(shade: shade);

      expect(shade.textControllers.isEmpty, true);
      controller.dispose();
    });

    test('replaces controller with same fieldId', () {
      final c1 = ShadeTextController(shade: shade, fieldId: 'pwd');
      final c2 = ShadeTextController(shade: shade, fieldId: 'pwd');

      expect(shade.getTextController('pwd'), same(c2));
      expect(shade.textControllers.length, 1);

      c1.dispose();
      c2.dispose();
    });

    // ---------------------------------------------------------
    // isReplaying flag
    // ---------------------------------------------------------

    test('isReplaying defaults to false', () {
      expect(shade.isReplaying, false);
    });

    test('isReplaying can be set', () {
      shade.isReplaying = true;
      expect(shade.isReplaying, true);
      shade.isReplaying = false;
    });

    // ---------------------------------------------------------
    // Route recording
    // ---------------------------------------------------------

    test('captures startRoute when getCurrentRoute is set', () {
      shade.getCurrentRoute = () => '/home';
      shade.startRecording(name: 'route', screenSize: const Size(375, 812));
      final session = shade.stopRecording();

      expect(session.startRoute, '/home');
    });

    test('startRoute is null when getCurrentRoute is not set', () {
      shade.startRecording(name: 'no_route', screenSize: const Size(375, 812));
      final session = shade.stopRecording();

      expect(session.startRoute, isNull);
    });

    test('startRoute is null when getCurrentRoute returns null', () {
      shade.getCurrentRoute = () => null;
      shade.startRecording(
        name: 'null_route',
        screenSize: const Size(375, 812),
      );
      final session = shade.stopRecording();

      expect(session.startRoute, isNull);
    });

    test('cancelRecording clears route state', () {
      shade.getCurrentRoute = () => '/settings';
      shade.startRecording(
        name: 'cancel_route',
        screenSize: const Size(375, 812),
      );
      shade.cancelRecording();

      // Start a new session without route callback
      shade.getCurrentRoute = null;
      shade.startRecording(name: 'fresh', screenSize: const Size(375, 812));
      final session = shade.stopRecording();

      expect(session.startRoute, isNull);
    });
  });
}
