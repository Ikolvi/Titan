# Chapter XLII: The Embargo Holds

> *"Before the Embargo, concurrent operations were a free-for-all. Two taps on the submit button meant two orders placed. Three tabs refreshing at once meant three copies of every API call. The developers wired up boolean flags — `_isSubmitting`, `_isLoading`, `_isSaving` — but they were fragile, forgot to reset on errors, and gave the UI no way to know what was happening. The Embargo brought discipline: declare the concurrency limit, and the engine enforces it."*

---

## The Problem

The Questboard had a critical bug. Heroes were purchasing potions by tapping the "Buy" button, but network latency meant impatient heroes tapped twice — and got charged twice. Kael's first fix was simple:

```dart
bool _isBuying = false;

Future<void> buyPotion() async {
  if (_isBuying) return; // Reject double-tap
  _isBuying = true;
  try {
    await api.purchase('potion');
  } finally {
    _isBuying = false;
  }
}
```

"It works," Kael said, "but the UI doesn't know `_isBuying` changed. The button doesn't disable. And if I forget the `finally`, the flag stays true forever."

Then Lyra discovered a second problem: the quest catalog screen made four API calls simultaneously, but the server throttled requests to three concurrent connections per user. The fourth call always failed.

"You need two things," she said. "A **mutex** for the buy button — only one at a time. And a **semaphore** for the API pool — up to three at a time. You need the **Embargo**."

---

## The Embargo

An embargo restricts the flow of operations. In Titan, `Embargo` is a reactive async mutex/semaphore that controls concurrency with observable state:

```dart
class ShopPillar extends Pillar {
  // Mutex — prevent double-submit (permits: 1, the default)
  late final buyLock = embargo(name: 'buy');

  // Semaphore — max 3 concurrent API calls
  late final apiPool = embargo(permits: 3, name: 'api');

  Future<void> buyPotion() async {
    await buyLock.guard(() async {
      await api.purchase('potion');
    });
  }

  Future<List<dynamic>> fetchAll(List<String> endpoints) async {
    final futures = endpoints.map((url) =>
      apiPool.guard(() => api.get(url)));
    return Future.wait(futures);
  }
}
```

The `guard()` method acquires a permit, runs the action, and releases the permit when done — even if the action throws. No manual flags. No forgotten resets. No boolean spaghetti.

---

## Mutex vs. Semaphore

The difference is a single parameter:

| Mode | `permits` | Use Case |
|------|-----------|----------|
| Mutex | `1` (default) | Prevent double-submit, serialize writes |
| Semaphore | `N` | Limit concurrent API calls, connection pools |

```dart
// Mutex: only one at a time
late final lock = embargo(name: 'lock');

// Semaphore: up to 5 at a time
late final pool = embargo(permits: 5, name: 'pool');
```

---

## Reactive State

Every aspect of the Embargo is observable:

| Property | Type | Description |
|----------|------|-------------|
| `isLocked` | `Derived<bool>` | All permits currently acquired |
| `activeCount` | `Core<int>` | Number of in-flight tasks |
| `queueLength` | `Core<int>` | Number of tasks waiting |
| `totalAcquires` | `Core<int>` | Lifetime acquire count |
| `status` | `Derived<EmbargoStatus>` | available / busy / contended |
| `isAvailable` | `Derived<bool>` | Has a free permit now |

This means the UI can react to lock state without additional wiring:

```dart
Vestige<ShopPillar>(
  builder: (context, pillar) {
    final locked = pillar.buyLock.isLocked.value;
    return FilledButton(
      onPressed: locked ? null : () => pillar.buyPotion(),
      child: Text(locked ? 'Processing...' : 'Buy Potion'),
    );
  },
)
```

No separate `isLoading` Core. No manual state management for the button. The Embargo *is* the state.

---

## Timeouts

Long waits can be bounded:

```dart
late final lock = embargo(
  timeout: Duration(seconds: 5),
  name: 'checkout',
);

try {
  await lock.guard(() => api.checkout());
} on EmbargoTimeoutException catch (e) {
  showError('Checkout busy. Try again in a moment.');
}
```

Per-call timeouts override the instance default:

```dart
await lock.guard(
  () => api.quickCheck(),
  timeout: Duration(milliseconds: 500),
);
```

---

## Manual Acquire / Release

For advanced patterns, acquire a lease directly:

```dart
final lease = await lock.acquire();
try {
  // ... critical section ...
} finally {
  lease.release();
}

lease.holdDuration; // How long the permit was held
lease.isReleased;   // Whether already released
```

But prefer `guard()` — it handles release automatically, even on errors.

---

## Status

The `EmbargoStatus` enum provides three states:

| Status | Meaning |
|--------|---------|
| `available` | Free permits — next call executes immediately |
| `busy` | All permits held, but no queue |
| `contended` | All permits held AND tasks are waiting |

```dart
switch (pool.status.value) {
  case EmbargoStatus.available:
    return Icon(Icons.check_circle, color: Colors.green);
  case EmbargoStatus.busy:
    return Icon(Icons.hourglass_empty, color: Colors.orange);
  case EmbargoStatus.contended:
    return Icon(Icons.warning, color: Colors.red);
}
```

---

## Performance

The Embargo is built for speed:

| Operation | Time |
|-----------|------|
| Mutex guard (uncontended) | 0.70 µs |
| Semaphore guard (5 permits) | 0.61 µs |
| Create | 0.30 µs |
| Acquire + Release | 0.18 µs |
| Mutex contended (100 tasks) | 5.90 µs/task |

Sub-microsecond for typical operations. The overhead of concurrency control is negligible compared to the network calls it protects.

---

## What Was Learned

1. **Replace boolean flags with Embargo** — `_isSubmitting` flags are fragile, non-reactive, and error-prone. Embargo handles acquisition, release on error, and UI observability automatically.
2. **Mutex for exclusion, Semaphore for throttling** — One class, one parameter. `permits: 1` serializes, `permits: N` throttles.
3. **Reactive concurrency state** — `isLocked`, `queueLength`, and `status` are reactive Cores/Derived, so the UI updates automatically when lock state changes.
4. **FIFO fairness** — Waiters are served in the order they arrive. No starvation.
5. **The resilience triad** — Moat controls *rate* (how many per second), Portcullis controls *health* (stop if failing), Embargo controls *concurrency* (how many at once). Together, they form a complete resilience layer.

The Embargo held. Double-submits vanished. API calls stayed within limits. And the buy button disabled itself the moment a purchase was in flight.

---

*Next: [Chapter XLIII →](chapter-43-todo.md)*
