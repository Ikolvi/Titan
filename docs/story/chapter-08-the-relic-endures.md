# Chapter VIII: The Relic Endures

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"Kingdoms rise and fall. Apps are opened and closed. But some things must endure — the hero's name, the chosen theme, the position in a quest. The ancients preserved their knowledge in Relics: artifacts that survived the collapse of worlds, waiting patiently to restore what was lost when the next age began."*

---

## The Cold Start Problem

Kael watched a tester open Questboard, configure their hero name, set the theme to dark mode, complete three quests — and then close the app. When they reopened it:

"Where did my hero name go? Why is it back to light mode? My quest progress is gone!"

Everything was reactive. Everything was fast. Nothing was persistent.

Core values lived in memory. Memory died with the process. Kael needed a way to save state and restore it seamlessly — without wrecking the clean Pillar architecture.

---

## Relic — The Persistence Layer

**Relic** is Titan's persistence and hydration system. It bridges your reactive Cores to a storage backend, handling serialization, deserialization, and automatic saving.

```dart
import 'package:titan/titan.dart';

class SettingsPillar extends Pillar {
  late final heroName = core('Unknown Hero');
  late final theme = core('light');
  late final fontSize = core(14.0);

  late final relic = Relic(
    adapter: myStorageAdapter,
    entries: {
      'hero_name': RelicEntry<String>(
        core: heroName,
        toJson: (value) => value,
        fromJson: (json) => json as String,
      ),
      'theme': RelicEntry<String>(
        core: theme,
        toJson: (value) => value,
        fromJson: (json) => json as String,
      ),
      'font_size': RelicEntry<double>(
        core: fontSize,
        toJson: (value) => value,
        fromJson: (json) => (json as num).toDouble(),
      ),
    },
  );

  @override
  void onInit() async {
    // Restore all values from storage
    await relic.hydrate();

    // Auto-save whenever tracked Cores change
    relic.enableAutoSave();
  }

  void setTheme(String newTheme) => strike(() => theme.value = newTheme);
  void setHeroName(String name) => strike(() => heroName.value = name);
  void setFontSize(double size) => strike(() => fontSize.value = size);

  @override
  void onDispose() {
    relic.dispose();
    super.onDispose();
  }
}
```

Two lines in `onInit()`: `hydrate()` restores state from storage, `enableAutoSave()` watches for changes and persists them automatically. The Cores don't know they're being persisted. The Pillar stays clean.

---

## How Hydration Works

When you call `relic.hydrate()`, Relic:

1. Reads each key from the storage adapter
2. Deserializes the stored JSON via `fromJson`
3. Silently sets the Core's value (without triggering normal reactive notifications)

The "silent" part is crucial. Hydration restores state without firing watchers or rebuilding widgets. The values are there when the first build happens — as if they were always there.

```dart
final pillar = SettingsPillar();
pillar.initialize();
// After onInit completes:
// pillar.heroName.value → 'Kael the Bold' (restored from storage)
// pillar.theme.value → 'dark' (restored from storage)
// pillar.fontSize.value → 16.0 (restored from storage)
```

If a key doesn't exist in storage yet (first launch), the Core keeps its initial value. No crashes, no special handling needed.

---

## Auto-Save — Invisible Persistence

After calling `enableAutoSave()`, Relic watches every registered Core. When any value changes, Relic automatically:

1. Serializes the new value via `toJson`
2. Writes it to the storage adapter

```dart
// User changes theme
pillar.setTheme('dark');
// → Relic auto-saves 'theme' → 'dark' to storage

// User changes font size
pillar.setFontSize(16.0);
// → Relic auto-saves 'font_size' → 16.0 to storage

// App closes and reopens
// → relic.hydrate() restores 'dark' and 16.0
```

No manual save calls. No "save state" buttons. It just works.

---

## The Storage Adapter

Relic doesn't care *where* you store data. It works through a `RelicAdapter` — a simple abstract class:

```dart
abstract class RelicAdapter {
  Future<Object?> read(String key);
  Future<void> write(String key, Object value);
  Future<void> delete(String key);
  Future<void> clear();
}
```

Four methods. Implement them for any backend:

```dart
/// SharedPreferences adapter
class SharedPrefsRelicAdapter extends RelicAdapter {
  final SharedPreferences _prefs;
  SharedPrefsRelicAdapter(this._prefs);

  @override
  Future<Object?> read(String key) async {
    final raw = _prefs.getString(key);
    return raw != null ? jsonDecode(raw) : null;
  }

  @override
  Future<void> write(String key, Object value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<void> delete(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }
}

/// Hive adapter
class HiveRelicAdapter extends RelicAdapter {
  final Box _box;
  HiveRelicAdapter(this._box);

  @override
  Future<Object?> read(String key) async => _box.get(key);

  @override
  Future<void> write(String key, Object value) async => _box.put(key, value);

  @override
  Future<void> delete(String key) async => _box.delete(key);

  @override
  Future<void> clear() async => _box.clear();
}
```

For testing, Titan includes `InMemoryRelicAdapter`:

```dart
final adapter = InMemoryRelicAdapter();
final relic = Relic(adapter: adapter, entries: {...});

// Pre-seed storage for tests
await adapter.write('theme', 'dark');
await relic.hydrate();
expect(pillar.theme.value, 'dark');
```

---

## Complex Data Types

Relic handles any type — as long as you provide `toJson` and `fromJson`:

```dart
class QuestboardPillar extends Pillar {
  late final quests = core(<Quest>[]);

  late final relic = Relic(
    adapter: storageAdapter,
    entries: {
      'quests': RelicEntry<List<Quest>>(
        core: quests,
        toJson: (value) => value.map((q) => q.toJson()).toList(),
        fromJson: (json) => (json as List)
            .map((j) => Quest.fromJson(j as Map<String, dynamic>))
            .toList(),
      ),
    },
  );
}
```

Maps, nested objects, custom classes — anything that can round-trip through JSON works with Relic.

---

## Manual Operations

Sometimes you need more control:

```dart
// Save everything right now
await relic.persist();

// Clear all persisted data
await relic.clear();
```

---

## The Complete Picture

Kael looked at the finished Questboard architecture. Every piece was in place:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // Global configuration
  Chronicle.level = LogLevel.info;
  Vigil.addHandler((report) {
    FirebaseCrashlytics.instance.recordError(report.error, report.stackTrace);
  });

  // Global Pillars
  Titan.put(AuthPillar());
  Titan.put(SettingsPillar(storage: SharedPrefsRelicAdapter(prefs)));

  runApp(const QuestboardApp());
}

class QuestboardApp extends StatelessWidget {
  const QuestboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: atlas.config,
    );
  }
}

final atlas = Atlas(
  passages: [
    Passage('/login', (wp) => const LoginScreen(),
      shift: Shift.fade(),
    ),
    Sanctum(
      shell: (child) => MainShell(child: child),
      passages: [
        Passage('/', (wp) => const QuestboardScreen(), name: 'home'),
        Passage('/heroes', (wp) => const LeaderboardScreen(), name: 'heroes'),
        Passage('/settings', (wp) => const SettingsScreen(), name: 'settings'),
      ],
    ),
    Passage('/quest/:id', (wp) => QuestDetailScreen(questId: wp.runes['id']!),
      shift: Shift.slideUp(),
      pillars: [
        () => QuestDetailPillar(questId: Atlas.current.runes['id']!),
      ],
    ),
  ],
  sentinels: [
    Sentinel.except(
      paths: {'/', '/login', '/heroes'},
      guard: (path, wp) {
        final auth = Titan.get<AuthPillar>();
        return auth.user.value == null ? '/login' : null;
      },
    ),
  ],
  observers: [HeraldAtlasObserver()],
  defaultShift: Shift.fade(),
);
```

---

## The Kingdom Stands

Kael leaned back and surveyed the Questboard:

- **Pillars** held the state — structured, testable, with automatic lifecycle management
- **Cores** provided fine-grained reactivity — no wasted rebuilds
- **Derived** values auto-computed from their dependencies
- **Strikes** batched mutations for optimal performance
- **Watches** handled side effects reactively
- **Beacons** shone Pillar state into the widget tree
- **Vestiges** consumed state with surgical precision
- **Herald** carried messages between domains — zero coupling
- **Vigil** watched for errors — centralized, contextual, relentless
- **Chronicle** recorded all operations — structured, leveled, pluggable
- **Epochs** gave the power of undo/redo — time travel for state
- **Flux** controlled the flow — debounce, throttle, streams
- **Atlas** mapped every route — declarative, guarded, animated
- **Sentinels** protected sensitive passages
- **Sanctums** held persistent layouts
- **Relics** preserved state across sessions

The code was clean. The tests were green. The architecture was scalable.

And it all started with a single Pillar.

---

> *The kingdom stood, strong and complete. From the first Pillar to the last Relic, every piece served its purpose. Kael looked at what had been built and knew: this wasn't just an app. It was an architecture that could hold up the sky.*
>
> *And high above, the Titans smiled.*

---

## The Full Lexicon

| Standard Term | Titan Name | Package | What It Does |
|---------------|------------|---------|--------------|
| Store / Bloc | **Pillar** | `titan` | State container with lifecycle |
| State | **Core** | `titan` | Reactive mutable value |
| Computed | **Derived** | `titan` | Auto-tracking computed value |
| Dispatch | **Strike** | `titan` | Batched state mutation |
| Side Effect | **Watch** | `titan` | Reactive effect |
| Event Bus | **Herald** | `titan` | Typed cross-domain messaging |
| Error Tracking | **Vigil** | `titan` | Centralized error capture |
| Logger | **Chronicle** | `titan` | Structured logging with sinks |
| Undo/Redo | **Epoch** | `titan` | Core with history stacks |
| Stream Ops | **Flux** | `titan` | debounce, throttle, asStream |
| Persistence | **Relic** | `titan` | State hydration & auto-save |
| DI Container | **Titan** | `titan` | Global registry |
| Consumer | **Vestige** | `titan_bastion` | Auto-tracking widget |
| Provider | **Beacon** | `titan_bastion` | Scoped Pillar provider |
| Router | **Atlas** | `titan_atlas` | Declarative Navigator 2.0 |
| Route | **Passage** | `titan_atlas` | Path → Widget mapping |
| Shell Route | **Sanctum** | `titan_atlas` | Persistent layout wrapper |
| Route Guard | **Sentinel** | `titan_atlas` | Navigation protection |
| Transition | **Shift** | `titan_atlas` | Page animation |
| Route State | **Waypoint** | `titan_atlas` | Resolved route information |
| Parameters | **Runes** | `titan_atlas` | Dynamic path segments |
| Redirect | **Drift** | `titan_atlas` | Global navigation redirect |

---

## Where to Go from Here

| Resource | Link |
|----------|------|
| Full Documentation | [docs/](https://github.com/Ikolvi/titan/tree/main/docs) |
| API Reference | [09-api-reference.md](https://github.com/Ikolvi/titan/blob/main/docs/09-api-reference.md) |
| Advanced Patterns | [08-advanced-patterns.md](https://github.com/Ikolvi/titan/blob/main/docs/08-advanced-patterns.md) |
| Example App | [packages/titan_example](https://github.com/Ikolvi/titan/tree/main/packages/titan_example) |
| titan on pub.dev | [pub.dev/packages/titan](https://pub.dev/packages/titan) |
| titan_bastion | [pub.dev/packages/titan_bastion](https://pub.dev/packages/titan_bastion) |
| titan_atlas | [pub.dev/packages/titan_atlas](https://pub.dev/packages/titan_atlas) |

---

*Thank you for reading The Chronicles of Titan. Now go build something legendary.*

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
| **VIII** | **The Relic Endures** ← You are here |
