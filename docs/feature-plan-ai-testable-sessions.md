# Feature Plan: AI-Testable Session Recording & Autonomous Testing

## Glyph + Tableau + Fresco + Stratagem + Verdict

*Colossus already records every gesture. Now it learns to see the screen, describe it to AI, optionally screenshot it, and execute AI-generated test plans autonomously — eliminating the need for human testers.*

---

## Executive Summary

| Question | Answer |
|---|---|
| **What?** | Two major capabilities: **(1)** Capture full screen context (widget layout, labels, button states) alongside gestures so AI agents can read, understand, and generate tests. **(2)** Execute AI-generated test blueprints (Stratagems) autonomously and produce detailed pass/fail reports (Verdicts) — no human tester required. |
| **Developer effort to adopt?** | **Zero.** If `Colossus.init()` is already called, everything is automatic. No new widgets, no annotations, no configuration. |
| **Screenshot capture?** | **Optional.** One flag: `Colossus.init(enableScreenCapture: true)`. Off by default (privacy/size). |
| **Breaking changes?** | **None.** Old sessions deserialize fine. All new fields are nullable/optional. |
| **Why Colossus?** | Everything lives inside Colossus — Shade, Phantom, Tableau, Glyph, Fresco, Stratagem, Verdict. One `init()`, one ecosystem, one package. |
| **The vision?** | Developer says "test the login flow" → AI writes a Stratagem → Colossus executes it → Verdict report shows pass/fail, API errors, missing pages → AI reads the Verdict and fixes issues. **No human tester in the loop.** |

---

## The Problem

Shade records WHERE the user tapped `(187.5, 642.0)`. It does NOT record WHAT they tapped ("Submit Order" button). An AI reading raw Imprints sees meaningless coordinates.

```json
{"type": "pointerDown", "x": 187.5, "y": 642.0, "ts": 3400000}
```

**AI sees**: "A finger touched (187.5, 642.0) at 3.4s."
**AI needs to see**: "User tapped the 'Add to Cart' button (ElevatedButton) on /product/123."

---

## The Solution

Five new Titan primitives, all managed internally by Colossus:

| Standard Term | Titan Name | Class | Purpose |
|---|---|---|---|
| UI Element Descriptor | **Glyph** | `Glyph` | Describes one UI element: type, label, bounds, interaction type, semantics |
| Screen Snapshot | **Tableau** | `Tableau` | Complete snapshot of all Glyphs on screen at a moment + route + metadata |
| Screen Image Capture | **Fresco** | `Fresco` | Optional PNG screenshot of the screen, captured alongside a Tableau |
| Test Blueprint | **Stratagem** | `Stratagem` | AI-generated test plan — steps, targets, expectations. Colossus executes it autonomously. |
| Execution Report | **Verdict** | `Verdict` | Complete pass/fail report from executing a Stratagem — failures, API errors, missed pages, performance. |

### Why These Names?

- **Glyph** — Carved symbols on a Titan monument. Each Glyph preserves a UI element's identity for future readers (AI agents) to decipher.
- **Tableau** — A frozen dramatic scene. The screen at any moment is a Tableau — a complete composition of Glyphs in a meaningful layout.
- **Fresco** — A painted mural on the Titan's wall. An actual visual image of the screen, preserved alongside the structural Glyph data.
- **Stratagem** — A Titan's battle plan. The AI writes the Stratagem (what to test, what to expect), and the Colossus executes it without question.
- **Verdict** — The judgment carved in stone. After executing the Stratagem, the Colossus delivers its Verdict — what passed, what failed, and why.

---

## Zero Developer Effort — Design Principle

**This is the most important constraint.** If a developer already has Colossus running, Glyph + Tableau capture must work with zero additional code.

### What the developer writes today (unchanged):

```dart
void main() {
  Colossus.init();

  runApp(
    ShadeListener(
      shade: Colossus.instance.shade,
      child: MaterialApp.router(
        routerConfig: atlas.config,
      ),
    ),
  );
}
```

### What happens automatically (new behavior):

When Shade starts recording, Colossus now:
1. Captures a Tableau (widget tree snapshot) at **recording start**
2. Captures a Tableau after each **pointerUp + settle** (the screen after a tap/gesture)
3. Captures a Tableau when the **route changes**
4. Captures a Tableau at **recording end**
5. Links each Imprint to its active Tableau via `tableauIndex`
6. If `enableScreenCapture: true` was set, also saves a PNG Fresco with each Tableau

**No new widgets. No annotations. No extra configuration. No fieldId requirements.** Everything uses Flutter's existing Element tree, RenderObject bounds, and Semantics tree — data that's already there.

### Optional screenshot — one flag:

```dart
Colossus.init(
  enableScreenCapture: true,  // Optional. Off by default.
);
```

That's it. When enabled, each Tableau automatically includes a `Fresco` (PNG bytes) captured via `RenderRepaintBoundary` or `dart:ui Scene.toImage()`.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  ENHANCED SHADE SESSION                       │
│                                                               │
│  ShadeSession                                                 │
│  ├── imprints: List<Imprint>      (existing — unchanged)     │
│  ├── tableaux: List<Tableau>      (NEW — auto-captured)      │
│  │   ├── Tableau #0 (at recording start)                     │
│  │   │   ├── route: "/cart"                                  │
│  │   │   ├── glyphs: [Glyph, Glyph, Glyph, ...]            │
│  │   │   │   ├── Glyph: ElevatedButton "Checkout" (180,640) │
│  │   │   │   ├── Glyph: Text "3 items in cart"              │
│  │   │   │   ├── Glyph: IconButton "Remove" (320,180)       │
│  │   │   │   └── ...                                         │
│  │   │   └── fresco: Uint8List? (optional PNG screenshot)    │
│  │   │                                                       │
│  │   ├── Tableau #1 (after tap + settle)                     │
│  │   │   ├── route: "/checkout"                              │
│  │   │   ├── glyphs: [...]                                   │
│  │   │   └── fresco: Uint8List?                              │
│  │   └── ...                                                 │
│  │                                                            │
│  └── Each Imprint now has:                                    │
│      └── tableauIndex: int? → points to active Tableau       │
│                                                               │
│  AI can read the session and see:                             │
│  "User tapped 'Checkout' button → navigated to /checkout     │
│   → filled 'Address' field → tapped 'Place Order'"           │
└───────────────────────────────────────────────────────────────┘
```

---

## Data Models

### Glyph — A Single UI Element

```dart
/// **Glyph** — a carved symbol describing one UI element on screen.
///
/// Contains everything an AI agent needs to understand what
/// this element is, where it is, what it does, and what it says.
///
/// Glyphs are captured automatically by Colossus during Shade
/// recording — no developer annotations required.
class Glyph {
  /// Widget runtime type: 'ElevatedButton', 'TextField', 'Text', etc.
  final String widgetType;

  /// Human-readable label extracted automatically:
  /// - Buttons → child text ("Submit Order")
  /// - Text fields → hint text or label ("Enter address")
  /// - Text → the displayed text (truncated to 100 chars)
  /// - Icons → tooltip or semantic label
  /// - Images → semantic label
  final String? label;

  /// Bounding box in logical pixels.
  final double left;
  final double top;
  final double width;
  final double height;

  /// Center point (convenience for AI coordinate matching).
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  /// Whether this element accepts user interaction.
  final bool isInteractive;

  /// Interaction type: 'tap', 'longPress', 'textInput', 'scroll',
  /// 'toggle', 'slider', 'dropdown', 'checkbox', 'radio', 'switch'.
  final String? interactionType;

  /// ShadeTextController field ID (if applicable).
  /// Links this Glyph to Shade's text recording automatically.
  final String? fieldId;

  /// Widget key (if set by developer).
  final String? key;

  /// Semantic role from Flutter's Semantics tree:
  /// 'button', 'textField', 'header', 'image', 'link', etc.
  final String? semanticRole;

  /// Current enabled state.
  final bool isEnabled;

  /// Current value for stateful widgets:
  /// Checkboxes → "true"/"false", Sliders → "0.75", etc.
  final String? currentValue;

  /// Nearest 5 ancestor widget types (for context).
  /// Example: ['Scaffold', 'Column', 'Card', 'Row', 'Padding']
  final List<String> ancestors;

  /// Tree depth (for z-ordering in hit-test resolution).
  final int depth;

  /// Serialization (compact keys matching Imprint style).
  Map<String, dynamic> toMap() => { /* ... */ };
  factory Glyph.fromMap(Map<String, dynamic> map) => /* ... */;
}
```

### Tableau — A Complete Screen Snapshot

```dart
/// **Tableau** — a frozen scene capturing every visible Glyph.
///
/// Captured automatically by Colossus at key moments during
/// recording. The AI reads Tableaux to understand what the user
/// saw at each step of the flow.
class Tableau {
  /// Index within the session's Tableau list.
  final int index;

  /// Time since recording start.
  final Duration timestamp;

  /// Route path at capture time.
  final String? route;

  /// Screen dimensions.
  final double screenWidth;
  final double screenHeight;

  /// All visible Glyphs, ordered by depth (frontmost first).
  final List<Glyph> glyphs;

  /// The Imprint index that triggered this capture.
  /// -1 for the initial Tableau (recording start).
  final int triggerImprintIndex;

  /// Optional PNG screenshot bytes (only when enableScreenCapture is on).
  final Uint8List? fresco;

  /// Auto-generated summary for AI consumption.
  ///
  /// Example: "Cart page with 3 items, 'Proceed to Checkout' button,
  /// total showing $117.97"
  String get summary => _generateSummary();

  /// Compute differences from a previous Tableau.
  ///
  /// Returns a human-readable diff:
  /// "ADDED: Dialog 'Confirm Order', REMOVED: Text '3 items',
  ///  CHANGED: ElevatedButton 'Place Order' disabled → enabled"
  TableauDiff diff(Tableau previous) => /* ... */;

  /// Find the Glyph at a given position (hit-test).
  ///
  /// Used to resolve "what did the user tap?" from Imprint coordinates.
  Glyph? glyphAt(double x, double y) {
    for (final glyph in glyphs) {
      if (x >= glyph.left && x <= glyph.left + glyph.width &&
          y >= glyph.top && y <= glyph.top + glyph.height &&
          glyph.isInteractive) {
        return glyph;
      }
    }
    return null;
  }

  /// Serialization.
  Map<String, dynamic> toMap() => { /* ... */ };
  factory Tableau.fromMap(Map<String, dynamic> map) => /* ... */;
}
```

### Fresco — Screenshot Capture (Internal)

```dart
/// **Fresco** — captures a PNG screenshot of the current screen.
///
/// Used internally by Colossus when `enableScreenCapture` is true.
/// Not a public API — developers never interact with this directly.
///
/// Captures via `dart:ui`'s `Scene.toImage()` or
/// `RenderRepaintBoundary.toImage()`, whichever is available.
class Fresco {
  /// Capture the current screen as PNG bytes.
  ///
  /// Returns null if capture fails (e.g., no render boundary).
  static Future<Uint8List?> capture({
    double pixelRatio = 1.0,
  }) async {
    try {
      final boundary = _findRepaintBoundary();
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(
        format: ImageByteFormat.png,
      );
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null; // Fail silently — screenshots are optional
    }
  }

  /// Find the root RenderRepaintBoundary.
  static RenderRepaintBoundary? _findRepaintBoundary() {
    final renderObject = WidgetsBinding
        .instance.rootElement?.renderObject;
    if (renderObject is RenderRepaintBoundary) return renderObject;
    // Walk down to find the first boundary
    RenderRepaintBoundary? result;
    renderObject?.visitChildren((child) {
      if (result != null) return;
      if (child is RenderRepaintBoundary) result = child;
    });
    return result;
  }
}
```

### Enhanced ShadeSession (backward-compatible additions)

```dart
class ShadeSession {
  // ... all existing fields unchanged ...

  /// Screen snapshots captured during recording.
  /// Empty for sessions recorded before this feature.
  final List<Tableau> tableaux;

  /// Generate a natural-language flow description for AI agents.
  String generateFlowDescription() { /* ... */ }

  /// Export as structured JSON optimized for AI agent consumption.
  Map<String, dynamic> toAiTestSpec() { /* ... */ }
}
```

### Enhanced Imprint (one new nullable field)

```dart
class Imprint {
  // ... all existing fields unchanged ...

  /// Index into ShadeSession.tableaux — the screen state when
  /// this event occurred. Null for old sessions.
  final int? tableauIndex;
}
```

---

## How It Works — Internal Flow (Zero Developer Code)

### During Recording

```
Developer calls: shade.startRecording(name: 'checkout_flow')

Colossus automatically:
  1. Captures Tableau #0 (initial screen state)
     → Walks Element tree, extracts Glyphs
     → If enableScreenCapture: captures Fresco (PNG)
     → Sets current tableauIndex = 0

User taps a button → Shade records Imprint with tableauIndex: 0

  2. On pointerUp:
     → Waits for settle (reuses Phantom's settle logic)
     → Captures Tableau #1 (post-interaction state)
     → If route changed: notes the transition
     → Updates current tableauIndex = 1
     → If enableScreenCapture: captures Fresco

User types in a text field → Shade records Imprint with tableauIndex: 1

  3. On text input settle (debounced):
     → Captures Tableau #2 if screen changed meaningfully
     → Updates current tableauIndex = 2

Developer calls: shade.stopRecording()

Colossus automatically:
  4. Captures final Tableau
  5. Bundles everything into ShadeSession:
     → imprints: [Imprint, Imprint, ...] (existing)
     → tableaux: [Tableau, Tableau, ...] (NEW)
  6. Session is ready for save/export/AI analysis
```

### Capture Trigger Rules

| Trigger | When | Why |
|---|---|---|
| Recording start | `shade.startRecording()` | Baseline screen state |
| After pointerUp + settle | Each tap/gesture completes | Shows what changed from the interaction |
| Route change detected | `getCurrentRoute()` returns new value | Captures the new page layout |
| Recording end | `shade.stopRecording()` | Final screen state |
| **NOT** on every frame | — | Too expensive, unnecessary |
| **NOT** on pointerMove | — | Screen doesn't change during drags |

### Deduplication

If a captured Tableau is structurally identical to the previous one (same Glyphs, same positions, same values), Colossus skips it and reuses the previous index. This prevents session bloat from meaningless captures (e.g., user taps a button that triggers no visible change).

---

## Glyph Extraction — Widget Classification

The tree walker automatically classifies widgets:

### Always Captured (Interactive)

```
ElevatedButton, TextButton, OutlinedButton, FilledButton,
IconButton, FloatingActionButton, InkWell, GestureDetector,
TextField, TextFormField, Checkbox, Radio, Switch, Slider,
DropdownButton, PopupMenuButton, BottomNavigationBar, TabBar,
ListTile, NavigationBar, NavigationRail, SearchBar, DatePicker,
SegmentedButton, MenuAnchor, Autocomplete
```

### Always Captured (Visible Content)

```
Text, RichText, Image, Icon, AppBar, Card, Dialog, AlertDialog,
SnackBar, BottomSheet, Chip, Badge, Banner, Tooltip, Drawer,
CircularProgressIndicator, LinearProgressIndicator
```

### Skipped (Layout Noise)

```
Container, Padding, SizedBox, Row, Column, Stack, Expanded,
Flexible, Center, Align, Positioned, Builder, LayoutBuilder,
MediaQuery, Theme, Material, Scaffold (body only)
```

### Label Extraction Strategy (Automatic, No Annotations)

| Widget Type | Label Source | Example |
|---|---|---|
| `ElevatedButton` | Child `Text` widget | "Submit Order" |
| `IconButton` | `tooltip` property | "Delete" |
| `TextField` | `decoration.hintText` or `decoration.labelText` | "Enter email" |
| `Text` | `data` property (truncated 100 chars) | "Total: $117.97" |
| `AppBar` | Title `Text` widget | "Shopping Cart" |
| `ListTile` | Title `Text` widget | "Wireless Headphones" |
| `Checkbox` | Nearest `Text` sibling or Semantics label | "Remember me" |
| `Image` | `semanticLabel` or `tooltip` | "Product photo" |
| `Icon` | `semanticLabel` or parent `tooltip` | "check_circle" |
| Any widget | Fall back to `Semantics.label` | (accessibility label) |

---

## Screenshot Capture (Fresco) — Optional

### Why Optional by Default

| Concern | Decision |
|---|---|
| **Privacy** | Screenshots may contain PII (names, addresses, payment info). Off by default. |
| **File size** | A single PNG at 1x can be 50-200KB. 10 Tableaux = 0.5-2MB per session. |
| **Performance** | `toImage()` is async and takes 5-15ms. Acceptable, but not free. |
| **AI doesn't need it** | Glyph data alone is sufficient for AI to understand the flow. Screenshots are for human reviewers. |

### When Screenshots Are Useful

- **Bug reports** — Attach the session + screenshots to a ticket. QA sees exactly what the user saw.
- **Visual regression** — Compare screenshots from two sessions of the same flow.
- **AI with vision** — Future AI models that can analyze images alongside structured data.
- **Stakeholder demos** — Show non-technical stakeholders the exact flow that was tested.

### Enabling Screenshots

```dart
Colossus.init(
  enableScreenCapture: true,        // Enable Fresco capture
  screenCapturePixelRatio: 0.5,     // Half resolution (saves space)
);
```

### Storage

When saved via `ShadeVault`, Frescos are stored as separate PNG files to keep session JSON lean:

```
shade_sessions/
├── checkout_flow_12345.shade.json     (session data + Glyphs)
├── checkout_flow_12345_t0.png         (Tableau #0 screenshot)
├── checkout_flow_12345_t1.png         (Tableau #1 screenshot)
└── checkout_flow_12345_t2.png         (Tableau #2 screenshot)
```

---

## The AI Agent Workflow

### Step 1: Human Records a Flow (Existing Code — No Changes)

```dart
Colossus.instance.shade.startRecording(name: 'checkout_flow');
// ... user interacts with the app ...
final session = Colossus.instance.shade.stopRecording();
await Colossus.instance.saveSession(session);
```

### Step 2: AI Reads the Session

```dart
final session = await Colossus.instance.loadSession('checkout_flow_xxx');
final description = session!.generateFlowDescription();
print(description);
```

Output the AI reads:

```
Session: checkout_flow (12.4s, 23 events, 5 tableaux)
Start Route: /cart

═══ Tableau #0 — Initial Screen ═══
Route: /cart
  AppBar: "Shopping Cart"
  Text: "3 items in cart"
  ListTile: "Wireless Headphones — $79.99" [IconButton: "Remove"]
  ListTile: "USB-C Cable — $12.99" [IconButton: "Remove"]
  ListTile: "Phone Case — $24.99" [IconButton: "Remove"]
  Text: "Total: $117.97"
  ElevatedButton: "Proceed to Checkout" [enabled]

═══ Step 1 [1.2s]: Tap ═══
Target: IconButton "Remove" at (320, 180)

═══ Tableau #1 — After Remove ═══
Route: /cart
  REMOVED: ListTile "Wireless Headphones — $79.99"
  CHANGED: Text "3 items in cart" → "2 items in cart"
  CHANGED: Text "Total: $117.97" → "Total: $37.98"

═══ Step 2 [3.4s]: Tap ═══
Target: ElevatedButton "Proceed to Checkout" at (187, 640)

═══ Tableau #2 — New Page ═══
Route: /checkout (was /cart)
  AppBar: "Checkout"
  TextField: "Street Address" (hint: "Enter your address")
  TextField: "City" (hint: "City")
  TextField: "Zip Code" (hint: "ZIP")
  Text: "Order Total: $37.98"
  ElevatedButton: "Place Order" [disabled]

═══ Step 3-5 [5.1s-8.2s]: Text Input ═══
  "Street Address" ← "123 Main St"
  "City" ← "San Francisco"
  "Zip Code" ← "94102"

═══ Tableau #3 — Form Filled ═══
  CHANGED: ElevatedButton "Place Order" disabled → enabled

═══ Step 6 [10.1s]: Tap ═══
Target: ElevatedButton "Place Order" at (187, 720)

═══ Tableau #4 — Final Screen ═══
Route: /order-confirmation (was /checkout)
  AppBar: "Order Confirmed"
  Icon: check_circle
  Text: "Order #12345"
  Text: "Thank you for your purchase!"
  ElevatedButton: "Continue Shopping" [enabled]
```

### Step 3: AI Generates Tests

From the flow description, the AI generates a complete widget test:

```dart
testWidgets('checkout flow removes items, fills form, completes order',
    (tester) async {
  await tester.pumpWidget(app);
  atlas.go('/cart');
  await tester.pumpAndSettle();

  // Verify initial state (Tableau #0)
  expect(find.text('3 items in cart'), findsOneWidget);
  expect(find.text('Total: \$117.97'), findsOneWidget);

  // Step 1: Remove first item
  await tester.tap(find.byTooltip('Remove').first);
  await tester.pumpAndSettle();
  expect(find.text('2 items in cart'), findsOneWidget);
  expect(find.text('Total: \$37.98'), findsOneWidget);

  // Step 2: Proceed to checkout
  await tester.tap(find.text('Proceed to Checkout'));
  await tester.pumpAndSettle();
  expect(find.text('Checkout'), findsOneWidget);

  // Steps 3-5: Fill form
  await tester.enterText(
    find.widgetWithText(TextField, 'Enter your address'), '123 Main St');
  await tester.enterText(
    find.widgetWithText(TextField, 'City'), 'San Francisco');
  await tester.enterText(
    find.widgetWithText(TextField, 'ZIP'), '94102');
  await tester.pumpAndSettle();

  // Step 6: Place order
  await tester.tap(find.text('Place Order'));
  await tester.pumpAndSettle();

  // Verify confirmation (Tableau #4)
  expect(find.text('Order Confirmed'), findsOneWidget);
  expect(find.textContaining('Order #'), findsOneWidget);
});
```

### Step 4: AI Replays + Performance Report

```dart
final result = await Colossus.instance.replaySession(session!);
final decree = Colossus.instance.decree();
// AI: "FPS dropped to 42 during cart→checkout transition.
// Tableau shows 12 widgets building simultaneously."
```

---

## Colossus API Changes

### New `init()` Parameters (All Optional)

```dart
Colossus.init(
  // ... all existing params unchanged ...

  // Tableau capture (on by default — zero-config)
  enableTableauCapture: true,        // Default: true
  tableauCaptureDepthLimit: 50,      // Max tree depth
  tableauGlyphLimit: 200,            // Max Glyphs per Tableau

  // Screenshot capture (off by default — opt-in)
  enableScreenCapture: false,        // Default: false
  screenCapturePixelRatio: 1.0,      // Resolution multiplier

  // Stratagem execution (always available — no config needed)
  stratagemStepTimeout: Duration(seconds: 5),  // Default per-step timeout
  stratagemVerdictDirectory: 'verdicts/',       // Where Verdicts are saved
);
```

### Shade Changes (All Internal — Developer Sees Nothing)

Shade now auto-captures Tableaux during recording. The `startRecording`, `recordPointerEvent`, and `stopRecording` methods gain internal Tableau capture calls. No API signature changes. No new developer-facing methods.

---

## Stratagem — The AI-Generated Test Blueprint

> *"Tell the AI what to test. The Colossus executes the battle plan."*

### The Problem Stratagem Solves

Glyph + Tableau lets AI **read** what happened. But the bigger prize is letting AI **write** what should happen and having Colossus **execute** it:

```
Today:     Human tester → manually clicks through app → writes bug report
Tomorrow:  AI → writes Stratagem → Colossus executes → Verdict report → AI reads & iterates
```

**The goal: eliminate the need for human testers for flow testing.**

### What Is a Stratagem?

A **Stratagem** is a structured, machine-readable test blueprint. It describes:

1. **Where to start** — the initial route
2. **What to do** — ordered steps (tap, type, scroll, swipe, wait, navigate)
3. **How to find targets** — by label, widget type, semantic role, or key (NOT coordinates)
4. **What to expect** — expected route, elements present/absent, values, enabled states
5. **How to handle failure** — timeout, retry, abort on first failure or continue

### Why Label-Based Targeting Matters

This is the critical difference from Phantom replay:

| | Phantom (Coordinate-Based) | Stratagem (Glyph-Based) |
|---|---|---|
| Targeting | `(187.5, 642.0)` | `"Login" button` |
| Layout change resilience | Breaks if button moves | Works — finds by label |
| Device independence | Breaks on different screen sizes | Works — resolution-independent |
| AI-writeable | No — AI doesn't know coordinates | Yes — AI knows labels |
| Human-readable | No | Yes |
| Self-healing | No | Can adapt if label text changes slightly |

Stratagem uses the **Glyph system** to find elements. When executing a step that says "tap the Login button", Colossus:
1. Captures a Tableau (live screen snapshot)
2. Searches Glyphs for `label: "Login", type: button`
3. Gets the Glyph's center coordinates
4. Dispatches a synthetic pointer event at those coordinates
5. Waits for settle
6. Validates the expectations

### Stratagem Template — What AI Must Follow

Colossus provides a standardized JSON schema. AI reads this template, understands the app's routes and UI, and generates a valid Stratagem:

```json
{
  "$schema": "titan://stratagem/v1",
  "name": "login_flow_happy_path",
  "description": "Test standard login flow with valid credentials",
  "tags": ["auth", "login", "critical-path"],
  "startRoute": "/login",
  "preconditions": {
    "authenticated": false,
    "notes": "User must be logged out before starting"
  },
  "testData": {
    "email": "test@example.com",
    "password": "SecurePass123!"
  },
  "timeout": 30000,
  "failurePolicy": "abort-on-first",
  "steps": [
    {
      "id": 1,
      "action": "verify",
      "description": "Verify login page is displayed",
      "expectations": {
        "route": "/login",
        "elementsPresent": [
          {"label": "Email", "type": "TextField"},
          {"label": "Password", "type": "TextField"},
          {"label": "Login", "type": "ElevatedButton"}
        ],
        "elementsAbsent": [
          {"label": "Dashboard"}
        ]
      }
    },
    {
      "id": 2,
      "action": "enterText",
      "description": "Enter email address",
      "target": {"label": "Email", "type": "TextField"},
      "value": "${testData.email}",
      "clearFirst": true
    },
    {
      "id": 3,
      "action": "enterText",
      "description": "Enter password",
      "target": {"label": "Password", "type": "TextField"},
      "value": "${testData.password}",
      "clearFirst": true
    },
    {
      "id": 4,
      "action": "verify",
      "description": "Verify login button is enabled after form fill",
      "expectations": {
        "elementStates": [
          {"label": "Login", "type": "ElevatedButton", "enabled": true}
        ]
      }
    },
    {
      "id": 5,
      "action": "tap",
      "description": "Tap login button",
      "target": {"label": "Login", "type": "ElevatedButton"},
      "waitAfter": 3000
    },
    {
      "id": 6,
      "action": "verify",
      "description": "Verify navigation to dashboard",
      "expectations": {
        "route": "/dashboard",
        "elementsPresent": [
          {"label": "Welcome"},
          {"label": "Dashboard"}
        ]
      }
    }
  ]
}
```

### Stratagem Data Model

```dart
/// **Stratagem** — an AI-generated test blueprint.
///
/// Contains ordered steps that Colossus executes autonomously
/// against the live app. Steps use Glyph-based targeting (labels,
/// types, semantic roles) instead of coordinates.
///
/// AI generates Stratagems from natural language instructions
/// like "test the login flow" using the Stratagem template schema.
class Stratagem {
  /// Unique name for this test plan.
  final String name;

  /// Human-readable description.
  final String description;

  /// Tags for categorization.
  final List<String> tags;

  /// Starting route — Colossus navigates here first.
  final String startRoute;

  /// Preconditions (informational + optional setup).
  final Map<String, dynamic>? preconditions;

  /// Test data available to steps via ${testData.key} references.
  final Map<String, dynamic>? testData;

  /// Ordered list of steps to execute.
  final List<StratagemStep> steps;

  /// Maximum total execution time.
  final Duration timeout;

  /// How to handle step failures.
  final StratagemFailurePolicy failurePolicy;

  /// Load from JSON (AI writes this).
  factory Stratagem.fromJson(Map<String, dynamic> json) => /* ... */;

  /// Serialize to JSON.
  Map<String, dynamic> toJson() => /* ... */;

  /// Load from a .stratagem.json file.
  static Future<Stratagem> loadFile(String path) async => /* ... */;

  /// Get the schema template (for AI to read).
  static Map<String, dynamic> get template => /* ... */;

  /// Get the schema as natural language (for AI prompt).
  static String get templateDescription => '''
Write a Stratagem JSON following this structure:
- name: short identifier
- description: what this test verifies
- startRoute: initial page route
- steps: ordered list of actions
  - action: "tap" | "enterText" | "scroll" | "swipe" | "longPress"
           | "navigate" | "wait" | "verify" | "back"
  - target: {label: "button text", type: "ElevatedButton"}
  - value: text to enter (for enterText)
  - expectations: {route: "/path", elementsPresent: [...], elementsAbsent: [...]}
Target elements by their visible label and widget type, never by coordinates.
''';
}

/// A single step in a Stratagem.
class StratagemStep {
  final int id;
  final StratagemAction action;
  final String description;
  final StratagemTarget? target;

  // --- Text Input ---
  final String? value;            // Text to enter, dropdown item, date, slider value
  final bool? clearFirst;         // Clear field before entering text
  final int? cursorPosition;      // Set cursor at this position after entering

  // --- Expectations ---
  final StratagemExpectations? expectations;
  final Duration? waitAfter;      // Wait after action

  // --- Scroll ---
  final Offset? scrollDelta;      // Scroll direction + distance
  final int? repeatCount;         // Max scroll attempts for scrollUntilVisible

  // --- Swipe / Drag ---
  final String? swipeDirection;   // 'left', 'right', 'up', 'down'
  final double? swipeDistance;    // Pixels to swipe
  final Offset? dragFrom;         // Drag start point
  final Offset? dragTo;           // Drag end point

  // --- Navigation ---
  final String? navigateRoute;    // Route for navigate action

  // --- Slider ---
  final Map<String, double>? sliderRange;  // {min: 0, max: 100}

  // --- Key ---
  final String? keyId;            // Physical key name for pressKey

  // --- Timeout ---
  final Duration? timeout;        // Step-level timeout override
}

/// How to identify a UI element by its Glyph properties.
class StratagemTarget {
  final String? label;          // Match by label text
  final String? type;           // Match by widget type
  final String? semanticRole;   // Match by semantic role
  final String? key;            // Match by widget key
  final int? index;             // Nth match (0-based)
  final String? ancestor;       // Must be descendant of this widget type

  /// Resolve this target against a Tableau.
  /// Returns the matching Glyph or null.
  Glyph? resolve(Tableau tableau) {
    final candidates = tableau.glyphs.where((g) {
      if (label != null && g.label != label) return false;
      if (type != null && !g.widgetType.contains(type!)) return false;
      if (semanticRole != null && g.semanticRole != semanticRole) return false;
      if (key != null && g.key != key) return false;
      if (ancestor != null && !g.ancestors.contains(ancestor)) return false;
      return true;
    }).toList();

    if (candidates.isEmpty) return null;
    return candidates[index ?? 0];
  }

  /// Fuzzy resolve — tries exact match first, then partial label match.
  Glyph? fuzzyResolve(Tableau tableau) {
    // Try exact match first
    final exact = resolve(tableau);
    if (exact != null) return exact;

    // Try partial label match (label contains or contained in)
    if (label != null) {
      final partial = tableau.glyphs.where((g) {
        if (g.label == null) return false;
        final normalizedTarget = label!.toLowerCase();
        final normalizedLabel = g.label!.toLowerCase();
        return normalizedLabel.contains(normalizedTarget) ||
               normalizedTarget.contains(normalizedLabel);
      }).toList();
      if (partial.isNotEmpty) return partial[index ?? 0];
    }

    return null;
  }
}

/// Expected state after a step.
class StratagemExpectations {
  final String? route;
  final List<StratagemTarget>? elementsPresent;
  final List<StratagemTarget>? elementsAbsent;
  final List<StratagemElementState>? elementStates;
  final Duration? settleTimeout;
}

/// Expected state of a specific element.
class StratagemElementState {
  final String label;
  final String? type;
  final bool? enabled;
  final String? value;
  final bool? visible;
}

/// Actions a Stratagem step can perform.
///
/// Every action Phantom can replay, Stratagem can command —
/// but by label instead of coordinates.
enum StratagemAction {
  // --- Core Interactions ---

  /// Tap an element (pointerDown → pointerUp at center).
  tap,

  /// Long-press an element (~500ms hold).
  longPress,

  /// Double-tap an element (two rapid taps).
  doubleTap,

  // --- Text Input ---

  /// Enter text into a TextField/TextFormField.
  /// Taps the field to focus, then injects text via
  /// ShadeTextController.setValueSilently() (same as Phantom).
  /// Supports clearFirst, selection positioning.
  enterText,

  /// Clear a text field completely.
  clearText,

  /// Submit the current text field (TextInputAction.done/next/go).
  /// Equivalent to pressing the keyboard action button.
  submitField,

  // --- Scroll & Swipe ---

  /// Scroll by a delta (pixels). Uses PointerScrollEvent.
  /// Can scroll vertically or horizontally.
  scroll,

  /// Scroll until an element becomes visible.
  /// Repeatedly scrolls and captures Tableau to find the target.
  scrollUntilVisible,

  /// Swipe gesture — drag from element center in a direction.
  /// Useful for dismissible items, swipe-to-delete, carousels.
  swipe,

  /// Drag from point A to point B (relative or element-based).
  drag,

  // --- Toggle & Selection ---

  /// Toggle a Switch widget.
  /// Finds by label, taps its center.
  toggleSwitch,

  /// Tap a Checkbox to toggle it.
  /// Finds by label, taps.
  toggleCheckbox,

  /// Select a Radio button.
  /// Finds by label, taps.
  selectRadio,

  /// Adjust a Slider to a specific value.
  /// Finds the slider, calculates position for target value,
  /// dispatches drag from current to target.
  adjustSlider,

  /// Select from a DropdownButton.
  /// Taps the dropdown to open, then taps the menu item by label.
  selectDropdown,

  /// Select a date from DatePicker.
  /// Taps the date field, then navigates the picker.
  selectDate,

  /// Select a SegmentedButton option.
  selectSegment,

  // --- Navigation ---

  /// Programmatic navigation (Atlas.go/push).
  navigate,

  /// Navigation back (pop).
  back,

  // --- Waiting ---

  /// Wait for a fixed duration.
  wait,

  /// Wait until an element appears on screen.
  /// Polls Tableau captures until target is found.
  waitForElement,

  /// Wait until an element disappears (e.g., loading spinner).
  waitForElementGone,

  // --- Verification ---

  /// Verify expectations without performing any action.
  verify,

  // --- Keyboard ---

  /// Dismiss the soft keyboard.
  dismissKeyboard,

  /// Type a physical key (for desktop/web).
  pressKey,
}

/// How to handle failures during execution.
enum StratagemFailurePolicy {
  /// Stop execution on first failure.
  abortOnFirst,
  /// Continue executing remaining steps.
  continueAll,
  /// Continue but skip steps that depend on failed steps.
  skipDependents,
}
```

---

## Comprehensive Input Support — What Stratagem Can Do

Stratagem inherits and extends every input capability Phantom has, but with **label-based targeting** instead of coordinates:

### Text Input (Login, Registration, Forms)

```json
{
  "id": 1,
  "action": "enterText",
  "description": "Enter username",
  "target": {"label": "Username", "type": "TextField"},
  "value": "john.doe@example.com",
  "clearFirst": true
}
```

**How it works internally:**
1. Capture Tableau → find Glyph matching `label: "Username", type: TextField`
2. Dispatch `pointerDown` + `pointerUp` at Glyph center (focuses the field)
3. Wait 100ms for keyboard to appear
4. Find the `ShadeTextController` for that field (via Glyph's `fieldId` or focused field detection — same as Phantom's `_tryInjectIntoFocusedField`)
5. Call `controller.setValueSilently(TextEditingValue(text: "john.doe@example.com"))` — bypasses keyboard entirely
6. Wait for settle

**Supports:**
- **clearFirst**: Clears existing text before entering new text
- **Selection positioning**: Can set cursor position
- **Obscured fields**: Works with password fields (obscureText: true) — same as Phantom
- **Multi-line**: Works with scrollable text areas
- **Form submit**: `submitField` action triggers `TextInputAction.done` / `.next` / `.go`

### Scrollable Forms

```json
[
  {
    "id": 1,
    "action": "scrollUntilVisible",
    "description": "Scroll down to the Terms checkbox",
    "target": {"label": "I agree to Terms"},
    "scrollDelta": {"dx": 0, "dy": -300},
    "maxScrollAttempts": 10
  },
  {
    "id": 2,
    "action": "toggleCheckbox",
    "description": "Accept terms",
    "target": {"label": "I agree to Terms"}
  }
]
```

**How `scrollUntilVisible` works:**
1. Capture Tableau → search for target Glyph
2. If not found: dispatch `PointerScrollEvent` with `scrollDelta`
3. Wait for settle → capture new Tableau → search again
4. Repeat up to `maxScrollAttempts` times
5. If found: succeed. If not: fail with `VerdictFailureType.targetNotFound`

### Checkboxes

```json
{
  "id": 5,
  "action": "toggleCheckbox",
  "description": "Check 'Remember me'",
  "target": {"label": "Remember me"},
  "expectations": {"elementStates": [{"label": "Remember me", "value": "true"}]}
}
```

### Switches / Toggles

```json
{
  "id": 3,
  "action": "toggleSwitch",
  "description": "Enable dark mode",
  "target": {"label": "Dark Mode", "type": "Switch"}
}
```

### Dropdown Selection

```json
{
  "id": 4,
  "action": "selectDropdown",
  "description": "Select country",
  "target": {"label": "Country", "type": "DropdownButton"},
  "value": "United States"
}
```

**How it works:**
1. Find Glyph for the DropdownButton by label
2. Dispatch tap at its center → opens dropdown overlay
3. Wait for settle → capture new Tableau (now includes the dropdown menu items)
4. Find the Glyph matching `value: "United States"` in the dropdown overlay
5. Dispatch tap at the matching item's center
6. Wait for settle → dropdown closes

### Radio Buttons

```json
{
  "id": 6,
  "action": "selectRadio",
  "description": "Select payment method",
  "target": {"label": "Credit Card", "type": "Radio"}
}
```

### Slider Adjustment

```json
{
  "id": 7,
  "action": "adjustSlider",
  "description": "Set quantity to 5",
  "target": {"label": "Quantity", "type": "Slider"},
  "value": "5",
  "sliderRange": {"min": 1, "max": 10}
}
```

**How it works:**
1. Find Slider Glyph → get its bounds (left, width)
2. Calculate target X position: `left + width * ((5 - 1) / (10 - 1))`
3. Dispatch `pointerDown` at current thumb position
4. Dispatch `pointerMove` + `pointerUp` at target X position

### Swipe / Drag

```json
{
  "id": 8,
  "action": "swipe",
  "description": "Dismiss notification",
  "target": {"label": "New message from John", "type": "Dismissible"},
  "swipeDirection": "left",
  "swipeDistance": 300
}
```

### Date Picker

```json
{
  "id": 9,
  "action": "selectDate",
  "description": "Select departure date",
  "target": {"label": "Departure Date"},
  "value": "2025-03-15"
}
```

**How it works:**
1. Tap the date field → opens DatePicker dialog
2. Navigate month/year if needed (tap forward/back arrows)
3. Find and tap the target day
4. Tap "OK" / confirm button

### Segmented Button / Tab Selection

```json
{
  "id": 10,
  "action": "selectSegment",
  "description": "Switch to list view",
  "target": {"label": "List", "type": "SegmentedButton"}
}
```

### Physical Key Events (Desktop / Web)

```json
{
  "id": 11,
  "action": "pressKey",
  "description": "Press Enter to submit",
  "keyId": "Enter"
}
```

### Wait for Element

```json
{
  "id": 12,
  "action": "waitForElement",
  "description": "Wait for loading to finish",
  "target": {"label": "Welcome Dashboard"},
  "timeout": 10000
}
```

```json
{
  "id": 13,
  "action": "waitForElementGone",
  "description": "Wait for spinner to disappear",
  "target": {"type": "CircularProgressIndicator"},
  "timeout": 15000
}
```

### Complete Login Form Example

```json
{
  "$schema": "titan://stratagem/v1",
  "name": "login_complete",
  "description": "Login with all form elements — username, password, remember me, submit",
  "startRoute": "/login",
  "testData": {
    "username": "admin@company.com",
    "password": "SecureP@ss2025!"
  },
  "timeout": 30000,
  "failurePolicy": "abort-on-first",
  "steps": [
    {
      "id": 1,
      "action": "verify",
      "description": "Login page loaded",
      "expectations": {
        "route": "/login",
        "elementsPresent": [
          {"label": "Email", "type": "TextField"},
          {"label": "Password", "type": "TextField"},
          {"label": "Remember me", "type": "Checkbox"},
          {"label": "Login", "type": "ElevatedButton"}
        ]
      }
    },
    {
      "id": 2,
      "action": "enterText",
      "description": "Enter email",
      "target": {"label": "Email", "type": "TextField"},
      "value": "${testData.username}",
      "clearFirst": true
    },
    {
      "id": 3,
      "action": "enterText",
      "description": "Enter password",
      "target": {"label": "Password", "type": "TextField"},
      "value": "${testData.password}",
      "clearFirst": true
    },
    {
      "id": 4,
      "action": "toggleCheckbox",
      "description": "Check remember me",
      "target": {"label": "Remember me"}
    },
    {
      "id": 5,
      "action": "tap",
      "description": "Tap login button",
      "target": {"label": "Login", "type": "ElevatedButton"}
    },
    {
      "id": 6,
      "action": "waitForElement",
      "description": "Wait for dashboard to load",
      "target": {"label": "Dashboard"},
      "timeout": 10000
    },
    {
      "id": 7,
      "action": "verify",
      "description": "Dashboard loaded successfully",
      "expectations": {
        "route": "/dashboard",
        "elementsPresent": [
          {"label": "Dashboard"},
          {"label": "Welcome"}
        ],
        "elementsAbsent": [
          {"label": "Login"}
        ]
      }
    }
  ]
}
```

### Complete Registration Form with Scrollable Fields

```json
{
  "name": "registration_full_form",
  "description": "Registration with scrollable form, dropdowns, checkboxes, all field types",
  "startRoute": "/register",
  "testData": {
    "firstName": "Jane",
    "lastName": "Doe",
    "email": "jane.doe@example.com",
    "password": "Str0ng!Pass",
    "phone": "+1-555-0123",
    "country": "United States",
    "birthDate": "1990-06-15"
  },
  "steps": [
    {"id": 1, "action": "enterText", "target": {"label": "First Name"}, "value": "${testData.firstName}"},
    {"id": 2, "action": "enterText", "target": {"label": "Last Name"}, "value": "${testData.lastName}"},
    {"id": 3, "action": "enterText", "target": {"label": "Email"}, "value": "${testData.email}"},
    {"id": 4, "action": "enterText", "target": {"label": "Password"}, "value": "${testData.password}"},
    {"id": 5, "action": "enterText", "target": {"label": "Confirm Password"}, "value": "${testData.password}"},
    {"id": 6, "action": "enterText", "target": {"label": "Phone"}, "value": "${testData.phone}"},
    {"id": 7, "action": "dismissKeyboard", "description": "Dismiss keyboard before scrolling"},
    {"id": 8, "action": "scrollUntilVisible", "target": {"label": "Country"}, "scrollDelta": {"dx": 0, "dy": -200}},
    {"id": 9, "action": "selectDropdown", "target": {"label": "Country"}, "value": "${testData.country}"},
    {"id": 10, "action": "scrollUntilVisible", "target": {"label": "Date of Birth"}, "scrollDelta": {"dx": 0, "dy": -200}},
    {"id": 11, "action": "selectDate", "target": {"label": "Date of Birth"}, "value": "${testData.birthDate}"},
    {"id": 12, "action": "scrollUntilVisible", "target": {"label": "Gender"}, "scrollDelta": {"dx": 0, "dy": -200}},
    {"id": 13, "action": "selectRadio", "target": {"label": "Female"}},
    {"id": 14, "action": "scrollUntilVisible", "target": {"label": "Receive newsletter"}, "scrollDelta": {"dx": 0, "dy": -200}},
    {"id": 15, "action": "toggleSwitch", "target": {"label": "Receive newsletter"}},
    {"id": 16, "action": "scrollUntilVisible", "target": {"label": "I agree to Terms"}, "scrollDelta": {"dx": 0, "dy": -200}},
    {"id": 17, "action": "toggleCheckbox", "target": {"label": "I agree to Terms"}},
    {"id": 18, "action": "scrollUntilVisible", "target": {"label": "Create Account"}, "scrollDelta": {"dx": 0, "dy": -200}},
    {"id": 19, "action": "tap", "target": {"label": "Create Account", "type": "ElevatedButton"}},
    {"id": 20, "action": "waitForElement", "target": {"label": "Account Created"}, "timeout": 15000},
    {"id": 21, "action": "verify", "expectations": {"route": "/welcome", "elementsPresent": [{"label": "Account Created"}]}}
  ]
}
```

---

## Supported Interaction Matrix

| Widget Type | Stratagem Action | Phantom Equivalent | How Stratagem Finds It |
|---|---|---|---|
| `ElevatedButton` | `tap` | `pointerDown` + `pointerUp` | label (child Text) |
| `TextButton` | `tap` | `pointerDown` + `pointerUp` | label (child Text) |
| `IconButton` | `tap` | `pointerDown` + `pointerUp` | label (tooltip) |
| `FloatingActionButton` | `tap` | `pointerDown` + `pointerUp` | label (tooltip) |
| `InkWell` / `GestureDetector` | `tap` / `longPress` | pointer events | label (child Text or Semantics) |
| `TextField` / `TextFormField` | `enterText` | `textInput` via ShadeTextController | label (hintText / labelText) |
| `Checkbox` | `toggleCheckbox` | `pointerDown` + `pointerUp` | label (nearest Text / Semantics) |
| `Switch` | `toggleSwitch` | `pointerDown` + `pointerUp` | label (nearest Text / Semantics) |
| `Radio` | `selectRadio` | `pointerDown` + `pointerUp` | label (nearest Text / Semantics) |
| `Slider` | `adjustSlider` | `pointerDown` + `pointerMove` + `pointerUp` | label + slider bounds |
| `DropdownButton` | `selectDropdown` | tap + tap menu item | label + overlay Glyph search |
| `DatePicker` | `selectDate` | multi-tap sequence | label + picker navigation |
| `SegmentedButton` | `selectSegment` | `pointerDown` + `pointerUp` | label (segment text) |
| `TabBar` | `tap` | `pointerDown` + `pointerUp` | label (tab text) |
| `BottomNavigationBar` | `tap` | `pointerDown` + `pointerUp` | label (item label) |
| `ListTile` | `tap` / `longPress` | pointer events | label (title Text) |
| `Dismissible` | `swipe` | pointer drag sequence | label (child content) |
| `PopupMenuButton` | `tap` + `tap` item | pointer events | label (tooltip or Semantics) |
| `Autocomplete` | `enterText` + `tap` suggestion | text + pointer | label + suggestion Glyph |
| `SearchBar` | `enterText` | textInput | label (hintText) |
| `NavigationRail` | `tap` | pointer events | label (item label) |
| Scrollable content | `scroll` / `scrollUntilVisible` | `pointerScroll` | n/a (direction + delta) |
| Any widget | `tap` | pointer events | key, semanticRole, or type |

---

## Known Limitations — What Stratagem Cannot Do

### Cannot Control Native OS UI

| What | Why | Workaround |
|---|---|---|
| **Google Sign-In dialog** | Native Android/iOS dialog — not in Flutter widget tree | Mock the auth service in test mode |
| **Native file picker** | OS-level dialog | Inject the file path programmatically |
| **Native camera UI** | OS camera app | Provide test image via mock |
| **Permission dialogs** | OS-level permission popup | Pre-grant permissions in test app |
| **System notifications** | OS notification center | Not testable from app layer |
| **Biometric auth prompt** | OS Touch ID / Face ID dialog | Mock biometric service |
| **App store rating dialog** | OS dialog | Suppress in test mode |
| **Native share sheet** | OS share dialog | Mock share service |

**Design guideline:** For flows that include native UI, split the Stratagem into segments. Test the Flutter portion before and after the native interaction. Use mock services to bypass native dialogs in test mode.

### Other Limitations

| Limitation | Explanation | Mitigation |
|---|---|---|
| **Animations during scroll** | Stratagem can't reliably interact with widgets that are animating | `scrollUntilVisible` waits for settle before interacting |
| **Canvas-drawn UI** (CustomPaint, charts) | No Glyphs — can't identify elements | Use Semantics annotations on canvas elements |
| **Identical labels** | Multiple buttons with same label | Use `index` (0-based), `key`, or `ancestor` to disambiguate |
| **Dynamic content** | Content that changes every run (timestamps, random data) | Use `fuzzyResolve` or Stratagem `testData` variables |
| **Network-dependent state** | API responses may vary | Provide test data setup in `preconditions` |
| **Platform channels** (hardware, Bluetooth) | Can't simulate hardware | Mock platform channels in test mode |
| **Web-only widgets** (HtmlElementView) | Not in Flutter widget tree | Can't be targeted — test web layer separately |
```

---

## Verdict — The Execution Report

### What Is a Verdict?

A **Verdict** is the complete, structured report produced by Colossus after executing a Stratagem. It contains everything an AI (or human) needs to understand what happened:

- Pass/fail status for every step
- What was expected vs what was found
- API/network errors detected during execution
- Missing elements (target not found on screen)
- Unexpected navigation (wrong route after action)
- Performance metrics (frame rate, settle time, memory)
- Tableaux captured at each step (what the screen actually looked like)
- Optional Frescos (screenshots) at failure points

### Verdict Data Model

```dart
/// **Verdict** — the judgment after executing a Stratagem.
///
/// Contains per-step results, failure details, performance metrics,
/// and captured Tableaux. Serializes to JSON for AI consumption.
class Verdict {
  /// The Stratagem that was executed.
  final String stratagemName;

  /// When execution started.
  final DateTime executedAt;

  /// Total execution time.
  final Duration duration;

  /// Overall pass/fail.
  final bool passed;

  /// Per-step results.
  final List<VerdictStep> steps;

  /// Aggregate failure summary.
  final VerdictSummary summary;

  /// Performance metrics collected during execution.
  final VerdictPerformance performance;

  /// Tableaux captured at each step (screen state evidence).
  final List<Tableau> tableaux;

  /// Serialize to JSON for AI to read.
  Map<String, dynamic> toJson() => /* ... */;

  /// Save to a .verdict.json file.
  Future<void> saveToFile(String directory) async => /* ... */;

  /// Generate a human-readable report.
  String toReport() => /* ... */;

  /// Generate an AI-optimized diagnostic (concise, structured).
  String toAiDiagnostic() => /* ... */;
}

/// Result of executing one Stratagem step.
class VerdictStep {
  /// Step ID from the Stratagem.
  final int stepId;

  /// What this step tried to do.
  final String description;

  /// Pass or fail.
  final VerdictStepStatus status;

  /// Time taken for this step.
  final Duration duration;

  /// The Tableau captured after this step executed.
  final Tableau? tableau;

  /// The Glyph that was resolved as the target (if applicable).
  final Glyph? resolvedTarget;

  /// Failure details (null if passed).
  final VerdictFailure? failure;

  /// Screenshot at this step (if screenshots enabled).
  final Uint8List? fresco;
}

/// Failure details for a step.
class VerdictFailure {
  /// Category of failure.
  final VerdictFailureType type;

  /// Human-readable failure message.
  final String message;

  /// What was expected.
  final String? expected;

  /// What was actually found.
  final String? actual;

  /// Suggestions for fixing (auto-generated).
  final List<String> suggestions;
}

/// Types of failures the Verdict can report.
enum VerdictFailureType {
  /// Target element not found on screen.
  targetNotFound,

  /// Expected element present but missing.
  elementMissing,

  /// Expected element absent but present.
  elementUnexpected,

  /// Navigation went to wrong route.
  wrongRoute,

  /// Element found but in wrong state (disabled when expected enabled, etc.).
  wrongState,

  /// Step timed out waiting for settle.
  timeout,

  /// API/network error detected during step.
  apiError,

  /// Exception thrown during step execution.
  exception,

  /// Element found but not interactive.
  notInteractive,

  /// Page failed to load.
  pageLoadFailure,

  /// Assertion in expectations failed.
  expectationFailed,
}

/// Aggregate summary of all failures.
class VerdictSummary {
  final int totalSteps;
  final int passedSteps;
  final int failedSteps;
  final int skippedSteps;
  final List<String> failedRoutes;
  final List<String> missingElements;
  final List<String> apiErrors;
  final List<String> unexpectedRoutes;
  final double successRate;

  String get oneLiner => passed
      ? '✅ All $totalSteps steps passed in ${duration}ms'
      : '❌ $failedSteps/$totalSteps steps failed: ${missingElements.join(", ")}';
}

/// Performance metrics captured during Stratagem execution.
class VerdictPerformance {
  /// Average FPS during execution.
  final double averageFps;

  /// Minimum FPS (worst frame).
  final double minFps;

  /// Jank frames (>16ms).
  final int jankFrames;

  /// Memory usage at start/end.
  final int startMemoryBytes;
  final int endMemoryBytes;

  /// Settle times per step.
  final Map<int, Duration> settleTimes;

  /// Steps that took longer than expected.
  final List<int> slowSteps;
}

/// Status of a single verdict step.
enum VerdictStepStatus {
  passed,
  failed,
  skipped,
}
```

---

## Stratagem Execution Engine — How Colossus Runs Tests

### The Complete Flow

```
                    ┌─────────────────────────────────┐
                    │   AI or Developer says:          │
                    │   "Test the login flow"          │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   AI reads:                      │
                    │   • Stratagem.templateDescription │
                    │   • App's route map (Atlas)      │
                    │   • Previous sessions/Verdicts   │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   AI writes: login.stratagem.json│
                    │   (structured test blueprint)    │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   Colossus.executeStratagem()    │
                    │                                  │
                    │   For each step:                 │
                    │   1. Capture Tableau              │
                    │   2. Resolve target Glyph         │
                    │   3. Execute action               │
                    │   4. Wait for settle              │
                    │   5. Validate expectations        │
                    │   6. Record VerdictStep           │
                    │   7. Capture Fresco (if enabled)  │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   Verdict saved to:              │
                    │   login_flow.verdict.json         │
                    │   + login_flow_step3.png (fail)   │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │   AI reads the Verdict:          │
                    │   "Step 5 failed: 'Dashboard'    │
                    │    not found on /home. Found      │
                    │    'Home' instead."               │
                    │                                  │
                    │   AI: Updates Stratagem or        │
                    │   reports bug to developer.       │
                    └─────────────────────────────────┘
```

### Execution API

```dart
// === Method 1: Execute from Stratagem object ===
final stratagem = Stratagem.fromJson(jsonDecode(stratagemJson));
final verdict = await Colossus.instance.executeStratagem(stratagem);
print(verdict.toReport());

// === Method 2: Execute from file ===
final verdict = await Colossus.instance.executeStratagemFile(
  'assets/stratagems/login_flow.stratagem.json',
);
await verdict.saveToFile('test_results/');

// === Method 3: Execute multiple (test suite) ===
final verdicts = await Colossus.instance.executeStratagemSuite(
  directory: 'assets/stratagems/',
  parallel: false,  // Sequential by default
  stopOnFirstFailure: false,
);
for (final verdict in verdicts) {
  print('${verdict.stratagemName}: ${verdict.summary.oneLiner}');
}

// === Method 4: AI-in-the-loop (Colossus gives AI context) ===
final context = Colossus.instance.getAiContext();
// Returns: app routes, recent Verdicts, known Glyphs, screen dimensions
// AI uses this to write better Stratagems
```

### Step Execution Detail

For each `StratagemStep`, Colossus executes:

```dart
Future<VerdictStep> _executeStep(StratagemStep step) async {
  final stopwatch = Stopwatch()..start();

  // 1. Capture current screen
  final tableau = await TableauCapture.capture();

  // 2. Resolve target (if action needs one)
  Glyph? target;
  if (step.target != null) {
    target = step.target!.fuzzyResolve(tableau);
    if (target == null) {
      return VerdictStep.failed(
        stepId: step.id,
        failure: VerdictFailure(
          type: VerdictFailureType.targetNotFound,
          message: 'Could not find ${step.target!.label} '
                   '(${step.target!.type}) on screen',
          suggestions: [
            'Elements found: ${tableau.glyphs.map((g) => g.label).where((l) => l != null).join(", ")}',
            'Current route: ${tableau.route}',
            'Try using a different label or check if element is visible',
          ],
        ),
      );
    }
  }

  // 3. Execute the action
  switch (step.action) {
    case StratagemAction.tap:
      await _dispatchTap(target!.centerX, target.centerY);
    case StratagemAction.doubleTap:
      await _dispatchDoubleTap(target!.centerX, target.centerY);
    case StratagemAction.longPress:
      await _dispatchLongPress(target!.centerX, target.centerY);
    case StratagemAction.enterText:
      // Same as Phantom: tap to focus → inject via ShadeTextController
      await _dispatchTap(target!.centerX, target.centerY);
      await Future.delayed(Duration(milliseconds: 100));
      await _injectText(target, step.value!,
        clearFirst: step.clearFirst ?? true);
    case StratagemAction.clearText:
      await _dispatchTap(target!.centerX, target.centerY);
      await Future.delayed(Duration(milliseconds: 100));
      await _injectText(target, '', clearFirst: true);
    case StratagemAction.submitField:
      await _dispatchTextAction(TextInputAction.done);
    case StratagemAction.scroll:
      await _dispatchScroll(step.scrollDelta!);
    case StratagemAction.scrollUntilVisible:
      await _scrollUntilVisible(step.target!, step.scrollDelta!,
        maxAttempts: step.repeatCount ?? 10);
    case StratagemAction.swipe:
      await _dispatchSwipe(target!.centerX, target.centerY,
        direction: step.swipeDirection!, distance: step.swipeDistance ?? 300);
    case StratagemAction.drag:
      await _dispatchDrag(step.dragFrom!, step.dragTo!);
    case StratagemAction.toggleSwitch:
    case StratagemAction.toggleCheckbox:
    case StratagemAction.selectRadio:
    case StratagemAction.selectSegment:
      // All toggles are taps — find by label, tap center
      await _dispatchTap(target!.centerX, target.centerY);
    case StratagemAction.adjustSlider:
      await _adjustSlider(target!, step.value!, step.sliderRange);
    case StratagemAction.selectDropdown:
      // 1) Tap dropdown to open, 2) Capture overlay, 3) Tap item
      await _dispatchTap(target!.centerX, target.centerY);
      await _waitForSettle(Duration(milliseconds: 500));
      final overlayTableau = await TableauCapture.capture();
      final item = StratagemTarget(label: step.value)
          .fuzzyResolve(overlayTableau);
      if (item != null) await _dispatchTap(item.centerX, item.centerY);
    case StratagemAction.selectDate:
      await _selectDate(target!, step.value!);
    case StratagemAction.navigate:
      _navigateTo(step.navigateRoute!);
    case StratagemAction.back:
      _navigateBack();
    case StratagemAction.wait:
      await Future.delayed(step.waitAfter ?? Duration(seconds: 1));
    case StratagemAction.waitForElement:
      await _waitForElement(step.target!, step.waitAfter ?? Duration(seconds: 10));
    case StratagemAction.waitForElementGone:
      await _waitForElementGone(step.target!, step.waitAfter ?? Duration(seconds: 10));
    case StratagemAction.verify:
      break; // No action — just validate expectations
    case StratagemAction.dismissKeyboard:
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    case StratagemAction.pressKey:
      await _dispatchKeyEvent(step.keyId!);
  }

  // 4. Wait for settle
  await _waitForSettle(step.waitAfter ?? Duration(seconds: 2));

  // 5. Capture post-action Tableau
  final postTableau = await TableauCapture.capture();

  // 6. Validate expectations
  final failure = _validateExpectations(step.expectations, postTableau);

  stopwatch.stop();
  return VerdictStep(
    stepId: step.id,
    description: step.description,
    status: failure == null ? VerdictStepStatus.passed : VerdictStepStatus.failed,
    duration: stopwatch.elapsed,
    tableau: postTableau,
    resolvedTarget: target,
    failure: failure,
  );
}
```

### API Error Detection

During Stratagem execution, Colossus monitors for errors using existing Vigil integration:

```dart
// Colossus hooks into Vigil (error tracking) during execution
// Any uncaught exception or API failure is captured and attached to the VerdictStep

// API failures detected via:
// 1. HTTP status codes (if using a Titan HTTP interceptor)
// 2. Pillar error states (Core values that become error states)
// 3. Vigil.captureError calls
// 4. Unhandled Flutter exceptions via FlutterError.onError
```

---

## The Verdict Report — What AI Reads

### Verdict JSON Output Example

```json
{
  "stratagemName": "login_flow_happy_path",
  "executedAt": "2025-01-15T14:30:22Z",
  "duration": 8420,
  "passed": false,
  "summary": {
    "totalSteps": 6,
    "passedSteps": 4,
    "failedSteps": 1,
    "skippedSteps": 1,
    "successRate": 0.67,
    "failedRoutes": [],
    "missingElements": ["Dashboard"],
    "apiErrors": [],
    "unexpectedRoutes": ["/home"]
  },
  "steps": [
    {
      "stepId": 1,
      "description": "Verify login page is displayed",
      "status": "passed",
      "duration": 120,
      "tableau": { "route": "/login", "glyphs": ["..."] }
    },
    {
      "stepId": 2,
      "description": "Enter email address",
      "status": "passed",
      "duration": 340,
      "resolvedTarget": {"label": "Email", "type": "TextField", "centerX": 195, "centerY": 280}
    },
    {
      "stepId": 3,
      "description": "Enter password",
      "status": "passed",
      "duration": 310,
      "resolvedTarget": {"label": "Password", "type": "TextField", "centerX": 195, "centerY": 380}
    },
    {
      "stepId": 4,
      "description": "Verify login button is enabled after form fill",
      "status": "passed",
      "duration": 80
    },
    {
      "stepId": 5,
      "description": "Tap login button",
      "status": "passed",
      "duration": 2100,
      "resolvedTarget": {"label": "Login", "type": "ElevatedButton", "centerX": 195, "centerY": 520}
    },
    {
      "stepId": 6,
      "description": "Verify navigation to dashboard",
      "status": "failed",
      "duration": 3200,
      "failure": {
        "type": "elementMissing",
        "message": "Expected element 'Dashboard' not found on screen",
        "expected": "Element with label 'Dashboard' present on route /dashboard",
        "actual": "Route is /home. Elements found: 'Welcome', 'Home', 'Settings', 'Profile'",
        "suggestions": [
          "The app navigated to /home instead of /dashboard",
          "The element 'Dashboard' may have been renamed to 'Home'",
          "Update Stratagem step 6: change route to '/home' and label to 'Home'"
        ]
      },
      "tableau": {
        "route": "/home",
        "glyphs": [
          {"label": "Welcome", "type": "Text"},
          {"label": "Home", "type": "Text"},
          {"label": "Settings", "type": "IconButton"},
          {"label": "Profile", "type": "IconButton"}
        ]
      }
    }
  ],
  "performance": {
    "averageFps": 58.4,
    "minFps": 42.1,
    "jankFrames": 3,
    "startMemoryBytes": 45000000,
    "endMemoryBytes": 52000000,
    "slowSteps": [5]
  }
}
```

### AI Reads the Verdict and Responds

```
AI Analysis of login_flow_happy_path Verdict:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RESULT: ❌ FAILED (4/6 steps passed — 67% success rate)

FAILURE: Step 6 — "Verify navigation to dashboard"
  • Expected route: /dashboard
  • Actual route: /home
  • Expected element: "Dashboard"
  • Found instead: "Home"

ROOT CAUSE ANALYSIS:
  The app navigates to /home after login, not /dashboard.
  The Stratagem assumed /dashboard but the actual route is /home.
  The label "Dashboard" doesn't exist — it's labeled "Home" instead.

RECOMMENDATION:
  Option A: Update Stratagem to expect route "/home" and label "Home"
  Option B: Report to developer — if /dashboard was intended, this is a bug

PERFORMANCE NOTE:
  Step 5 (login tap) took 2.1s — may indicate slow API call.
  FPS dropped to 42 during login transition — minor jank.
  Memory increased by 7MB — normal for page transition.

UPDATED STRATAGEM (auto-corrected):
  Step 6: route → "/home", elementsPresent → ["Welcome", "Home"]
```

---

## The Complete Autonomous Testing Loop

### Phase 1: AI Writes the Stratagem

The AI receives a natural language instruction and context:

```
Input to AI:
  "Test the login flow with valid credentials"

AI receives from Colossus:
  • Stratagem.templateDescription (schema documentation)
  • App routes: ["/login", "/home", "/settings", "/profile", ...]
  • Known Glyphs from previous sessions (optional)
  • Previous Verdicts (if any — for learning)

AI outputs:
  login_flow.stratagem.json
```

### Phase 2: Colossus Executes

```dart
// In your test file, CI pipeline, or even a debug button:
final verdict = await Colossus.instance.executeStratagemFile(
  'assets/stratagems/login_flow.stratagem.json',
);
await verdict.saveToFile('test_results/');
```

### Phase 3: AI Reads the Verdict

```dart
// AI reads the Verdict file
final verdictJson = File('test_results/login_flow.verdict.json').readAsStringSync();
// AI parses, analyzes, and recommends fixes
```

### Phase 4: AI Iterates

If the Verdict has failures, AI can:
1. **Self-correct** — Update the Stratagem and re-execute
2. **Report bug** — If the failure is a real app bug, generate a bug report
3. **Expand testing** — Write additional Stratagems to test edge cases
4. **Performance alert** — Flag slow steps or high memory usage

### The Vision: Continuous AI Testing

```
┌──────────────────────────────────────────────────────────┐
│                  CONTINUOUS AI TESTING                     │
│                                                           │
│  Developer pushes code                                    │
│       ↓                                                   │
│  CI runs Stratagem suite                                  │
│       ↓                                                   │
│  Colossus executes all Stratagems                         │
│       ↓                                                   │
│  Verdicts generated                                       │
│       ↓                                                   │
│  AI reads Verdicts                                        │
│       ├── All passed → ✅ Merge approved                  │
│       ├── Failure is test issue → AI updates Stratagem    │
│       └── Failure is app bug → AI files issue + suggests  │
│                                       fix with code diff  │
│                                                           │
│  No human tester needed at any point.                     │
└──────────────────────────────────────────────────────────┘
```

---

## Example Stratagems for Common Flows

### "Test until this page" — Exploratory Stratagem

When AI is told "test until the checkout page", it writes an exploratory Stratagem:

```json
{
  "name": "explore_to_checkout",
  "description": "Navigate through the app until reaching /checkout",
  "startRoute": "/",
  "timeout": 60000,
  "failurePolicy": "continue-all",
  "steps": [
    {
      "id": 1,
      "action": "verify",
      "description": "Verify landing page",
      "expectations": {"route": "/"}
    },
    {
      "id": 2,
      "action": "tap",
      "description": "Navigate to products",
      "target": {"label": "Shop", "type": "NavigationDestination"}
    },
    {
      "id": 3,
      "action": "tap",
      "description": "Select first product",
      "target": {"type": "ListTile", "index": 0}
    },
    {
      "id": 4,
      "action": "tap",
      "description": "Add to cart",
      "target": {"label": "Add to Cart", "type": "ElevatedButton"}
    },
    {
      "id": 5,
      "action": "tap",
      "description": "Go to cart",
      "target": {"label": "Cart", "semanticRole": "button"}
    },
    {
      "id": 6,
      "action": "tap",
      "description": "Proceed to checkout",
      "target": {"label": "Checkout", "type": "ElevatedButton"}
    },
    {
      "id": 7,
      "action": "verify",
      "description": "Verify reached checkout",
      "expectations": {
        "route": "/checkout",
        "elementsPresent": [{"label": "Checkout"}]
      }
    }
  ]
}
```

### E2E Registration Flow

```json
{
  "name": "registration_e2e",
  "description": "Full registration flow with email verification",
  "startRoute": "/register",
  "testData": {
    "name": "Test User",
    "email": "newuser@example.com",
    "password": "StrongPass!2025"
  },
  "steps": [
    {"id": 1, "action": "enterText", "target": {"label": "Full Name"}, "value": "${testData.name}"},
    {"id": 2, "action": "enterText", "target": {"label": "Email"}, "value": "${testData.email}"},
    {"id": 3, "action": "enterText", "target": {"label": "Password"}, "value": "${testData.password}"},
    {"id": 4, "action": "enterText", "target": {"label": "Confirm Password"}, "value": "${testData.password}"},
    {"id": 5, "action": "tap", "target": {"label": "I agree to the Terms", "type": "Checkbox"}},
    {"id": 6, "action": "verify", "expectations": {"elementStates": [{"label": "Create Account", "enabled": true}]}},
    {"id": 7, "action": "tap", "target": {"label": "Create Account"}},
    {"id": 8, "action": "verify", "description": "Verify success", "expectations": {
      "route": "/verify-email",
      "elementsPresent": [{"label": "Check your email"}]
    }}
  ]
}
```

### Error Handling Flow

```json
{
  "name": "login_invalid_credentials",
  "description": "Verify error handling with wrong password",
  "startRoute": "/login",
  "testData": {"email": "user@example.com", "password": "wrong"},
  "steps": [
    {"id": 1, "action": "enterText", "target": {"label": "Email"}, "value": "${testData.email}"},
    {"id": 2, "action": "enterText", "target": {"label": "Password"}, "value": "${testData.password}"},
    {"id": 3, "action": "tap", "target": {"label": "Login"}},
    {"id": 4, "action": "verify", "description": "Error shown, stayed on login", "expectations": {
      "route": "/login",
      "elementsPresent": [{"label": "Invalid credentials"}, {"label": "Login"}]
    }}
  ]
}
```

---

## Colossus API for Stratagem Execution

### New Methods on Colossus

```dart
class Colossus extends Pillar {
  // ... existing API unchanged ...

  /// Execute a Stratagem and return the Verdict.
  Future<Verdict> executeStratagem(
    Stratagem stratagem, {
    bool captureScreenshots = false,
    Duration? stepTimeout,
    void Function(VerdictStep)? onStepComplete,
  }) async { /* ... */ }

  /// Execute a Stratagem from a JSON file.
  Future<Verdict> executeStratagemFile(
    String path, {
    bool captureScreenshots = false,
  }) async { /* ... */ }

  /// Execute all Stratagems in a directory.
  Future<List<Verdict>> executeStratagemSuite({
    required String directory,
    bool parallel = false,
    bool stopOnFirstFailure = false,
    bool captureScreenshots = false,
  }) async { /* ... */ }

  /// Get context information for AI to write better Stratagems.
  /// Includes: app routes, known Glyphs, screen dimensions, recent Verdicts.
  Map<String, dynamic> getAiContext() { /* ... */ }

  /// Save a Verdict to disk.
  Future<void> saveVerdict(Verdict verdict, {String? directory}) async { /* ... */ }

  /// Load a previous Verdict from disk.
  Future<Verdict?> loadVerdict(String name, {String? directory}) async { /* ... */ }
}
```

| Operation | Cost | Frequency | Impact |
|---|---|---|---|
| Tableau capture (tree walk) | 2-8ms | After each pointerUp (~5-20/session) | Negligible — runs after settle |
| Glyph extraction per widget | ~1us | ~50-150 widgets per capture | Total: ~0.15ms |
| Fresco (screenshot) | 5-15ms | Same as Tableau (optional) | Acceptable — async |
| Deduplication check | <1ms | Per capture | Prevents redundant Tableaux |
| Serialization overhead | +2-5KB/Tableau | Per save | Typical session: +20-50KB |
| Stratagem step execution | 50-3000ms | Per step (~5-30 steps) | Includes settle wait — expected |
| Stratagem Glyph resolution | 1-5ms | Per step with target | Tree walk + label matching |
| Verdict serialization | 5-20KB | Per execution | One-time at end |
| **Total recording overhead** | **<10ms per interaction** | Only during Shade recording | **Zero impact when not recording** |
| **Total Stratagem overhead** | **N/A — testing tool** | Only during test execution | **Not in production path** |

---

## Backward Compatibility

| Concern | Solution |
|---|---|
| Old sessions without Tableaux | `ShadeSession.fromJson()` defaults `tableaux` to `[]`. All existing APIs unchanged. |
| Old Imprints without `tableauIndex` | Defaults to `null`. `resolveTargetGlyph()` returns `null`. |
| Phantom replay | Phantom ignores Tableaux — replays Imprints only. Tableaux are read-only metadata. |
| `ShadeVault` | Auto-includes Tableaux in JSON. Old sessions load fine. |
| Fresco null | `Tableau.fresco` is `Uint8List?` — null when disabled or for old sessions. |
| Stratagem/Verdict | Entirely new classes — no existing code affected. Completely additive. |
| No Stratagems? | App works exactly as before. Stratagems are opt-in test tooling. |

---

## Implementation Plan

### Phase 1: Core Data Models (Week 1)

| # | Task | File |
|---|---|---|
| 1 | `Glyph` class with full serialization | `lib/src/recording/glyph.dart` |
| 2 | `Tableau` class with serialization, `summary`, `diff()`, `glyphAt()` | `lib/src/recording/tableau.dart` |
| 3 | `Fresco` static screenshot capture | `lib/src/recording/fresco.dart` |
| 4 | `TableauCapture` — Element tree walker + Glyph extraction engine | `lib/src/recording/tableau_capture.dart` |
| 5 | Add `tableauIndex` to `Imprint` (nullable, backward-compatible) | `lib/src/recording/imprint.dart` |
| 6 | Add `tableaux` to `ShadeSession` (backward-compatible) | `lib/src/recording/imprint.dart` |
| 7 | Tests: Glyph serialization, Tableau serialization, diff, glyphAt | `test/recording/` |

### Phase 2: Shade Integration (Week 2)

| # | Task | File |
|---|---|---|
| 8 | Wire `TableauCapture` into `Shade.startRecording()` — auto-initial | `lib/src/recording/shade.dart` |
| 9 | Auto-capture Tableau on `pointerUp` + settle | `lib/src/recording/shade.dart` |
| 10 | Auto-capture Tableau on route change | `lib/src/recording/shade.dart` |
| 11 | Auto-capture Tableau on `stopRecording()` | `lib/src/recording/shade.dart` |
| 12 | Set `tableauIndex` on each Imprint during recording | `lib/src/recording/shade.dart` |
| 13 | Deduplication logic (skip identical Tableaux) | `lib/src/recording/shade.dart` |
| 14 | Add `enableTableauCapture` + `enableScreenCapture` to `Colossus.init()` | `lib/src/colossus.dart` |
| 15 | Integration tests: recording with Tableaux, dedup, screenshot | `test/recording/` |

### Phase 3: AI Output Generators (Week 3)

| # | Task | File |
|---|---|---|
| 16 | `ShadeSession.generateFlowDescription()` | `lib/src/recording/imprint.dart` |
| 17 | `ShadeSession.toAiTestSpec()` (structured JSON) | `lib/src/recording/imprint.dart` |
| 18 | `TableauDiff` — detailed change detection between Tableaux | `lib/src/recording/tableau.dart` |
| 19 | `Imprint.resolveTargetGlyph(tableau)` hit-test | `lib/src/recording/imprint.dart` |
| 20 | Tests: flow description, AI spec, diff, glyph resolution | `test/recording/` |

### Phase 4: Lens UI + Polish (Week 4)

| # | Task | File |
|---|---|---|
| 21 | Tableau viewer in `ShadeLensTab` (list of Tableaux + Glyph details) | `lib/src/integration/shade_lens_tab.dart` |
| 22 | "Export for AI" button (copies flow description to clipboard) | `lib/src/integration/shade_lens_tab.dart` |
| 23 | Screenshot viewer (expandable thumbnails) if Fresco enabled | `lib/src/integration/shade_lens_tab.dart` |
| 24 | Barrel file exports | `lib/titan_colossus.dart` |
| 25 | Story chapter for Glyph + Tableau | `docs/story/` |
| 26 | Update lexicon + source map in instructions | `.github/` |

### Phase 5: Stratagem Engine (Week 5-6)

| # | Task | File |
|---|---|---|
| 27 | `Stratagem` class with JSON serialization + template schema | `lib/src/testing/stratagem.dart` |
| 28 | `StratagemStep`, `StratagemTarget`, `StratagemAction`, `StratagemExpectations` | `lib/src/testing/stratagem.dart` |
| 29 | `StratagemTarget.resolve()` — Glyph-based element finding | `lib/src/testing/stratagem.dart` |
| 30 | `StratagemTarget.fuzzyResolve()` — partial label matching | `lib/src/testing/stratagem.dart` |
| 31 | `Verdict`, `VerdictStep`, `VerdictFailure`, `VerdictSummary`, `VerdictPerformance` | `lib/src/testing/verdict.dart` |
| 32 | `StratagemRunner` — execution engine (step loop, action dispatch, settle, validate) | `lib/src/testing/stratagem_runner.dart` |
| 33 | Action dispatch: tap, longPress, enterText, scroll via GestureBinding | `lib/src/testing/stratagem_runner.dart` |
| 34 | Expectation validation: route, elementsPresent/Absent, elementStates | `lib/src/testing/stratagem_runner.dart` |
| 35 | API error detection via Vigil/FlutterError hook during execution | `lib/src/testing/stratagem_runner.dart` |
| 36 | `testData` variable interpolation (`${testData.key}` in values) | `lib/src/testing/stratagem.dart` |
| 37 | `Stratagem.templateDescription` — natural language schema for AI prompts | `lib/src/testing/stratagem.dart` |
| 38 | `Stratagem.template` — structured JSON schema for AI | `lib/src/testing/stratagem.dart` |
| 39 | Tests: Stratagem serialization, target resolution, fuzzy matching | `test/testing/` |
| 40 | Tests: StratagemRunner step execution, action dispatch | `test/testing/` |

### Phase 6: Verdict Output + Colossus Integration (Week 7)

| # | Task | File |
|---|---|---|
| 41 | `Verdict.toJson()` + `Verdict.toReport()` (human-readable) | `lib/src/testing/verdict.dart` |
| 42 | `Verdict.toAiDiagnostic()` — concise AI-optimized output | `lib/src/testing/verdict.dart` |
| 43 | `Verdict.saveToFile()` — persist as `.verdict.json` | `lib/src/testing/verdict.dart` |
| 44 | Auto-failure suggestions (per `VerdictFailureType`) | `lib/src/testing/verdict.dart` |
| 45 | `Colossus.executeStratagem()` | `lib/src/colossus.dart` |
| 46 | `Colossus.executeStratagemFile()` | `lib/src/colossus.dart` |
| 47 | `Colossus.executeStratagemSuite()` | `lib/src/colossus.dart` |
| 48 | `Colossus.getAiContext()` — route map, known Glyphs, screen dims | `lib/src/colossus.dart` |
| 49 | `Colossus.saveVerdict()` + `Colossus.loadVerdict()` | `lib/src/colossus.dart` |
| 50 | Stratagem Lens tab — execute, view Verdicts, step-by-step viewer | `lib/src/integration/shade_lens_tab.dart` |
| 51 | Barrel file exports for testing classes | `lib/titan_colossus.dart` |
| 52 | Integration tests: full Stratagem → Verdict pipeline | `test/testing/` |
| 53 | Story chapter for Stratagem + Verdict | `docs/story/` |
| 54 | Performance benchmarks: Stratagem execution overhead | `test/testing/` |

### Totals

| Metric | Value |
|---|---|
| **New files** | 8 production + 8 test |
| **Modified files** | 5 (`imprint.dart`, `shade.dart`, `colossus.dart`, `shade_lens_tab.dart`, barrel) |
| **New tests** | 130+ |
| **New production lines** | ~3,500 |
| **Developer code changes needed** | **Zero** |

---

## File Structure After Implementation

```
packages/titan_colossus/lib/src/
├── recording/
│   ├── fresco.dart              ← NEW: Screenshot capture utility
│   ├── glyph.dart               ← NEW: UI element descriptor
│   ├── imprint.dart             ← MODIFIED: +tableauIndex, +tableaux on ShadeSession
│   ├── phantom.dart             ← UNCHANGED
│   ├── shade.dart               ← MODIFIED: auto-captures Tableaux during recording
│   ├── shade_vault.dart         ← UNCHANGED (Tableaux auto-serialized)
│   ├── tableau.dart             ← NEW: Screen snapshot + diff engine
│   └── tableau_capture.dart     ← NEW: Element tree walker → Glyph extraction
│
├── testing/                     ← NEW DIRECTORY
│   ├── stratagem.dart           ← NEW: Test blueprint (AI-generated plan)
│   ├── stratagem_runner.dart    ← NEW: Execution engine (runs Stratagems against live app)
│   └── verdict.dart             ← NEW: Execution report (pass/fail, errors, suggestions)
│
├── colossus.dart                ← MODIFIED: +executeStratagem, +getAiContext, +saveVerdict
└── integration/
    └── shade_lens_tab.dart      ← MODIFIED: +Tableau viewer, +Stratagem runner UI
```

---

## Competitive Landscape

| Feature | BLoC | Riverpod | GetX | Firebase | Amplitude | Detox | Maestro | **Titan Colossus** |
|---|---|---|---|---|---|---|---|---|
| Gesture recording | -- | -- | -- | -- | -- | -- | -- | Shade |
| Gesture replay | -- | -- | -- | -- | -- | -- | -- | Phantom |
| Screen layout capture | -- | -- | -- | -- | -- | -- | -- | **Tableau + Glyph** |
| Screenshot capture | -- | -- | -- | -- | Heatmaps (cloud) | Screenshots | Screenshots | **Fresco** (local, optional) |
| AI-readable output | -- | -- | -- | -- | -- | -- | -- | **Flow Description** |
| AI-generated test plans | -- | -- | -- | -- | -- | -- | -- | **Stratagem** |
| Autonomous test execution | -- | -- | -- | -- | -- | Manual | Manual | **StratagemRunner** |
| Structured pass/fail report | -- | -- | -- | -- | -- | Basic | Basic | **Verdict** (AI-readable) |
| Label-based element targeting | -- | -- | -- | -- | -- | TestID | Label | **Glyph** (auto-extracted) |
| AI self-correction loop | -- | -- | -- | -- | -- | -- | -- | **Verdict → AI → Stratagem** |
| Performance monitoring | -- | -- | -- | Perf traces | -- | -- | -- | Pulse/Stride/Vessel |
| Integrated with state mgmt | N/A | N/A | N/A | -- | -- | -- | -- | Deep integration |
| Developer setup effort | N/A | N/A | N/A | SDK + config | SDK + config | Config | Config | **Zero extra** |
| Eliminates human testers | -- | -- | -- | -- | -- | No | No | **Yes — AI loop** |

---

## What the Developer Does vs What Colossus Does

| | Developer | Colossus (Automatic) |
|---|---|---|
| **Setup** | `Colossus.init()` (existing) | Wires up Tableau capture, tree walker, Fresco, Stratagem engine |
| **Recording** | `shade.startRecording()` / `stopRecording()` (existing) | Captures Tableaux at start, after each tap, on route change, at end |
| **Screenshot** | Optionally: `enableScreenCapture: true` | Captures PNG at each Tableau |
| **AI output** | `session.generateFlowDescription()` | Walks Tableaux + Imprints, generates natural-language flow |
| **Replay** | `replaySession(session)` (existing) | Unchanged — Phantom replays Imprints |
| **Annotations** | **Nothing** | Extracts labels from widget text, tooltips, hints, Semantics |
| **Widget changes** | **Nothing** | Uses existing Element tree and RenderObject data |
| **Test blueprint** | **Nothing** — AI writes the Stratagem | Provides `Stratagem.template` schema for AI, `getAiContext()` for route/element info |
| **Test execution** | `executeStratagem(stratagem)` — one call | Navigates, finds elements by label, taps, types, validates, waits, captures evidence |
| **Test report** | **Nothing** — reads the Verdict file | Produces Verdict with per-step pass/fail, API errors, missing elements, suggestions, screenshots |
| **Test iteration** | **Nothing** — AI reads Verdict and auto-corrects | Outputs structured JSON that AI can parse, diagnose, and use to update the Stratagem |
| **Writing test code** | **Nothing** | AI writes Stratagem JSON, no Dart test code needed |

**The developer's code doesn't change. Colossus just gets smarter. And the testers? They can focus on edge cases the AI hasn't learned yet — or they can go home.**

---

*"The Colossus doesn't just watch. It sees. It remembers every Glyph on every Tableau. When the Oracle commands 'Test the gates!', the Colossus reads the Stratagem, marches through every screen, and delivers its Verdict — carved in stone, for all to read. No mortal tester required."*
