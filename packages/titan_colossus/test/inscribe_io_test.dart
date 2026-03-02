import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  late Decree decree;
  late Directory tempDir;

  setUp(() {
    decree = Decree(
      sessionStart: DateTime(2025, 1, 15, 10, 0, 0),
      generatedAt: DateTime(2025, 1, 15, 10, 5, 30),
      totalFrames: 1000,
      jankFrames: 30,
      avgFps: 59.2,
      avgBuildTime: const Duration(microseconds: 3500),
      avgRasterTime: const Duration(microseconds: 2800),
      pageLoads: [
        PageLoadMark(
          path: '/home',
          duration: const Duration(milliseconds: 150),
        ),
      ],
      pillarCount: 8,
      totalInstances: 15,
      leakSuspects: [],
      rebuildsPerWidget: {'TestWidget': 10},
    );
    tempDir = Directory.systemTemp.createTempSync('inscribe_io_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('InscribeIO.saveMarkdown', () {
    test('saves markdown file to specified directory', () async {
      final path = await InscribeIO.saveMarkdown(
        decree,
        directory: tempDir.path,
      );

      expect(File(path).existsSync(), isTrue);
      expect(path, endsWith('.md'));
      final content = File(path).readAsStringSync();
      expect(content, contains('# Colossus Performance Decree'));
      expect(content, contains('GOOD'));
    });

    test('accepts custom filename', () async {
      final path = await InscribeIO.saveMarkdown(
        decree,
        directory: tempDir.path,
        filename: 'my-report.md',
      );

      expect(path, contains('my-report.md'));
      expect(File(path).existsSync(), isTrue);
    });

    test('saves to system temp when no directory given', () async {
      final path = await InscribeIO.saveMarkdown(decree);

      expect(File(path).existsSync(), isTrue);
      // Clean up
      File(path).deleteSync();
    });
  });

  group('InscribeIO.saveJson', () {
    test('saves valid JSON file', () async {
      final path = await InscribeIO.saveJson(decree, directory: tempDir.path);

      expect(File(path).existsSync(), isTrue);
      expect(path, endsWith('.json'));
      final content = File(path).readAsStringSync();
      expect(content, contains('"health"'));
      expect(content, contains('"pulse"'));
    });

    test('accepts custom filename', () async {
      final path = await InscribeIO.saveJson(
        decree,
        directory: tempDir.path,
        filename: 'perf.json',
      );

      expect(path, contains('perf.json'));
    });
  });

  group('InscribeIO.saveHtml', () {
    test('saves self-contained HTML file', () async {
      final path = await InscribeIO.saveHtml(decree, directory: tempDir.path);

      expect(File(path).existsSync(), isTrue);
      expect(path, endsWith('.html'));
      final content = File(path).readAsStringSync();
      expect(content, contains('<!DOCTYPE html>'));
      expect(content, contains('<style>'));
    });

    test('accepts custom filename', () async {
      final path = await InscribeIO.saveHtml(
        decree,
        directory: tempDir.path,
        filename: 'dashboard.html',
      );

      expect(path, contains('dashboard.html'));
    });
  });

  group('InscribeIO.saveAll', () {
    test('saves all three formats', () async {
      final result = await InscribeIO.saveAll(decree, directory: tempDir.path);

      expect(File(result.markdown).existsSync(), isTrue);
      expect(File(result.json).existsSync(), isTrue);
      expect(File(result.html).existsSync(), isTrue);

      expect(result.markdown, endsWith('.md'));
      expect(result.json, endsWith('.json'));
      expect(result.html, endsWith('.html'));
    });

    test('all files share the same timestamp stem', () async {
      final result = await InscribeIO.saveAll(decree, directory: tempDir.path);

      // Extract stem without extension from each path
      final mdStem = _stem(result.markdown);
      final jsonStem = _stem(result.json);
      final htmlStem = _stem(result.html);

      expect(mdStem, equals(jsonStem));
      expect(jsonStem, equals(htmlStem));
    });

    test('all property returns all paths', () async {
      final result = await InscribeIO.saveAll(decree, directory: tempDir.path);

      expect(result.all, hasLength(3));
      expect(result.all, contains(result.markdown));
      expect(result.all, contains(result.json));
      expect(result.all, contains(result.html));
    });

    test('toString shows all paths', () async {
      final result = await InscribeIO.saveAll(decree, directory: tempDir.path);

      final str = result.toString();
      expect(str, contains('SaveResult'));
      expect(str, contains('md='));
      expect(str, contains('json='));
      expect(str, contains('html='));
    });
  });

  group('Edge cases', () {
    test('creates directory if it does not exist', () async {
      final nested = '${tempDir.path}/sub/dir';
      expect(Directory(nested).existsSync(), isFalse);

      final path = await InscribeIO.saveMarkdown(decree, directory: nested);

      expect(File(path).existsSync(), isTrue);
    });

    test('auto-generated filename starts with colossus-decree', () async {
      final path = await InscribeIO.saveMarkdown(
        decree,
        directory: tempDir.path,
      );

      final filename = path.split('/').last;
      expect(filename, startsWith('colossus-decree-'));
    });
  });
}

/// Extract the filename stem (without extension) from a path.
String _stem(String path) {
  final filename = path.split('/').last;
  return filename.substring(0, filename.lastIndexOf('.'));
}
