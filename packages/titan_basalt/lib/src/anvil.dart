/// Anvil — Reactive Dead Letter & Retry Queue.
///
/// An Anvil queues failed operations and retries them with configurable
/// backoff strategies (exponential, linear, constant — all with optional
/// jitter). Operations that exhaust retries move to a dead-letter state
/// for manual inspection and replay.
///
/// ## Why "Anvil"?
///
/// An anvil is where broken things are hammered back into shape. Titan's
/// Anvil takes broken operations — failed API calls, dropped syncs,
/// rejected submissions — and hammers at them with automatic retries
/// until they succeed or are set aside for manual repair.
///
/// ## Usage
///
/// ```dart
/// class OrderPillar extends Pillar {
///   late final retryQueue = anvil<String>(
///     maxRetries: 5,
///     backoff: AnvilBackoff.exponential(),
///     name: 'order-retry',
///   );
///
///   Future<void> submitOrder(Order order) async {
///     try {
///       await api.submit(order);
///     } catch (e) {
///       retryQueue.enqueue(
///         () => api.submit(order).then((_) => 'ok'),
///         id: order.id,
///       );
///     }
///   }
/// }
/// ```
///
/// ## Features
///
/// - **Configurable backoff** — exponential, linear, or constant delay
///   with optional jitter for thundering-herd prevention
/// - **Dead letter queue** — exhausted entries land in a dead-letter
///   list for manual inspection, replay, or purge
/// - **Reactive state** — `pendingCount`, `deadLetterCount`,
///   `succeededCount`, `retryingCount` are live Cores
/// - **Manual replay** — `retryDeadLetters()` re-enqueues dead entries
/// - **Purge** — `purge()` clears dead letters, `clear()` clears all
/// - **Pillar integration** — `anvil()` factory with auto-disposal
///
/// ## Entry Lifecycle
///
/// ```
///   ┌───────────┐   success    ┌───────────┐
///   │  PENDING  │ ──────────→ │ SUCCEEDED │
///   │           │              └───────────┘
///   └───────────┘
///        │
///        │ failure (retries remain)
///        ↓
///   ┌───────────┐   success    ┌───────────┐
///   │ RETRYING  │ ──────────→ │ SUCCEEDED │
///   │           │              └───────────┘
///   └───────────┘
///        │
///        │ failure (no retries left)
///        ↓
///   ┌───────────────┐
///   │ DEAD_LETTERED │ → manual retryDeadLetters()
///   └───────────────┘
/// ```
library;

import 'dart:async';
import 'dart:math';

import 'package:titan/titan.dart';

// ---------------------------------------------------------------------------
// Anvil — Reactive Dead Letter & Retry Queue
// ---------------------------------------------------------------------------

/// Status of an [AnvilEntry] in the retry lifecycle.
enum AnvilStatus {
  /// Entry is queued, waiting for its next attempt.
  pending,

  /// Entry is currently executing a retry attempt.
  retrying,

  /// Entry has succeeded — operation completed without error.
  succeeded,

  /// Entry has exhausted all retries and moved to dead letter.
  deadLettered,
}

/// Configurable backoff strategy for retry delays.
///
/// Supports exponential, linear, and constant backoff with optional
/// jitter to prevent thundering-herd problems.
///
/// ## Examples
///
/// ```dart
/// // Exponential: 1s, 2s, 4s, 8s, 16s...
/// AnvilBackoff.exponential(
///   initial: Duration(seconds: 1),
///   multiplier: 2.0,
/// );
///
/// // Linear: 500ms, 1000ms, 1500ms, 2000ms...
/// AnvilBackoff.linear(
///   initial: Duration(milliseconds: 500),
///   increment: Duration(milliseconds: 500),
/// );
///
/// // Constant: 2s, 2s, 2s...
/// AnvilBackoff.constant(Duration(seconds: 2));
///
/// // With jitter (adds up to 25% random variation)
/// AnvilBackoff.exponential(jitter: true);
/// ```
class AnvilBackoff {
  /// Creates a custom backoff configuration.
  const AnvilBackoff._({
    required this.initial,
    required this.computeDelay,
    this.jitter = false,
    this.maxDelay,
  });

  /// Exponential backoff: delay doubles (or multiplies) each attempt.
  ///
  /// - [initial] — First delay (default: 1 second).
  /// - [multiplier] — Factor applied each attempt (default: 2.0).
  /// - [jitter] — If true, adds up to 25% random variation.
  /// - [maxDelay] — Upper bound for delay (default: no limit).
  factory AnvilBackoff.exponential({
    Duration initial = const Duration(seconds: 1),
    double multiplier = 2.0,
    bool jitter = false,
    Duration? maxDelay,
  }) {
    return AnvilBackoff._(
      initial: initial,
      jitter: jitter,
      maxDelay: maxDelay,
      computeDelay: (attempt) {
        final ms = initial.inMicroseconds * pow(multiplier, attempt);
        return Duration(microseconds: ms.toInt());
      },
    );
  }

  /// Linear backoff: delay increases by a fixed increment each attempt.
  ///
  /// - [initial] — First delay (default: 500ms).
  /// - [increment] — Added per attempt (default: 500ms).
  /// - [jitter] — If true, adds up to 25% random variation.
  /// - [maxDelay] — Upper bound for delay (default: no limit).
  factory AnvilBackoff.linear({
    Duration initial = const Duration(milliseconds: 500),
    Duration increment = const Duration(milliseconds: 500),
    bool jitter = false,
    Duration? maxDelay,
  }) {
    return AnvilBackoff._(
      initial: initial,
      jitter: jitter,
      maxDelay: maxDelay,
      computeDelay: (attempt) {
        return initial + increment * attempt;
      },
    );
  }

  /// Constant backoff: same delay every attempt.
  ///
  /// - [delay] — Fixed delay between attempts.
  /// - [jitter] — If true, adds up to 25% random variation.
  factory AnvilBackoff.constant(Duration delay, {bool jitter = false}) {
    return AnvilBackoff._(
      initial: delay,
      jitter: jitter,
      computeDelay: (_) => delay,
    );
  }

  /// Initial delay for the first retry.
  final Duration initial;

  /// Whether to add random jitter (up to 25% of computed delay).
  final bool jitter;

  /// Optional maximum delay cap.
  final Duration? maxDelay;

  /// Function that computes delay for a given attempt number (0-based).
  final Duration Function(int attempt) computeDelay;

  /// Calculate the delay for a given attempt number (0-based).
  ///
  /// Applies jitter and maxDelay cap if configured.
  Duration delayFor(int attempt, [Random? rng]) {
    var delay = computeDelay(attempt);

    // Cap at maxDelay
    if (maxDelay != null && delay > maxDelay!) {
      delay = maxDelay!;
    }

    // Apply jitter (up to 25% variation)
    if (jitter) {
      final random = rng ?? Random();
      final jitterFactor = 1.0 + (random.nextDouble() * 0.5 - 0.25);
      delay = Duration(
        microseconds: (delay.inMicroseconds * jitterFactor).toInt(),
      );
    }

    return delay;
  }

  @override
  String toString() =>
      'AnvilBackoff(initial: $initial, jitter: $jitter'
      '${maxDelay != null ? ', maxDelay: $maxDelay' : ''})';
}

/// A single entry in the retry queue.
///
/// Tracks the operation to retry, its status, attempt count, and
/// any associated metadata.
class AnvilEntry<T> {
  /// Creates a retry queue entry.
  AnvilEntry({
    required this.operation,
    required this.maxRetries,
    required this.enqueueTime,
    this.id,
    this.metadata,
    this.onSuccess,
    this.onDeadLetter,
  });

  /// Unique identifier for this entry (optional, for lookup/dedup).
  final String? id;

  /// The async operation to retry.
  final Future<T> Function() operation;

  /// Maximum number of retry attempts.
  final int maxRetries;

  /// When this entry was first enqueued.
  final DateTime enqueueTime;

  /// Optional metadata for debugging/audit.
  final Map<String, dynamic>? metadata;

  /// Callback invoked on successful completion.
  final void Function(T result)? onSuccess;

  /// Callback invoked when entry moves to dead letter.
  final void Function(AnvilEntry<T> entry)? onDeadLetter;

  /// Current status of this entry.
  AnvilStatus status = AnvilStatus.pending;

  /// Number of attempts made (including the initial attempt).
  int attempts = 0;

  /// Last error encountered during a retry attempt.
  Object? lastError;

  /// Stack trace from the last error.
  StackTrace? lastStackTrace;

  /// Timestamp of the last attempt.
  DateTime? lastAttemptTime;

  /// Result value if operation succeeded.
  T? result;

  @override
  String toString() =>
      'AnvilEntry(${id ?? 'unnamed'}, '
      'status: ${status.name}, '
      'attempts: $attempts/$maxRetries)';
}

/// **Anvil** — Reactive dead letter & retry queue.
///
/// Queues failed operations and retries them with configurable backoff
/// strategies. Operations that exhaust retries move to a dead-letter
/// state for manual inspection and replay.
///
/// ## Quick Usage
///
/// ```dart
/// class SyncPillar extends Pillar {
///   late final retryQueue = anvil<String>(
///     maxRetries: 3,
///     backoff: AnvilBackoff.exponential(),
///     name: 'sync-retry',
///   );
///
///   Future<void> syncData(String payload) async {
///     try {
///       await api.sync(payload);
///     } catch (e) {
///       retryQueue.enqueue(
///         () => api.sync(payload).then((_) => 'synced'),
///         id: 'sync-$payload',
///       );
///     }
///   }
/// }
/// ```
///
/// ## How It Works
///
/// 1. **Enqueue** — A failed operation is added to the queue.
/// 2. **Retry** — The queue processes entries with backoff delays.
///    Each attempt increments the attempt counter.
/// 3. **Success** — Entry moves to succeeded, callbacks fire.
/// 4. **Dead Letter** — If max retries exhausted, entry moves to
///    dead-letter for manual inspection.
/// 5. **Replay** — Dead letters can be manually re-enqueued.
///
/// See also:
/// - [AnvilBackoff] — backoff strategy configuration
/// - [AnvilEntry] — individual queue entry
/// - [AnvilStatus] — entry lifecycle states
class Anvil<T> {
  /// Creates a reactive dead letter & retry queue.
  ///
  /// - [maxRetries] — Maximum retry attempts per entry (default: 3).
  /// - [backoff] — Backoff strategy (default: exponential with 1s
  ///   initial and 2x multiplier).
  /// - [maxDeadLetters] — Max dead-letter entries to retain
  ///   (default: 100).
  /// - [autoStart] — Whether to begin processing immediately on
  ///   enqueue (default: true).
  /// - [name] — Debug name for this queue and its reactive nodes.
  Anvil({
    int maxRetries = 3,
    AnvilBackoff? backoff,
    int maxDeadLetters = 100,
    bool autoStart = true,
    String? name,
  }) : _maxRetries = maxRetries,
       _backoff = backoff ?? AnvilBackoff.exponential(),
       _maxDeadLetters = maxDeadLetters,
       _autoStart = autoStart,
       _name = name {
    final prefix = name ?? 'anvil';
    _pendingCountCore = TitanState<int>(0, name: '${prefix}_pending');
    _retryingCountCore = TitanState<int>(0, name: '${prefix}_retrying');
    _succeededCountCore = TitanState<int>(0, name: '${prefix}_succeeded');
    _deadLetterCountCore = TitanState<int>(0, name: '${prefix}_deadLetters');
    _totalEnqueuedCore = TitanState<int>(0, name: '${prefix}_totalEnqueued');
    _isProcessingComputed = TitanComputed<bool>(
      () => _retryingCountCore.value > 0 || _pendingCountCore.value > 0,
      name: '${prefix}_isProcessing',
    );
  }

  final int _maxRetries;
  final AnvilBackoff _backoff;
  final int _maxDeadLetters;
  final bool _autoStart;
  final String? _name;
  bool _isDisposed = false;

  // Reactive state
  late final TitanState<int> _pendingCountCore;
  late final TitanState<int> _retryingCountCore;
  late final TitanState<int> _succeededCountCore;
  late final TitanState<int> _deadLetterCountCore;
  late final TitanState<int> _totalEnqueuedCore;
  late final TitanComputed<bool> _isProcessingComputed;

  // Queues
  final List<AnvilEntry<T>> _pendingQueue = [];
  final List<AnvilEntry<T>> _deadLetters = [];
  final List<AnvilEntry<T>> _succeeded = [];

  // Active timers
  final List<Timer> _activeTimers = [];

  // ---------------------------------------------------------------------------
  // Reactive Properties
  // ---------------------------------------------------------------------------

  /// Number of entries waiting to be retried.
  int get pendingCount => _pendingCountCore.value;

  /// Number of entries currently being retried.
  int get retryingCount => _retryingCountCore.value;

  /// Total number of entries that have succeeded.
  int get succeededCount => _succeededCountCore.value;

  /// Number of entries in the dead letter queue.
  int get deadLetterCount => _deadLetterCountCore.value;

  /// Total number of entries ever enqueued.
  int get totalEnqueued => _totalEnqueuedCore.value;

  /// Whether the queue is actively processing entries.
  bool get isProcessing => _isProcessingComputed.value;

  /// Entries currently in the pending queue.
  List<AnvilEntry<T>> get pending => List.unmodifiable(_pendingQueue);

  /// Entries that have been dead-lettered.
  List<AnvilEntry<T>> get deadLetters => List.unmodifiable(_deadLetters);

  /// Entries that have succeeded.
  List<AnvilEntry<T>> get succeeded => List.unmodifiable(_succeeded);

  /// Debug name.
  String? get name => _name;

  /// Whether this Anvil has been disposed.
  bool get isDisposed => _isDisposed;

  /// Max retries per entry.
  int get maxRetries => _maxRetries;

  // ---------------------------------------------------------------------------
  // Enqueue
  // ---------------------------------------------------------------------------

  /// Add a failed operation to the retry queue.
  ///
  /// The operation will be retried according to the configured backoff
  /// strategy until it succeeds or exhausts [maxRetries].
  ///
  /// - [operation] — The async operation to retry.
  /// - [id] — Optional unique identifier for dedup/lookup.
  /// - [metadata] — Optional metadata for debugging/audit.
  /// - [onSuccess] — Callback when the operation succeeds.
  /// - [onDeadLetter] — Callback when the entry is dead-lettered.
  /// - [maxRetries] — Override max retries for this entry (null = use
  ///   queue default).
  ///
  /// Returns the created [AnvilEntry].
  ///
  /// ```dart
  /// queue.enqueue(
  ///   () => api.submit(order),
  ///   id: 'order-${order.id}',
  ///   metadata: {'orderId': order.id},
  ///   onDeadLetter: (e) => log.error('Order failed: ${e.id}'),
  /// );
  /// ```
  AnvilEntry<T> enqueue(
    Future<T> Function() operation, {
    String? id,
    Map<String, dynamic>? metadata,
    void Function(T result)? onSuccess,
    void Function(AnvilEntry<T> entry)? onDeadLetter,
    int? maxRetries,
  }) {
    _assertNotDisposed();

    final entry = AnvilEntry<T>(
      operation: operation,
      maxRetries: maxRetries ?? _maxRetries,
      enqueueTime: DateTime.now(),
      id: id,
      metadata: metadata,
      onSuccess: onSuccess,
      onDeadLetter: onDeadLetter,
    );

    _pendingQueue.add(entry);
    _pendingCountCore.value = _pendingQueue.length;
    _totalEnqueuedCore.value = _totalEnqueuedCore.peek() + 1;

    if (_autoStart) {
      _scheduleRetry(entry, 0);
    }

    return entry;
  }

  // ---------------------------------------------------------------------------
  // Process / Retry
  // ---------------------------------------------------------------------------

  /// Manually trigger processing of all pending entries.
  ///
  /// This is only needed when [autoStart] is false.
  void processAll() {
    _assertNotDisposed();
    for (final entry in _pendingQueue.toList()) {
      if (entry.status == AnvilStatus.pending) {
        _scheduleRetry(entry, entry.attempts);
      }
    }
  }

  /// Retry all dead-lettered entries by re-enqueuing them.
  ///
  /// Entries are moved back to pending and processed with fresh
  /// attempt counts.
  ///
  /// Returns the number of entries re-enqueued.
  ///
  /// ```dart
  /// final count = queue.retryDeadLetters();
  /// print('Re-enqueued $count dead letters');
  /// ```
  int retryDeadLetters() {
    _assertNotDisposed();
    if (_deadLetters.isEmpty) return 0;

    final count = _deadLetters.length;
    final entries = _deadLetters.toList();
    _deadLetters.clear();
    _deadLetterCountCore.value = 0;

    for (final entry in entries) {
      entry.status = AnvilStatus.pending;
      entry.attempts = 0;
      entry.lastError = null;
      entry.lastStackTrace = null;
      _pendingQueue.add(entry);
    }

    _pendingCountCore.value = _pendingQueue.length;

    if (_autoStart) {
      for (final entry in entries) {
        _scheduleRetry(entry, 0);
      }
    }

    return count;
  }

  // ---------------------------------------------------------------------------
  // Clear / Purge
  // ---------------------------------------------------------------------------

  /// Remove all dead-lettered entries.
  ///
  /// Returns the number of entries purged.
  int purge() {
    _assertNotDisposed();
    final count = _deadLetters.length;
    _deadLetters.clear();
    _deadLetterCountCore.value = 0;
    return count;
  }

  /// Remove all entries from all queues and cancel active timers.
  void clear() {
    _assertNotDisposed();
    _cancelAllTimers();
    _pendingQueue.clear();
    _deadLetters.clear();
    _succeeded.clear();
    _pendingCountCore.value = 0;
    _retryingCountCore.value = 0;
    _deadLetterCountCore.value = 0;
  }

  /// Remove a specific entry by ID from pending or dead letter queue.
  ///
  /// Returns true if the entry was found and removed.
  bool remove(String id) {
    _assertNotDisposed();

    final pendingIdx = _pendingQueue.indexWhere((e) => e.id == id);
    if (pendingIdx != -1) {
      _pendingQueue.removeAt(pendingIdx);
      _pendingCountCore.value = _pendingQueue.length;
      return true;
    }

    final deadIdx = _deadLetters.indexWhere((e) => e.id == id);
    if (deadIdx != -1) {
      _deadLetters.removeAt(deadIdx);
      _deadLetterCountCore.value = _deadLetters.length;
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Find an entry by ID across all queues.
  ///
  /// Returns null if not found.
  AnvilEntry<T>? findById(String id) {
    for (final entry in _pendingQueue) {
      if (entry.id == id) return entry;
    }
    for (final entry in _deadLetters) {
      if (entry.id == id) return entry;
    }
    for (final entry in _succeeded) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Internal — Retry Scheduling
  // ---------------------------------------------------------------------------

  void _scheduleRetry(AnvilEntry<T> entry, int attempt) {
    if (_isDisposed) return;

    final delay = attempt == 0 ? Duration.zero : _backoff.delayFor(attempt - 1);

    if (delay == Duration.zero) {
      _executeRetry(entry);
    } else {
      final timer = Timer(delay, () {
        _executeRetry(entry);
      });
      _activeTimers.add(timer);
    }
  }

  Future<void> _executeRetry(AnvilEntry<T> entry) async {
    if (_isDisposed) return;
    if (entry.status == AnvilStatus.succeeded ||
        entry.status == AnvilStatus.deadLettered) {
      return;
    }

    entry.status = AnvilStatus.retrying;
    entry.attempts++;
    entry.lastAttemptTime = DateTime.now();
    _retryingCountCore.value = _retryingCountCore.peek() + 1;

    try {
      final result = await entry.operation();
      if (_isDisposed) return;

      // Success
      entry.status = AnvilStatus.succeeded;
      entry.result = result;
      _pendingQueue.remove(entry);
      _succeeded.add(entry);
      _pendingCountCore.value = _pendingQueue.length;
      _retryingCountCore.value = max(0, _retryingCountCore.peek() - 1);
      _succeededCountCore.value = _succeededCountCore.peek() + 1;

      entry.onSuccess?.call(result);
    } catch (e, st) {
      if (_isDisposed) return;

      entry.lastError = e;
      entry.lastStackTrace = st;
      _retryingCountCore.value = max(0, _retryingCountCore.peek() - 1);

      if (entry.attempts >= entry.maxRetries) {
        // Dead letter
        _deadLetter(entry);
      } else {
        // Schedule next retry
        entry.status = AnvilStatus.pending;
        _scheduleRetry(entry, entry.attempts);
      }
    }
  }

  void _deadLetter(AnvilEntry<T> entry) {
    entry.status = AnvilStatus.deadLettered;
    _pendingQueue.remove(entry);
    _deadLetters.add(entry);

    // Enforce max dead letters
    while (_deadLetters.length > _maxDeadLetters) {
      _deadLetters.removeAt(0);
    }

    _pendingCountCore.value = _pendingQueue.length;
    _deadLetterCountCore.value = _deadLetters.length;

    entry.onDeadLetter?.call(entry);
  }

  void _cancelAllTimers() {
    for (final timer in _activeTimers) {
      timer.cancel();
    }
    _activeTimers.clear();
  }

  // ---------------------------------------------------------------------------
  // Pillar Integration
  // ---------------------------------------------------------------------------

  /// All managed reactive computed nodes for Pillar auto-disposal.
  List<TitanComputed<dynamic>> get managedNodes => [_isProcessingComputed];

  /// All managed state nodes for Pillar auto-disposal.
  List<TitanState<dynamic>> get managedStateNodes => [
    _pendingCountCore,
    _retryingCountCore,
    _succeededCountCore,
    _deadLetterCountCore,
    _totalEnqueuedCore,
  ];

  /// Dispose this Anvil and all internal reactive nodes.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _cancelAllTimers();
    _pendingQueue.clear();
    _deadLetters.clear();
    _succeeded.clear();
    _pendingCountCore.dispose();
    _retryingCountCore.dispose();
    _succeededCountCore.dispose();
    _deadLetterCountCore.dispose();
    _totalEnqueuedCore.dispose();
    _isProcessingComputed.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use a disposed Anvil');
    }
  }

  @override
  String toString() =>
      'Anvil(${_name ?? 'unnamed'}, '
      'pending: ${_pendingQueue.length}, '
      'deadLetters: ${_deadLetters.length}, '
      'succeeded: ${_succeeded.length})';
}
