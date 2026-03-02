# Chapter X: The Codex Opens

*In which Kael learns to read the ancient pages one at a time, and discovers that infinite lists aren't so infinite after all.*

---

The quest board was growing. What started as a handful of test entries had turned into hundreds of real quests submitted by teams across the company. The list view that loaded everything at once was choking.

"Users are complaining about load times," the PM said, her tone sharpening. "We need pagination."

Kael had implemented pagination before. Create page variables, track loading states, handle append vs. replace, manage cursors, prevent duplicate requests during scroll events... it was always 50+ lines of fragile glue code.

Then he found the **Codex**.

---

## Opening the Codex

> *A codex is an ancient book — a collection of pages. Titan's Codex manages your data page by page.*

The API was deceptively simple:

```dart
class QuestListPillar extends Pillar {
  late final quests = codex<Quest>(
    (request) async {
      final result = await api.getQuests(
        page: request.page,
        limit: request.pageSize,
      );
      return CodexPage(
        items: result.items,
        hasMore: result.hasMore,
      );
    },
    pageSize: 20,
    name: 'quests',
  );

  @override
  void onInit() => quests.loadFirst();
}
```

One declaration. That was it. Kael stared at the `codex()` factory method, waiting for the catch. There wasn't one.

---

## Reading the Pages

The Codex provided reactive state for everything:

```dart
Vestige<QuestListPillar>(
  builder: (context, pillar) {
    final items = pillar.quests.items.value;
    final isLoading = pillar.quests.isLoading.value;
    final hasMore = pillar.quests.hasMore.value;
    final error = pillar.quests.error.value;

    if (isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && items.isEmpty) {
      return Center(child: Text('Error: $error'));
    }

    return ListView.builder(
      itemCount: items.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) {
          // Load more trigger
          pillar.quests.loadNext();
          return const Center(child: CircularProgressIndicator());
        }
        return QuestTile(quest: items[index]);
      },
    );
  },
)
```

Every field — `items`, `isLoading`, `hasMore`, `currentPage`, `error` — was a reactive Core. Vestige auto-tracked exactly which ones the builder read and rebuilt only when those changed.

---

## How the Pages Turn

Kael traced the lifecycle:

1. **`loadFirst()`** — Clears existing data, resets to page 0, fetches the first page
2. **`loadNext()`** — Appends the next page (no-op if already loading or no more pages)
3. **`refresh()`** — Clears everything and reloads from page 0

```dart
// In the Pillar
void refreshQuests() => quests.refresh();

// Pull-to-refresh in the UI
RefreshIndicator(
  onRefresh: () => pillar.quests.refresh(),
  child: questListView,
)
```

The `loadNext()` guard was particularly clever — it silently ignored calls when loading was already in progress or when there were no more pages. This meant Kael could safely call it from scroll listeners without worrying about duplicate requests.

---

## Cursor-Based Pagination

The next week, the API team migrated to cursor-based pagination. Kael's change was minimal:

```dart
class FeedPillar extends Pillar {
  late final feed = codex<Post>(
    (request) async {
      final result = await api.getFeed(
        cursor: request.cursor,
        limit: request.pageSize,
      );
      return CodexPage(
        items: result.posts,
        hasMore: result.hasMore,
        nextCursor: result.nextCursor, // ← cursor for next page
      );
    },
    pageSize: 10,
  );

  @override
  void onInit() => feed.loadFirst();
}
```

The `CodexRequest` carried both `page` (for offset pagination) and `cursor` (for cursor pagination). The Codex tracked the cursor from the previous response and passed it automatically to the next request.

---

## Testing the Codex

```dart
void main() {
  test('loads multiple pages and appends items', () async {
    int callCount = 0;
    final codex = Codex<String>(
      fetcher: (req) async {
        callCount++;
        if (req.page == 0) {
          return const CodexPage(
            items: ['Quest A', 'Quest B'],
            hasMore: true,
          );
        }
        return const CodexPage(
          items: ['Quest C'],
          hasMore: false,
        );
      },
      pageSize: 2,
    );

    await codex.loadFirst();
    expect(codex.items.value, ['Quest A', 'Quest B']);
    expect(codex.hasMore.value, true);

    await codex.loadNext();
    expect(codex.items.value, ['Quest A', 'Quest B', 'Quest C']);
    expect(codex.hasMore.value, false);
    expect(callCount, 2);

    // loadNext is a no-op now
    await codex.loadNext();
    expect(callCount, 2); // Not called again

    codex.dispose();
  });
}
```

Pure Dart. No mocks. The Codex was a standalone unit that could be tested without Flutter.

---

## The Anatomy of a Codex

| Reactive State | Type | Description |
|---------------|------|-------------|
| `items` | `Core<List<T>>` | All accumulated items across pages |
| `isLoading` | `Core<bool>` | Whether a page fetch is in progress |
| `hasMore` | `Core<bool>` | Whether more pages are available |
| `currentPage` | `Core<int>` | Current page number (0-indexed) |
| `error` | `Core<Object?>` | Most recent error, or null |

| Method | Description |
|--------|-------------|
| `loadFirst()` | Clear and fetch page 0 |
| `loadNext()` | Fetch next page (guarded) |
| `refresh()` | Clear and reload from page 0 |

| Convenience | Type | Description |
|-------------|------|-------------|
| `isEmpty` | `bool` | No items and not loading |
| `isNotEmpty` | `bool` | Has at least one item |
| `itemCount` | `int` | Total items loaded so far |

---

## Turning the Page

The paginated quest list was deployed by end of day. Load times dropped from 4 seconds to under 200ms for the first visible page. Users scrolled smoothly through hundreds of quests with zero jank.

But Kael noticed something: some data was being fetched multiple times across different screens. The user profile, for instance, was loaded on the dashboard, the settings page, and the quest detail screen. Three identical API calls.

There had to be a smarter way to fetch data — one that cached, invalidated, and revalidated automatically.

Kael turned to the **Quarry**.

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
| **X** | **The Codex Opens** ← You are here |
| [XI](chapter-11-the-quarry-yields.md) | The Quarry Yields |
| [XII](chapter-12-the-confluence-converges.md) | The Confluence Converges |
| [XIII](chapter-13-the-lens-reveals.md) | The Lens Reveals |
| [XIV](chapter-14-the-enterprise-arsenal.md) | The Enterprise Arsenal |
| [XV](chapter-15-the-loom-weaves.md) | The Loom Weaves |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
