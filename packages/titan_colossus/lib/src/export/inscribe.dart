import 'dart:convert';

import '../metrics/decree.dart';

// ---------------------------------------------------------------------------
// Inscribe — Performance Report Exporter
// ---------------------------------------------------------------------------

/// **Inscribe** — writes the [Decree] onto parchment in the format of
/// your choosing.
///
/// Inscribe converts a [Decree] performance report into exportable
/// formats: Markdown, JSON, or a self-contained HTML dashboard.
///
/// ## Why "Inscribe"?
///
/// The Titans inscribed their decrees onto stone and parchment for
/// posterity. Inscribe writes the Colossus's performance verdict
/// into a permanent, shareable format.
///
/// ## Quick Start
///
/// ```dart
/// final decree = Colossus.instance.decree();
///
/// // Export as Markdown
/// final md = Inscribe.markdown(decree);
///
/// // Export as JSON
/// final json = Inscribe.json(decree);
///
/// // Export as a self-contained HTML dashboard
/// final html = Inscribe.html(decree);
/// ```
///
/// ## Export Formats
///
/// | Format | Method | Best For |
/// |--------|--------|----------|
/// | Markdown | `Inscribe.markdown()` | README, tickets, team sharing |
/// | JSON | `Inscribe.json()` | CI pipelines, dashboards, data analysis |
/// | HTML | `Inscribe.html()` | Visual reports, stakeholder reviews |
class Inscribe {
  // Private constructor — static-only class.
  Inscribe._();

  // -----------------------------------------------------------------------
  // Markdown
  // -----------------------------------------------------------------------

  /// Export the [decree] as a Markdown report.
  ///
  /// Produces a clean, table-based Markdown document suitable for
  /// pasting into GitHub issues, PRs, or documentation.
  ///
  /// ```dart
  /// final md = Inscribe.markdown(Colossus.instance.decree());
  /// // Write to file, copy to clipboard, attach to CI artifact, etc.
  /// ```
  static String markdown(Decree decree) {
    final buf = StringBuffer();

    // Header
    buf
      ..writeln('# Colossus Performance Decree')
      ..writeln()
      ..writeln(
        '**Health: ${decree.health.name.toUpperCase()}** '
        '${_healthEmoji(decree.health)}',
      )
      ..writeln()
      ..writeln('| | |')
      ..writeln('|---|---|')
      ..writeln('| **Session start** | ${_fmtDt(decree.sessionStart)} |')
      ..writeln('| **Report generated** | ${_fmtDt(decree.generatedAt)} |')
      ..writeln(
        '| **Duration** | '
        '${decree.generatedAt.difference(decree.sessionStart).inSeconds}s |',
      )
      ..writeln();

    // Pulse
    buf
      ..writeln('## Pulse (Frame Metrics)')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|--------|-------|')
      ..writeln('| FPS | ${decree.avgFps.toStringAsFixed(1)} |')
      ..writeln('| Total frames | ${decree.totalFrames} |')
      ..writeln('| Jank frames | ${decree.jankFrames} |')
      ..writeln('| Jank rate | ${decree.jankRate.toStringAsFixed(1)}% |')
      ..writeln(
        '| Avg build time | '
        '${decree.avgBuildTime.inMicroseconds}\u00b5s |',
      )
      ..writeln(
        '| Avg raster time | '
        '${decree.avgRasterTime.inMicroseconds}\u00b5s |',
      )
      ..writeln();

    // Stride
    buf
      ..writeln('## Stride (Page Loads)')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|--------|-------|')
      ..writeln('| Total page loads | ${decree.pageLoads.length} |')
      ..writeln(
        '| Avg load time | '
        '${decree.avgPageLoad.inMilliseconds}ms |',
      );
    final slowest = decree.slowestPageLoad;
    if (slowest != null) {
      buf.writeln(
        '| Slowest | ${slowest.path} '
        '(${slowest.duration.inMilliseconds}ms) |',
      );
    }
    buf.writeln();

    if (decree.pageLoads.isNotEmpty) {
      buf
        ..writeln('### Page Load Details')
        ..writeln()
        ..writeln('| Path | Pattern | Duration |')
        ..writeln('|------|---------|----------|');
      for (final load in decree.pageLoads) {
        buf.writeln(
          '| ${load.path} | ${load.pattern ?? '-'} | '
          '${load.duration.inMilliseconds}ms |',
        );
      }
      buf.writeln();
    }

    // Vessel
    buf
      ..writeln('## Vessel (Memory)')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|--------|-------|')
      ..writeln('| Live Pillars | ${decree.pillarCount} |')
      ..writeln('| Total DI instances | ${decree.totalInstances} |')
      ..writeln('| Leak suspects | ${decree.leakSuspects.length} |')
      ..writeln();

    if (decree.leakSuspects.isNotEmpty) {
      buf
        ..writeln('### Leak Suspects')
        ..writeln()
        ..writeln('| Type | Age |')
        ..writeln('|------|-----|');
      for (final suspect in decree.leakSuspects) {
        buf.writeln('| ${suspect.typeName} | ${suspect.age.inSeconds}s |');
      }
      buf.writeln();
    }

    // Echo
    buf
      ..writeln('## Echo (Rebuilds)')
      ..writeln()
      ..writeln('| Metric | Value |')
      ..writeln('|--------|-------|')
      ..writeln('| Total rebuilds | ${decree.totalRebuilds} |')
      ..writeln();

    final top = decree.topRebuilders(10);
    if (top.isNotEmpty) {
      buf
        ..writeln('### Top Rebuilders')
        ..writeln()
        ..writeln('| Widget | Rebuilds |')
        ..writeln('|--------|----------|');
      for (final entry in top) {
        buf.writeln('| ${entry.key} | ${entry.value} |');
      }
      buf.writeln();
    }

    // Verdict
    buf
      ..writeln('---')
      ..writeln()
      ..writeln(
        '> **Verdict: ${decree.health.name.toUpperCase()}** '
        '${_healthEmoji(decree.health)}',
      )
      ..writeln()
      ..writeln(
        '*Generated by Colossus — '
        'Titan Performance Monitoring*',
      );

    return buf.toString();
  }

  // -----------------------------------------------------------------------
  // JSON
  // -----------------------------------------------------------------------

  /// Export the [decree] as a JSON string.
  ///
  /// Returns a compact JSON document using [Decree.toMap].
  /// Suitable for CI pipelines, dashboard ingestion, or data analysis.
  ///
  /// For pretty-printed output, use:
  /// ```dart
  /// const JsonEncoder.withIndent('  ').convert(decree.toMap());
  /// ```
  ///
  /// ```dart
  /// final json = Inscribe.json(Colossus.instance.decree());
  /// ```
  static String json(Decree decree) {
    return jsonEncode(decree.toMap());
  }

  // -----------------------------------------------------------------------
  // HTML
  // -----------------------------------------------------------------------

  /// Export the [decree] as a self-contained HTML dashboard.
  ///
  /// Produces a single HTML file with embedded CSS — no external
  /// dependencies. Opens in any browser for visual review.
  ///
  /// ```dart
  /// final html = Inscribe.html(Colossus.instance.decree());
  /// // Write to file and open in browser
  /// ```
  static String html(Decree decree) {
    final healthColor = switch (decree.health) {
      PerformanceHealth.good => '#22c55e',
      PerformanceHealth.fair => '#eab308',
      PerformanceHealth.poor => '#ef4444',
    };
    final healthLabel = decree.health.name.toUpperCase();
    final duration = decree.generatedAt.difference(decree.sessionStart);

    final buf = StringBuffer();

    buf.writeln('<!DOCTYPE html>');
    buf.writeln('<html lang="en">');
    buf.writeln('<head>');
    buf.writeln('<meta charset="UTF-8">');
    buf.writeln(
      '<meta name="viewport" '
      'content="width=device-width, initial-scale=1.0">',
    );
    buf.writeln('<title>Colossus Performance Decree</title>');
    buf.writeln('<style>');
    buf.writeln(_css);
    buf.writeln('</style>');
    buf.writeln('</head>');
    buf.writeln('<body>');

    // Header
    buf.writeln('<div class="header">');
    buf.writeln('<h1>Colossus Performance Decree</h1>');
    buf.writeln(
      '<div class="health-badge" style="background:$healthColor">'
      '$healthLabel</div>',
    );
    buf.writeln('<div class="session-info">');
    buf.writeln(
      '<span>${_fmtDt(decree.sessionStart)} &rarr; '
      '${_fmtDt(decree.generatedAt)}</span>',
    );
    buf.writeln('<span>Duration: ${duration.inSeconds}s</span>');
    buf.writeln('</div>');
    buf.writeln('</div>');

    // Grid
    buf.writeln('<div class="grid">');

    // Pulse card
    buf.writeln('<div class="card">');
    buf.writeln('<h2>Pulse</h2>');
    buf.writeln('<p class="subtitle">Frame Metrics</p>');
    buf.writeln(_metricRow('FPS', decree.avgFps.toStringAsFixed(1)));
    buf.writeln(_metricRow('Total Frames', '${decree.totalFrames}'));
    buf.writeln(
      _metricRow(
        'Jank',
        '${decree.jankFrames} '
            '(${decree.jankRate.toStringAsFixed(1)}%)',
      ),
    );
    buf.writeln(
      _metricRow('Avg Build', '${decree.avgBuildTime.inMicroseconds}\u00b5s'),
    );
    buf.writeln(
      _metricRow('Avg Raster', '${decree.avgRasterTime.inMicroseconds}\u00b5s'),
    );

    // Jank bar
    buf.writeln('<div class="bar-container">');
    buf.writeln('<div class="bar-label">Jank Rate</div>');
    final jankWidth = decree.jankRate.clamp(0, 100).toStringAsFixed(0);
    final jankColor = decree.jankRate > 10
        ? '#ef4444'
        : decree.jankRate > 5
        ? '#eab308'
        : '#22c55e';
    buf.writeln(
      '<div class="bar"><div class="bar-fill" '
      'style="width:$jankWidth%;background:$jankColor"></div></div>',
    );
    buf.writeln('</div>');
    buf.writeln('</div>');

    // Stride card
    buf.writeln('<div class="card">');
    buf.writeln('<h2>Stride</h2>');
    buf.writeln('<p class="subtitle">Page Loads</p>');
    buf.writeln(_metricRow('Total', '${decree.pageLoads.length}'));
    buf.writeln(
      _metricRow('Avg Load', '${decree.avgPageLoad.inMilliseconds}ms'),
    );
    final slowestLoad = decree.slowestPageLoad;
    if (slowestLoad != null) {
      buf.writeln(
        _metricRow(
          'Slowest',
          '${slowestLoad.path} '
              '(${slowestLoad.duration.inMilliseconds}ms)',
        ),
      );
    }
    if (decree.pageLoads.isNotEmpty) {
      buf.writeln('<table>');
      buf.writeln('<tr><th>Path</th><th>Duration</th></tr>');
      for (final load in decree.pageLoads) {
        final loadColor = load.duration.inMilliseconds > 500
            ? '#ef4444'
            : load.duration.inMilliseconds > 200
            ? '#eab308'
            : '#22c55e';
        buf.writeln(
          '<tr><td>${_esc(load.path)}</td>'
          '<td style="color:$loadColor">'
          '${load.duration.inMilliseconds}ms</td></tr>',
        );
      }
      buf.writeln('</table>');
    }
    buf.writeln('</div>');

    // Vessel card
    buf.writeln('<div class="card">');
    buf.writeln('<h2>Vessel</h2>');
    buf.writeln('<p class="subtitle">Memory</p>');
    buf.writeln(_metricRow('Live Pillars', '${decree.pillarCount}'));
    buf.writeln(_metricRow('DI Instances', '${decree.totalInstances}'));
    buf.writeln(_metricRow('Leak Suspects', '${decree.leakSuspects.length}'));
    if (decree.leakSuspects.isNotEmpty) {
      buf.writeln('<div class="alert">');
      for (final suspect in decree.leakSuspects) {
        buf.writeln(
          '<div class="alert-item">'
          '\u26a0 ${_esc(suspect.typeName)} '
          '(${suspect.age.inSeconds}s)</div>',
        );
      }
      buf.writeln('</div>');
    }
    buf.writeln('</div>');

    // Echo card
    buf.writeln('<div class="card">');
    buf.writeln('<h2>Echo</h2>');
    buf.writeln('<p class="subtitle">Rebuilds</p>');
    buf.writeln(_metricRow('Total Rebuilds', '${decree.totalRebuilds}'));
    final top = decree.topRebuilders(10);
    if (top.isNotEmpty) {
      buf.writeln('<table>');
      buf.writeln('<tr><th>Widget</th><th>Rebuilds</th></tr>');
      for (final entry in top) {
        buf.writeln(
          '<tr><td>${_esc(entry.key)}</td>'
          '<td>${entry.value}</td></tr>',
        );
      }
      buf.writeln('</table>');
    }
    buf.writeln('</div>');

    buf.writeln('</div>'); // grid

    // Footer
    buf.writeln('<div class="footer">');
    buf.writeln(
      'Generated by <strong>Colossus</strong> &mdash; '
      'Titan Performance Monitoring',
    );
    buf.writeln('</div>');

    buf.writeln('</body>');
    buf.writeln('</html>');

    return buf.toString();
  }

  // -----------------------------------------------------------------------
  // Helpers
  // -----------------------------------------------------------------------

  static String _fmtDt(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:'
      '${dt.second.toString().padLeft(2, '0')}';

  static String _healthEmoji(PerformanceHealth health) => switch (health) {
    PerformanceHealth.good => '\u2705',
    PerformanceHealth.fair => '\u26a0\ufe0f',
    PerformanceHealth.poor => '\u274c',
  };

  static String _metricRow(String label, String value) =>
      '<div class="metric"><span class="metric-label">'
      '$label</span><span class="metric-value">$value</span></div>';

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  // -----------------------------------------------------------------------
  // Embedded CSS
  // -----------------------------------------------------------------------

  static const _css = '''
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
background:#0f172a;color:#e2e8f0;padding:24px;max-width:1200px;margin:0 auto}
.header{text-align:center;margin-bottom:32px}
.header h1{font-size:28px;color:#f8fafc;margin-bottom:12px}
.health-badge{display:inline-block;padding:6px 20px;border-radius:20px;
font-weight:700;font-size:18px;color:#fff;margin-bottom:12px}
.session-info{color:#94a3b8;font-size:14px;display:flex;
justify-content:center;gap:24px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));
gap:20px}
.card{background:#1e293b;border-radius:12px;padding:20px;
border:1px solid #334155}
.card h2{font-size:20px;color:#f8fafc;margin-bottom:2px}
.card .subtitle{font-size:13px;color:#64748b;margin-bottom:16px}
.metric{display:flex;justify-content:space-between;padding:8px 0;
border-bottom:1px solid #334155}
.metric-label{color:#94a3b8;font-size:14px}
.metric-value{color:#f8fafc;font-weight:600;font-size:14px}
.bar-container{margin-top:12px}
.bar-label{font-size:12px;color:#64748b;margin-bottom:4px}
.bar{height:8px;background:#334155;border-radius:4px;overflow:hidden}
.bar-fill{height:100%;border-radius:4px;transition:width 0.3s}
table{width:100%;margin-top:12px;border-collapse:collapse}
th{text-align:left;font-size:12px;color:#64748b;padding:6px 8px;
border-bottom:1px solid #334155}
td{font-size:13px;padding:6px 8px;border-bottom:1px solid #1e293b}
.alert{margin-top:8px}
.alert-item{background:#7f1d1d;border-radius:6px;padding:6px 10px;
font-size:13px;margin-bottom:4px;color:#fca5a5}
.footer{text-align:center;margin-top:32px;padding-top:16px;
border-top:1px solid #334155;color:#64748b;font-size:13px}
''';
}
