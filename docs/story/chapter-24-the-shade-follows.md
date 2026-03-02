# Chapter XXIV: The Shade Follows

*In which Kael discovers that the truest test of performance is not what the developer measures — but what the user experiences.*

---

The Decree was written. The Inscribe had preserved it — Markdown for reviews, JSON for dashboards, HTML for the board. Kael had numbers. Charts. Export buttons.

But something nagged at him.

"We're measuring how the *machine* performs," Kael said, staring at the Lens overlay. "FPS. Build times. Raster durations. These are the *engine's* metrics."

His architect looked up from her screen. "And?"

"What about the *user's* journey? When someone taps through checkout — add to cart, fill address, confirm payment — do we know what that *feels* like? Not what the frame counter says, but what a real finger on real glass experiences?"

The architect smiled. "You want to follow the user."

"I want to *be* the user. Or at least... have something that can be their shadow."

---

## The Shade

> *Every Colossus casts a shadow. The Shade follows every gesture a user makes — silent, invisible, faithful. It records the exact path they walked, and when called upon, a Phantom walks that path again.*

The Shade is the Colossus's recording system. Where the Colossus watches *performance*, the Shade watches *behavior*. It captures every tap, every scroll, every drag, every swipe — the complete interaction fingerprint of a user session.

```dart
// The Shade lives within the Colossus
final shade = Colossus.instance.shade;

// Start recording the user's journey
shade.startRecording(name: 'checkout_flow');
```

But the Shade cannot see what it cannot touch. To capture every gesture in the app, Kael needed the **ShadeListener** — a transparent sentinel that wraps the entire widget tree.

---

## The ShadeListener

> *The ShadeListener stands at the gate, invisible to all who pass. Every gesture that enters the realm leaves its mark — an Imprint in the Shade's ledger.*

```dart
// Wrap the entire app to capture all pointer events
ShadeListener(
  shade: Colossus.instance.shade,
  child: MaterialApp.router(
    routerConfig: atlas.config,
  ),
)
```

The `ShadeListener` uses Flutter's `Listener` widget with `HitTestBehavior.translucent` — meaning it sees every pointer event but never intercepts them. The user notices nothing. The app behaves identically. But beneath the surface, every touch is being recorded.

"It's like a one-way mirror," Kael mused. "The Shade sees everything. The user sees only their reflection."

---

## The Imprint

> *Each gesture leaves an Imprint — a fossilized moment of interaction. Position, timing, pressure, device — everything needed to reconstruct the original touch.*

When the Shade captures a pointer event, it creates an `Imprint`:

```dart
// An Imprint preserves every detail of a pointer event
final imprint = Imprint(
  type: ImprintType.pointerDown,        // What happened
  positionX: 187.5,                      // Where (logical pixels)
  positionY: 402.0,
  timestamp: Duration(milliseconds: 1200), // When (relative to start)
  pointer: 1,                            // Which finger/button
  buttons: 1,                            // Primary button pressed
  pressure: 0.85,                        // How hard
);
```

Every interaction decomposes into a sequence of Imprints:

| User Action | Imprint Sequence |
|-------------|-----------------|
| Tap | `pointerDown` → `pointerUp` |
| Scroll | `pointerDown` → `pointerMove` × N → `pointerUp` |
| Swipe | `pointerDown` → `pointerMove` × N → `pointerUp` (with velocity) |
| Long press | `pointerDown` → (pause) → `pointerUp` |
| Pinch zoom | Two `pointerDown`s → `pointerMove` × N → two `pointerUp`s |
| Mouse scroll | `pointerScroll` with `scrollDeltaY` |

The timestamp on each Imprint is relative to the session start — not wall-clock time. This means replay can be speed-adjusted without losing the relationship between events.

---

## The ShadeSession

> *A collection of Imprints, bound together with metadata, forms a ShadeSession — the complete record of a user's journey through the app.*

When Kael stopped the recording, the Shade assembled all Imprints into a `ShadeSession`:

```dart
// Stop recording and get the complete session
final session = shade.stopRecording();

print(session.name);        // 'checkout_flow'
print(session.eventCount);  // 247
print(session.duration);    // 0:00:12.450000
print(session.screenWidth); // 375.0
print(session.screenHeight);// 812.0
```

The session captures the screen dimensions at recording time — critical information. If the session is replayed on a different device, the Phantom can normalize positions proportionally.

Sessions serialize to JSON:

```dart
// Save the session for later
final json = session.toJson();

// Restore it anytime
final restored = ShadeSession.fromJson(json);
```

"Twelve seconds," Kael read from the session. "Two hundred forty-seven events. That's the entire checkout flow, frozen in JSON."

"Now replay it," the architect said.

---

## The Phantom

> *The Phantom is a ghost user — invisible, silent, perfect. It walks the exact path the original user walked, triggering the same taps and scrolls at the same timing. The Colossus watches, measures, and judges.*

The `Phantom` takes a `ShadeSession` and replays every Imprint through Flutter's gesture system using `GestureBinding.handlePointerEvent()` — the exact same code path that real touch input follows.

```dart
// Replay the recorded session while monitoring performance
final result = await Colossus.instance.replaySession(session);

// The Colossus measured everything during replay
final decree = Colossus.instance.decree();
print(decree.summary);
// Health: GOOD | FPS: 59.8 | Jank: 0.5% | Pillars: 8
```

This is the key insight: **the Phantom's events are indistinguishable from real input.** Flutter's gesture recognizers — tap detectors, scroll controllers, drag handlers — process synthetic events identically to human-generated ones. The hit-testing, gesture arena, and event dispatch all work exactly the same.

### Replay Speed

The Phantom can replay at any speed:

```dart
// Double speed — useful for quick regression checks
final phantom = Phantom(speedMultiplier: 2.0);
await phantom.replay(session);

// Half speed — useful for debugging specific interactions
final phantom = Phantom(speedMultiplier: 0.5);
await phantom.replay(session);
```

### Screen Normalization

If the replay device has a different screen size, the Phantom normalizes positions proportionally:

```dart
// Recorded on iPhone 14 (375×812)
// Replaying on iPad (768×1024)
// Phantom scales all positions automatically
final phantom = Phantom(normalizePositions: true); // default
await phantom.replay(session);
```

### Replay Progress

Track replay progress for UI feedback:

```dart
final result = await Colossus.instance.replaySession(
  session,
  onProgress: (current, total) {
    print('Event $current / $total');
  },
);

print(result.eventsDispatched); // 247
print(result.actualDuration);   // 0:00:12.510000
print(result.wasNormalized);    // true
```

---

## The PhantomResult

> *When the Phantom completes its walk, it delivers a result — how many events it dispatched, how long it took, whether it was cancelled or completed.*

```dart
final result = await phantom.replay(session);

print(result.sessionName);      // 'checkout_flow'
print(result.eventsDispatched);  // 245
print(result.eventsSkipped);     // 2 (unsupported types)
print(result.totalEvents);       // 247
print(result.expectedDuration);  // Original recording duration
print(result.actualDuration);    // How long replay actually took
print(result.wasNormalized);     // true (different screen size)
print(result.wasCancelled);      // false
print(result.speedRatio);        // ~1.0 (actual/expected)
```

---

## The Complete Flow

Kael assembled the entire pipeline:

```dart
void main() {
  Colossus.init(
    tremors: [Tremor.fps(), Tremor.jankRate()],
  );

  runApp(
    ShadeListener(
      shade: Colossus.instance.shade,
      child: Lens(
        enabled: kDebugMode,
        child: MaterialApp.router(routerConfig: atlas.config),
      ),
    ),
  );
}

// Later, in a test or debug screen:
Future<void> replayAndReport() async {
  // Load a previously saved session
  final session = ShadeSession.fromJson(savedJson);

  // Replay — Colossus monitors everything
  final result = await Colossus.instance.replaySession(session);

  // Generate and export the report
  final decree = Colossus.instance.decree();
  await InscribeIO.saveAll(decree, directory: '/reports');

  print('Replay: ${result.eventsDispatched} events, '
        '${result.actualDuration.inMilliseconds}ms');
  print('Performance: ${decree.summary}');
}
```

The architect reviewed Kael's code. "You've closed the loop," she said. "Record once, replay forever. Same gestures, same timing, different code. Compare the Decrees and you know if you're getting faster or slower."

"It's not a unit test," Kael said. "It's the *user's* test."

---

## The Lens Shade Tab

The Shade also registers its own tab in the Lens overlay — separate from the Perf tab. From there, Kael could:

1. **Record** — Start/stop gesture recording with a single tap
2. **View** — See the last session's metadata (event count, duration, screen size)
3. **Replay** — Play back the recorded session with a progress indicator
4. **Report** — Check the Perf tab for metrics collected during replay

"Two tabs," Kael noted. "Perf for the engine. Shade for the user. The Colossus watches both."

---

## Limitations

> *Even the Colossus had its blind spots. The Shade records what Flutter sees — not what the platform hides.*

Kael learned the Shade's boundaries:

| What the Shade Can Record | What It Cannot |
|---------------------------|----------------|
| Taps, scrolls, drags, swipes | Text input (platform channel) |
| Mouse clicks and wheel scrolls | Platform dialogs |
| Multi-touch gestures | System gestures (home, notifications) |
| Pan and zoom on trackpads | Android back button |
| iOS edge-swipe back | Keyboard shortcuts (partially) |

"The Shade sees everything *inside* Flutter," Kael summarized. "System-level gestures are outside its reach. But for testing user flows — checkout, onboarding, browsing — it captures everything that matters."

---

## What Kael Learned

1. **The Shade follows silently** — `ShadeListener` captures all pointer events without interfering
2. **Imprints preserve everything** — position, timing, pressure, device kind
3. **Sessions serialize to JSON** — record once, replay anywhere
4. **The Phantom walks the same path** — synthetic events are identical to real input
5. **Screen normalization handles different devices** — positions scale proportionally
6. **The Colossus watches during replay** — full performance metrics during automated playback
7. **Record once, compare forever** — same interaction, different code versions

---

*The Shade had always been there — following the Colossus across the harbor, stretching long in the afternoon sun. Now Kael had given it purpose. The shadow that once merely followed would now lead — guiding the Phantom through the same steps, the same paths, the same gestures that real users walked.*

*But as the Phantom replayed the checkout flow for the tenth time, Kael noticed something in the Decree that made him pause. The metrics were good. The FPS was solid. The jank rate was low.*

*But the patterns... the patterns were changing. The same code, the same gestures, but subtly different results each time. Not in the numbers — in the shapes. The Colossus was watching the weather, but someone needed to watch the climate.*

*Kael opened a new file. There was more work to do...*

---

| | |
|---|---|
| **Previous** | [Chapter XXIII: The Inscribe Endures](chapter-23-the-inscribe-endures.md) |
| **Next** | [Chapter XXV: The Vault Remembers](chapter-25-the-vault-remembers.md) |
