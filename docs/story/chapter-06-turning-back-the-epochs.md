# Chapter VI: Turning Back the Epochs

*The Chronicles of Titan — A Developer's Odyssey*

---

> *"Not all Strikes land true. Sometimes a hero acts in haste — deletes the wrong quest, edits the wrong field, assigns the wrong hero. In the ancient days, there was no remedy. But then the Titans discovered the Epoch — the power to step backward through time itself, undoing what had been done, and redoing what had been undone."*

---

## The Accidental Delete

The bug report was simple and devastating: "I accidentally deleted my quest notes. Three hours of planning, gone."

Kael stared at the ticket. The notes field was a `core('')` — each keystroke overwrote the previous value. There was no history. No way back.

"I need undo," Kael said. Then, after a beat: "And redo."

---

## Epoch — A Core with Memory

An **Epoch** is a Core that remembers every value it's ever held. It's created with `epoch()` instead of `core()`, and it gives you `undo()`, `redo()`, and full history navigation.

```dart
class QuestNotesPillar extends Pillar {
  final String questId;
  QuestNotesPillar({required this.questId});

  // epoch() instead of core() — same API, but with history
  late final notes = epoch('');
  late final title = epoch('Untitled Quest');

  void updateNotes(String text) => strike(() {
    notes.value = text;
  });

  void updateTitle(String text) => strike(() {
    title.value = text;
  });

  void undo() {
    if (notes.canUndo) notes.undo();
  }

  void redo() {
    if (notes.canRedo) notes.redo();
  }
}
```

That's it. No history management. No state snapshots. No command pattern. Just swap `core()` for `epoch()` and you get undo/redo for free.

---

## How Epoch Works

Every time you set an Epoch's value, it pushes the *previous* value onto an undo stack. When you call `undo()`, it moves the current value to the redo stack and pops the previous value from undo:

```dart
final pillar = QuestNotesPillar(questId: '1');
pillar.initialize();

pillar.updateNotes('Draft 1');
pillar.updateNotes('Draft 2');
pillar.updateNotes('Draft 3');

print(pillar.notes.value);     // 'Draft 3'
print(pillar.notes.canUndo);   // true
print(pillar.notes.undoCount); // 3 (including initial '')

// Step back through time
pillar.notes.undo();
print(pillar.notes.value);     // 'Draft 2'

pillar.notes.undo();
print(pillar.notes.value);     // 'Draft 1'

pillar.notes.undo();
print(pillar.notes.value);     // '' (original value)
print(pillar.notes.canUndo);   // false — we're at the beginning

// Step forward
pillar.notes.redo();
print(pillar.notes.value);     // 'Draft 1'

pillar.notes.redo();
print(pillar.notes.value);     // 'Draft 2'
print(pillar.notes.canRedo);   // true — 'Draft 3' is still ahead

// New edit clears the redo stack (just like any text editor)
pillar.updateNotes('Draft 2 revised');
print(pillar.notes.canRedo);   // false — future history is gone
```

---

## The Editor UI

Kael built the quest notes editor with undo/redo buttons:

```dart
class QuestNotesScreen extends StatelessWidget {
  const QuestNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Vestige<QuestNotesPillar>(
          builder: (context, pillar) => Text(pillar.title.value),
        ),
        actions: [
          // Undo button — only enabled when there's history
          Vestige<QuestNotesPillar>(
            builder: (context, pillar) => IconButton(
              icon: const Icon(Icons.undo),
              onPressed: pillar.notes.canUndo ? () => pillar.undo() : null,
            ),
          ),

          // Redo button — only enabled when there's future
          Vestige<QuestNotesPillar>(
            builder: (context, pillar) => IconButton(
              icon: const Icon(Icons.redo),
              onPressed: pillar.notes.canRedo ? () => pillar.redo() : null,
            ),
          ),
        ],
      ),
      body: Vestige<QuestNotesPillar>(
        builder: (context, pillar) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: TextEditingController(text: pillar.notes.value),
            maxLines: null,
            onChanged: pillar.updateNotes,
            decoration: const InputDecoration(
              hintText: 'Write your quest notes...',
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }
}
```

The undo/redo buttons enable and disable automatically based on `canUndo` and `canRedo` — and because they're in separate Vestige widgets, the undo button only rebuilds when the undo stack changes, and the redo button only rebuilds when the redo stack changes. Surgical precision, even for toolbar state.

---

## History Depth

By default, Epoch keeps 100 history entries. For a text editor, you might want more. For a simple toggle, you might want less:

```dart
class EditorPillar extends Pillar {
  // Deep history for text editing
  late final content = epoch('', maxHistory: 500);

  // Shallow history — just remember a few recent values
  late final fontSize = epoch(14.0, maxHistory: 10);

  // Default: 100 entries
  late final theme = epoch('light');
}
```

When the undo stack exceeds `maxHistory`, the oldest entries are quietly dropped.

---

## Inspecting History

Need to see the full history? Perhaps for a "version history" feature:

```dart
// Get the full undo history
final history = notes.history; // List<String>

// Display version history
for (var i = 0; i < history.length; i++) {
  print('Version ${i + 1}: ${history[i]}');
}

// Clear history (keeps current value)
notes.clearHistory();
print(notes.canUndo); // false
```

---

## Flux — Controlling the Flow

While working on the notes editor, Kael noticed a problem. Every keystroke fired `updateNotes()`, which wrote to the Epoch, which pushed to the undo stack. Typing "Hello" created five history entries: "H", "He", "Hel", "Hell", "Hello".

Kael needed to **debounce** — wait for the user to stop typing, then record the value as a single history entry.

**Flux** is Titan's stream operator toolkit. It provides `debounce()`, `throttle()`, and `asStream()` as extensions on Core:

```dart
class SmartEditorPillar extends Pillar {
  // Raw input — changes on every keystroke
  late final rawInput = core('');

  // Debounced — settles 500ms after the last keystroke
  late final settled = rawInput.debounce(Duration(milliseconds: 500));

  // History tracked on the settled, debounced value
  late final content = epoch('');

  @override
  void onInit() {
    // When the settled value changes, record it as an Epoch entry
    watch(() {
      final text = settled.value;
      if (text != content.value) {
        content.value = text;
      }
    });
  }

  void type(String text) => strike(() => rawInput.value = text);
  void undo() => content.undo();
  void redo() => content.redo();
}
```

Now typing "Hello" rapidly produces only one Epoch entry after the user pauses for 500ms.

---

## Throttle — Rate Limiting

For real-time features like a leaderboard that updates on every quest completion across the team, throttle prevents the UI from being overwhelmed:

```dart
class LeaderboardPillar extends Pillar {
  late final rawScores = core(<String, int>{});

  // Update at most once per second, even if events arrive faster
  late final displayScores = rawScores.throttle(Duration(seconds: 1));

  @override
  void onInit() {
    listen<QuestCompleted>((event) {
      strike(() {
        final scores = Map<String, int>.from(rawScores.value);
        scores.update(event.questTitle, (v) => v + 1, ifAbsent: () => 1);
        rawScores.value = scores;
      });
    });
  }
}
```

---

## Stream Bridge

Need to bridge Titan signals into Dart streams? `asStream()` gives you a standard `Stream<T>`:

```dart
class AnalyticsPillar extends Pillar {
  late final events = core(<String>[]);

  @override
  void onInit() {
    // Convert any Core/Derived to a Stream
    final questStream = events.asStream();

    questStream.listen((eventList) {
      // Process with standard stream operators
      print('Events updated: ${eventList.length}');
    });
  }
}
```

---

## onChange — React to Any Value Change

For simple change callbacks without the full Watch machinery:

```dart
class SettingsPillar extends Pillar {
  late final theme = core('light');

  @override
  void onInit() {
    theme.onChange((value) {
      print('Theme changed to: $value');
    });
  }
}
```

---

## What Kael Learned

| Concept | Titan Name | What It Does |
|---------|------------|--------------|
| Undo/Redo state | **Epoch** | Core with history stack — `undo()`, `redo()`, `history` |
| Debounce | **Flux** | Wait for silence before propagating — `core.debounce()` |
| Throttle | **Flux** | Rate-limit updates — `core.throttle()` |
| To Stream | **Flux** | Bridge signals to Dart streams — `core.asStream()` |
| Change callback | **Flux** | Simple listener — `core.onChange()` |

The notes editor now had undo/redo. The search input was debounced. The leaderboard was throttled. Time itself bent to Kael's will.

---

> *With the power of Epochs and the control of Flux, the kingdom was stable and responsive. But Questboard needed to grow beyond a single screen. It needed routes — a way to navigate between the quest board, hero profiles, settings, and more. It was time to consult the greatest navigator of all: Atlas.*

---

**Next:** [Chapter VII — The Atlas Unfurls →](chapter-07-the-atlas-unfurls.md)

---

| Chapter | Title |
|---------|-------|
| [I](chapter-01-the-first-pillar.md) | The First Pillar |
| [II](chapter-02-forging-the-derived.md) | Forging the Derived |
| [III](chapter-03-the-beacon-shines.md) | The Beacon Shines |
| [IV](chapter-04-the-herald-rides.md) | The Herald Rides |
| [V](chapter-05-the-vigilant-watch.md) | The Vigilant Watch |
| **VI** | **Turning Back the Epochs** ← You are here |
| [VII](chapter-07-the-atlas-unfurls.md) | The Atlas Unfurls |
| [VIII](chapter-08-the-relic-endures.md) | The Relic Endures |
