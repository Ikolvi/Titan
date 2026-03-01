/// Oracle of Atlas — Navigation observer for analytics, logging, and debugging.
///
/// Attach observers to Atlas to receive lifecycle events whenever
/// navigation occurs.
///
/// ```dart
/// class AnalyticsObserver extends AtlasObserver {
///   @override
///   void onNavigate(Waypoint from, Waypoint to) {
///     analytics.trackScreen(to.path);
///   }
/// }
///
/// final atlas = Atlas(
///   passages: [...],
///   observers: [AnalyticsObserver()],
/// );
/// ```
library;

import '../core/waypoint.dart';

/// Base class for Atlas navigation observers.
///
/// Extend this class and override the methods you care about.
///
/// ```dart
/// class LogObserver extends AtlasObserver {
///   @override
///   void onNavigate(Waypoint from, Waypoint to) {
///     print('${from.path} → ${to.path}');
///   }
/// }
/// ```
abstract class AtlasObserver {
  const AtlasObserver();

  /// Called when navigating to a new route (`Atlas.to`, `Atlas.toNamed`).
  void onNavigate(Waypoint from, Waypoint to) {}

  /// Called when replacing the current route (`Atlas.replace`).
  void onReplace(Waypoint from, Waypoint to) {}

  /// Called when going back (`Atlas.back`, `Atlas.backTo`).
  void onPop(Waypoint from, Waypoint to) {}

  /// Called when resetting the navigation stack (`Atlas.reset`).
  void onReset(Waypoint to) {}

  /// Called when a Sentinel redirects navigation.
  void onGuardRedirect(String originalPath, String redirectPath) {}

  /// Called when a Drift redirects navigation.
  void onDriftRedirect(String originalPath, String redirectPath) {}

  /// Called when a 404 occurs (no matching Passage).
  void onNotFound(String path) {}
}

/// A logging observer that prints navigation events to the console.
///
/// ```dart
/// Atlas(
///   passages: [...],
///   observers: [AtlasLoggingObserver()],
/// )
/// ```
class AtlasLoggingObserver extends AtlasObserver {
  /// Optional prefix for log messages.
  final String prefix;

  const AtlasLoggingObserver({this.prefix = 'Atlas'});

  @override
  void onNavigate(Waypoint from, Waypoint to) {
    // ignore: avoid_print
    print('$prefix: navigate ${from.path} → ${to.path}');
  }

  @override
  void onReplace(Waypoint from, Waypoint to) {
    // ignore: avoid_print
    print('$prefix: replace ${from.path} → ${to.path}');
  }

  @override
  void onPop(Waypoint from, Waypoint to) {
    // ignore: avoid_print
    print('$prefix: pop ${from.path} → ${to.path}');
  }

  @override
  void onReset(Waypoint to) {
    // ignore: avoid_print
    print('$prefix: reset → ${to.path}');
  }

  @override
  void onGuardRedirect(String originalPath, String redirectPath) {
    // ignore: avoid_print
    print('$prefix: sentinel $originalPath → $redirectPath');
  }

  @override
  void onDriftRedirect(String originalPath, String redirectPath) {
    // ignore: avoid_print
    print('$prefix: drift $originalPath → $redirectPath');
  }

  @override
  void onNotFound(String path) {
    // ignore: avoid_print
    print('$prefix: 404 $path');
  }
}
