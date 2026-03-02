# Chapter III: The Beacon Shines

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"All the power in the world means nothing if it cannot be seen. The Titan raised a Beacon — a pillar of light that shone downward through the realm, carrying illumination to every corner that needed it. Where its light touched, the invisible became visible."*

---

## The Gap Between Logic and Light

Kael had built two Pillars — `HeroPillar` and `QuestboardPillar` — and tested them in pure Dart. They were clean, reactive, and fast. But they existed in the dark. No UI. No pixels. No app.

The business logic was complete. Now it needed to *shine*.

For this, Titan offered two weapons:

- **Beacon** — The provider. It creates Pillars and shines their state down to the widget subtree.
- **Vestige** — The consumer. A visible trace of the Pillar's power — a widget that rebuilds only when the specific Cores it reads actually change.

---

## Lighting the First Beacon

A Beacon wraps a section of the widget tree and makes Pillars available to every descendant. You hand it factory functions, and it handles creation, initialization, and disposal automatically.

```dart
import 'package:flutter/material.dart';
import 'package:titan_bastion/titan_bastion.dart';

void main() {
  runApp(
    Beacon(
      pillars: [
        QuestboardPillar.new,
        HeroPillar.new,
      ],
      child: const QuestboardApp(),
    ),
  );
}

class QuestboardApp extends StatelessWidget {
  const QuestboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Questboard',
      home: const QuestboardScreen(),
    );
  }
}
```

That's the entire setup. One `Beacon`, two Pillars, done. No `MultiBlocProvider` chains. No `ProviderScope` wrappers. No `GetMaterialApp`. One widget. All state.

When the `Beacon` mounts, it:
1. Calls each factory function to create the Pillar instances
2. Calls `initialize()` on each (which triggers `onInit()`)
3. Makes them available to descendants via `Vestige`

When the `Beacon` unmounts, it calls `dispose()` on every Pillar it owns. All Cores, Derived values, Watchers, and subscriptions are cleaned up automatically.

---

## The Vestige — Surgical Rebuilds

Here's where Titan's magic truly reveals itself.

A `Vestige<P>` widget finds the Pillar of type `P` and provides it to a builder function. But the real power is what happens under the hood: Vestige **auto-tracks** which Cores and Derived values you read during the build, and only rebuilds when *those specific values* change.

```dart
class QuestboardScreen extends StatelessWidget {
  const QuestboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questboard'),
        // This Vestige ONLY rebuilds when heroName or rank changes
        actions: [
          Vestige<HeroPillar>(
            builder: (context, hero) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  '${hero.heroName.value} — ${hero.rank.value}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats bar — only rebuilds when glory or counts change
          const _StatsBar(),

          // Quest list — only rebuilds when the quest list changes
          const Expanded(child: _QuestList()),
        ],
      ),
    );
  }
}
```

---

## Fine-Grained in Action

Watch this. Each Vestige tracks independently:

```dart
class _StatsBar extends StatelessWidget {
  const _StatsBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Only rebuilds when activeCount changes
          Vestige<QuestboardPillar>(
            builder: (context, board) => _StatCard(
              label: 'Active',
              value: '${board.activeCount.value}',
              color: Colors.blue,
            ),
          ),

          // Only rebuilds when completedCount changes
          Vestige<QuestboardPillar>(
            builder: (context, board) => _StatCard(
              label: 'Completed',
              value: '${board.completedCount.value}',
              color: Colors.green,
            ),
          ),

          // Only rebuilds when totalGlory changes
          Vestige<QuestboardPillar>(
            builder: (context, board) => _StatCard(
              label: 'Glory',
              value: '${board.totalGlory.value}',
              color: Colors.amber,
            ),
          ),
        ],
      ),
    );
  }
}
```

Three `Vestige` widgets watching the same `QuestboardPillar`, but rebuilding independently:

- Complete a quest? `activeCount` decreases (rebuilds stat card 1), `completedCount` increases (rebuilds stat card 2), `totalGlory` increases (rebuilds stat card 3).
- Add a quest? Only `activeCount` changes — stat cards 2 and 3 don't rebuild at all.

This is the precision of signal-based reactivity. **You never write a selector. You never tell Titan what to watch. You just read values, and it figures out the rest.**

---

## The Quest List

```dart
class _QuestList extends StatelessWidget {
  const _QuestList();

  @override
  Widget build(BuildContext context) {
    return Vestige<QuestboardPillar>(
      builder: (context, board) {
        final quests = board.quests.value;

        if (quests.isEmpty) {
          return const Center(
            child: Text('No quests yet. The board awaits...'),
          );
        }

        return ListView.builder(
          itemCount: quests.length,
          itemBuilder: (context, index) {
            final quest = quests[index];
            return _QuestCard(quest: quest);
          },
        );
      },
    );
  }
}

class _QuestCard extends StatelessWidget {
  final Quest quest;
  const _QuestCard({required this.quest});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          quest.isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: quest.isCompleted ? Colors.green : Colors.grey,
        ),
        title: Text(
          quest.title,
          style: TextStyle(
            decoration: quest.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text('Glory: ${quest.glory}'),
        trailing: quest.isCompleted
          ? null
          : IconButton(
              icon: const Icon(Icons.done, color: Colors.green),
              onPressed: () {
                // Access the Pillar through the Vestige's context
                // We can call methods directly!
                final board = Beacon.of<QuestboardPillar>(context);
                board.completeQuest(quest.id);
              },
            ),
      ),
    );
  }
}
```

Wait — `Beacon.of<QuestboardPillar>(context)`? Yes. When you need the Pillar outside a Vestige builder, you can look it up directly. But for reactive rebuilds, always use `Vestige`.

---

## Scoped Beacons — State That Lives and Dies with the Screen

Kael needed a quest detail screen. The state for it should only exist while the screen is visible:

```dart
class QuestDetailPillar extends Pillar {
  final String questId;

  QuestDetailPillar({required this.questId});

  late final notes = core('');
  late final isEditing = core(false);

  void toggleEdit() => strike(() => isEditing.value = !isEditing.value);
  void updateNotes(String text) => strike(() => notes.value = text);
}

// Navigate with a scoped Beacon
Navigator.push(context, MaterialPageRoute(
  builder: (_) => Beacon(
    pillars: [() => QuestDetailPillar(questId: quest.id)],
    child: const QuestDetailScreen(),
  ),
));
```

When the user navigates away, the `Beacon` unmounts → `QuestDetailPillar` is disposed → all Cores cleaned up. Zero leaks.

---

## Nested Beacons

Beacons can nest. Inner Vestiges can access both inner and outer Pillars:

```dart
// App-level Beacon — lives for the lifetime of the app
Beacon(
  pillars: [AuthPillar.new, HeroPillar.new],
  child: MaterialApp(
    home: Beacon(
      // Screen-level Beacon — lives while this screen is mounted
      pillars: [QuestboardPillar.new],
      child: Scaffold(
        body: Column(
          children: [
            // Reads from outer Beacon's HeroPillar ✅
            Vestige<HeroPillar>(
              builder: (context, hero) => Text(hero.heroName.value),
            ),
            // Reads from inner Beacon's QuestboardPillar ✅
            Vestige<QuestboardPillar>(
              builder: (context, board) => Text('${board.activeCount.value} active'),
            ),
          ],
        ),
      ),
    ),
  ),
)
```

The resolution order is always: nearest Beacon first, then walk up the tree, then fall back to the global Titan registry.

---

## Global Registration — The Titan Registry

Sometimes you want a Pillar to live globally — not tied to any widget tree. For this, there's the **Titan** class:

```dart
void main() {
  // Register globally — lives until you remove it
  Titan.put(AuthPillar());
  Titan.put(HeroPillar());

  runApp(const QuestboardApp());
}
```

Now any `Vestige<AuthPillar>` anywhere in the tree finds it from the global registry — no Beacon needed. But Kael preferred Beacons for most things. Global state was for truly app-wide concerns: authentication, feature flags, configuration.

---

## The Screen Comes Alive

Kael ran the app. The Questboard screen painted smoothly. Stats updated independently. Quests completed with a tap. The hero's rank climbed.

And the best part? When Kael profiled the rebuild count, each Vestige only rebuilt when its exact dependencies changed. The glory stat card never rebuilt when a quest was added. The hero name never rebuilt when glory changed.

Surgical precision. Zero wasted frames.

---

> *The Beacon shone, and the Pillar's power became visible. But Questboard was growing. Multiple Pillars needed to coordinate — when a quest was completed in one domain, the hero's stats in another domain needed to know. Kael needed a messenger. A Herald.*

---

**Next:** [Chapter IV — The Herald Rides →](chapter-04-the-herald-rides.md)

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| **III** | **The Beacon Shines** ← You are here |
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
| [XIV](chapter-14-the-enterprise-arsenal.md) | The Enterprise Arsenal |
| [XV](chapter-15-the-loom-weaves.md) | The Loom Weaves |
| [XVI](chapter-16-the-forge-and-crucible.md) | The Forge & Crucible |
| [XVII](chapter-17-the-annals-record.md) | The Annals Record |
