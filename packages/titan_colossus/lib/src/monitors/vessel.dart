import 'dart:async';

import 'package:titan/titan.dart';

import '../metrics/mark.dart';

// ---------------------------------------------------------------------------
// Vessel — Memory Monitoring
// ---------------------------------------------------------------------------

/// **Vessel** — watches over your app's memory and detects leaks.
///
/// Monitors Titan's DI registry for Pillar lifecycle anomalies:
/// instances that remain registered far longer than expected,
/// suggesting they were never properly disposed.
///
/// ## Why "Vessel"?
///
/// A vessel holds content — when it overflows, there's a leak.
/// Vessel watches your Pillar containers for overflow.
///
/// Vessel is managed internally by [Colossus]. Access metrics through
/// `Colossus.instance`.
class Vessel {
  /// How often to check for leaks (default: every 10 seconds).
  final Duration checkInterval;

  /// How long a Pillar must live before it becomes a leak suspect.
  ///
  /// Pillars alive longer than this without being explicitly marked
  /// as long-lived are flagged.
  final Duration leakThreshold;

  /// Pillar types that are exempt from leak detection.
  ///
  /// Global Pillars (AuthPillar, AppPillar, etc.) should be listed here.
  final Set<String> exemptTypes;

  final Map<String, DateTime> _instanceFirstSeen = {};
  final List<LeakSuspect> _leakSuspects = [];
  Timer? _timer;

  int _pillarCount = 0;
  int _totalInstances = 0;

  /// Called when memory data updates.
  void Function()? onUpdate;

  /// Creates a [Vessel] monitor.
  Vessel({
    this.checkInterval = const Duration(seconds: 10),
    this.leakThreshold = const Duration(minutes: 5),
    Set<String>? exemptTypes,
  }) : exemptTypes = exemptTypes ?? {};

  /// Number of live Pillar instances.
  int get pillarCount => _pillarCount;

  /// Total Titan DI instances.
  int get totalInstances => _totalInstances;

  /// Current leak suspects.
  List<LeakSuspect> get leakSuspects => List.unmodifiable(_leakSuspects);

  /// Start periodic memory checks.
  void start() {
    _timer?.cancel();
    _check(); // Initial check
    _timer = Timer.periodic(checkInterval, (_) => _check());
  }

  /// Stop periodic memory checks.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    final instances = Titan.instances;
    _totalInstances = instances.length;

    // Count Pillars
    _pillarCount = 0;
    final now = DateTime.now();
    final currentTypes = <String>{};

    for (final entry in instances.entries) {
      final typeName = entry.key.toString();
      currentTypes.add(typeName);

      if (entry.value is Pillar) {
        _pillarCount++;

        // Track first-seen time
        _instanceFirstSeen.putIfAbsent(typeName, () => now);

        // Check for leak suspects
        if (!exemptTypes.contains(typeName)) {
          final firstSeen = _instanceFirstSeen[typeName]!;
          final age = now.difference(firstSeen);
          if (age > leakThreshold) {
            final existing = _leakSuspects.where((s) => s.typeName == typeName);
            if (existing.isEmpty) {
              _leakSuspects.add(
                LeakSuspect(typeName: typeName, firstSeen: firstSeen),
              );
            }
          }
        }
      }
    }

    // Remove suspects for instances that are no longer registered
    _leakSuspects.removeWhere((s) => !currentTypes.contains(s.typeName));

    // Clean up first-seen for removed instances
    _instanceFirstSeen.removeWhere((k, _) => !currentTypes.contains(k));

    onUpdate?.call();
  }

  /// Take a memory snapshot.
  MemoryMark snapshot() {
    _check();
    return MemoryMark(
      pillarCount: _pillarCount,
      totalInstances: _totalInstances,
      leakSuspects: _leakSuspects.map((s) => s.typeName).toList(),
    );
  }

  /// Mark a Pillar type as long-lived (exempt from leak detection).
  void exempt(String typeName) {
    exemptTypes.add(typeName);
    _leakSuspects.removeWhere((s) => s.typeName == typeName);
  }

  /// Reset all memory tracking data.
  void reset() {
    _instanceFirstSeen.clear();
    _leakSuspects.clear();
    _pillarCount = 0;
    _totalInstances = 0;
  }

  /// Dispose the vessel and cancel timers.
  void dispose() {
    stop();
    reset();
  }
}
