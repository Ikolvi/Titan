# Chapter XXXVIII — The Anvil Strikes

*In which broken operations are hammered back into shape, and the dead are given a second chance.*

> **Package:** This feature is in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use it.

---

The morning report was grim.

"Seventeen quest completions dropped overnight," said the operations chief, spreading a scroll of failure logs across the war table. "Payment confirmations, reward distributions, ranking updates — all lost to transient network hiccups. The heroes completed their quests, but the system never recorded it."

Kael studied the logs. Each failure was a single-point catastrophe: an operation failed, threw an error, and vanished into the void. No retry. No record. No recourse. The heroes had to file manual claims, and the administrators had to reconcile by hand.

"We can't just let failed operations disappear," Kael said. "When a smith's work breaks, they don't discard the metal. They put it back on the **anvil** and hammer it again."

---

## The Retry Queue

The Anvil was a dead letter and retry queue — a place where failed operations landed, were hammered with automatic retries, and either recovered or were set aside for manual repair.

```dart
class RewardPillar extends Pillar {
  late final retryQueue = anvil<String>(
    maxRetries: 5,
    backoff: AnvilBackoff.exponential(
      initial: Duration(seconds: 1),
      multiplier: 2.0,
    ),
    name: 'reward-retry',
  );

  Future<void> distributeReward(String heroId, int gold) async {
    try {
      await api.sendReward(heroId, gold);
    } catch (e) {
      retryQueue.enqueue(
        () => api.sendReward(heroId, gold).then((_) => 'sent'),
        id: 'reward-$heroId',
        metadata: {'heroId': heroId, 'gold': gold},
        onDeadLetter: (entry) {
          log.error('Reward permanently failed: ${entry.id}');
        },
      );
    }
  }
}
```

"Five attempts," Kael explained. "Exponential backoff — wait 1 second, then 2, then 4, then 8, then 16. If the network hiccup is truly transient, we'll catch it. If it's a persistent failure, we'll know."

---

## Backoff Strategies

The master smith taught three techniques for working the anvil, each suited to different metals:

```dart
// Exponential: 1s, 2s, 4s, 8s, 16s — for network failures
final aggressive = AnvilBackoff.exponential(
  initial: Duration(seconds: 1),
  multiplier: 2.0,
);

// Linear: 500ms, 1000ms, 1500ms — for rate-limited APIs
final gentle = AnvilBackoff.linear(
  initial: Duration(milliseconds: 500),
  increment: Duration(milliseconds: 500),
);

// Constant: 2s, 2s, 2s — for simple polling retries
final steady = AnvilBackoff.constant(Duration(seconds: 2));
```

"And when many operations fail at once," the smith added, "use jitter to prevent them all from retrying at the same instant."

```dart
final withJitter = AnvilBackoff.exponential(
  initial: Duration(seconds: 1),
  jitter: true, // Adds up to 25% random variation
  maxDelay: Duration(minutes: 5), // Safety cap
);
```

---

## The Dead Letter Queue

Not all repairs succeed. Some metal is too damaged, some operations too broken. When an entry exhausts all its retries, it doesn't vanish — it moves to the dead letter queue for manual inspection.

```dart
class SyncPillar extends Pillar {
  late final syncRetry = anvil<String>(
    maxRetries: 3,
    backoff: AnvilBackoff.exponential(),
    name: 'sync',
  );

  void checkDeadLetters() {
    for (final entry in syncRetry.deadLetters) {
      log.warning(
        'Dead letter: ${entry.id}, '
        'attempts: ${entry.attempts}, '
        'error: ${entry.lastError}',
      );
    }
  }

  // Re-enqueue all dead letters for another round
  void retryAllDead() {
    final count = syncRetry.retryDeadLetters();
    log.info('Re-enqueued $count dead letters');
  }

  // Purge dead letters that are beyond saving
  void clearDead() {
    syncRetry.purge();
  }
}
```

"The dead letter queue is your safety net," Kael told the apprentices. "Operations don't disappear into the void. They wait, with full metadata, for someone to decide their fate — retry, inspect, or discard."

---

## The Reactive Dashboard

Every metric on the Anvil was reactive — a living signal that flowed into dashboards and UI widgets:

```dart
class MonitorPillar extends Pillar {
  late final queue = anvil<String>(
    maxRetries: 5,
    name: 'operations',
  );

  late final healthSummary = derived(() =>
    'Pending: ${queue.pendingCount}, '
    'Dead: ${queue.deadLetterCount}, '
    'Succeeded: ${queue.succeededCount}'
  );

  late final hasProblems = derived(() =>
    queue.deadLetterCount > 0
  );
}
```

The watchtower screens updated in real-time:
- **Pending count** — operations waiting for their next attempt
- **Retrying count** — operations currently being hammered
- **Succeeded count** — operations that recovered
- **Dead letter count** — operations that need human attention
- **Total enqueued** — lifetime operations that passed through the queue

---

## Entry Lifecycle

The smith drew the lifecycle on the forge wall:

```
   ┌───────────┐   success    ┌───────────┐
   │  PENDING  │ ──────────→ │ SUCCEEDED │
   └───────────┘              └───────────┘
        │
        │ failure (retries remain)
        ↓
   ┌───────────┐   success    ┌───────────┐
   │ RETRYING  │ ──────────→ │ SUCCEEDED │
   └───────────┘              └───────────┘
        │
        │ failure (no retries left)
        ↓
   ┌───────────────┐
   │ DEAD_LETTERED │ → manual retryDeadLetters()
   └───────────────┘
```

"Every entry knows exactly where it is in the process," the smith said. "Its attempt count, its last error, its timing — all available for inspection."

---

## Per-Entry Overrides

Sometimes a particularly important piece of metal deserved extra hammering:

```dart
// Critical payment — more retries than the default
queue.enqueue(
  () => api.processPayment(order),
  id: 'payment-${order.id}',
  maxRetries: 10, // Override queue default of 3
  onSuccess: (result) {
    log.info('Payment recovered: $result');
  },
);
```

---

## The Lesson

That evening, as the last dead letter was either resolved or acknowledged, Kael recorded the principle in the engineering codex:

> *"In a distributed world, failure is not exceptional — it is expected. The difference between a fragile system and a resilient one is what happens after the first failure. A fragile system loses the operation forever. A resilient system puts it on the Anvil and hammers until it either succeeds or lands in a place where humans can see it and decide."*

The Anvil taught three truths:

1. **Failed operations must never vanish** — Every failure should be captured with full context: what failed, how many times, which error, and when. Silent data loss is the most insidious bug.

2. **Retries must be intelligent** — Exponential backoff prevents thundering herds. Jitter prevents synchronized retries. Max delays prevent infinite waits. Each strategy exists because someone learned the hard way.

3. **Dead letters are a feature** — When retries are exhausted, the operation doesn't get discarded. It gets preserved with full metadata for human inspection. Sometimes the fix is a code change, not another retry.

---

| Navigation | |
|---|---|
| [← Chapter XXXVII: The Portcullis Descends](chapter-37-the-portcullis-descends.md) | [Chapter XXXIX →](chapter-39-the-next-chapter.md) |
