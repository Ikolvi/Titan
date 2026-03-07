import 'dart:collection';
import 'dart:convert';

import 'march.dart';
import 'outpost.dart';

// ---------------------------------------------------------------------------
// Terrain — The Complete Flow Graph
// ---------------------------------------------------------------------------

/// **Terrain** — the complete flow graph of the app.
///
/// Built incrementally by the [Scout] as it observes user sessions
/// and Stratagem executions. Contains all known screens ([Outpost]s)
/// and transitions ([March]es).
///
/// ## Why "Terrain"?
///
/// The battlefield terrain that the Titan surveys before attacking. Every
/// corridor, gate, and defensive position is mapped for the AI
/// strategist to plan its Campaign.
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
/// final aiMap = terrain.toAiMap();
/// ```
class Terrain {
  /// All discovered screens keyed by route pattern.
  final Map<String, Outpost> outposts;

  /// When the Terrain was last updated.
  DateTime lastUpdated;

  /// Total Shade sessions analyzed to build this Terrain.
  int sessionsAnalyzed;

  /// Total Stratagem executions analyzed.
  int stratagemExecutionsAnalyzed;

  /// Creates a [Terrain].
  Terrain({
    Map<String, Outpost>? outposts,
    DateTime? lastUpdated,
    this.sessionsAnalyzed = 0,
    this.stratagemExecutionsAnalyzed = 0,
  })  : outposts = outposts ?? {},
        lastUpdated = lastUpdated ?? DateTime.now();

  // -----------------------------------------------------------------------
  // Cache — invalidated by [invalidateCache] whenever the graph mutates.
  // -----------------------------------------------------------------------

  List<March>? _marchesCache;
  List<Outpost>? _deadEndsCache;
  List<March>? _unreliableMarchesCache;

  /// Invalidate all cached derived data.
  ///
  /// Call this after mutating [outposts] or their exits, e.g. after
  /// [Scout.analyzeSession]. The [reset] method also calls this.
  void invalidateCache() {
    _marchesCache = null;
    _deadEndsCache = null;
    _unreliableMarchesCache = null;
  }

  // -----------------------------------------------------------------------
  // Accessors
  // -----------------------------------------------------------------------

  /// All discovered March transitions (deduplicated from Outpost exits).
  ///
  /// The result is cached and reused until [invalidateCache] is called.
  List<March> get marches {
    if (_marchesCache != null) return _marchesCache!;
    final seen = <String>{};
    final result = <March>[];
    for (final outpost in outposts.values) {
      for (final march in outpost.exits) {
        final key = '${march.fromRoute}→${march.toRoute}:'
            '${march.triggerElementLabel}';
        if (seen.add(key)) result.add(march);
      }
    }
    return _marchesCache = List.unmodifiable(result);
  }

  /// Total number of discovered screens.
  int get screenCount => outposts.length;

  /// Total number of discovered transitions.
  int get transitionCount => marches.length;

  // -----------------------------------------------------------------------
  // Graph Queries
  // -----------------------------------------------------------------------

  /// Get all screens reachable from a starting route.
  ///
  /// Uses BFS to traverse the flow graph.
  List<Outpost> reachableFrom(String routePattern) {
    final start = outposts[routePattern];
    if (start == null) return [];

    final visited = <String>{routePattern};
    final queue = Queue<String>()..add(routePattern);
    final result = <Outpost>[start];

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final outpost = outposts[current];
      if (outpost == null) continue;

      for (final exit in outpost.exits) {
        if (visited.add(exit.toRoute)) {
          queue.add(exit.toRoute);
          final target = outposts[exit.toRoute];
          if (target != null) result.add(target);
        }
      }
    }

    return result;
  }

  /// Get the shortest path between two screens.
  ///
  /// Returns ordered list of [March]es, or null if no path exists.
  /// Uses BFS for shortest path in unweighted graph.
  List<March>? shortestPath(String from, String to) {
    if (from == to) return [];
    if (!outposts.containsKey(from)) return null;

    final visited = <String>{from};
    final queue = Queue<_PathNode>()
      ..add(_PathNode(route: from, path: []));

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      final outpost = outposts[node.route];
      if (outpost == null) continue;

      for (final exit in outpost.exits) {
        if (exit.toRoute == to) {
          return [...node.path, exit];
        }
        if (visited.add(exit.toRoute)) {
          queue.add(_PathNode(
            route: exit.toRoute,
            path: [...node.path, exit],
          ));
        }
      }
    }

    return null; // No path found
  }

  /// Get all screens that require authentication.
  List<Outpost> get authProtectedScreens =>
      outposts.values.where((o) => o.requiresAuth).toList();

  /// Get all screens reachable without authentication.
  List<Outpost> get publicScreens =>
      outposts.values.where((o) => !o.requiresAuth).toList();

  /// Get screens with no observed exits (dead ends or terminal screens).
  ///
  /// The result is cached and reused until [invalidateCache] is called.
  List<Outpost> get deadEnds =>
      _deadEndsCache ??= List.unmodifiable(
        outposts.values.where((o) => o.exits.isEmpty).toList(),
      );

  /// Get screens with no observed entrances (entry points).
  ///
  /// These are root screens or screens only reachable via deep link.
  List<Outpost> get entryPoints =>
      outposts.values.where((o) => o.entrances.isEmpty).toList();

  /// Get unreliable transitions (observed only once).
  ///
  /// The result is cached and reused until [invalidateCache] is called.
  List<March> get unreliableMarches =>
      _unreliableMarchesCache ??= List.unmodifiable(
        marches.where((m) => !m.isReliable).toList(),
      );

  /// Whether a route pattern exists in the Terrain.
  bool hasRoute(String routePattern) => outposts.containsKey(routePattern);

  // -----------------------------------------------------------------------
  // AI Output
  // -----------------------------------------------------------------------

  /// Complete AI-readable map of the app.
  ///
  /// Returns a structured text document the AI can use to understand
  /// the entire app flow and generate comprehensive Stratagems.
  String toAiMap() {
    final buffer = StringBuffer();
    buffer.writeln('APP TERRAIN MAP');
    buffer.writeln('===============');
    buffer.writeln(
      'Screens: $screenCount | Transitions: $transitionCount | '
      'Sessions analyzed: $sessionsAnalyzed',
    );
    buffer.writeln(
      'Auth-protected: ${authProtectedScreens.length} | '
      'Public: ${publicScreens.length}',
    );
    buffer.writeln();

    // Screens
    for (final outpost in outposts.values) {
      buffer.writeln(outpost.toAiSummary());
      buffer.writeln();
    }

    // Dead ends
    final dead = deadEnds;
    if (dead.isNotEmpty) {
      buffer.writeln(
        'DEAD ENDS: ${dead.map((o) => o.routePattern).join(", ")}',
      );
    }

    // Unreliable transitions
    final unreliable = unreliableMarches;
    if (unreliable.isNotEmpty) {
      buffer.writeln(
        'UNRELIABLE TRANSITIONS: '
        '${unreliable.map((m) => "${m.fromRoute} → ${m.toRoute}").join(", ")}',
      );
    }

    return buffer.toString().trimRight();
  }

  /// Mermaid flowchart of the app's flow graph.
  ///
  /// ```
  /// graph TD
  ///   login["/login<br>Login Screen"] -->|tap 'Enter'| home["/"]
  ///   home -->|tap quest| detail["/quest/:id"]
  /// ```
  String toMermaid() {
    final buffer = StringBuffer('graph TD\n');
    final nodeIds = <String, String>{};
    var nextId = 0;

    String nodeId(String route) {
      return nodeIds.putIfAbsent(route, () => 'n${nextId++}');
    }

    // Declare nodes
    for (final outpost in outposts.values) {
      final id = nodeId(outpost.routePattern);
      final label =
          '${outpost.routePattern}<br>${outpost.displayName}';
      if (outpost.requiresAuth) {
        buffer.writeln('  $id(["$label 🔒"])');
      } else {
        buffer.writeln('  $id["$label"]');
      }
    }

    // Declare edges
    for (final outpost in outposts.values) {
      final fromId = nodeId(outpost.routePattern);
      for (final exit in outpost.exits) {
        final toId = nodeId(exit.toRoute);
        final edgeLabel = exit.triggerElementLabel != null
            ? '${exit.trigger.name} "${exit.triggerElementLabel}"'
            : exit.trigger.name;
        buffer.writeln('  $fromId -->|$edgeLabel| $toId');
      }
    }

    return buffer.toString().trimRight();
  }

  // -----------------------------------------------------------------------
  // Serialization
  // -----------------------------------------------------------------------

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    r'$schema': 'titan://terrain/v1',
    'lastUpdated': lastUpdated.toIso8601String(),
    'sessionsAnalyzed': sessionsAnalyzed,
    'stratagemExecutionsAnalyzed': stratagemExecutionsAnalyzed,
    'outposts': outposts.map((k, v) => MapEntry(k, v.toJson())),
  };

  /// Deserialize from JSON map.
  factory Terrain.fromJson(Map<String, dynamic> json) {
    final outpostsJson = json['outposts'] as Map<String, dynamic>? ?? {};
    final outposts = outpostsJson.map(
      (k, v) => MapEntry(k, Outpost.fromJson(v as Map<String, dynamic>)),
    );

    return Terrain(
      outposts: outposts,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : null,
      sessionsAnalyzed: json['sessionsAnalyzed'] as int? ?? 0,
      stratagemExecutionsAnalyzed:
          json['stratagemExecutionsAnalyzed'] as int? ?? 0,
    );
  }

  /// Serialize to a pretty-printed JSON string.
  ///
  /// For a compact (non-indented) JSON string, use [toCompactJsonString].
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Serialize to a compact JSON string (no indentation).
  ///
  /// ~8x faster than [toJsonString] for large Terrains.
  String toCompactJsonString() => jsonEncode(toJson());

  /// Reset the entire Terrain.
  void reset() {
    outposts.clear();
    sessionsAnalyzed = 0;
    stratagemExecutionsAnalyzed = 0;
    lastUpdated = DateTime.now();
    invalidateCache();
  }

  @override
  String toString() =>
      'Terrain($screenCount screens, $transitionCount transitions, '
      '$sessionsAnalyzed sessions)';
}

/// Internal BFS node for shortest-path computation.
class _PathNode {
  final String route;
  final List<March> path;

  const _PathNode({required this.route, required this.path});
}
