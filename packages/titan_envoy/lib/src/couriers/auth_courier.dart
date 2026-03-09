import 'dart:async';

import '../courier.dart';
import '../dispatch.dart';
import '../envoy_error.dart';
import '../missive.dart';

/// A [Courier] that automatically injects authentication tokens into requests.
///
/// Supports automatic token refresh on 401 Unauthorized responses. The
/// token provider and refresh callbacks are decoupled — connect to Argus
/// or any auth system via callbacks.
///
/// ```dart
/// envoy.addCourier(AuthCourier(
///   tokenProvider: () async => authService.accessToken,
///   onUnauthorized: () async {
///     await authService.refreshToken();
///     return authService.accessToken;
///   },
/// ));
/// ```
class AuthCourier extends Courier {
  /// Creates an [AuthCourier] with the given token callbacks.
  ///
  /// - [tokenProvider]: Returns the current auth token.
  /// - [headerName]: The header to set (default: `'Authorization'`).
  /// - [tokenPrefix]: Prefix before the token (default: `'Bearer '`).
  /// - [onUnauthorized]: Called when a 401 is received. Should refresh
  ///   the token and return the new one. The request is then retried.
  /// - [maxRefreshAttempts]: Maximum 401 → refresh → retry cycles (default: 1).
  AuthCourier({
    required this.tokenProvider,
    this.headerName = 'Authorization',
    this.tokenPrefix = 'Bearer ',
    this.onUnauthorized,
    this.maxRefreshAttempts = 1,
  });

  /// Returns the current authentication token.
  final FutureOr<String?> Function() tokenProvider;

  /// The header name for the auth token.
  final String headerName;

  /// Prefix added before the token value (e.g., `'Bearer '`).
  final String tokenPrefix;

  /// Called when a 401 response is received.
  ///
  /// Should refresh the token and return the new token string.
  /// If `null`, 401 errors are not automatically retried.
  final FutureOr<String?> Function()? onUnauthorized;

  /// Maximum number of refresh-and-retry cycles for 401 responses.
  final int maxRefreshAttempts;

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    // Skip auth for requests that already have the header
    if (missive.headers.containsKey(headerName)) {
      return chain.proceed(missive);
    }

    // Inject token
    var authenticatedMissive = await _injectToken(missive);
    var refreshAttempts = 0;

    while (true) {
      try {
        final dispatch = await chain.proceed(authenticatedMissive);

        // Handle 401 with automatic refresh
        if (dispatch.statusCode == 401 &&
            onUnauthorized != null &&
            refreshAttempts < maxRefreshAttempts) {
          refreshAttempts++;
          final newToken = await onUnauthorized!();
          if (newToken != null) {
            authenticatedMissive = _setAuthHeader(missive, newToken);
            continue;
          }
        }

        return dispatch;
      } on EnvoyError catch (e) {
        if (e.type == EnvoyErrorType.badResponse &&
            e.dispatch?.statusCode == 401 &&
            onUnauthorized != null &&
            refreshAttempts < maxRefreshAttempts) {
          refreshAttempts++;
          final newToken = await onUnauthorized!();
          if (newToken != null) {
            authenticatedMissive = _setAuthHeader(missive, newToken);
            continue;
          }
        }
        rethrow;
      }
    }
  }

  Future<Missive> _injectToken(Missive missive) async {
    final token = await tokenProvider();
    if (token == null || token.isEmpty) return missive;
    return _setAuthHeader(missive, token);
  }

  Missive _setAuthHeader(Missive missive, String token) {
    return missive.copyWith(
      headers: {...missive.headers, headerName: '$tokenPrefix$token'},
    );
  }
}
