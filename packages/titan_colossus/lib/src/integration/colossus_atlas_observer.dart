import 'package:titan_atlas/titan_atlas.dart';

import '../colossus.dart';

// ---------------------------------------------------------------------------
// ColossusAtlasObserver — Atlas Route Timing Integration
// ---------------------------------------------------------------------------

/// An [AtlasObserver] that automatically times page loads with [Stride].
///
/// Add this to your Atlas configuration to get automatic page load
/// timing for every route navigation.
///
/// ## Usage
///
/// ```dart
/// final atlas = Atlas(
///   passages: [...],
///   observers: [
///     ColossusAtlasObserver(),
///     AtlasLoggingObserver(), // Can combine with other observers
///   ],
/// );
/// ```
///
/// ## How It Works
///
/// On every navigation event (`to`, `replace`, `reset`), the observer
/// calls `Colossus.instance.stride.startTiming()` which starts a
/// stopwatch and registers a post-frame callback to capture the
/// time-to-first-paint.
class ColossusAtlasObserver extends AtlasObserver {
  /// Creates a [ColossusAtlasObserver].
  const ColossusAtlasObserver();

  @override
  void onNavigate(Waypoint from, Waypoint to) {
    if (!Colossus.isActive) return;
    Colossus.instance.stride.startTiming(to.path, pattern: to.pattern);
  }

  @override
  void onReplace(Waypoint from, Waypoint to) {
    if (!Colossus.isActive) return;
    Colossus.instance.stride.startTiming(to.path, pattern: to.pattern);
  }

  @override
  void onReset(Waypoint to) {
    if (!Colossus.isActive) return;
    Colossus.instance.stride.startTiming(to.path, pattern: to.pattern);
  }
}
