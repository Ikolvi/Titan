import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  group('BlueprintExport', () {
    setUp(() {
      Scout.reset();
    });

    Terrain buildSampleTerrain() {
      final t = Terrain();
      // Add outposts manually via Scout
      final scout = Scout.withTerrain(t);
      scout.parameterizer.registerPattern('/quest/:id');

      // Create a minimal session with tableaux to feed the scout
      final session = ShadeSession(
        id: 'test-1',
        name: 'test-session',
        recordedAt: DateTime(2025),
        duration: const Duration(seconds: 10),
        screenWidth: 400,
        screenHeight: 800,
        devicePixelRatio: 2.0,
        imprints: const [],
        tableaux: [
          Tableau(
            index: 0,
            route: '/quests',
            timestamp: const Duration(seconds: 1),
            screenWidth: 400,
            screenHeight: 800,
            glyphs: const [],
          ),
          Tableau(
            index: 1,
            route: '/quest/42',
            timestamp: const Duration(seconds: 5),
            screenWidth: 400,
            screenHeight: 800,
            glyphs: const [],
          ),
        ],
      );

      scout.analyzeSession(session);
      return t;
    }

    test('fromScout creates export with terrain and stratagems', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final export = BlueprintExport.fromScout(scout: scout);

      expect(export.terrain, same(t));
      expect(export.terrain.screenCount, greaterThan(0));
      expect(export.exportedAt, isNotNull);
      expect(export.verdicts, isEmpty);
    });

    test('fromSessions creates export from raw sessions', () {
      final session = ShadeSession(
        id: 'test-2',
        name: 'raw-session',
        recordedAt: DateTime(2025),
        duration: const Duration(seconds: 5),
        screenWidth: 400,
        screenHeight: 800,
        devicePixelRatio: 2.0,
        imprints: const [],
        tableaux: [
          Tableau(
            index: 0,
            route: '/home',
            timestamp: const Duration(seconds: 1),
            screenWidth: 400,
            screenHeight: 800,
            glyphs: const [],
          ),
          Tableau(
            index: 1,
            route: '/settings',
            timestamp: const Duration(seconds: 3),
            screenWidth: 400,
            screenHeight: 800,
            glyphs: const [],
          ),
        ],
      );

      final export = BlueprintExport.fromSessions(
        sessions: [session],
        routePatterns: ['/quest/:id'],
        metadata: {'test': true},
      );

      expect(export.terrain.screenCount, greaterThan(0));
      expect(export.metadata['source'], 'offline');
      expect(export.metadata['sessionsAnalyzed'], 1);
      expect(export.metadata['test'], true);
      // routePatterns contains observed routes from sessions
      expect(export.routePatterns, contains('/home'));
      expect(export.routePatterns, contains('/settings'));
    });

    test('fromSessions with empty sessions creates empty export', () {
      final export = BlueprintExport.fromSessions(sessions: []);

      expect(export.terrain.screenCount, 0);
      expect(export.stratagems, isEmpty);
    });

    test('toJson produces valid JSON structure', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final export = BlueprintExport.fromScout(scout: scout);
      final json = export.toJson();

      expect(json['version'], BlueprintExport.schemaVersion);
      expect(json['exportedAt'], isA<String>());
      expect(json['terrain'], isA<Map<String, dynamic>>());
      expect(json['aiMap'], isA<String>());
      expect(json['mermaid'], isA<String>());
      expect(json['stratagems'], isA<List>());
      expect(json['lineage'], isA<Map<String, dynamic>>());
      expect(json['metadata'], isA<Map<String, dynamic>>());
    });

    test('toJson includes lineage data', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final export = BlueprintExport.fromScout(scout: scout);
      final json = export.toJson();
      final lineage = json['lineage'] as Map<String, dynamic>;

      expect(lineage['patterns'], isA<List>());
      expect(lineage['totalScreens'], isA<int>());
      expect(lineage['totalTransitions'], isA<int>());
      expect(lineage['sessionsAnalyzed'], isA<int>());
    });

    test('toJson includes verdicts when provided', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final verdict = Verdict.fromSteps(
        stratagemName: 'test-stratagem',
        executedAt: DateTime(2025),
        duration: const Duration(seconds: 1),
        steps: [
          VerdictStep.passed(
            stepId: 1,
            description: 'Navigate to /quests',
            duration: const Duration(milliseconds: 100),
          ),
        ],
        performance: const VerdictPerformance(averageFps: 60),
      );

      final export = BlueprintExport.fromScout(
        scout: scout,
        verdicts: [verdict],
      );
      final json = export.toJson();

      expect(json['verdicts'], isA<List>());
      expect((json['verdicts'] as List).length, 1);
      // Debrief should be generated
      expect(json.containsKey('debrief'), true);
    });

    test('toJson omits verdicts key when no verdicts', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final export = BlueprintExport.fromScout(scout: scout);
      final json = export.toJson();

      expect(json.containsKey('verdicts'), false);
    });

    test('toJsonString produces valid JSON', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final export = BlueprintExport.fromScout(scout: scout);
      final jsonString = export.toJsonString();

      expect(() => jsonDecode(jsonString), returnsNormally);

      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(parsed['version'], BlueprintExport.schemaVersion);
    });

    test('toCompactJsonString produces valid JSON without indentation', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final export = BlueprintExport.fromScout(scout: scout);
      final compact = export.toCompactJsonString();
      final pretty = export.toJsonString();

      // Both parse to the same data
      expect(() => jsonDecode(compact), returnsNormally);
      final compactParsed = jsonDecode(compact) as Map<String, dynamic>;
      final prettyParsed = jsonDecode(pretty) as Map<String, dynamic>;
      expect(compactParsed['version'], prettyParsed['version']);
      expect(
        compactParsed['terrain']['sessionsAnalyzed'],
        prettyParsed['terrain']['sessionsAnalyzed'],
      );

      // Compact is smaller
      expect(compact.length, lessThan(pretty.length));

      // Compact has no indentation
      expect(compact, isNot(contains('\n  ')));
    });

    test('toAiPrompt generates Markdown content', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final export = BlueprintExport.fromScout(scout: scout);
      final prompt = export.toAiPrompt();

      expect(prompt, contains('# App Blueprint'));
      expect(prompt, contains('## Navigation Map'));
      expect(prompt, contains('Screens:'));
      expect(prompt, contains('Transitions:'));
    });

    test('toAiPrompt includes dead ends when present', () {
      // Create a terrain with a dead end (outpost with no exits)
      final session = ShadeSession(
        id: 'dead-end',
        name: 'dead-end-session',
        recordedAt: DateTime(2025),
        duration: const Duration(seconds: 5),
        screenWidth: 400,
        screenHeight: 800,
        devicePixelRatio: 2.0,
        imprints: const [],
        tableaux: [
          Tableau(
            index: 0,
            route: '/home',
            timestamp: const Duration(seconds: 1),
            screenWidth: 400,
            screenHeight: 800,
            glyphs: const [],
          ),
        ],
      );

      final export = BlueprintExport.fromSessions(sessions: [session]);
      final prompt = export.toAiPrompt();

      // /home with only one tableau and no transitions is a dead end
      expect(prompt, contains('Dead End'));
    });

    test('toAiPrompt includes route patterns', () {
      // Create a session with routes so observed routes are populated
      final session = ShadeSession(
        id: 'pattern-test',
        name: 'pattern-session',
        recordedAt: DateTime(2025),
        duration: const Duration(seconds: 5),
        screenWidth: 400,
        screenHeight: 800,
        devicePixelRatio: 2.0,
        imprints: const [],
        tableaux: [
          Tableau(
            index: 0,
            route: '/quest/42',
            timestamp: const Duration(seconds: 1),
            screenWidth: 400,
            screenHeight: 800,
            glyphs: const [],
          ),
        ],
      );

      final export = BlueprintExport.fromSessions(
        sessions: [session],
        routePatterns: ['/quest/:id'],
      );
      final prompt = export.toAiPrompt();

      expect(prompt, contains('Known Route Patterns'));
      expect(prompt, contains('/quest'));
    });

    test('toAiPrompt includes failed verdicts', () {
      final t = buildSampleTerrain();
      final scout = Scout.withTerrain(t);

      final verdict = Verdict.fromSteps(
        stratagemName: 'failing-test',
        executedAt: DateTime(2025),
        duration: const Duration(seconds: 1),
        steps: [
          VerdictStep.failed(
            stepId: 1,
            description: 'Navigate to /broken',
            duration: const Duration(milliseconds: 100),
            failure: const VerdictFailure(
              message: 'Route not found',
              type: VerdictFailureType.expectationFailed,
            ),
          ),
        ],
        performance: const VerdictPerformance(averageFps: 60),
      );

      final export = BlueprintExport.fromScout(
        scout: scout,
        verdicts: [verdict],
      );
      final prompt = export.toAiPrompt();

      expect(prompt, contains('Previous Test Results'));
      expect(prompt, contains('FAILED: failing-test'));
      expect(prompt, contains('Route not found'));
    });

    test('schemaVersion is 1.0.0', () {
      expect(BlueprintExport.schemaVersion, '1.0.0');
    });
  });

  group('BlueprintExportIO', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('blueprint_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    BlueprintExport createExport() {
      return BlueprintExport(
        terrain: Terrain(),
        stratagems: const [],
        verdicts: const [],
        routePatterns: {'/quest/:id'},
        exportedAt: DateTime(2025),
      );
    }

    test('save writes JSON file', () async {
      final export = createExport();

      final path = await BlueprintExportIO.save(
        export,
        directory: tempDir.path,
      );

      expect(File(path).existsSync(), true);

      final content = File(path).readAsStringSync();
      final parsed = jsonDecode(content) as Map<String, dynamic>;
      expect(parsed['version'], '1.0.0');
    });

    test('save uses default filename', () async {
      final export = createExport();

      final path = await BlueprintExportIO.save(
        export,
        directory: tempDir.path,
      );

      expect(path, contains(BlueprintExportIO.defaultFilename));
    });

    test('save uses custom filename', () async {
      final export = createExport();

      final path = await BlueprintExportIO.save(
        export,
        directory: tempDir.path,
        filename: 'custom.json',
      );

      expect(path, contains('custom.json'));
    });

    test('savePrompt writes Markdown file', () async {
      final export = createExport();

      final path = await BlueprintExportIO.savePrompt(
        export,
        directory: tempDir.path,
      );

      expect(File(path).existsSync(), true);

      final content = File(path).readAsStringSync();
      expect(content, contains('# App Blueprint'));
    });

    test('saveAll writes both files', () async {
      final export = createExport();

      final result = await BlueprintExportIO.saveAll(
        export,
        directory: tempDir.path,
      );

      expect(File(result.json).existsSync(), true);
      expect(File(result.prompt).existsSync(), true);
      expect(result.all.length, 2);
    });

    test('save creates directory if missing', () async {
      final export = createExport();
      final nestedDir = '${tempDir.path}/nested/deep';

      final path = await BlueprintExportIO.save(export, directory: nestedDir);

      expect(File(path).existsSync(), true);
    });

    test('loadTerrain loads from saved file', () async {
      final export = createExport();
      final path = await BlueprintExportIO.save(
        export,
        directory: tempDir.path,
      );

      final loaded = await BlueprintExportIO.loadTerrain(path);

      expect(loaded, isNotNull);
      expect(loaded!.screenCount, 0);
    });

    test('loadTerrain returns null for missing file', () async {
      final loaded = await BlueprintExportIO.loadTerrain(
        '${tempDir.path}/nonexistent.json',
      );

      expect(loaded, isNull);
    });

    test('loadTerrain returns null for malformed file', () async {
      final file = File('${tempDir.path}/bad.json');
      file.writeAsStringSync('not valid json');

      final loaded = await BlueprintExportIO.loadTerrain(file.path);

      expect(loaded, isNull);
    });

    test('loadSessions loads session files', () async {
      // Create a minimal session JSON file
      final session = ShadeSession(
        id: 'load-test',
        name: 'loadable',
        recordedAt: DateTime(2025),
        duration: const Duration(seconds: 5),
        screenWidth: 400,
        screenHeight: 800,
        devicePixelRatio: 2.0,
        imprints: const [],
        tableaux: const [],
      );

      final sessionDir = '${tempDir.path}/sessions';
      Directory(sessionDir).createSync();
      File('$sessionDir/session1.json').writeAsStringSync(session.toJson());

      final loaded = await BlueprintExportIO.loadSessions(sessionDir);

      expect(loaded.length, 1);
      expect(loaded.first.id, 'load-test');
    });

    test('loadSessions returns empty for missing directory', () async {
      final loaded = await BlueprintExportIO.loadSessions(
        '${tempDir.path}/nonexistent',
      );

      expect(loaded, isEmpty);
    });

    test('loadSessions skips malformed files', () async {
      final sessionDir = '${tempDir.path}/sessions';
      Directory(sessionDir).createSync();
      File('$sessionDir/bad.json').writeAsStringSync('{"garbage": true}');
      File('$sessionDir/not-json.json').writeAsStringSync('hello world');

      final loaded = await BlueprintExportIO.loadSessions(sessionDir);

      expect(loaded, isEmpty);
    });

    test('loadSessions ignores non-json files', () async {
      final sessionDir = '${tempDir.path}/sessions';
      Directory(sessionDir).createSync();
      File('$sessionDir/readme.txt').writeAsStringSync('not a session');

      final loaded = await BlueprintExportIO.loadSessions(sessionDir);

      expect(loaded, isEmpty);
    });
  });

  group('BlueprintSaveResult', () {
    test('all returns both paths', () async {
      final export = BlueprintExport(
        terrain: Terrain(),
        stratagems: const [],
        verdicts: const [],
        routePatterns: const {},
        exportedAt: DateTime(2025),
      );

      final tempDir = Directory.systemTemp.createTempSync('bsr_test_');
      try {
        final result = await BlueprintExportIO.saveAll(
          export,
          directory: tempDir.path,
        );

        expect(result.all, hasLength(2));
        expect(result.all, contains(result.json));
        expect(result.all, contains(result.prompt));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('ColossusPlugin blueprintExportDirectory', () {
    test('default is null', () {
      const plugin = ColossusPlugin();
      expect(plugin.blueprintExportDirectory, isNull);
    });

    test('accepts custom directory', () {
      const plugin = ColossusPlugin(blueprintExportDirectory: '.titan');
      expect(plugin.blueprintExportDirectory, '.titan');
    });
  });
}
