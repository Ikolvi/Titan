# Chapter XXXI: The Trove Hoards

> *"In every kingdom, the wisest rulers kept a trove — a vault of the most precious things, guarded by time and memory. When the trove grew too full, the oldest treasures were quietly returned to the world, making room for the new. The trove never forgot what mattered most."*

> **Package:** This feature is in `titan_basalt` — add `import 'package:titan_basalt/titan_basalt.dart';` to use it.

---

## The Problem

Questboard had grown. Heroes everywhere loaded quest details, browsed reward lists, and checked leaderboards. Every screen hit the network. Every scroll fetched the same data again. The servers groaned.

"We're fetching the same quests over and over," Kael said, watching the network panel fill with duplicate requests. "A hero opens quest 42, closes it, opens it again — that's two API calls for identical data."

Lyra leaned forward. "We need a cache. But not just any cache — one that knows when data goes stale, one that evicts intelligently when memory is tight, and one whose stats are *reactive*."

"We need a **Trove**."

---

## The Trove

A trove is a hoard of precious things. Titan's `Trove<K, V>` is a reactive in-memory cache with TTL (time-to-live) expiry and LRU (least-recently-used) eviction — all with O(1) performance.

```dart
import 'package:titan/titan.dart';

class QuestCachePillar extends Pillar {
  late final questCache = trove<String, Quest>(
    defaultTtl: Duration(minutes: 10),
    maxEntries: 200,
    onEvict: (key, value, reason) {
      log.debug('Evicted quest $key ($reason)');
    },
  );

  Future<Quest> getQuest(String id) async {
    final cached = questCache.get(id);
    if (cached != null) return cached;

    final quest = await api.fetchQuest(id);
    questCache.put(id, quest);
    return quest;
  }
}
```

The `trove()` factory method on Pillar creates a managed Trove with automatic disposal. When the Pillar is disposed, the Trove — its timers, its reactive state, everything — is cleaned up automatically.

---

## TTL Expiry

Every entry in the Trove can have a time-to-live. After that duration, the entry is considered expired:

```dart
// Default TTL: 10 minutes for all entries
final cache = Trove<String, Quest>(
  defaultTtl: Duration(minutes: 10),
);

// Override per-entry
cache.put('hot-quest', quest, ttl: Duration(minutes: 1));  // expires sooner
cache.put('static-data', config, ttl: Duration(hours: 24)); // lasts longer
```

Expired entries are evicted lazily on access (no background thread storms) and periodically cleaned up by a configurable timer:

```dart
final cache = Trove<String, Quest>(
  defaultTtl: Duration(minutes: 5),
  cleanupInterval: Duration(seconds: 30), // purge expired entries every 30s
);
```

You can inspect remaining TTL:

```dart
final remaining = cache.remainingTtl('quest-42');
if (remaining != null && remaining.inSeconds < 30) {
  // Almost expired — prefetch
  prefetch('quest-42');
}
```

---

## LRU Eviction

When capacity is set and the cache is full, the *least-recently-used* entry is automatically evicted:

```dart
final cache = Trove<String, Quest>(
  maxEntries: 100,
);

// After 100 puts, the 101st evicts the least-recently-accessed entry
for (var i = 0; i < 101; i++) {
  cache.put('quest-$i', quests[i]);
}

// 'quest-0' was evicted (oldest and never accessed again)
assert(cache.get('quest-0') == null);
```

Internally, the Trove uses a doubly-linked list with a HashMap, giving O(1) performance for all operations — get, put, and eviction. No linear scans, no sorting.

---

## The Get-or-Put Pattern

The most common cache pattern — fetch from cache or compute and store — is a single call:

```dart
// Synchronous
final quest = cache.putIfAbsent('quest-42', () => computeQuest('42'));

// Asynchronous
final quest = await cache.getOrPut('quest-42', () async {
  return await api.fetchQuest('42');
});
```

`putIfAbsent` stores the value only if the key is absent (or expired). `getOrPut` does the same but supports async computation — perfect for network fetches.

---

## Reactive Cache Stats

Every Trove exposes reactive Cores for its statistics. These update automatically and drive UI rebuilds:

```dart
class CacheMonitorPillar extends Pillar {
  late final cache = trove<String, dynamic>(
    defaultTtl: Duration(minutes: 5),
    maxEntries: 500,
    name: 'api',
  );

  // These are Cores — they update reactively
  // cache.size       → current entry count
  // cache.hits       → total cache hits
  // cache.misses     → total cache misses
  // cache.evictions  → total evictions
  // cache.hitRate    → percentage (0.0–100.0)
}
```

In a Vestige:

```dart
Vestige<CacheMonitorPillar>(
  builder: (context, pillar) {
    return Column(
      children: [
        Text('Entries: ${pillar.cache.size.value}'),
        Text('Hit rate: ${pillar.cache.hitRate.toStringAsFixed(1)}%'),
        Text('Evictions: ${pillar.cache.evictions.value}'),
      ],
    );
  },
)
```

---

## Batch Operations

For efficiency, load or store multiple entries at once:

```dart
// Store many entries
cache.putAll({
  'quest-1': quest1,
  'quest-2': quest2,
  'quest-3': quest3,
});

// Retrieve many entries (skips expired/missing keys)
final results = cache.getAll(['quest-1', 'quest-2', 'quest-99']);
// results == {'quest-1': quest1, 'quest-2': quest2}
// quest-99 is missing → not in the result map
```

---

## Eviction Callbacks

The `onEvict` callback fires for every eviction, providing the reason:

```dart
final cache = Trove<String, Quest>(
  defaultTtl: Duration(minutes: 5),
  maxEntries: 100,
  onEvict: (key, value, reason) {
    switch (reason) {
      case TroveEvictionReason.expired:
        analytics.track('cache_expired', {'key': key});
      case TroveEvictionReason.capacity:
        analytics.track('cache_lru_evict', {'key': key});
      case TroveEvictionReason.manual:
        // Explicit evict() or clear() call
        break;
    }
  },
);
```

The three eviction reasons:

| Reason | When |
|--------|------|
| `TroveEvictionReason.expired` | TTL elapsed — entry is stale |
| `TroveEvictionReason.capacity` | LRU eviction — cache is full |
| `TroveEvictionReason.manual` | `evict()` or `clear()` called explicitly |

---

## Cache Inspection

```dart
// Check existence (without counting as a hit/miss)
if (cache.containsKey('quest-42')) { ... }

// Check if an entry is expired
if (cache.isExpired('quest-42')) { ... }

// Get remaining TTL
final remaining = cache.remainingTtl('quest-42');
print('Expires in ${remaining?.inSeconds}s');

// Manually evict
cache.evict('quest-42');

// Clear everything
cache.clear();

// Reset stats and clear
cache.reset();
```

---

## Pillar Integration

The `trove()` factory method on Pillar creates a managed Trove whose reactive Cores are automatically tracked and disposed:

```dart
class ProductPillar extends Pillar {
  late final products = trove<String, Product>(
    defaultTtl: Duration(minutes: 15),
    maxEntries: 300,
    name: 'products',
  );

  late final cacheStatus = derived(
    () => 'Products: ${products.size.value} cached, '
          '${products.hitRate.toStringAsFixed(0)}% hit rate',
  );
}
```

No manual cleanup needed — when the Pillar disposes, the Trove disposes with it.

---

## What You Learned

| Concept | Purpose |
|---------|---------|
| `Trove<K, V>` | TTL + LRU in-memory cache with O(1) operations |
| `trove()` | Pillar factory method — auto-managed lifecycle |
| `get()` / `put()` | Basic cache operations with lazy expiry |
| `getOrPut()` | Async fetch-or-cache pattern |
| `putIfAbsent()` | Sync compute-or-cache pattern |
| `putAll()` / `getAll()` | Batch cache operations |
| `size` / `hits` / `misses` / `evictions` | Reactive cache statistics (Cores) |
| `hitRate` / `missRate` | Percentage-based cache efficiency |
| `remainingTtl()` / `isExpired()` / `containsKey()` | Cache inspection |
| `TroveEvictionReason` | `expired`, `capacity`, `manual` |
| `onEvict` | Callback for eviction events |

---

> *"The Trove gleamed in the dark, its contents perfectly ordered — the newest treasures at the front, the stale ones quietly fading away. The heroes never noticed the cache. They only noticed that everything was faster. That was the point."*

---

[← Chapter XXX: The Cartograph Maps](chapter-30-the-cartograph-maps.md) | [Chapter XXXII: The Moat Defends →](chapter-32-the-moat-defends.md)
