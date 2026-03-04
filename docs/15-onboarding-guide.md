# Onboarding Guide — The Titan Lexicon

*From zero to productive in one page.*

---

> **"Titan has too many names to learn."**
>
> This is a common first impression — and it's understandable. Titan uses mythology-inspired names instead of generic terms. But the core learning surface is **smaller than BLoC's**, and 73% of the names are advanced features you'll pick up gradually (or never need).
>
> This guide gets you productive fast.

---

## The Rosetta Stone

If you know BLoC, Provider, Riverpod, or GetX — you already know Titan. Different names, same ideas.

### Core (Learn Day 1)

| What It Does | BLoC | Provider | Riverpod | GetX | **Titan** |
|---|---|---|---|---|---|
| Holds state & logic | `Bloc` / `Cubit` | `ChangeNotifier` | `Notifier` | `GetxController` | **Pillar** |
| A reactive value | State class | Field + `notifyListeners()` | `state` | `.obs` | **Core** |
| Computed value | — (manual) | — (manual) | `Provider` | `Obx(() => ...)` | **Derived** |
| Dispatch action | `add(event)` / `emit()` | Method call | Method call | Method call | **strike()** |
| React to changes | `BlocListener` | `Consumer` listen | `ref.listen` | `ever()` | **watch()** |
| Provide to widget tree | `BlocProvider` | `ChangeNotifierProvider` | `ProviderScope` | `Get.put()` | **Beacon** |
| Consume in widget | `BlocBuilder` | `Consumer` | `ConsumerWidget` | `Obx` | **Vestige** |
| Global DI | `context.read<T>()` | `context.read<T>()` | `ref.read` | `Get.find()` | **Titan.get()** |

**That's it. 8 concepts. You can build a full app with just these.**

### Essential (Learn Week 1)

| What It Does | Other Frameworks | **Titan** |
|---|---|---|
| Async loading state | `AsyncValue` (Riverpod) | **Ether** (`AsyncValue`) |
| Multi-consumer widget | `MultiBlocListener` | **Confluence** |
| Hooks-style widget | `flutter_hooks` | **Spark** |
| Read-only state view | — (no equivalent) | **ReadCore** |

### Routing (When You Need It)

| What It Does | go_router | **Titan (Atlas)** |
|---|---|---|
| Router | `GoRouter` | **Atlas** |
| Route definition | `GoRoute` | **Passage** |
| Shell/nested layout | `ShellRoute` | **Sanctum** |
| Route guard | `redirect` | **Sentinel** |
| Redirect target | `redirect` return | **Drift** |
| Route state | `GoRouterState` | **Waypoint** |
| Path parameters | `pathParameters` | **Runes** |

### Everything Else (Learn When You Need It)

You don't need to memorize these. They exist when the problem demands them.

| Category | Titan Names | When You'll Need Them |
|---|---|---|
| Events & Logging | Herald, Vigil, Chronicle | Cross-Pillar communication, error tracking |
| Time Travel | Epoch, Flux | Undo/redo, debounce/throttle |
| Persistence | Relic | Save/restore state |
| Forms | Scroll, ScrollGroup | Form validation |
| Data Fetching | Quarry, Codex | API calls, pagination |
| Middleware | Conduit, Prism | Core-level transforms, selectors |
| Collections | Nexus | Reactive List/Map/Set |
| FSM | Loom | Finite state machines |
| Auth | Argus, Garrison | Authentication flows |
| Testing | Crucible, Bulwark, Snapshot | Test harness, integration tests |
| Performance | Colossus, Pulse, Stride, Vessel, Echo | Performance monitoring |
| Enterprise Infra | Trove, Moat, Portcullis, Anvil, Pyre, Banner, Sieve, Lattice, Embargo, Census, Warden, Arbiter, Lode, Tithe, Sluice, Clarion, Tapestry | Caching, rate limiting, circuit breaking, feature flags, job scheduling, event sourcing... |

---

## The Learning Path

### Day 1 — Build Your First Feature

```dart
import 'package:titan/titan.dart';

class CounterPillar extends Pillar {
  late final _count = core(0);               // Core — reactive value
  ReadCore<int> get count => _count;          // ReadCore — read-only view

  late final doubled = derived(() => _count.value * 2);  // Derived — computed

  void increment() => strike(() => _count.value++);      // Strike — mutation
}
```

```dart
// In Flutter:
Beacon(                              // Beacon — provides Pillar
  create: (_) => CounterPillar(),
  child: Vestige<CounterPillar>(     // Vestige — rebuilds on change
    builder: (context, pillar) {
      return Text('${pillar.count.value}');
    },
  ),
);
```

**Concepts used: 5** — Pillar, Core, ReadCore, Derived, Strike, Beacon, Vestige.

### Week 1 — Handle Async & Side Effects

```dart
class QuestPillar extends Pillar {
  late final _quests = core(Ether.initial(<Quest>[]));    // Ether — async state
  ReadCore<AsyncValue<List<Quest>>> get quests => _quests;

  @override
  void onInit() {
    watch(() {                                             // watch — side effect
      // Runs when dependencies change
    });
    loadQuests();
  }

  Future<void> loadQuests() => strikeAsync(() async {      // strikeAsync
    _quests.value = Ether.loading();
    try {
      final data = await api.fetchQuests();
      _quests.value = Ether.data(data);
    } catch (e) {
      _quests.value = Ether.error(e);
    }
  });
}
```

### Month 1+ — Pick Up What You Need

Browse the [story tutorial](story/README.md). Each chapter introduces one concept when the Questboard app demands it. You'll never learn something before you need it.

---

## Why Custom Names?

Three reasons:

1. **Precision** — "Core" means exactly one thing: a fine-grained reactive value. "State" means a hundred things in Flutter. Unambiguous names prevent confusion in large codebases.

2. **Searchability** — Searching for "Pillar" across a codebase returns only Titan code. Searching for "Provider" returns Flutter's Provider, Riverpod's Provider, BlocProvider, ChangeNotifierProvider, and ServiceProvider.

3. **Identity** — Every named concept has a single class, a single responsibility, and a single chapter in the docs. If you know the name, you know where to look.

---

## The Numbers

| Metric | Titan | BLoC + Ecosystem |
|---|---|---|
| Core concepts (typical app) | **12** | **24** |
| Total named concepts | 95 | ~55 (across 6+ packages) |
| Packages for full app | 2–3 | 6–10 |
| Code generation required | No | Practically yes |
| Boilerplate per feature | 1 file | 3–4 files |
| Built-in routing | Yes | No (add go_router) |
| Built-in persistence | Yes | No (add hydrated_bloc) |
| Built-in auth guards | Yes | No (roll your own) |

**Titan has more names because it does more things.** For equivalent functionality, BLoC spreads concepts across separate packages with inconsistent naming. Titan bundles them under one roof with one lexicon.

---

## Quick Reference Card

Print this. Pin it. Forget it when it becomes second nature.

```
┌─────────────────────────────────────────────────┐
│              TITAN QUICK REFERENCE              │
├────────────┬────────────────────────────────────┤
│ Pillar     │ Your store. Holds state & logic.   │
│ Core       │ A reactive value. core(0)          │
│ ReadCore   │ Read-only Core. Hides the setter.  │
│ Derived    │ Computed from Cores. Auto-tracks.   │
│ Strike     │ Mutate state. strike(() => ...)     │
│ Watcher    │ Side effect. watch(() => ...)       │
│ Beacon     │ Provides Pillar to widget tree.     │
│ Vestige    │ Rebuilds when Pillar state changes. │
│ Titan.get  │ Global DI. Titan.get<MyPillar>()   │
│ Ether      │ Async state: loading/data/error.    │
│ Confluence │ Multi-Pillar consumer widget.       │
│ Spark      │ Hooks-style widget (useCore, etc.)  │
├────────────┴────────────────────────────────────┤
│ That's it. Everything else is optional.         │
└─────────────────────────────────────────────────┘
```

---

*Part of the [Titan](https://github.com/Ikolvi/titan) documentation — [Ikolvi](https://ikolvi.com)*
