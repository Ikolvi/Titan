# Chapter XXVI: The Colossus Turns Inward

*In which Kael discovers hypocrisy in the watch tower, teaches the Colossus to use its own Pillars, the Shade to feel without polling, and the Phantom to wait with patience.*

---

It started with a code review.

Kael was scrolling through the Colossus source — the Lens tabs, the Shade overlay, the performance recording bar — when a line stopped him cold.

```dart
class _ShadeLensTabState extends State<_ShadeLensTab> {
  ShadeSession? _lastSession;
  PhantomResult? _lastResult;
  String _status = 'idle';
  double _replayProgress = 0;
  // ... eleven mutable fields
```

Eleven mutable fields. In a `StatefulWidget`. With manual `setState()` calls scattered across thirty methods.

Kael stared at the screen. He had spent *weeks* building Pillar, Core, Beacon, and Vestige — a reactive architecture that tracked dependencies automatically, rebuilt only what changed, and kept business logic separated from widgets.

And the Colossus — the *performance monitor* — was using none of it.

"The watchmen don't use the tools they watch over," Kael muttered. He thought of the Questboard Pillars, each one clean and testable. He thought of Vestiges that rebuilt with surgical precision. He thought of Beacons that managed lifecycle without a single `dispose()` override.

Then he looked back at eleven mutable fields and a `setState()` that rebuilt the entire tab every time a single value changed.

The hypocrisy was architectural. And Kael decided to fix it.

---

## The Pillar Within

> *If the framework's own tools don't trust the framework, why should anyone else? The Colossus had to eat what it served.*

Kael started with the Shade Lens tab — the most complex panel, with its recording controls, session library, auto-replay toggles, and replay progress bars. Eleven pieces of state, all tangled together in widget-level fields.

The pattern was clear. Extract a Pillar. Move every field into a Core. Move every action method into the Pillar. Let the Vestige handle the reactive rendering.

```dart
class _ShadeLensPillar extends Pillar {
  _ShadeLensPillar({required this.shade, required this.colossus});

  final Shade shade;
  final Colossus colossus;

  // Every mutable field becomes a Core
  late final lastSession = core<ShadeSession?>(null);
  late final lastResult = core<PhantomResult?>(null);
  late final status = core('idle');
  late final replayProgress = core(0.0);
  late final replayTotal = core(0);
  late final isReplaying = core(false);
  late final autoReplayEnabled = core(false);
  late final waitForSettledEnabled = core(false);
  late final replaySpeed = core(1.0);
  late final savedSessions = core<List<ShadeSessionSummary>>([]);
  late final showLibrary = core(false);

  @override
  void onInit() {
    // Fire-and-forget async initialization
    _loadAutoReplayConfig();
    _loadSavedSessions();
  }

  // All business logic lives here — not in the widget
  void startRecording() {
    Lens.hide(); // Hide Lens overlay during recording
    shade.startRecording();
    status.value = 'recording';
    lastSession.value = null;
    lastResult.value = null;
  }

  void stopRecording() {
    final session = shade.stopRecording();
    lastSession.value = session;
    status.value = 'stopped';
  }
  
  // ... every action method, extracted from widget into Pillar
}
```

The beauty was in what *disappeared*. No more `setState()`. No more `mounted` checks. No more `_updateStatus()` helper that manually set five fields and triggered a rebuild of the entire tree.

Each Core tracked its own subscribers. When `status.value` changed, only the widgets reading `status` rebuilt. When `replayProgress.value` ticked forward, the progress bar re-rendered while the recording controls stayed frozen — untouched, efficient, correct.

---

## The Beacon Lifecycle

> *A Beacon creates Pillars when the widget mounts and disposes them when it unmounts. No `initState()` override. No `dispose()` override. No lifecycle bugs.*

The widget side collapsed to almost nothing:

```dart
class _ShadeTabContent extends StatelessWidget {
  const _ShadeTabContent({required this.shade, required this.colossus});
  
  final Shade shade;
  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    return Beacon(
      pillars: [() => _ShadeLensPillar(shade: shade, colossus: colossus)],
      child: Vestige<_ShadeLensPillar>(
        builder: (context, pillar) {
          return Column(
            children: [
              _buildRecordingSection(pillar),
              _buildSpeedControl(pillar),
              _buildSessionInfo(pillar),
              if (pillar.isReplaying.value)
                _buildReplayProgress(pillar),
              if (pillar.lastResult.value != null)
                _buildReplayResult(pillar),
            ],
          );
        },
      ),
    );
  }
}
```

The Beacon created `_ShadeLensPillar` in its `initState()`, called `initialize()` (which triggered `onInit()`), and would call `dispose()` automatically when the Lens closed. The entire lifecycle was declarative.

But Kael hit his first trap.

---

## The Scope Trap

> *A Vestige's builder runs inside a TitanEffect scope. Any Core read inside that scope is automatically tracked. But move that read outside the scope — into a child widget's `build()` method — and the tracking silently breaks.*

Kael's first refactoring attempt looked innocent:

```dart
// ❌ BROKEN — Core reads happen outside Vestige scope
class _RecordingSection extends StatelessWidget {
  const _RecordingSection({required this.pillar});
  final _ShadeLensPillar pillar;

  @override
  Widget build(BuildContext context) {
    // This read of pillar.status.value happens in StatelessWidget.build(),
    // which runs OUTSIDE the Vestige's TitanEffect scope.
    // Result: no tracking, no rebuilds when status changes.
    final currentStatus = pillar.status.value;
    return Text(currentStatus);
  }
}
```

This compiled. It rendered the initial state. But when `status` changed, *nothing happened*. The text stayed frozen because the Core read occurred in `_RecordingSection.build()` — a separate build method that ran outside the Vestige's tracking scope.

The fix was subtle but important. Instead of child widgets, Kael used *builder functions* called directly from the Vestige:

```dart
// ✅ CORRECT — Core reads happen inside Vestige scope
Widget _buildRecordingSection(_ShadeLensPillar p) {
  final currentStatus = p.status.value; // ← tracked!
  return Column(
    children: [
      Text('Status: $currentStatus'),
      if (currentStatus == 'idle')
        ElevatedButton(
          onPressed: p.startRecording,
          child: const Text('Record'),
        ),
      if (currentStatus == 'recording')
        ElevatedButton(
          onPressed: p.stopRecording,
          child: const Text('Stop & Report'),
        ),
    ],
  );
}
```

These functions weren't widgets — they were plain Dart functions called synchronously from the Vestige's builder. Every `Core.value` read inside them was captured by the active TitanEffect scope. When any tracked Core changed, the Vestige scheduled a rebuild, the builder ran again, and the functions ran inside the new scope.

This was the rule Kael carved into the codebase:

> **Core reads MUST happen within the Vestige builder or functions called synchronously from it. Never in child StatelessWidget `build()` methods.**

---

## The Performance Recording Bar

> *The Colossus Lens tab got its own Pillar — a lightweight sentinel for the performance recording workflow.*

The Colossus metrics tab had a simpler problem. Just two pieces of state: whether performance recording was active, and a status message. But the same principle applied.

```dart
class _PerfRecordingPillar extends Pillar {
  _PerfRecordingPillar(this.colossus);

  final Colossus colossus;
  DateTime? _perfRecordingStart;

  late final isPerfRecording = core(false);
  late final perfStatus = core('');

  void startPerfRecording() {
    colossus.resetAll();
    _perfRecordingStart = DateTime.now();
    isPerfRecording.value = true;
    perfStatus.value = 'Recording performance...';
  }

  void stopPerfRecording() {
    isPerfRecording.value = false;
    final duration = DateTime.now().difference(_perfRecordingStart!);
    perfStatus.value = 'Recorded ${duration.inSeconds}s of performance data';
    _perfRecordingStart = null;
  }
}
```

The widget wrapped it in a Beacon and Vestige, just like the Shade tab. Same pattern, smaller scale. The architectural consistency was the point.

---

## The Reactive Shade

> *The ShadeListener had been built on a lie — a 500-millisecond Timer.periodic that polled the Shade's state like a clock checking whether the sun had risen. It was time to teach it to feel.*

This was where the twist cut deepest.

The `ShadeListener` — the invisible widget wrapping the entire app, capturing gestures and showing recording indicators — used a `Timer.periodic` to check the Shade's state every half second:

```dart
// ❌ OLD — Polling every 500ms
class _ShadeListenerState extends State<ShadeListener> {
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _indicatorTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) {
        if (mounted) setState(() {}); // Rebuild to check state
      },
    );
  }
}
```

This was wasteful. Every 500 milliseconds, the ShadeListener rebuilt — even when nothing had changed. During a 30-second idle period, that was 60 unnecessary rebuilds. And when the state *did* change, there was up to a 500ms lag before the UI reflected it.

Kael saw the answer immediately. The Shade already held `isRecording` and `isReplaying` as boolean fields. He promoted them to Cores:

```dart
class Shade {
  // Before: bool _isRecording = false;
  // After:
  final Core<bool> isRecordingCore = Core(false);
  final Core<bool> isReplayingCore = Core(false);

  // Non-reactive getter for internal guards
  bool get isRecording => isRecordingCore.peek();
  bool get isReplaying => isReplayingCore.peek();

  void startRecording() {
    if (isRecordingCore.peek()) return; // .peek() avoids tracking
    isRecordingCore.value = true;       // .value= triggers listeners
    _events.clear();
    _stopwatch
      ..reset()
      ..start();
  }
}
```

The distinction mattered. Inside the Shade's own methods, `isRecordingCore.peek()` read the value without subscribing — these were guard checks, not reactive reads. But the `ShadeListener` used `.addListener()` to react instantly:

```dart
// ✅ NEW — Reactive, instant, efficient
class _ShadeListenerState extends State<ShadeListener> {
  void Function()? _stateListener;
  Timer? _eventCountTimer;  // Only during active recording

  void _setupStateListeners() {
    _stateListener = () {
      if (!mounted) return;
      setState(() {});
      
      // Start event-count polling only while recording
      if (shade.isRecording) {
        _startEventCountPolling();
      } else {
        _stopEventCountPolling();
      }
    };
    
    shade.isRecordingCore.addListener(_stateListener!);
    shade.isReplayingCore.addListener(_stateListener!);
  }

  void _teardownStateListeners() {
    if (_stateListener != null) {
      shade.isRecordingCore.removeListener(_stateListener!);
      shade.isReplayingCore.removeListener(_stateListener!);
    }
    _stopEventCountPolling();
  }
}
```

The result was dramatic. Zero rebuilds during idle time. Instant response when recording started or stopped — no 500ms lag. And the lightweight event-count timer (which tracked how many gestures had been captured) only ran *during* active recording, stopping the instant recording ended.

The polling timer died. The reactive pulse took its place.

---

## The Lens Knows When It's Seen

> *Sometimes the simplest additions carry the most weight. Lens.isVisible gave the framework awareness of its own debug overlay.*

Previously, there was no way to check whether the Lens overlay was currently showing. Components had to guess, or track their own shadow state.

```dart
// Now the Lens reports its own visibility
if (Lens.isVisible) {
  // Overlay is currently showing
  print('Debug panel is open');
}

// Shade uses this to hide the Lens during recording
void startRecording() {
  Lens.hide(); // Ensure Lens overlay doesn't interfere with recording
  shade.startRecording();
  status.value = 'recording';
}
```

A simple getter, backed by the existing overlay state. But it completed the circuit: the Lens could now see itself.

---

## The Phantom Learns Patience

> *Real apps don't pause between actions. They fire API calls, show loading spinners, open date pickers, and expect users to wait. The Phantom needed to learn the same patience.*

The original Phantom was fast — *too* fast. It replayed gestures at exact recorded intervals, which worked for simple flows. But in a real Questboard checkout:

1. User taps "Add to Cart" → API call fires, spinner appears
2. User waits 2 seconds for the response
3. User taps "Checkout" → dialog opens
4. User taps "Confirm" in the dialog

The Phantom replayed the gestures at the right timestamps, but the API call during replay might take 3 seconds instead of 2. The "Checkout" tap landed before the cart loaded. The "Confirm" tap fired before the dialog opened.

Kael added `waitForSettled` — a hook that paused the Phantom between events until the app was ready:

```dart
final result = await Phantom.replay(
  session,
  waitForSettled: () async {
    // Wait until no loading indicators are visible
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  },
);
```

Between each replayed event, the Phantom called `waitForSettled()`. If a loading spinner was still spinning, `pumpAndSettle` waited. If a dialog was animating open, it waited. Only when the widget tree settled — no pending frames, no running animations — did the Phantom fire the next event.

This made replays reliable across network conditions, device speeds, and animation durations. The Phantom didn't guess timing. It *observed* readiness.

---

## The Route Guardian Speaks

> *The auto-replay safety check gained a visual voice — a warning banner in the Lens panel when the Phantom detected a route mismatch.*

When `checkAutoReplay()` detected that the current route didn't match the session's `startRoute`, it blocked the replay. But previously, this was silent — the replay simply didn't start, and the developer had to check logs to understand why.

Now the Lens showed the mismatch:

```dart
void checkRouteMismatch() {
  final session = lastSession.value;
  if (session == null) return;

  final currentRoute = Atlas.currentRoute;
  if (session.startRoute != null && 
      currentRoute != session.startRoute) {
    // Core update triggers an immediate rebuild of the warning banner
    status.value = 
      'Route mismatch: session recorded on "${session.startRoute}" '
      'but current route is "$currentRoute"';
  }
}
```

A single Core update. The Vestige rebuilt the relevant section. A warning banner appeared:

```
⚠ Route mismatch: session recorded on "/checkout" but current route is "/home"
```

No manual `setState()`. No notification system. Just a Core, a Vestige, and the truth.

---

## The Mirror Test

Kael stood back and surveyed the refactoring.

The Shade Lens tab: eleven mutable fields replaced by eleven Cores in a Pillar. Thirty `setState()` calls replaced by direct Core assignments. A 400-line `StatefulWidget` replaced by a 50-line `StatelessWidget` wrapping a Beacon and a Vestige.

The Colossus Lens tab: same pattern, smaller scale. Two Cores, one Pillar, one Beacon.

The ShadeListener: a polling timer replaced by two `Core.addListener()` registrations. Zero rebuilds during idle. Instant response during state transitions.

The architecture had turned inward. The framework's own monitoring tools now used the framework's reactive patterns — the same Pillars and Cores that powered the Questboard's quest lists, the same Vestiges that tracked hero leaderboards, the same Beacons that managed lifecycle.

This was the mirror test. If the watchmen trust the walls they guard, the walls are strong.

---

## What Kael Learned

1. **The framework must use itself** — if the Colossus widgets don't use Pillar/Core/Beacon/Vestige, the patterns aren't proven at scale
2. **Eleven fields become eleven Cores** — every mutable field in a StatefulWidget is a candidate for extraction into a Pillar
3. **Beacon manages lifecycle** — creates Pillars on mount, disposes on unmount, no `initState()` or `dispose()` overrides needed
4. **Vestige scope is law** — Core reads must happen inside the Vestige builder, never in child widget `build()` methods
5. **Builder functions, not builder widgets** — use plain functions called from Vestige, not StatelessWidget subclasses, to preserve the tracking scope
6. **`Core.peek()` for guards, `.value` for reactivity** — internal state checks use `.peek()` to avoid accidental subscriptions; UI reads use `.value` for auto-tracking
7. **`Core.addListener()` replaces polling** — instant state transitions, zero idle rebuilds, no lag between state change and response
8. **`Lens.isVisible` completes the circuit** — the Lens can now check its own visibility, enabling behaviors like hiding during recording
9. **`waitForSettled` makes replays reliable** — the Phantom waits for the app to settle between events, handling variable network and animation timing
10. **Route mismatch warnings are reactive** — a single `Core.value` assignment triggers the Vestige to show the warning banner, no notification plumbing required
11. **The mirror test validates the architecture** — when the framework's own tools use the framework, trust is earned, not claimed

---

*The watchtower no longer stood apart from the city it guarded. Its stones were the same stones, its mortar the same mortar, its foundations the same foundations. The Colossus had turned inward and found itself.*

*But as Kael watched the reactive pulses flow — Core to Vestige, Pillar to Beacon, Shade to Phantom — he noticed something else. Patterns. Not in the code, but in the data. The sessions recorded by the Shade weren't just replays. They were *blueprints*. Each one described a user's path through the app — the hesitations, the backtracks, the abandoned checkout flows.*

*"What if we could learn from them?" Kael whispered. Not just replay. Not just monitor. But understand. Predict. Anticipate.*

*He opened the Shade's session data and began to see shapes in the chaos...*

---

| | |
|---|---|
| **Previous** | [Chapter XXV: The Vault Remembers](chapter-25-the-vault-remembers.md) |
| **Next** | [Chapter XXVII: The Sentinel Awakens](chapter-27-the-sentinel-awakens.md) |
