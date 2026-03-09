import 'dispatch.dart';
import 'missive.dart';

/// Types of errors that can occur during an [Envoy] request.
enum EnvoyErrorType {
  /// The connection to the server could not be established.
  connectionError,

  /// The request timed out (connect, send, or receive timeout).
  timeout,

  /// The request was cancelled via a [Recall] token.
  cancelled,

  /// The server returned an error status code (4xx or 5xx).
  badResponse,

  /// The response body could not be parsed.
  parseError,

  /// An unknown or unexpected error occurred.
  unknown,
}

/// An error that occurred during an [Envoy] HTTP operation.
///
/// ```dart
/// try {
///   await envoy.get('/protected');
/// } on EnvoyError catch (e) {
///   switch (e.type) {
///     case EnvoyErrorType.timeout:
///       print('Request timed out after ${e.missive.receiveTimeout}');
///     case EnvoyErrorType.badResponse:
///       print('Server error: ${e.dispatch?.statusCode}');
///     case EnvoyErrorType.cancelled:
///       print('Request was recalled');
///     default:
///       print('Network error: ${e.message}');
///   }
/// }
/// ```
class EnvoyError implements Exception {
  /// Creates an [EnvoyError] with the given parameters.
  EnvoyError({
    required this.type,
    required this.missive,
    this.dispatch,
    this.error,
    this.stackTrace,
    String? message,
  }) : message = message ?? _defaultMessage(type);

  /// Creates a connection error.
  factory EnvoyError.connectionError({
    required Missive missive,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return EnvoyError(
      type: EnvoyErrorType.connectionError,
      missive: missive,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Creates a timeout error.
  factory EnvoyError.timeout({
    required Missive missive,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return EnvoyError(
      type: EnvoyErrorType.timeout,
      missive: missive,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Creates a cancellation error.
  factory EnvoyError.cancelled({required Missive missive}) {
    return EnvoyError(type: EnvoyErrorType.cancelled, missive: missive);
  }

  /// Creates a bad response error.
  factory EnvoyError.badResponse({
    required Missive missive,
    required Dispatch dispatch,
  }) {
    return EnvoyError(
      type: EnvoyErrorType.badResponse,
      missive: missive,
      dispatch: dispatch,
      message: 'Bad response: ${dispatch.statusCode}',
    );
  }

  /// Creates a parse error.
  factory EnvoyError.parseError({
    required Missive missive,
    Dispatch? dispatch,
    Object? error,
    StackTrace? stackTrace,
  }) {
    return EnvoyError(
      type: EnvoyErrorType.parseError,
      missive: missive,
      dispatch: dispatch,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// The type of error that occurred.
  final EnvoyErrorType type;

  /// The [Missive] that caused this error.
  final Missive missive;

  /// The [Dispatch] response, if one was received.
  ///
  /// Available for [EnvoyErrorType.badResponse] errors.
  final Dispatch? dispatch;

  /// The underlying error, if any.
  final Object? error;

  /// The stack trace of the error.
  final StackTrace? stackTrace;

  /// Human-readable error message.
  final String message;

  static String _defaultMessage(EnvoyErrorType type) {
    return switch (type) {
      EnvoyErrorType.connectionError => 'Connection failed',
      EnvoyErrorType.timeout => 'Request timed out',
      EnvoyErrorType.cancelled => 'Request was recalled',
      EnvoyErrorType.badResponse => 'Bad response from server',
      EnvoyErrorType.parseError => 'Failed to parse response',
      EnvoyErrorType.unknown => 'An unknown error occurred',
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer('EnvoyError [${type.name}]: $message');
    buffer.write(' | ${missive.method.verb} ${missive.resolvedUri}');
    if (dispatch != null) {
      buffer.write(' → ${dispatch!.statusCode}');
    }
    if (error != null) {
      buffer.write(' | Cause: $error');
    }
    return buffer.toString();
  }
}
