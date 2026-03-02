import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../recording/shade.dart';

// ---------------------------------------------------------------------------
// ShadeListener — Global gesture capture widget
// ---------------------------------------------------------------------------

/// **ShadeListener** — a transparent widget that captures all pointer events.
///
/// Wrap your app (or any subtree) with [ShadeListener] to feed all
/// pointer events into a [Shade] recorder. Uses [Listener] with
/// [HitTestBehavior.translucent] so events pass through to the
/// underlying widget tree without interference.
///
/// ## Recording Indicator
///
/// When [showIndicator] is `true` (the default), a small red dot
/// appears in the top-left corner during recording, and a teal play
/// icon appears during replay. This gives visual feedback without
/// interfering with the UI.
///
/// ## Usage
///
/// ```dart
/// ShadeListener(
///   shade: shade,
///   child: MaterialApp(
///     home: MyHomePage(),
///   ),
/// )
/// ```
///
/// ## How It Works
///
/// [ShadeListener] wraps the child in a [Listener] widget that
/// intercepts all pointer events (down, move, up, hover, scroll,
/// cancel) and passes them to `shade.recordPointerEvent()`. The
/// [HitTestBehavior.translucent] behavior ensures events still
/// reach their intended targets — ShadeListener is invisible to
/// the user.
///
/// ## Placement
///
/// Place [ShadeListener] as high in the widget tree as possible
/// to capture all interactions:
///
/// ```dart
/// void main() {
///   final shade = Shade();
///
///   runApp(
///     ShadeListener(
///       shade: shade,
///       child: MaterialApp.router(
///         routerConfig: atlas.config,
///       ),
///     ),
///   );
/// }
/// ```
///
/// ## Reactive Indicator
///
/// The indicator reacts to state changes through [Shade.isRecordingCore]
/// and [Shade.isReplayingCore] — reactive [Core] fields that fire
/// notifications immediately when recording or replay starts/stops.
/// This replaces the previous `Timer.periodic` polling approach,
/// giving instant UI feedback with zero cost when idle. Event count
/// updates during recording still use a lightweight 500ms timer.
class ShadeListener extends StatefulWidget {
  /// The [Shade] recorder to feed captured events to.
  final Shade shade;

  /// The child widget tree to capture events from.
  final Widget child;

  /// Whether to show a recording/replaying indicator on screen.
  ///
  /// When `true`, a small red dot appears in the top-left corner
  /// during recording, and a teal play icon during replay.
  /// Defaults to `true`.
  final bool showIndicator;

  /// Creates a [ShadeListener] that captures pointer events for [shade].
  const ShadeListener({
    super.key,
    required this.shade,
    required this.child,
    this.showIndicator = true,
  });

  @override
  State<ShadeListener> createState() => _ShadeListenerState();
}

class _ShadeListenerState extends State<ShadeListener> {
  void Function()? _stateListener;
  Timer? _eventCountTimer;

  @override
  void initState() {
    super.initState();
    widget.shade.registerKeyboardHandler();
    if (widget.showIndicator) {
      _setupStateListeners();
    }
  }

  @override
  void didUpdateWidget(ShadeListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shade != widget.shade) {
      oldWidget.shade.unregisterKeyboardHandler();
      widget.shade.registerKeyboardHandler();
      _teardownStateListeners();
      if (widget.showIndicator) {
        _setupStateListeners();
      }
    } else if (widget.showIndicator && _stateListener == null) {
      _setupStateListeners();
    } else if (!widget.showIndicator) {
      _teardownStateListeners();
    }
  }

  @override
  void dispose() {
    _teardownStateListeners();
    widget.shade.unregisterKeyboardHandler();
    super.dispose();
  }

  /// Listen to [Shade.isRecordingCore] and [Shade.isReplayingCore]
  /// for immediate reactive updates instead of Timer-based polling.
  void _setupStateListeners() {
    _stateListener = () {
      if (!mounted) return;
      setState(() {});
      // Start event count polling only while recording
      if (widget.shade.isRecording && _eventCountTimer == null) {
        _startEventCountPolling();
      } else if (!widget.shade.isRecording) {
        _stopEventCountPolling();
      }
    };
    widget.shade.isRecordingCore.addListener(_stateListener!);
    widget.shade.isReplayingCore.addListener(_stateListener!);
  }

  void _teardownStateListeners() {
    if (_stateListener != null) {
      widget.shade.isRecordingCore.removeListener(_stateListener!);
      widget.shade.isReplayingCore.removeListener(_stateListener!);
      _stateListener = null;
    }
    _stopEventCountPolling();
  }

  /// Poll event count every 500ms during recording for live display.
  void _startEventCountPolling() {
    _eventCountTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopEventCountPolling() {
    _eventCountTimer?.cancel();
    _eventCountTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final listener = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.shade.recordPointerEvent,
      onPointerMove: widget.shade.recordPointerEvent,
      onPointerUp: widget.shade.recordPointerEvent,
      onPointerCancel: widget.shade.recordPointerEvent,
      onPointerHover: widget.shade.recordPointerEvent,
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: widget.shade.recordPointerEvent,
      onPointerPanZoomUpdate: widget.shade.recordPointerEvent,
      onPointerPanZoomEnd: widget.shade.recordPointerEvent,
      child: widget.child,
    );

    if (!widget.showIndicator) return listener;

    final isRecording = widget.shade.isRecording;
    final isReplaying = widget.shade.isReplaying;

    if (!isRecording && !isReplaying) return listener;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          listener,
          Positioned(
            left: 8,
            top: 8,
            child: IgnorePointer(
              child: _ShadeIndicator(
                isRecording: isRecording,
                isReplaying: isReplaying,
                eventCount: isRecording ? widget.shade.currentEventCount : 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    // PointerScrollEvent is a subclass of PointerSignalEvent
    widget.shade.recordPointerEvent(event);
  }
}

// ---------------------------------------------------------------------------
// Recording / Replay Indicator
// ---------------------------------------------------------------------------

class _ShadeIndicator extends StatelessWidget {
  final bool isRecording;
  final bool isReplaying;
  final int eventCount;

  const _ShadeIndicator({
    required this.isRecording,
    required this.isReplaying,
    required this.eventCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRecording ? Colors.redAccent : Colors.tealAccent;
    final icon = isRecording ? Icons.fiber_manual_record : Icons.play_arrow;
    final label = isRecording ? '$eventCount events' : 'Replaying...';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
