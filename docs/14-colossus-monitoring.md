# Colossus — Enterprise Performance Monitoring

**Package:** `titan_colossus` · **Named for:** The Colossus of Rhodes, a giant who stood watch over the harbor

Titan's enterprise performance monitoring package provides frame tracking, page load timing, memory monitoring, rebuild counting, threshold alerts, aggregated reports, export, and gesture recording/replay.

## The Colossus Lexicon

| Standard Term | Titan Name | Class |
|---------------|------------|-------|
| Performance Monitor | **Colossus** | `Colossus` |
| Frame Metrics | **Pulse** | `Pulse` |
| Page Load Timing | **Stride** | `Stride` |
| Memory Monitor | **Vessel** | `Vessel` |
| Rebuild Counter | **Echo** | `Echo` |
| Performance Alert | **Tremor** | `Tremor` |
| Performance Report | **Decree** | `Decree` |
| Report Export | **Inscribe** | `Inscribe` |
| Metric Data Point | **Mark** | `Mark` |
| Gesture Recorder | **Shade** | `Shade` |
| Recorded Event | **Imprint** | `Imprint` |
| Replay Engine | **Phantom** | `Phantom` |
| Capture Widget | **ShadeListener** | `ShadeListener` |
| Session Store | **ShadeVault** | `ShadeVault` |
| Text Controller | **ShadeTextController** | `ShadeTextController` |
| Plugin Adapter | **ColossusPlugin** | `ColossusPlugin` |
| Test Discovery | **Scout** | `Scout` |
| Flow Graph | **Terrain** | `Terrain` |
| Screen Node | **Outpost** | `Outpost` |
| Transition Edge | **March** | `March` |
| Route Resolver | **Lineage** | `RouteParameterizer` |
| Edge-Case Generator | **Gauntlet** | `Gauntlet` |
| Test Plan | **Stratagem** | `Stratagem` |
| Test Orchestrator | **Campaign** | `Campaign` |
| Step Result | **Verdict** | `Verdict` |
| Campaign Analysis | **Debrief** | `Debrief` |
| Screen Identifier | **Signet** | `Signet` |
| Blueprint Overlay | **BlueprintLensTab** | `BlueprintLensTab` |

## Installation

```yaml
dependencies:
  titan_colossus: ^1.1.0
```

```dart
import 'package:titan_colossus/titan_colossus.dart';
```

---

## Quick Start

### Plugin Integration (Recommended)

The simplest way to add Colossus — one line to add, one line to remove:

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  runApp(
    Beacon(
      pillars: [MyPillar.new],
      plugins: [
        if (kDebugMode) ColossusPlugin(
          tremors: [Tremor.fps(), Tremor.leaks()],
          enableLens: true,
          enableShade: true,
          getCurrentRoute: () => Atlas.current.path,
        ),
      ],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

`ColossusPlugin` handles everything: `Colossus.init()`, `Lens` overlay, `ShadeListener` wrapping, export/route callbacks, and `Colossus.shutdown()` on dispose. Remove the plugin line for production builds — no widget tree restructuring needed.

### Manual Integration

For more control over initialization order:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Colossus (registers as a Pillar via Titan.put)
  final colossus = Colossus.init(
    enablePulse: true,    // frame metrics
    enableStride: true,   // page load timing
    enableVessel: true,   // memory monitoring
    vesselInterval: const Duration(seconds: 30),
    tremors: [
      Tremor(
        name: 'Slow Frame',
        severity: TremorSeverity.warning,
        condition: (marks) => marks.whereType<FrameMark>()
            .any((m) => m.buildDuration.inMilliseconds > 16),
      ),
    ],
  );

  runApp(
    ShadeListener(
      shade: colossus.shade,
      child: MaterialApp.router(
        routerConfig: Atlas(
          observers: [ColossusAtlasObserver()],
          // ...
        ),
      ),
    ),
  );
}
```

---

## Colossus — The Orchestrator

`Colossus` is a `Pillar` singleton that manages all monitors:

```dart
// Initialize
final colossus = Colossus.init(
  enablePulse: true,
  enableStride: true,
  enableVessel: true,
);

// Access the singleton
final instance = Colossus.instance;

// Check status
if (Colossus.isActive) {
  // ...
}

// Generate a report
final decree = colossus.generateDecree();

// Shutdown
colossus.shutdown();
```

### Zero Overhead When Inactive

All monitors check `Colossus.isActive` before collecting data. When Colossus isn't initialized, overhead is zero.

---

## Monitors

### Pulse — Frame Metrics

Tracks frame build and raster durations using `SchedulerBinding.addTimingsCallback`:

```dart
Colossus.init(enablePulse: true);

// Access frame history
final frames = colossus.pulse.frames;  // List<FrameMark>
final avgBuild = colossus.pulse.averageBuildTime;
final avgRaster = colossus.pulse.averageRasterTime;
final jankyFrames = colossus.pulse.jankyFrameCount;
```

**FrameMark** fields:

| Field | Type | Description |
|-------|------|-------------|
| `buildDuration` | `Duration` | Time spent building the frame |
| `rasterDuration` | `Duration` | Time spent rasterizing |
| `timestamp` | `DateTime` | When the frame was recorded |

### Stride — Page Load Timing

Measures page load durations using post-frame callbacks:

```dart
Colossus.init(enableStride: true);

// With Atlas observer (automatic):
Atlas(observers: [ColossusAtlasObserver()]);

// Manual recording:
colossus.stride.startTiming('profile-page');
// ... page loads ...
colossus.stride.stopTiming('profile-page');

// Access history
final loads = colossus.stride.pageLoads;  // List<PageLoadMark>
```

**PageLoadMark** fields:

| Field | Type | Description |
|-------|------|-------------|
| `pageName` | `String` | Route or page identifier |
| `duration` | `Duration` | Total load time |
| `timestamp` | `DateTime` | When the load was recorded |

### Vessel — Memory Monitoring

Periodically checks memory usage via `Timer.periodic`:

```dart
Colossus.init(
  enableVessel: true,
  vesselInterval: const Duration(seconds: 30),
);

final snapshots = colossus.vessel.snapshots;  // List<MemoryMark>
final suspects = colossus.vessel.leakSuspects; // List<LeakSuspect>
```

**MemoryMark** fields:

| Field | Type | Description |
|-------|------|-------------|
| `rss` | `int` | Resident set size in bytes |
| `timestamp` | `DateTime` | When the snapshot was taken |

### Echo — Rebuild Counter

A `StatelessWidget` wrapper that counts rebuilds with zero allocation overhead:

```dart
Echo(
  name: 'profile-card',
  child: ProfileCard(),
)
```

When `Colossus.isActive`, each rebuild increments a counter. Access via `colossus.echo.rebuilds`.

---

## Tremor — Performance Alerts

Configure threshold-based alerts that fire when conditions are met:

```dart
Colossus.init(
  tremors: [
    Tremor(
      name: 'Slow Frame',
      severity: TremorSeverity.warning,
      condition: (marks) => marks.whereType<FrameMark>()
          .any((m) => m.buildDuration.inMilliseconds > 16),
    ),
    Tremor(
      name: 'Memory Spike',
      severity: TremorSeverity.critical,
      condition: (marks) => marks.whereType<MemoryMark>()
          .any((m) => m.rss > 500 * 1024 * 1024), // 500 MB
    ),
  ],
);
```

Tremors are emitted via `Herald` as `ColossusTremor` events, integrating with the standard Titan event bus:

```dart
herald.on<ColossusTremor>((tremor) {
  print('Alert: ${tremor.name} [${tremor.severity}]');
});
```

**TremorSeverity** levels: `info`, `warning`, `critical`.

---

## Decree — Performance Reports

Generate aggregated performance reports:

```dart
final decree = colossus.generateDecree();

print(decree.health);          // PerformanceHealth.good / .warning / .critical
print(decree.avgBuildTime);    // Duration
print(decree.avgRasterTime);   // Duration
print(decree.totalRebuilds);   // int
print(decree.jankyFrameRatio); // double (0.0 – 1.0)
print(decree.pageLoads);       // List<PageLoadMark>
print(decree.memorySnapshots); // List<MemoryMark>
print(decree.leakSuspects);    // List<LeakSuspect>
print(decree.activeTremors);   // List<Tremor>
```

**PerformanceHealth** verdicts: `good`, `warning`, `critical`.

---

## Inscribe — Report Export

Export Decree reports in multiple formats:

```dart
final decree = colossus.generateDecree();

// Markdown
final md = Inscribe.toMarkdown(decree);

// JSON
final json = Inscribe.toJson(decree);

// HTML
final html = Inscribe.toHtml(decree);

// Save to disk (dart:io)
final result = await InscribeIO.save(decree, format: 'md', directory: '/tmp');
print(result.path); // SaveResult with file path
```

---

## Integration

### ColossusPlugin — One-Line Integration

`ColossusPlugin` is a `TitanPlugin` that wraps all Colossus setup into a single Beacon plugin:

```dart
Beacon(
  pillars: [MyPillar.new],
  plugins: [
    if (kDebugMode) ColossusPlugin(
      tremors: [Tremor.fps(), Tremor.leaks()],
      enableLens: true,           // wraps with Lens overlay
      enableShade: true,          // wraps with ShadeListener
      enableLensTab: true,        // registers Perf + Shade tabs
      enableChronicle: true,      // logs to Chronicle
      shadeStoragePath: '/path',  // session persistence
      exportDirectory: '/export', // report export directory
      onExport: (paths) => Share.shareFiles(paths),
      getCurrentRoute: () => Atlas.current.path,
      autoReplayOnStartup: true,
    ),
  ],
  child: MaterialApp(...),
)
```

| Lifecycle | What Happens |
|-----------|-------------|
| `onAttach()` | Calls `Colossus.init()`, wires export/route callbacks, schedules auto-replay |
| `buildOverlay()` | Wraps child with `Lens` and `ShadeListener` (if enabled) |
| `onDetach()` | Calls `Colossus.shutdown()` |

To remove Colossus entirely: delete the `ColossusPlugin(...)` line and remove the `titan_colossus` import.

### Lens Debug Overlay

Lens (debug overlay) is part of `titan_colossus`. Add performance tabs to the Lens debug overlay:

```dart
import 'package:titan_colossus/titan_colossus.dart';

Lens(
  plugins: [ColossusLensTab()],
  child: MaterialApp(...),
)
```

### Atlas Route Timing

Automatically time page loads during navigation:

```dart
Atlas(
  observers: [ColossusAtlasObserver()],
  // ...
)
```

---

## Shade — Gesture Recording & Replay

Shade records user interactions (pointer events, keyboard input, text entry) for replay and debugging.

### Recording

```dart
final shade = colossus.shade;

// Start recording
shade.startRecording();

// ... user interacts with the app ...

// Stop recording
final session = shade.stopRecording(); // ShadeSession
```

### ShadeListener

Wrap your app to capture all pointer events:

```dart
ShadeListener(
  shade: colossus.shade,
  child: MaterialApp(...),
)
```

### ShadeTextController

Auto-recording `TextEditingController` for text input capture:

```dart
final controller = ShadeTextController(
  shade: shade,
  fieldId: 'hero_name',
);

TextField(controller: controller)
```

During replay, Phantom can inject text directly via the controller registry — no keyboard simulation needed.

### Phantom — Replay Engine

Replay recorded sessions programmatically:

```dart
final phantom = Phantom(shade: shade, suppressKeyboard: true);
final result = await phantom.replay(session);

print(result.totalEvents);    // int
print(result.actualDuration); // Duration
print(result.wasCancelled);   // bool
```

### Route Safety

Ensure replay starts on the correct route:

```dart
shade.getCurrentRoute = () => Atlas.current.path;

// Route is captured automatically on startRecording()
print(session.startRoute); // '/quest/42'

// Enforce matching route on replay
await Colossus.instance.replaySession(
  session,
  requireMatchingRoute: true, // throws if current route ≠ startRoute
);
```

### ShadeVault — Session Persistence

Persist recording sessions to disk:

```dart
final vault = ShadeVault(directory: '/path/to/sessions');

// Save a session
await vault.save(session);

// List saved sessions
final summaries = await vault.listSessions(); // List<ShadeSessionSummary>

// Load a session
final loaded = await vault.load(summaries.first.id);

// Configure auto-replay
await vault.setAutoReplayConfig(
  ShadeAutoReplayConfig(
    enabled: true,
    sessionId: session.id,
    speed: 2.0,
  ),
);
```

### Shade Lens Tab

Add a recording/replay UI to the Lens debug overlay:

```dart
Lens(
  plugins: [ColossusLensTab(), ShadeLensTab(shade: colossus.shade)],
  child: MaterialApp(...),
)
```

The Shade Lens tab provides:
- Start/stop recording controls
- Session library browser
- One-tap replay with speed control
- Route mismatch warnings

---

## Imprint — Recorded Events

Each recorded event is an `Imprint`:

| Field | Type | Description |
|-------|------|-------------|
| `type` | `ImprintType` | `pointer`, `keyboard`, `text`, `textAction` |
| `timestamp` | `DateTime` | When the event occurred |
| `data` | `Map<String, dynamic>` | Event-specific payload |

**ImprintType** values: `pointer`, `keyboard`, `text`, `textAction`.

---

## PhantomResult

Replay outcome data:

| Field | Type | Description |
|-------|------|-------------|
| `totalEvents` | `int` | Dispatched + skipped events |
| `actualDuration` | `Duration` | Wall-clock replay time |
| `wasNormalized` | `bool` | Whether positions were normalized |
| `wasCancelled` | `bool` | Whether replay was cancelled |
| `speedRatio` | `double` | Actual / expected duration ratio |

---

## Complete Example

### With ColossusPlugin (Recommended)

```dart
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final atlas = Atlas(
    observers: [HeraldAtlasObserver(), ColossusAtlasObserver()],
    passages: [
      Passage('/', (_) => const HomeScreen()),
      Passage('/profile', (_) => const ProfileScreen()),
    ],
  );

  runApp(
    Beacon(
      pillars: [HomePillar.new, ProfilePillar.new],
      plugins: [
        if (kDebugMode) ColossusPlugin(
          tremors: [Tremor.fps(), Tremor.jankRate(), Tremor.leaks()],
          enableLens: true,
          enableShade: true,
          enableChronicle: true,
          shadeStoragePath: '/tmp/shade_sessions',
          exportDirectory: '/tmp/reports',
          onExport: (paths) => Share.shareFiles(paths),
          getCurrentRoute: () {
            try { return Atlas.current.path; }
            catch (_) { return null; }
          },
          autoReplayOnStartup: true,
        ),
      ],
      child: MaterialApp.router(routerConfig: atlas.config),
    ),
  );
}
```

### Manual Integration

```dart
import 'package:titan_colossus/titan_colossus.dart';
import 'package:titan_argus/titan_argus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final colossus = Colossus.init(
    enablePulse: true,
    enableStride: true,
    enableVessel: true,
    tremors: [
      Tremor(
        name: 'Janky Frame',
        severity: TremorSeverity.warning,
        condition: (marks) => marks.whereType<FrameMark>()
            .any((m) => m.buildDuration.inMilliseconds > 16),
      ),
    ],
  );

  // Wire route tracking for Shade
  colossus.shade.getCurrentRoute = () => Atlas.current.path;

  runApp(
    ShadeListener(
      shade: colossus.shade,
      child: Lens(
        plugins: [
          ColossusLensTab(),
          ShadeLensTab(shade: colossus.shade),
        ],
        child: MaterialApp.router(
          routerConfig: Atlas(
            observers: [ColossusAtlasObserver()],
            passages: [
              Passage('/', (_) => const HomeScreen()),
              Passage('/profile', (_) => const ProfileScreen()),
            ],
          ),
        ),
      ),
    ),
  );
}
```

---

## AI Blueprint Generation

Colossus can passively learn your app's navigation structure from real user sessions, then auto-generate edge-case test plans. This entire pipeline — from passive recording to AI-ready test blueprints — requires zero manual configuration when using `ColossusPlugin`.

### How It Works

```
Shade (recording) → Scout (analysis) → Terrain (graph)
                                           ↓
                              Gauntlet (edge-case generation)
                                           ↓
                              Campaign (orchestrated execution)
                                           ↓
                              Verdict / Debrief (results)
```

1. **Shade** records user interactions as `ShadeSession` objects
2. **Scout** analyzes each session, extracting screen names and transitions
3. **Terrain** builds a directed graph of Outposts (screens) and Marches (transitions)
4. **Gauntlet** reads the Terrain and generates Stratagems targeting dead-ends, low-reliability edges, and orphaned screens
5. **Campaign** executes Stratagems in sequence with lifecycle management
6. **Verdict** captures per-step pass/fail results; **Debrief** aggregates campaign-level analysis

### Scout — Passive Session Analysis

Scout is a singleton that incrementally builds a Terrain from Shade sessions:

```dart
final scout = Scout.instance;

// Analyze a recorded session
scout.analyzeSession(session);

// Each session enriches the existing terrain
scout.analyzeSession(anotherSession);

// Access the live terrain
final terrain = scout.terrain;
```

With `autoLearnSessions: true` (the default), every completed Shade recording is automatically fed to Scout — no manual calls needed.

### Terrain — The Flow Graph

Terrain is a directed graph where:
- **Outpost** = a screen (identified by route path)
- **March** = a directed edge between two screens (a navigation transition)

```dart
final terrain = scout.terrain;

// Inspect the graph
print(terrain.outposts.length);   // Number of unique screens
print(terrain.marches.length);    // Number of unique transitions

// Find a specific screen
final screen = terrain.findOutpost('/quest/details');
print(screen?.visitCount);        // How many times visited
print(screen?.deadEnd);           // true if no outgoing transitions
print(screen?.reliability);       // Transition success rate

// Export for visualization or AI consumption
final mermaid = terrain.toMermaid();   // Mermaid graph diagram
final aiMap = terrain.toAiMap();       // Structured AI-ready map
```

### Lineage — Route Resolution

When Scout encounters paths like `/quest/42` or `/hero/7`, Lineage resolves them back to their registered patterns:

```dart
final parameterizer = RouteParameterizer();
parameterizer.registerPattern('/quest/:id');
parameterizer.registerPattern('/hero/:heroId/quest/:questId');

// Resolves concrete paths to patterns
parameterizer.resolve('/quest/42');           // → '/quest/:id'
parameterizer.resolve('/hero/7/quest/99');    // → '/hero/:heroId/quest/:questId'
parameterizer.resolve('/settings');           // → '/settings' (no pattern match)
```

With `autoAtlasIntegration: true`, route patterns are pre-seeded from Atlas's trie — no manual registration required.

### Gauntlet — Edge-Case Test Generation

Gauntlet reads the Terrain and generates **Stratagems** — test plans targeting weak spots:

```dart
final gauntlet = Gauntlet(terrain: scout.terrain);

// Generate for a specific screen
final stratagems = gauntlet.forOutpost('/quest/details');

// Generate for the entire terrain
final all = gauntlet.forAll();

for (final s in all) {
  print('${s.name}: ${s.steps.length} steps, '
        'targets: ${s.targetOutposts.join(", ")}');
}
```

Gauntlet targets:
- **Dead-end screens** — screens with no outgoing transitions
- **Low-reliability edges** — transitions that fail often
- **Orphaned screens** — screens reachable only from one path
- **High-traffic bottlenecks** — screens with many incoming transitions
- **Back-navigation gaps** — screens that users frequently back out of

### Campaign — Test Orchestration

Campaign executes a batch of Stratagems with full lifecycle management:

```dart
final campaign = Campaign(
  stratagems: gauntlet.forAll(),
  onSetup: () async {
    // Initialize test environment, seed data, etc.
  },
  onTeardown: () async {
    // Clean up test state
  },
);

final debrief = await campaign.execute();
```

### Verdict & Debrief — Results

**Verdict** captures per-step results:

```dart
for (final verdict in debrief.verdicts) {
  print('${verdict.step}: ${verdict.outcome}');
  if (verdict.outcome == VerdictOutcome.fail) {
    print('  Error: ${verdict.error}');
    print('  Fix: ${verdict.fixSuggestion}');
  }
}
```

**Debrief** aggregates campaign-level analysis:

```dart
print(debrief.passRate);           // e.g. 0.85
print(debrief.failedVerdicts);     // List<Verdict> that failed
print(debrief.fixSuggestions);     // AI-ready fix recommendations
print(debrief.duration);           // Total execution time
```

### Blueprint Lens Tab

The Blueprint tab adds a 5-sub-tab interactive interface to the Lens overlay:

| Sub-tab | What it shows |
|---------|---------------|
| **Terrain** | Mermaid graph visualization, AI map export, dead-end/conflict detection |
| **Stratagem** | Browse auto-generated test plans with expandable detail cards |
| **Verdict** | Step-by-step test results with pass/fail/skip rows and fix suggestions |
| **Lineage** | Route resolution metrics, Signet analysis, pattern matching stats |
| **Campaign** | Campaign execution timeline, debrief summaries, pass rate charts |

The Blueprint tab auto-refreshes when Scout analyzes new sessions, thanks to the `terrainNotifier` ChangeNotifier.

### Zero-Code Auto-Integration

With `ColossusPlugin`, the entire Blueprint pipeline wires itself automatically:

```dart
ColossusPlugin(
  tremors: [Tremor.fps(), Tremor.leaks()],
  // All three default to true:
  enableTableauCapture: true,     // Shade records screen metadata
  autoLearnSessions: true,        // Shade → Scout auto-feed
  autoAtlasIntegration: true,     // Auto-wire Atlas observer & routes
)
```

What happens behind the scenes:

1. **`autoLearnSessions`**: Chains onto `shade.onRecordingStopped` so every completed recording is automatically fed to `Scout.analyzeSession()`
2. **`autoAtlasIntegration`**: Registers a `ColossusAtlasObserver` for page-load timing, pre-seeds `RouteParameterizer` with patterns from `Atlas.registeredPatterns`, and sets `shade.getCurrentRoute` from Atlas
3. **`enableTableauCapture`**: Passed through to `Colossus.init()` for Shade tableau metadata
4. **`terrainNotifier`**: Fires after each Scout analysis, triggering Blueprint Lens Tab auto-refresh

All integration is try-catch wrapped — if Atlas isn't available, Colossus gracefully degrades without errors.

---

## AI-Bridge Export

The AI Blueprint Generation pipeline builds rich data at **runtime** — but AI assistants like Copilot and Claude operate at **IDE time**. The AI-Bridge Export layer closes this gap by exporting Blueprint data to disk in formats that AI tools can consume.

### The Problem

```
Runtime (app running)          IDE-time (Copilot/Claude)
━━━━━━━━━━━━━━━━━━━━          ━━━━━━━━━━━━━━━━━━━━━━━━
Scout → Terrain                ← "What's in the Terrain?"
Gauntlet → Stratagems          ← "What tests should I write?"
Campaign → Verdicts            ← "What failed last time?"
Debrief → Fix suggestions      ← "How do I fix this?"
```

Without export, Copilot has no access to the navigation graph, test plans, or past results. AI-Bridge Export solves this with four complementary strategies.

### Strategy 1: Auto-Export on App Shutdown

The simplest approach — add one parameter to `ColossusPlugin`:

```dart
ColossusPlugin(
  blueprintExportDirectory: '.titan',
)
```

When the app shuts down (`onDetach`), the plugin automatically:
1. Creates a `BlueprintExport` from the current Scout state
2. Saves `.titan/blueprint.json` (structured data for MCP tools)
3. Saves `.titan/blueprint-prompt.md` (AI-ready Markdown summary)

This is fire-and-forget — no manual intervention required.

### Strategy 2: Programmatic Export

For finer control, use `BlueprintExport` and `BlueprintExportIO` directly:

```dart
// Create export from live Scout state
final export = BlueprintExport.fromScout(
  scout: Scout.instance,
  verdicts: recentVerdicts,   // Optional: include test results
  intensity: GauntletIntensity.thorough,
);

// Save to disk
final result = await BlueprintExportIO.saveAll(
  export,
  directory: '.titan',
);

print(result.json);    // .titan/blueprint.json
print(result.prompt);  // .titan/blueprint-prompt.md

// Or get raw data without writing files
final jsonString = export.toJsonString();
final aiPrompt = export.toAiPrompt();
```

### Strategy 3: Offline CLI Export

Export a Blueprint from previously saved Shade session files — useful for CI/CD pipelines or team-shared session archives:

```bash
cd packages/titan_colossus

# Basic export (default: .titan/sessions → .titan/)
fvm dart run titan_colossus:export_blueprint

# Full options
fvm dart run titan_colossus:export_blueprint \
  --sessions-dir .titan/sessions \
  --output-dir .titan \
  --patterns /quest/:id,/hero/:heroId \
  --intensity thorough

# AI prompt only (skip JSON)
fvm dart run titan_colossus:export_blueprint --prompt-only
```

The CLI tool:
1. Loads all JSON session files from `--sessions-dir`
2. Feeds them through Scout analysis
3. Generates Stratagems via Gauntlet
4. Writes `blueprint.json` and `blueprint-prompt.md` to `--output-dir`

### Strategy 4: MCP Server

The Blueprint MCP Server exposes Blueprint data directly to AI assistants via the [Model Context Protocol](https://modelcontextprotocol.io/):

```json
// .vscode/settings.json
{
  "github.copilot.chat.mcpServers": {
    "titan-blueprint": {
      "command": "dart",
      "args": ["run", "titan_colossus:blueprint_mcp_server"],
      "cwd": "${workspaceFolder}/packages/titan_colossus"
    }
  }
}
```

Available MCP tools:

| Tool | Description |
|------|-------------|
| `get_terrain` | Full navigation graph (json, mermaid, or ai_map format) |
| `get_stratagems` | Generated test plans, filterable by route |
| `get_ai_prompt` | AI-ready Markdown summary of the entire Blueprint |
| `get_dead_ends` | Screens with no outgoing transitions |
| `get_unreliable_routes` | Transitions with low reliability scores |
| `get_route_patterns` | Registered parameterized route patterns |

The MCP server reads from `.titan/blueprint.json` and caches results until the file changes on disk.

### BlueprintExport Data Structure

The exported `blueprint.json` contains:

```json
{
  "version": "1.0.0",
  "exportedAt": "2025-03-15T10:30:00.000Z",
  "terrain": { /* Full Terrain graph with Outposts & Marches */ },
  "aiMap": "APP TERRAIN MAP\n===============\n...",
  "mermaid": "graph LR\n  home[/home] -->|tap| quest_list[/quests]\n...",
  "stratagems": [ /* Generated test plans */ ],
  "lineage": {
    "patterns": ["/quest/:id", "/hero/:heroId"],
    "totalScreens": 12,
    "totalTransitions": 18,
    "sessionsAnalyzed": 47
  },
  "verdicts": [ /* Previous test results (if available) */ ],
  "debrief": { /* Aggregated analysis (if verdicts exist) */ },
  "metadata": { "source": "offline", "sessionsAnalyzed": 47 }
}
```

### Loading Exported Data

Read back a saved Blueprint programmatically:

```dart
// Load terrain from a blueprint.json file
final terrain = await BlueprintExportIO.loadTerrain(
  '.titan/blueprint.json',
);

// Load sessions from a directory of JSON files
final sessions = await BlueprintExportIO.loadSessions(
  '.titan/sessions',
);

// Re-analyze with fresh settings
final export = BlueprintExport.fromSessions(
  sessions: sessions,
  routePatterns: ['/quest/:id'],
  intensity: GauntletIntensity.thorough,
);
```

---

## Testing

```bash
cd packages/titan_colossus && fvm flutter test  # 1197+ tests
```

---

[← Argus Auth](13-argus-auth.md) · [Migration Guide →](10-migration-guide.md)
