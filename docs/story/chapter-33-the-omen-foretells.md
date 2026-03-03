# Chapter XXXIII: The Omen Foretells

> *"The oracle did not predict one future — she watched the present, and when the present changed, she spoke a new prophecy. Her visions were never stale, never late. They arrived precisely when the omens shifted."*

---

## The Problem

Questboard's search page was getting complicated. Heroes could filter quests by keyword, difficulty, region, and sort order — four independent inputs, all driving a single API call. Every time a hero changed any filter, the results had to refresh.

"Right now we're wiring up listeners on each filter Core, calling an `_updateResults()` method, debouncing manually, managing loading flags, tracking previous data for skeleton screens..." Kael stared at the tangled mess of watchers and async state in `SearchPillar`. "It's forty lines of ceremony for something that should be one declaration."

Lyra frowned. "It's the same pattern on the dashboard. Three Cores feed an API call. When any of them change, we re-fetch. We debounce. We show stale data while refreshing. Every time, we write it from scratch."

"A `Derived` handles this beautifully for synchronous values," Kael said. "You declare `derived(() => a.value + b.value)` and Titan auto-tracks the dependencies. But the moment the computation is async — an API call, a database query — we're back to manual plumbing."

"We need a Derived that understands `Future`."

"We need an **Omen**."

---

## The Omen

An omen is a sign of things to come. Titan's `Omen<T>` is a reactive async Derived — it evaluates an asynchronous computation and automatically re-executes whenever the Core values read inside it change, just as `Derived` does for synchronous values.

```dart
import 'package:titan/titan.dart';

class SearchPillar extends Pillar {
  late final query = core('');
  late final difficulty = core('all');
  late final region = core('all');
  late final sortBy = core('relevance');

  late final results = omen<List<Quest>>(
    () async => api.searchQuests(
      query: query.value,
      difficulty: difficulty.value,
      region: region.value,
      sort: sortBy.value,
    ),
    debounce: Duration(milliseconds: 300),
  );
}
```

That's it. No watchers. No manual debouncing. No loading flags. The `omen()` factory method on Pillar creates a managed `Omen` that:

1. **Auto-tracks** every Core read inside the computation (`query`, `difficulty`, `region`, `sortBy`)
2. **Re-executes** whenever any of those Cores change
3. **Debounces** rapid changes so the API is called at most once every 300ms
4. **Shows previous data** while refreshing (stale-while-revalidate)
5. **Auto-disposes** when the Pillar disposes

---

## Reading the Prophecy

An Omen's value is an `AsyncValue<T>` — a sealed class with four states. Use `when()` for exhaustive matching:

```dart
final snapshot = pillar.results.value;

snapshot.when(
  onData: (quests) => QuestList(quests),
  onLoading: () => LoadingSpinner(),
  onError: (error, stackTrace) => ErrorBanner(error),
  onRefreshing: (staleQuests) => QuestList(staleQuests, dimmed: true),
);
```

Or use Dart's `switch` pattern matching for more control:

```dart
switch (pillar.results.value) {
  case AsyncData(:final data):
    return QuestList(data);
  case AsyncLoading():
    return LoadingSpinner();
  case AsyncRefreshing(:final data):
    return Stack(children: [QuestList(data), RefreshIndicator()]);
  case AsyncError(:final error):
    return ErrorBanner(error);
}
```

Both styles are exhaustive — the compiler ensures you handle every state.

---

## Auto-Tracking

The magic of Omen is the same dependency tracking that powers `Derived`. When the computation executes, Titan records every Core that is `.value`-read:

```dart
late final results = omen<List<Quest>>(
  () async {
    // These reads are tracked automatically:
    final q = query.value;       // dependency 1
    final d = difficulty.value;  // dependency 2
    final r = region.value;      // dependency 3
    final s = sortBy.value;      // dependency 4

    return api.searchQuests(query: q, difficulty: d, region: r, sort: s);
  },
);
```

Change `query`? The Omen re-executes. Change `sortBy`? Re-executes. Change both within the debounce window? One re-execution. Dependencies can even be *conditional*:

```dart
late final results = omen<List<Quest>>(
  () async {
    final q = query.value;
    if (q.isEmpty) return []; // region is NOT a dependency when query is empty
    return api.searchQuests(query: q, region: region.value);
  },
);
```

When `query` is empty, the Omen won't re-execute if `region` changes — because `region.value` was never read. The dependency set is rebuilt on every execution, just like `Derived`.

---

## Debounce

Heroes type fast. Without debouncing, every keystroke triggers an API call. The `debounce` parameter coalesces rapid dependency changes:

```dart
late final results = omen<List<Quest>>(
  () async => api.searchQuests(query: query.value),
  debounce: Duration(milliseconds: 300),
);
```

When `query` changes, the Omen waits 300ms of silence before executing. If `query` changes again within that window, the timer resets. The API is called only when the hero stops typing.

Without debounce, the Omen re-executes immediately on every dependency change — useful for computations backed by local databases or in-memory operations where latency is negligible.

---

## Stale-While-Revalidate

The `keepPreviousData` parameter (default: `true`) implements the stale-while-revalidate pattern. When a dependency changes and the Omen re-executes, the state transitions to `AsyncRefreshing` rather than `AsyncLoading`:

```dart
late final results = omen<List<Quest>>(
  () async => api.searchQuests(query: query.value),
  keepPreviousData: true, // default
);
```

The lifecycle:

1. **First load** — `AsyncLoading` → `AsyncData(results)`
2. **Dependency changes** — `AsyncRefreshing(previousResults)` → `AsyncData(newResults)`
3. **Error during refresh** — `AsyncError(error)`

This means the UI can continue showing the previous results (perhaps dimmed or with a refresh indicator) while the new data loads. No jarring blank screens.

To disable this and always show a full loading state:

```dart
late final results = omen<List<Quest>>(
  () async => api.searchQuests(query: query.value),
  keepPreviousData: false, // always AsyncLoading on re-execution
);
```

---

## Manual Control

Sometimes the prophecy needs a nudge.

### Refresh

Force a re-execution regardless of whether dependencies changed:

```dart
pillar.results.refresh(); // re-fetches from API
```

Useful for pull-to-refresh gestures or "retry" buttons.

### Cancel

Cancel the in-flight computation:

```dart
pillar.results.cancel(); // stops the current fetch
```

The state remains at its current value. Call `refresh()` to restart.

### Reset

Clear everything and start fresh:

```dart
pillar.results.reset(); // back to AsyncLoading, execution count → 0
```

This cancels any in-flight computation, resets the state to `AsyncLoading`, zeros the execution counter, and immediately re-executes.

---

## Reactive Diagnostics

The Omen tracks how many times it has executed:

```dart
// Reactive — can be read inside Derived or Vestige builders
final count = pillar.results.executionCount.value;
```

Combined with the convenience getters, this gives full observability:

```dart
pillar.results.isLoading;    // true during initial load
pillar.results.isRefreshing; // true during refresh (has previous data)
pillar.results.hasData;      // true if data is available
pillar.results.hasError;     // true if the last execution errored
pillar.results.data;         // T? — the data, or null
```

---

## A Complete Example

Kael rewrote the Questboard dashboard. Three reactive inputs — the selected guild, the date range, and whether to include completed quests — drive a stats aggregation API:

```dart
import 'package:titan/titan.dart';

class DashboardPillar extends Pillar {
  late final selectedGuild = core<String?>('all');
  late final dateRange = core(DateRange.lastWeek());
  late final includeCompleted = core(false);

  late final stats = omen<DashboardStats>(
    () async => api.fetchDashboardStats(
      guild: selectedGuild.value,
      from: dateRange.value.start,
      to: dateRange.value.end,
      includeCompleted: includeCompleted.value,
    ),
    debounce: Duration(milliseconds: 500),
    name: 'dashboard-stats',
  );

  late final statusText = derived(() {
    final exec = stats.executionCount.value;
    return stats.value.when(
      onData: (_) => 'Loaded ($exec fetches)',
      onLoading: () => 'Loading...',
      onError: (e, _) => 'Error: $e',
      onRefreshing: (_) => 'Refreshing ($exec fetches)...',
    );
  });
}
```

The `statusText` Derived is itself reactive — it re-evaluates whenever the Omen's state or execution count changes. Layers of reactivity, zero boilerplate.

In the UI:

```dart
Vestige<DashboardPillar>(
  builder: (context, pillar) {
    return switch (pillar.stats.value) {
      AsyncData(:final data) => DashboardView(stats: data),
      AsyncLoading() => const DashboardSkeleton(),
      AsyncRefreshing(:final data) => DashboardView(
        stats: data,
        refreshing: true,
      ),
      AsyncError(:final error) => RetryBanner(
        error: error,
        onRetry: pillar.stats.refresh,
      ),
    };
  },
)
```

---

## Eager vs Lazy

By default, an Omen executes eagerly on creation. Pass `eager: false` to defer execution until the first time `.value` is read:

```dart
late final heavyStats = omen<ExpensiveResult>(
  () async => api.computeExpensiveStats(),
  eager: false, // won't execute until someone reads heavyStats.value
);
```

This is useful for data that might never be needed — the computation only runs when a widget actually reads the value.

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Omen<T>` | Reactive async Derived with auto-dependency tracking |
| `omen<T>()` | Pillar factory method — auto-managed lifecycle |
| Auto-tracking | Core reads inside compute are detected automatically |
| `debounce` | Coalesce rapid dependency changes before re-executing |
| `keepPreviousData` | Stale-while-revalidate — show old data while refreshing |
| `refresh()` | Manual re-execution (ignores debounce) |
| `cancel()` | Cancel in-flight computation |
| `reset()` | Clear state, zero execution count, re-execute |
| `executionCount` | Reactive counter of completed executions |
| `value` | Current `AsyncValue<T>` state (reactive) |
| `data` / `isLoading` / `hasData` / `hasError` / `isRefreshing` | Convenience getters |
| `when()` / `switch` | Exhaustive pattern matching on AsyncValue |
| `eager` | If `false`, defers execution until first `.value` read |

---

> *"The Omen never slept. It watched every thread tied to its prophecy, and when any thread trembled, it spoke again — patiently, after the trembling stilled. The heroes never had to ask for the future. The future arrived on its own."*

---

[← Chapter XXXII: The Moat Defends](chapter-32-the-moat-defends.md) | [Chapter XXXIV →](chapter-34-the-pyre-burns.md)
