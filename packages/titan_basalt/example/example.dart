// ignore_for_file: avoid_print, unused_local_variable

/// Basalt — Titan's infrastructure & resilience toolkit.
///
/// This example demonstrates the key infrastructure components:
/// - [Trove] — Reactive in-memory cache with TTL/LRU eviction
/// - [Moat] — Token-bucket rate limiter
/// - [Portcullis] — Circuit breaker with automatic recovery
/// - [Anvil] — Dead-letter retry queue with backoff
/// - [Pyre] — Priority-ordered async task queue
library;

import 'package:titan/titan.dart';
import 'package:titan_basalt/titan_basalt.dart';

// ---------------------------------------------------------------------------
// Define a Pillar with Basalt infrastructure
// ---------------------------------------------------------------------------

class ApiPillar extends Pillar {
  /// In-memory cache — entries expire after 5 minutes, max 200 entries.
  late final cache = trove<String, String>(
    defaultTtl: Duration(minutes: 5),
    maxEntries: 200,
    name: 'api-cache',
  );

  /// Rate limiter — allows 60 requests per second.
  late final limiter = moat(
    maxTokens: 60,
    refillRate: Duration(seconds: 1),
    name: 'api-rate',
  );

  /// Circuit breaker — opens after 5 consecutive failures, resets after 30s.
  late final breaker = portcullis(
    failureThreshold: 5,
    resetTimeout: Duration(seconds: 30),
    name: 'service',
  );

  /// Retry queue — retries failed tasks up to 3 times with exponential backoff.
  late final retryQueue = anvil<String>(
    maxRetries: 3,
    backoff: AnvilBackoff.exponential(),
    name: 'orders',
  );

  /// Priority task queue — processes up to 2 tasks concurrently.
  late final uploads = pyre<String>(
    concurrency: 2,
    maxQueueSize: 50,
    name: 'uploads',
  );

  /// Fetch data with caching, rate limiting, and circuit breaking.
  Future<String> fetchData(String key) async {
    // Check cache first
    final cached = cache.get(key);
    if (cached != null) return cached;

    // Rate-limit outgoing requests
    if (!limiter.tryConsume()) {
      throw Exception('Rate limited — try again later');
    }

    // Call through the circuit breaker
    final result = await breaker.protect(() async {
      // Simulate API call
      await Future<void>.delayed(Duration(milliseconds: 50));
      return 'data-for-$key';
    });

    // Cache the result
    cache.put(key, result);
    return result;
  }
}

// ---------------------------------------------------------------------------
// Usage — Pure Dart (no Flutter needed)
// ---------------------------------------------------------------------------

void main() async {
  final api = ApiPillar();

  // Fetch with cache, rate limiting, and circuit breaker protection
  final data = await api.fetchData('user-123');
  print('Fetched: $data');

  // Second call hits the cache
  final cached = await api.fetchData('user-123');
  print('Cached: $cached');

  // Inspect reactive stats
  print('Cache size: ${api.cache.size}');
  print('Cache hit rate: ${api.cache.hitRate.toStringAsFixed(1)}%');
  print('Rate limiter tokens: ${api.limiter.remainingTokens.value}');
  print('Circuit breaker state: ${api.breaker.state}');

  // Enqueue a priority task
  api.uploads.enqueue(() async {
    await Future<void>.delayed(Duration(milliseconds: 100));
    return 'uploaded';
  }, priority: PyrePriority.high);

  print('Upload queue pending: ${api.uploads.queueLength}');

  // Clean up
  api.dispose();
}
