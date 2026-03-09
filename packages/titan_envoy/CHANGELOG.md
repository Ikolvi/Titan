# Changelog

## 1.0.0

### Added

#### Core HTTP Client
- **Envoy** — Full-featured HTTP client with interceptor pipeline, timeouts, redirects, and response streaming
- **Missive** — Request builder with method, headers, body, query params, and cancel token support
- **Dispatch** — Response wrapper with status code, headers, body, and timing metadata
- **Method** — HTTP method enum (GET, POST, PUT, PATCH, DELETE, HEAD, OPTIONS)
- **EnvoyError** — Typed error hierarchy with `EnvoyErrorType` (connectTimeout, sendTimeout, receiveTimeout, cancel, response, other)

#### Interceptor Pipeline (Couriers)
- **Courier** — Base interceptor class with `onRequest`, `onResponse`, `onError` hooks
- **CourierChain** — Interceptor chain with ordered execution and short-circuiting
- **LogCourier** — Request/response logging with configurable detail levels
- **RetryCourier** — Automatic retry with exponential backoff and configurable conditions
- **AuthCourier** — Token injection with automatic refresh on 401 responses
- **CacheCourier** — HTTP caching with `CachePolicy` strategies (networkFirst, cacheFirst, staleWhileRevalidate, networkOnly, cacheOnly)
- **MetricsCourier** — Request metrics collection and Colossus integration
- **DedupCourier** — Deduplicates concurrent identical GET requests
- **CookieCourier** — Cookie jar management (set-cookie/cookie headers)

#### Caching
- **EnvoyCache** — Cache interface with `CacheEntry` storage
- **MemoryCache** — In-memory TTL-based cache with LRU eviction
- **CachePolicy** — Cache strategy configuration (ttl, staleAge, methods, statusCodes)

#### Advanced Features
- **Recall** — Cancel token for aborting in-flight requests
- **Parcel** — Multipart form data with `ParcelFile` and `ParcelEntry` support
- **Gate** — Request throttling with configurable concurrency limits
- **EnvoySocket** — WebSocket client with `SocketStatus` lifecycle management
- **EnvoySse** — Server-Sent Events client with `SseEvent` parsing
- **EnvoyPin** — SSL certificate pinning with SHA-256 fingerprints
- **EnvoyProxy** — HTTP/SOCKS proxy configuration
- **EnvoyMetric** — Per-request performance metrics (latency, bytes, status)

#### Titan Ecosystem Integration
- **EnvoyPillar** — Pillar base class for HTTP-backed state management
- **EnvoyModule** — DI module for registering Envoy in Titan's Vault
- **EnvoyPillarExtension** — `envoyQuarry` and `envoyCodex` extensions for route-based data fetching with Quarry and Codex
