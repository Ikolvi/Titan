# Chapter XXXVI: The Ledger Binds

> *"The scribes of old did not write with ink that could be half-spilled. Their ledgers were complete or they were blank. A partial entry was worse than no entry — it was a lie told to future readers. And so the scribes bound their quills: write all or write nothing."*

---

## The Problem

Questboard's checkout flow had a lurking bug. When a hero completed a quest, three things needed to happen:

1. Deduct the reward from the guild treasury
2. Credit the hero's account
3. Record the completion in the quest log

"It works perfectly," Kael said, "until the server hiccups during step two."

Lyra frowned. "What happens then?"

"The treasury is debited, but the hero never gets paid. The quest log is never updated. We're left with half-completed state — the worst kind of bug because it *looks* like it worked from the treasury's perspective."

She pulled up the code:

```dart
void completeQuest(Quest quest, Hero hero) {
  strike(() {
    treasury.value -= quest.reward;       // Step 1 ✓
    hero.gold.value += quest.reward;      // Step 2 💥 throws!
    questLog.value = [...questLog.value, quest.id]; // Step 3 — never reached
  });
}
```

"Strike batches the *notifications*," Lyra said. "But it doesn't batch the *state changes*. If step two throws, step one has already mutated the treasury. There's no rollback."

Kael listed what they needed:

1. **Atomicity** — all changes commit together or none do
2. **Rollback** — if any step fails, revert all Cores to their pre-mutation values
3. **Audit trail** — record what happened (committed, rolled back, failed)
4. **Reactive status** — track active transactions, commit counts, failure counts
5. **Manual and automatic modes** — `transact()` for simple cases, `begin()`/`commit()`/`rollback()` for complex workflows

"Database transactions," Kael said. "But for in-memory state."

"We open a **Ledger**," Lyra replied.

---

## The Ledger

A **Ledger** is a reactive state transaction manager. Before you mutate any Core, you `capture` its current value. If the transaction succeeds, changes commit atomically. If it fails, every captured Core reverts to its pre-transaction snapshot.

```dart
class CheckoutPillar extends Pillar {
  late final treasury = core(10000);
  late final heroGold = core(0);
  late final questLog = core(<String>[]);
  late final txManager = ledger(name: 'checkout');

  Future<void> completeQuest(String questId, int reward) async {
    await txManager.transact((tx) async {
      tx.capture(treasury);
      tx.capture(heroGold);
      tx.capture(questLog);

      treasury.value -= reward;
      heroGold.value += reward;

      // If this throws, treasury and heroGold revert automatically
      await api.recordCompletion(questId);

      questLog.value = [...questLog.value, questId];
    }, name: 'complete-quest');
  }
}
```

If `api.recordCompletion()` throws, the treasury gets its gold back, the hero's balance returns to zero, and the quest log is unchanged. No partial state corruption.

---

## Two Modes: Auto and Manual

### Auto Mode — `transact()` and `transactSync()`

The simplest way. Auto-commits on success, auto-rolls back on exception:

```dart
// Async
await ledger.transact((tx) async {
  tx.capture(a);
  tx.capture(b);
  a.value = 10;
  b.value = await fetchValue();
}, name: 'async-update');

// Sync
ledger.transactSync((tx) {
  tx.capture(a);
  tx.capture(b);
  a.value = 10;
  b.value = 20;
}, name: 'sync-update');
```

Both return the value produced by the action function:

```dart
final orderId = await ledger.transact((tx) async {
  tx.capture(inventory);
  inventory.value -= qty;
  return await api.createOrder(qty);
});
print(orderId); // e.g., 'order-42'
```

### Manual Mode — `begin()` / `commit()` / `rollback()`

For workflows that need conditional commit logic:

```dart
final tx = ledger.begin(name: 'multi-step');

tx.capture(step1Core);
step1Core.value = 'started';

// ... some conditional logic ...
if (shouldProceed) {
  tx.capture(step2Core);
  step2Core.value = 'completed';
  tx.commit(); // All changes finalized
} else {
  tx.rollback(); // step1Core reverts to its original value
}
```

After commit or rollback, the transaction is finalized. Attempting to use it again throws `StateError`.

---

## Capturing Cores

The `capture()` method snapshots a Core's current value *before* you mutate it. This is the value that will be restored on rollback.

```dart
final tx = ledger.begin();

tx.capture(name);   // Snapshots current value of 'name'
tx.capture(email);  // Snapshots current value of 'email'

name.value = 'Alice';
email.value = 'alice@example.com';

// If we rollback now, name and email revert to their pre-capture values
```

Key rules:
- **Capture before mutating** — if you mutate first, the snapshot holds the already-mutated value
- **Double capture is a no-op** — capturing the same Core twice doesn't overwrite the first snapshot
- **Uncaptured Cores aren't affected** — only captured Cores revert on rollback

```dart
final tx = ledger.begin();
tx.capture(a);
a.value = 10;
a.value = 20;
a.value = 30;
tx.rollback();
// a.value is back to its pre-capture value, NOT 10 or 20
```

---

## Reactive Properties

Ledger exposes reactive state for UI-driven status displays:

```dart
ledger.activeCount    // Number of currently open transactions
ledger.commitCount    // Total successful commits
ledger.rollbackCount  // Total rollbacks
ledger.failCount      // Total failed transactions (exceptions)
ledger.hasActive      // Whether any transaction is currently open
```

These are backed by internal Cores, so they participate in reactive tracking:

```dart
Vestige<CheckoutPillar>(
  builder: (_, p) {
    if (p.txManager.hasActive) {
      return const CircularProgressIndicator();
    }
    return Text('Completed: ${p.txManager.commitCount} transactions');
  },
)
```

---

## Transaction History

Ledger records every completed transaction as a `LedgerRecord`:

```dart
final records = ledger.history; // Most recent first

for (final r in records) {
  print('TX #${r.id}: ${r.status.name}');
  print('  Cores modified: ${r.coreCount}');
  print('  Time: ${r.timestamp}');
  if (r.error != null) print('  Error: ${r.error}');
  if (r.name != null) print('  Name: ${r.name}');
}
```

The `maxHistory` parameter controls how many records are retained (default: 100). Oldest records are evicted when the limit is exceeded.

```dart
late final txManager = ledger(maxHistory: 50, name: 'checkout');
```

---

## In Questboard

Kael rewrote the quest completion flow:

```dart
class QuestCompletionPillar extends Pillar {
  late final treasury = core(50000);
  late final heroBalance = core(0);
  late final completedQuests = core(<String>[]);
  late final pendingRewards = core(0);

  late final txManager = ledger(name: 'quest-completion');

  /// Derived: transaction status text.
  late final statusText = derived(() {
    if (txManager.hasActive) return 'Processing...';
    return 'Completed ${txManager.commitCount} | '
        'Rolled back ${txManager.rollbackCount} | '
        'Failed ${txManager.failCount}';
  });

  Future<void> completeQuest(String questId, int reward) async {
    try {
      await txManager.transact((tx) async {
        tx.capture(treasury);
        tx.capture(heroBalance);
        tx.capture(completedQuests);
        tx.capture(pendingRewards);

        treasury.value -= reward;
        heroBalance.value += reward;
        pendingRewards.value++;

        // Simulate server call that might fail
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (reward > treasury.peek()) {
          throw Exception('Insufficient treasury funds');
        }

        completedQuests.value = [...completedQuests.value, questId];
        pendingRewards.value--;
      }, name: 'complete-$questId');
    } catch (e) {
      // Transaction auto-rolled back; state is clean
      log.warning('Quest completion failed: $e');
    }
  }

  /// Batch complete multiple quests — each in its own transaction
  Future<void> batchComplete(List<(String, int)> quests) async {
    for (final (id, reward) in quests) {
      await completeQuest(id, reward);
    }
  }
}
```

And in the UI:

```dart
Vestige<QuestCompletionPillar>(
  builder: (_, p) => Column(
    children: [
      // Status bar — auto-updates
      Card(
        child: ListTile(
          leading: p.txManager.hasActive
              ? const CircularProgressIndicator()
              : const Icon(Icons.check_circle, color: Colors.green),
          title: Text(p.statusText.value),
          subtitle: Text('Treasury: ${p.treasury.value} gold'),
        ),
      ),

      // Transaction history
      ...p.txManager.history.reversed.take(5).map((r) => ListTile(
        title: Text('TX #${r.id}: ${r.name ?? "unnamed"}'),
        subtitle: Text('${r.status.name} — ${r.coreCount} cores'),
        trailing: r.status == LedgerStatus.failed
            ? const Icon(Icons.error, color: Colors.red)
            : const Icon(Icons.check, color: Colors.green),
      )),
    ],
  ),
)
```

"No more half-applied state," Lyra said. "The treasury either loses gold *and* the hero gains it, or neither happens. The Ledger doesn't deal in half-truths."

---

## Under the Hood

1. **Capture** snapshots the current value of each Core via `peek()` (non-tracking read).
2. **Mutations** happen normally — Cores are modified in place, notifications proceed as usual.
3. **Commit** is a no-op on the state side — values are already applied. It records the transaction in history and updates reactive counters.
4. **Rollback** restores each captured Core to its snapshot value via `titanBatch` — one notification wave for all reversions.
5. **Failed transactions** (`transact` with exception) auto-rollback and record the error in history.

Internal reactive nodes:
- `_activeCountCore` (`TitanState<int>`) — tracks open transaction count
- `_commitCountCore`, `_rollbackCountCore`, `_failCountCore` — lifetime counters
- `_hasActiveComputed` (`TitanComputed<bool>`) — derived from activeCount

All nodes register via `managedNodes`/`managedStateNodes` for Pillar auto-disposal.

---

## Performance

Ledger is designed for minimal overhead on the happy path:

| Operation | µs/op |
|-----------|-------|
| Create | 0.314 |
| Begin + Commit (empty) | 0.476 |
| Capture (3 Cores) + Commit | 0.635 |
| Rollback (3 Cores) | 1.422 |
| `transactSync` (1 Core) | 0.754 |

Sub-microsecond commits mean you can use transactions liberally without measurable impact.

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Ledger` | Reactive state transaction manager |
| `ledger()` | Pillar factory method — auto-managed lifecycle |
| `LedgerTransaction` | Individual transaction scope |
| `begin()` | Start a manual transaction |
| `transact()` | Auto-commit/rollback async transaction |
| `transactSync()` | Auto-commit/rollback sync transaction |
| `capture(core)` | Snapshot a Core's value before mutation |
| `commit()` | Finalize transaction — keep all changes |
| `rollback()` | Revert all captured Cores to pre-transaction values |
| `LedgerStatus` | `active`, `committed`, `rolledBack`, `failed` |
| `LedgerRecord` | Completed transaction audit entry |
| `activeCount` / `commitCount` / `rollbackCount` / `failCount` | Reactive counters |
| `hasActive` | Reactive: is a transaction currently open? |
| `history` | Transaction audit trail |
| `maxHistory` | Limit how many records are retained |

---

> *"The Ledger was opened, and every transaction in Questboard was bound — all or nothing, complete or void. The treasury no longer lost gold without giving it. The heroes no longer gained what wasn't owed. The arithmetic of the kingdom balanced, because the Ledger did not permit otherwise."*

---

[← Chapter XXXV: The Mandate Decrees](chapter-35-the-mandate-decrees.md) | [Chapter XXXVII: The Portcullis Descends →](chapter-37-the-portcullis-descends.md)
