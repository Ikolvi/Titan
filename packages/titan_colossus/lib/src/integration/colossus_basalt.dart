import 'package:titan_basalt/titan_basalt.dart';

import '../colossus.dart';

/// **ColossusBasalt** — Resilience monitoring bridge between Basalt
/// infrastructure primitives and [Colossus].
///
/// Forwards state changes from [Portcullis] (circuit breaker),
/// [Moat] (rate limiter), [Embargo] (async mutex), and [Warden]
/// (service health) to [Colossus.trackEvent] for real-time
/// observability of resilience patterns.
///
/// ## Usage
///
/// Register components for monitoring:
///
/// ```dart
/// final breaker = Portcullis(failureThreshold: 3);
/// ColossusBasalt.monitorPortcullis('api-breaker', breaker);
///
/// final limiter = Moat(maxTokens: 100, refillInterval: Duration(seconds: 1));
/// ColossusBasalt.monitorMoat('api-rate-limit', limiter);
///
/// final mutex = Embargo(name: 'db-lock');
/// ColossusBasalt.monitorEmbargo('db-lock', mutex);
///
/// final health = Warden();
/// ColossusBasalt.monitorWarden(health);
/// ```
///
/// ## Tracked Events
///
/// | Event Type | Source | When |
/// |------------|--------|------|
/// | `circuit_trip` | `basalt` | Portcullis opens (circuit broken) |
/// | `circuit_recover` | `basalt` | Portcullis closes (circuit restored) |
/// | `rate_limit_hit` | `basalt` | Moat rejection count increases |
/// | `mutex_contention` | `basalt` | Embargo status becomes `contended` |
/// | `health_degraded` | `basalt` | Warden overall health degrades |
/// | `health_down` | `basalt` | Warden overall health goes down |
/// | `health_recovered` | `basalt` | Warden overall health returns to healthy |
///
/// ## Cleanup
///
/// ```dart
/// ColossusBasalt.disconnectAll();
/// ```
class ColossusBasalt {
  ColossusBasalt._();

  /// Active listener disposers keyed by monitor registration key.
  static final Map<String, void Function()> _disposers = {};

  /// Whether any monitors are currently active.
  static bool get isActive => _disposers.isNotEmpty;

  /// All registered monitor names.
  static Set<String> get monitoredComponents =>
      Set.unmodifiable(_disposers.keys);

  /// Monitors a [Portcullis] circuit breaker for trip/recovery events.
  ///
  /// Listens to the state reactive node and emits `circuit_trip` when
  /// the circuit opens and `circuit_recover` when it closes again.
  ///
  /// ```dart
  /// ColossusBasalt.monitorPortcullis('payment-api', breaker);
  /// ```
  static void monitorPortcullis(String name, Portcullis portcullis) {
    // Remove existing monitor with same name.
    _disposers[name]?.call();

    var lastState = portcullis.state;
    final stateNode = portcullis.managedStateNodes[0]; // _stateCore

    void listener() {
      if (!Colossus.isActive) return;
      final current = portcullis.state;
      if (current == lastState) return;

      if (current == PortcullisState.open) {
        Colossus.instance.trackEvent({
          'source': 'basalt',
          'type': 'circuit_trip',
          'name': name,
          'tripCount': portcullis.tripCount,
          'failureCount': portcullis.failureCount,
        });
      } else if (current == PortcullisState.closed &&
          lastState != PortcullisState.closed) {
        Colossus.instance.trackEvent({
          'source': 'basalt',
          'type': 'circuit_recover',
          'name': name,
          'totalTrips': portcullis.tripCount,
        });
      }
      lastState = current;
    }

    stateNode.addListener(listener);
    _disposers[name] = () => stateNode.removeListener(listener);
  }

  /// Monitors a [Moat] rate limiter for rejection events.
  ///
  /// Listens to the `rejections` reactive node and emits
  /// `rate_limit_hit` each time the rejection count increases.
  ///
  /// ```dart
  /// ColossusBasalt.monitorMoat('api-throttle', moat);
  /// ```
  static void monitorMoat(String name, Moat moat) {
    _disposers[name]?.call();

    var lastRejections = moat.rejections.peek();
    final dispose = moat.rejections.listen((count) {
      if (!Colossus.isActive) return;
      if (count > lastRejections) {
        Colossus.instance.trackEvent({
          'source': 'basalt',
          'type': 'rate_limit_hit',
          'name': name,
          'totalRejections': count,
          'remaining': moat.remainingTokens.peek(),
        });
      }
      lastRejections = count;
    });

    _disposers[name] = dispose;
  }

  /// Monitors an [Embargo] async mutex for contention events.
  ///
  /// Listens to the `status` reactive node and emits
  /// `mutex_contention` when the status becomes [EmbargoStatus.contended].
  ///
  /// ```dart
  /// ColossusBasalt.monitorEmbargo('db-write-lock', embargo);
  /// ```
  static void monitorEmbargo(String name, Embargo embargo) {
    _disposers[name]?.call();

    void listener() {
      if (!Colossus.isActive) return;
      final status = embargo.status.peek();
      if (status == EmbargoStatus.contended) {
        Colossus.instance.trackEvent({
          'source': 'basalt',
          'type': 'mutex_contention',
          'name': name,
          'queueLength': embargo.queueLength.peek(),
          'activeCount': embargo.activeCount.peek(),
        });
      }
    }

    embargo.status.addListener(listener);
    _disposers[name] = () => embargo.status.removeListener(listener);
  }

  /// Monitors a [Warden] service health checker for degradation events.
  ///
  /// Listens to the `overallHealth` reactive node and emits events
  /// when the aggregate health status changes.
  ///
  /// ```dart
  /// ColossusBasalt.monitorWarden(warden);
  /// ```
  static void monitorWarden(Warden warden, {String name = 'warden'}) {
    _disposers[name]?.call();

    var lastHealth = warden.overallHealth.peek();
    void listener() {
      if (!Colossus.isActive) return;
      final health = warden.overallHealth.peek();
      if (health == lastHealth) return;

      final String type;
      if (health == ServiceStatus.down) {
        type = 'health_down';
      } else if (health == ServiceStatus.degraded) {
        type = 'health_degraded';
      } else if (health == ServiceStatus.healthy &&
          lastHealth != ServiceStatus.healthy) {
        type = 'health_recovered';
      } else {
        lastHealth = health;
        return;
      }

      Colossus.instance.trackEvent({
        'source': 'basalt',
        'type': type,
        'name': name,
        'healthyCount': warden.healthyCount.peek(),
        'degradedCount': warden.degradedCount.peek(),
      });
      lastHealth = health;
    }

    warden.overallHealth.addListener(listener);
    _disposers[name] = () => warden.overallHealth.removeListener(listener);
  }

  /// Removes a specific monitor by name.
  ///
  /// ```dart
  /// ColossusBasalt.disconnect('api-breaker');
  /// ```
  static void disconnect(String name) {
    _disposers.remove(name)?.call();
  }

  /// Removes all active monitors.
  ///
  /// Call this during shutdown to clean up all listeners.
  ///
  /// ```dart
  /// ColossusBasalt.disconnectAll();
  /// ```
  static void disconnectAll() {
    for (final dispose in _disposers.values) {
      dispose();
    }
    _disposers.clear();
  }
}
