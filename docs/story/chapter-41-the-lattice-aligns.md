# Chapter XLI: The Lattice Aligns

> *"Before the Lattice, every initialization was a gamble — load too early and dependencies crumble, load too late and the world waits. Tasks that could run in parallel were chained single-file, wasting precious seconds while heroes stared at loading spinners. The Lattice brought order to the chaos: declare what depends on what, and let the engine find the fastest path."*

---

## The Problem

The Questboard had grown from a simple list to a full platform — configuration, authentication, feature flags, user data, quest catalogs, leaderboards. Each system needed to initialize at startup, but they weren't independent:

- **Config** had to load first (everything depended on it)
- **Auth** needed config (for API endpoints)
- **Feature flags** needed config (for flag sources)
- **User data** needed auth (to know which user)
- **Quest catalog** needed auth AND feature flags (to filter by permissions)
- **Leaderboard** needed user data (to highlight the hero's rank)

Kael had been chaining these with `await`:

```dart
final config = await loadConfig();
final auth = await authenticate(config);
final flags = await loadFlags(config);       // Waits for auth unnecessarily!
final userData = await loadUserData(auth);
final quests = await loadQuests(auth, flags);
final board = await loadLeaderboard(userData);
```

"Auth and flags are independent," Lyra observed. "They both need config, but not each other. They should run in parallel."

"And quests only needs auth and flags — it doesn't need to wait for user data," Kael added.

"You need a way to declare the dependency graph, then let the engine resolve the optimal execution order. You need the **Lattice**."

---

## The Lattice

A lattice is a mathematical structure where elements are connected by a partial order. In Titan, `Lattice` is a reactive DAG (directed acyclic graph) task executor that resolves dependencies and maximizes parallelism:

```dart
class AppPillar extends Pillar {
  late final startup = lattice(name: 'startup');

  @override
  void onInit() {
    startup
      ..node('config', (_) => loadConfig())
      ..node('auth', (r) => authenticate(r['config']),
          dependsOn: ['config'])
      ..node('flags', (r) => loadFlags(r['config']),
          dependsOn: ['config'])
      ..node('userData', (r) => loadUserData(r['auth']),
          dependsOn: ['auth'])
      ..node('quests', (r) => loadQuests(r['auth'], r['flags']),
          dependsOn: ['auth', 'flags'])
      ..node('board', (r) => loadLeaderboard(r['userData']),
          dependsOn: ['userData']);

    startup.execute();
  }
}
```

The Lattice analyzes the graph and produces this execution plan:

```text
Round 1:  config
Round 2:  auth, flags          ← parallel!
Round 3:  userData, quests     ← parallel!
Round 4:  board
```

What took 6 sequential awaits now completes in 4 rounds, with independent tasks running simultaneously.

---

## How It Works

### Node Registration

Each node has an ID, a task function, and an optional list of dependencies:

```dart
lattice.node('config', (_) async => await loadConfig());
lattice.node('auth', (upstream) async {
  final config = upstream['config'] as Config;
  return await authenticate(config);
}, dependsOn: ['config']);
```

The `upstream` map contains the return values of all completed dependencies, keyed by node ID. This lets downstream tasks access their prerequisites' results without global state.

### Execution

Calling `execute()` triggers Kahn's algorithm for topological sorting:

1. Compute in-degree (number of unmet dependencies) for each node
2. Find all nodes with in-degree 0 — they're ready immediately
3. Execute ready nodes in parallel via `Future.wait`
4. When a node completes, decrement in-degrees of its dependents
5. Repeat until all nodes complete or an error occurs

### Error Handling

Lattice uses **fail-fast** semantics: if any task throws, execution stops immediately. Downstream tasks that depended on the failed node never execute:

```dart
final result = await startup.execute();
if (!result.succeeded) {
  for (final entry in result.errors.entries) {
    print('Task ${entry.key} failed: ${entry.value}');
  }
}
```

The `LatticeResult` captures both successful values and errors, along with execution order and wall-clock timing.

---

## Reactive Progress

The Lattice provides reactive state for UI integration:

| Property | Type | Description |
|----------|------|-------------|
| `status` | `Core<LatticeStatus>` | idle → running → completed/failed |
| `completedCount` | `Core<int>` | Number of finished tasks |
| `progress` | `Derived<double>` | 0.0 to 1.0 completion ratio |

```dart
// In a splash screen Vestige:
Vestige<AppPillar>(
  builder: (context, pillar) {
    final progress = pillar.startup.progress.value;
    final status = pillar.startup.status.value;

    if (status == LatticeStatus.running) {
      return LinearProgressIndicator(value: progress);
    }
    if (status == LatticeStatus.failed) {
      return Text('Startup failed');
    }
    return MainApp();
  },
)
```

---

## Graph Inspection

Before execution, you can inspect the graph for debugging:

```dart
startup.nodeIds;              // ['config', 'auth', 'flags', ...]
startup.nodeCount;            // 6
startup.dependenciesOf('auth'); // ['config']
startup.hasCycle;             // false — safe to execute
```

The `hasCycle` check uses Kahn's algorithm without executing, catching circular dependencies at configuration time rather than runtime.

---

## Re-Execution

After completion, call `reset()` to return to idle state:

```dart
startup.reset();
// Modify nodes or re-execute
final result = await startup.execute();
```

This is useful for retry-on-failure scenarios or periodic re-initialization.

---

## Performance

The Lattice is built for speed:

| Operation | 4 nodes | 10 nodes | 100 nodes |
|-----------|---------|----------|-----------|
| Chain (sequential) | — | 47 µs | 476 µs |
| Wide (parallel) | — | 8 µs | 57 µs |
| Diamond | 4 µs | — | — |
| Create | 0.39 µs | — | — |
| Cycle check | — | 5 µs | — |

Note how wide (fully parallel) graphs execute much faster than chains — the Lattice automatically maximizes concurrency.

---

## What Was Learned

1. **Declare dependencies, not order** — Instead of manually sequencing async operations, declare what depends on what. Let the engine find the optimal execution order.
2. **Maximize parallelism automatically** — Independent tasks run simultaneously without manual `Future.wait` wiring.
3. **Upstream result passing** — Tasks receive their dependencies' results through the `upstream` map, eliminating the need for shared mutable state.
4. **Fail-fast correctness** — When a task fails, downstream dependents are never started. No wasted computation, no cascading errors.
5. **Reactive progress** — The Lattice's reactive state (progress, status, completedCount) integrates naturally with Vestige for loading UIs.

The Lattice had proven its worth. Startup time dropped by 40% as independent systems loaded in parallel. The loading spinner was replaced with a smooth progress bar. And when a dependency graph changed, only the declaration needed updating — the engine handled the rest.

---

*Next: [Chapter XLII →](chapter-42-todo.md)*
