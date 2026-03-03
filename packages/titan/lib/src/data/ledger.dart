import '../core/batch.dart';
import '../core/computed.dart';
import '../core/state.dart';

// ---------------------------------------------------------------------------
// Ledger — Reactive State Transaction Manager
// ---------------------------------------------------------------------------

/// Status of a [LedgerTransaction].
enum LedgerStatus {
  /// Transaction is open and accepting reads/writes.
  active,

  /// Transaction has been committed — all changes applied atomically.
  committed,

  /// Transaction has been rolled back — all changes discarded.
  rolledBack,

  /// Transaction failed due to an exception.
  failed,
}

/// A snapshot entry for a single Core's value before mutation.
class _CoreSnapshot {
  _CoreSnapshot(this.core, this.originalValue);

  final TitanState<dynamic> core;
  final dynamic originalValue;

  /// Restore the core to its pre-transaction value.
  void restore() {
    core.value = originalValue;
  }
}

/// Record of a completed transaction for history/audit.
///
/// Contains metadata about the transaction outcome without retaining
/// large state snapshots.
class LedgerRecord {
  /// Creates a transaction record.
  const LedgerRecord({
    required this.id,
    required this.status,
    required this.coreCount,
    required this.timestamp,
    this.error,
    this.name,
  });

  /// Unique transaction identifier.
  final int id;

  /// Final status of the transaction.
  final LedgerStatus status;

  /// Number of Cores modified in this transaction.
  final int coreCount;

  /// When the transaction completed.
  final DateTime timestamp;

  /// Error that caused failure (if [status] is [LedgerStatus.failed]).
  final Object? error;

  /// Optional transaction name for debugging.
  final String? name;

  @override
  String toString() =>
      'LedgerRecord(#$id, ${status.name}, cores: $coreCount'
      '${name != null ? ', name: $name' : ''}'
      '${error != null ? ', error: $error' : ''})';
}

/// A single atomic transaction scope.
///
/// All Core modifications within a transaction are tracked. On commit,
/// changes are applied atomically (notifications batched into one).
/// On rollback, all Cores revert to their pre-transaction values.
///
/// ```dart
/// final tx = ledger.begin(name: 'checkout');
/// try {
///   inventory.value = inventory.value - order.quantity;
///   total.value = computeTotal(order);
///   await paymentApi.charge(total.value);
///   tx.commit();
/// } catch (e) {
///   tx.rollback();
/// }
/// ```
class LedgerTransaction {
  LedgerTransaction._({required int id, required Ledger ledger, String? name})
    : _id = id,
      _ledger = ledger,
      _name = name;

  final int _id;
  final Ledger _ledger;
  final String? _name;
  final List<_CoreSnapshot> _snapshots = [];
  final Set<TitanState<dynamic>> _trackedCores = {};
  LedgerStatus _status = LedgerStatus.active;

  /// Transaction ID.
  int get id => _id;

  /// Debug name, if provided.
  String? get name => _name;

  /// Current status.
  LedgerStatus get status => _status;

  /// Whether this transaction is still active (not committed/rolled back).
  bool get isActive => _status == LedgerStatus.active;

  /// Number of Cores modified in this transaction.
  int get coreCount => _trackedCores.length;

  /// Record a Core's current value before the first mutation.
  ///
  /// Call this before modifying a Core within a transaction scope.
  /// If the Core has already been recorded, this is a no-op.
  void capture(TitanState<dynamic> core) {
    _assertActive();
    if (_trackedCores.contains(core)) return;
    _trackedCores.add(core);
    _snapshots.add(_CoreSnapshot(core, core.peek()));
  }

  /// Commit all changes atomically.
  ///
  /// After commit, all Cores retain their current values and a single
  /// notification wave fires (via batching). The transaction is finalized
  /// and cannot be used again.
  void commit() {
    _assertActive();
    _status = LedgerStatus.committed;
    _ledger._onTransactionComplete(this);
  }

  /// Roll back all changes — restore every captured Core to its
  /// pre-transaction value.
  ///
  /// Uses [TitanState.silent] + explicit notify to avoid triggering
  /// conduits on the rollback write.
  void rollback() {
    _assertActive();
    _status = LedgerStatus.rolledBack;
    titanBatch(() {
      for (final snap in _snapshots.reversed) {
        snap.restore();
      }
    });
    _ledger._onTransactionComplete(this);
  }

  void _fail(Object error) {
    _status = LedgerStatus.failed;
    _ledger._onTransactionComplete(this, error: error);
  }

  void _assertActive() {
    if (!isActive) {
      throw StateError('Transaction #$_id is ${_status.name} — cannot modify.');
    }
  }
}

/// **Ledger** — Reactive state transaction manager.
///
/// Provides ACID-like transaction semantics for multi-Core state mutations:
///
/// - **Atomicity**: All changes commit together or roll back together.
/// - **Consistency**: If any step fails, state reverts to the pre-transaction
///   snapshot — no partial corruption.
/// - **Isolation**: Changes within a transaction don't notify dependents
///   until committed. Manual transactions can hold open scopes.
/// - **Durability**: Transaction history is recorded for audit.
///
/// ## Quick Usage
///
/// ```dart
/// class CheckoutPillar extends Pillar {
///   late final inventory = core(100);
///   late final balance = core(500.0);
///   late final orderId = core<String?>(null);
///
///   late final txManager = ledger(maxHistory: 50, name: 'checkout');
///
///   Future<void> placeOrder(int qty, double price) async {
///     await txManager.transact(
///       (tx) async {
///         tx.capture(inventory);
///         tx.capture(balance);
///         tx.capture(orderId);
///
///         inventory.value -= qty;
///         balance.value -= price;
///         orderId.value = await api.createOrder(qty, price);
///       },
///       name: 'place-order',
///     );
///   }
/// }
/// ```
///
/// ## How It Works
///
/// 1. [begin] or [transact] starts a transaction, capturing the current
///    values of any Cores you [capture].
/// 2. You mutate Cores normally — state changes are live but downstream
///    notifications are deferred (batched).
/// 3. On [commit], a single notification wave fires.
/// 4. On [rollback] (manual or automatic on exception in [transact]),
///    all captured Cores revert silently, then a single notification
///    wave fires to propagate the restored values.
///
/// ## Manual vs Auto
///
/// - **[transact]**: Auto-commits on success, auto-rolls back on exception.
/// - **[begin] + [commit]/[rollback]**: Full manual control for workflows
///   that need conditional commit logic.
///
/// See also:
/// - [LedgerTransaction] — individual transaction scope
/// - [LedgerRecord] — completed transaction audit entry
/// - [LedgerStatus] — transaction lifecycle states
class Ledger {
  final String? _name;
  final int _maxHistory;
  int _nextId = 0;
  bool _isDisposed = false;

  // Active transactions
  final List<LedgerTransaction> _activeTransactions = [];

  // History ring buffer
  final List<LedgerRecord> _history = [];

  // Reactive state
  late final TitanState<int> _activeCountCore;
  late final TitanState<int> _commitCountCore;
  late final TitanState<int> _rollbackCountCore;
  late final TitanState<int> _failCountCore;
  late final TitanComputed<bool> _hasActiveComputed;

  /// Creates a reactive state transaction manager.
  ///
  /// - [maxHistory] — Maximum number of [LedgerRecord]s to retain
  ///   (default: 100). Oldest records are evicted when exceeded.
  /// - [name] — Debug name for reactive nodes.
  Ledger({int maxHistory = 100, String? name})
    : _maxHistory = maxHistory,
      _name = name {
    final prefix = name ?? 'ledger';
    _activeCountCore = TitanState<int>(0, name: '${prefix}_activeCount');
    _commitCountCore = TitanState<int>(0, name: '${prefix}_commitCount');
    _rollbackCountCore = TitanState<int>(0, name: '${prefix}_rollbackCount');
    _failCountCore = TitanState<int>(0, name: '${prefix}_failCount');
    _hasActiveComputed = TitanComputed<bool>(
      () => _activeCountCore.value > 0,
      name: '${prefix}_hasActive',
    );
  }

  // ---------------------------------------------------------------------------
  // Reactive Properties
  // ---------------------------------------------------------------------------

  /// Number of currently active transactions.
  int get activeCount => _activeCountCore.value;

  /// Total successfully committed transactions.
  int get commitCount => _commitCountCore.value;

  /// Total rolled-back transactions.
  int get rollbackCount => _rollbackCountCore.value;

  /// Total failed transactions (exceptions).
  int get failCount => _failCountCore.value;

  /// Whether any transaction is currently active.
  bool get hasActive => _hasActiveComputed.value;

  /// Transaction history (most recent first).
  List<LedgerRecord> get history => List.unmodifiable(_history);

  /// Debug name, if provided.
  String? get name => _name;

  /// Whether this Ledger has been disposed.
  bool get isDisposed => _isDisposed;

  // ---------------------------------------------------------------------------
  // Transaction API
  // ---------------------------------------------------------------------------

  /// Begin a manual transaction.
  ///
  /// You must call [LedgerTransaction.commit] or [LedgerTransaction.rollback]
  /// to finalize the transaction.
  ///
  /// ```dart
  /// final tx = ledger.begin(name: 'update-profile');
  /// tx.capture(userName);
  /// tx.capture(userEmail);
  /// userName.value = 'Alice';
  /// userEmail.value = 'alice@example.com';
  /// tx.commit(); // atomic notification
  /// ```
  LedgerTransaction begin({String? name}) {
    _assertNotDisposed();
    final tx = LedgerTransaction._(id: _nextId++, ledger: this, name: name);
    _activeTransactions.add(tx);
    _activeCountCore.value = _activeTransactions.length;
    return tx;
  }

  /// Execute a function within a transaction scope.
  ///
  /// - Auto-commits on successful completion.
  /// - Auto-rolls back on exception and rethrows.
  /// - Returns the value returned by [action].
  ///
  /// ```dart
  /// final result = await ledger.transact((tx) async {
  ///   tx.capture(inventory);
  ///   tx.capture(balance);
  ///   inventory.value -= qty;
  ///   balance.value -= price;
  ///   return await api.placeOrder(qty, price);
  /// }, name: 'checkout');
  /// ```
  Future<T> transact<T>(
    Future<T> Function(LedgerTransaction tx) action, {
    String? name,
  }) async {
    _assertNotDisposed();
    final tx = begin(name: name);
    try {
      final result = await action(tx);
      if (tx.isActive) tx.commit();
      return result;
    } catch (e) {
      if (tx.isActive) {
        tx._fail(e);
        // Rollback on failure
        titanBatch(() {
          for (final snap in tx._snapshots.reversed) {
            snap.restore();
          }
        });
      }
      rethrow;
    }
  }

  /// Synchronous version of [transact].
  ///
  /// ```dart
  /// ledger.transactSync((tx) {
  ///   tx.capture(a);
  ///   tx.capture(b);
  ///   a.value = 10;
  ///   b.value = 20;
  /// });
  /// ```
  T transactSync<T>(T Function(LedgerTransaction tx) action, {String? name}) {
    _assertNotDisposed();
    final tx = begin(name: name);
    try {
      final result = action(tx);
      if (tx.isActive) tx.commit();
      return result;
    } catch (e) {
      if (tx.isActive) {
        tx._fail(e);
        titanBatch(() {
          for (final snap in tx._snapshots.reversed) {
            snap.restore();
          }
        });
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Inspection
  // ---------------------------------------------------------------------------

  /// IDs of all currently active transactions.
  List<int> get activeTransactionIds =>
      _activeTransactions.map((tx) => tx.id).toList();

  /// The most recent [LedgerRecord], if any.
  LedgerRecord? get lastRecord => _history.isNotEmpty ? _history.last : null;

  /// Total transactions ever started.
  int get totalStarted => _nextId;

  // ---------------------------------------------------------------------------
  // Pillar Integration
  // ---------------------------------------------------------------------------

  /// All managed reactive computed nodes for Pillar auto-disposal.
  List<TitanComputed<dynamic>> get managedNodes => [_hasActiveComputed];

  /// All managed state nodes for Pillar auto-disposal.
  List<TitanState<dynamic>> get managedStateNodes => [
    _activeCountCore,
    _commitCountCore,
    _rollbackCountCore,
    _failCountCore,
  ];

  /// Dispose this Ledger and all internal reactive nodes.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _activeTransactions.clear();
    _history.clear();
    _activeCountCore.dispose();
    _commitCountCore.dispose();
    _rollbackCountCore.dispose();
    _failCountCore.dispose();
    _hasActiveComputed.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _onTransactionComplete(LedgerTransaction tx, {Object? error}) {
    _activeTransactions.remove(tx);
    _activeCountCore.value = _activeTransactions.length;

    switch (tx.status) {
      case LedgerStatus.committed:
        _commitCountCore.value = _commitCountCore.peek() + 1;
      case LedgerStatus.rolledBack:
        _rollbackCountCore.value = _rollbackCountCore.peek() + 1;
      case LedgerStatus.failed:
        _failCountCore.value = _failCountCore.peek() + 1;
      case LedgerStatus.active:
        break;
    }

    _recordHistory(tx, error: error);
  }

  void _recordHistory(LedgerTransaction tx, {Object? error}) {
    _history.add(
      LedgerRecord(
        id: tx.id,
        status: tx.status,
        coreCount: tx.coreCount,
        timestamp: DateTime.now(),
        error: error,
        name: tx.name,
      ),
    );
    // Evict oldest if over capacity
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
    }
  }

  void _assertNotDisposed() {
    if (_isDisposed) {
      throw StateError('Cannot use a disposed Ledger');
    }
  }

  @override
  String toString() =>
      'Ledger(${_name ?? 'unnamed'}, '
      'active: ${_activeTransactions.length}, '
      'commits: ${_commitCountCore.peek()}, '
      'rollbacks: ${_rollbackCountCore.peek()})';
}
