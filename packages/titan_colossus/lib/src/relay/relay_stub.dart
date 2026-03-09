/// **Relay** — Web platform stub.
///
/// Browsers cannot host HTTP servers. This stub provides the same
/// API surface but `start()` completes as a no-op with a warning.
library;

import 'dart:async';

import 'relay.dart';

/// Web stub implementation of Relay.
///
/// All methods are no-ops. [start] logs a warning and returns
/// immediately. This allows ColossusPlugin to unconditionally
/// reference Relay without conditional compilation.
class RelayPlatform {
  /// Current status — always reports not running on web.
  RelayStatus get status => const RelayStatus(isRunning: false);

  /// No-op on web. Browsers cannot host HTTP servers.
  ///
  /// This is not an error — the app functions normally without
  /// Relay on web. AI-driven campaigns can still be run by
  /// pasting JSON into the Lens Blueprint tab.
  Future<void> start({
    required RelayConfig config,
    required RelayHandler handler,
    void Function(bool connected)? onStatusChange,
  }) async {
    // Web platform cannot host HTTP servers.
    // Relay is silently disabled.
  }

  /// No-op on web.
  Future<void> stop() async {}
}
