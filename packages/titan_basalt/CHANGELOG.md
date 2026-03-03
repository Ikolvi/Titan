# Changelog

## 1.0.0

### Initial Release

Infrastructure & resilience features extracted from `titan` core:

- **Trove** — Reactive TTL/LRU in-memory cache with hit-rate tracking
- **Moat** — Token-bucket rate limiter with per-key quotas (MoatPool)
- **Portcullis** — Reactive circuit breaker with half-open probing
- **Anvil** — Dead letter & retry queue with configurable backoff
- **Pyre** — Priority-ordered async task queue with concurrency control
- **Codex** — Reactive paginated data loading (offset & cursor-based)
- **Quarry** — SWR data queries with dedup, retry, and optimistic updates
- **Bulwark** — Lightweight circuit breaker with reactive state
- **Saga** — Multi-step workflow orchestration with compensation/rollback
- **Volley** — Parallel batch async execution with progress tracking
- **Tether** — Composable middleware-style action chain
- **Annals** — Capped, queryable append-only audit log

All features integrate with `Pillar` via extension methods — use
`late final cache = trove(...)` just like core factory methods.
