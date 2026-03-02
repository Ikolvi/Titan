# Chapter XXV: The Vault Remembers

*In which Kael teaches the Shade to read, the Vault to persist, the Phantom to awaken on its own, the keyboard to stay silent, and the routes to keep the Phantom safe.*

---

The Shade had proven itself. Recording gestures, replaying them through the Phantom, monitoring the results with the Colossus. The feedback loop was powerful.

But Kael hit three walls in the same afternoon.

The first wall: the login flow. A user taps the email field, *types* an address, tabs to the password field, *types* a password, taps Submit. The Shade captured the taps — but the typing vanished. The replay pressed the right buttons but never entered a single character.

The second wall: sessions died with the app. Every recording lived in memory. Close the app, lose the recording. Every QA cycle started from zero.

The third wall: the manual trigger. Someone had to open the Lens, tap Record, walk through the flow, tap Stop, tap Replay. Every. Single. Time. "What if," Kael muttered, "the app replayed itself the instant it launched?"

---

## The Shade Reads

> *The original Shade was blind to text — it followed fingers but not thoughts. To capture what the user writes, the Shade needed a new instrument: the ShadeTextController.*

The problem was architectural. Text input in Flutter flows through platform channels — a closed pipeline between the soft keyboard and the `TextEditingController`. The Shade's `Listener` widget never sees these events because they bypass the pointer system entirely.

Kael needed a different approach. Instead of intercepting text from the outside, he wired the tracking *into* the controller itself:

```dart
// A TextEditingController that automatically records to Shade
final emailController = ShadeTextController(
  shade: Colossus.instance.shade,
  fieldId: 'email',    // Identifies this field during replay
);

// Drop-in replacement — same API, but now tracked
TextField(controller: emailController)
```

The `ShadeTextController` extends `TextEditingController` and listens to its own value changes. When the text content changes (not just cursor movement), it calls `shade.recordTextChange()` — creating an `ImprintType.textInput` event with the full editing state:

```dart
// What gets recorded for each text change
Imprint(
  type: ImprintType.textInput,
  text: 'kael@ironclad.dev',
  selectionBase: 18,
  selectionExtent: 18,
  composingBase: -1,
  composingExtent: -1,
  fieldId: 'email',
  timestamp: Duration(milliseconds: 3400),
)
```

"It's opt-in," Kael explained to the team. "Regular `TextEditingController` knows nothing about Shade. You swap in `ShadeTextController` only for fields you want to track."

### Keyboard Events

Beyond text content, the Shade also captures raw keyboard events through `HardwareKeyboard.instance`:

```dart
// These happen automatically when ShadeListener is in the tree
Imprint(type: ImprintType.keyDown, keyId: 0x61, character: 'a', ...)
Imprint(type: ImprintType.keyUp,   keyId: 0x61, ...)
```

The `ShadeListener` — now a `StatefulWidget` — registers a keyboard handler on mount and removes it on dispose. Every `KeyDownEvent`, `KeyUpEvent`, and `KeyRepeatEvent` becomes an Imprint with the logical key ID, physical USB HID code, and generated character.

### Text Actions

When the user taps "Done" or "Next" on the soft keyboard, that's a `TextInputAction`. The Shade captures those too:

```dart
shade.recordTextAction(TextInputAction.done, fieldId: 'email');
// Creates ImprintType.textAction with action index
```

The complete picture now includes everything:

| User Action | Imprint Type | Data Captured |
|-------------|-------------|---------------|
| Tap, scroll, drag | `pointerDown/Move/Up` | Position, pressure, timing |
| Key press | `keyDown/keyUp/keyRepeat` | Logical key, physical key, character |
| Text entry | `textInput` | Full text, selection, composing, field ID |
| Keyboard action | `textAction` | Action index, field ID |

"Now the Shade sees *everything*," Kael said. "Fingers *and* thoughts."

---

## The Vault Preserves

> *A recording that dies with the app is a recording that never existed. The Vault persists sessions across lifetimes, keeping them safe until the Phantom needs them again.*

Sessions needed a home. Kael built the `ShadeVault` — a file-based persistence layer that saves sessions as JSON:

```dart
// Initialize Colossus with a storage path
Colossus.init(
  tremors: [Tremor.fps(), Tremor.jankRate()],
  enableLensTab: true,
  shadeStoragePath: '/path/to/app/shade_sessions',
);

// After recording, save to the vault
final session = shade.stopRecording();
await Colossus.instance.saveSession(session);
```

The vault stores each session as a `.shade.json` file with the session ID as the filename. Loading, listing, and deleting are straightforward:

```dart
final vault = Colossus.instance.vault!;

// List all saved sessions (metadata only — fast)
final sessions = await vault.list();
for (final summary in sessions) {
  print('${summary.name}: ${summary.eventCount} events, '
        '${summary.durationMs}ms');
}

// Load a specific session for replay
final session = await vault.load('checkout_flow_1234');

// Delete when no longer needed
await vault.delete('old_session');

// Nuclear option
await vault.deleteAll();
```

The `list()` method returns `ShadeSessionSummary` objects — lightweight metadata without loading the full imprint array. This keeps the session library fast even with hundreds of saved recordings.

"Save once, replay forever," the architect said. "Now your QA recordings survive app restarts, CI runs, even device changes."

---

## The Phantom Awakens

> *The ultimate automation: the Phantom doesn't wait to be summoned. Configure auto-replay, and the next time the app launches, the ghost walks on its own.*

This was the breakthrough Kael had been chasing. Instead of manually triggering replays, the app could replay a saved session automatically on startup:

```dart
// Configure auto-replay
await Colossus.instance.setAutoReplay(
  enabled: true,
  sessionId: 'checkout_flow_1234',
  speed: 2.0,  // 2× speed for faster regression checks
);
```

The configuration is stored in a `.shade_config.json` file alongside the sessions. On the next app launch, a single line triggers the replay:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  Colossus.init(
    tremors: [Tremor.fps()],
    shadeStoragePath: shadeDir,
  );

  // Check for auto-replay after the first frame renders
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Colossus.instance.checkAutoReplay();
  });

  runApp(MyApp());
}
```

`checkAutoReplay()` reads the config, loads the specified session, and replays it — all automatically. The Colossus monitors performance during the replay, and when it's done, you have a full `Decree` ready for comparison.

"Imagine this in CI," Kael said, his eyes widening. "Record the checkout flow once. Every build, the app launches, replays the same flow, generates a Decree. Compare Decrees across builds. Performance regression detection — fully automated."

### Disabling Auto-Replay

Turn it off when you're done:

```dart
await Colossus.instance.setAutoReplay(enabled: false);
```

The config file updates, and the next launch proceeds normally.

---

## The Enhanced Lens

> *The Shade tab in the Lens overlay grew beyond a simple Record/Stop toggle. It became a full control surface — session library, speed controls, auto-replay toggle, all at the developer's fingertips.*

The redesigned Shade tab in Lens now provides:

### Speed Control

Four preset speeds for replay — 0.5×, 1×, 2×, and 5×:

```
Speed: [0.5x] [1x] [2x] [5x]
```

Select a speed before hitting Replay. The Phantom adjusts all inter-event delays proportionally.

### Session Library

An expandable section listing all saved sessions with per-session controls:

```
▸ Session Library (3)
  checkout_flow    247 events · 12450ms    [⟳] [▶] [🗑]
  onboarding       89 events · 5200ms     [⟳] [▶] [🗑]
  settings_nav     156 events · 8100ms    [⟳] [▶] [🗑]
                                          Clear All
```

Each session has three action icons:
- **⟳** Set as auto-replay session
- **▶** Replay immediately
- **🗑** Delete from vault

### Auto-Replay Toggle

A switch that enables or disables auto-replay for the next app launch:

```
[⟳] Auto-replay on restart  [═══○]
```

When enabled with a current session loaded, it saves the session and configures auto-replay in one action.

### Save Button

After recording, a "Save" button appears alongside "Replay" — storing the session in the vault for later use:

```
[● Record]  [▶ Replay]  [💾 Save]
```

"Everything from one overlay," Kael said, swiping through the controls. "Record, save, browse, replay, automate. No need to leave the app."

---

## The Silent Update

> *During replay, the ShadeTextController needs to change text without re-recording it. The silent update prevents an infinite echo.*

A subtle but critical detail: when the Phantom replays a text input event, it needs to set the text field's value. But if it uses a `ShadeTextController`, that change would be re-recorded — creating duplicate events. The solution:

```dart
// During replay — set text without triggering recording
controller.setTextSilently('kael@ironclad.dev');

// Or set the full editing value (text + selection + composing)
controller.setValueSilently(TextEditingValue(
  text: 'kael@ironclad.dev',
  selection: TextSelection.collapsed(offset: 18),
));
```

The `_suppressed` flag inside `ShadeTextController` blocks the listener during silent updates, preventing the echo loop.

---

## The Controller Registry

> *A controller that registers itself with the Shade — so the Phantom can find it by name, inject text directly, and never open the keyboard at all.*

The silent update solved the echo problem, but there was a deeper issue. During replay, the Phantom needed to *find* the right `ShadeTextController` for each text event. The `onTextInput` callback worked, but it required the app to manually route events to the correct field. For ten fields across five screens, that wiring became a tangle.

Kael built a registry. Every `ShadeTextController` with a `fieldId` automatically registers itself with the Shade on creation and unregisters on dispose:

```dart
// Creating a controller auto-registers it
final email = ShadeTextController(shade: shade, fieldId: 'email');
// shade.textControllers['email'] == email  ✓

// Disposing auto-unregisters
email.dispose();
// shade.textControllers['email'] == null  ✓
```

Now the Phantom has a direct line to every text field:

```dart
// During replay — Phantom looks up the controller by field ID
final controller = shade.getTextController(imprint.fieldId!);

if (controller != null) {
  // Direct injection — no keyboard, no callbacks, no wiring
  controller.setValueSilently(TextEditingValue(
    text: imprint.text ?? '',
    selection: TextSelection(
      baseOffset: imprint.selectionBase ?? 0,
      extentOffset: imprint.selectionExtent ?? 0,
    ),
  ));
} else {
  // Fallback for unregistered fields
  onTextInput?.call(imprint);
}
```

"If the controller exists, use it directly," Kael said. "If not, fall back to the callback. Zero configuration for the common case."

The Shade also tracks replay state with an `isReplaying` flag. When the Phantom starts replaying, it sets `shade.isReplaying = true`, and when it finishes (or cancels), it sets it back to `false`. During replay, `ShadeTextController` checks this flag and suppresses recording — preventing echo without any manual intervention.

---

## The Keyboard Silence

> *The soft keyboard flashed open and closed on every tap — a distracting, stuttering mess during replay. To silence it, Kael taught the Phantom to look ahead.*

The first real test was devastating. The Phantom tapped the email field. The keyboard flew up. The Phantom injected text directly via the controller. The keyboard was now open but *empty* — a confusing flash. Then the Phantom tapped the next field. The keyboard flew up *again*. More flashing.

The problem: pointer events that tap text fields trigger the platform's keyboard pipeline. The Phantom dispatches a `PointerDownEvent` → Flutter's focus system gives focus to the text field → the platform opens the soft keyboard. All before the text injection even happens.

Kael's solution was two-fold.

**Look-ahead detection**: Before dispatching a pointer event, the Phantom scans forward through the remaining imprints. If a `textInput` or `textAction` event appears before the next `pointerDown`, this tap is about to focus a text field:

```dart
// Phantom's internal look-ahead
bool _nextImprintIsText(int index, List<Imprint> imprints) {
  for (var i = index + 1; i < imprints.length; i++) {
    final next = imprints[i];
    if (next.type == ImprintType.textInput ||
        next.type == ImprintType.textAction) {
      return true;
    }
    if (next.type == ImprintType.pointerDown) return false;
  }
  return false;
}
```

**Preemptive dismissal**: When the look-ahead detects text, the Phantom dismisses focus and hides the keyboard *before* dispatching the pointer event:

```dart
if (suppressKeyboard && _nextImprintIsText(i, session.imprints)) {
  FocusManager.instance.primaryFocus?.unfocus();
  SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
}

binding.handlePointerEvent(event);  // Tap proceeds — but keyboard stays down
```

Two mechanisms work together:
- `FocusManager.instance.primaryFocus?.unfocus()` — removes focus from the currently focused widget
- `SystemChannels.textInput.invokeMethod('TextInput.hide')` — tells the platform to dismiss the soft keyboard

The result: the Phantom taps the email field, text appears character by character, the Phantom taps the password field, text appears there too — and the keyboard never opens once.

```dart
final phantom = Phantom(
  shade: shade,
  suppressKeyboard: true,  // default — the keyboard stays silent
);
```

"The user sees text appearing in fields like a ghost is typing," Kael grinned. "No keyboard. No flashing. Just clean, direct text injection."

---

## The Route Sentinel

> *A session recorded on the checkout page becomes dangerous on the home page. The Shade needed to remember where it was — and the Phantom needed to check before replaying.*

The bug manifested on a Friday afternoon. A QA engineer recorded a session on the settings screen — toggles, sliders, text fields. Then they navigated to the hero list and hit Replay. The Phantom dutifully dispatched pointer events at coordinates that made sense on the settings page — but on the hero list, those coordinates hit delete buttons and navigation links. Three heroes were deleted before anyone hit Stop.

The fix had two parts.

**Part one: remember the route.** When recording starts, the Shade captures the current route:

```dart
shade.getCurrentRoute = () {
  try {
    return Atlas.current.path;
  } catch (_) {
    return null;
  }
};

shade.startRecording(name: 'settings_flow');
// session.startRoute == '/settings'  ✓
```

The `getCurrentRoute` callback keeps the Shade decoupled from Atlas — it's just a `String? Function()?` that the app wires up. The route is stored in `ShadeSession.startRoute` and serialized through `toJson`/`fromJson`, so it survives vault persistence.

**Part two: check before replay.** `Colossus.replaySession()` compares the session's route against the current route:

```dart
// Soft check — warn but proceed
final result = await Colossus.instance.replaySession(session);
// Chronicle logs: "Route mismatch: session was recorded on '/settings'
//                  but app is on '/heroes'"

// Hard check — throw on mismatch
final result = await Colossus.instance.replaySession(
  session,
  requireMatchingRoute: true,  // throws StateError on mismatch
);
```

**Part three: visual warning.** The Lens overlay shows the route information in the session card. When the current route doesn't match, an orange warning banner appears:

```
⚠ Route mismatch
  Recorded on "/settings" but on "/heroes"
```

The replay still *works* — the warning is informational, not a blocker. But with `requireMatchingRoute: true`, the Phantom refuses to start.

"The Shade remembers where it was," Kael said. "And the Phantom checks before it walks."

---

## The Complete Pipeline

Kael wired everything together:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final shadeDir = '${Directory.systemTemp.path}/questboard_shade';

  Colossus.init(
    tremors: [Tremor.fps(), Tremor.jankRate(), Tremor.leaks()],
    enableLensTab: true,
    shadeStoragePath: shadeDir,
  );

  // Auto-replay if configured
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Colossus.instance.checkAutoReplay();
  });

  runApp(
    ShadeListener(
      shade: Colossus.instance.shade,
      child: Lens(
        enabled: true,
        child: MaterialApp.router(routerConfig: atlas.config),
      ),
    ),
  );
}

// In a form screen
class LoginScreen extends StatefulWidget { ... }

class _LoginScreenState extends State<LoginScreen> {
  late final ShadeTextController _email;
  late final ShadeTextController _password;

  @override
  void initState() {
    super.initState();
    final shade = Colossus.instance.shade;
    _email = ShadeTextController(shade: shade, fieldId: 'email');
    _password = ShadeTextController(shade: shade, fieldId: 'password');
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _email, decoration: ...),
        TextField(controller: _password, obscureText: true, ...),
        FilledButton(onPressed: _login, child: Text('Sign In')),
      ],
    );
  }
}
```

Now the complete flow:

1. **User opens app** → `checkAutoReplay()` checks for saved config
2. **If auto-replay enabled** → Phantom replays the saved session automatically
3. **If not** → user interacts normally, Shade captures everything (taps + text + keys)
4. **User finishes** → Stop recording, save to vault through Lens
5. **Next launch** → same flow replays with full Colossus monitoring
6. **Compare Decrees** → detect performance regressions across builds

---

## What Kael Learned

1. **ShadeTextController tracks text input** — opt-in, per-field, with field IDs for targeting
2. **Silent updates prevent echo** — `setTextSilently()` and `setValueSilently()` for replay
3. **The controller registry enables direct injection** — `ShadeTextController` auto-registers via `fieldId`, Phantom looks up controllers by name
4. **HardwareKeyboard captures keys** — `keyDown`, `keyUp`, `keyRepeat` events with full key data
5. **ShadeVault persists sessions** — JSON files on disk, lightweight listing, full CRUD
6. **Auto-replay automates everything** — configure once, replay on every launch
7. **The Lens is the control center** — speed controls, session library, auto-replay toggle, route mismatch warnings
8. **Keyboard suppression is preemptive** — look-ahead detection + `FocusManager.unfocus()` + `SystemChannels.textInput.hide` prevents keyboard flashes
9. **Route safety protects against misplaced replays** — `ShadeSession.startRoute` + `Colossus.replaySession(requireMatchingRoute: true)` + Lens warning banner
10. **The `isReplaying` flag coordinates suppression** — controllers and listeners stop recording during replay
11. **The loop is closed** — record → save → auto-replay → compare Decrees → detect regressions

---

*The Vault's shelves filled with sessions — checkout flows, onboarding sequences, settings explorations, edge cases that once required a human to reproduce. Each session was a frozen moment in time, ready to be thawed by the Phantom at a moment's notice.*

*But Kael's gaze had already moved beyond the Vault. The sessions were recordings of what *was*. The Decrees were snapshots of how the app *performed*. Together they told the story of the past.*

*"What about the future?" Kael wondered. "Can we predict where the Colossus will stumble before it falls?"*

*He opened a new file and began to type...*

---

| | |
|---|---|
| **Previous** | [Chapter XXIV: The Shade Follows](chapter-24-the-shade-follows.md) |
| **Next** | [Chapter XXVI: The Colossus Turns Inward](chapter-26-the-colossus-turns-inward.md) |
