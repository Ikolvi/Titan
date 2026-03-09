import 'package:titan_argus/titan_argus.dart';

import '../colossus.dart';

/// **ColossusArgus** — Authentication monitoring bridge between [Argus]
/// and [Colossus].
///
/// Listens to [Argus.isLoggedIn] state changes and forwards
/// authentication events to [Colossus.trackEvent] for enterprise
/// observability of auth flows.
///
/// ## Automatic (via ColossusPlugin)
///
/// When `autoArgusMetrics: true` (default), ColossusPlugin calls
/// [connect] during attach. No user code needed:
///
/// ```dart
/// class AppAuth extends Argus { ... }
///
/// // Register auth in DI:
/// Titan.put<Argus>(AppAuth());
///
/// runApp(
///   Beacon(
///     plugins: [ColossusPlugin()],
///     child: MyApp(),
///   ),
/// );
/// // ↑ Colossus tracks login/logout events automatically.
/// ```
///
/// ## Manual
///
/// ```dart
/// ColossusArgus.connect();
/// ```
///
/// ## Tracked Events
///
/// | Event Type | Source | When |
/// |------------|--------|------|
/// | `login` | `argus` | `isLoggedIn` changes to `true` |
/// | `logout` | `argus` | `isLoggedIn` changes to `false` |
class ColossusArgus {
  ColossusArgus._();

  static void Function()? _dispose;

  /// Whether Argus auth events are currently being forwarded to Colossus.
  static bool get isConnected => _dispose != null;

  // ── Counters & timestamps ──────────────────────────────────────────

  /// Total login events observed since [connect].
  static int get loginCount => _loginCount;
  static int _loginCount = 0;

  /// Total logout events observed since [connect].
  static int get logoutCount => _logoutCount;
  static int _logoutCount = 0;

  /// Timestamp of the most recent login event, or `null`.
  static DateTime? get lastLoginTime => _lastLoginTime;
  static DateTime? _lastLoginTime;

  /// Timestamp of the most recent logout event, or `null`.
  static DateTime? get lastLogoutTime => _lastLogoutTime;
  static DateTime? _lastLogoutTime;

  /// Start of the current authenticated session, or `null` if logged out.
  static DateTime? get currentSessionStart => _currentSessionStart;
  static DateTime? _currentSessionStart;

  /// Durations of completed sessions (login → logout), newest last.
  static List<Duration> get sessionDurations =>
      List.unmodifiable(_sessionDurations);
  static final List<Duration> _sessionDurations = [];

  /// Connects the DI-registered [Argus] to [Colossus] for automatic
  /// auth event tracking.
  ///
  /// If no [Argus] is registered in Titan DI, or [Colossus] is not
  /// active, this is a no-op — graceful degradation.
  ///
  /// Returns `true` if the bridge was established, `false` otherwise.
  static bool connect() {
    if (_dispose != null) return true; // Already connected.

    try {
      final argus = Titan.find<Argus>();
      // ignore: unnecessary_null_comparison
      if (argus == null) return false;
    } on StateError {
      return false;
    }

    if (!Colossus.isActive) return false;

    final argus = Titan.get<Argus>();
    _dispose = argus.isLoggedIn.listen((loggedIn) {
      if (!Colossus.isActive) return;

      final now = DateTime.now();

      if (loggedIn) {
        _loginCount++;
        _lastLoginTime = now;
        _currentSessionStart = now;
      } else {
        _logoutCount++;
        _lastLogoutTime = now;
        if (_currentSessionStart != null) {
          _sessionDurations.add(now.difference(_currentSessionStart!));
          _currentSessionStart = null;
        }
      }

      Colossus.instance.trackEvent({
        'source': 'argus',
        'type': loggedIn ? 'login' : 'logout',
      });
    });

    return true;
  }

  /// Disconnects the auth event bridge.
  static void disconnect() {
    _dispose?.call();
    _dispose = null;
    _loginCount = 0;
    _logoutCount = 0;
    _lastLoginTime = null;
    _lastLogoutTime = null;
    _currentSessionStart = null;
    _sessionDurations.clear();
  }
}
