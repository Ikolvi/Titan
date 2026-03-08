/// Exports the current Blueprint data (Terrain, Stratagems, AI prompt)
/// from saved Shade sessions to `.titan/blueprint.json`.
///
/// Usage:
///   dart run titan_colossus:export_blueprint [options]
///
/// Options:
///   --sessions-dir   Directory containing ShadeSession JSON files
///                    (defaults to `.titan/sessions`)
///   --output-dir     Output directory for blueprint files
///                    (defaults to `.titan`)
///   --patterns       Comma-separated route patterns to register
///                    (e.g. `/quest/:id,/hero/:heroId`)
///   --intensity      Gauntlet intensity: quick, standard, thorough
///                    (defaults to `standard`)
///   --prompt-only    Only generate the AI prompt Markdown, skip JSON
///   --help           Show this help message
library;

import 'dart:io';

import 'package:titan_colossus/titan_colossus.dart';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final sessionsDir = _getArg(args, '--sessions-dir') ?? '.titan/sessions';
  final outputDir = _getArg(args, '--output-dir') ?? '.titan';
  final patternsArg = _getArg(args, '--patterns');
  final intensityArg = _getArg(args, '--intensity') ?? 'standard';
  final promptOnly = args.contains('--prompt-only');

  final intensity = switch (intensityArg) {
    'quick' => GauntletIntensity.quick,
    'thorough' => GauntletIntensity.thorough,
    _ => GauntletIntensity.standard,
  };

  // Parse route patterns
  final patterns = <String>[];
  if (patternsArg != null) {
    patterns.addAll(patternsArg.split(',').map((p) => p.trim()));
  }

  stdout.writeln('🔭 Titan Blueprint Export');
  stdout.writeln('   Sessions: $sessionsDir');
  stdout.writeln('   Output:   $outputDir');
  if (patterns.isNotEmpty) {
    stdout.writeln('   Patterns: ${patterns.join(', ')}');
  }
  stdout.writeln('   Intensity: $intensityArg');
  stdout.writeln();

  // Load sessions
  stdout.write('Loading sessions... ');
  final sessions = await BlueprintExportIO.loadSessions(sessionsDir);
  stdout.writeln('${sessions.length} found');

  if (sessions.isEmpty) {
    stdout.writeln();
    stdout.writeln('No sessions found in $sessionsDir');
    stdout.writeln(
      'Record some Shade sessions first, or specify a different '
      'directory with --sessions-dir',
    );
    exit(1);
  }

  // Build export
  stdout.write('Analyzing sessions... ');
  final export = BlueprintExport.fromSessions(
    sessions: sessions,
    routePatterns: patterns,
    intensity: intensity,
    metadata: {'tool': 'export_blueprint', 'sessionsDir': sessionsDir},
  );
  stdout.writeln('done');

  stdout.writeln(
    '   Screens: ${export.terrain.screenCount} | '
    'Transitions: ${export.terrain.transitionCount} | '
    'Stratagems: ${export.stratagems.length}',
  );
  stdout.writeln();

  // Save
  if (promptOnly) {
    stdout.write('Saving AI prompt... ');
    final path = await BlueprintExportIO.savePrompt(
      export,
      directory: outputDir,
    );
    stdout.writeln('done');
    stdout.writeln('   $path');
  } else {
    stdout.write('Saving blueprint... ');
    final result = await BlueprintExportIO.saveAll(
      export,
      directory: outputDir,
    );
    stdout.writeln('done');
    stdout.writeln('   JSON:   ${result.json}');
    stdout.writeln('   Prompt: ${result.prompt}');
  }

  stdout.writeln();
  stdout.writeln('Blueprint export complete.');
  stdout.writeln(
    'AI assistants can now read the blueprint to understand your '
    "app's navigation and generate targeted tests.",
  );
}

String? _getArg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

void _printUsage() {
  stdout.writeln('Titan Blueprint Export');
  stdout.writeln();
  stdout.writeln(
    'Exports Blueprint data (Terrain, Stratagems, AI prompt) from '
    'saved Shade sessions.',
  );
  stdout.writeln();
  stdout.writeln('Usage:');
  stdout.writeln('  dart run titan_colossus:export_blueprint [options]');
  stdout.writeln();
  stdout.writeln('Options:');
  stdout.writeln(
    '  --sessions-dir <dir>   Directory with ShadeSession JSON files '
    '(default: .titan/sessions)',
  );
  stdout.writeln(
    '  --output-dir <dir>     Output directory '
    '(default: .titan)',
  );
  stdout.writeln(
    '  --patterns <list>      Comma-separated route patterns '
    '(e.g. /quest/:id,/hero/:heroId)',
  );
  stdout.writeln(
    '  --intensity <level>    Gauntlet intensity: quick, standard, '
    'thorough (default: standard)',
  );
  stdout.writeln(
    '  --prompt-only          Only generate the AI prompt Markdown',
  );
  stdout.writeln('  --help, -h             Show this help message');
}
