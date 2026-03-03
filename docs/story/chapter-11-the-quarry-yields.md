# Chapter XI: The Quarry Yields

*In which Kael learns to mine data wisely — fetch once, cache smart, and show stale data while the fresh stuff loads.*

> **Package:** This feature is in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use it.

---

The bug report was embarrassing.

"When I open a quest detail, it shows a loading spinner. When I go back to the list and tap the same quest, it shows the spinner *again*. Why is it re-fetching data I just loaded two seconds ago?"

Kael looked at the code. Sure enough, every time the quest detail screen mounted, it called `api.getQuest(id)`. No caching. No staleness check. Just blind fetching.

In React land, there was TanStack Query. In Flutter's existing ecosystem... nothing as clean. But Titan had the **Quarry**.

---

## Mining the Quarry

> *A quarry is where raw resources are extracted. Titan's Quarry extracts your data from remote sources and refines it into reactive state — with caching, deduplication, and stale-while-revalidate built in.*

```dart
class QuestDetailPillar extends Pillar {
  final String questId;
  QuestDetailPillar(this.questId);

  late final questQuery = quarry<Quest>(
    fetcher: () => api.getQuest(questId),
    staleTime: Duration(minutes: 5),
    name: 'quest_$questId',
  );

  @override
  void onInit() => questQuery.fetch();
}
```

Kael read the key behaviors:

1. **First fetch**: `isLoading = true`, fetches data, stores result
2. **Fresh refetch**: Does nothing — data is still fresh (within `staleTime`)
3. **Stale refetch**: Keeps existing data visible, sets `isFetching = true`, fetches fresh data in the background
4. **Error**: Stores error, keeps any previous data visible

This was the stale-while-revalidate pattern, built into a single reactive primitive.

---

## Stale While Revalidate

The UI was seamless:

```dart
Vestige<QuestDetailPillar>(
  builder: (context, pillar) {
    final quest = pillar.questQuery.data.value;
    final isLoading = pillar.questQuery.isLoading.value;
    final isFetching = pillar.questQuery.isFetching.value;
    final error = pillar.questQuery.error.value;

    // Initial load — no data yet
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (quest == null) {
      return Center(child: Text('Error: $error'));
    }

    return Stack(
      children: [
        QuestDetailView(quest: quest),
        // Subtle background refresh indicator
        if (isFetching)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(),
          ),
      ],
    );
  },
)
```

The user experience was night and day:
- **First visit**: Loading spinner → data appears
- **Return visit** (within 5 minutes): Data appears *instantly* (cached), no spinner
- **Return visit** (after 5 minutes): Data appears instantly (stale cache), subtle progress bar at top while fresh data loads in background

---

## Deduplication

Kael's favorite feature was automatic deduplication:

```dart
// These run concurrently — but only ONE API call is made
await Future.wait([
  pillar.questQuery.fetch(),
  pillar.questQuery.fetch(),
  pillar.questQuery.fetch(),
]);
```

If a fetch was already in progress, subsequent `fetch()` calls returned the same future. No duplicate requests. No race conditions.

---

## Optimistic Updates

When the team added a "favorite quest" toggle, Kael used optimistic updates:

```dart
class QuestDetailPillar extends Pillar {
  // ... questQuery from above

  void toggleFavorite() {
    final current = questQuery.data.value!;
    // 1. Update UI immediately (optimistic)
    questQuery.setData(
      current.copyWith(isFavorite: !current.isFavorite),
    );
    // 2. Sync with server, refetch on failure
    strikeAsync(() async {
      try {
        await api.toggleFavorite(current.id);
      } catch (_) {
        await questQuery.refetch(); // Rollback to server truth
      }
    });
  }
}
```

`setData()` updated the cached data immediately, made `isStale = false` (fresh), and cleared any error. If the server call failed, `refetch()` replaced the optimistic data with the actual server state.

---

## Retry with Backoff

For unreliable network conditions, Kael added retry logic:

```dart
late final leaderboard = quarry<List<Hero>>(
  fetcher: () => api.getLeaderboard(),
  staleTime: Duration(minutes: 1),
  retry: QuarryRetry(
    maxAttempts: 3,
    baseDelay: Duration(seconds: 1), // 1s, 2s, 4s (exponential)
  ),
);
```

On failure, the Quarry retried with exponential backoff: 1 second, then 2 seconds, then 4 seconds. If all retries failed, the error was stored in `error` and `isLoading`/`isFetching` returned to `false`.

---

## Invalidation

When a quest was updated elsewhere (via Herald event), Kael invalidated the cache:

```dart
@override
void onInit() {
  questQuery.fetch();

  listen<QuestUpdated>((event) {
    if (event.questId == questId) {
      questQuery.invalidate(); // Mark stale
      questQuery.fetch();      // Refetch in background
    }
  });
}
```

`invalidate()` marked the data as stale without clearing it. The next `fetch()` performed a background refetch with stale-while-revalidate semantics.

---

## The Full Quarry API

| Reactive State | Type | Description |
|---------------|------|-------------|
| `data` | `Core<T?>` | The fetched data (null if not yet fetched) |
| `isLoading` | `Core<bool>` | Initial load in progress (no data) |
| `isFetching` | `Core<bool>` | Background refetch in progress (data exists) |
| `error` | `Core<Object?>` | Most recent error, or null |

| Property | Type | Description |
|----------|------|-------------|
| `hasData` | `bool` | Data is not null |
| `hasError` | `bool` | Error is not null |
| `isStale` | `bool` | Data needs refetch |

| Method | Description |
|--------|-------------|
| `fetch()` | Fetch if stale; no-op if fresh; deduplicates |
| `refetch()` | Force refetch regardless of staleness |
| `invalidate()` | Mark stale without refetching |
| `setData(T)` | Optimistic update |
| `reset()` | Clear all state |

---

## Testing the Quarry

```dart
void main() {
  test('stale-while-revalidate keeps data visible', () async {
    int calls = 0;
    final q = Quarry<String>(
      fetcher: () async {
        calls++;
        return 'data_$calls';
      },
      staleTime: Duration.zero, // Always stale
    );

    await q.fetch();
    expect(q.data.value, 'data_1');

    // Second fetch — data exists but is stale
    bool sawFetching = false;
    q.isFetching.addListener(() {
      if (q.isFetching.value) sawFetching = true;
    });

    await q.fetch();
    expect(sawFetching, true);     // Background indicator shown
    expect(q.data.value, 'data_2'); // Fresh data
    expect(calls, 2);

    q.dispose();
  });
}
```

---

## The Quarry Delivers

The quest detail screen now felt instant. Users tapped a quest, saw data immediately if cached, and barely noticed the background refresh. The PM was thrilled.

But then came a more complex screen — the quest dashboard — that needed data from *four* different Pillars simultaneously: the hero profile, the quest list, the notification count, and the theme settings.

Building four nested `Vestige` widgets felt wrong. Kael needed a way to converge multiple Pillars into a single builder.

He turned to the **Confluence**.

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
| [IX](chapter-09-the-scroll-inscribes.md) | The Scroll Inscribes |
| [X](chapter-10-the-codex-opens.md) | The Codex Opens |
| **XI** | **The Quarry Yields** ← You are here |
| [XII](chapter-12-the-confluence-converges.md) | The Confluence Converges |
| [XIII](chapter-13-the-lens-reveals.md) | The Lens Reveals |
| [XIV](chapter-14-the-enterprise-arsenal.md) | The Enterprise Arsenal |
| [XV](chapter-15-the-loom-weaves.md) | The Loom Weaves |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
