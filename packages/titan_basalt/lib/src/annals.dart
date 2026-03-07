/// Annals — Immutable audit trail for reactive state mutations.
///
/// Annals provides a centralized, append-only log of Core value changes
/// with timestamps, source Pillar types, and optional metadata. Essential
/// for enterprise compliance, debugging, and regulatory requirements.
///
/// ## Why "Annals"?
///
/// Annals are historical records — the definitive chronicle of events.
/// Titan's Annals record every significant state mutation for posterity.
///
/// ## Usage
///
/// ```dart
/// // Enable audit trail
/// Annals.enable();
///
/// // Record a mutation
/// Annals.record(AnnalEntry(
///   coreName: 'balance',
///   pillarType: 'AccountPillar',
///   oldValue: 100,
///   newValue: 200,
///   action: 'deposit',
/// ));
///
/// // Query entries
/// final recent = Annals.entries.take(10);
/// final filtered = Annals.query(pillarType: 'AccountPillar');
///
/// // Export for compliance
/// final json = Annals.export();
/// ```
library;

import 'dart:async';
import 'dart:collection';

/// A single entry in the audit trail.
///
/// Each entry records a state mutation with full context:
/// who changed what, when, and from/to which values.
class AnnalEntry {
  /// The name of the Core that was mutated.
  final String coreName;

  /// The runtime type of the Pillar that owns the Core.
  final String? pillarType;

  /// The value before the mutation.
  final dynamic oldValue;

  /// The value after the mutation.
  final dynamic newValue;

  /// When the mutation occurred.
  final DateTime timestamp;

  /// Optional action/event name that triggered this mutation.
  final String? action;

  /// Optional user identifier for compliance tracking.
  final String? userId;

  /// Optional metadata for additional context.
  final Map<String, dynamic>? metadata;

  /// Creates an audit entry.
  AnnalEntry({
    required this.coreName,
    this.pillarType,
    required this.oldValue,
    required this.newValue,
    DateTime? timestamp,
    this.action,
    this.userId,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to a serializable map.
  Map<String, dynamic> toMap() => {
    'coreName': coreName,
    if (pillarType != null) 'pillarType': pillarType,
    'oldValue': '$oldValue',
    'newValue': '$newValue',
    'timestamp': timestamp.toIso8601String(),
    if (action != null) 'action': action,
    if (userId != null) 'userId': userId,
    if (metadata != null) 'metadata': metadata,
  };

  @override
  String toString() =>
      'AnnalEntry($coreName: $oldValue → $newValue${action != null ? ' [$action]' : ''})';
}

/// Centralized, immutable audit trail manager.
///
/// Records state mutations as [AnnalEntry] objects with configurable
/// retention, filtering, and export capabilities.
///
/// ```dart
/// Annals.enable();
///
/// // Automatic recording via Pillar integration
/// pillar.strike(() {
///   balance.value = newBalance; // Recorded if audit is enabled
/// });
///
/// // Manual recording
/// Annals.record(AnnalEntry(
///   coreName: 'setting',
///   oldValue: oldVal,
///   newValue: newVal,
///   action: 'user_update',
///   userId: currentUser.id,
/// ));
///
/// // Query and export
/// final exports = Annals.export();
/// ```
class Annals {
  Annals._();

  static bool _enabled = false;
  static int _maxEntries = 10000;
  static final Queue<AnnalEntry> _entries = Queue<AnnalEntry>();
  static StreamController<AnnalEntry>? _controller;

  /// Secondary index: pillarType → entries for O(1) type-scoped queries.
  static final Map<String, List<AnnalEntry>> _byPillarType = {};

  /// Whether the secondary index is enabled.
  ///
  /// Enabled automatically when [enable] is called with `indexed: true`.
  static bool get isIndexed => _indexed;
  static bool _indexed = false;

  /// Lazily creates the broadcast StreamController.
  static StreamController<AnnalEntry> get _activeController {
    var c = _controller;
    if (c == null || c.isClosed) {
      c = StreamController<AnnalEntry>.broadcast();
      _controller = c;
    }
    return c;
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Whether the audit trail is enabled.
  static bool get isEnabled => _enabled;

  /// Enable the audit trail.
  ///
  /// When enabled, calls to [record] store entries and emit them
  /// through [stream].
  ///
  /// Set [indexed] to `true` to maintain a secondary index on
  /// [AnnalEntry.pillarType] for O(1) type-scoped queries. The index
  /// costs one hash-map insertion per [record] but eliminates linear
  /// scans for the most common query pattern:
  ///
  /// ```dart
  /// Annals.enable(indexed: true);
  /// // Later:
  /// Annals.query(pillarType: 'AccountPillar'); // O(1) lookup
  /// ```
  static void enable({int maxEntries = 10000, bool indexed = false}) {
    _enabled = true;
    _maxEntries = maxEntries;
    _indexed = indexed;
  }

  /// Disable the audit trail.
  ///
  /// New entries are ignored but existing entries are preserved.
  static void disable() {
    _enabled = false;
  }

  /// The maximum number of entries to retain.
  ///
  /// When the limit is reached, oldest entries are evicted (FIFO).
  static int get maxEntries => _maxEntries;

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Record an audit entry.
  ///
  /// Ignored if the audit trail is not [isEnabled].
  ///
  /// ```dart
  /// Annals.record(AnnalEntry(
  ///   coreName: 'email',
  ///   pillarType: 'UserPillar',
  ///   oldValue: 'old@email.com',
  ///   newValue: 'new@email.com',
  ///   action: 'profile_update',
  ///   userId: 'user_123',
  /// ));
  /// ```
  static void record(AnnalEntry entry) {
    if (!_enabled) return;

    _entries.addLast(entry);

    // Maintain secondary index.
    if (_indexed && entry.pillarType != null) {
      _byPillarType.putIfAbsent(entry.pillarType!, () => []).add(entry);
    }

    // Evict oldest when over capacity — O(1) with Queue.removeFirst().
    while (_entries.length > _maxEntries) {
      final evicted = _entries.removeFirst();
      if (_indexed && evicted.pillarType != null) {
        _byPillarType[evicted.pillarType!]?.remove(evicted);
      }
    }

    final c = _controller;
    if (c != null && !c.isClosed) {
      c.add(entry);
    }
  }

  // ---------------------------------------------------------------------------
  // Querying
  // ---------------------------------------------------------------------------

  /// All recorded entries (oldest first, unmodifiable view).
  static List<AnnalEntry> get entries => List.unmodifiable(_entries.toList());

  /// The number of recorded entries.
  static int get length => _entries.length;

  /// Stream of audit entries as they are recorded.
  static Stream<AnnalEntry> get stream => _activeController.stream;

  /// Query entries with optional filters.
  ///
  /// All filters are AND-combined.
  ///
  /// ```dart
  /// final userChanges = Annals.query(
  ///   pillarType: 'UserPillar',
  ///   after: oneHourAgo,
  ///   coreName: 'email',
  /// );
  /// ```
  static List<AnnalEntry> query({
    String? coreName,
    String? pillarType,
    String? action,
    String? userId,
    DateTime? after,
    DateTime? before,
    int? limit,
  }) {
    bool matches(AnnalEntry e) {
      if (coreName != null && e.coreName != coreName) return false;
      if (pillarType != null && e.pillarType != pillarType) return false;
      if (action != null && e.action != action) return false;
      if (userId != null && e.userId != userId) return false;
      if (after != null && !e.timestamp.isAfter(after)) return false;
      if (before != null && !e.timestamp.isBefore(before)) return false;
      return true;
    }

    // Index fast-path: pillarType-only query with no other filters.
    if (_indexed &&
        pillarType != null &&
        coreName == null &&
        action == null &&
        userId == null &&
        after == null &&
        before == null) {
      final indexed = _byPillarType[pillarType];
      if (indexed == null || indexed.isEmpty) return const [];
      if (limit != null && limit > 0 && limit < indexed.length) {
        return indexed.sublist(indexed.length - limit);
      }
      return List.of(indexed);
    }

    // Index-assisted: pillarType filter with additional filters.
    // Start from the narrower index instead of scanning all entries.
    if (_indexed && pillarType != null) {
      final indexed = _byPillarType[pillarType];
      if (indexed == null || indexed.isEmpty) return const [];
      if (limit != null && limit > 0) {
        final collected = <AnnalEntry>[];
        for (var i = indexed.length - 1;
            i >= 0 && collected.length < limit;
            i--) {
          if (matches(indexed[i])) collected.add(indexed[i]);
        }
        return collected.reversed.toList();
      }
      return indexed.where(matches).toList();
    }

    // Fast path: when limit is specified, collect the last N matches
    // by iterating backwards.
    if (limit != null && limit > 0) {
      final asList = _entries.toList(growable: false);
      final collected = <AnnalEntry>[];
      for (var i = asList.length - 1; i >= 0 && collected.length < limit; i--) {
        if (matches(asList[i])) {
          collected.add(asList[i]);
        }
      }
      return collected.reversed.toList();
    }

    // No limit — iterate forward and collect all matches.
    return _entries.where(matches).toList();
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Export all entries as a list of serializable maps.
  ///
  /// ```dart
  /// final data = Annals.export();
  /// final json = jsonEncode(data);
  /// ```
  static List<Map<String, dynamic>> export({
    String? pillarType,
    DateTime? after,
    DateTime? before,
  }) {
    final filtered = query(
      pillarType: pillarType,
      after: after,
      before: before,
    );
    return filtered.map((e) => e.toMap()).toList();
  }

  /// Export entries directly to a [StringSink] as a JSON array.
  ///
  /// Avoids building an intermediate `List<Map>` — writes entries
  /// one-by-one to the provided sink. For 100K entries this is
  /// significantly faster and uses less peak memory.
  ///
  /// ```dart
  /// final buffer = StringBuffer();
  /// Annals.exportToBuffer(buffer);
  /// final json = buffer.toString();
  /// ```
  static void exportToBuffer(
    StringSink sink, {
    String? pillarType,
    DateTime? after,
    DateTime? before,
  }) {
    final filtered = query(
      pillarType: pillarType,
      after: after,
      before: before,
    );

    sink.write('[');
    for (var i = 0; i < filtered.length; i++) {
      if (i > 0) sink.write(',');
      _writeEntryJson(sink, filtered[i]);
    }
    sink.write(']');
  }

  /// Write a single entry as JSON to a [StringSink].
  static void _writeEntryJson(StringSink sink, AnnalEntry e) {
    sink.write('{"coreName":"');
    sink.write(_escapeJson(e.coreName));
    sink.write('"');
    if (e.pillarType != null) {
      sink.write(',"pillarType":"');
      sink.write(_escapeJson(e.pillarType!));
      sink.write('"');
    }
    sink.write(',"oldValue":"');
    sink.write(_escapeJson('${e.oldValue}'));
    sink.write('","newValue":"');
    sink.write(_escapeJson('${e.newValue}'));
    sink.write('","timestamp":"');
    sink.write(e.timestamp.toIso8601String());
    sink.write('"');
    if (e.action != null) {
      sink.write(',"action":"');
      sink.write(_escapeJson(e.action!));
      sink.write('"');
    }
    if (e.userId != null) {
      sink.write(',"userId":"');
      sink.write(_escapeJson(e.userId!));
      sink.write('"');
    }
    sink.write('}');
  }

  static String _escapeJson(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
  }

  // ---------------------------------------------------------------------------
  // Management
  // ---------------------------------------------------------------------------

  /// Clear all audit entries.
  static void clear() {
    _entries.clear();
    _byPillarType.clear();
  }

  /// Reset the audit system completely.
  ///
  /// Clears all entries and disables auditing.
  static void reset() {
    _entries.clear();
    _byPillarType.clear();
    _enabled = false;
    _indexed = false;
    _maxEntries = 10000;
  }

  /// Dispose the stream controller and clear all entries.
  ///
  /// After calling dispose, the [stream] getter will create a fresh
  /// controller on next access.
  static void dispose() {
    _controller?.close();
    _controller = null;
    _entries.clear();
    _byPillarType.clear();
    _enabled = false;
    _indexed = false;
    _maxEntries = 10000;
  }
}
