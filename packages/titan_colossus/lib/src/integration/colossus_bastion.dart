import 'package:titan/titan.dart';

import '../colossus.dart';

/// **ColossusBastion** — Reactive engine monitoring bridge between
/// Titan's [TitanObserver] system and [Colossus].
///
/// Registers a [TitanObserver] that tracks:
/// - **Pillar lifecycle** — init/dispose events for every Pillar
/// - **Effect errors** — runtime errors in watchers and effects
/// - **State mutation frequency** — counts mutations per state node
///   to detect hot states that may indicate performance issues
///
/// ## Automatic (via ColossusPlugin)
///
/// When `autoBastionMetrics: true` (default), ColossusPlugin calls
/// [connect] during attach:
///
/// ```dart
/// runApp(
///   Beacon(
///     plugins: [ColossusPlugin()],
///     child: MyApp(),
///   ),
/// );
/// // ↑ Colossus tracks Pillar lifecycle and state mutations.
/// ```
///
/// ## Manual
///
/// ```dart
/// ColossusBastion.connect();
/// ```
///
/// ## Tracked Events
///
/// | Event Type | Source | When |
/// |------------|--------|------|
/// | `pillar_init` | `bastion` | A Pillar is initialized |
/// | `pillar_dispose` | `bastion` | A Pillar is disposed |
/// | `effect_error` | `bastion` | A TitanEffect throws an error |
///
/// ## Aggregate Metrics
///
/// Access state mutation counts via [stateHeatMap]:
///
/// ```dart
/// final heatMap = ColossusBastion.stateHeatMap;
/// // {'counter': 42, 'username': 3, ...}
/// ```
class ColossusBastion {
  ColossusBastion._();

  static _ColossusBastionObserver? _observer;

  /// Whether Bastion metrics are currently being forwarded to Colossus.
  static bool get isConnected => _observer != null;

  /// Number of Pillar initializations tracked since [connect].
  static int get pillarInitCount => _observer?.pillarInitCount ?? 0;

  /// Number of Pillar disposals tracked since [connect].
  static int get pillarDisposeCount => _observer?.pillarDisposeCount ?? 0;

  /// Number of effect errors tracked since [connect].
  static int get effectErrorCount => _observer?.effectErrorCount ?? 0;

  /// Total state mutations tracked since [connect].
  static int get totalStateMutations => _observer?.totalMutations ?? 0;

  /// Per-state mutation counts (state name → count).
  ///
  /// Useful for identifying "hot" states that mutate excessively.
  ///
  /// ```dart
  /// final hot = ColossusBastion.stateHeatMap.entries
  ///     .where((e) => e.value > 100)
  ///     .map((e) => e.key);
  /// ```
  static Map<String, int> get stateHeatMap =>
      Map.unmodifiable(_observer?.stateMutations ?? {});

  /// Connects Titan's observer system to [Colossus] for automatic
  /// Pillar lifecycle and state mutation tracking.
  ///
  /// Returns `true` if the bridge was established, `false` otherwise.
  static bool connect() {
    if (_observer != null) return true; // Already connected.
    if (!Colossus.isActive) return false;

    _observer = _ColossusBastionObserver();
    TitanObserver.addObserver(_observer!);
    return true;
  }

  /// Disconnects the observer bridge.
  static void disconnect() {
    if (_observer != null) {
      TitanObserver.removeObserver(_observer!);
      _observer = null;
    }
  }
}

/// Internal observer that forwards lifecycle and error events to Colossus.
class _ColossusBastionObserver extends TitanObserver {
  int pillarInitCount = 0;
  int pillarDisposeCount = 0;
  int effectErrorCount = 0;
  int totalMutations = 0;
  final Map<String, int> stateMutations = {};

  @override
  void onStateChanged({
    required TitanState state,
    required dynamic oldValue,
    required dynamic newValue,
  }) {
    totalMutations++;
    final name = state.name ?? 'unnamed';
    stateMutations[name] = (stateMutations[name] ?? 0) + 1;
  }

  @override
  void onPillarInit(Pillar pillar) {
    pillarInitCount++;
    if (!Colossus.isActive) return;
    Colossus.instance.trackEvent({
      'source': 'bastion',
      'type': 'pillar_init',
      'pillar': pillar.runtimeType.toString(),
    });
  }

  @override
  void onPillarDispose(Pillar pillar) {
    pillarDisposeCount++;
    if (!Colossus.isActive) return;
    Colossus.instance.trackEvent({
      'source': 'bastion',
      'type': 'pillar_dispose',
      'pillar': pillar.runtimeType.toString(),
    });
  }

  @override
  void onEffectError(TitanEffect effect, Object error, StackTrace stackTrace) {
    effectErrorCount++;
    if (!Colossus.isActive) return;
    Colossus.instance.trackEvent({
      'source': 'bastion',
      'type': 'effect_error',
      'error': error.toString(),
    });
  }
}
