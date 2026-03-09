// ignore_for_file: avoid_print

/// Envoy — Titan's HTTP client with interceptors, caching, and ecosystem
/// integration.
///
/// This example demonstrates core Envoy capabilities:
/// - [Envoy] — HTTP client with interceptor pipeline
/// - [Courier] — Request/response interceptors
/// - [CacheCourier] — Response caching with multiple strategies
/// - [Recall] — Request cancellation
/// - [EnvoyPillar] — HTTP-backed Pillar integration
library;

import 'package:titan_envoy/titan_envoy.dart';

// ---------------------------------------------------------------------------
// Basic HTTP requests
// ---------------------------------------------------------------------------

Future<void> basicRequests() async {
  final envoy = Envoy(baseUrl: 'https://jsonplaceholder.typicode.com');

  // GET
  final dispatch = await envoy.get('/posts/1');
  print('Title: ${(dispatch.data as Map<String, dynamic>?)?['title']}');

  // POST
  final created = await envoy.post(
    '/posts',
    data: {
      'title': 'Hello from Envoy',
      'body': 'Titan HTTP client',
      'userId': 1,
    },
  );
  print(
    'Created post ID: '
    '${(created.data as Map<String, dynamic>?)?['id']}',
  );

  envoy.close();
}

// ---------------------------------------------------------------------------
// Interceptor pipeline (Couriers)
// ---------------------------------------------------------------------------

Future<void> courierPipeline() async {
  final envoy = Envoy(baseUrl: 'https://jsonplaceholder.typicode.com');

  // Add logging, retry, and caching
  envoy.addCourier(LogCourier());
  envoy.addCourier(RetryCourier(maxRetries: 3));
  envoy.addCourier(
    CacheCourier(
      cache: MemoryCache(maxEntries: 50),
      defaultPolicy: const CachePolicy.staleWhileRevalidate(
        ttl: Duration(minutes: 5),
      ),
    ),
  );

  // Requests now flow through the courier pipeline
  final dispatch = await envoy.get('/posts');
  print('Fetched ${(dispatch.data as List).length} posts');

  envoy.close();
}

// ---------------------------------------------------------------------------
// Cancel in-flight requests
// ---------------------------------------------------------------------------

Future<void> cancellation() async {
  final envoy = Envoy(baseUrl: 'https://jsonplaceholder.typicode.com');
  final recall = Recall();

  try {
    // ignore: unawaited_futures
    envoy.get('/posts', recall: recall);
    recall.cancel('User navigated away');
  } on EnvoyError catch (e) {
    if (e.type == EnvoyErrorType.cancelled) {
      print('Request cancelled: ${e.message}');
    }
  }

  envoy.close();
}

// ---------------------------------------------------------------------------
// Request throttling via Gate courier
// ---------------------------------------------------------------------------

Future<void> throttling() async {
  final envoy = Envoy(baseUrl: 'https://jsonplaceholder.typicode.com');

  // Gate is a Courier — max 2 concurrent requests, others queue
  envoy.addCourier(Gate(maxConcurrent: 2));
  final futures = List.generate(10, (i) => envoy.get('/posts/${i + 1}'));

  final results = await Future.wait(futures);
  print('Fetched ${results.length} posts with throttling');

  envoy.close();
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Future<void> main() async {
  print('=== Basic Requests ===');
  await basicRequests();

  print('\n=== Courier Pipeline ===');
  await courierPipeline();

  print('\n=== Cancellation ===');
  await cancellation();

  print('\n=== Throttling ===');
  await throttling();
}
