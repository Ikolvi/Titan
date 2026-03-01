# Chapter I: The First Pillar

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"Before the world had form, there was nothing but chaos — scattered state, tangled callbacks, widgets that rebuilt when they shouldn't have. Then a Titan raised the first Pillar, and the sky held steady."*

---

## The Brief

It began, as all great endeavors do, with a problem.

Kael was a developer at a small studio called Ironclad Labs. Their latest project: **Questboard** — a team task-tracking app where developers were "heroes" and tasks were "quests." Each hero could claim quests, mark them complete, and earn glory.

Simple enough. But the last three attempts had collapsed into architectural rubble. The first used raw `setState` — it worked for a week, then became a labyrinth of callbacks nobody dared touch. The second used a popular framework with event classes, state classes, mappers, and so many files for a single feature that the team spent more time writing plumbing than logic. The third... Kael didn't like to talk about the third.

Then Kael discovered something ancient. Something powerful.

**Titan.**

---

## Raising the First Pillar

Every structure needs a foundation. In Titan, that foundation is a **Pillar** — a single, self-contained unit that holds reactive state, business logic, and lifecycle management.

Kael's first task was simple: track a hero's quest count.

```dart
import 'package:titan/titan.dart';

class HeroPillar extends Pillar {
  // A Core — the indestructible center. Reactive. Independent. Fine-grained.
  late final questsCompleted = core(0);
  late final heroName = core('Unknown Hero');
}
```

That's it. No event classes. No state classes. No builders, no reducers, no mappers.

Two lines of reactive state. Kael stared at the screen, waiting for the catch. There had to be more boilerplate hiding somewhere.

There wasn't.

---

## Understanding the Core

A **Core** is Titan's reactive primitive — a mutable value that knows when it changes and who's watching.

```dart
final pillar = HeroPillar();
pillar.initialize();

// Read the value
print(pillar.heroName.value);      // 'Unknown Hero'
print(pillar.questsCompleted.value); // 0

// Write and it reacts
pillar.heroName.value = 'Kael the Bold';
print(pillar.heroName.value);      // 'Kael the Bold'
```

Each Core is **independent**. Changing `heroName` does not notify anything watching `questsCompleted`. This is the surgical precision that Titan promises — no wasted rebuilds, no shotgun notifications.

Kael added more state to the Pillar:

```dart
class HeroPillar extends Pillar {
  late final heroName = core('Unknown Hero');
  late final title = core('Apprentice');
  late final questsCompleted = core(0);
  late final isOnQuest = core(false);
}
```

Four independent reactive values. Four Cores. Each one fine-grained, each one precise.

---

## The First Strike

State without mutation is just a constant. Kael needed to *change* things. In Titan, mutations are called **Strikes** — fast, decisive, powerful.

```dart
class HeroPillar extends Pillar {
  late final heroName = core('Unknown Hero');
  late final title = core('Apprentice');
  late final questsCompleted = core(0);
  late final isOnQuest = core(false);

  void beginQuest() => strike(() {
    isOnQuest.value = true;
  });

  void completeQuest() => strike(() {
    questsCompleted.value++;
    isOnQuest.value = false;

    // Promotion logic
    if (questsCompleted.value >= 10) {
      title.value = 'Veteran';
    } else if (questsCompleted.value >= 5) {
      title.value = 'Journeyman';
    }
  });
}
```

A Strike batches all mutations inside it into a **single notification cycle**. When `completeQuest()` fires, three Cores change — but dependents are notified only once, after all changes are applied. No intermediate states. No phantom rebuilds.

```dart
final hero = HeroPillar();
hero.initialize();

hero.beginQuest();
print(hero.isOnQuest.value);        // true

hero.completeQuest();
print(hero.questsCompleted.value);  // 1
print(hero.isOnQuest.value);        // false
print(hero.title.value);            // 'Apprentice'

// Fast-forward through 4 more quests...
for (var i = 0; i < 4; i++) {
  hero.beginQuest();
  hero.completeQuest();
}
print(hero.questsCompleted.value);  // 5
print(hero.title.value);            // 'Journeyman'
```

Kael smiled. Five minutes in, and the hero's entire state lifecycle worked — cleanly, predictably, with zero boilerplate.

---

## Lifecycle: Birth and Death of a Pillar

Every Pillar has a lifecycle. It's born (`initialize`), it lives, and when it's no longer needed, it dies (`dispose`). Titan manages this automatically in Flutter — but you can hook into it.

```dart
class HeroPillar extends Pillar {
  late final heroName = core('Unknown Hero');
  late final questsCompleted = core(0);

  @override
  void onInit() {
    // Called once when the Pillar is first initialized.
    // Load data, set up watchers, prepare for battle.
    print('$heroName reporting for duty.');
  }

  @override
  void onDispose() {
    // Called when the Pillar is disposed.
    // Close connections, cancel timers, say goodbye.
    print('${heroName.value} has left the battlefield.');
  }
}
```

Kael didn't need to worry about memory leaks. Every Core created inside a Pillar is **automatically tracked and disposed** when the Pillar itself is disposed. No manual cleanup. No subscription management. The Pillar handles its own.

---

## The Questboard Takes Shape

With the fundamentals in place, Kael built the first real Pillar for Questboard:

```dart
class Quest {
  final String id;
  final String title;
  final String description;
  final int glory;
  final bool isCompleted;

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.glory,
    this.isCompleted = false,
  });

  Quest copyWith({bool? isCompleted}) => Quest(
    id: id,
    title: title,
    description: description,
    glory: glory,
    isCompleted: isCompleted ?? this.isCompleted,
  );
}

class QuestboardPillar extends Pillar {
  late final quests = core(<Quest>[]);
  late final selectedQuestId = core<String?>(null);

  void addQuest(Quest quest) => strike(() {
    quests.value = [...quests.value, quest];
  });

  void completeQuest(String id) => strike(() {
    quests.value = quests.value.map((q) {
      return q.id == id ? q.copyWith(isCompleted: true) : q;
    }).toList();
  });

  void selectQuest(String? id) => strike(() {
    selectedQuestId.value = id;
  });
}
```

Clean. Readable. Testable as plain Dart — no Flutter required.

```dart
void main() {
  final board = QuestboardPillar();
  board.initialize();

  board.addQuest(Quest(
    id: '1',
    title: 'Slay the Null Dragon',
    description: 'Eliminate all null pointer exceptions in the auth module.',
    glory: 50,
  ));

  board.addQuest(Quest(
    id: '2',
    title: 'Refactor the Dark Tower',
    description: 'Break the legacy monolith into clean modules.',
    glory: 100,
  ));

  print(board.quests.value.length);         // 2
  print(board.quests.value.first.title);    // 'Slay the Null Dragon'

  board.completeQuest('1');
  print(board.quests.value.first.isCompleted); // true
}
```

Kael leaned back in the chair and nodded. The first Pillar stood. The sky held.

But a Pillar alone is just a column. What Kael needed were **derived truths** — computed values that reacted automatically.

---

> *The Pillar stood firm, but it was only the beginning. From the Core, new powers would need to be forged — values that derived their strength from others, changing only when their sources changed. Tomorrow, Kael would learn the art of the Derived.*

---

**Next:** [Chapter II — Forging the Derived →](chapter-02-forging-the-derived.md)

---

| Chapter | Title |
|---------|-------|
| **I** | **The First Pillar** ← You are here |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| [VI](chapter-06-turning-back-the-epochs.md) | Turning Back the Epochs |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
