# AI Blueprint Generation — Feature Plan

## "The Scout Maps the Terrain, the General Writes the Campaign"

**Status**: Design Document  
**Package**: `titan_colossus`  
**Dependencies**: Stratagem Engine (Phase 5-6), Shade, Tableau, Glyph  
**Estimated Scope**: ~3,500 lines production code, ~2,000 lines tests  

---

## Table of Contents

1. [Vision](#1-vision)
2. [The Titan Lexicon — New Names](#2-the-titan-lexicon--new-names)
3. [Architecture Overview](#3-architecture-overview)
4. [Phase 1: Scout — Flow Discovery Engine](#4-phase-1-scout--flow-discovery-engine)
5. [Phase 2: Lineage — Prerequisite Chain Resolution](#5-phase-2-lineage--prerequisite-chain-resolution)
6. [Phase 3: Gauntlet — Edge-Case Pattern Generator](#6-phase-3-gauntlet--edge-case-pattern-generator)
7. [Phase 4: Campaign — AI Blueprint Orchestrator](#7-phase-4-campaign--ai-blueprint-orchestrator)
8. [Phase 5: Feedback Loop — Learning from Verdicts](#8-phase-5-feedback-loop--learning-from-verdicts)
9. [Phase 6: Integration — Colossus API & Lens UI](#9-phase-6-integration--colossus-api--lens-ui)
10. [AI Prompt Engineering](#10-ai-prompt-engineering)
11. [JSON Schemas](#11-json-schemas)
12. [Example Workflows](#12-example-workflows)
13. [Edge-Case Catalog](#13-edge-case-catalog)
14. [Test Plan](#14-test-plan)

---

## 1. Vision

### The Problem

Today's Stratagem engine is powerful but **dumb** — an AI must:
1. Already know every screen in the app
2. Already know which flows require login
3. Manually enumerate edge cases (rapid taps, empty fields, etc.)
4. Start from scratch for each new test, even when flows share setup

This design turns Colossus into an **autonomous test strategist** that:
- **Discovers** the app's screen graph by observing it
- **Understands** that `/dashboard` requires login (prerequisite chains)
- **Generates** complete Stratagem suites including tester-style edge cases
- **Learns** from execution results to improve future blueprints

### The Metaphor

> A fortress cannot be tested by striking one wall. The **Scout** maps every
> corridor and gate. The **Lineage** reveals which doors must be unlocked
> first. The **Gauntlet** hammers each gate a hundred times. And the
> **Campaign** orchestrates the siege.

### Design Principles

1. **Runtime-observable**: All discovery comes from actually running/observing the app, not from source code analysis
2. **AI-native**: Every data structure is JSON-serializable with natural-language descriptions
3. **Incremental**: Each user session (manual or automated) adds knowledge to the terrain map
4. **Non-destructive**: Discovery never mutates app state — it observes and records
5. **Composable**: Stratagems reference prerequisite Stratagems by name, building a DAG

---

## 2. The Titan Lexicon — New Names

| Standard Term | Titan Name | Class/Type | Purpose |
|---------------|------------|------------|---------|
| Flow Graph | **Terrain** | `Terrain` | Complete app flow map (screens + transitions) |
| Screen Node | **Outpost** | `Outpost` | A known screen with its element fingerprint |
| Screen Transition | **March** | `March` | An observed route transition (edge in the graph) |
| Flow Discovery Engine | **Scout** | `Scout` | Observes app to build the Terrain |
| Prerequisite Chain | **Lineage** | `Lineage` | Dependency tree for reaching a screen |
| Edge-Case Pattern | **Gauntlet** | `Gauntlet` | Stress/edge-case test pattern generator |
| Blueprint Suite | **Campaign** | `Campaign` | Orchestrated set of Stratagems with ordering |
| Screen Fingerprint | **Signet** | `Signet` | Hash-based identity of a screen's interactive elements |
| Discovery Session | **Sortie** | `Sortie` | One exploration run through the app |
| Verdict Feedback | **Debrief** | `Debrief` | Analysis of Verdict results for learning |

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    AI Agent (LLM)                       │
│  Receives: Terrain graph, Lineage chains, Gauntlet      │
│  patterns, templateDescription, getAiContext()           │
│  Produces: Campaign JSON (ordered Stratagem suite)       │
└────────────────────────┬────────────────────────────────┘
                         │
         ┌───────────────▼───────────────┐
         │        Campaign Engine        │
         │  Resolves prerequisite order  │
         │  Injects Gauntlet patterns    │
         │  Feeds Stratagems to Runner   │
         └───────────┬───────────────────┘
                     │
    ┌────────────────▼────────────────┐
    │       Stratagem Runner          │
    │  (existing Phase 5 engine)      │
    │  Executes steps, produces       │
    │  Verdict for each Stratagem     │
    └────────────────┬────────────────┘
                     │
    ┌────────────────▼────────────────┐
    │         Debrief Engine          │
    │  Analyzes Verdicts              │
    │  Updates Terrain with new data  │
    │  Reports patterns to AI         │
    └─────────────────────────────────┘
                     │
    ┌────────────────▼────────────────┐
    │       Scout (Discovery)         │
    │  Observes Shade sessions        │
    │  Builds/updates Terrain         │
    │  Identifies new routes          │
    └─────────────────────────────────┘
```

### Data Flow

```
User/AI browses app
    → Shade records ShadeSession (Imprints + Tableaux)
    → Scout observes ShadeSession
    → Scout extracts Outposts (screens) and Marches (transitions)
    → Scout builds/updates Terrain (flow graph)
    → Lineage computes prerequisite chains from Terrain
    → AI receives Terrain + Lineage + Gauntlet catalog
    → AI generates Campaign (suite of Stratagems)
    → Campaign Engine resolves dependency order
    → Campaign Engine injects Gauntlet edge-case variants
    → Stratagem Runner executes each Stratagem
    → Debrief Engine analyzes Verdicts
    → Debrief updates Terrain (new routes discovered, dead ends noted)
    → Feedback sent to AI for next iteration
```

---

## 4. Phase 1: Scout — Flow Discovery Engine

### 4.1 Overview

The **Scout** observes the app's behavior — through manual user sessions (Shade recordings) and automated Stratagem executions — to build a **Terrain** (flow graph). Every time a user navigates, the Scout learns a new route transition (March).

### 4.2 Core Data Models

#### Signet — Screen Fingerprint

A Signet uniquely identifies a screen by its interactive elements, independent of dynamic data:

```dart
/// **Signet** — A unique fingerprint identifying a screen.
///
/// Two screens are "the same" if they have the same Signet,
/// even if displayed data differs (e.g., different user profiles
/// on `/profile` still have the same interactive layout).
///
/// The Signet hashes:
/// - Route pattern (parameterized: `/quest/:id` not `/quest/42`)
/// - Interactive widget types and their semantic roles
/// - Widget tree structure (ancestor chains)
///
/// It deliberately ignores:
/// - Text content (labels change with data)
/// - Positions (layout varies by device)
/// - Non-interactive decorations
class Signet {
  /// The route pattern this screen appears at.
  ///
  /// Parameterized: `/quest/:id` instead of `/quest/42`.
  final String routePattern;
  
  /// Sorted list of interactive element descriptors.
  ///
  /// Each descriptor: `"widgetType:semanticRole:interactionType"`
  /// Example: `["ElevatedButton:button:tap", "TextField:textField:textInput"]`
  final List<String> interactiveDescriptors;
  
  /// SHA-256 hash of the structural fingerprint.
  ///
  /// Computed from sorted `interactiveDescriptors` joined with `|`.
  final String hash;
  
  /// Human-readable screen identity.
  ///
  /// Example: `"login_screen"` (auto-generated from route + elements)
  final String identity;

  // Factory: from Tableau
  factory Signet.fromTableau(Tableau tableau) { ... }
  
  // Equality: two Signets match if their hashes match
  @override
  bool operator ==(Object other) => other is Signet && hash == other.hash;
  
  // Serialization
  Map<String, dynamic> toJson() => { ... };
  factory Signet.fromJson(Map<String, dynamic> json) => ...;
}
```

**Route parameterization** — The Scout must detect that `/quest/42` and `/quest/7` are the same screen pattern `/quest/:id`. Algorithm:

```
1. Collect all observed routes: ["/quest/42", "/quest/7", "/quest/99"]
2. Split by "/": [["quest", "42"], ["quest", "7"], ["quest", "99"]]
3. For each segment position, if values vary → replace with `:param`
4. Result: "/quest/:id"
```

#### Outpost — A Known Screen

```dart
/// **Outpost** — A discovered screen in the app.
///
/// Each Outpost represents a unique screen the Scout has observed,
/// identified by its [Signet]. Contains everything AI needs to know
/// about what's on this screen and how to interact with it.
class Outpost {
  /// Unique screen fingerprint.
  final Signet signet;
  
  /// Route pattern (e.g., `/login`, `/quest/:id`).
  final String routePattern;
  
  /// Human-readable screen name (auto-generated or user-assigned).
  ///
  /// Example: `"Login Screen"`, `"Quest Detail"`, `"Hero Profile"`
  String displayName;
  
  /// All interactive elements observed on this screen.
  ///
  /// Merged from multiple observations — if button "X" appeared in
  /// any observation, it's listed here.
  final List<OutpostElement> interactiveElements;
  
  /// All text/display elements observed.
  final List<OutpostElement> displayElements;
  
  /// Whether this screen requires authentication.
  ///
  /// Determined by Lineage analysis: if every observed path to this
  /// screen passes through a login screen, `requiresAuth = true`.
  bool requiresAuth;
  
  /// Tags automatically assigned based on content analysis.
  ///
  /// Example: `["auth", "form"]` for login, `["list", "scrollable"]` for quest list
  final List<String> tags;
  
  /// Number of times this screen has been observed.
  int observationCount;
  
  /// Outgoing transitions (Marches) from this screen.
  final List<March> exits;
  
  /// Incoming transitions (Marches) to this screen.
  final List<March> entrances;
  
  /// Representative Tableau snapshot (most recent observation).
  Tableau? lastTableau;
  
  // Serialization
  Map<String, dynamic> toJson() => { ... };
  factory Outpost.fromJson(Map<String, dynamic> json) => ...;
  
  /// AI-readable summary of this screen.
  ///
  /// Example:
  /// ```
  /// SCREEN: Login Screen (/login)
  /// AUTH: not required
  /// INTERACTIVE: TextField "Hero Name", ElevatedButton "Enter the Realm"
  /// EXITS: → / (tap "Enter the Realm"), → /register (tap "Register"), → /about (tap "About")
  /// ENTRANCES: ← / (redirect when unauthenticated), ← /register (tap "Back")
  /// ```
  String toAiSummary() => ...;
}

/// An element observed on an [Outpost] screen.
class OutpostElement {
  final String widgetType;
  final String? label;
  final String? interactionType;
  final String? semanticRole;
  final String? key;
  final bool isInteractive;
  
  /// How many times this element appeared across observations.
  int frequency;
  
  /// Whether this element is always present (vs. conditional).
  ///
  /// If `frequency == outpost.observationCount`, it's stable.
  bool get isStable => frequency == _outpostObservations;
  
  Map<String, dynamic> toJson() => { ... };
}
```

#### March — A Transition Between Screens

```dart
/// **March** — An observed transition between two [Outpost] screens.
///
/// Records how a user or automation moved from one screen to another,
/// including which element was interacted with to trigger the transition.
class March {
  /// Source screen route pattern.
  final String fromRoute;
  
  /// Destination screen route pattern.
  final String toRoute;
  
  /// What triggered this transition.
  final MarchTrigger trigger;
  
  /// The element that was interacted with (null for programmatic navigation).
  final OutpostElement? triggerElement;
  
  /// Number of times this transition was observed.
  int observationCount;
  
  /// Whether this transition is reliable (observed 2+ times).
  bool get isReliable => observationCount >= 2;
  
  /// Average time taken for this transition (between Tableaux timestamps).
  Duration averageDuration;
  
  /// Whether this transition requires specific preconditions.
  ///
  /// Example: navigating from /login to / requires valid credentials.
  String? preconditionNotes;
  
  Map<String, dynamic> toJson() => { ... };
}

/// What triggered a [March] transition.
enum MarchTrigger {
  /// User tapped a button/link.
  tap,
  
  /// User submitted a form.
  formSubmit,
  
  /// Programmatic navigation (e.g., after successful login).
  programmatic,
  
  /// System redirect (e.g., auth guard).
  redirect,
  
  /// Back navigation (pop).
  back,
  
  /// Swipe gesture (e.g., dismissing).
  swipe,
  
  /// Deep link.
  deepLink,
  
  /// Unknown/unobserved.
  unknown,
}
```

#### Terrain — The Complete Flow Graph

```dart
/// **Terrain** — The complete flow graph of the app.
///
/// Built incrementally by the [Scout] as it observes user sessions
/// and Stratagem executions. Contains all known screens (Outposts)
/// and transitions (Marches).
///
/// ## AI Consumption
///
/// AI receives the Terrain as a structured graph enabling it to:
/// 1. Know every screen in the app
/// 2. Know how to get to each screen
/// 3. Know what elements exist on each screen
/// 4. Know which screens require authentication
/// 5. Know which transitions are reliable
///
/// ```dart
/// final terrain = Scout.instance.terrain;
/// final aiMap = terrain.toAiMap(); // Full graph for AI
/// ```
class Terrain {
  /// All discovered screens.
  final Map<String, Outpost> outposts; // keyed by routePattern
  
  /// All discovered transitions.
  final List<March> marches;
  
  /// When the Terrain was last updated.
  DateTime lastUpdated;
  
  /// Total Shade sessions analyzed to build this Terrain.
  int sessionsAnalyzed;
  
  /// Total Stratagem executions analyzed.
  int stratagemExecutionsAnalyzed;
  
  // ---- Graph Queries ----
  
  /// Get all screens reachable from a starting route.
  List<Outpost> reachableFrom(String routePattern) => ...;
  
  /// Get the shortest path between two screens.
  ///
  /// Returns ordered list of Marches, or null if no path exists.
  List<March>? shortestPath(String from, String to) => ...;
  
  /// Get all screens that require authentication.
  List<Outpost> get authProtectedScreens => ...;
  
  /// Get all screens reachable without authentication.
  List<Outpost> get publicScreens => ...;
  
  /// Get screens with no observed exits (dead ends or terminal screens).
  List<Outpost> get deadEnds => ...;
  
  /// Get screens with no observed entrances (entry points only via deep link).
  List<Outpost> get entryPoints => ...;
  
  /// Get unreliable transitions (observed only once).
  List<March> get unreliableMarches =>
      marches.where((m) => !m.isReliable).toList();
  
  // ---- AI Output ----
  
  /// Complete AI-readable map of the app.
  ///
  /// Returns a structured document the AI can use to understand
  /// the entire app flow and generate comprehensive Stratagems.
  String toAiMap() => ...;
  
  /// Mermaid flowchart of the app.
  ///
  /// ```
  /// graph TD
  ///   login["/login<br>Login Screen"] --> |tap 'Enter'| home["/"]
  ///   home --> |tap quest| detail["/quest/:id"]
  ///   login --> |tap 'Register'| register["/register"]
  /// ```
  String toMermaid() => ...;
  
  /// JSON serialization for persistence.
  Map<String, dynamic> toJson() => { ... };
  factory Terrain.fromJson(Map<String, dynamic> json) => ...;
  
  /// Save to file.
  Future<void> saveToFile(String path) async => ...;
  
  /// Load from file.
  static Future<Terrain> loadFromFile(String path) async => ...;
}
```

### 4.3 Scout — The Discovery Engine

```dart
/// **Scout** — Flow discovery engine.
///
/// Observes the app through Shade sessions and Stratagem executions
/// to build a [Terrain] — a complete map of the app's screens
/// and transitions.
///
/// ## How It Works
///
/// 1. User (or AI) browses the app with Shade recording active
/// 2. Scout analyzes the ShadeSession's Tableaux sequence
/// 3. Each unique screen becomes an Outpost
/// 4. Each route change becomes a March
/// 5. The Terrain grows with each observation
///
/// ## Discovery Strategies
///
/// ### Passive Discovery (Default)
/// Scout watches Shade sessions silently, building the Terrain
/// from normal app usage.
///
/// ### Active Discovery (AI-Directed)
/// Scout generates exploration Stratagems that systematically
/// navigate to each interactive element on each screen, chasing
/// untapped buttons and unexplored routes.
///
/// ```dart
/// // Active discovery:
/// final sortie = await Scout.instance.explore();
/// // Scout taps every button it hasn't tried yet,
/// // follows every link, maps every screen
/// ```
class Scout {
  /// Singleton instance (managed by Colossus).
  static Scout? _instance;
  static Scout get instance => _instance ??= Scout._();
  
  /// The accumulated flow graph.
  final Terrain terrain = Terrain();
  
  // ---- Passive Discovery ----
  
  /// Analyze a completed Shade session to update the Terrain.
  ///
  /// Extracts Outposts and Marches from the session's Tableaux.
  /// Call this after every Shade recording completes.
  void analyzeSession(ShadeSession session) {
    final tableaux = session.tableaux;
    if (tableaux.isEmpty) return;
    
    for (var i = 0; i < tableaux.length; i++) {
      final tableau = tableaux[i];
      _registerOutpost(tableau);
      
      if (i > 0) {
        _registerMarch(
          from: tableaux[i - 1],
          to: tableau, 
          trigger: _inferTrigger(session.imprints, tableaux[i - 1], tableau),
        );
      }
    }
    
    terrain.sessionsAnalyzed++;
    terrain.lastUpdated = DateTime.now();
  }
  
  /// Analyze a Stratagem Verdict to update the Terrain.
  ///
  /// Each step's pre/post Tableaux reveal transitions. Failed steps
  /// reveal dead ends or gated routes.
  void analyzeVerdict(Verdict verdict) {
    for (final step in verdict.steps) {
      if (step.postTableau != null) {
        _registerOutpost(step.postTableau!);
      }
      if (step.preTableau != null && step.postTableau != null) {
        final preRoute = step.preTableau!.route;
        final postRoute = step.postTableau!.route;
        if (preRoute != postRoute) {
          _registerMarch(
            from: step.preTableau!,
            to: step.postTableau!,
            trigger: _inferTriggerFromAction(step.action),
          );
        }
      }
    }
    
    terrain.stratagemExecutionsAnalyzed++;
    terrain.lastUpdated = DateTime.now();
  }
  
  // ---- Active Discovery ----
  
  /// Generate an exploration Stratagem for a specific screen.
  ///
  /// Creates a Stratagem that navigates to the target screen
  /// and taps every untried interactive element, discovering
  /// new transitions.
  ///
  /// Returns null if the screen has been fully explored.
  Stratagem? generateSortie(String routePattern) {
    final outpost = terrain.outposts[routePattern];
    if (outpost == null) return null;
    
    final unexploredElements = outpost.interactiveElements.where((e) {
      // Check if tapping this element has ever been observed
      return !outpost.exits.any((m) =>
        m.triggerElement?.label == e.label &&
        m.triggerElement?.widgetType == e.widgetType
      );
    }).toList();
    
    if (unexploredElements.isEmpty) return null; // Fully explored
    
    final steps = <StratagemStep>[];
    for (var i = 0; i < unexploredElements.length; i++) {
      final elem = unexploredElements[i];
      steps.add(StratagemStep(
        id: i + 1,
        action: StratagemAction.tap,
        description: 'Explore: tap ${elem.label ?? elem.widgetType}',
        target: StratagemTarget(
          label: elem.label,
          type: elem.widgetType,
          key: elem.key,
        ),
        waitAfter: const Duration(seconds: 1),
      ));
      // Navigate back after each exploration tap
      steps.add(StratagemStep(
        id: i + 2,
        action: StratagemAction.back,
        description: 'Return to explore next element',
        waitAfter: const Duration(milliseconds: 500),
      ));
    }
    
    return Stratagem(
      name: 'sortie_${routePattern.replaceAll("/", "_")}',
      description: 'Active discovery of $routePattern',
      tags: ['discovery', 'sortie'],
      startRoute: routePattern,
      steps: steps,
      failurePolicy: StratagemFailurePolicy.continueAll,
      timeout: Duration(seconds: unexploredElements.length * 10),
    );
  }
  
  /// Generate Sorties for all partially-explored screens.
  List<Stratagem> generateAllSorties() {
    return terrain.outposts.keys
        .map(generateSortie)
        .whereType<Stratagem>()
        .toList();
  }
  
  // ---- Internal ----
  
  void _registerOutpost(Tableau tableau) { /* ... */ }
  void _registerMarch({
    required Tableau from,
    required Tableau to,
    required MarchTrigger trigger,
  }) { /* ... */ }
  MarchTrigger _inferTrigger(
    List<Imprint> imprints,
    Tableau before,
    Tableau after,
  ) { /* ... */ }
  MarchTrigger _inferTriggerFromAction(StratagemAction action) { /* ... */ }
}
```

### 4.4 Trigger Inference Algorithm

How does the Scout determine **what caused** a route transition?

```
GIVEN: Two consecutive Tableaux (before, after) and Imprints between them

1. Find Imprints with timestamps between before.timestamp and after.timestamp
2. Filter for pointerUp events (completed interactions)
3. For each pointerUp, find the Glyph at the pointer coordinates in `before`
4. Classify:
   a. If Glyph is an ElevatedButton/TextButton/IconButton → tap
   b. If Glyph is a TextField + a submit Imprint follows → formSubmit
   c. If beforeRoute == afterRoute but elements changed → no March (same screen update)
   d. If no Glyph at pointer position but route changed → redirect (auth guard)
   e. If swipe Imprints detected → swipe
   f. If pointerDown + back navigation → back
   g. Otherwise → unknown
```

### 4.5 Route Parameterization Algorithm

```dart
/// Detect route parameters by analyzing observed route variations.
///
/// Example: ["/quest/1", "/quest/42", "/quest/99"] → "/quest/:id"
///
/// Algorithm:
/// 1. Group routes by segment count
/// 2. Within each group, find segment positions that vary
/// 3. Replace varying segments with `:paramN`
/// 4. Merge identical patterns
class RouteParameterizer {
  /// Known route patterns (updated incrementally).
  final Set<String> _observedRoutes = {};
  
  /// Computed parameterized patterns.
  final Map<String, String> _routeToPattern = {};
  
  /// Register an observed route and return its pattern.
  String parameterize(String route) {
    _observedRoutes.add(route);
    
    // Check existing patterns
    if (_routeToPattern.containsKey(route)) {
      return _routeToPattern[route]!;
    }
    
    // Find routes with same segment count
    final segments = route.split('/');
    final sameLength = _observedRoutes
        .where((r) => r.split('/').length == segments.length)
        .toList();
    
    if (sameLength.length < 2) {
      _routeToPattern[route] = route; // Not enough data to parameterize
      return route;
    }
    
    // Compare segments — variable positions get :param
    final pattern = List<String>.filled(segments.length, '');
    for (var i = 0; i < segments.length; i++) {
      final uniqueValues = sameLength.map((r) => r.split('/')[i]).toSet();
      if (uniqueValues.length == 1) {
        pattern[i] = segments[i]; // Constant segment
      } else if (_looksLikeId(uniqueValues)) {
        pattern[i] = ':id'; // Numeric or UUID-like → :id
      } else {
        pattern[i] = ':param$i'; // Generic parameter
      }
    }
    
    final patternStr = pattern.join('/');
    
    // Update all matching routes to use this pattern
    for (final r in sameLength) {
      _routeToPattern[r] = patternStr;
    }
    
    return patternStr;
  }
  
  bool _looksLikeId(Set<String> values) {
    return values.every((v) =>
      int.tryParse(v) != null || // Numeric ID
      RegExp(r'^[a-f0-9-]{8,}$').hasMatch(v) // UUID-like
    );
  }
}
```

---

## 5. Phase 2: Lineage — Prerequisite Chain Resolution

### 5.1 Overview

**Lineage** answers the question: *"What must happen before I can test this screen?"*

For example:
- Testing `/dashboard` requires: login first
- Testing `/quest/42` requires: login → navigate to quest list → tap quest
- Testing `/register` requires: be on guest-only `/login` screen → tap Register

### 5.2 How Lineage Discovers Prerequisites

```
ALGORITHM: Build Prerequisite Chain

INPUT: Terrain graph, target route pattern
OUTPUT: Ordered list of prerequisite Stratagems

1. Find all paths from entry points to the target in the Terrain graph
2. For each path, extract the March sequence (transitions)
3. Identify "gates" — transitions that require specific actions:
   a. Auth gate: transition that only occurs after form submission on /login
   b. Form gate: transition requiring specific text input
   c. Navigation gate: transition requiring tap on a specific element
4. For each gate, produce a prerequisite Stratagem:
   a. Auth gate → "login_prerequisite" Stratagem (enterText + submit)
   b. Form gate → "fill_form_prerequisite" Stratagem
   c. Navigation gate → "navigate_to_X" Stratagem
5. Order prerequisites by dependency (login before dashboard before feature)
6. Return ordered prerequisite chain
```

### 5.3 Core Data Model

```dart
/// **Lineage** — Prerequisite chain for reaching a screen.
///
/// Tells AI what steps must be completed before a target screen
/// can be tested. Built automatically from the [Terrain] graph.
///
/// ## Example
///
/// ```dart
/// final lineage = Lineage.resolve(terrain, targetRoute: '/quest/42');
/// // lineage.prerequisites:
/// //   1. login_prerequisite (navigate to /login, enter credentials, submit)
/// //   2. navigate_to_quest_list (from /, tap "Quests" tab)
/// //   3. navigate_to_quest_42 (tap quest card with id 42)
/// ```
class Lineage {
  /// The target screen this Lineage leads to.
  final String targetRoute;
  
  /// Ordered prerequisite Stratagems (must execute in order).
  ///
  /// Each prerequisite is a complete Stratagem that sets up
  /// one part of the path to the target screen.
  final List<StratagemPrerequisite> prerequisites;
  
  /// The shortest path through the Terrain to reach the target.
  final List<March> path;
  
  /// Whether authentication is required anywhere in the chain.
  bool get requiresAuth => prerequisites.any((p) => p.isAuthGate);
  
  /// Total estimated time to execute all prerequisites.
  Duration get estimatedSetupTime => prerequisites.fold(
    Duration.zero,
    (sum, p) => sum + p.estimatedDuration,
  );
  
  /// Resolve the prerequisite chain from a Terrain.
  factory Lineage.resolve(Terrain terrain, {required String targetRoute}) {
    // Find shortest path from any entry point to target
    final entryPoints = terrain.entryPoints;
    List<March>? bestPath;
    
    for (final entry in entryPoints) {
      final path = terrain.shortestPath(entry.routePattern, targetRoute);
      if (path != null && (bestPath == null || path.length < bestPath.length)) {
        bestPath = path;
      }
    }
    
    if (bestPath == null) {
      return Lineage._(
        targetRoute: targetRoute,
        prerequisites: [],
        path: [],
      );
    }
    
    // Convert path to prerequisite Stratagems
    final prerequisites = _buildPrerequisites(bestPath, terrain);
    
    return Lineage._(
      targetRoute: targetRoute,
      prerequisites: prerequisites,
      path: bestPath,
    );
  }
  
  /// Generate a setup Stratagem that chains all prerequisites.
  ///
  /// Returns a single Stratagem that, when executed, will navigate
  /// from the app's initial state to the target screen, ready for testing.
  Stratagem toSetupStratagem({Map<String, dynamic>? testData}) {
    final allSteps = <StratagemStep>[];
    var stepId = 1;
    
    for (final prereq in prerequisites) {
      for (final step in prereq.stratagem.steps) {
        allSteps.add(StratagemStep(
          id: stepId++,
          action: step.action,
          description: '[Setup] ${step.description}',
          target: step.target,
          value: step.value,
          clearFirst: step.clearFirst,
          expectations: step.expectations,
          waitAfter: step.waitAfter,
          navigateRoute: step.navigateRoute,
        ));
      }
    }
    
    return Stratagem(
      name: 'setup_for_${targetRoute.replaceAll("/", "_")}',
      description: 'Auto-generated setup to reach $targetRoute',
      tags: ['setup', 'auto-generated'],
      startRoute: prerequisites.isNotEmpty 
          ? prerequisites.first.stratagem.startRoute 
          : targetRoute,
      testData: testData,
      steps: allSteps,
      failurePolicy: StratagemFailurePolicy.abortOnFirst,
    );
  }
  
  /// AI-readable summary.
  String toAiSummary() => '''
LINEAGE: Reaching $targetRoute
AUTH REQUIRED: $requiresAuth
ESTIMATED SETUP: ${estimatedSetupTime.inSeconds}s
PREREQUISITES (${prerequisites.length}):
${prerequisites.asMap().entries.map((e) => '  ${e.key + 1}. ${e.value.description}').join('\n')}
PATH: ${path.map((m) => '${m.fromRoute} → ${m.toRoute}').join(' → ')}
''';
  
  Map<String, dynamic> toJson() => { ... };
  
  const Lineage._({
    required this.targetRoute,
    required this.prerequisites,
    required this.path,
  });
}

/// A single prerequisite in a [Lineage] chain.
class StratagemPrerequisite {
  /// Human-readable description.
  final String description;
  
  /// The Stratagem that satisfies this prerequisite.
  final Stratagem stratagem;
  
  /// Whether this is an authentication gate.
  final bool isAuthGate;
  
  /// Whether this is a form submission gate.
  final bool isFormGate;
  
  /// Estimated execution time.
  final Duration estimatedDuration;
  
  Map<String, dynamic> toJson() => { ... };
}
```

### 5.4 Auth Detection Algorithm

```
ALGORITHM: Detect Authentication Gates

INPUT: Terrain graph
OUTPUT: Set of route patterns that require authentication

1. Find the login screen:
   a. Screen with TextField + "password"/"login"/"sign in" labels
   b. Screen where form submission triggers navigation to a different route
   c. Screen that appears as a redirect destination from multiple routes

2. Mark post-login routes:
   a. Any route reachable ONLY through the login screen's exit = auth-required
   b. Routes reachable without passing through login = public
   
3. Detect redirect patterns:
   a. If navigating to /dashboard without login → redirected to /login
   b. The Scout observes this as: attempted March to /dashboard, 
      but arrived at /login instead
   c. Mark /dashboard as auth-required

4. Cross-validate with Sentinel guards (if Atlas metadata available):
   a. Routes behind GarrisonAuth → auth-required
   b. Routes in publicPaths → public
   c. Routes in guestPaths → guest-only (redirect away when authenticated)
```

### 5.5 Smart Prerequisite Inference

The Lineage system doesn't just trace paths — it infers what **data** prerequisites need:

```
EXAMPLE: Login prerequisite for /dashboard

Observation from Shade session:
  Screen /login has:
    - TextField with label "Hero Name" (fieldId: "hero_name")
    - ElevatedButton with label "Enter the Realm"
  
  Transition /login → /:
    - Triggered by: tap on "Enter the Realm"
    - Preceded by: text input in "Hero Name" field
    - Text entered: "Thorin" (from ShadeTextController)

Generated prerequisite Stratagem:
  {
    "name": "login_prerequisite",
    "startRoute": "/login",
    "testData": {
      "heroName": "${testData.heroName}"  // Parameterized!
    },
    "steps": [
      {
        "id": 1,
        "action": "enterText",
        "target": {"label": "Hero Name", "type": "TextField"},
        "value": "${testData.heroName}",
        "clearFirst": true
      },
      {
        "id": 2,
        "action": "tap",
        "target": {"label": "Enter the Realm", "type": "ElevatedButton"},
        "expectations": {"route": "/"}
      }
    ]
  }
```

---

## 6. Phase 3: Gauntlet — Edge-Case Pattern Generator

### 6.1 Overview

The **Gauntlet** is a catalog of edge-case patterns that testers use. Given an Outpost (screen), the Gauntlet generates stress-test and edge-case Stratagems automatically.

### 6.2 Edge-Case Categories

#### Category 1: Interaction Stress

| Pattern | Name | Description | When to Apply |
|---------|------|-------------|---------------|
| Rapid tap | `rapid_fire` | Tap same button N times quickly | Any tappable button |
| Double submit | `double_submit` | Submit form twice rapidly | Any form with submit button |
| Multi-field blur | `tab_storm` | Quickly tab through all form fields | Screens with 2+ text fields |
| Tap during transition | `mid_flight_tap` | Tap button while page is transitioning | Any button that triggers navigation |
| Back during load | `retreat_under_fire` | Press back while async operation in progress | Buttons that trigger API calls |

#### Category 2: Input Boundaries

| Pattern | Name | Description | When to Apply |
|---------|------|-------------|---------------|
| Empty submit | `hollow_strike` | Submit form with all fields empty | Any form |
| Max length | `overflow_scroll` | Enter maximum-length text | Any TextField |
| Special characters | `rune_injection` | Enter `<script>`, emoji, RTL text, null bytes | Any TextField |
| Unicode edge | `glyph_storm` | Enter zalgo text, emoji sequences, CJK | Any TextField |
| Whitespace only | `phantom_text` | Enter only spaces/tabs | Any TextField |
| Numeric overflow | `titan_count` | Enter very large/negative numbers | Numeric fields |
| Slider extremes | `edge_of_range` | Drag slider to min, max, beyond bounds | Any Slider |

#### Category 3: Navigation Stress

| Pattern | Name | Description | When to Apply |
|---------|------|-------------|---------------|
| Rapid back | `full_retreat` | Press back N times quickly | Any screen with depth > 1 |
| Deep link cold | `ambush_arrival` | Navigate directly to deep route without setup | Auth-protected screens |
| Circular navigation | `eternal_march` | Navigate A → B → A → B repeatedly | Connected screens |
| Back from root | `bedrock_back` | Press back from the root screen | Root/home screen |

#### Category 4: State Integrity

| Pattern | Name | Description | When to Apply |
|---------|------|-------------|---------------|
| Toggle storm | `switch_frenzy` | Rapidly toggle a switch 10 times | Any Switch/Checkbox |
| Slider dance | `slider_tempest` | Rapidly drag slider between extremes | Any Slider |
| Dropdown reselect | `choice_reversal` | Select dropdown item, change to another, back to first | Any Dropdown |
| Form partial fill | `half_inscription` | Fill some fields, leave others, submit | Any form with 2+ fields |
| Stale screen | `forgotten_outpost` | Navigate away and back — verify data persists | Screens with state |

#### Category 5: Timing & Async

| Pattern | Name | Description | When to Apply |
|---------|------|-------------|---------------|
| Slow interaction | `patient_siege` | Long press (3s) instead of tap | Any tappable element |
| Scroll spam | `avalanche_scroll` | Scroll rapidly in both directions | Any scrollable screen |
| Wait abandon | `impatient_general` | Start operation, navigate away before it completes | Screens with async operations |

### 6.3 Gauntlet Data Model

```dart
/// **Gauntlet** — Edge-case pattern generator.
///
/// Analyzes an [Outpost] and generates stress-test Stratagems
/// based on the elements present on screen.
///
/// ## Philosophy
///
/// "A tester doesn't just verify the happy path — they hammer
/// every gate, pick every lock, and rattle every hinge."
///
/// ## Usage
///
/// ```dart
/// final outpost = terrain.outposts['/login'];
/// final edgeCases = Gauntlet.generateFor(outpost);
/// // Returns 10-20 edge-case Stratagems specific to the login screen
/// ```
class Gauntlet {
  /// Generate all applicable edge-case Stratagems for a screen.
  ///
  /// Analyzes the Outpost's elements and returns Stratagems that
  /// test interaction stress, input boundaries, navigation stress,
  /// state integrity, and timing edge cases.
  static List<Stratagem> generateFor(
    Outpost outpost, {
    Lineage? lineage,
    GauntletIntensity intensity = GauntletIntensity.standard,
  }) {
    final stratagems = <Stratagem>[];
    
    // Attach prerequisites if lineage provided
    final preconditions = lineage?.prerequisites.isEmpty ?? true
        ? null
        : {'setupStratagem': lineage!.toSetupStratagem().name};
    
    // Category 1: Interaction Stress
    stratagems.addAll(_interactionStress(outpost, preconditions));
    
    // Category 2: Input Boundaries
    stratagems.addAll(_inputBoundaries(outpost, preconditions));
    
    // Category 3: Navigation Stress
    stratagems.addAll(_navigationStress(outpost, preconditions));
    
    // Category 4: State Integrity
    stratagems.addAll(_stateIntegrity(outpost, preconditions));
    
    // Category 5: Timing & Async
    if (intensity == GauntletIntensity.thorough) {
      stratagems.addAll(_timingEdgeCases(outpost, preconditions));
    }
    
    return stratagems;
  }
  
  /// Generate edge cases for a specific element.
  static List<Stratagem> generateForElement(
    Outpost outpost,
    OutpostElement element, {
    Lineage? lineage,
  }) { ... }
  
  /// Get the full catalog of available patterns.
  static List<GauntletPattern> get catalog => [ ... ];
  
  // ---- Internal Generators ----
  
  static List<Stratagem> _interactionStress(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    final results = <Stratagem>[];
    
    // Rapid-fire tap on every button
    for (final elem in outpost.interactiveElements) {
      if (elem.interactionType == 'tap') {
        results.add(_rapidFireTap(outpost, elem, preconditions));
      }
    }
    
    // Double-submit on forms
    final hasForm = outpost.interactiveElements.any(
      (e) => e.interactionType == 'textInput',
    );
    final hasSubmit = outpost.interactiveElements.any(
      (e) => e.interactionType == 'tap' && 
          (e.label?.toLowerCase().contains('submit') ?? false) ||
          (e.label?.toLowerCase().contains('login') ?? false) ||
          (e.label?.toLowerCase().contains('save') ?? false) ||
          (e.label?.toLowerCase().contains('register') ?? false),
    );
    if (hasForm && hasSubmit) {
      results.add(_doubleSubmit(outpost, preconditions));
    }
    
    return results;
  }
  
  static Stratagem _rapidFireTap(
    Outpost outpost,
    OutpostElement element,
    Map<String, dynamic>? preconditions,
  ) {
    const tapCount = 5;
    return Stratagem(
      name: 'gauntlet_rapid_fire_${_slugify(element.label ?? element.widgetType)}',
      description: 'Rapid-fire tap ${element.label ?? element.widgetType} $tapCount times',
      tags: ['gauntlet', 'stress', 'rapid-tap'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: List.generate(tapCount, (i) => StratagemStep(
        id: i + 1,
        action: StratagemAction.tap,
        description: 'Rapid tap #${i + 1}',
        target: StratagemTarget(
          label: element.label,
          type: element.widgetType,
          key: element.key,
        ),
        waitAfter: const Duration(milliseconds: 50), // Very fast!
      )),
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }
  
  static Stratagem _doubleSubmit(
    Outpost outpost,
    Map<String, dynamic>? preconditions,
  ) {
    // Find submit button
    final submitBtn = outpost.interactiveElements.firstWhere(
      (e) => e.interactionType == 'tap' && _isSubmitLabel(e.label),
    );
    
    return Stratagem(
      name: 'gauntlet_double_submit_${_slugify(outpost.routePattern)}',
      description: 'Submit form twice rapidly on ${outpost.displayName}',
      tags: ['gauntlet', 'stress', 'double-submit'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        StratagemStep(
          id: 1,
          action: StratagemAction.tap,
          description: 'First submit',
          target: StratagemTarget(label: submitBtn.label, type: submitBtn.widgetType),
          waitAfter: const Duration(milliseconds: 50),
        ),
        StratagemStep(
          id: 2,
          action: StratagemAction.tap,
          description: 'Second submit (rapid double-tap)',
          target: StratagemTarget(label: submitBtn.label, type: submitBtn.widgetType),
          waitAfter: const Duration(seconds: 2),
        ),
        StratagemStep(
          id: 3,
          action: StratagemAction.verify,
          description: 'Verify no crash or double-action',
          expectations: StratagemExpectations(
            settleTimeout: const Duration(seconds: 3),
          ),
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    );
  }
  
  // ... more generators for each pattern
  
  static bool _isSubmitLabel(String? label) {
    if (label == null) return false;
    final lower = label.toLowerCase();
    return lower.contains('submit') || lower.contains('login') ||
           lower.contains('save') || lower.contains('register') ||
           lower.contains('sign') || lower.contains('create') ||
           lower.contains('send') || lower.contains('enter');
  }
  
  static String _slugify(String input) =>
      input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
}

/// Gauntlet test intensity.
enum GauntletIntensity {
  /// Essential edge cases only (~5-10 per screen).
  quick,
  
  /// Standard coverage (~10-20 per screen).
  standard,
  
  /// Exhaustive stress testing (~20-40 per screen).
  thorough,
}

/// A named edge-case pattern in the [Gauntlet] catalog.
class GauntletPattern {
  /// Pattern identifier (e.g., `"rapid_fire"`).
  final String id;
  
  /// Human-readable name (e.g., `"Rapid-Fire Tap"`).
  final String name;
  
  /// Titan-themed name (e.g., `"rapid_fire"`).
  final String titanName;
  
  /// Description of what this pattern tests.
  final String description;
  
  /// Which element types this pattern applies to.
  final List<String> applicableInteractionTypes;
  
  /// Edge-case category.
  final GauntletCategory category;
  
  /// Risk level being tested.
  final GauntletRisk risk;
  
  Map<String, dynamic> toJson() => { ... };
}

/// Categories of edge-case testing.
enum GauntletCategory {
  interactionStress,
  inputBoundaries,
  navigationStress,
  stateIntegrity,
  timingAsync,
}

/// Risk level of a Gauntlet pattern.
enum GauntletRisk {
  /// Could crash the app.
  critical,
  
  /// Could cause incorrect behavior.
  high,
  
  /// Could cause visual glitches.
  medium,
  
  /// Cosmetic or minor UX issue.
  low,
}
```

### 6.4 Input Boundary Generator Detail

```dart
static List<Stratagem> _inputBoundaries(
  Outpost outpost,
  Map<String, dynamic>? preconditions,
) {
  final results = <Stratagem>[];
  final textFields = outpost.interactiveElements
      .where((e) => e.interactionType == 'textInput')
      .toList();
  
  if (textFields.isEmpty) return results;
  
  // 1. Empty submit — fill nothing, tap submit
  results.add(Stratagem(
    name: 'gauntlet_hollow_strike_${_slugify(outpost.routePattern)}',
    description: 'Submit form with all fields empty',
    tags: ['gauntlet', 'input', 'empty-submit'],
    startRoute: outpost.routePattern,
    preconditions: preconditions,
    steps: [
      // Clear all fields first
      ...textFields.asMap().entries.map((e) => StratagemStep(
        id: e.key + 1,
        action: StratagemAction.clearText,
        target: StratagemTarget(
          label: e.value.label,
          type: e.value.widgetType,
        ),
      )),
      // Tap submit
      if (_findSubmitButton(outpost) case final btn?)
        StratagemStep(
          id: textFields.length + 1,
          action: StratagemAction.tap,
          target: StratagemTarget(label: btn.label, type: btn.widgetType),
          description: 'Submit empty form',
        ),
    ],
    failurePolicy: StratagemFailurePolicy.continueAll,
  ));
  
  // 2. Special characters in each field
  const specialInputs = [
    '<script>alert("xss")</script>',
    '🔥💀🎭€£¥',
    'مرحبا بالعالم', // RTL Arabic
    '   \t\n   ', // Whitespace only
    'A' * 10000, // Very long string
    "Robert'); DROP TABLE Students;--", // SQL injection
    '../../../etc/passwd', // Path traversal
  ];
  
  for (final field in textFields) {
    for (final input in specialInputs) {
      results.add(Stratagem(
        name: 'gauntlet_rune_injection_${_slugify(field.label ?? "field")}_${_slugify(input.substring(0, 10))}',
        description: 'Enter special characters in ${field.label}: ${input.substring(0, 20)}...',
        tags: ['gauntlet', 'input', 'special-chars'],
        startRoute: outpost.routePattern,
        preconditions: preconditions,
        steps: [
          StratagemStep(
            id: 1,
            action: StratagemAction.enterText,
            target: StratagemTarget(label: field.label, type: field.widgetType),
            value: input,
            clearFirst: true,
          ),
          StratagemStep(
            id: 2,
            action: StratagemAction.verify,
            description: 'Verify no crash after special input',
          ),
        ],
        failurePolicy: StratagemFailurePolicy.continueAll,
      ));
    }
  }
  
  // 3. Slider extremes
  final sliders = outpost.interactiveElements
      .where((e) => e.interactionType == 'slider')
      .toList();
  for (final slider in sliders) {
    results.add(Stratagem(
      name: 'gauntlet_edge_of_range_${_slugify(slider.label ?? "slider")}',
      description: 'Drag ${slider.label ?? "slider"} to extremes',
      tags: ['gauntlet', 'input', 'slider-extremes'],
      startRoute: outpost.routePattern,
      preconditions: preconditions,
      steps: [
        StratagemStep(
          id: 1,
          action: StratagemAction.adjustSlider,
          target: StratagemTarget(label: slider.label, type: slider.widgetType),
          value: '0', // Minimum
        ),
        StratagemStep(
          id: 2,
          action: StratagemAction.adjustSlider,
          target: StratagemTarget(label: slider.label, type: slider.widgetType),
          value: '1', // Maximum
        ),
        StratagemStep(
          id: 3,
          action: StratagemAction.verify,
          description: 'Verify slider state after extremes',
        ),
      ],
      failurePolicy: StratagemFailurePolicy.continueAll,
    ));
  }
  
  return results;
}
```

---

## 7. Phase 4: Campaign — AI Blueprint Orchestrator

### 7.1 Overview

A **Campaign** is an ordered suite of Stratagems with dependency resolution, prerequisite injection, and edge-case augmentation. It's the top-level artifact that AI produces as a comprehensive test plan.

### 7.2 Data Model

```dart
/// **Campaign** — An orchestrated suite of Stratagems.
///
/// Unlike `executeStratagemSuite()` (flat directory scan), a Campaign
/// is a DAG of Stratagems with:
/// - **Dependencies**: Stratagem B depends on Stratagem A (login before dashboard)
/// - **Prerequisites**: Auto-injected setup Stratagems from Lineage
/// - **Edge cases**: Gauntlet-generated stress tests per screen
/// - **Ordering**: Topological sort ensures correct execution order
///
/// ## How AI Creates a Campaign
///
/// 1. AI receives the Terrain (flow graph) and Lineage (prerequisites)
/// 2. AI selects which flows to test (or tests all flows)
/// 3. Campaign engine:
///    a. Resolves prerequisites via Lineage
///    b. Injects Gauntlet edge cases per screen
///    c. Topologically sorts the Stratagem DAG
///    d. Executes in order, passing state between steps
///
/// ```dart
/// final campaign = Campaign.fromJson(aiGeneratedJson);
/// final results = await campaign.execute();
/// // results: Map<String, Verdict> keyed by Stratagem name
/// ```
class Campaign {
  /// Campaign name.
  final String name;
  
  /// Human-readable description.
  final String description;
  
  /// Tags for categorization.
  final List<String> tags;
  
  /// The core Stratagems in this Campaign.
  ///
  /// These are the "user-facing" tests — the ones AI explicitly
  /// wants to run. Prerequisites are resolved automatically.
  final List<CampaignEntry> entries;
  
  /// Shared test data across all Stratagems.
  ///
  /// Individual Stratagems can override with their own testData.
  final Map<String, dynamic>? sharedTestData;
  
  /// Whether to generate and include Gauntlet edge cases.
  final bool includeGauntlet;
  
  /// Gauntlet intensity if edge cases are included.
  final GauntletIntensity gauntletIntensity;
  
  /// How to handle failures across the campaign.
  final CampaignFailurePolicy failurePolicy;
  
  /// Total campaign timeout.
  final Duration timeout;
  
  /// Execute the full Campaign.
  ///
  /// 1. Resolves prerequisites via Lineage
  /// 2. Optionally generates Gauntlet edge cases
  /// 3. Topologically sorts all Stratagems
  /// 4. Executes in order
  /// 5. Produces Debrief (combined analysis)
  Future<CampaignResult> execute({
    required Terrain terrain,
    bool captureScreenshots = false,
    void Function(String stratagemName, Verdict verdict)? onStratagemComplete,
  }) async { ... }
  
  /// AI template for generating Campaigns.
  static String get templateDescription => '''
Write a Campaign JSON to orchestrate multiple Stratagems:

REQUIRED FIELDS:
- name: campaign identifier
- entries: array of Stratagem entries to execute

EACH ENTRY HAS:
- stratagem: a complete Stratagem JSON (see Stratagem template)
- dependsOn: array of Stratagem names that must succeed first
- skipIf: condition to skip this entry (e.g., "previous_failed")

OPTIONAL FIELDS:
- description: what this campaign tests
- tags: category tags (e.g., ["regression", "auth"])
- sharedTestData: key-value data available to all Stratagems
- includeGauntlet: true/false — auto-generate edge-case tests (default: false)
- gauntletIntensity: "quick" | "standard" | "thorough" (default: "standard")
- failurePolicy: "abortOnFirst" | "continueAll" | "skipDependents" (default: "skipDependents")
- timeout: total campaign timeout in milliseconds

DEPENDENCY NOTES:
- Use dependsOn to declare that one Stratagem requires another to pass first
- The Campaign engine auto-resolves execution order (topological sort)
- If a dependency fails and failurePolicy is "skipDependents", dependent entries are skipped
- You do NOT need to manually write login/setup steps — the engine auto-injects
  prerequisite Stratagems from the app's Lineage (prerequisite chain)

AUTOMATIC PREREQUISITES:
- If your Stratagem starts at a route that requires login, the engine automatically
  prepends the login steps
- If your Stratagem starts at a deep route, the engine auto-generates navigation
  steps to get there
- You only need to write the TEST steps, not the SETUP steps

GAUNTLET (EDGE CASES):
- Set includeGauntlet: true to auto-generate stress tests for each screen visited
- This adds rapid-tap, empty-submit, special-character, and navigation-stress tests
- Gauntlet tests run after the main Stratagems, using the same prerequisites
''';
  
  static Map<String, dynamic> get template => { ... };
  
  Map<String, dynamic> toJson() => { ... };
  factory Campaign.fromJson(Map<String, dynamic> json) => ...;
}

/// A single entry in a [Campaign].
class CampaignEntry {
  /// The Stratagem to execute.
  final Stratagem stratagem;
  
  /// Names of Stratagems that must succeed before this one runs.
  final List<String> dependsOn;
  
  /// Condition to skip this entry.
  final String? skipIf;
  
  /// Override test data for this specific entry.
  final Map<String, dynamic>? testDataOverride;
  
  Map<String, dynamic> toJson() => { ... };
  factory CampaignEntry.fromJson(Map<String, dynamic> json) => ...;
}

/// Result of a [Campaign] execution.
class CampaignResult {
  /// Campaign that was executed.
  final Campaign campaign;
  
  /// Results keyed by Stratagem name.
  final Map<String, Verdict> verdicts;
  
  /// Stratagems that were skipped (dependency failed).
  final List<String> skipped;
  
  /// Auto-injected prerequisite Stratagems and their results.
  final Map<String, Verdict> prerequisiteVerdicts;
  
  /// Gauntlet edge-case results (if generated).
  final Map<String, Verdict>? gauntletVerdicts;
  
  /// Combined Debrief analysis.
  final Debrief debrief;
  
  /// Overall pass rate.
  double get passRate {
    final total = verdicts.length;
    if (total == 0) return 1.0;
    final passed = verdicts.values.where((v) => v.passed).length;
    return passed / total;
  }
  
  /// Human-readable report.
  String toReport() => ...;
  
  /// AI-readable diagnostic.
  String toAiDiagnostic() => ...;
  
  Map<String, dynamic> toJson() => { ... };
}

/// How to handle failures in a Campaign.
enum CampaignFailurePolicy {
  /// Stop entire campaign on first failure.
  abortOnFirst,
  
  /// Continue all stratagems regardless of failures.
  continueAll,
  
  /// Skip stratagems whose dependencies failed.
  skipDependents,
}
```

### 7.3 Topological Execution

```
ALGORITHM: Campaign Execution Order

INPUT: List<CampaignEntry> with dependsOn references
OUTPUT: Ordered execution list

1. Build adjacency list: entry.name → entry.dependsOn
2. Detect cycles (throw CampaignCycleException)
3. Topological sort (Kahn's algorithm):
   a. Find entries with no dependencies → first batch
   b. Execute batch in parallel (independent Stratagems)
   c. Remove completed entries from dependency lists
   d. Find next batch of entries with all deps satisfied
   e. Repeat until all entries processed
4. For each batch:
   a. Execute all Stratagems in the batch
   b. Check results:
      - If any dependency failed and policy == skipDependents → skip dependents
      - If any failed and policy == abortOnFirst → stop campaign
      - If policy == continueAll → continue regardless
```

### 7.4 Automatic Prerequisite Injection

```
ALGORITHM: Auto-inject prerequisites before Campaign execution

INPUT: Campaign entries, Terrain graph
OUTPUT: Augmented entry list with prerequisite Stratagems prepended

For each CampaignEntry:
  1. Get the Stratagem's startRoute
  2. Resolve Lineage for that route: Lineage.resolve(terrain, targetRoute: startRoute)
  3. If Lineage has prerequisites:
     a. Generate setup Stratagem from Lineage.toSetupStratagem()
     b. Prepend as a hidden entry with name "prereq_{originalName}"
     c. Set original entry's dependsOn to include "prereq_{originalName}"
  4. If Lineage shows requiresAuth:
     a. Inject login testData from sharedTestData
     b. Apply to the setup Stratagem's testData
```

---

## 8. Phase 5: Feedback Loop — Learning from Verdicts

### 8.1 Overview

The **Debrief** engine analyzes Verdict results and feeds insights back to the Terrain and AI, enabling the system to learn and improve over time.

### 8.2 What AI Learns

```dart
/// **Debrief** — Analysis of Verdict results for learning.
///
/// After a Campaign or Stratagem executes, the Debrief:
/// 1. Updates the Terrain with newly discovered routes/elements
/// 2. Identifies patterns in failures
/// 3. Produces actionable insights for the AI's next iteration
///
/// ## Learning Loop
///
/// ```
/// AI generates Campaign
///   → Executed → Verdict(s) produced
///   → Debrief analyzes verdicts
///   → Terrain updated with new knowledge
///   → Debrief.insights sent back to AI
///   → AI generates improved Campaign
///   → Repeat until all tests pass or defects found
/// ```
class Debrief {
  /// Verdicts being analyzed.
  final List<Verdict> verdicts;
  
  /// Terrain to update with discoveries.
  final Terrain terrain;
  
  /// Perform the debrief analysis.
  DebriefReport analyze() {
    final insights = <DebriefInsight>[];
    
    for (final verdict in verdicts) {
      // 1. Update Terrain from verdict
      Scout.instance.analyzeVerdict(verdict);
      
      // 2. Analyze failures
      for (final step in verdict.steps.where((s) => !s.passed)) {
        insights.add(_analyzeFailure(step, verdict));
      }
      
      // 3. Detect patterns
      insights.addAll(_detectPatterns(verdict));
    }
    
    return DebriefReport(
      verdicts: verdicts,
      insights: insights,
      terrainUpdates: _summarizeTerrainUpdates(),
      suggestedNextActions: _suggestNextActions(insights),
    );
  }
  
  DebriefInsight _analyzeFailure(VerdictStep step, Verdict verdict) {
    return switch (step.failure?.type) {
      VerdictFailureType.targetNotFound => DebriefInsight(
        type: InsightType.elementNotFound,
        message: 'Element "${step.failure!.expected}" not found on ${step.route}',
        suggestion: 'The element may have a different label. '
            'Visible elements: ${step.postTableau?.glyphs.take(10).map((g) => g.label).where((l) => l != null).join(", ")}',
        actionable: true,
        fixSuggestion: 'Update target label to match one of the visible elements',
      ),
      
      VerdictFailureType.wrongRoute => DebriefInsight(
        type: InsightType.unexpectedNavigation,
        message: 'Expected route ${step.failure!.expected}, got ${step.failure!.actual}',
        suggestion: 'The app may have redirected (auth guard?). '
            'Update the Lineage with this redirect pattern.',
        actionable: true,
        fixSuggestion: 'Add auth prerequisite or update expected route',
      ),
      
      VerdictFailureType.timeout => DebriefInsight(
        type: InsightType.performanceIssue,
        message: 'Step timed out after ${step.duration.inMilliseconds}ms',
        suggestion: 'The operation may be slower than expected. '
            'Consider increasing timeout or checking for network issues.',
        actionable: true,
        fixSuggestion: 'Increase step timeout or add explicit wait step',
      ),
      
      _ => DebriefInsight(
        type: InsightType.general,
        message: 'Step failed: ${step.failure?.message}',
        suggestion: step.failure?.suggestions?.join('; ') ?? '',
        actionable: false,
      ),
    };
  }
  
  List<DebriefInsight> _detectPatterns(Verdict verdict) {
    final insights = <DebriefInsight>[];
    
    // Pattern: All steps after a route fail → probably missing prerequisite
    final failedSteps = verdict.steps.where((s) => !s.passed).toList();
    if (failedSteps.isNotEmpty && failedSteps.first.failure?.type == VerdictFailureType.wrongRoute) {
      insights.add(DebriefInsight(
        type: InsightType.missingPrerequisite,
        message: 'First failure is a route mismatch — subsequent failures may be cascading',
        suggestion: 'This screen likely requires a prerequisite step '
            '(e.g., login). Resolve the route issue first.',
        actionable: true,
        fixSuggestion: 'Add prerequisite: navigate to ${failedSteps.first.failure!.expected} first',
      ));
    }
    
    // Pattern: targetNotFound on multiple steps → wrong screen
    final notFoundCount = failedSteps.where(
      (s) => s.failure?.type == VerdictFailureType.targetNotFound,
    ).length;
    if (notFoundCount >= 3) {
      insights.add(DebriefInsight(
        type: InsightType.wrongScreen,
        message: '$notFoundCount elements not found — possibly on the wrong screen',
        suggestion: 'The Stratagem may be targeting a different version '
            'of the screen, or the screen layout changed.',
        actionable: true,
        fixSuggestion: 'Re-scan the screen with getAiContext() and update targets',
      ));
    }
    
    return insights;
  }
  
  List<String> _suggestNextActions(List<DebriefInsight> insights) {
    final actions = <String>[];
    
    if (insights.any((i) => i.type == InsightType.missingPrerequisite)) {
      actions.add('RESOLVE: Add missing prerequisites (likely authentication)');
    }
    if (insights.any((i) => i.type == InsightType.elementNotFound)) {
      actions.add('UPDATE: Refresh element targets using getAiContext()');
    }
    if (insights.any((i) => i.type == InsightType.performanceIssue)) {
      actions.add('TUNE: Increase timeouts or add wait steps for slow operations');
    }
    if (insights.isEmpty) {
      actions.add('EXPAND: All tests passed — consider adding Gauntlet edge cases');
    }
    
    return actions;
  }
}

/// A single insight from a [Debrief] analysis.
class DebriefInsight {
  final InsightType type;
  final String message;
  final String suggestion;
  final bool actionable;
  final String? fixSuggestion;
  
  Map<String, dynamic> toJson() => { ... };
}

/// Types of insights the Debrief can produce.
enum InsightType {
  elementNotFound,
  unexpectedNavigation,
  missingPrerequisite,
  wrongScreen,
  performanceIssue,
  stateCorruption,
  general,
}

/// Debrief report for AI consumption.
class DebriefReport {
  final List<Verdict> verdicts;
  final List<DebriefInsight> insights;
  final String terrainUpdates;
  final List<String> suggestedNextActions;
  
  /// AI-readable summary.
  String toAiSummary() => '''
DEBRIEF REPORT
==============
VERDICTS: ${verdicts.length} Stratagems executed
PASSED: ${verdicts.where((v) => v.passed).length}/${verdicts.length}
INSIGHTS: ${insights.length}

${insights.map((i) => '${i.type.name.toUpperCase()}: ${i.message}\n  → ${i.suggestion}${i.fixSuggestion != null ? '\n  FIX: ${i.fixSuggestion}' : ''}').join('\n\n')}

TERRAIN UPDATES:
$terrainUpdates

SUGGESTED NEXT ACTIONS:
${suggestedNextActions.map((a) => '  • $a').join('\n')}
''';
  
  Map<String, dynamic> toJson() => { ... };
}
```

---

## 9. Phase 6: Integration — Colossus API & Lens UI

### 9.1 Colossus API Additions

```dart
// Add to Colossus class:

// ---- Scout & Terrain ----

/// Get the Scout instance for flow discovery.
Scout get scout => Scout.instance;

/// Get the current Terrain (flow graph).
Terrain get terrain => Scout.instance.terrain;

/// Analyze a Shade session to update the Terrain.
void learnFromSession(ShadeSession session) {
  Scout.instance.analyzeSession(session);
}

/// Generate exploration Stratagems for unmapped routes.
List<Stratagem> generateSorties() {
  return Scout.instance.generateAllSorties();
}

// ---- Lineage ----

/// Resolve prerequisites for reaching a specific route.
Lineage resolveLineage(String targetRoute) {
  return Lineage.resolve(terrain, targetRoute: targetRoute);
}

/// Get prerequisite chain as AI-readable text.
String getLineageSummary(String targetRoute) {
  return resolveLineage(targetRoute).toAiSummary();
}

// ---- Gauntlet ----

/// Generate edge-case tests for a specific screen.
List<Stratagem> generateGauntlet(String routePattern, {
  GauntletIntensity intensity = GauntletIntensity.standard,
}) {
  final outpost = terrain.outposts[routePattern];
  if (outpost == null) return [];
  final lineage = resolveLineage(routePattern);
  return Gauntlet.generateFor(outpost, lineage: lineage, intensity: intensity);
}

// ---- Campaign ----

/// Execute a Campaign (ordered Stratagem suite with dependencies).
Future<CampaignResult> executeCampaign(Campaign campaign, {
  bool captureScreenshots = false,
}) async { ... }

/// Execute a Campaign from JSON.
Future<CampaignResult> executeCampaignJson(Map<String, dynamic> json, {
  bool captureScreenshots = false,
}) async {
  final campaign = Campaign.fromJson(json);
  return executeCampaign(campaign, captureScreenshots: captureScreenshots);
}

// ---- Enhanced AI Context ----

/// Get comprehensive AI context including Terrain and Lineage.
///
/// This is the primary method AI agents call to understand the app
/// and generate Campaigns.
Future<Map<String, dynamic>> getAiBlueprint() async {
  final baseContext = await getAiContext();
  
  return {
    ...baseContext,
    'terrain': terrain.toJson(),
    'terrainMap': terrain.toAiMap(),
    'terrainMermaid': terrain.toMermaid(),
    'campaignTemplate': Campaign.templateDescription,
    'gauntletCatalog': Gauntlet.catalog.map((p) => p.toJson()).toList(),
    'discoveredScreens': terrain.outposts.values.map((o) => o.toAiSummary()).toList(),
    'authProtectedRoutes': terrain.authProtectedScreens.map((o) => o.routePattern).toList(),
    'publicRoutes': terrain.publicScreens.map((o) => o.routePattern).toList(),
    'deadEnds': terrain.deadEnds.map((o) => o.routePattern).toList(),
    'unreliableTransitions': terrain.unreliableMarches.map((m) => {
      'from': m.fromRoute,
      'to': m.toRoute,
      'observations': m.observationCount,
    }).toList(),
  };
}

// ---- Debrief ----

/// Analyze verdicts and produce a debrief report.
DebriefReport debrief(List<Verdict> verdicts) {
  return Debrief(verdicts: verdicts, terrain: terrain).analyze();
}
```

### 9.2 Lens UI Additions

```
New Lens Tab Sections:

1. TERRAIN MAP
   - Mermaid flow graph visualization
   - Screen count, transition count, coverage percentage
   - Tap screen to see Outpost detail (elements, exits, entrances)
   
2. LINEAGE VIEWER
   - Dropdown: select target route
   - Shows prerequisite chain
   - "Generate Setup Stratagem" button → copies to clipboard
   
3. GAUNTLET LAUNCHER
   - Dropdown: select screen
   - Intensity selector (quick / standard / thorough)
   - Preview edge cases before running
   - "Run Gauntlet" button → executes and shows results
   
4. CAMPAIGN BUILDER
   - JSON input for Campaign
   - "Execute Campaign" button
   - Real-time progress (which Stratagem is running)
   - Results summary with pass/fail per Stratagem
   
5. DEBRIEF DASHBOARD
   - Historical verdict analysis
   - Insight cards with fix suggestions
   - "Copy AI Debrief" → copies toAiSummary() to clipboard
```

---

## 10. AI Prompt Engineering

### 10.1 The Complete AI Prompt

When an AI agent wants to test the app, it sends a single request to `getAiBlueprint()` and receives everything needed:

```
AI SYSTEM PROMPT FOR TITAN TEST GENERATION
==========================================

You are a test strategist for a Flutter application using the Titan framework.
Your job is to generate comprehensive test Campaigns.

## Available Information

You will receive:
1. TERRAIN MAP: Graph of all discovered screens and transitions
2. SCREEN DETAILS: Interactive elements on each screen
3. PREREQUISITES: What setup is needed before each screen
4. GAUNTLET CATALOG: Available edge-case patterns
5. CURRENT SCREEN: Live Tableau snapshot

## Your Task

Generate a Campaign JSON that:
1. Tests all critical user flows (login, main features, navigation)
2. Includes proper dependencies (login before authenticated features)
3. Has clear expectations (route changes, element presence/absence)
4. Uses testData for parameterized values
5. Optionally includes Gauntlet edge cases

## Key Rules

1. You do NOT need to write login/setup steps manually — the engine auto-injects them
2. Use `dependsOn` to declare ordering between Stratagems
3. Set `includeGauntlet: true` to auto-generate edge-case tests
4. Use `sharedTestData` for values used across multiple Stratagems
5. Target elements by label and type, NOT by coordinates
6. Every Stratagem should have expectations to verify success

## Example Campaign

{SEE SECTION 12 FOR FULL EXAMPLES}
```

### 10.2 Teaching AI About Blueprint Creation

The key to AI learning is the **feedback loop**:

```
ITERATION 1:
  AI: "I see a login screen at /login with TextField 'Hero Name' and button 'Enter the Realm'"
  AI generates: login_flow_test Stratagem
  Result: PASSED ✅
  Debrief: "Login flow working. 1 new route discovered: / (home)"
  AI learns: Login button navigates to /

ITERATION 2:
  AI: "I now see / has tabs: Quests, Hero, Enterprise, Spark, Shade"
  AI generates: navigation_campaign (tap each tab)
  Result: 3/5 PASSED, 2 FAILED (Enterprise and Spark tabs don't match expected labels)
  Debrief: "Tab labels are 'Enterprise Demo' not 'Enterprise'. Update targets."
  AI learns: Exact labels matter, use fuzzy matching or re-scan

ITERATION 3:
  AI: "Updated labels. All tabs working. Now testing quest detail."  
  AI generates: quest_detail_campaign with dependsOn: ["login_flow_test"]
  Result: PASSED ✅ (prerequisites auto-injected)
  Debrief: "Quest detail reachable. 2 new elements discovered."
  AI learns: Deep routes work with auto-prerequisites

ITERATION 4:
  AI: "Running Gauntlet on login screen"
  Gauntlet generates: empty_submit, special_chars, rapid_tap_login (12 edge cases)
  Result: 11/12 PASSED, 1 FAILED (rapid-tap-login caused double navigation)
  Debrief: "BUG FOUND: Rapid tapping 'Enter the Realm' causes double push"
  AI learns: This is a real bug to report!
```

---

## 11. JSON Schemas

### 11.1 Terrain JSON

```json
{
  "$schema": "titan://terrain/v1",
  "lastUpdated": "2025-01-15T10:30:00Z",
  "sessionsAnalyzed": 5,
  "stratagemExecutionsAnalyzed": 12,
  "outposts": {
    "/login": {
      "routePattern": "/login",
      "displayName": "Login Screen",
      "requiresAuth": false,
      "tags": ["auth", "form", "entry-point"],
      "observationCount": 8,
      "interactiveElements": [
        {
          "widgetType": "TextField",
          "label": "Hero Name",
          "interactionType": "textInput",
          "semanticRole": "textField",
          "isInteractive": true,
          "frequency": 8
        },
        {
          "widgetType": "ElevatedButton",
          "label": "Enter the Realm",
          "interactionType": "tap",
          "semanticRole": "button",
          "isInteractive": true,
          "frequency": 8
        }
      ],
      "exits": [
        {
          "toRoute": "/",
          "trigger": "formSubmit",
          "triggerElement": {"label": "Enter the Realm"},
          "observationCount": 6
        },
        {
          "toRoute": "/register",
          "trigger": "tap",
          "triggerElement": {"label": "Register"},
          "observationCount": 2
        }
      ],
      "entrances": [
        {
          "fromRoute": "/",
          "trigger": "redirect",
          "observationCount": 4
        }
      ]
    },
    "/": {
      "routePattern": "/",
      "displayName": "Quest List (Home)",
      "requiresAuth": true,
      "tags": ["home", "list", "tabbed"],
      "observationCount": 12,
      "interactiveElements": [ ... ],
      "exits": [ ... ],
      "entrances": [ ... ]
    }
  },
  "marches": [
    {
      "fromRoute": "/login",
      "toRoute": "/",
      "trigger": "formSubmit",
      "observationCount": 6,
      "averageDurationMs": 850
    }
  ]
}
```

### 11.2 Campaign JSON

```json
{
  "$schema": "titan://campaign/v1",
  "name": "questboard_full_regression",
  "description": "Complete regression suite for Questboard app",
  "tags": ["regression", "full"],
  "sharedTestData": {
    "heroName": "TestHero_42",
    "questId": "1"
  },
  "includeGauntlet": true,
  "gauntletIntensity": "standard",
  "failurePolicy": "skipDependents",
  "timeout": 300000,
  "entries": [
    {
      "stratagem": {
        "name": "login_happy_path",
        "startRoute": "/login",
        "steps": [
          {
            "id": 1,
            "action": "enterText",
            "target": {"label": "Hero Name", "type": "TextField"},
            "value": "${testData.heroName}",
            "clearFirst": true
          },
          {
            "id": 2,
            "action": "tap",
            "target": {"label": "Enter the Realm", "type": "ElevatedButton"},
            "expectations": {
              "route": "/",
              "elementsPresent": [{"label": "Quests"}],
              "elementsAbsent": [{"label": "Hero Name"}]
            }
          }
        ]
      },
      "dependsOn": []
    },
    {
      "stratagem": {
        "name": "navigate_all_tabs",
        "description": "Verify all bottom navigation tabs work",
        "startRoute": "/",
        "steps": [
          {
            "id": 1,
            "action": "tap",
            "target": {"label": "Hero", "type": "NavigationDestination"},
            "expectations": {"route": "/hero"}
          },
          {
            "id": 2,
            "action": "tap",
            "target": {"label": "Enterprise", "type": "NavigationDestination"},
            "expectations": {"route": "/enterprise"}
          },
          {
            "id": 3,
            "action": "tap",
            "target": {"label": "Quests", "type": "NavigationDestination"},
            "expectations": {"route": "/"}
          }
        ]
      },
      "dependsOn": ["login_happy_path"]
    },
    {
      "stratagem": {
        "name": "view_quest_detail",
        "description": "Navigate to a quest detail page",
        "startRoute": "/",
        "steps": [
          {
            "id": 1,
            "action": "tap",
            "target": {"label": "Defend the Northern Wall", "type": "ListTile"},
            "expectations": {
              "route": "/quest/${testData.questId}",
              "elementsPresent": [{"label": "Defend the Northern Wall"}]
            }
          }
        ]
      },
      "dependsOn": ["login_happy_path"]
    }
  ]
}
```

### 11.3 Lineage JSON

```json
{
  "$schema": "titan://lineage/v1",
  "targetRoute": "/quest/:id",
  "requiresAuth": true,
  "estimatedSetupMs": 3500,
  "path": [
    {"from": "/login", "to": "/", "trigger": "formSubmit"},
    {"from": "/", "to": "/quest/:id", "trigger": "tap"}
  ],
  "prerequisites": [
    {
      "description": "Log in with hero name",
      "isAuthGate": true,
      "isFormGate": true,
      "estimatedDurationMs": 2000,
      "stratagem": {
        "name": "prereq_login",
        "startRoute": "/login",
        "steps": [
          {
            "id": 1,
            "action": "enterText",
            "target": {"label": "Hero Name"},
            "value": "${testData.heroName}"
          },
          {
            "id": 2,
            "action": "tap",
            "target": {"label": "Enter the Realm"},
            "expectations": {"route": "/"}
          }
        ]
      }
    },
    {
      "description": "Navigate to quest list and tap target quest",
      "isAuthGate": false,
      "isFormGate": false,
      "estimatedDurationMs": 1500,
      "stratagem": {
        "name": "prereq_navigate_quest",
        "startRoute": "/",
        "steps": [
          {
            "id": 1,
            "action": "tap",
            "target": {"type": "ListTile", "index": 0},
            "expectations": {"route": "/quest/:id"}
          }
        ]
      }
    }
  ]
}
```

---

## 12. Example Workflows

### 12.1 Full Discovery → Blueprint → Test Cycle

```dart
// Step 1: Initialize
Colossus.init(app: const QuestboardApp());

// Step 2: Manual exploration (user browses the app)
// Shade records everything automatically

// Step 3: Build Terrain from sessions
final sessions = ShadeVault.listShort(); // All recorded sessions
for (final summary in sessions) {
  final session = await Shade.instance.loadSession(summary.id);
  Colossus.instance.learnFromSession(session);
}

// Step 4: AI receives context
final blueprint = await Colossus.instance.getAiBlueprint();
// Send `blueprint` to AI agent...

// Step 5: AI generates Campaign
final campaign = Campaign.fromJson(aiGeneratedCampaignJson);

// Step 6: Execute Campaign
final result = await Colossus.instance.executeCampaign(
  campaign, 
  captureScreenshots: true,
);

// Step 7: Debrief
print(result.debrief.toAiSummary());
// → "12/14 tests passed. 2 failures on /enterprise (label mismatch)."
// → "Gauntlet found: rapid-tap bug on login button"
// → "Suggested: Update 'Enterprise' label to 'Enterprise Demo'"

// Step 8: AI iterates
// AI reads debrief, updates Campaign, re-runs
```

### 12.2 Active Discovery Mode

```dart
// When the app is new and no manual sessions exist:

// 1. Scout generates exploration sorties
final sorties = Colossus.instance.generateSorties();

// 2. Execute sorties to discover routes
for (final sortie in sorties) {
  final verdict = await Colossus.instance.executeStratagem(sortie);
  Colossus.instance.scout.analyzeVerdict(verdict);
}

// 3. Terrain now populated with discovered screens
print(Colossus.instance.terrain.toAiMap());
// → "5 screens discovered, 8 transitions, 2 auth-protected"

// 4. Generate sorties for newly discovered screens
final moreSorties = Colossus.instance.generateSorties();
// Repeat until no more sorties generated (fully explored)
```

### 12.3 AI Learning from Failures

```
SCENARIO: AI tries to test /hero but it requires login

AI generates:
  Stratagem: "test_hero_profile"
  startRoute: "/hero"
  steps: [tap "Edit", enterText "New Name", tap "Save"]

Execution:
  Step 0 (auto): Navigate to /hero
  Result: REDIRECTED to /login (auth guard)
  Step 1: tap "Edit" → FAILED (not on /hero, on /login)

Verdict: FAILED
  failure: wrongRoute (expected: /hero, actual: /login)

Debrief:
  INSIGHT: missingPrerequisite
  MESSAGE: "First failure is route mismatch — /hero redirected to /login"
  FIX: "Add auth prerequisite — login before /hero"
  
  Terrain updated:
  - March added: /hero → /login (redirect, auth-required)
  - /hero marked as requiresAuth = true

AI 2nd attempt:
  Lineage.resolve(terrain, targetRoute: '/hero')
  → Prerequisites: [login_prerequisite]
  → Setup Stratagem auto-injected
  
  Campaign: "test_hero_profile" with dependsOn: ["login_prerequisite"]
  
  Result: PASSED ✅ (login auto-executed first)
```

---

## 13. Edge-Case Catalog

### 13.1 Complete Gauntlet Pattern Registry

```
INTERACTION STRESS (5 patterns)
├── rapid_fire: Tap same button 5x with 50ms gaps
│   Applies to: Any button/tappable element
│   Risk: CRITICAL — can cause double navigation, double API calls
│
├── double_submit: Submit form twice in 100ms
│   Applies to: Forms with submit buttons
│   Risk: CRITICAL — can cause duplicate records
│
├── tab_storm: Focus each text field for 50ms then move to next
│   Applies to: Screens with 2+ text fields
│   Risk: MEDIUM — can cause validation flickering
│
├── mid_flight_tap: Tap button during page transition animation
│   Applies to: Buttons that trigger navigation
│   Risk: HIGH — can cause concurrent navigation
│
└── retreat_under_fire: Press back while async operation runs
    Applies to: Any screen with async operations
    Risk: HIGH — can cause orphaned operations

INPUT BOUNDARIES (7 patterns)
├── hollow_strike: Submit form with all fields empty
│   Applies to: Any form
│   Risk: MEDIUM — tests validation coverage
│
├── overflow_scroll: Enter 10,000 characters
│   Applies to: Any TextField
│   Risk: MEDIUM — can cause performance degradation
│
├── rune_injection: XSS, SQL injection, path traversal strings
│   Applies to: Any TextField
│   Risk: HIGH — security vulnerability testing
│
├── glyph_storm: Zalgo, emoji sequences, RTL, CJK text
│   Applies to: Any TextField
│   Risk: MEDIUM — rendering/encoding issues
│
├── phantom_text: Only whitespace (spaces, tabs, newlines)
│   Applies to: Any TextField
│   Risk: LOW — validation edge case
│
├── titan_count: Number.MAX_SAFE_INTEGER, -1, 0, 99999999
│   Applies to: Numeric input fields
│   Risk: MEDIUM — overflow/underflow
│
└── edge_of_range: Slider to 0.0, 1.0, beyond bounds
    Applies to: Any Slider
    Risk: LOW — bounds checking

NAVIGATION STRESS (4 patterns)
├── full_retreat: Press back 10x with 100ms gaps
│   Applies to: Any screen with nav depth > 1
│   Risk: HIGH — can cause empty stack crash
│
├── ambush_arrival: Deep link directly to auth-protected route
│   Applies to: Routes behind auth guards
│   Risk: HIGH — tests guard reliability
│
├── eternal_march: Navigate A→B→A→B 5 times
│   Applies to: Any two connected screens
│   Risk: MEDIUM — memory leak detection
│
└── bedrock_back: Press back from root screen
    Applies to: Root/home screen
    Risk: LOW — should be a no-op

STATE INTEGRITY (5 patterns)
├── switch_frenzy: Toggle switch/checkbox 10x in 500ms
│   Applies to: Any Switch or Checkbox
│   Risk: MEDIUM — state sync issues
│
├── slider_tempest: Drag slider min→max→min 5 times rapidly
│   Applies to: Any Slider
│   Risk: MEDIUM — value settling issues
│
├── choice_reversal: Select A → Select B → Select A from dropdown
│   Applies to: Any Dropdown
│   Risk: LOW — state sync
│
├── half_inscription: Fill 1 of 3 required fields, submit
│   Applies to: Forms with 2+ fields
│   Risk: MEDIUM — partial validation
│
└── forgotten_outpost: Navigate away, return, verify state persists
    Applies to: Any screen with state
    Risk: MEDIUM — state restoration

TIMING & ASYNC (3 patterns)
├── patient_siege: Long press 3s instead of tap
│   Applies to: Any tappable element
│   Risk: LOW — unintended long-press behavior
│
├── avalanche_scroll: Scroll up-down-up-down rapidly 20 times
│   Applies to: Any scrollable screen
│   Risk: MEDIUM — scroll position issues, jank
│
└── impatient_general: Start async op, navigate away immediately
    Applies to: Screens with async operations
    Risk: HIGH — disposed controller issues

TOTAL: 24 patterns across 5 categories
```

### 13.2 Pattern Applicability Matrix

```
Screen Analysis:
  /login        → 12 applicable patterns (form + buttons + auth)
  /             → 8 patterns (list + tabs + navigation)
  /hero         → 10 patterns (form + toggles + auth)
  /quest/:id    → 7 patterns (detail + navigation + state)
  /register     → 14 patterns (form + multiple fields + validation)
  /enterprise   → 6 patterns (demo widgets + toggles)
  /spark        → 8 patterns (hooks + state + interactive)
  /about        → 3 patterns (minimal, public, read-only)
```

---

## 14. Test Plan

### 14.1 Test Distribution

| Component | Unit Tests | Integration Tests | Total |
|-----------|-----------|-------------------|-------|
| Signet | 25 | — | 25 |
| Outpost + OutpostElement | 30 | — | 30 |
| March + MarchTrigger | 20 | — | 20 |
| Terrain (graph queries) | 40 | 10 | 50 |
| RouteParameterizer | 25 | — | 25 |
| Scout (passive) | 30 | 10 | 40 |
| Scout (active/sortie) | 20 | 5 | 25 |
| Lineage (resolution) | 35 | 10 | 45 |
| StratagemPrerequisite | 15 | — | 15 |
| Gauntlet (generators) | 60 | 10 | 70 |
| GauntletPattern catalog | 24 | — | 24 |
| Campaign (model) | 25 | — | 25 |
| Campaign (execution) | — | 20 | 20 |
| CampaignResult | 15 | — | 15 |
| Debrief (analysis) | 30 | 5 | 35 |
| DebriefReport | 15 | — | 15 |
| Colossus API additions | — | 15 | 15 |
| AI context (getAiBlueprint) | 10 | 5 | 15 |
| **TOTAL** | **419** | **90** | **509** |

### 14.2 Test File Layout

```
test/
├── signet_test.dart              # Signet fingerprinting
├── outpost_test.dart             # Outpost + OutpostElement
├── march_test.dart               # March + MarchTrigger
├── terrain_test.dart             # Terrain graph queries
├── route_parameterizer_test.dart # Route pattern detection
├── scout_test.dart               # Scout passive + active discovery
├── lineage_test.dart             # Lineage prerequisite resolution
├── gauntlet_test.dart            # Gauntlet pattern generation
├── gauntlet_catalog_test.dart    # All 24 patterns
├── campaign_test.dart            # Campaign model + serialization
├── campaign_execution_test.dart  # Campaign execution (integration)
├── debrief_test.dart             # Debrief analysis
├── ai_blueprint_test.dart        # getAiBlueprint API
```

### 14.3 Key Test Scenarios

```
SCOUT:
  ✓ Analyze session with 3 Tableaux → creates 3 Outposts, 2 Marches
  ✓ Analyze session with duplicate screens → merges into single Outpost
  ✓ Analyze session with route change → creates March with correct trigger
  ✓ Parameterize /quest/1 + /quest/2 → /quest/:id
  ✓ Generate sortie for partially explored screen
  ✓ Return null sortie for fully explored screen
  ✓ Detect auth redirect (/dashboard → /login)

LINEAGE:
  ✓ Resolve empty lineage for public route
  ✓ Resolve login prerequisite for auth-protected route
  ✓ Resolve multi-hop prerequisite (login → list → detail)
  ✓ Generate setup Stratagem from lineage
  ✓ Detect auth gate from redirect March
  ✓ Handle unreachable route (no path exists)

GAUNTLET:
  ✓ Generate rapid_fire for each button on login screen
  ✓ Generate hollow_strike for form screens only
  ✓ Skip input-boundary patterns for screens without text fields
  ✓ Include navigation-stress only for screens with depth > 1
  ✓ Apply correct intensity filter (quick vs standard vs thorough)
  ✓ Attach prerequisites from lineage

CAMPAIGN:
  ✓ Topological sort with no dependencies → original order
  ✓ Topological sort with A→B→C chain → correct order
  ✓ Detect circular dependency → throws exception
  ✓ Skip dependent entries when prerequisite fails
  ✓ Auto-inject login prerequisite
  ✓ Merge sharedTestData with per-entry overrides
  ✓ Include Gauntlet edge cases when flag is true

DEBRIEF:
  ✓ Identify missing prerequisite from wrongRoute failures
  ✓ Identify wrong screen from 3+ targetNotFound failures
  ✓ Suggest timeout increase for timeout failures
  ✓ Update Terrain from verdict results
  ✓ Generate correct suggestedNextActions
```

---

## Implementation Priority

| Phase | Components | LOC Est. | Test Est. | Priority |
|-------|-----------|----------|-----------|----------|
| **Phase 1** | Signet, Outpost, March, Terrain, RouteParameterizer, Scout | ~900 | ~190 | P0 — Foundation |
| **Phase 2** | Lineage, StratagemPrerequisite, auth detection | ~500 | ~60 | P0 — Critical path |
| **Phase 3** | Gauntlet, GauntletPattern, all 24 patterns | ~800 | ~94 | P1 — High value |
| **Phase 4** | Campaign, CampaignEntry, CampaignResult, topo sort | ~600 | ~60 | P1 — Orchestration |
| **Phase 5** | Debrief, DebriefInsight, DebriefReport, learning loop | ~400 | ~50 | P2 — Intelligence |
| **Phase 6** | Colossus API, Lens UI, getAiBlueprint | ~300 | ~55 | P2 — Integration |
| **TOTAL** | | **~3,500** | **~509** | |

---

## File Layout

```
lib/src/
├── discovery/
│   ├── signet.dart              # Screen fingerprint
│   ├── outpost.dart             # Screen node
│   ├── march.dart               # Transition edge
│   ├── terrain.dart             # Flow graph
│   ├── scout.dart               # Discovery engine
│   └── route_parameterizer.dart # Route pattern detection
├── testing/
│   ├── stratagem.dart           # (existing)
│   ├── stratagem_runner.dart    # (existing)
│   ├── verdict.dart             # (existing)
│   ├── lineage.dart             # Prerequisite chain
│   ├── gauntlet.dart            # Edge-case generator
│   ├── campaign.dart            # Blueprint orchestrator
│   └── debrief.dart             # Feedback analysis
├── colossus.dart                # (existing, add new APIs)
└── integration/
    └── shade_lens_tab.dart      # (existing, add new UI sections)
```

---

## Summary

This design transforms Colossus from a **test execution engine** into an **autonomous test strategist**:

1. **Scout** maps the app by observing sessions → builds **Terrain** (flow graph)
2. **Lineage** resolves prerequisite chains → auto-injects login/setup steps
3. **Gauntlet** generates 24 edge-case patterns → catches bugs testers would find
4. **Campaign** orchestrates ordered Stratagem suites → dependency-aware execution
5. **Debrief** analyzes results and updates knowledge → AI improves each iteration

The AI loop:
```
Observe → Map → Analyze → Generate → Execute → Learn → Repeat
```

Every component is JSON-serializable, AI-readable, and incrementally buildable. The system grows smarter with every session observed and every Stratagem executed.
