import 'package:flutter/scheduler.dart';

import '../metrics/mark.dart';

// ---------------------------------------------------------------------------
// Stride — Page Load Timing
// ---------------------------------------------------------------------------

/// **Stride** — measures the time from navigation to first paint.
///
/// Each page load is a stride forward. Stride tracks how long each
/// step takes, from the moment Atlas navigates to the moment the
/// destination frame renders.
///
/// ## Why "Stride"?
///
/// The Colossus takes great strides across the world. Each stride
/// is a page transition, measured for speed and grace.
///
/// Stride is managed internally by [Colossus]. It integrates with
/// [ColossusAtlasObserver] for automatic route timing.
class Stride {
  /// Internal circular buffer for page load history.
  late final List<PageLoadMark?> _ring = List<PageLoadMark?>.filled(
    maxHistory,
    null,
  );
  int _ringHead = 0;
  int _ringCount = 0;

  /// Maximum number of page load marks to retain.
  final int maxHistory;

  // Running average accumulator — avoids re-folding on every read.
  int _totalDurationUs = 0;

  Stopwatch? _activeStopwatch;
  String? _activePath;
  String? _activePattern;

  /// Called when a new page load completes.
  void Function(PageLoadMark mark)? onPageLoad;

  /// Creates a [Stride] monitor.
  Stride({this.maxHistory = 100});

  /// All recorded page loads (newest last).
  List<PageLoadMark> get history {
    if (_ringCount == 0) return const [];
    final result = <PageLoadMark>[];
    for (var i = 0; i < _ringCount; i++) {
      final idx = (_ringHead - _ringCount + i) % maxHistory;
      result.add(_ring[idx < 0 ? idx + maxHistory : idx]!);
    }
    return result;
  }

  /// Most recent page load (if any).
  PageLoadMark? get lastPageLoad {
    if (_ringCount == 0) return null;
    final idx = (_ringHead - 1) % maxHistory;
    return _ring[idx < 0 ? idx + maxHistory : idx];
  }

  /// Average page load duration.
  ///
  /// O(1) — uses a running accumulator instead of fold.
  Duration get avgPageLoad {
    if (_ringCount == 0) return Duration.zero;
    return Duration(microseconds: _totalDurationUs ~/ _ringCount);
  }

  /// Start timing a page load.
  ///
  /// Called by [ColossusAtlasObserver] when navigation begins.
  void startTiming(String path, {String? pattern}) {
    _activeStopwatch = Stopwatch()..start();
    _activePath = path;
    _activePattern = pattern;

    // Schedule end-of-frame callback to capture first paint
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _completeTiming();
    });
  }

  void _completeTiming() {
    if (_activeStopwatch == null || _activePath == null) return;

    _activeStopwatch!.stop();
    final mark = PageLoadMark(
      path: _activePath!,
      pattern: _activePattern,
      duration: _activeStopwatch!.elapsed,
    );

    _addMark(mark);
    onPageLoad?.call(mark);

    _activeStopwatch = null;
    _activePath = null;
    _activePattern = null;
  }

  /// Manually record a page load mark (for custom timing scenarios).
  ///
  /// ```dart
  /// final sw = Stopwatch()..start();
  /// await loadData();
  /// sw.stop();
  /// Colossus.instance.stride.record('/data', sw.elapsed);
  /// ```
  void record(String path, Duration duration, {String? pattern}) {
    final mark = PageLoadMark(path: path, pattern: pattern, duration: duration);
    _addMark(mark);
    onPageLoad?.call(mark);
  }

  /// Add a mark to the ring buffer, evicting the oldest if full.
  void _addMark(PageLoadMark mark) {
    // Subtract the evicted entry's duration from the running total
    if (_ringCount == maxHistory) {
      final evicted = _ring[_ringHead];
      if (evicted != null) {
        _totalDurationUs -= evicted.duration.inMicroseconds;
      }
    }

    _ring[_ringHead] = mark;
    _ringHead = (_ringHead + 1) % maxHistory;
    if (_ringCount < maxHistory) _ringCount++;
    _totalDurationUs += mark.duration.inMicroseconds;
  }

  /// Reset all page load data.
  void reset() {
    _ring.fillRange(0, maxHistory, null);
    _ringHead = 0;
    _ringCount = 0;
    _totalDurationUs = 0;
    _activeStopwatch = null;
    _activePath = null;
    _activePattern = null;
  }
}
