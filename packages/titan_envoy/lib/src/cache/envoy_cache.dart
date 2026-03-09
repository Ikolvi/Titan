import 'dart:async';

/// A cached HTTP response entry stored by [EnvoyCache].
///
/// Contains the response data, headers, and metadata for cache management.
class CacheEntry {
  /// Creates a new [CacheEntry].
  const CacheEntry({
    required this.statusCode,
    required this.headers,
    required this.storedAt,
    this.data,
    this.rawBody,
    this.ttl,
  });

  /// The cached HTTP status code.
  final int statusCode;

  /// The parsed response data.
  final Object? data;

  /// The raw response body string.
  final String? rawBody;

  /// The cached response headers.
  final Map<String, String> headers;

  /// When this entry was stored.
  final DateTime storedAt;

  /// Time-to-live for this entry.
  final Duration? ttl;

  /// Whether this entry has expired.
  bool get isExpired {
    if (ttl == null) return false;
    return DateTime.now().difference(storedAt) > ttl!;
  }

  /// Serializes this entry to a JSON-compatible map for persistent storage.
  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'rawBody': rawBody,
      'headers': headers,
      'storedAt': storedAt.toIso8601String(),
      'ttlMs': ttl?.inMilliseconds,
    };
  }

  /// Deserializes a [CacheEntry] from a JSON map.
  factory CacheEntry.fromJson(Map<String, dynamic> json) {
    return CacheEntry(
      statusCode: json['statusCode'] as int,
      rawBody: json['rawBody'] as String?,
      headers: Map<String, String>.from(json['headers'] as Map),
      storedAt: DateTime.parse(json['storedAt'] as String),
      ttl: json['ttlMs'] != null
          ? Duration(milliseconds: json['ttlMs'] as int)
          : null,
    );
  }
}

/// Abstract cache adapter for [CacheCourier].
///
/// Implement this interface to provide any storage backend for HTTP
/// response caching. The cache is fully decoupled from the Envoy core —
/// use in-memory, shared preferences, SQLite, Hive, or any other backend.
///
/// ```dart
/// class MyPersistentCache implements EnvoyCache {
///   final SharedPreferences _prefs;
///
///   @override
///   Future<CacheEntry?> get(String key) async {
///     final json = _prefs.getString(key);
///     if (json == null) return null;
///     return CacheEntry.fromJson(jsonDecode(json));
///   }
///
///   @override
///   Future<void> put(String key, CacheEntry entry) async {
///     await _prefs.setString(key, jsonEncode(entry.toJson()));
///   }
///
///   // ... other methods
/// }
/// ```
abstract interface class EnvoyCache {
  /// Retrieves a cached entry by key.
  ///
  /// Returns `null` if no entry exists for the key.
  FutureOr<CacheEntry?> get(String key);

  /// Stores an entry in the cache.
  FutureOr<void> put(String key, CacheEntry entry);

  /// Removes an entry from the cache.
  FutureOr<void> remove(String key);

  /// Removes all entries from the cache.
  FutureOr<void> clear();

  /// Returns the number of entries in the cache.
  FutureOr<int> get size;
}
