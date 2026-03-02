# Chapter XIV: The Enterprise Arsenal

*In which the Questboard grows beyond a prototype, and Kael discovers tools forged for production warfare.*

---

The Questboard was live. Real users. Real quests. Real problems.

The first bug report came in at 6:47 AM: "I renamed my hero three times and now the app froze." The second came at 7:12 AM: "The quest list flickers every time I scroll." The third was from the CTO: "Can we see who changed what, and when?"

Kael stared at the backlog. The Questboard wasn't a prototype anymore. It needed enterprise armor.

---

## Core Extensions — Quick Strikes

> *A hero's blade should swing fast. Core Extensions add convenience methods that eliminate verbose mutation patterns.*

Kael found himself writing `count.value = count.value + 1` everywhere. Then he discovered the **Core Extensions**:

```dart
class QuestboardPillar extends Pillar {
  late final glory = core(0);
  late final questsCompleted = core(0);
  late final isPremium = core(false);
  late final tags = core<List<String>>([]);
  late final settings = core<Map<String, dynamic>>({});

  void awardGlory(int amount) {
    // Instead of: glory.value = glory.value + amount
    glory.increment(amount);
    questsCompleted.increment();
  }

  void togglePremium() {
    // Instead of: isPremium.value = !isPremium.value
    isPremium.toggle();
  }

  void addTag(String tag) {
    // Instead of: tags.value = [...tags.value, tag]
    tags.add(tag);
  }

  void clearCompletedTags() {
    tags.removeWhere((t) => t.startsWith('done:'));
  }
}
```

Available extensions:
- **`CoreBoolExtensions`** — `.toggle()`
- **`CoreIntExtensions`** — `.increment([amount])`, `.decrement([amount])`
- **`CoreDoubleExtensions`** — `.increment([amount])`, `.decrement([amount])`
- **`CoreListExtensions`** — `.add()`, `.addAll()`, `.removeWhere()`, `.updateWhere()`
- **`CoreMapExtensions`** — `.put(key, value)`, `.remove(key)`, `.putAll()`

### Under the Hood

Each extension mutates the value and triggers reactivity — no need to create a new list or map manually. The reactive system handles notifications automatically.

---

## Debounced & Throttled Strikes

> *Some actions fire too fast. Debounced Strikes delay until the flurry stops. Throttled Strikes limit the rate.*

The hero rename dialog was firing a strike on every keystroke. Kael switch to a debounced strike:

```dart
class QuestboardPillar extends Pillar {
  late final searchQuery = core('');

  void onSearchChanged(String query) {
    // Only fires after user stops typing for 300ms
    strikeDebounced(
      () => searchQuery.value = query,
      duration: const Duration(milliseconds: 300),
      tag: 'search', // Identifies this debounce group
    );
  }

  void onSliderChanged(double value) {
    // At most once per 100ms
    strikeThrottled(
      () => glory.value = value.toInt(),
      duration: const Duration(milliseconds: 100),
      tag: 'slider',
    );
  }
}
```

The `tag` parameter groups multiple calls — if the same tag fires again before the delay expires, the timer resets (debounce) or the call is dropped (throttle).

---

## Guarded Watch — Conditional Side Effects

> *Not every watcher should run all the time. Guarded watches only execute when a condition is met.*

```dart
@override
void onInit() {
  // Only log rank changes when premium mode is active
  watch(
    () => log.info('Rank: ${rank.value}'),
    when: () => isPremium.value,
  );
}
```

The `when` parameter is itself reactive — when `isPremium` changes from `false` to `true`, the watcher activates. When it changes back, the watcher stops.

---

## Pillar.onError — Per-Pillar Error Recovery

> *Global error handling with Vigil is great. But sometimes a Pillar needs to handle its own errors — show a snackbar, retry a fetch, or log context-specific information.*

```dart
class QuestListPillar extends Pillar {
  late final loadError = core<String?>(null);

  @override
  void onError(Object error, StackTrace? stackTrace) {
    // Set a user-facing error message
    loadError.value = error.toString();
    // Vigil still captures the error globally
  }
}
```

The `onError` hook fires whenever `captureError()` is called or when `strikeAsync()` catches an exception. The error is *always* captured by Vigil regardless.

---

## Auto-Dispose — Reference-Counted Pillars

> *Pillars that live forever waste memory. Auto-dispose Pillars clean up when their last consumer disconnects.*

```dart
class ModalPillar extends Pillar {
  late final data = core<String>('');

  @override
  void onInit() {
    enableAutoDispose();
  }

  @override
  void onAutoDispose() {
    log.info('ModalPillar cleaned up — no more consumers');
  }
}
```

When used with `Beacon` or `Vestige`, each widget `ref()`s the Pillar when it mounts and `unref()`s when it unmounts. When `refCount` reaches zero, the Pillar disposes itself.

---

## Async Initialization — onInitAsync

> *Some Pillars need to load data before they're ready. `onInitAsync()` provides a reactive readiness indicator.*

```dart
class ConfigPillar extends Pillar {
  late final settings = core<Map<String, dynamic>>({});

  @override
  Future<void> onInitAsync() async {
    final config = await loadConfig();
    settings.value = config;
  }
}

// In the widget tree:
Vestige<ConfigPillar>(
  builder: (context, pillar) {
    if (!pillar.isReady.value) {
      return const CircularProgressIndicator();
    }
    return Text('Welcome to ${pillar.settings.value['appName']}');
  },
)
```

The `isReady` Core starts as `false` and becomes `true` when `onInitAsync()` completes. Widgets that read `isReady.value` automatically rebuild when it changes.

---

## Core.select — Fine-Grained Reactivity

> *When a Core holds a complex object, every change rebuilds every consumer — even if only one field changed. `select` creates a focused lens on a sub-value.*

```dart
class UserPillar extends Pillar {
  late final user = core(User(name: 'Kael', email: 'kael@questboard.io'));

  // Only triggers when the name changes, not when email changes
  late final userName = user.select((u) => u.name);
}
```

The `select` creates a `Derived` that extracts one field. Downstream consumers only rebuild when the *selected* value changes — even if the parent object has other mutations.

---

## Aegis — Retry with Backoff

> *Network requests fail. Aegis retries them with exponential backoff, jitter, and configurable strategies.*

```dart
final result = await Aegis.run(
  () => api.fetchQuest('quest-42'),
  maxAttempts: 3,
  strategy: BackoffStrategy.exponential,
  baseDelay: const Duration(seconds: 1),
  jitter: true,
);
```

Strategies:
- **`BackoffStrategy.exponential`** — 1s → 2s → 4s → 8s...
- **`BackoffStrategy.linear`** — 1s → 2s → 3s → 4s...
- **`BackoffStrategy.constant`** — 1s → 1s → 1s...

Use the `retryIf` predicate to retry only on specific errors:

```dart
final result = await Aegis.run(
  () => api.fetchQuest('quest-42'),
  maxAttempts: 5,
  retryIf: (e) => e is SocketException || e is TimeoutException,
  onRetry: (attempt, error, nextDelay) {
    log.warning('Retry $attempt: $error (next in $nextDelay)');
  },
);
```

---

## Sigil — Feature Flags

> *Not every feature should ship to every user. Sigil provides reactive feature flags that can be loaded from config, overridden in development, and queried from any Pillar.*

```dart
// Register feature flags
Sigil.register('dark_mode', false);
Sigil.register('new_quest_ui', false);

// Check a flag reactively
watch(() {
  if (Sigil.isEnabled('dark_mode')) {
    log.info('Dark mode activated');
  }
});

// Toggle at runtime
Sigil.enable('dark_mode');
Sigil.toggle('new_quest_ui');

// Load all flags at once
Sigil.loadAll({'dark_mode': true, 'new_quest_ui': false});

// Override for development/testing
Sigil.override('new_quest_ui', true);
```

---

## What Kael Learned

Looking at the refactored Questboard, Kael realized these weren't just "nice to have" features. They were the difference between a prototype and a production system:

- **Core Extensions** eliminated verbose state mutations
- **Debounced Strikes** prevented performance death-by-keystroke
- **Guarded Watch** kept side effects from running wild
- **onError** gave each Pillar its own error recovery
- **Auto-Dispose** prevented memory leaks from modal Pillars
- **Aegis** made network calls resilient
- **Sigil** let the team ship features safely

But the CTO's question lingered: *"Can we see who changed what, and when?"*

That answer would require something deeper. Something that recorded every state mutation in an immutable ledger.

Kael opened a new file and typed: `import 'package:titan/titan.dart'`.

The **Annals** were about to open.

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
| [XI](chapter-11-the-quarry-yields.md) | The Quarry Yields |
| [XII](chapter-12-the-confluence-converges.md) | The Confluence Converges |
| [XIII](chapter-13-the-lens-reveals.md) | The Lens Reveals |
| **XIV** | **The Enterprise Arsenal** ← You are here |
| [XV](chapter-15-the-loom-weaves.md) | The Loom Weaves |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
