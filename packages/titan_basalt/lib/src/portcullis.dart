/// Portcullis — Reactive Circuit Breaker for Service Resilience.
///
/// A Portcullis monitors failure rates for external service calls and
/// automatically "trips" (opens the circuit) when failures exceed a
/// configured threshold. While open, calls are fast-failed without
/// reaching the service. After a cooldown, the circuit enters a
/// half-open state where a limited number of probe requests test
/// whether the service has recovered.
///
/// ## Why "Portcullis"?
///
/// A portcullis is a heavy fortified gate that drops to seal a
/// castle entrance when danger is detected. Titan's Portcullis
/// drops when a service fails too often, protecting your app from
/// cascading failures — and raises again once the service recovers.
///
/// ## Usage
///
/// ```dart
/// class PaymentPillar extends Pillar {
///   late final breaker = portcullis(
///     failureThreshold: 3,
///     resetTimeout: Duration(seconds: 30),
///     name: 'payment-api',
///   );
///
///   Future<Receipt> charge(double amount) async {
///     return breaker.protect(() => api.charge(amount));
///   }
/// }
/// ```
///
/// ## Features
///
/// - **Three-state circuit** — closed (healthy) → open (tripped) → half-open (probing)
/// - **Configurable thresholds** — failure count, success probes, reset timeout
/// - **Reactive state** — `state`, `failureCount`, `successCount` are live Cores
/// - **Trip history** — `tripCount`, `lastTrip`, `lastFailure` reactive audit
/// - **Custom failure test** — control which exceptions count as failures
/// - **Half-open probes** — configurable number of successes needed to close
/// - **Manual override** — `trip()` and `reset()` for manual control
/// - **Pillar integration** — `portcullis()` factory with auto-disposal
///
/// ## Circuit States
///
/// ```
///   ┌──────────┐  failures >= threshold  ┌──────────┐
///   │  CLOSED  │ ──────────────────────→ │   OPEN   │
///   │ (healthy)│                          │ (tripped)│
///   └──────────┘                          └──────────┘
///        ↑                                     │
///        │  probeSuccesses >= halfOpenMax       │ resetTimeout expires
///        │                                     ↓
///        │                               ┌──────────┐
///        └────────────────────────────── │ HALF-OPEN│
///                                        │ (probing)│
///                                        └──────────┘
///                                              │
///                        failure in half-open   │
///                        ──────────────────────→ back to OPEN
/// ```
library;

import 'dart:async';

import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Portcullis — Reactive Circuit Breaker
// ---------------------------------------------------------------------------

/// The three states of a circuit breaker.
enum PortcullisState {
  /// Circuit is closed — requests pass through normally.
  /// Failures are counted; when threshold is reached, circuit opens.
  closed,

  /// Circuit is open — requests are immediately rejected (fast-fail).
  /// After [PortcullisConfig.resetTimeout], transitions to [halfOpen].
  open,

  /// Circuit is half-open — a limited number of probe requests pass
  /// through to test service recovery. If probes succeed, circuit
  /// closes. If a probe fails, circuit re-opens.
  halfOpen,
}

/// Exception thrown when a protected call is rejected because the
/// circuit breaker is open.
class PortcullisOpenException implements Exception {
  /// Creates a circuit-open rejection exception.
  const PortcullisOpenException({this.name, this.remainingTimeout});

  /// Name of the circuit breaker that rejected the call.
  final String? name;

  /// Approximate remaining time until the circuit enters half-open.
  final Duration? remainingTimeout;

  @override
  String toString() =>
      'PortcullisOpenException: circuit${name != null ? ' "$name"' : ''} '
      'is open'
      '${remainingTimeout != null ? ' (resets in $remainingTimeout)' : ''}';
}

/// Record of a circuit trip event for audit.
class PortcullisTripRecord {
  /// Creates a trip record.
  const PortcullisTripRecord({
    required this.timestamp,
    required this.failureCount,
    this.lastError,
  });

  /// When the circuit tripped.
  final DateTime timestamp;

  /// Number of consecutive failures at trip time.
  final int failureCount;

  /// The error that caused the final failure (if available).
  final Object? lastError;

  @override
  String toString() =>
      'PortcullisTripRecord(failures: $failureCount'
      '${lastError != null ? ', error: $lastError' : ''})';
}

/// **Portcullis** — Reactive circuit breaker for service resilience.
///
/// Monitors failure rates for external calls and automatically trips
/// when failures exceed a threshold, fast-failing subsequent requests.
/// After a cooldown, probe requests test recovery.
///
/// ## Quick Usage
///
/// ```dart
/// class ApiPillar extends Pillar {
///   late final breaker = portcullis(
///     failureThreshold: 5,
///     resetTimeout: Duration(seconds: 30),
///     name: 'api',
///   );
///
///   Future<Data> fetchData() async {
///     return breaker.protect(() => api.getData());
///   }
/// }
/// ```
///
/// ## How It Works
///
/// 1. **Closed** — Calls pass through. Each failure increments the
///    counter. When failures reach [failureThreshold], the circuit
///    trips to **open**.
/// 2. **Open** — All calls are immediately rejected with
///    [PortcullisOpenException]. After [resetTimeout], the circuit
///    moves to **half-open**.
/// 3. **Half-open** — A limited number of probe calls pass through.
///    If [halfOpenMaxProbes] succeed consecutively, the circuit
///    **closes**. If any probe fails, the circuit re-**opens**.
///
/// See also:
/// - [PortcullisState] — circuit lifecycle states
/// - [PortcullisOpenException] — rejection exception
/// - [PortcullisTripRecord] — trip audit record
class Portcullis {
  /// Creates a reactive circuit breaker.
  ///
  /// - [failureThreshold] — Number of consecutive failures to trip
  ///   the circuit (default: 5).
  /// - [resetTimeout] — Duration to wait in open state before
  ///   entering half-open (default: 30 seconds).
  /// - [halfOpenMaxProbes] — Number of consecutive successful probes
  ///   needed to close the circuit (default: 1).
  /// - [shouldTrip] — Optional predicate to control which errors
  ///   count as failures. If null, all errors count.
  /// - [maxTripHistory] — Maximum trip records to retain (default: 20).
  /// - [name] — Debug name for this breaker and its reactive nodes.
  Portcullis({
    int failureThreshold = 5,
    Duration resetTimeout = const Duration(seconds: 30),
    int halfOpenMaxProbes = 1,
    bool Function(Object error, StackTrace stack)? shouldTrip,
    int maxTripHistory = 20,
    String? name,
  }) : _failureThreshold = failureThreshold,
       _resetTimeout = resetTimeout,
       _halfOpenMaxProbes = halfOpenMaxProbes,
       _shouldTrip = shouldTrip,
       _maxTripHistory = maxTripHistory,
       _name = name {
    final prefix = name ?? 'portcullis';
    _stateCore = TitanState<PortcullisState>(
      PortcullisState.closed,
      name: '${prefix}_state',
    );
    _failureCountCore = TitanState<int>(0, name: '${prefix}_failures');
    _successCountCore = TitanState<int>(0, name: '${prefix}_successes');
    _tripCountCore = TitanState<int>(0, name: '${prefix}_trips');
    _lastTripCore = TitanState<DateTime?>(null, name: '${prefix}_lastTrip');
    _lastFailureCore = TitanState<Object?>(null, name: '${prefix}_lastFailure');
    _probeSuccessCountCore = TitanState<int>(
      0,
      name: '${prefix}_probeSuccesses',
    );
    _isClosedComputed = TitanComputed<bool>(
      () => _stateCore.value == PortcullisState.closed,
      name: '${prefix}_isClosed',
    );
  }

  final int _failureThreshold;
  final Duration _resetTimeout;
  final int _halfOpenMaxProbes;
  final bool Function(Object error, StackTrace stack)? _shouldTrip;
  final int _maxTripHistory;
  final String? _name;
  bool _isDisposed = false;

  // Reactive state
  late final TitanState<PortcullisState> _stateCore;
  late final TitanState<int> _failureCountCore;
  late final TitanState<int> _successCountCore;
  late final TitanState<int> _tripCountCore;
  late final TitanState<DateTime?> _lastTripCore;
  late final TitanState<Object?> _lastFailureCore;
  late final TitanState<int> _probeSuccessCountCore;
  late final TitanComputed<bool> _isClosedComputed;

  // Timer for open → half-open transition
  Timer? _resetTimer;

  // Trip history
  final List<PortcullisTripRecord> _tripHistory = [];

  // ---------------------------------------------------------------------------
  // Reactive Properties
  // ---------------------------------------------------------------------------

  /// Current circuit state.
  PortcullisState get state => _stateCore.value;

  /// Number of consecutive failures in the current closed cycle.
  int get failureCount => _failureCountCore.value;

  /// Total successful calls since creation.
  int get successCount => _successCountCore.value;

  /// Total number of times the circuit has tripped.
  int get tripCount => _tripCountCore.value;

  /// When the circuit last tripped (null if never tripped).
  DateTime? get lastTrip => _lastTripCore.value;

  /// The last error that caused a failure (null if no failures).
  Object? get lastFailure => _lastFailureCore.value;

  /// Number of consecutive probe successes in half-open state.
  int get probeSuccessCount => _probeSuccessCountCore.value;

  /// Whether the circuit is closed (healthy).
  bool get isClosed => _isClosedComputed.value;

  /// Trip history records (most recent last).
  List<PortcullisTripRecord> get tripHistory => List.unmodifiable(_tripHistory);

  /// Debug name.
  String? get name => _name;

  /// Whether this Portcullis has been disposed.
  bool get isDisposed => _isDisposed;

  /// Failure threshold.
  int get failureThreshold => _failureThreshold;

  /// Reset timeout duration.
  Duration get resetTimeout => _resetTimeout;

  /// Half-open max probes needed to close.
  int get halfOpenMaxProbes => _halfOpenMaxProbes;

  // ---------------------------------------------------------------------------
  // Protection API
  // ---------------------------------------------------------------------------

  /// Execute [action] with circuit breaker protection.
  ///
  /// - **Closed**: Calls pass through. Success resets failure count.
  ///   Failure increments count; threshold trips circuit to open.
  /// - **Open**: Throws [PortcullisOpenException] immediately.
  /// - **Half-open**: Calls pass through as probes. Success increments
  ///   probe count; enough probes close the circuit. Failure re-opens.
  ///
  /// Returns the result of [action] on success.
  ///
  /// ```dart
  /// final data = await breaker.protect(() => api.fetchData());
  /// ```
  Future<T> protect<T>(Future<T> Function() action) async {
    _assertNotDisposed();

    switch (_stateCore.peek()) {
      case PortcullisState.open:
        throw PortcullisOpenException(
          name: _name,
          remainingTimeout: _estimateRemainingTimeout(),
        );

      case PortcullisState.closed:
        return _executeClosed(action);

      case PortcullisState.halfOpen:
        return _executeHalfOpen(action);
    }
  }

  /// Synchronous protection for non-async calls.
  ///
  /// ```dart
  /// final result = breaker.protectSync(() => cache.get(key));
  /// ```
  T protectSync<T>(T Function() action) {
    _assertNotDisposed();

    switch (_stateCore.peek()) {
      case PortcullisState.open:
        throw PortcullisOpenException(
          name: _name,
          remainingTimeout: _estimateRemainingTimeout(),
        );

      case PortcullisState.closed:
        return _executeClosedSync(action);

      case PortcullisState.halfOpen:
        return _executeHalfOpenSync(action);
    }
  }

  // ---------------------------------------------------------------------------
  // Manual Controls
  // ---------------------------------------------------------------------------

  /// Manually trip the circuit to open state.
  ///
  /// Useful for proactive protection when you detect upstream issues.
  void trip() {
    _assertNotDisposed();
    if (_stateCore.peek() == PortcullisState.open) return;
    _tripCircuit(null);
  }

  /// Manually reset the circuit to closed state.
  ///
  /// Clears failure counts and cancels any reset timer.
  void reset() {
    _assertNotDisposed();
    _closeCircuit();
  }

  // ---------------------------------------------------------------------------
  // Internal — Closed State Execution
  // ---------------------------------------------------------------------------

  Future<T> _executeClosed<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      _onSuccess();
      return result;
    } catch (e, st) {
      _onFailure(e, st);
      rethrow;
    }
  }

  T _executeClosedSync<T>(T Function() action) {
    try {
      final result = action();
      _onSuccess();
      return result;
    } catch (e, st) {
      _onFailure(e, st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — Half-Open State Execution
  // ---------------------------------------------------------------------------

  Future<T> _executeHalfOpen<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      _onProbeSuccess();
      return result;
    } catch (e, st) {
      _onProbeFailure(e, st);
      rethrow;
    }
  }

  T _executeHalfOpenSync<T>(T Function() action) {
    try {
      final result = action();
      _onProbeSuccess();
      return result;
    } catch (e, st) {
      _onProbeFailure(e, st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — State Transitions
  // ---------------------------------------------------------------------------

  void _onSuccess() {
    _failureCountCore.value = 0;
    _successCountCore.value = _successCountCore.peek() + 1;
  }

  void _onFailure(Object error, StackTrace stack) {
    // Check if this error counts as a failure
    if (_shouldTrip != null && !_shouldTrip(error, stack)) return;

    _lastFailureCore.value = error;
    final newCount = _failureCountCore.peek() + 1;
    _failureCountCore.value = newCount;

    if (newCount >= _failureThreshold) {
      _tripCircuit(error);
    }
  }

  void _onProbeSuccess() {
    _successCountCore.value = _successCountCore.peek() + 1;
    final newProbes = _probeSuccessCountCore.peek() + 1;
    _probeSuccessCountCore.value = newProbes;

    if (newProbes >= _halfOpenMaxProbes) {
      _closeCircuit();
    }
  }

  void _onProbeFailure(Object error, StackTrace stack) {
    // Check if this error counts as a failure
    if (_shouldTrip != null && !_shouldTrip(error, stack)) return;

    _lastFailureCore.value = error;
    _tripCircuit(error);
  }

  void _tripCircuit(Object? lastError) {
    _resetTimer?.cancel();
    _stateCore.value = PortcullisState.open;
    _tripCountCore.value = _tripCountCore.peek() + 1;
    _lastTripCore.value = DateTime.now();
    _probeSuccessCountCore.value = 0;

    // Record trip
    _tripHistory.add(
      PortcullisTripRecord(
        timestamp: DateTime.now(),
        failureCount: _failureCountCore.peek(),
        lastError: lastError,
      ),
    );
    while (_tripHistory.length > _maxTripHistory) {
      _tripHistory.removeAt(0);
    }

    // Schedule transition to half-open
    _resetTimer = Timer(_resetTimeout, _transitionToHalfOpen);
  }

  void _transitionToHalfOpen() {
    if (_isDisposed) return;
    _stateCore.value = PortcullisState.halfOpen;
    _probeSuccessCountCore.value = 0;
  }

  void _closeCircuit() {
    _resetTimer?.cancel();
    _stateCore.value = PortcullisState.closed;
    _failureCountCore.value = 0;
    _probeSuccessCountCore.value = 0;
  }

  // ---------------------------------------------------------------------------
  // Pillar Integration
  // ---------------------------------------------------------------------------

  /// All managed reactive computed nodes for Pillar auto-disposal.
  List<TitanComputed<dynamic>> get managedNodes => [_isClosedComputed];

  /// All managed state nodes for Pillar auto-disposal.
  List<TitanState<dynamic>> get managedStateNodes => [
    _stateCore,
    _failureCountCore,
    _successCountCore,
    _tripCountCore,
    _lastTripCore,
    _lastFailureCore,
    _probeSuccessCountCore,
  ];

  /// Dispose this Portcullis and all internal reactive nodes.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _resetTimer?.cancel();
    _resetTimer = null;
    _tripHistory.clear();
    _stateCore.dispose();
    _failureCountCore.dispose();
    _successCountCore.dispose();
    _tripCountCore.dispose();
    _lastTripCore.dispose();
    _lastFailureCore.dispose();
    _probeSuccessCountCore.dispose();
    _isClosedComputed.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Duration? _estimateRemainingTimeout() {
    final trip = _lastTripCore.peek();
    if (trip == null) return null;
    final elapsed = DateTime.now().difference(trip);
    final remaining = _resetTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use a disposed Portcullis');
    }
  }

  @override
  String toString() =>
      'Portcullis(${_name ?? 'unnamed'}, '
      'state: ${_stateCore.peek().name}, '
      'failures: ${_failureCountCore.peek()}, '
      'trips: ${_tripCountCore.peek()})';
}
