import 'dart:ui';

import '../metrics/mark.dart';

// ---------------------------------------------------------------------------
// Pulse — Frame Monitoring
// ---------------------------------------------------------------------------

/// **Pulse** — the heartbeat of your app's rendering pipeline.
///
/// Tracks frame build times, raster times, FPS, and jank detection
/// using Flutter's `addTimingsCallback` API.
///
/// ## Why "Pulse"?
///
/// Every heartbeat is a frame. A strong pulse means smooth rendering.
/// When the pulse weakens, jank appears.
///
/// Pulse is managed internally by [Colossus] — you don't create it
/// directly. Access metrics through `Colossus.instance`.
class Pulse {
  /// Internal circular buffer for frame history.
  ///
  /// Using a fixed-size list with a write index avoids the O(n)
  /// cost of `List.removeAt(0)` on every frame.
  late final List<FrameMark?> _ring;
  int _ringHead = 0;
  int _ringCount = 0;

  /// Maximum number of frame marks to retain.
  final int maxHistory;

  /// The jank threshold in milliseconds (default: 16ms for 60 FPS).
  final int jankThresholdMs;

  int _totalFrames = 0;
  int _jankFrames = 0;
  double _fps = 0;
  Duration _avgBuildTime = Duration.zero;
  Duration _avgRasterTime = Duration.zero;
  DateTime? _lastFpsCalc;
  int _framesSinceLastCalc = 0;

  // Rolling average accumulators (last [_avgWindow] frames)
  static const _avgWindow = 60;
  final _recentBuild = List<int>.filled(_avgWindow, 0);
  final _recentRaster = List<int>.filled(_avgWindow, 0);
  int _avgIndex = 0;
  int _avgCount = 0;
  int _buildSum = 0;
  int _rasterSum = 0;

  /// Called when new frame data is available.
  void Function()? onUpdate;

  /// Creates a [Pulse] monitor.
  Pulse({this.maxHistory = 300, this.jankThresholdMs = 16})
    : _ring = List<FrameMark?>.filled(maxHistory, null);

  /// Current estimated FPS.
  double get fps => _fps;

  /// Total frames measured.
  int get totalFrames => _totalFrames;

  /// Total janky frames (> [jankThresholdMs]).
  int get jankFrames => _jankFrames;

  /// Average frame build duration.
  Duration get avgBuildTime => _avgBuildTime;

  /// Average frame raster duration.
  Duration get avgRasterTime => _avgRasterTime;

  /// Jank rate as a percentage (0.0–100.0).
  double get jankRate =>
      _totalFrames > 0 ? (_jankFrames / _totalFrames) * 100 : 0;

  /// Recent frame history (newest last).
  List<FrameMark> get history {
    if (_ringCount == 0) return const [];
    final result = <FrameMark>[];
    for (var i = 0; i < _ringCount; i++) {
      final idx = (_ringHead - _ringCount + i) % maxHistory;
      result.add(_ring[idx < 0 ? idx + maxHistory : idx]!);
    }
    return result;
  }

  /// Process a batch of frame timings from Flutter's rendering pipeline.
  ///
  /// Called by [Colossus] via `SchedulerBinding.addTimingsCallback`.
  void processTimings(List<FrameTiming> timings) {
    final now = DateTime.now();

    for (final timing in timings) {
      final frame = FrameMark(
        buildDuration: timing.buildDuration,
        rasterDuration: timing.rasterDuration,
        totalDuration: timing.totalSpan,
        timestamp: now,
      );

      _ring[_ringHead] = frame;
      _ringHead = (_ringHead + 1) % maxHistory;
      if (_ringCount < maxHistory) _ringCount++;

      _totalFrames++;
      if (frame.isJank) _jankFrames++;

      _updateRollingAvg(frame);
    }

    // Calculate FPS every ~1 second
    _framesSinceLastCalc += timings.length;
    _lastFpsCalc ??= now;
    final elapsed = now.difference(_lastFpsCalc!);
    if (elapsed.inMilliseconds >= 1000) {
      _fps = (_framesSinceLastCalc / elapsed.inMilliseconds) * 1000;
      _framesSinceLastCalc = 0;
      _lastFpsCalc = now;
    }

    onUpdate?.call();
  }

  /// Incrementally update rolling averages using a circular accumulator.
  ///
  /// O(1) per frame — subtracts the oldest value and adds the new one,
  /// avoiding re-iterating the window on every call.
  void _updateRollingAvg(FrameMark frame) {
    final buildUs = frame.buildDuration.inMicroseconds;
    final rasterUs = frame.rasterDuration.inMicroseconds;

    // Subtract the value being overwritten
    _buildSum -= _recentBuild[_avgIndex];
    _rasterSum -= _recentRaster[_avgIndex];

    // Insert new value
    _recentBuild[_avgIndex] = buildUs;
    _recentRaster[_avgIndex] = rasterUs;
    _buildSum += buildUs;
    _rasterSum += rasterUs;

    _avgIndex = (_avgIndex + 1) % _avgWindow;
    if (_avgCount < _avgWindow) _avgCount++;

    _avgBuildTime = Duration(microseconds: _buildSum ~/ _avgCount);
    _avgRasterTime = Duration(microseconds: _rasterSum ~/ _avgCount);
  }

  /// Manually record a single frame timing.
  ///
  /// Useful for testing or manual instrumentation when you have the
  /// build, raster, and total durations directly.
  ///
  /// ```dart
  /// pulse.recordFrame(
  ///   buildDuration: Duration(microseconds: 4000),
  ///   rasterDuration: Duration(microseconds: 3000),
  ///   totalDuration: Duration(microseconds: 7000),
  /// );
  /// ```
  void recordFrame({
    required Duration buildDuration,
    required Duration rasterDuration,
    required Duration totalDuration,
  }) {
    final frame = FrameMark(
      buildDuration: buildDuration,
      rasterDuration: rasterDuration,
      totalDuration: totalDuration,
    );

    _ring[_ringHead] = frame;
    _ringHead = (_ringHead + 1) % maxHistory;
    if (_ringCount < maxHistory) _ringCount++;

    _totalFrames++;
    if (frame.isJank) _jankFrames++;

    _updateRollingAvg(frame);
    onUpdate?.call();
  }

  /// Reset all frame metrics.
  void reset() {
    _ring.fillRange(0, maxHistory, null);
    _ringHead = 0;
    _ringCount = 0;
    _totalFrames = 0;
    _jankFrames = 0;
    _fps = 0;
    _avgBuildTime = Duration.zero;
    _avgRasterTime = Duration.zero;
    _lastFpsCalc = null;
    _framesSinceLastCalc = 0;
    _recentBuild.fillRange(0, _avgWindow, 0);
    _recentRaster.fillRange(0, _avgWindow, 0);
    _avgIndex = 0;
    _avgCount = 0;
    _buildSum = 0;
    _rasterSum = 0;
  }
}
