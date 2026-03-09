# Titan Forge — VS Code Extension Feature Plan

## "The Brain Sees, the Hands Touch, the Forge Unites"

**Status**: Design Document
**Package**: `titan_forge` (new VS Code extension)
**Dependencies**: `titan_colossus` (Scry, Relay, MCP), platform automation tools
**Estimated Scope**: ~8,000 lines TypeScript, ~2,000 lines tests

---

## Table of Contents

1. [Vision](#1-vision)
2. [Architecture Overview](#2-architecture-overview)
3. [Layer Model — Brain + Hands](#3-layer-model--brain--hands)
4. [Phase 1: Foundation — Extension Shell & Relay Client](#4-phase-1-foundation--extension-shell--relay-client)
5. [Phase 2: Live Mirror — Screenshot Panel & Click-to-Interact](#5-phase-2-live-mirror--screenshot-panel--click-to-interact)
6. [Phase 3: Element Inspector — Widget Tree Panel](#6-phase-3-element-inspector--widget-tree-panel)
7. [Phase 4: Platform Bridge — OS-Level Touch Injection](#7-phase-4-platform-bridge--os-level-touch-injection)
8. [Phase 5: AI Vision — System Dialog Understanding](#8-phase-5-ai-vision--system-dialog-understanding)
9. [Phase 6: Unified Testing — Cross-Layer Test Orchestration](#9-phase-6-unified-testing--cross-layer-test-orchestration)
10. [Phase 7: Copilot Integration — MCP Tool Provider](#10-phase-7-copilot-integration--mcp-tool-provider)
11. [Platform Support Matrix](#11-platform-support-matrix)
12. [Technical Implementation Details](#12-technical-implementation-details)
13. [JSON Schemas & APIs](#13-json-schemas--apis)
14. [Example Workflows](#14-example-workflows)
15. [Security Considerations](#15-security-considerations)
16. [Milestones & Timeline](#16-milestones--timeline)

---

## 1. Vision

### The Problem

Currently, Titan Colossus provides powerful AI-driven app interaction via MCP tools
(Scry, Shade, Campaign, Gauntlet). But it has two fundamental limitations:

1. **Flutter-only**: Scry reads Flutter's `RenderObject` tree — system permission
   dialogs, third-party SDK overlays (ads, payments), and OS notifications are
   invisible because they render outside Flutter's engine.

2. **Terminal-only**: The MCP server runs via stdio/SSE — there's no visual
   interface showing the app state, no click-to-interact, no element inspector
   panel. AI assistants work blind, relying on text descriptions.

### The Solution

**Titan Forge** is a VS Code extension that combines two complementary layers:

| Layer | Name | What It Does |
|-------|------|-------------|
| **Brain** | Titan Colossus (Scry/Relay) | Semantic understanding of Flutter widgets — labels, types, keys, state, accessibility |
| **Hands** | Platform Bridge | OS-level touch injection via scrcpy/adb (Android), macOS Accessibility (desktop), iPhone Mirroring (iOS) |

Together: **the Brain knows WHAT to touch, the Hands can touch ANYTHING on screen.**

### The Metaphor

> The **Forge** is where raw materials become weapons. The Scout's intelligence
> (Brain) meets the Titan's physical reach (Hands). Inside the Forge, the
> AI smith can see every corner of the battlefield — Flutter widgets, system
> dialogs, native overlays — and strike precisely.

### Design Principles

1. **Two-layer architecture**: Semantic (Relay) for Flutter UI, Visual (OS) for
   everything else. Each layer is independently useful; together they're complete.
2. **Zero-config discovery**: Auto-detect running Flutter apps with Relay enabled.
   Auto-detect connected Android devices. Auto-detect available simulators.
3. **Click-to-interact**: Show live screenshots in a VS Code panel. Click on
   the screenshot to tap on the app. Drag to swipe.
4. **AI-native**: Every panel provides data that AI assistants can consume.
   The extension IS an MCP tool provider for Copilot Chat.
5. **Cross-platform**: Works on macOS, Windows, and Linux. Connects to iOS,
   Android, Web, Desktop apps.

---

## 2. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                      VS Code Extension                       │
│                        (Titan Forge)                          │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────┐ │
│  │ Screenshot   │  │ Element     │  │ Controls             │ │
│  │ Panel        │  │ Inspector   │  │ Panel                │ │
│  │              │  │ (Tree View) │  │                      │ │
│  │ • Live view  │  │ • Widgets   │  │ • Record/Stop        │ │
│  │ • Click tap  │  │ • Buttons   │  │ • Export Blueprint    │ │
│  │ • Drag swipe │  │ • Fields    │  │ • Run Campaign       │ │
│  │ • Annotate   │  │ • Nav tabs  │  │ • Performance stats  │ │
│  └──────┬───┬──┘  └──────┬──────┘  └───────┬──────────────┘ │
│         │   │            │                  │                │
│  ┌──────▼───▼────────────▼──────────────────▼──────────────┐ │
│  │                    Core Engine                           │ │
│  │                                                          │ │
│  │  ┌──────────────┐    ┌────────────────────────────────┐  │ │
│  │  │ Relay Client │    │ Platform Bridge                │  │ │
│  │  │ (WebSocket)  │    │                                │  │ │
│  │  │              │    │ ┌───────┐ ┌──────┐ ┌────────┐  │  │ │
│  │  │ • Scry       │    │ │ scrcpy│ │ ADB  │ │ macOS  │  │  │ │
│  │  │ • Campaign   │    │ │ Stream│ │Input │ │Access. │  │  │ │
│  │  │ • Shade      │    │ └───────┘ └──────┘ └────────┘  │  │ │
│  │  │ • Screenshot │    │ ┌───────┐ ┌──────┐ ┌────────┐  │  │ │
│  │  │ • Events     │    │ │ iPhone│ │Windows│ │ Linux  │  │  │ │
│  │  │ • Metrics    │    │ │Mirror │ │UIAuto│ │xdotool │  │  │ │
│  │  └──────┬───────┘    │ └───────┘ └──────┘ └────────┘  │  │ │
│  │         │            └──────────────┬─────────────────┘  │ │
│  └─────────┼───────────────────────────┼────────────────────┘ │
│            │                           │                      │
└────────────┼───────────────────────────┼──────────────────────┘
             │                           │
    ┌────────▼────────┐        ┌─────────▼──────────┐
    │ Flutter App     │        │ Device / OS        │
    │ (any platform)  │        │                    │
    │                 │        │ • System dialogs   │
    │ ColossusPlugin  │        │ • Native overlays  │
    │ + Relay server  │        │ • Third-party SDK  │
    │ + Scry engine   │        │ • Notifications    │
    └─────────────────┘        └────────────────────┘
```

### Data Flow

```
User clicks on screenshot panel at (x, y)
    → Forge checks: Is this position within a Flutter widget? (via Scry glyph bounds)
        YES → Use Relay: scry_act(tap, label: "widget_name")
              Precise, semantic, uses widget key/label
        NO  → Use Platform Bridge: OS-level tap at screen coordinates
              Works for system dialogs, native overlays
    → App processes the touch event
    → Forge captures new screenshot
    → Forge updates element inspector tree
    → Forge shows diff of what changed
```

---

## 3. Layer Model — Brain + Hands

### Layer 1: Brain (Titan Colossus / Relay)

**What it provides:**
- Complete Flutter widget tree with semantic labels, types, keys
- Element reachability and interactivity state
- Form status, tab order, scroll position
- Navigation route history
- Performance metrics (frame rate, memory, page loads)
- Recording/replay capabilities (Shade)
- AI test generation (Gauntlet, Campaign)

**What it cannot access:**
- OS permission dialogs (camera, location, notifications)
- Native overlays (AdMob banners, payment sheets)
- System UI (status bar, notification center)
- Third-party SDK screens rendered outside Flutter

**Connection**: WebSocket to Relay server running inside the Flutter app.

### Layer 2: Hands (Platform Bridge)

**What it provides:**
- Touch/tap injection at any screen coordinate
- Screenshot capture of the ENTIRE screen (including system UI)
- Swipe, long-press, and multi-touch gestures
- Keyboard input simulation
- Window/app management (focus, resize, close)

**What it cannot provide:**
- Semantic understanding (what IS the button at those coordinates?)
- Widget state (is this field enabled? what's its value?)
- Flutter-specific data (route history, DI container, performance metrics)

**Connection**: Platform-specific tools (scrcpy/adb, macOS Accessibility API,
iPhone Mirroring, xdotool, etc.)

### Layer 3: Vision (AI Understanding)

**What it provides:**
- OCR extracted text from screenshots of non-Flutter UI
- AI-analyzed button labels, dialog messages, error text
- Decision-making: "tap Allow on the permission dialog"
- Layout understanding from visual analysis

**Connection**: AI model API (Claude, GPT-4o) with inline image analysis.

### Unified Decision Flow

```
┌────────────────────────────────────────────────┐
│            Forge Decision Engine               │
│                                                │
│  Input: "Tap the Allow button"                 │
│                                                │
│  1. Check Scry glyphs for "Allow" button       │
│     └─ Found? → Relay: scry_act(tap, "Allow")  │
│                                                │
│  2. Not found in Flutter → Take OS screenshot  │
│     └─ Send to AI Vision: "Find 'Allow'"       │
│     └─ AI returns coordinates: (540, 1200)     │
│                                                │
│  3. Platform Bridge: tap(540, 1200)            │
│     └─ adb shell input tap 540 1200            │
│     └─ or cliclick c:540,1200                  │
│     └─ or xdotool mousemove 540 1200 click 1   │
│                                                │
│  4. Verify: retake screenshot, confirm change  │
└────────────────────────────────────────────────┘
```

---

## 4. Phase 1: Foundation — Extension Shell & Relay Client

### 4.1 Overview

Create the VS Code extension project, implement auto-discovery of running
Flutter apps with Relay, and establish the WebSocket communication layer.

### 4.2 Extension Structure

```
titan_forge/
├── package.json              # Extension manifest
├── tsconfig.json
├── src/
│   ├── extension.ts          # Activation, command registration
│   ├── relay/
│   │   ├── client.ts         # WebSocket client for Relay
│   │   ├── discovery.ts      # Auto-discover Relay endpoints
│   │   └── types.ts          # TypeScript types for Relay protocol
│   ├── panels/
│   │   ├── screenshot.ts     # Screenshot webview panel
│   │   ├── controls.ts       # Controls panel (record, campaign, etc.)
│   │   └── inspector.ts      # Element inspector tree view
│   ├── bridge/
│   │   ├── platform.ts       # Platform detection & bridge factory
│   │   ├── android.ts        # scrcpy/adb bridge
│   │   ├── macos.ts          # macOS Accessibility bridge
│   │   ├── windows.ts        # Windows UI Automation bridge
│   │   ├── linux.ts          # xdotool bridge
│   │   └── ios.ts            # iPhone Mirroring / idevice bridge
│   ├── vision/
│   │   ├── analyzer.ts       # AI Vision screenshot analysis
│   │   └── ocr.ts            # OCR fallback for text extraction
│   ├── mcp/
│   │   └── provider.ts       # MCP tool provider for Copilot Chat
│   └── utils/
│       ├── config.ts         # Extension settings
│       └── logger.ts         # Output channel logging
├── media/
│   ├── screenshot.html       # Screenshot panel HTML
│   └── icons/                # Extension icons
└── test/
    └── suite/
        ├── relay.test.ts
        ├── bridge.test.ts
        └── vision.test.ts
```

### 4.3 Extension Manifest (package.json)

```json
{
  "name": "titan-forge",
  "displayName": "Titan Forge",
  "description": "AI-powered Flutter app interaction — see, touch, and test any screen element",
  "version": "0.1.0",
  "publisher": "ikolvi",
  "engines": { "vscode": "^1.85.0" },
  "categories": ["Testing", "Debuggers", "Other"],
  "keywords": ["flutter", "dart", "testing", "automation", "ai"],
  "activationEvents": [
    "workspaceContains:pubspec.yaml",
    "onCommand:titanForge.connect"
  ],
  "main": "./dist/extension.js",
  "contributes": {
    "commands": [
      { "command": "titanForge.connect", "title": "Titan Forge: Connect to App" },
      { "command": "titanForge.screenshot", "title": "Titan Forge: Show Live Mirror" },
      { "command": "titanForge.scry", "title": "Titan Forge: Observe Screen" },
      { "command": "titanForge.tap", "title": "Titan Forge: Tap Element" },
      { "command": "titanForge.record", "title": "Titan Forge: Start Recording" },
      { "command": "titanForge.stopRecord", "title": "Titan Forge: Stop Recording" },
      { "command": "titanForge.runCampaign", "title": "Titan Forge: Run Campaign" },
      { "command": "titanForge.inspector", "title": "Titan Forge: Show Element Inspector" }
    ],
    "viewsContainers": {
      "activitybar": [
        {
          "id": "titanForge",
          "title": "Titan Forge",
          "icon": "media/icons/forge.svg"
        }
      ]
    },
    "views": {
      "titanForge": [
        { "id": "titanForge.devices", "name": "Devices" },
        { "id": "titanForge.elements", "name": "Elements" },
        { "id": "titanForge.performance", "name": "Performance" },
        { "id": "titanForge.recordings", "name": "Recordings" }
      ]
    },
    "configuration": {
      "title": "Titan Forge",
      "properties": {
        "titanForge.relayPort": {
          "type": "number",
          "default": 8080,
          "description": "Default Relay WebSocket port"
        },
        "titanForge.autoDiscover": {
          "type": "boolean",
          "default": true,
          "description": "Auto-discover running Flutter apps with Relay"
        },
        "titanForge.screenshotInterval": {
          "type": "number",
          "default": 1000,
          "description": "Screenshot refresh interval (ms)"
        },
        "titanForge.adbPath": {
          "type": "string",
          "default": "adb",
          "description": "Path to adb executable"
        },
        "titanForge.scrcpyPath": {
          "type": "string",
          "default": "scrcpy",
          "description": "Path to scrcpy executable"
        },
        "titanForge.aiVisionEnabled": {
          "type": "boolean",
          "default": false,
          "description": "Enable AI Vision for non-Flutter UI understanding"
        }
      }
    }
  }
}
```

### 4.4 Relay Client

```typescript
// src/relay/client.ts

import WebSocket from 'ws';

interface RelayMessage {
  id: string;
  method: string;
  params?: Record<string, unknown>;
}

interface RelayResponse {
  id: string;
  result?: unknown;
  error?: { code: number; message: string };
}

export class RelayClient {
  private ws: WebSocket | null = null;
  private pending = new Map<string, {
    resolve: (value: unknown) => void;
    reject: (reason: Error) => void;
  }>();
  private messageId = 0;

  constructor(private url: string) {}

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);
      this.ws.on('open', () => resolve());
      this.ws.on('error', (err) => reject(err));
      this.ws.on('message', (data) => this.handleMessage(data.toString()));
    });
  }

  async send(method: string, params?: Record<string, unknown>): Promise<unknown> {
    const id = `msg_${++this.messageId}`;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws?.send(JSON.stringify({ id, method, params }));
    });
  }

  // Convenience methods matching Relay protocol
  async scry(): Promise<ScryGaze> { ... }
  async scryAct(action: string, label?: string, ...): Promise<ScryResult> { ... }
  async captureScreenshot(): Promise<Buffer> { ... }
  async startRecording(name?: string): Promise<void> { ... }
  async stopRecording(): Promise<void> { ... }
  async getWidgetTree(): Promise<WidgetNode[]> { ... }
  async getPerformance(): Promise<PerformanceData> { ... }
  async getEvents(): Promise<EventData[]> { ... }
}
```

### 4.5 Auto-Discovery

```typescript
// src/relay/discovery.ts

export class RelayDiscovery {
  /**
   * Scan common ports for Relay servers.
   * Checks: 8080, 8081, 9090, and any port in settings.
   */
  async discover(): Promise<RelayEndpoint[]> {
    const ports = [8080, 8081, 9090];
    const endpoints: RelayEndpoint[] = [];

    for (const port of ports) {
      try {
        const ws = new WebSocket(`ws://localhost:${port}/ws`);
        // Try to connect and send a health check
        const response = await this.probe(ws);
        if (response.isTitanRelay) {
          endpoints.push({
            url: `ws://localhost:${port}/ws`,
            appName: response.appName,
            platform: response.platform,
            port,
          });
        }
      } catch {
        // Not a Relay server, skip
      }
    }

    return endpoints;
  }

  /**
   * Also discover Android devices via adb.
   */
  async discoverAndroid(): Promise<AndroidDevice[]> {
    // Run: adb devices -l
    // Parse output for connected devices
    // For each device, check if port forwarding is needed
  }

  /**
   * Discover iOS simulators via xcrun.
   */
  async discoverIosSimulators(): Promise<Simulator[]> {
    // Run: xcrun simctl list devices -j
    // Parse JSON for booted simulators
  }
}
```

### 4.6 Deliverables

- [ ] Extension project scaffolding with TypeScript build
- [ ] WebSocket Relay client with full protocol support
- [ ] Auto-discovery of Relay endpoints (localhost scan)
- [ ] Auto-discovery of Android devices (adb)
- [ ] Auto-discovery of iOS simulators (simctl)
- [ ] Status bar item showing connection state
- [ ] Output channel for logging
- [ ] Extension settings (port, paths, intervals)

---

## 5. Phase 2: Live Mirror — Screenshot Panel & Click-to-Interact

### 5.1 Overview

Show a live screenshot of the running app in a VS Code webview panel.
Users can click on the screenshot to tap elements, drag to swipe, and
see real-time updates.

### 5.2 Screenshot Panel

The panel displays a continuously-refreshed screenshot (via Relay's
`capture_screenshot` or OS-level capture). Clicking on the image
translates pixel coordinates to either:

1. **Scry target** (if the click lands on a known Flutter widget) →
   accurate, semantic interaction via Relay
2. **OS-level tap** (if outside Flutter's render tree) → raw coordinate,
   platform-specific injection

```
┌──────────────────────────────────┐
│  Titan Forge — Live Mirror       │
│  ┌────────────────────────────┐  │
│  │                            │  │
│  │   [Screenshot of app]      │  │
│  │                            │  │
│  │   ┌──────────────┐        │  │
│  │   │ Allow Camera │ ← OS   │  │
│  │   │    Access    │  dialog│  │
│  │   ├──────────────┤        │  │
│  │   │ Allow │ Deny │        │  │
│  │   └──────────────┘        │  │
│  │                            │  │
│  └────────────────────────────┘  │
│  ┌──────────┬──────────────────┐ │
│  │ 60 FPS   │ 128 MB  │ /home │ │
│  └──────────┴──────────────────┘ │
│  [Record]  [Scry]  [Campaign]    │
└──────────────────────────────────┘
```

### 5.3 Interaction Modes

| Mode | Trigger | Handler |
|------|---------|---------|
| **Tap** | Single click | Scry match → `scry_act(tap)` OR Platform Bridge `tap(x, y)` |
| **Swipe** | Click + drag | Relay `scry_act(swipe, direction)` OR Platform Bridge `swipe(x1, y1, x2, y2)` |
| **Long Press** | Click + hold (500ms) | Relay `scry_act(longPress)` OR Platform Bridge `longPress(x, y)` |
| **Text Entry** | Double-click on text field | Input dialog → Relay `scry_act(enterText, value)` |
| **Scroll** | Mouse wheel on panel | Relay `scry_act(scroll, direction)` OR Platform Bridge `scroll(x, y, delta)` |
| **Inspect** | Right-click | Show element details tooltip (widget type, key, bounds, state) |

### 5.4 Screenshot Sources

| Platform | Source | Refresh Rate |
|----------|--------|-------------|
| Web app | Relay `capture_screenshot` | ~1 FPS (WebSocket round-trip) |
| Desktop app | Relay `capture_screenshot` + OS window capture | ~2 FPS |
| Android | `adb exec-out screencap -p` or scrcpy stream | ~10 FPS |
| iOS Simulator | `xcrun simctl io booted screenshot -` | ~2 FPS |
| iOS Device | `pymobiledevice3` screenshot or iPhone Mirroring capture | ~1 FPS |

### 5.5 Coordinate Translation

```typescript
// Convert webview click position to app screen coordinates
function translateCoordinates(
  clickX: number,      // Click position in webview
  clickY: number,
  panelWidth: number,  // Webview panel dimensions
  panelHeight: number,
  appWidth: number,    // Actual app screen dimensions
  appHeight: number,
  devicePixelRatio: number,
): { appX: number; appY: number } {
  return {
    appX: (clickX / panelWidth) * appWidth * devicePixelRatio,
    appY: (clickY / panelHeight) * appHeight * devicePixelRatio,
  };
}

// Match coordinates to Scry glyph (Flutter widget)
function findGlyphAtPosition(
  appX: number,
  appY: number,
  glyphs: ScryGlyph[],
): ScryGlyph | null {
  // Sort by area (smallest first) to find most specific widget
  const sorted = glyphs
    .filter(g => appX >= g.x && appX <= g.x + g.w && appY >= g.y && appY <= g.y + g.h)
    .sort((a, b) => (a.w * a.h) - (b.w * b.h));
  return sorted[0] ?? null;
}
```

### 5.6 Deliverables

- [ ] Webview panel with screenshot display
- [ ] Auto-refresh screenshot (configurable interval)
- [ ] Click-to-tap with Scry glyph matching
- [ ] Drag-to-swipe gesture detection
- [ ] Mouse wheel scroll forwarding
- [ ] Right-click element inspection tooltip
- [ ] Coordinate translation for different device pixel ratios
- [ ] Status bar: FPS, memory, current route

---

## 6. Phase 3: Element Inspector — Widget Tree Panel

### 6.1 Overview

A VS Code Tree View in the sidebar showing all interactive elements
on the current screen, organized by type (Buttons, Fields, Navigation,
Content). Clicking an element highlights it on the screenshot panel
and provides interaction options.

### 6.2 Tree Structure

```
🏔️ Titan Forge
├── 📱 Devices
│   ├── 🌐 Flutter Web (localhost:8080) — Connected
│   ├── 📱 Pixel 7 (adb:R5CR1234) — Connected
│   └── 📱 iPhone 15 (sim:ABCD-1234) — Disconnected
├── 🔘 Elements
│   ├── 📝 Text Fields (2)
│   │   ├── Hero Name = "Kael" [TextField]
│   │   └── Quest Note = "" [TextField]
│   ├── 🔘 Buttons (5)
│   │   ├── Submit (FilledButton) → tap
│   │   ├── Cancel (OutlinedButton) → tap
│   │   ├── Delete ⚠️ (IconButton) → tap [requires permission]
│   │   ├── Back (IconButton) → tap
│   │   └── Menu (PopupMenuButton) → tap
│   ├── 🗂️ Navigation (3)
│   │   ├── Quests [selected]
│   │   ├── Hero
│   │   └── Settings
│   └── 📄 Content (8)
│       ├── "Welcome, Kael"
│       ├── "0 Glory • Novice"
│       └── ... 6 more
├── 📊 Performance
│   ├── Frame Rate: 60 FPS
│   ├── Memory: 128 MB
│   ├── Page Load: 245ms
│   └── Active Tremors: 0
└── 🎬 Recordings
    ├── ▶️ Start Recording
    ├── 📋 Session: login_flow (03:24)
    └── 📋 Session: quest_browse (01:12)
```

### 6.3 Element Actions (Context Menu)

Right-clicking an element in the tree shows:
- **Tap** — interact with the element
- **Copy Label** — copy the element's label text
- **Copy Key** — copy the widget key (if available)
- **Highlight** — flash the element on the screenshot panel
- **Inspect** — show full details (bounds, ancestry, state)
- **Enter Text** (for text fields) — show input dialog

### 6.4 Deliverables

- [ ] TreeDataProvider for Devices, Elements, Performance, Recordings
- [ ] Auto-refresh on Scry observation
- [ ] Context menu actions (tap, copy, inspect, highlight)
- [ ] Element highlighting on screenshot panel
- [ ] Performance metrics tree with live updates
- [ ] Recording management (start, stop, list, export)

---

## 7. Phase 4: Platform Bridge — OS-Level Touch Injection

### 7.1 Overview

Platform-specific adapters for sending touch events and capturing
screenshots at the OS level. This enables interaction with elements
that are invisible to Flutter (system dialogs, native overlays).

### 7.2 Platform Adapters

#### Android (scrcpy + adb)

```typescript
// src/bridge/android.ts

export class AndroidBridge implements PlatformBridge {
  constructor(
    private deviceId: string,
    private adbPath: string = 'adb',
  ) {}

  async tap(x: number, y: number): Promise<void> {
    await exec(`${this.adbPath} -s ${this.deviceId} shell input tap ${x} ${y}`);
  }

  async swipe(x1: number, y1: number, x2: number, y2: number, durationMs = 300): Promise<void> {
    await exec(`${this.adbPath} -s ${this.deviceId} shell input swipe ${x1} ${y1} ${x2} ${y2} ${durationMs}`);
  }

  async longPress(x: number, y: number, durationMs = 1000): Promise<void> {
    await exec(`${this.adbPath} -s ${this.deviceId} shell input swipe ${x} ${y} ${x} ${y} ${durationMs}`);
  }

  async type(text: string): Promise<void> {
    await exec(`${this.adbPath} -s ${this.deviceId} shell input text "${text}"`);
  }

  async pressKey(keycode: string): Promise<void> {
    await exec(`${this.adbPath} -s ${this.deviceId} shell input keyevent ${keycode}`);
  }

  async screenshot(): Promise<Buffer> {
    const { stdout } = await exec(
      `${this.adbPath} -s ${this.deviceId} exec-out screencap -p`,
      { encoding: 'buffer' },
    );
    return stdout;
  }

  async getAccessibilityTree(): Promise<UiAutomatorNode[]> {
    await exec(`${this.adbPath} -s ${this.deviceId} shell uiautomator dump /sdcard/ui_dump.xml`);
    const { stdout } = await exec(
      `${this.adbPath} -s ${this.deviceId} shell cat /sdcard/ui_dump.xml`,
    );
    return parseUiAutomatorXml(stdout);
  }

  async forwardPort(localPort: number, remotePort: number): Promise<void> {
    await exec(
      `${this.adbPath} -s ${this.deviceId} forward tcp:${localPort} tcp:${remotePort}`,
    );
  }
}
```

#### macOS Desktop

```typescript
// src/bridge/macos.ts

export class MacOSBridge implements PlatformBridge {
  constructor(private appName: string) {}

  async tap(x: number, y: number): Promise<void> {
    // Using cliclick for reliable mouse click simulation
    await exec(`cliclick c:${Math.round(x)},${Math.round(y)}`);
  }

  async swipe(x1: number, y1: number, x2: number, y2: number): Promise<void> {
    await exec(`cliclick dd:${x1},${y1} du:${x2},${y2}`);
  }

  async screenshot(): Promise<Buffer> {
    // Capture specific window
    const { stdout } = await exec(
      `screencapture -l $(osascript -e 'tell application "System Events" to ` +
      `return id of first window of process "${this.appName}"') -x -t png /dev/stdout`,
      { encoding: 'buffer' },
    );
    return stdout;
  }

  async getAccessibilityTree(): Promise<AccessibilityNode[]> {
    // Use osascript to query Accessibility API
    const script = `
      tell application "System Events"
        tell process "${this.appName}"
          return entire contents of window 1
        end tell
      end tell
    `;
    const { stdout } = await exec(`osascript -e '${script}'`);
    return parseAccessibilityOutput(stdout);
  }

  async focusWindow(): Promise<void> {
    await exec(`osascript -e 'tell application "${this.appName}" to activate'`);
  }
}
```

#### iOS Simulator

```typescript
// src/bridge/ios.ts

export class IOSSimulatorBridge implements PlatformBridge {
  constructor(private deviceId: string) {}

  async tap(x: number, y: number): Promise<void> {
    // simctl doesn't support direct tap, use AppleScript on Simulator.app
    const script = `
      tell application "Simulator"
        activate
      end tell
    `;
    await exec(`osascript -e '${script}'`);
    // Then use cliclick at the window position
    const windowPos = await this.getSimulatorWindowPosition();
    await exec(`cliclick c:${windowPos.x + x},${windowPos.y + y}`);
  }

  async screenshot(): Promise<Buffer> {
    const tmpFile = `/tmp/titan_sim_screenshot_${Date.now()}.png`;
    await exec(`xcrun simctl io ${this.deviceId} screenshot ${tmpFile}`);
    const buffer = await fs.readFile(tmpFile);
    await fs.unlink(tmpFile);
    return buffer;
  }

  async installApp(bundlePath: string): Promise<void> {
    await exec(`xcrun simctl install ${this.deviceId} ${bundlePath}`);
  }

  async launchApp(bundleId: string): Promise<void> {
    await exec(`xcrun simctl launch ${this.deviceId} ${bundleId}`);
  }
}
```

#### Windows

```typescript
// src/bridge/windows.ts

export class WindowsBridge implements PlatformBridge {
  async tap(x: number, y: number): Promise<void> {
    // PowerShell-based approach
    const script = `
      Add-Type -TypeDefinition @"
      using System;
      using System.Runtime.InteropServices;
      public class Win32 {
        [DllImport("user32.dll")]
        public static extern bool SetCursorPos(int X, int Y);
        [DllImport("user32.dll")]
        public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
      }
"@
      [Win32]::SetCursorPos(${x}, ${y})
      [Win32]::mouse_event(0x0002, 0, 0, 0, 0) # MOUSEEVENTF_LEFTDOWN
      [Win32]::mouse_event(0x0004, 0, 0, 0, 0) # MOUSEEVENTF_LEFTUP
    `;
    await exec(`powershell -Command "${script}"`);
  }

  async screenshot(): Promise<Buffer> {
    // Use PowerShell to capture screen
    // Or use external tool like nircmd
  }
}
```

#### Linux

```typescript
// src/bridge/linux.ts

export class LinuxBridge implements PlatformBridge {
  async tap(x: number, y: number): Promise<void> {
    await exec(`xdotool mousemove ${x} ${y} click 1`);
  }

  async swipe(x1: number, y1: number, x2: number, y2: number): Promise<void> {
    await exec(`xdotool mousemove ${x1} ${y1} mousedown 1`);
    await exec(`xdotool mousemove ${x2} ${y2} mouseup 1`);
  }

  async screenshot(): Promise<Buffer> {
    const { stdout } = await exec('import -window root png:-', { encoding: 'buffer' });
    return stdout;
  }

  async findWindow(title: string): Promise<number> {
    const { stdout } = await exec(`xdotool search --name "${title}"`);
    return parseInt(stdout.trim(), 10);
  }
}
```

### 7.3 Platform Bridge Interface

```typescript
// src/bridge/platform.ts

export interface PlatformBridge {
  // Touch gestures
  tap(x: number, y: number): Promise<void>;
  swipe(x1: number, y1: number, x2: number, y2: number, durationMs?: number): Promise<void>;
  longPress(x: number, y: number, durationMs?: number): Promise<void>;

  // Text input
  type?(text: string): Promise<void>;
  pressKey?(keycode: string): Promise<void>;

  // Screen capture
  screenshot(): Promise<Buffer>;

  // Accessibility (optional)
  getAccessibilityTree?(): Promise<AccessibilityNode[]>;

  // Window management (optional)
  focusWindow?(): Promise<void>;
}

export function createBridge(platform: 'android' | 'macos' | 'windows' | 'linux' | 'ios-sim'): PlatformBridge {
  switch (platform) {
    case 'android': return new AndroidBridge(deviceId);
    case 'macos': return new MacOSBridge(appName);
    case 'windows': return new WindowsBridge();
    case 'linux': return new LinuxBridge();
    case 'ios-sim': return new IOSSimulatorBridge(deviceId);
  }
}
```

### 7.4 Deliverables

- [ ] PlatformBridge interface with common API
- [ ] Android bridge (adb + scrcpy)
- [ ] macOS bridge (cliclick + osascript + screencapture)
- [ ] Windows bridge (PowerShell + Win32)
- [ ] Linux bridge (xdotool + import)
- [ ] iOS Simulator bridge (simctl + cliclick)
- [ ] Platform auto-detection
- [ ] Bridge health checks (verify tools installed)
- [ ] Accessibility tree parsing for Android (uiautomator XML)
- [ ] Accessibility tree parsing for macOS (AXUIElement)

---

## 8. Phase 5: AI Vision — System Dialog Understanding

### 8.1 Overview

When Scry can't identify an element (because it's native OS UI, not Flutter),
use AI Vision to analyze a screenshot and extract actionable information:
button labels, dialog text, input field positions.

### 8.2 AI Vision Pipeline

```
OS Screenshot (PNG)
    │
    ▼
┌──────────────────────────┐
│ AI Vision Model          │
│ (Claude / GPT-4o)        │
│                          │
│ Prompt:                  │
│ "Analyze this screenshot │
│  of an Android device.   │
│  A permission dialog is  │
│  showing. Identify:      │
│  1. Dialog title/message │
│  2. Button labels        │
│  3. Button positions     │
│     (pixel coordinates)" │
│                          │
│ Response:                │
│ {                        │
│   "dialog": "Camera      │
│     Permission",         │
│   "message": "Allow app  │
│     to access camera?",  │
│   "buttons": [           │
│     {"label": "Allow",   │
│      "bounds": {          │
│        "x": 480,          │
│        "y": 1200,         │
│        "w": 180,          │
│        "h": 60            │
│      }},                  │
│     {"label": "Deny",    │
│      "bounds": {          │
│        "x": 200,          │
│        "y": 1200,         │
│        "w": 180,          │
│        "h": 60            │
│      }}                   │
│   ]                      │
│ }                        │
└──────────────────────────┘
    │
    ▼
Platform Bridge: tap(570, 1230)  // Center of "Allow" button
```

### 8.3 Fallback: Android uiautomator

For Android, we can get precise element data without AI Vision:

```xml
<!-- Output of: adb shell uiautomator dump -->
<hierarchy>
  <node class="android.widget.FrameLayout" bounds="[0,0][1080,2400]">
    <node class="android.widget.LinearLayout" bounds="[150,1000][930,1350]">
      <node class="android.widget.TextView"
            text="Allow Titan to access your camera?"
            bounds="[200,1020][880,1100]" />
      <node class="android.widget.Button"
            text="ALLOW"
            bounds="[480,1200][660,1260]"
            clickable="true" />
      <node class="android.widget.Button"
            text="DENY"
            bounds="[200,1200][380,1260]"
            clickable="true" />
    </node>
  </node>
</hierarchy>
```

The extension parses this XML, finds the "ALLOW" button at bounds
`[480,1200][660,1260]`, and taps at the center: `(570, 1230)`.

### 8.4 Decision Tree

```
Element interaction requested ("Tap Allow")
    │
    ├─ Scry glyphs contain "Allow"?
    │   └─ YES → Relay: scry_act(tap, "Allow")  [fastest, most precise]
    │
    ├─ Platform: Android?
    │   └─ YES → adb uiautomator dump
    │       └─ XML contains "ALLOW" button with bounds?
    │           └─ YES → adb input tap <center>  [precise, no AI needed]
    │
    ├─ Platform: macOS?
    │   └─ YES → Accessibility API
    │       └─ AXUIElement tree contains "Allow" button?
    │           └─ YES → cliclick at button position  [precise, no AI needed]
    │
    └─ Fallback: AI Vision
        └─ Send screenshot to AI model
        └─ Parse response for button position
        └─ Platform Bridge: tap at identified position
```

### 8.5 Deliverables

- [ ] AI Vision analyzer with configurable model provider
- [ ] Standardized prompt templates for dialog analysis
- [ ] Android uiautomator XML parser
- [ ] macOS Accessibility tree parser
- [ ] Decision tree engine (Scry → Platform Accessibility → AI Vision)
- [ ] Confidence scoring for AI Vision coordinates
- [ ] Retry logic with adjusted prompts on failure

---

## 9. Phase 6: Unified Testing — Cross-Layer Test Orchestration

### 9.1 Overview

Enable test flows that seamlessly cross the Flutter/OS boundary:

1. Open app → Flutter UI (Scry/Relay)
2. Tap "Take Photo" → Flutter button via Scry
3. System camera permission dialog appears → OS UI (Platform Bridge)
4. Tap "Allow" → Platform Bridge
5. Camera opens → Mixed (native camera + Flutter overlay)
6. Take photo → Platform Bridge
7. Return to app → Scry detects new screen with photo
8. Verify photo displayed → Scry element inspection

### 9.2 Cross-Layer Campaign Format

Extend the Campaign/Stratagem JSON to support platform bridge actions:

```json
{
  "name": "camera_permission_flow",
  "entries": [
    {
      "stratagem": {
        "name": "navigate_to_camera",
        "startRoute": "/home",
        "steps": [
          {"id": 1, "action": "tap", "target": {"label": "Profile"}},
          {"id": 2, "action": "tap", "target": {"label": "Change Photo"}},
          {"id": 3, "action": "tap", "target": {"label": "Take Photo"}}
        ]
      }
    },
    {
      "stratagem": {
        "name": "handle_permission_dialog",
        "layer": "platform",
        "steps": [
          {"id": 1, "action": "waitForDialog", "timeout": 5000},
          {"id": 2, "action": "tap", "target": {"text": "Allow"}, "layer": "os"}
        ]
      }
    },
    {
      "stratagem": {
        "name": "verify_camera_opened",
        "steps": [
          {"id": 1, "action": "waitForElement", "target": {"label": "Capture"}, "timeout": 5000},
          {"id": 2, "action": "tap", "target": {"label": "Capture"}},
          {"id": 3, "action": "waitForElement", "target": {"label": "Use Photo"}, "timeout": 10000},
          {"id": 4, "action": "tap", "target": {"label": "Use Photo"}}
        ]
      }
    }
  ]
}
```

### 9.3 Deliverables

- [ ] Cross-layer Campaign executor
- [ ] `layer: "os"` / `layer: "flutter"` step attribute
- [ ] `waitForDialog` action using Platform Bridge accessibility check
- [ ] Dialog auto-detection (monitor for non-Flutter UI appearance)
- [ ] Cross-layer verdict reporting
- [ ] Template library for common permission flows

---

## 10. Phase 7: Copilot Integration — MCP Tool Provider

### 10.1 Overview

Register the extension as an MCP tool provider so Copilot Chat can
directly use Forge capabilities. This extends the existing MCP server
tools with platform bridge actions.

### 10.2 Additional MCP Tools

| Tool | Description |
|------|-------------|
| `forge_connect` | Connect to a Flutter app by platform/port |
| `forge_screenshot` | Capture OS-level screenshot (not just Flutter) |
| `forge_tap_os` | Tap at OS-level coordinates |
| `forge_swipe_os` | Swipe at OS-level |
| `forge_accessibility_tree` | Get accessibility tree (Android uiautomator / macOS AX) |
| `forge_analyze_dialog` | AI Vision analysis of current screen |
| `forge_handle_permission` | Auto-handle a permission dialog |
| `forge_devices` | List connected devices and their status |
| `forge_run_cross_campaign` | Execute a cross-layer Campaign |

### 10.3 Copilot Chat Workflow

```
User: "Test the camera flow including the permission dialog"

Copilot:
  1. forge_connect(platform: "android", deviceId: "Pixel7")
  2. scry() → sees "Take Photo" button
  3. scry_act(tap, "Take Photo")
  4. forge_screenshot() → sees permission dialog
  5. forge_accessibility_tree() → finds "ALLOW" button at (570, 1230)
  6. forge_tap_os(570, 1230)
  7. scry() → camera view with "Capture" button
  8. scry_act(tap, "Capture")
  9. scry() → preview with "Use Photo" button
  10. scry_act(tap, "Use Photo")
  11. scry() → profile page with updated photo
  12. "Camera flow tested successfully, permission dialog handled"
```

### 10.4 Deliverables

- [ ] MCP tool provider registration
- [ ] Forge-specific MCP tools (10 tools)
- [ ] Cross-layer tool coordination
- [ ] Tool documentation and schemas
- [ ] Integration tests with Copilot Chat

---

## 11. Platform Support Matrix

| Platform | Screenshot | Touch Injection | Accessibility Tree | AI Vision | Relay |
|----------|-----------|----------------|-------------------|-----------|-------|
| **Web** | Relay ✅ | Relay ✅ | Scry ✅ | ✅ | ✅ |
| **macOS Desktop** | screencapture ✅ | cliclick ✅ | AXUIElement ✅ | ✅ | ✅ |
| **Windows Desktop** | PowerShell ✅ | Win32 API ✅ | UI Automation ✅ | ✅ | ✅ |
| **Linux Desktop** | import ✅ | xdotool ✅ | AT-SPI ⚠️ | ✅ | ✅ |
| **Android (USB)** | adb screencap ✅ | adb input ✅ | uiautomator ✅ | ✅ | ✅ (port fwd) |
| **Android (scrcpy)** | scrcpy stream ✅ | scrcpy input ✅ | uiautomator ✅ | ✅ | ✅ |
| **iOS Simulator** | simctl ✅ | simctl/cliclick ⚠️ | Limited ⚠️ | ✅ | ✅ |
| **iOS Device** | pymobiledevice3 ⚠️ | Limited ❌ | Not available ❌ | ✅ | ✅ (WiFi) |
| **iPhone Mirroring** | macOS capture ✅ | cliclick on mirror ✅ | Not available ❌ | ✅ | ✅ |

**Legend**: ✅ Full support | ⚠️ Partial/workaround | ❌ Not available

### Key Notes

- **iOS physical devices** are the most limited — no open-source input injection
  exists without jailbreak. iPhone Mirroring (macOS Sequoia+) is the best option.
- **Android** has the best support thanks to adb's comprehensive automation API.
- **Relay** works on ALL platforms because it runs inside the Flutter process.
- **AI Vision** works everywhere (just needs a screenshot + AI model access).

---

## 12. Technical Implementation Details

### 12.1 scrcpy Integration

scrcpy can run headlessly and stream video to a file descriptor:

```bash
# Start scrcpy with video stream to stdout (no window)
scrcpy --no-display --record=file.mp4

# Capture single frame
scrcpy --no-display --no-audio --time-limit=1 --record=frame.mkv

# Forward touch events programmatically
# scrcpy has a --keyboard=uhid --mouse=uhid mode for raw input
```

For real-time streaming, use `scrcpy`'s `--v4l2-sink` (Linux) or
raw video stream parsing. On macOS/Windows, the desktop window
approach (scrcpy shows a window, extension clicks on it) is simpler.

### 12.2 Extension State Management

```typescript
// Global state
interface ForgeState {
  // Connections
  relayClient: RelayClient | null;
  platformBridge: PlatformBridge | null;

  // Cache
  lastScreenshot: Buffer | null;
  lastGaze: ScryGaze | null;
  lastAccessibilityTree: AccessibilityNode[] | null;

  // Recording
  isRecording: boolean;
  recordingName: string | null;

  // Settings
  screenshotInterval: number;
  autoDiscovery: boolean;
}
```

### 12.3 Error Handling

```
// Decision: Use Relay first, fall back to Platform Bridge

async function interact(action: string, target: string): Promise<void> {
  // Layer 1: Try Scry/Relay
  try {
    const gaze = await relay.scry();
    const element = findElement(gaze, target);
    if (element) {
      await relay.scryAct(action, target);
      return;
    }
  } catch (e) {
    // Relay not connected or element not found
  }

  // Layer 2: Try Platform Accessibility
  try {
    const tree = await bridge.getAccessibilityTree?.();
    if (tree) {
      const node = findAccessibilityNode(tree, target);
      if (node) {
        await bridge.tap(node.centerX, node.centerY);
        return;
      }
    }
  } catch (e) {
    // Accessibility not available
  }

  // Layer 3: AI Vision fallback
  const screenshot = await bridge.screenshot();
  const analysis = await aiVision.analyze(screenshot, `Find "${target}" button`);
  if (analysis.found) {
    await bridge.tap(analysis.centerX, analysis.centerY);
    return;
  }

  throw new Error(`Could not find "${target}" on any layer`);
}
```

---

## 13. JSON Schemas & APIs

### 13.1 Device Discovery Response

```json
{
  "devices": [
    {
      "id": "web-8080",
      "name": "Flutter Web",
      "platform": "web",
      "connection": "relay",
      "relayUrl": "ws://localhost:8080/ws",
      "status": "connected"
    },
    {
      "id": "android-R5CR1234",
      "name": "Pixel 7 Pro",
      "platform": "android",
      "connection": "adb",
      "serialNumber": "R5CR1234",
      "relayPort": 8081,
      "status": "connected"
    },
    {
      "id": "ios-sim-ABCD",
      "name": "iPhone 15 Pro",
      "platform": "ios-simulator",
      "connection": "simctl",
      "udid": "ABCD-1234-EFGH",
      "status": "booted"
    }
  ]
}
```

### 13.2 Unified Element Format

```json
{
  "id": "elem_42",
  "source": "scry",
  "label": "Allow",
  "type": "button",
  "className": "ElevatedButton",
  "bounds": { "x": 480, "y": 1200, "w": 180, "h": 60 },
  "interactable": true,
  "key": "ValueKey('allow_btn')",
  "layer": "flutter"
}
```

```json
{
  "id": "elem_os_1",
  "source": "uiautomator",
  "label": "ALLOW",
  "type": "button",
  "className": "android.widget.Button",
  "bounds": { "x": 480, "y": 1200, "w": 180, "h": 60 },
  "interactable": true,
  "layer": "os"
}
```

### 13.3 AI Vision Request/Response

```json
// Request
{
  "screenshot": "<base64 PNG>",
  "prompt": "Identify all interactive elements on this screen. For each, return: label, type (button/text-field/checkbox/link), and bounds (x, y, width, height in pixels).",
  "context": "Android permission dialog for camera access"
}

// Response
{
  "elements": [
    {
      "label": "Allow Titan to take pictures and record video?",
      "type": "text",
      "bounds": { "x": 200, "y": 1020, "w": 680, "h": 80 }
    },
    {
      "label": "While using the app",
      "type": "button",
      "bounds": { "x": 200, "y": 1140, "w": 680, "h": 48 }
    },
    {
      "label": "Only this time",
      "type": "button",
      "bounds": { "x": 200, "y": 1188, "w": 680, "h": 48 }
    },
    {
      "label": "Don't allow",
      "type": "button",
      "bounds": { "x": 200, "y": 1236, "w": 680, "h": 48 }
    }
  ],
  "confidence": 0.95
}
```

---

## 14. Example Workflows

### 14.1 Login → Permission → Camera Flow

```
1. [Forge] Auto-discovers Flutter web app on localhost:8080
2. [Forge] Shows live screenshot in panel
3. [User/AI] Clicks "Login" button → Scry handles tap
4. [User/AI] Enters credentials → Scry handles enterText
5. [User/AI] Clicks "Take Photo" → Scry handles tap
6. [Forge] Detects system dialog (Scry reports no change, but OS screenshot differs)
7. [Forge] Android uiautomator dump → finds "ALLOW" button
8. [Forge] adb input tap at ALLOW position
9. [Forge] Camera opens → Scry detects camera view
10. [User/AI] Clicks "Capture" → Scry handles tap
11. Done — full flow tested including system dialog
```

### 14.2 Multi-Device Testing

```
1. [Forge] Connects to:
   - Flutter Web on Chrome (Relay ws://localhost:8080)
   - Flutter Android on Pixel 7 (adb + Relay port-forwarded)
   - Flutter iOS on Simulator (simctl + Relay)
2. [Campaign] Same test campaign runs on all 3 devices
3. [Forge] Shows side-by-side screenshot panels
4. [Debrief] Compares results across platforms
```

### 14.3 Accessibility Audit with OS-Level Validation

```
1. [Scry] audit_accessibility → 80 issues found in Flutter UI
2. [Forge] Android TalkBack enabled → adb shell settings put secure enabled_accessibility_services ...
3. [Forge] Navigate app, capture OS accessibility tree at each screen
4. [Forge] Compare Scry accessibility data with Android accessibility data
5. [Report] Divergences = real accessibility bugs
```

---

## 15. Security Considerations

### 15.1 No Remote Access by Default

- All connections are localhost-only
- Relay WebSocket restricted to `127.0.0.1`
- adb connections are USB-only by default (must explicitly enable TCP/IP)
- No credentials stored in extension settings

### 15.2 OS Automation Risks

- Platform Bridge can click anywhere on screen — restrict to app window
- Validate target bounds are within the app's window before clicking
- AI Vision screenshots may contain sensitive data — process locally when possible
- User approval required before Platform Bridge sends input (configurable)

### 15.3 Permissions Model

| Action | Auto-allowed | Requires Approval |
|--------|-------------|-------------------|
| Relay/Scry interaction | ✅ | — |
| OS screenshot | ✅ | — |
| OS tap (within app window) | ✅ | — |
| OS tap (outside app window) | — | ✅ |
| adb commands | ✅ | — |
| AI Vision (send screenshot to cloud) | — | ✅ (first time) |
| Install/launch app | — | ✅ |

---

## 16. Milestones & Timeline

### Phase 1: Foundation (2-3 weeks)
- Extension scaffolding, Relay client, auto-discovery
- Status bar, output channel, settings
- **MVP**: Connect to running Flutter app, run Scry from command palette

### Phase 2: Live Mirror (2-3 weeks)
- Screenshot webview panel, click-to-interact
- Coordinate translation, Scry glyph matching
- **MVP**: See app screenshot, click to tap elements

### Phase 3: Element Inspector (1-2 weeks)
- Tree view for devices, elements, performance
- Context menu actions, element highlighting
- **MVP**: Browse all screen elements in sidebar

### Phase 4: Platform Bridge (3-4 weeks)
- Android (adb), macOS, Windows, Linux, iOS Simulator bridges
- Platform detection, tool health checks
- **MVP**: Tap system dialog buttons on Android

### Phase 5: AI Vision (2-3 weeks)
- Screenshot analysis, dialog understanding
- Decision tree (Scry → Accessibility → AI Vision)
- **MVP**: Auto-handle permission dialogs

### Phase 6: Unified Testing (2-3 weeks)
- Cross-layer Campaign executor
- Template library for common flows
- **MVP**: Run a camera-permission test flow end-to-end

### Phase 7: Copilot Integration (1-2 weeks)
- MCP tool provider, Forge-specific tools
- Copilot Chat workflow documentation
- **MVP**: Copilot can use Forge tools in chat

### Total Estimated Timeline: 13-20 weeks

### Priority Order

1. **Phase 1 + 2** — most impactful: visual app interaction from VS Code
2. **Phase 4** (Android only) — enables the key differentiator: system dialog handling
3. **Phase 3** — nice-to-have sidebar
4. **Phase 5** — AI Vision makes system dialogs work without manual coordinates
5. **Phase 7** — Copilot integration leverages everything above
6. **Phase 6** — cross-layer campaigns (advanced)
7. **Phase 4** (remaining platforms) — expand coverage

---

## Appendix A: Required External Tools

| Tool | Platform | Install | Purpose |
|------|----------|---------|---------|
| `adb` | Android | Android SDK Platform Tools | Device communication |
| `scrcpy` | Android | `brew install scrcpy` / `apt install scrcpy` | Screen mirroring + input |
| `cliclick` | macOS | `brew install cliclick` | Mouse click simulation |
| `osascript` | macOS | Built-in | AppleScript automation |
| `screencapture` | macOS | Built-in | Window screenshot |
| `xcrun simctl` | iOS Sim | Xcode Command Line Tools | Simulator control |
| `xdotool` | Linux | `apt install xdotool` | Mouse/keyboard simulation |
| `import` | Linux | ImageMagick (`apt install imagemagick`) | Screenshot capture |
| `PowerShell` | Windows | Built-in | Win32 API access |
| `pymobiledevice3` | iOS Device | `pip install pymobiledevice3` | iOS device communication |

## Appendix B: Competitive Landscape

| Tool | Flutter Semantic | System Dialogs | Multi-Platform | AI Agent | VS Code |
|------|-----------------|----------------|----------------|----------|---------|
| **Titan Forge** | ✅ Full (Scry) | ✅ (Bridge) | ✅ All | ✅ MCP + Vision | ✅ Native |
| Flutter Driver | ✅ Basic | ❌ | ✅ | ❌ | ❌ |
| Patrol | ✅ | ✅ (native) | Android + iOS | ❌ | ❌ |
| Appium | ❌ (generic) | ✅ | ✅ | ❌ | ❌ |
| Maestro | ⚠️ Limited | ✅ | Android + iOS | ❌ | ❌ |
| Detox | ❌ (React Native) | ✅ | Android + iOS | ❌ | ❌ |

**Titan Forge's unique value**: Only solution combining Flutter-native semantic 
intelligence (Scry widget tree) with OS-level interaction (Platform Bridge) AND
AI agent capabilities (MCP + Vision) — all inside VS Code.
