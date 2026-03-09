import 'dart:async';

/// A Recall token allows cancelling one or more in-flight [Envoy] requests.
///
/// Pass a [Recall] to a request's [Missive.recall] parameter. When [cancel]
/// is called, all requests sharing this token will be aborted with an
/// [EnvoyError] of type [EnvoyErrorType.cancelled].
///
/// ```dart
/// final recall = Recall();
///
/// // Start a long request
/// final future = envoy.get('/slow', recall: recall);
///
/// // Cancel it after 2 seconds
/// Timer(Duration(seconds: 2), () => recall.cancel('Too slow'));
///
/// try {
///   await future;
/// } on EnvoyError catch (e) {
///   print(e.type); // EnvoyErrorType.cancelled
///   print(recall.reason); // 'Too slow'
/// }
/// ```
class Recall {
  final Completer<String?> _completer = Completer<String?>();

  /// Whether this token has been cancelled.
  bool get isCancelled => _completer.isCompleted;

  /// The cancellation reason, or `null` if not cancelled.
  String? _reason;

  /// The cancellation reason, or `null` if not yet cancelled.
  String? get reason => _reason;

  /// Cancels all requests using this token.
  ///
  /// [reason] is an optional message describing why the request was recalled.
  void cancel([String? reason]) {
    if (!_completer.isCompleted) {
      _reason = reason;
      _completer.complete(reason);
    }
  }

  /// A [Future] that completes when this token is cancelled.
  ///
  /// Used internally by [Envoy] to race against the HTTP request.
  Future<String?> get whenCancelled => _completer.future;

  /// Throws [EnvoyError.cancelled] if this token has already been cancelled.
  ///
  /// Call this at checkpoints during request processing to fail fast.
  void throwIfCancelled(dynamic missive) {
    if (isCancelled) {
      throw _CancelledException(reason);
    }
  }
}

/// Internal exception used to signal cancellation within the Envoy pipeline.
///
/// Caught and converted to [EnvoyError.cancelled] before surfacing to callers.
class _CancelledException implements Exception {
  const _CancelledException(this.reason);

  /// The cancellation reason.
  final String? reason;

  @override
  String toString() => 'Request recalled${reason != null ? ': $reason' : ''}';
}
