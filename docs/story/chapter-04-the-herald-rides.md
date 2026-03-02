# Chapter IV: The Herald Rides

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"In the age before the Herald, each Pillar stood alone — mighty, but deaf to the others. When the kingdom grew and Pillars multiplied across distant domains, a messenger was needed. One who could carry word between realms without binding them together. The Herald rode forth — coupling no one, connecting everyone."*

---

## The Coordination Problem

Questboard was growing. Kael now had three Pillars:

- `QuestboardPillar` — managed the quest list
- `HeroPillar` — tracked the hero's stats and rank
- `NotificationPillar` — showed in-app notifications

The problem: when a quest was completed in `QuestboardPillar`, the `HeroPillar` needed to increment its quest count, and the `NotificationPillar` needed to show a congratulations toast.

Kael's first instinct was to inject one Pillar into another:

```dart
// ❌ Don't do this — tight coupling, circular dependency risk
class QuestboardPillar extends Pillar {
  final HeroPillar hero;
  final NotificationPillar notifications;

  QuestboardPillar(this.hero, this.notifications);

  void completeQuest(String id) => strike(() {
    // ... update quests ...
    hero.complete();              // Direct coupling!
    notifications.show('Quest completed!');  // More coupling!
  });
}
```

This would work, but it created a web of dependencies. Every new cross-cutting concern would require more constructor parameters, more wiring, more fragility. The Pillars would be chained together like prisoners.

There had to be a way to communicate without coupling.

---

## Enter the Herald

The **Herald** is Titan's cross-domain event bus. It carries typed messages between any part of the application — Pillars, services, widgets — without any of them knowing about each other.

First, Kael defined the events — simple Dart classes:

```dart
/// Emitted when a quest is completed
class QuestCompleted {
  final String questId;
  final String questTitle;
  final int glory;

  const QuestCompleted({
    required this.questId,
    required this.questTitle,
    required this.glory,
  });
}

/// Emitted when a hero levels up
class HeroPromoted {
  final String heroName;
  final String newRank;

  const HeroPromoted({
    required this.heroName,
    required this.newRank,
  });
}
```

No base class. No interface. No registration. Just plain Dart classes. The Herald routes by type.

---

## Emitting Events

The QuestboardPillar completes a quest and **emits** a Herald event. It doesn't know who's listening. It doesn't care.

```dart
class QuestboardPillar extends Pillar {
  late final quests = core(<Quest>[]);

  void completeQuest(String id) => strike(() {
    final quest = quests.value.firstWhere((q) => q.id == id);

    quests.value = quests.value.map((q) {
      return q.id == id ? q.copyWith(isCompleted: true) : q;
    }).toList();

    // Herald carries the message — no coupling to listeners
    emit(QuestCompleted(
      questId: quest.id,
      questTitle: quest.title,
      glory: quest.glory,
    ));
  });
}
```

`emit()` is built into every Pillar. One line. The event is broadcast to anyone listening for `QuestCompleted` events, anywhere in the app.

---

## Listening for Events

The HeroPillar doesn't know about QuestboardPillar. It just listens for events of a specific type:

```dart
class HeroPillar extends Pillar {
  late final heroName = core('Unknown Hero');
  late final questsCompleted = core(0);
  late final rank = derived(() {
    final completed = questsCompleted.value;
    if (completed >= 50) return 'Titan';
    if (completed >= 25) return 'Champion';
    if (completed >= 10) return 'Veteran';
    if (completed >= 5) return 'Journeyman';
    return 'Apprentice';
  });

  String? _previousRank;

  @override
  void onInit() {
    _previousRank = rank.value;

    // Listen for quest completions — auto-cancelled on dispose
    listen<QuestCompleted>((event) {
      strike(() => questsCompleted.value++);

      // Check if rank changed
      if (rank.value != _previousRank) {
        emit(HeroPromoted(
          heroName: heroName.value,
          newRank: rank.value,
        ));
        _previousRank = rank.value;
      }
    });
  }
}
```

Notice the elegance: `HeroPillar` listens for `QuestCompleted`, updates its own state, and if the rank changes, it emits `HeroPromoted`. **Events cascade naturally through the system without any Pillar knowing about any other.**

---

## The Notification Chain

The NotificationPillar listens for both event types:

```dart
class NotificationPillar extends Pillar {
  late final notifications = core(<String>[]);

  @override
  void onInit() {
    listen<QuestCompleted>((event) {
      strike(() {
        notifications.value = [
          ...notifications.value,
          '⚔️ Quest completed: ${event.questTitle} (+${event.glory} glory)',
        ];
      });
    });

    listen<HeroPromoted>((event) {
      strike(() {
        notifications.value = [
          ...notifications.value,
          '🏆 ${event.heroName} promoted to ${event.newRank}!',
        ];
      });
    });
  }

  void dismiss(int index) => strike(() {
    notifications.value = [...notifications.value]..removeAt(index);
  });
}
```

---

## The Beautiful Cascade

Here's what happens when a quest is completed:

```
User taps "Complete" on a quest
      │
      ▼
QuestboardPillar.completeQuest()
      │ updates quest list
      │ emits QuestCompleted
      │
      ├─────────────────────────────────────┐
      ▼                                     ▼
HeroPillar                          NotificationPillar
  │ increments questsCompleted        │ adds quest notification
  │ checks rank                       │
  │ emits HeroPromoted (if changed)   │
  │                                   │
  ├───────────────────────────────────►│
  │                                   │ adds promotion notification
  │                                   │
  ▼                                   ▼
UI rebuilds:                        UI rebuilds:
  hero rank badge                     notification list
  (ONLY if rank changed)             (adds 1 or 2 items)
```

Three Pillars. Zero direct references between them. Complete decoupling. The Herald rides between domains, carrying messages effortlessly.

---

## Listen Once

Sometimes you only need to handle an event a single time:

```dart
class OnboardingPillar extends Pillar {
  late final hasSeenWelcome = core(false);

  @override
  void onInit() {
    // Fire once, then auto-cancel
    listenOnce<QuestCompleted>((_) {
      strike(() => hasSeenWelcome.value = true);
      // Show first-quest celebration
    });
  }
}
```

`listenOnce` handles exactly one event, then the subscription is automatically cancelled. And if the Pillar is disposed before the event arrives? The subscription is cancelled too. No leaks.

---

## Direct Herald Usage

You don't have to be inside a Pillar to use the Herald. It works anywhere:

```dart
// Emit from anywhere
Herald.emit(SystemEvent('app_launched'));

// Listen from anywhere (but remember to cancel!)
final subscription = Herald.on<SystemEvent>((event) {
  print('System: ${event.message}');
});

// Later...
subscription.cancel();
```

But inside Pillars, always use `emit()` and `listen()` — they're managed automatically.

---

## Wiring It All Up

```dart
void main() {
  runApp(
    Beacon(
      pillars: [
        QuestboardPillar.new,
        HeroPillar.new,
        NotificationPillar.new,
      ],
      child: const QuestboardApp(),
    ),
  );
}
```

Three Pillars. No wiring between them. No dependency injection graph connecting them. They communicate through the Herald — and the Herald doesn't care who's talking or who's listening.

---

## Testing Herald Events

Since events are just Dart objects, testing is straightforward:

```dart
void main() {
  group('HeroPillar responds to Herald events', () {
    late HeroPillar hero;

    setUp(() {
      hero = HeroPillar();
      hero.initialize();
    });

    tearDown(() {
      hero.dispose();
      Herald.reset();
    });

    test('increments questsCompleted on QuestCompleted', () {
      Herald.emit(QuestCompleted(
        questId: '1',
        questTitle: 'Test Quest',
        glory: 50,
      ));

      expect(hero.questsCompleted.value, 1);
    });

    test('emits HeroPromoted when rank changes', () {
      final promotions = <HeroPromoted>[];
      Herald.on<HeroPromoted>((e) => promotions.add(e));

      // Complete 5 quests to trigger Journeyman
      for (var i = 0; i < 5; i++) {
        Herald.emit(QuestCompleted(
          questId: '$i',
          questTitle: 'Quest $i',
          glory: 10,
        ));
      }

      expect(promotions, hasLength(1));
      expect(promotions.first.newRank, 'Journeyman');
    });
  });
}
```

Pure Dart tests. No mocks needed. Events flow naturally.

---

> *The Herald rode tirelessly between the Pillars, and the kingdom hummed with coordination. But as the application grew and more Strikes were dispatched, failures began to creep in — network errors, parsing exceptions, edge cases. Someone needed to watch for these dangers. Someone needed to stand vigil.*

---

**Next:** [Chapter V — The Vigilant Watch →](chapter-05-the-vigilant-watch.md)

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| **IV** | **The Herald Rides** ← You are here |
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
