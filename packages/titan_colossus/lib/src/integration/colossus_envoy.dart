import 'package:titan/titan.dart';
import 'package:titan_envoy/titan_envoy.dart';

import '../colossus.dart';

/// **ColossusEnvoy** — Zero-config bridge between [Envoy] and [Colossus].
///
/// Automatically wires a [MetricsCourier] to the DI-registered [Envoy]
/// so every HTTP request is forwarded to [Colossus.trackApiMetric].
///
/// ## Automatic (via ColossusPlugin)
///
/// When `autoEnvoyMetrics: true` (default), ColossusPlugin calls
/// [connect] during attach. No user code needed:
///
/// ```dart
/// // main.dart
/// EnvoyModule.production(baseUrl: 'https://api.example.com');
///
/// runApp(
///   Beacon(
///     plugins: [ColossusPlugin()],
///     child: MyApp(),
///   ),
/// );
/// // ↑ Colossus now tracks every Envoy request automatically.
/// ```
///
/// ## Manual
///
/// Call [connect] after both [EnvoyModule.install] and [Colossus.init]:
///
/// ```dart
/// ColossusEnvoy.connect();
/// ```
///
/// Call [disconnect] to stop metric forwarding:
///
/// ```dart
/// ColossusEnvoy.disconnect();
/// ```
class ColossusEnvoy {
  ColossusEnvoy._();

  static MetricsCourier? _courier;

  /// Whether Envoy metrics are currently being forwarded to Colossus.
  static bool get isConnected => _courier != null;

  /// Connects the DI-registered [Envoy] to [Colossus] for automatic
  /// API metric tracking.
  ///
  /// If no [Envoy] is registered in Titan DI, or [Colossus] is not
  /// active, this is a no-op — graceful degradation.
  ///
  /// Returns `true` if the bridge was established, `false` otherwise.
  ///
  /// ```dart
  /// // After EnvoyModule.install() and Colossus.init():
  /// ColossusEnvoy.connect();
  /// ```
  static bool connect() {
    if (_courier != null) return true; // Already connected.

    final envoy = Titan.find<Envoy>();
    if (envoy == null) return false;
    if (!Colossus.isActive) return false;

    _courier = MetricsCourier(
      onMetric: (metric) {
        if (Colossus.isActive) {
          Colossus.instance.trackApiMetric(metric.toJson());
        }
      },
    );

    envoy.addCourier(_courier!);
    return true;
  }

  /// Disconnects Envoy metric forwarding to Colossus.
  ///
  /// After calling this, HTTP requests are no longer tracked
  /// by Colossus. The [MetricsCourier] is removed from the
  /// DI-registered [Envoy].
  ///
  /// Safe to call even if not connected — no-op.
  static void disconnect() {
    if (_courier == null) return;

    final envoy = Titan.find<Envoy>();
    if (envoy != null) {
      envoy.removeCourier(_courier!);
    }

    _courier = null;
  }
}
