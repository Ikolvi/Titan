import 'dart:io';

import '../metrics/decree.dart';
import 'inscribe.dart';

// ---------------------------------------------------------------------------
// InscribeIO — File-based report export
// ---------------------------------------------------------------------------

/// **InscribeIO** — persists the [Decree] to disk.
///
/// Extends the [Inscribe] formatter with file I/O capabilities,
/// writing performance reports to the file system as Markdown, JSON,
/// or self-contained HTML files.
///
/// > **Note**: Uses `dart:io` — available on mobile, desktop, and
/// > server platforms. Not available on web.
///
/// ## Quick Start
///
/// ```dart
/// final decree = Colossus.instance.decree();
///
/// // Save to specific directory
/// final path = await InscribeIO.saveHtml(decree, directory: '/tmp');
/// print('Report saved to $path');
///
/// // Save to system temp directory (default)
/// final path2 = await InscribeIO.saveMarkdown(decree);
///
/// // Save all three formats at once
/// final paths = await InscribeIO.saveAll(decree, directory: '/reports');
/// ```
class InscribeIO {
  // Private constructor — static-only class.
  InscribeIO._();

  // -----------------------------------------------------------------------
  // Save methods
  // -----------------------------------------------------------------------

  /// Save the [decree] as a Markdown file.
  ///
  /// Returns the absolute path of the saved file.
  ///
  /// If [directory] is omitted, saves to the system temp directory.
  /// The filename is auto-generated with a timestamp unless [filename]
  /// is provided.
  ///
  /// ```dart
  /// final path = await InscribeIO.saveMarkdown(decree);
  /// print('Saved to $path');
  /// ```
  static Future<String> saveMarkdown(
    Decree decree, {
    String? directory,
    String? filename,
  }) async {
    final content = Inscribe.markdown(decree);
    final name = filename ?? _autoFilename('md');
    return _save(content, directory: directory, filename: name);
  }

  /// Save the [decree] as a JSON file.
  ///
  /// Returns the absolute path of the saved file.
  ///
  /// If [directory] is omitted, saves to the system temp directory.
  /// The filename is auto-generated with a timestamp unless [filename]
  /// is provided.
  ///
  /// ```dart
  /// final path = await InscribeIO.saveJson(decree);
  /// ```
  static Future<String> saveJson(
    Decree decree, {
    String? directory,
    String? filename,
  }) async {
    final content = Inscribe.json(decree);
    final name = filename ?? _autoFilename('json');
    return _save(content, directory: directory, filename: name);
  }

  /// Save the [decree] as a self-contained HTML file.
  ///
  /// Returns the absolute path of the saved file. The HTML file
  /// can be opened directly in any browser — no external dependencies.
  ///
  /// If [directory] is omitted, saves to the system temp directory.
  /// The filename is auto-generated with a timestamp unless [filename]
  /// is provided.
  ///
  /// ```dart
  /// final path = await InscribeIO.saveHtml(decree);
  /// // Open in browser, share with stakeholders, attach to CI
  /// ```
  static Future<String> saveHtml(
    Decree decree, {
    String? directory,
    String? filename,
  }) async {
    final content = Inscribe.html(decree);
    final name = filename ?? _autoFilename('html');
    return _save(content, directory: directory, filename: name);
  }

  /// Save the [decree] in all three formats (Markdown, JSON, HTML).
  ///
  /// Returns a [SaveResult] with the paths of all three files.
  ///
  /// ```dart
  /// final result = await InscribeIO.saveAll(decree, directory: '/tmp');
  /// print(result.markdown); // /tmp/colossus-decree-2025...md
  /// print(result.json);     // /tmp/colossus-decree-2025...json
  /// print(result.html);     // /tmp/colossus-decree-2025...html
  /// ```
  static Future<SaveResult> saveAll(Decree decree, {String? directory}) async {
    final timestamp = _timestamp();
    final results = await Future.wait([
      saveMarkdown(
        decree,
        directory: directory,
        filename: 'colossus-decree-$timestamp.md',
      ),
      saveJson(
        decree,
        directory: directory,
        filename: 'colossus-decree-$timestamp.json',
      ),
      saveHtml(
        decree,
        directory: directory,
        filename: 'colossus-decree-$timestamp.html',
      ),
    ]);
    return SaveResult._(
      markdown: results[0],
      json: results[1],
      html: results[2],
    );
  }

  // -----------------------------------------------------------------------
  // Internal
  // -----------------------------------------------------------------------

  static Future<String> _save(
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

  static String _autoFilename(String ext) =>
      'colossus-decree-${_timestamp()}.$ext';

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '-'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// SaveResult — Result from saveAll
// ---------------------------------------------------------------------------

/// Result of [InscribeIO.saveAll] containing paths to all exported files.
class SaveResult {
  /// Path to the saved Markdown file.
  final String markdown;

  /// Path to the saved JSON file.
  final String json;

  /// Path to the saved HTML file.
  final String html;

  const SaveResult._({
    required this.markdown,
    required this.json,
    required this.html,
  });

  /// All saved file paths as a list.
  List<String> get all => [markdown, json, html];

  @override
  String toString() => 'SaveResult(md=$markdown, json=$json, html=$html)';
}
