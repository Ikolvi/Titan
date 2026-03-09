import 'package:titan_atlas/titan_atlas.dart';

import '../colossus.dart';

// ---------------------------------------------------------------------------
// ColossusAtlasObserver — Atlas Route Timing & Event Integration
// ---------------------------------------------------------------------------

/// An [AtlasObserver] that automatically times page loads with [Stride]
/// and records navigation events to [Colossus.trackEvent].
///
/// Add this to your Atlas configuration to get automatic page load
/// timing for every route navigation, plus event tracking for guard
/// redirects, drift redirects, route-not-found, and pop events.
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
/// ## Tracked Events
///
/// | Event Type | Source | When |
/// |------------|--------|------|
/// | `navigate` | `atlas` | Route push |
/// | `replace` | `atlas` | Route replace |
/// | `reset` | `atlas` | Router reset |
/// | `pop` | `atlas` | Route pop (back navigation) |
/// | `guard_redirect` | `atlas` | Sentinel redirected navigation |
/// | `drift_redirect` | `atlas` | Drift callback redirected navigation |
/// | `not_found` | `atlas` | No matching route found |
class ColossusAtlasObserver extends AtlasObserver {
  /// Creates a [ColossusAtlasObserver].
  const ColossusAtlasObserver();

  @override
  void onNavigate(Waypoint from, Waypoint to) {
    if (!Colossus.isActive) return;
    Colossus.instance.stride.startTiming(to.path, pattern: to.pattern);
    Colossus.instance.trackEvent({
      'source': 'atlas',
      'type': 'navigate',
      'from': from.path,
      'to': to.path,
      'pattern': to.pattern,
    });
  }

  @override
  void onReplace(Waypoint from, Waypoint to) {
    if (!Colossus.isActive) return;
    Colossus.instance.stride.startTiming(to.path, pattern: to.pattern);
    Colossus.instance.trackEvent({
      'source': 'atlas',
      'type': 'replace',
      'from': from.path,
      'to': to.path,
      'pattern': to.pattern,
    });
  }

  @override
  void onReset(Waypoint to) {
    if (!Colossus.isActive) return;
    Colossus.instance.stride.startTiming(to.path, pattern: to.pattern);
    Colossus.instance.trackEvent({
      'source': 'atlas',
      'type': 'reset',
      'to': to.path,
      'pattern': to.pattern,
    });
  }

  @override
  void onPop(Waypoint from, Waypoint to) {
    if (!Colossus.isActive) return;
    Colossus.instance.trackEvent({
      'source': 'atlas',
      'type': 'pop',
      'from': from.path,
      'to': to.path,
    });
  }

  @override
  void onGuardRedirect(String originalPath, String redirectPath) {
    if (!Colossus.isActive) return;
    Colossus.instance.trackEvent({
      'source': 'atlas',
      'type': 'guard_redirect',
      'originalPath': originalPath,
      'redirectPath': redirectPath,
    });
  }

  @override
  void onDriftRedirect(String originalPath, String redirectPath) {
    if (!Colossus.isActive) return;
    Colossus.instance.trackEvent({
      'source': 'atlas',
      'type': 'drift_redirect',
      'originalPath': originalPath,
      'redirectPath': redirectPath,
    });
  }

  @override
  void onNotFound(String path) {
    if (!Colossus.isActive) return;
    Colossus.instance.trackEvent({
      'source': 'atlas',
      'type': 'not_found',
      'path': path,
    });
  }
}
