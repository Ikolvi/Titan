# Chapter LIV — The Scout Surveys

*In which the Colossus learns to see without being told — building a living map of the realm from the footprints of those who walk through it.*

> **Package:** This feature is in `titan_colossus` — add `import 'package:titan_colossus/titan_colossus.dart';` to use it.

---

The Shade had been watching for weeks.

Every tap, every swipe, every hesitation — the silent observer captured it all, storing each session in its Vault like pressed flowers in a book. Kael could replay any session with Phantom, watching the ghost of a user retrace their steps through the Questboard. It was powerful. It was also blind.

"We have ten thousand recordings," Fen said, scrolling through the ShadeVault's session list. "But what do they *mean*?"

Kael knew the problem. Each Shade session was a flat sequence of pointer events — a trail of coordinates and timestamps. You could replay them, but you couldn't *reason* about them. You couldn't ask: *Which screens do users visit most? Where do they get stuck? What path leads to the crash on the rewards page?*

The data was there. The understanding was not.

"We need a Scout," Kael said. "Someone who reads the footprints and draws the map."

---

## The First Survey

A Scout doesn't explore — a Scout *observes*. It watches others move through the terrain and builds knowledge from their paths.

```dart
class QuestboardPillar extends Pillar {
  void analyzeLastSession() {
    final shade = Colossus.instance.shade;
    final session = shade.lastSession;
    if (session == null) return;

    // The Scout reads the session and learns
    Scout.instance.analyzeSession(session);

    // Every session enriches the same terrain
    final terrain = Scout.instance.terrain;
    print('Known screens: ${terrain.outposts.length}');
    print('Known transitions: ${terrain.marches.length}');
  }
}
```

"The Scout doesn't replace Shade," Kael explained. "Shade *records*. Scout *understands*. Shade gives us the raw footage; Scout gives us the map."

The team crowded around as Kael fed the first ten sessions into Scout. Each session was a different user's journey through the Questboard — some browsed quests, some posted new ones, some checked hero profiles.

After ten sessions, the Terrain had discovered twelve screens and twenty-three transitions between them. A map that no one had drawn — assembled entirely from observation.

---

## The Terrain Unfolds

The Terrain was not a list. It was a **directed graph** — a web of Outposts connected by Marches.

```dart
final terrain = Scout.instance.terrain;

// Each Outpost is a screen the Scout has observed
for (final outpost in terrain.outposts) {
  print('${outpost.route}:');
  print('  Visited ${outpost.visitCount} times');
  print('  Dead end: ${outpost.deadEnd}');
  print('  Reliability: ${(outpost.reliability * 100).toStringAsFixed(1)}%');
}

// Each March is a transition between two screens
for (final march in terrain.marches) {
  print('${march.from} → ${march.to} (${march.count} times)');
}
```

"An Outpost," Kael said, pointing to a node on the diagram, "is any screen the Scout has seen a user visit. `/quests`, `/quest/details`, `/hero/profile` — each one becomes an Outpost."

"A March," he continued, tracing an arrow between two nodes, "is a transition. When a user navigates from `/quests` to `/quest/details`, the Scout records a March between those two Outposts. Each subsequent navigation along the same path increments the March's count."

Fen studied the graph. "What about that one?" She pointed to the `/rewards/claim` Outpost, which had three incoming Marches but no outgoing ones.

"A dead end," Kael said quietly. "Users arrive at that screen, but they never navigate *away* from it. They either close the app or hit the back button."

"Or they crash," Rhea added.

The room went silent. Dead ends were not inherently bad — a success confirmation page was naturally a dead end. But the `/rewards/claim` screen was supposed to return users to their quest list after claiming. The fact that no one ever made that transition meant something was broken.

And the Scout had found it without being told to look.

---

## Lineage — The Name Behind the Face

There was one problem the Scout encountered immediately. When users visited `/quest/42`, `/quest/187`, and `/quest/3`, those weren't three different screens — they were the same screen with different data. But the Scout couldn't know that without help.

That was where Lineage came in.

```dart
final parameterizer = RouteParameterizer();

// Register the patterns the app actually uses
parameterizer.registerPattern('/quest/:id');
parameterizer.registerPattern('/hero/:heroId');
parameterizer.registerPattern('/hero/:heroId/quest/:questId');

// Now the Scout can resolve concrete paths
parameterizer.resolve('/quest/42');         // → '/quest/:id'
parameterizer.resolve('/quest/187');        // → '/quest/:id'
parameterizer.resolve('/hero/7/quest/99');  // → '/hero/:heroId/quest/:questId'
```

"Without Lineage, the Terrain would think `/quest/42` and `/quest/187` are different screens," Kael explained. "With Lineage, it knows they're both instances of `/quest/:id`. One Outpost instead of hundreds."

The resolution was precise. Lineage matched concrete paths against registered patterns, extracting parameter segments and collapsing them back to their canonical form. Unmatched paths — like `/settings` or `/about` — passed through unchanged. No false matches. No hallucinations.

"But where do the patterns come from?" Fen asked.

Kael smiled. "The Atlas already knows them."

---

## The Atlas Connection

Every route pattern in the Questboard was already registered in the Atlas — the router that managed all navigation. The patterns lived inside Atlas's Trie, a tree structure optimized for fast route matching. All the Scout needed to do was read them.

```dart
// Atlas already knows every route pattern in the app
final patterns = Atlas.registeredPatterns;
// ['/quests', '/quest/:id', '/hero/:heroId', '/settings', ...]

// Pre-seed the RouteParameterizer
final parameterizer = RouteParameterizer();
for (final pattern in patterns) {
  parameterizer.registerPattern(pattern);
}
```

"The patterns are already there," Kael said. "We just connect the Scout to the Atlas, and Lineage resolves itself."

No manual registration. No configuration files. No forgetting to add a new route when the app grows. The Atlas was the single source of truth, and the Scout read from it automatically.

---

## The Living Map

The real power of the Terrain was that it was **incremental**. Each new session enriched the existing graph rather than replacing it. Visit counts accumulated. New transitions appeared. Reliability scores adjusted as more data flowed in.

```dart
// Session 1: user visits /quests → /quest/42 → /quest/42/rewards
Scout.instance.analyzeSession(session1);
print(terrain.outposts.length);  // 3

// Session 2: user visits /quests → /hero/7 → /quests
Scout.instance.analyzeSession(session2);
print(terrain.outposts.length);  // 4 (added /hero/:heroId)
print(terrain.marches.length);   // 4 (added 2 new transitions)

// Session 3: user visits /quests → /quest/99 → /quest/99/rewards
Scout.instance.analyzeSession(session3);
// No new outposts (same patterns), but visit counts increase
// /quest/:id now has visitCount: 2, /quest/:id/rewards has visitCount: 2
```

"Every user who touches the Questboard teaches the Scout something," Kael said. "After a hundred sessions, the Terrain is a detailed map of how the app is actually used — not how we *designed* it to be used, but how it's *actually* used."

Rhea looked up from the Mermaid diagram the Terrain had generated:

```dart
final mermaid = terrain.toMermaid();
// graph LR
//   quests["/quests (visits: 47)"]
//   quest_id["/quest/:id (visits: 23)"]
//   hero_id["/hero/:heroId (visits: 12)"]
//   rewards["/quest/:id/rewards (visits: 8, DEAD END)"]
//   quests -->|"35x"| quest_id
//   quests -->|"12x"| hero_id
//   quest_id -->|"8x"| rewards
//   hero_id -->|"9x"| quests
```

"I can see the bottleneck," she said. "Thirty-five transitions from `/quests` to `/quest/:id`, but only eight continue to `/quest/:id/rewards`. Twenty-seven users opened a quest and didn't finish it."

"And the rewards page is a dead end," Fen added. "Every user who *does* complete a quest gets stuck there."

The map told a story no individual recording could. It was the difference between following one person through a city and seeing the city from above — the patterns emerged only when you looked at the aggregate.

---

## The AI Map

For teams working with AI coding assistants, the Terrain could export itself as a structured map — a format designed for AI consumption:

```dart
final aiMap = terrain.toAiMap();
```

The AI map included screen identifiers, visit counts, transition frequencies, dead-end flags, reliability scores, and relationship data — everything an AI assistant needed to understand the app's navigation structure and generate meaningful test coverage.

"Hand this to your AI pair programmer," Kael said. "It'll know where the weak spots are."

---

## The Scout's Silence

The most remarkable thing about the Scout was what it *didn't* require: attention.

With the ColossusPlugin's `autoLearnSessions` flag (enabled by default), every completed Shade recording was automatically fed to Scout. No button to press, no callback to wire, no background job to schedule. The Scout simply listened to Shade's `onRecordingStopped` callback and consumed each session as it arrived.

```dart
// This is all you need. The Scout learns automatically.
ColossusPlugin(
  tremors: [Tremor.fps(), Tremor.leaks()],
)
```

Behind the scenes, when a Shade session completed, the plugin chained a callback onto `onRecordingStopped` that passed the session to `Scout.analyzeSession()`. The Terrain grew silently, session by session, building understanding from observation.

"The best intelligence," Kael said, "is the kind you don't have to ask for."

After a week of production use — with no developer intervention, no configuration changes, no manual analysis — the Scout had mapped the entire Questboard. Every screen. Every transition. Every dead end and every bottleneck. A map drawn by the users themselves, read by a system that knew how to listen.

The Scout had surveyed the realm. And the *Gauntlet* — well, that was something else entirely.

---

*The scout does not need a torch to see. It reads the footprints left by others and draws the map they never knew they were making. The terrain does not lie — it simply records what is.*

---

### Lexicon Entry

| Standard Term | Titan Name | Purpose |
|---|---|---|
| Test Discovery | **Scout** | Passive session analyzer — builds flow graph from recordings |
| Flow Graph | **Terrain** | Directed graph of screens and transitions |
| Screen Node | **Outpost** | A single screen in the Terrain graph |
| Transition Edge | **March** | A directed edge between two Outposts |
| Route Resolver | **Lineage** | Resolves parameterized routes to canonical patterns |
| Route Patterns | **RouteParameterizer** | Registers and matches known route patterns |
| Screen Identifier | **Signet** | Type-safe screen identifier for Outpost lookup |

### Key APIs

| API | Description |
|---|---|
| `Scout.instance` | Singleton Scout instance |
| `scout.analyzeSession(session)` | Feed a ShadeSession into the Scout for analysis |
| `scout.terrain` | Access the current Terrain graph |
| `terrain.outposts` | List of all discovered Outpost nodes |
| `terrain.marches` | List of all discovered March edges |
| `terrain.findOutpost(route)` | Look up a specific Outpost by route |
| `terrain.toMermaid()` | Export the graph as a Mermaid diagram |
| `terrain.toAiMap()` | Export a structured map for AI consumption |
| `RouteParameterizer.registerPattern(pattern)` | Register a known route pattern |
| `RouteParameterizer.resolve(path)` | Resolve a concrete path to its pattern |
| `Atlas.registeredPatterns` | All route patterns from the Atlas trie |

---

| [← Chapter LIII: The Forge Accepts](chapter-53-the-forge-accepts.md) | [Chapter LV: The Gauntlet Awaits →](chapter-55-the-gauntlet-awaits.md) |
