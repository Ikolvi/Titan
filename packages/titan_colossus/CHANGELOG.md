# Changelog

## [1.3.0] - 2026-03-06

### Added

#### AI Blueprint Generation — Six-Phase Discovery & Testing Engine
- **Scout** — Passive session analyzer that builds a flow graph (Terrain) from recorded Shade sessions. Discovers screens, transitions, and interactive elements automatically.
- **Terrain** — Flow graph model storing discovered routes (Outposts), transitions (Marches), and structural metadata (dead ends, unreliable transitions, auth-protected screens). Exports to Mermaid diagrams and AI-ready maps.
- **Outpost** — Discovered screen node with route pattern, interactive elements, display elements, and dimensional info.
- **March** — Discovered transition edge with source/destination routes, trigger type, trigger element, timing, and reliability score.
- **Lineage** — Prerequisite chain resolver that computes the navigation steps required to reach any screen from the app's entry point. Outputs AI-consumable setup instructions.
- **Gauntlet** — Edge-case test generator that produces targeted Stratagems for specific screens based on their interactive elements (taps, long-presses, text inputs, scrolls, boundary values).
- **Stratagem** — Executable test step specification with route, action, expected outcomes, and metadata. Serializable to/from JSON for AI consumption. Includes `StratagemRunner` for headless execution.
- **Campaign** — Multi-route test orchestrator that sequences Stratagems across flows, managing setup, execution, and teardown. Supports JSON campaign definitions.
- **Verdict** — Per-Stratagem execution result with pass/fail, timing, error details, and captured Tableau snapshots. Rich equality and serialization.
- **Debrief** — Verdict analyzer that produces structured reports with pass/fail ratios, failure categorization, fix suggestions, and AI-ready summaries.
- **RouteParameterizer** — Normalizes dynamic route segments (e.g., `/user/42` → `/user/:id`) for consistent terrain mapping.
- **Signet** — Screen identity fingerprint using interactive element hashing for change detection across sessions.

#### AI-Bridge Export — Bringing Blueprint Data to IDE-Time AI Assistants
- **BlueprintExport** — Structured container for exporting `Terrain`, `Stratagem`s, `Verdict`s, and `Debrief` results to disk. Factory constructors `fromScout()` (live app) and `fromSessions()` (offline analysis). Serializes to JSON via `toJson()`/`toJsonString()` and generates AI-ready Markdown prompts via `toAiPrompt()`.
- **BlueprintExportIO** — File I/O utilities: `save()` writes `blueprint.json`, `savePrompt()` writes `blueprint-prompt.md`, `saveAll()` writes both. `loadTerrain()` and `loadSessions()` for offline consumption. Auto-creates directories.
- **Export CLI** (`bin/export_blueprint.dart`) — Command-line tool for offline Blueprint export from saved Shade sessions. Flags: `--sessions-dir`, `--output-dir`, `--patterns` (comma-separated route patterns), `--intensity` (quick/standard/thorough), `--prompt-only`, `--help`.
- **Blueprint MCP Server** (`bin/blueprint_mcp_server.dart`) — Model Context Protocol server exposing Blueprint data to AI assistants (Copilot, Claude) over stdio. Tools: `get_terrain` (json/mermaid/ai_map), `get_stratagems`, `get_ai_prompt`, `get_dead_ends`, `get_unreliable_routes`, `get_route_patterns`. File-level caching with automatic invalidation.
- **`blueprintExportDirectory`** on **ColossusPlugin** — Set a directory path (e.g., `'.titan'`) and the plugin auto-exports `blueprint.json` + `blueprint-prompt.md` on app shutdown via `onDetach()`. Fire-and-forget for zero-friction developer experience.

#### Blueprint Lens Tab — Interactive Debug Overlay
- **BlueprintLensTab** — Lens plugin with five interactive sub-tabs:
  - **Terrain** — Live flow graph metrics (screens, transitions, sessions, dead ends, unreliable transitions) with reactive auto-refresh
  - **Lineage** — Route selector and prerequisite chain viewer with copy-to-clipboard actions
  - **Gauntlet** — Edge-case generator with intensity selector, stratagem cards, and pattern count display
  - **Campaign** — JSON campaign builder with execute/copy actions and result display
  - **Debrief** — Verdict analysis with insights, fix suggestions, and AI summary export

#### Zero-Code Auto-Integration
- **`autoLearnSessions`** — When `true` (default), completed Shade recordings are automatically fed to Scout. No manual `learnFromSession()` wiring needed.
- **`terrainNotifier`** — `ChangeNotifier` that fires after every `learnFromSession()` call. Blueprint Lens Tab subscribes automatically for live-updating metrics.
- **`autoAtlasIntegration`** — When `true` (default), ColossusPlugin automatically:
  - Registers `ColossusAtlasObserver` for page-load timing via `Atlas.addObserver()`
  - Pre-seeds `RouteParameterizer` with declared Atlas route patterns via `Atlas.registeredPatterns`
  - Auto-wires `Shade.getCurrentRoute` via `Atlas.current.path` (only if not user-provided)
  - Gracefully degrades if Atlas is not present or not initialized
- **`enableTableauCapture`** — Defaults to `true` in ColossusPlugin (vs `false` in `Colossus.init()` for backward compatibility). Required for Scout discovery.

### Changed
- **ColossusPlugin** — Three new configuration parameters: `enableTableauCapture`, `autoLearnSessions`, `autoAtlasIntegration`. All default to `true` for zero-configuration setup.
- **Colossus.init()** — New `autoLearnSessions` parameter (default: `true`). Colossus now owns the Shade → Scout → Terrain pipeline internally.

## [1.2.0] - 2026-03-05

### Fixed
- **Shade session persistence** — Recorded sessions now survive Lens hide/show cycles. Session is stored on `Colossus` instance instead of disposed Pillar.

### Added
- **Auto-show Lens after FAB stop** — Lens overlay automatically opens when stopping a recording via the floating action button.
- **Draggable FAB** — Lens floating button can be dragged to any position. Position persists across hide/show. Added `Lens.resetFabPosition()` to restore defaults.

### Changed
- **Plugin tabs first** — Plugin tabs (Shade) now appear before built-in tabs (Pillars, Herald, Vigil, Chronicle) in the Lens panel.

## [1.1.0] - 2026-03-04

### Added
- **ColossusPlugin** — One-line `TitanPlugin` adapter for full Colossus integration. Add or remove performance monitoring with a single line in `Beacon(plugins: [...])`
  - Manages `Colossus.init()`, `Lens` overlay, `ShadeListener`, export/route callbacks, auto-replay, and `Colossus.shutdown()` automatically

## [1.0.4] - 2026-03-04

### Changed
- **Assert → Runtime Errors**: `Phantom` speedMultiplier validation and `Colossus.instance` guard changed from debug-only `assert` to runtime errors (`ArgumentError` / `StateError`)

## [1.0.3] - 2026-03-04

### Changed
- Updated `titan` dependency to `^1.1.0`

## [1.0.2] - 2026-03-03

### Added
- Example file for pub.dev documentation score

### Changed
- Updated `titan` dependency to `^1.0.1`
- Updated `titan_bastion` dependency to `^1.0.1`
- Updated `titan_atlas` dependency to `^1.0.1`

## [1.0.1] - 2026-03-02

- **Lens** — `Lens`, `LensPlugin`, and `LensLogSink` moved here from `titan_bastion`. Import from `package:titan_colossus/titan_colossus.dart`.

## 1.0.0

- Initial release
- **Colossus** — Enterprise performance monitoring Pillar
- **Pulse** — Frame metrics (FPS, jank detection, build/raster timing)
- **Stride** — Page load timing with Atlas integration
- **Vessel** — Memory monitoring and leak detection
- **Echo** — Widget rebuild tracking
- **Tremor** — Configurable performance alerts via Herald
- **Decree** — Performance report generation
- **Lens integration** — Plugin tab for the Lens debug overlay
- **ColossusAtlasObserver** — Automatic route timing via Atlas
