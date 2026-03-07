import 'dart:convert';
import 'dart:io';

import '../discovery/gauntlet.dart';
import '../discovery/route_parameterizer.dart';
import '../discovery/scout.dart';
import '../discovery/terrain.dart';
import '../recording/imprint.dart';
import '../testing/debrief.dart';
import '../testing/stratagem.dart';
import '../testing/verdict.dart';

// ---------------------------------------------------------------------------
// BlueprintExport — Structured Blueprint data for AI consumption
// ---------------------------------------------------------------------------

/// A structured export of the [Scout]'s discovered [Terrain], generated
/// [Stratagem]s from the [Gauntlet], and optional [Verdict]/[Debrief] results.
///
/// Designed as the bridge between Colossus's runtime AI Blueprint Generation
/// and external AI assistants (Copilot, Claude, etc.) that operate at IDE
/// time. Export this to a `.titan/blueprint.json` file in the project root
/// and AI assistants can read it to understand your app's navigation graph,
/// edge-case test plans, and recent test results.
///
/// ```dart
/// final export = BlueprintExport.fromScout(
///   scout: Scout.instance,
///   verdicts: recentVerdicts,
/// );
///
/// // Write to disk
/// await BlueprintExportIO.save(export, directory: '.titan');
///
/// // Or get the JSON string directly
/// final json = export.toJsonString();
/// ```
class BlueprintExport {
  /// Schema version for forward compatibility.
  static const String schemaVersion = '1.0.0';

  /// The Terrain graph data.
  final Terrain terrain;

  /// Auto-generated Stratagems from Gauntlet analysis.
  final List<Stratagem> stratagems;

  /// Verdicts from previous Campaign executions (if available).
  final List<Verdict> verdicts;

  /// Route patterns registered in the [RouteParameterizer].
  final Set<String> routePatterns;

  /// Timestamp when this export was created.
  final DateTime exportedAt;

  /// Optional metadata about the export environment.
  final Map<String, dynamic> metadata;

  /// Creates a [BlueprintExport] with the given data.
  const BlueprintExport({
    required this.terrain,
    required this.stratagems,
    required this.verdicts,
    required this.routePatterns,
    required this.exportedAt,
    this.metadata = const {},
  });

  /// Creates a [BlueprintExport] from the current [Scout] state.
  ///
  /// Reads the Scout's [Terrain], generates [Stratagem]s via [Gauntlet]
  /// for every discovered [Outpost], and includes any provided [Verdict]s.
  ///
  /// ```dart
  /// final export = BlueprintExport.fromScout(
  ///   scout: Scout.instance,
  ///   verdicts: campaignResult.verdicts,
  /// );
  /// ```
  factory BlueprintExport.fromScout({
    required Scout scout,
    List<Verdict> verdicts = const [],
    GauntletIntensity intensity = GauntletIntensity.standard,
    Map<String, dynamic> metadata = const {},
  }) {
    final terrain = scout.terrain;

    // Generate stratagems for every discovered outpost
    final stratagems = <Stratagem>[];
    for (final outpost in terrain.outposts.values) {
      stratagems.addAll(
        Gauntlet.generateFor(outpost, intensity: intensity),
      );
    }

    return BlueprintExport(
      terrain: terrain,
      stratagems: stratagems,
      verdicts: verdicts,
      routePatterns: Set<String>.of(scout.parameterizer.observedRoutes),
      exportedAt: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Creates a [BlueprintExport] from sessions loaded from disk.
  ///
  /// Useful for offline analysis: load saved [ShadeSession] JSON files,
  /// feed them to a fresh [Scout], then export the results.
  ///
  /// ```dart
  /// final sessions = await BlueprintExportIO.loadSessions('/path/to/sessions');
  /// final export = BlueprintExport.fromSessions(
  ///   sessions: sessions,
  ///   routePatterns: ['/quest/:id', '/hero/:heroId'],
  /// );
  /// ```
  factory BlueprintExport.fromSessions({
    required List<ShadeSession> sessions,
    List<String> routePatterns = const [],
    GauntletIntensity intensity = GauntletIntensity.standard,
    Map<String, dynamic> metadata = const {},
  }) {
    // Create a dedicated Scout for this analysis
    final terrain = Terrain();
    final scout = Scout.withTerrain(terrain);

    // Register route patterns
    for (final pattern in routePatterns) {
      scout.parameterizer.registerPattern(pattern);
    }

    // Feed all sessions
    for (final session in sessions) {
      scout.analyzeSession(session);
    }

    // Generate stratagems
    final stratagems = <Stratagem>[];
    for (final outpost in terrain.outposts.values) {
      stratagems.addAll(
        Gauntlet.generateFor(outpost, intensity: intensity),
      );
    }

    return BlueprintExport(
      terrain: terrain,
      stratagems: stratagems,
      verdicts: const [],
      routePatterns: Set<String>.of(scout.parameterizer.observedRoutes),
      exportedAt: DateTime.now(),
      metadata: {
        'sessionsAnalyzed': sessions.length,
        'source': 'offline',
        ...metadata,
      },
    );
  }

  /// Serializes this export to a JSON map.
  ///
  /// The output includes:
  /// - `version` — schema version for forward compatibility
  /// - `exportedAt` — ISO 8601 timestamp
  /// - `terrain` — full Terrain graph with Outposts and Marches
  /// - `aiMap` — human/AI-readable text summary of the Terrain
  /// - `mermaid` — Mermaid diagram of the Terrain graph
  /// - `stratagems` — generated test plans
  /// - `verdicts` — previous test results (if any)
  /// - `debrief` — aggregated analysis (if verdicts exist)
  /// - `lineage` — route pattern data
  /// - `metadata` — custom metadata
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'version': schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'terrain': terrain.toJson(),
      'aiMap': terrain.toAiMap(),
      'mermaid': terrain.toMermaid(),
      'stratagems': stratagems.map((s) => s.toJson()).toList(),
      'lineage': {
        'patterns': routePatterns.toList(),
        'totalScreens': terrain.screenCount,
        'totalTransitions': terrain.transitionCount,
        'sessionsAnalyzed': terrain.sessionsAnalyzed,
      },
      'metadata': metadata,
    };

    // Include verdicts and debrief if available
    if (verdicts.isNotEmpty) {
      map['verdicts'] = verdicts.map((v) => v.toJson()).toList();
      try {
        final debrief = Debrief(
          verdicts: verdicts,
          terrain: terrain,
        );
        map['debrief'] = debrief.analyze().toJson();
      } catch (_) {
        // Debrief analysis failed — skip silently
      }
    }

    return map;
  }

  /// Serializes this export to a pretty-printed JSON string.
  ///
  /// For a compact (non-indented) JSON string, use [toCompactJsonString].
  String toJsonString() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(toJson());
  }

  /// Serializes this export to a compact JSON string (no indentation).
  ///
  /// ~8x faster than [toJsonString] and produces a smaller file.
  /// Suitable for hot paths, CI pipelines, and machine-to-machine transfer.
  ///
  /// ```dart
  /// final compact = export.toCompactJsonString();
  /// // ~0.3ms vs ~2.7ms for toJsonString() on a 200KB export
  /// ```
  String toCompactJsonString() => jsonEncode(toJson());

  /// Generates a concise AI-readable summary suitable for pasting
  /// into an AI assistant's context window.
  ///
  /// This is a Markdown-formatted overview of:
  /// - Navigation structure (screens and transitions)
  /// - Dead ends and unreliable routes
  /// - Suggested test scenarios
  /// - Previous test results (if available)
  String toAiPrompt() {
    final buf = StringBuffer();

    buf.writeln('# App Blueprint — AI Test Generation Context');
    buf.writeln();
    buf.writeln('Generated: ${exportedAt.toIso8601String()}');
    buf.writeln(
      'Screens: ${terrain.screenCount} | '
      'Transitions: ${terrain.transitionCount} | '
      'Sessions Analyzed: ${terrain.sessionsAnalyzed}',
    );
    buf.writeln();

    // Navigation map
    buf.writeln('## Navigation Map');
    buf.writeln();
    buf.writeln(terrain.toAiMap());
    buf.writeln();

    // Dead ends
    final deadEnds = terrain.deadEnds;
    if (deadEnds.isNotEmpty) {
      buf.writeln('## Dead Ends (${deadEnds.length})');
      buf.writeln();
      for (final de in deadEnds) {
        buf.writeln(
          '- `${de.routePattern}` — ${de.observationCount} visits, '
          'no outgoing transitions',
        );
      }
      buf.writeln();
    }

    // Unreliable transitions
    final unreliable = terrain.unreliableMarches;
    if (unreliable.isNotEmpty) {
      buf.writeln('## Unreliable Transitions (${unreliable.length})');
      buf.writeln();
      for (final m in unreliable) {
        buf.writeln(
          '- `${m.fromRoute}` → `${m.toRoute}` — '
          '${m.observationCount} observations, '
          'trigger: ${m.trigger.name}',
        );
      }
      buf.writeln();
    }

    // Stratagems
    if (stratagems.isNotEmpty) {
      buf.writeln('## Suggested Test Scenarios (${stratagems.length})');
      buf.writeln();
      for (final s in stratagems) {
        buf.writeln('### ${s.name}');
        buf.writeln();
        buf.writeln(s.description);
        buf.writeln();
        buf.writeln('**Start route:** `${s.startRoute}`');
        buf.writeln('**Steps:** ${s.steps.length}');
        if (s.tags.isNotEmpty) {
          buf.writeln('**Tags:** ${s.tags.join(', ')}');
        }
        buf.writeln();
      }
    }

    // Verdicts
    if (verdicts.isNotEmpty) {
      final passed = verdicts.where((v) => v.passed).length;
      final failed = verdicts.length - passed;
      buf.writeln('## Previous Test Results');
      buf.writeln();
      buf.writeln('Passed: $passed | Failed: $failed');
      buf.writeln();
      for (final v in verdicts.where((v) => !v.passed)) {
        buf.writeln('### FAILED: ${v.stratagemName}');
        buf.writeln();
        for (final step in v.steps.where(
          (s) => s.status != VerdictStepStatus.passed,
        )) {
          buf.writeln(
            '- Step "${step.description}": '
            '${step.failure?.message ?? "unknown error"}',
          );
        }
        buf.writeln();
      }
    }

    // Route patterns
    if (routePatterns.isNotEmpty) {
      buf.writeln('## Known Route Patterns');
      buf.writeln();
      for (final p in routePatterns) {
        buf.writeln('- `$p`');
      }
      buf.writeln();
    }

    return buf.toString();
  }
}

// ---------------------------------------------------------------------------
// BlueprintExportIO — File I/O for BlueprintExport
// ---------------------------------------------------------------------------

/// File I/O utilities for [BlueprintExport].
///
/// Saves and loads Blueprint exports to/from the file system,
/// enabling offline analysis and AI assistant consumption.
///
/// ```dart
/// // Save current Blueprint to project root
/// final path = await BlueprintExportIO.save(
///   export,
///   directory: '.titan',
/// );
///
/// // Load a previously saved export
/// final loaded = await BlueprintExportIO.load('.titan/blueprint.json');
///
/// // Load Shade sessions from a directory
/// final sessions = await BlueprintExportIO.loadSessions(
///   '.titan/sessions',
/// );
/// ```
class BlueprintExportIO {
  BlueprintExportIO._();

  /// The default filename for Blueprint exports.
  static const String defaultFilename = 'blueprint.json';

  /// The default filename for the AI prompt export.
  static const String defaultPromptFilename = 'blueprint-prompt.md';

  /// Save a [BlueprintExport] to disk as JSON.
  ///
  /// Returns the absolute path of the saved file.
  ///
  /// If [directory] is omitted, saves to the system temp directory.
  /// If [filename] is omitted, uses [defaultFilename].
  /// If [compact] is `true`, uses [BlueprintExport.toCompactJsonString]
  /// for approximately 8x faster serialization and smaller file size.
  ///
  /// ```dart
  /// final path = await BlueprintExportIO.save(
  ///   export,
  ///   directory: '.titan',
  /// );
  /// print('Saved to $path');
  /// ```
  static Future<String> save(
    BlueprintExport export, {
    String? directory,
    String? filename,
    bool compact = false,
  }) async {
    final content =
        compact ? export.toCompactJsonString() : export.toJsonString();
    return _writeFile(
      content,
      directory: directory,
      filename: filename ?? defaultFilename,
    );
  }

  /// Save the AI prompt to disk as Markdown.
  ///
  /// Returns the absolute path of the saved file.
  ///
  /// ```dart
  /// final path = await BlueprintExportIO.savePrompt(
  ///   export,
  ///   directory: '.titan',
  /// );
  /// ```
  static Future<String> savePrompt(
    BlueprintExport export, {
    String? directory,
    String? filename,
  }) async {
    final content = export.toAiPrompt();
    return _writeFile(
      content,
      directory: directory,
      filename: filename ?? defaultPromptFilename,
    );
  }

  /// Save both JSON and AI prompt to disk.
  ///
  /// Returns a [BlueprintSaveResult] with paths to both files.
  ///
  /// ```dart
  /// final result = await BlueprintExportIO.saveAll(
  ///   export,
  ///   directory: '.titan',
  /// );
  /// print(result.json);   // .titan/blueprint.json
  /// print(result.prompt); // .titan/blueprint-prompt.md
  /// ```
  static Future<BlueprintSaveResult> saveAll(
    BlueprintExport export, {
    String? directory,
  }) async {
    final results = await Future.wait([
      save(export, directory: directory),
      savePrompt(export, directory: directory),
    ]);
    return BlueprintSaveResult._(json: results[0], prompt: results[1]);
  }

  /// Load a [BlueprintExport]'s Terrain from a JSON file.
  ///
  /// Returns the parsed Terrain, or `null` if the file doesn't exist
  /// or is malformed.
  ///
  /// ```dart
  /// final terrain = await BlueprintExportIO.loadTerrain(
  ///   '.titan/blueprint.json',
  /// );
  /// ```
  static Future<Terrain?> loadTerrain(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      if (map['terrain'] is! Map<String, dynamic>) return null;
      return Terrain.fromJson(map['terrain'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Load [ShadeSession]s from a directory of JSON files.
  ///
  /// Each `.json` file in the directory is parsed as a [ShadeSession].
  /// Files that fail to parse are silently skipped.
  ///
  /// ```dart
  /// final sessions = await BlueprintExportIO.loadSessions(
  ///   '.titan/sessions',
  /// );
  /// print('Loaded ${sessions.length} sessions');
  /// ```
  static Future<List<ShadeSession>> loadSessions(String directory) async {
    final dir = Directory(directory);
    if (!dir.existsSync()) return const [];

    final sessions = <ShadeSession>[];
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          sessions.add(ShadeSession.fromJson(content));
        } catch (_) {
          // Skip malformed session files
        }
      }
    }
    return sessions;
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  static Future<String> _writeFile(
    String content, {
    String? directory,
    required String filename,
  }) async {
    final dir = directory ?? Directory.systemTemp.path;
    final targetDir = Directory(dir);
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }
    final file = File('$dir/$filename');
    await file.writeAsString(content);
    return file.absolute.path;
  }
}

// ---------------------------------------------------------------------------
// BlueprintSaveResult
// ---------------------------------------------------------------------------

/// Result of [BlueprintExportIO.saveAll] containing paths to all saved files.
class BlueprintSaveResult {
  /// Path to the saved JSON file.
  final String json;

  /// Path to the saved AI prompt Markdown file.
  final String prompt;

  const BlueprintSaveResult._({required this.json, required this.prompt});

  /// All saved file paths as a list.
  List<String> get all => [json, prompt];
}
