import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:titan/titan.dart';

import '../widgets/shade_text_controller.dart';
import 'imprint.dart';

// ---------------------------------------------------------------------------
// Shade — Gesture Recording Controller
// ---------------------------------------------------------------------------

/// **Shade** — the Colossus's shadow that records user interactions.
///
/// Shade silently captures every tap, scroll, drag, and swipe during
/// a recording session, preserving them as [Imprint]s in a
/// [ShadeSession]. The session can then be replayed by [Phantom] to
/// reproduce the exact interaction sequence while [Colossus] measures
/// performance.
///
/// ## Why "Shade"?
///
/// A shade follows every movement, recording silently without
/// interfering. Like the shadow of the Colossus that stretches across
/// the harbor, Shade follows the user's every gesture, faithfully
/// preserving their journey.
///
/// ## Usage
///
/// ```dart
/// final shade = Shade();
///
/// // Start recording
/// shade.startRecording(name: 'checkout_flow');
///
/// // ... user interacts with the app ...
///
/// // Stop and get the session
/// final session = shade.stopRecording();
/// print('Recorded ${session.eventCount} events');
///
/// // Save for later replay
/// final json = session.toJson();
/// ```
///
/// ## Integration with ShadeListener
///
/// Wrap your app with [ShadeListener] to automatically capture all
/// pointer events and feed them to [Shade]:
///
/// ```dart
/// ShadeListener(
///   shade: shade,
///   child: MaterialApp(...),
/// )
/// ```
class Shade {
  final List<Imprint> _imprints = [];
  DateTime? _recordingStart;
  String? _sessionName;
  String? _sessionDescription;
  int _sessionCounter = 0;

  // Screen metadata captured at recording start
  double _screenWidth = 0;
  double _screenHeight = 0;
  double _devicePixelRatio = 1;
  String? _startRoute;

  /// Reactive [Core] tracking the recording state.
  ///
  /// [ShadeListener] listens to this for immediate UI updates
  /// instead of polling.
  final Core<bool> isRecordingCore = Core(false);

  /// Whether Shade is currently recording events.
  bool get isRecording => isRecordingCore.peek();

  /// Reactive [Core] tracking the replay state.
  ///
  /// [ShadeListener] listens to this for immediate UI updates
  /// instead of polling.
  final Core<bool> isReplayingCore = Core(false);

  /// Whether the Phantom is currently replaying through this Shade.
  ///
  /// When `true`, [ShadeTextController]s should suppress recording
  /// and [ShadeListener] should avoid capturing duplicate events.
  bool get isReplaying => isReplayingCore.peek();
  set isReplaying(bool value) => isReplayingCore.value = value;

  /// Number of events recorded in the current session.
  int get currentEventCount => _imprints.length;

  /// The elapsed time since recording started.
  ///
  /// Returns [Duration.zero] if not recording.
  Duration get elapsed {
    if (_recordingStart == null) return Duration.zero;
    return DateTime.now().difference(_recordingStart!);
  }

  /// Called when recording starts. Useful for UI indicators.
  void Function()? onRecordingStarted;

  /// Called when recording stops. Receives the completed session.
  void Function(ShadeSession session)? onRecordingStopped;

  /// Called when an imprint is captured during recording.
  void Function(Imprint imprint)? onImprintCaptured;

  /// Optional callback to get the current route path.
  ///
  /// When set, [startRecording] captures the route into the session
  /// metadata so [Phantom] can verify the correct page before replay.
  ///
  /// ```dart
  /// shade.getCurrentRoute = () => Atlas.instance.currentRoute;
  /// ```
  String? Function()? getCurrentRoute;

  // -----------------------------------------------------------------------
  // Text controller registry
  // -----------------------------------------------------------------------

  final Map<String, ShadeTextController> _textControllers = {};

  /// Register a [ShadeTextController] for direct replay targeting.
  ///
  /// Called automatically by [ShadeTextController] in its constructor
  /// when a [fieldId] is provided.
  void registerTextController(String fieldId, ShadeTextController controller) {
    _textControllers[fieldId] = controller;
  }

  /// Unregister a [ShadeTextController].
  ///
  /// Called automatically by [ShadeTextController.dispose].
  void unregisterTextController(String fieldId) {
    _textControllers.remove(fieldId);
  }

  /// Get a registered [ShadeTextController] by field ID.
  ///
  /// Returns `null` if no controller is registered for the given ID.
  ShadeTextController? getTextController(String fieldId) =>
      _textControllers[fieldId];

  /// All registered text controllers, keyed by field ID.
  Map<String, ShadeTextController> get textControllers =>
      Map.unmodifiable(_textControllers);

  // -----------------------------------------------------------------------
  // Recording lifecycle
  // -----------------------------------------------------------------------

  /// Start recording user interactions.
  ///
  /// Captures pointer events until [stopRecording] is called.
  /// Provide a [name] for the session (defaults to `'session_N'`).
  ///
  /// The [screenSize] and [devicePixelRatio] are stored in the session
  /// metadata for replay normalization. If omitted, they default to
  /// the current window metrics.
  ///
  /// ```dart
  /// shade.startRecording(
  ///   name: 'login_flow',
  ///   description: 'Tests the login → dashboard navigation',
  /// );
  /// ```
  void startRecording({
    String? name,
    String? description,
    Size? screenSize,
    double? devicePixelRatio,
  }) {
    if (isRecordingCore.peek()) return;

    _sessionCounter++;
    _sessionName = name ?? 'session_$_sessionCounter';
    _sessionDescription = description;
    _imprints.clear();
    _recordingStart = DateTime.now();
    isRecordingCore.value = true;

    // Capture screen dimensions
    final view = PlatformDispatcher.instance.views.first;
    final logicalSize =
        screenSize ?? (view.physicalSize / view.devicePixelRatio);
    _screenWidth = logicalSize.width;
    _screenHeight = logicalSize.height;
    _devicePixelRatio = devicePixelRatio ?? view.devicePixelRatio;

    // Capture the current route for replay safety
    _startRoute = getCurrentRoute?.call();

    onRecordingStarted?.call();
  }

  /// Stop recording and return the completed [ShadeSession].
  ///
  /// Returns the session containing all recorded [Imprint]s.
  /// Throws [StateError] if not currently recording.
  ///
  /// ```dart
  /// final session = shade.stopRecording();
  /// print('Captured ${session.eventCount} events in ${session.duration}');
  /// ```
  ShadeSession stopRecording() {
    if (!isRecordingCore.peek()) {
      throw StateError('Shade is not recording. Call startRecording() first.');
    }

    isRecordingCore.value = false;
    final duration = DateTime.now().difference(_recordingStart!);

    final session = ShadeSession(
      id: '${_sessionName}_${_recordingStart!.millisecondsSinceEpoch}',
      name: _sessionName!,
      recordedAt: _recordingStart!,
      duration: duration,
      screenWidth: _screenWidth,
      screenHeight: _screenHeight,
      devicePixelRatio: _devicePixelRatio,
      imprints: List.of(_imprints),
      description: _sessionDescription,
      startRoute: _startRoute,
    );

    _imprints.clear();
    _recordingStart = null;
    _sessionName = null;
    _sessionDescription = null;
    _startRoute = null;

    onRecordingStopped?.call(session);
    return session;
  }

  /// Cancel the current recording without producing a session.
  void cancelRecording() {
    if (!isRecordingCore.peek()) return;

    isRecordingCore.value = false;
    _imprints.clear();
    _recordingStart = null;
    _sessionName = null;
    _sessionDescription = null;
    _startRoute = null;
  }

  // -----------------------------------------------------------------------
  // Event capture
  // -----------------------------------------------------------------------

  /// Record a pointer event as an [Imprint].
  ///
  /// Called by [ShadeListener] when a pointer event is detected.
  /// Only records while [isRecording] is true.
  void recordPointerEvent(PointerEvent event) {
    if (!isRecordingCore.peek()) return;

    final type = _classifyEvent(event);
    if (type == null) return;

    final timeSinceStart = DateTime.now().difference(_recordingStart!);

    final imprint = Imprint(
      type: type,
      positionX: event.position.dx,
      positionY: event.position.dy,
      timestamp: timeSinceStart,
      pointer: event.pointer,
      deviceKind: event.kind.index,
      buttons: event.buttons,
      deltaX: event.delta.dx,
      deltaY: event.delta.dy,
      scrollDeltaX: event is PointerScrollEvent ? event.scrollDelta.dx : 0,
      scrollDeltaY: event is PointerScrollEvent ? event.scrollDelta.dy : 0,
      pressure: event.pressure,
    );

    _imprints.add(imprint);
    onImprintCaptured?.call(imprint);
  }

  /// Classifies a [PointerEvent] into an [ImprintType].
  ///
  /// Returns `null` for event types we don't record (enter/exit
  /// are synthesized from move/hover and don't need recording).
  ImprintType? _classifyEvent(PointerEvent event) {
    return switch (event) {
      PointerDownEvent() => ImprintType.pointerDown,
      PointerMoveEvent() => ImprintType.pointerMove,
      PointerUpEvent() => ImprintType.pointerUp,
      PointerCancelEvent() => ImprintType.pointerCancel,
      PointerHoverEvent() => ImprintType.pointerHover,
      PointerScrollEvent() => ImprintType.pointerScroll,
      PointerScrollInertiaCancelEvent() =>
        ImprintType.pointerScrollInertiaCancel,
      PointerAddedEvent() => ImprintType.pointerAdded,
      PointerRemovedEvent() => ImprintType.pointerRemoved,
      PointerPanZoomStartEvent() => ImprintType.pointerPanZoomStart,
      PointerPanZoomUpdateEvent() => ImprintType.pointerPanZoomUpdate,
      PointerPanZoomEndEvent() => ImprintType.pointerPanZoomEnd,
      _ => null, // Skip PointerEnterEvent/PointerExitEvent (synthesized)
    };
  }

  // -----------------------------------------------------------------------
  // Key event capture
  // -----------------------------------------------------------------------

  bool _keyHandlerRegistered = false;

  /// Registers a keyboard event handler to capture key events.
  ///
  /// Called automatically by [ShadeListener] when it mounts.
  /// You can also call this manually if not using [ShadeListener].
  void registerKeyboardHandler() {
    if (_keyHandlerRegistered) return;
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    _keyHandlerRegistered = true;
  }

  /// Removes the keyboard event handler.
  ///
  /// Called automatically by [ShadeListener] when it unmounts.
  void unregisterKeyboardHandler() {
    if (!_keyHandlerRegistered) return;
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _keyHandlerRegistered = false;
  }

  /// Internal handler for [HardwareKeyboard] events.
  bool _onKeyEvent(KeyEvent event) {
    if (!isRecordingCore.peek()) return false;

    final type = switch (event) {
      KeyDownEvent() => ImprintType.keyDown,
      KeyUpEvent() => ImprintType.keyUp,
      KeyRepeatEvent() => ImprintType.keyRepeat,
      _ => null,
    };

    if (type == null) return false;

    final timeSinceStart = DateTime.now().difference(_recordingStart!);

    final imprint = Imprint(
      type: type,
      positionX: 0,
      positionY: 0,
      timestamp: timeSinceStart,
      keyId: event.logicalKey.keyId,
      physicalKey: event.physicalKey.usbHidUsage,
      character: event.character,
    );

    _imprints.add(imprint);
    onImprintCaptured?.call(imprint);

    return false; // Don't consume — let widgets process normally
  }

  // -----------------------------------------------------------------------
  // Text input capture
  // -----------------------------------------------------------------------

  /// Record a text editing state change.
  ///
  /// Called by [ShadeTextController] when the text or cursor
  /// position changes. Associate the event with a [fieldId] to
  /// track multiple text fields independently.
  ///
  /// ```dart
  /// shade.recordTextChange(
  ///   controller.value,
  ///   fieldId: 'hero_name',
  /// );
  /// ```
  void recordTextChange(TextEditingValue value, {String? fieldId}) {
    if (!isRecordingCore.peek()) return;

    final timeSinceStart = DateTime.now().difference(_recordingStart!);

    final imprint = Imprint(
      type: ImprintType.textInput,
      positionX: 0,
      positionY: 0,
      timestamp: timeSinceStart,
      text: value.text,
      selectionBase: value.selection.baseOffset,
      selectionExtent: value.selection.extentOffset,
      composingBase: value.composing.start,
      composingExtent: value.composing.end,
      fieldId: fieldId,
    );

    _imprints.add(imprint);
    onImprintCaptured?.call(imprint);
  }

  /// Record a text input action (done, next, newline, etc.).
  ///
  /// Called when the user performs a text input action on the
  /// keyboard (e.g. pressing Enter or the action button).
  ///
  /// ```dart
  /// shade.recordTextAction(TextInputAction.done, fieldId: 'email');
  /// ```
  void recordTextAction(TextInputAction action, {String? fieldId}) {
    if (!isRecordingCore.peek()) return;

    final timeSinceStart = DateTime.now().difference(_recordingStart!);

    final imprint = Imprint(
      type: ImprintType.textAction,
      positionX: 0,
      positionY: 0,
      timestamp: timeSinceStart,
      textInputAction: action.index,
      fieldId: fieldId,
    );

    _imprints.add(imprint);
    onImprintCaptured?.call(imprint);
  }
}
