# Chapter XLVI: The Lode Opens

> *"Every connection was precious. Opening one cost time and memory; leaving one idle wasted both. The application needed a vein of managed resources — a Lode that could be tapped on demand, validated before use, and sealed when spent. The pool would breathe with the application's rhythm, expanding under pressure and contracting in calm."*

---

## The Problem

Questboard's backend grew. Every quest submission required a database connection, every map tile fetched through an HTTP client, every real-time update streamed over a WebSocket channel. Each resource was expensive to create and dangerous to leak.

"I'm opening a new connection per request," Kael admitted, scrolling through the logs:

```dart
Future<List<Quest>> fetchQuests() async {
  final conn = await DbConnection.open('postgres://...');
  try {
    return await conn.query('SELECT * FROM quests');
  } finally {
    await conn.close(); // Hope this doesn't throw
  }
}
```

"Every call pays the connection handshake," Lyra observed. "Under load, you'll exhaust the server's connection limit. And if `close()` throws, you leak."

"I tried caching a single connection," Kael said, "but it goes stale after the server's idle timeout. And I can't share one connection across concurrent requests."

Lyra handed him a crystalline key engraved with a pickaxe. "You need a **Lode** — a managed vein of resources that creates, validates, and recycles on demand."

---

## The Lode Opens

```dart
class DatabasePillar extends Pillar {
  late final connections = lode<DbConnection>(
    create: () async => DbConnection.open('postgres://...'),
    destroy: (conn) async => conn.close(),
    validate: (conn) async => conn.isOpen,
    maxSize: 10,
  );

  Future<List<Row>> query(String sql) async {
    return connections.withResource((conn) => conn.query(sql));
  }
}
```

Kael studied the code. "The pool manages the lifecycle. `withResource` acquires, executes, and releases automatically?"

"Exactly. And if a connection has gone stale, `validate` catches it before your query runs. The Lode destroys the bad connection and tries the next one — or creates a fresh one if needed."

---

## Reactive Pool Metrics

The Lode exposed its internal state as reactive signals:

```dart
// In a monitoring Vestige
Vestige<DatabasePillar>(
  builder: (context, pillar, child) {
    final available = pillar.connections.available.value;
    final inUse = pillar.connections.inUse.value;
    final utilization = pillar.connections.utilization.value;
    final waiting = pillar.connections.waiters.value;

    return Column(children: [
      Text('Pool: $inUse / ${pillar.connections.maxSize} in use'),
      Text('Available: $available idle'),
      Text('Utilization: ${(utilization * 100).toStringAsFixed(0)}%'),
      if (waiting > 0)
        Text('⚠ $waiting requests waiting', style: TextStyle(color: Colors.orange)),
    ]);
  },
)
```

"Every metric is a reactive Core or Derived," Lyra explained. "Your UI updates the instant a connection is checked out or returned. No polling."

---

## The Lease Contract

When a resource was checked out, the Lode issued a **LodeLease** — a contract that guaranteed the resource would be returned:

```dart
final lease = await pillar.connections.acquire();
try {
  final conn = lease.resource;
  await conn.execute('INSERT INTO quests ...');
} finally {
  lease.release(); // Returns to pool for reuse
}
```

"But what if the connection broke mid-query?" Kael asked.

"Then you **invalidate** instead of releasing:"

```dart
final lease = await pillar.connections.acquire();
try {
  await lease.resource.execute(sql);
  lease.release();
} catch (e) {
  await lease.invalidate(); // Destroys instead of returning
  rethrow;
}
```

"An invalidated resource is destroyed immediately. The pool's size shrinks, and the next acquire creates a fresh one."

---

## Warming the Vein

Cold starts were expensive. The first ten requests each paid the full connection-open cost:

```dart
// Pre-create 5 connections at startup
await pillar.connections.warmup(5);
```

"Now the first five requests get instant connections from the idle pool," Lyra said. "`warmup` respects `maxSize` — you can't over-provision."

---

## Exhaustion and Patience

Under peak load, all connections were in use. New requests waited:

```dart
// With timeout — throws TimeoutException if no resource available
final lease = await pillar.connections.acquire(
  timeout: Duration(seconds: 5),
);
```

"Without a timeout, the caller waits indefinitely. With one, it fails fast and you can show the user a retry option."

The waiters queue was reactive too. Kael could show a loading indicator the moment the pool was exhausted:

```dart
final isExhausted = pillar.connections.waiters.value > 0;
```

---

## Draining and Disposal

When the application backgrounded or the user logged out, idle connections could be reclaimed:

```dart
// Destroy idle resources but keep checked-out ones alive
await pillar.connections.drain();
```

"Drain is graceful," Lyra said. "Checked-out connections keep working. They'll be destroyed when released — or when you call `dispose()` to shut everything down."

```dart
// Full shutdown — destroys all resources, cancels waiters
await pillar.connections.dispose();
```

---

## Under the Hood

Kael examined the Lode's internals:

| Component | Purpose |
|-----------|---------|
| `Queue<T> _idle` | FIFO queue of available resources |
| `Set<T> _checkedOut` | Currently borrowed resources |
| `Queue<Completer<T>> _waiting` | Callers blocked on an exhausted pool |
| `_syncMetrics()` | Updates all reactive Cores after every state change |

The **acquire** flow: try idle → validate → create new → wait in queue. The **release** flow: if waiters exist, hand directly to first waiter; otherwise return to idle.

"No resource is ever lost," Lyra said. "Every path — release, invalidate, drain, dispose — ends with the resource either back in the pool or properly destroyed."

---

## The Metrics

```
46. Lode        | Acquire+Release(10K)      |  10000 × 0.573 µs/op
46. Lode        | withResource(10K)         |  10000 × 0.727 µs/op
46. Lode        | Warmup5+Drain(1K)         |   1000 × 2.929 µs/op
```

Sub-microsecond checkout and return. The overhead was invisible — all the cost was in the actual resource creation, which the pool amortized across requests.

---

## What the Lode Taught

Kael recorded the lessons:

1. **Pool, don't create** — expensive resources should be reused, not recreated per request
2. **Validate before use** — stale resources cause silent failures; validate on checkout
3. **Lease, don't share** — the LodeLease contract ensures every checkout has a matching return
4. **React to pressure** — utilization, waiters, and availability are reactive signals, not hidden metrics
5. **Timeout, don't hang** — bounded waits prevent queue buildup under sustained load

The Lode had opened, and Questboard's resources flowed like ore through a well-managed mine — extracted when needed, refined before use, and returned when spent.

---

*Next: [Chapter XLVII — *forthcoming*]*
