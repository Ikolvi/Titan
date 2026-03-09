import 'package:flutter/material.dart';

import 'lens.dart';
import '../colossus.dart';

/// Lens plugin tab that visualizes HTTP traffic from the Envoy bridge.
///
/// Three sub-tabs:
/// - **Traffic**: Live request feed showing method, URL, status, duration
/// - **Stats**: Aggregate metrics — success rate, avg/p95 latency,
///   cache hit rate, status code distribution
/// - **Errors**: Filtered view of failed requests with error messages
///
/// Registered automatically when `enableLensTab: true` on `ColossusPlugin`.
///
/// ```dart
/// // Manual usage:
/// final tab = EnvoyLensTab(colossus);
/// Lens.registerPlugin(tab);
/// ```
class EnvoyLensTab extends LensPlugin {
  /// Creates an Envoy Lens tab backed by [colossus] API metrics.
  EnvoyLensTab(this.colossus);

  /// The Colossus instance supplying API metric data.
  final Colossus colossus;

  @override
  String get title => 'Envoy';

  @override
  IconData get icon => Icons.http;

  @override
  Widget build(BuildContext context) {
    return _EnvoyLensContent(colossus: colossus);
  }
}

/// Root content widget with three sub-tabs.
class _EnvoyLensContent extends StatelessWidget {
  const _EnvoyLensContent({required this.colossus});

  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    return Localizations(
      locale: const Locale('en', 'US'),
      delegates: const [
        DefaultWidgetsLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
      ],
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const _SubTabBar(tabs: ['Traffic', 'Stats', 'Errors']),
            Expanded(
              child: TabBarView(
                children: [
                  _TrafficView(colossus: colossus),
                  _StatsView(colossus: colossus),
                  _ErrorsView(colossus: colossus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-tab bar
// ---------------------------------------------------------------------------

class _SubTabBar extends StatelessWidget {
  const _SubTabBar({required this.tabs});

  final List<String> tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1E2E),
      child: TabBar(
        isScrollable: true,
        labelColor: Colors.tealAccent,
        unselectedLabelColor: Colors.white38,
        indicatorColor: Colors.tealAccent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        tabs: tabs.map((t) => Tab(text: t)).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Traffic tab — live request feed
// ---------------------------------------------------------------------------

class _TrafficView extends StatelessWidget {
  const _TrafficView({required this.colossus});

  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    final metrics = colossus.apiMetrics;

    if (metrics.isEmpty) {
      return const Center(
        child: Text(
          'No HTTP traffic recorded.\n'
          'Connect ColossusEnvoy to start tracking.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    // Show newest first
    final reversed = metrics.reversed.toList();

    return ListView.builder(
      key: const PageStorageKey('envoy_traffic'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: reversed.length,
      itemBuilder: (_, i) => _RequestCard(metric: reversed[i]),
    );
  }
}

/// Card for a single HTTP request.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.metric});

  final Map<String, dynamic> metric;

  @override
  Widget build(BuildContext context) {
    final method = (metric['method'] as String?) ?? '?';
    final url = (metric['url'] as String?) ?? '';
    final statusCode = metric['statusCode'] as int?;
    final durationMs = metric['durationMs'] as int?;
    final success = (metric['success'] as bool?) ?? true;
    final cached = (metric['cached'] as bool?) ?? false;
    final timestamp = metric['timestamp'] as String?;
    final responseSize = metric['responseSize'] as int?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF262636),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: success ? Colors.white10 : Colors.redAccent.withAlpha(80),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MethodBadge(method: method),
              const SizedBox(width: 6),
              if (statusCode != null) ...[
                _StatusBadge(statusCode: statusCode),
                const SizedBox(width: 6),
              ],
              if (cached) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withAlpha(40),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'CACHED',
                    style: TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              if (durationMs != null)
                Text(
                  '${durationMs}ms',
                  style: TextStyle(
                    color: _durationColor(durationMs),
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _truncateUrl(url),
            style: const TextStyle(color: Colors.white70, fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (responseSize != null)
                Text(
                  _formatBytes(responseSize),
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
                ),
              const Spacer(),
              if (timestamp != null)
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(color: Colors.white24, fontSize: 9),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _durationColor(int ms) {
    if (ms < 200) return Colors.tealAccent;
    if (ms < 500) return Colors.amberAccent;
    if (ms < 1000) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  static String _truncateUrl(String url) {
    // Remove scheme + host for display if long
    final uri = Uri.tryParse(url);
    if (uri != null && url.length > 60) {
      final path = uri.path;
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '$path$query';
    }
    return url;
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / 1048576).toStringAsFixed(1)}MB';
  }

  static String _formatTimestamp(String timestamp) {
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return timestamp;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

/// HTTP method badge with color coding.
class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.method});

  final String method;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: _methodColor(method).withAlpha(40),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        method.toUpperCase(),
        style: TextStyle(
          color: _methodColor(method),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  static Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return Colors.tealAccent;
      case 'POST':
        return Colors.lightBlueAccent;
      case 'PUT':
        return Colors.amberAccent;
      case 'PATCH':
        return Colors.orangeAccent;
      case 'DELETE':
        return Colors.redAccent;
      case 'HEAD':
        return Colors.purpleAccent;
      case 'OPTIONS':
        return Colors.grey;
      default:
        return Colors.white54;
    }
  }
}

/// Status code badge (green for 2xx, blue for 3xx, amber for 4xx, red for 5xx).
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.statusCode});

  final int statusCode;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$statusCode',
      style: TextStyle(
        color: _statusColor(statusCode),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        fontFamily: 'monospace',
      ),
    );
  }

  static Color _statusColor(int code) {
    if (code < 300) return Colors.tealAccent;
    if (code < 400) return Colors.lightBlueAccent;
    if (code < 500) return Colors.amberAccent;
    return Colors.redAccent;
  }
}

// ---------------------------------------------------------------------------
// Stats tab — aggregate metrics
// ---------------------------------------------------------------------------

class _StatsView extends StatelessWidget {
  const _StatsView({required this.colossus});

  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    final metrics = colossus.apiMetrics;

    if (metrics.isEmpty) {
      return const Center(
        child: Text(
          'No metrics available yet.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    final total = metrics.length;
    final successes = metrics.where((m) => m['success'] == true).length;
    final failures = total - successes;
    final cachedCount = metrics.where((m) => m['cached'] == true).length;

    // Duration stats
    final durations =
        metrics
            .where((m) => m['durationMs'] != null)
            .map((m) => m['durationMs'] as int)
            .toList()
          ..sort();
    final avgDuration = durations.isEmpty
        ? 0
        : durations.reduce((a, b) => a + b) ~/ durations.length;
    final p95Duration = durations.isEmpty
        ? 0
        : durations[(durations.length * 0.95).floor().clamp(
            0,
            durations.length - 1,
          )];
    final maxDuration = durations.isEmpty ? 0 : durations.last;

    // Response size stats
    final sizes = metrics
        .where((m) => m['responseSize'] != null)
        .map((m) => m['responseSize'] as int)
        .toList();
    final totalBytes = sizes.isEmpty ? 0 : sizes.reduce((a, b) => a + b);

    // Status code distribution
    final statusGroups = <String, int>{};
    for (final m in metrics) {
      final code = m['statusCode'] as int?;
      if (code != null) {
        final group = '${code ~/ 100}xx';
        statusGroups[group] = (statusGroups[group] ?? 0) + 1;
      }
    }

    // Method distribution
    final methodGroups = <String, int>{};
    for (final m in metrics) {
      final method = (m['method'] as String?) ?? '?';
      methodGroups[method] = (methodGroups[method] ?? 0) + 1;
    }

    // Top 5 slowest endpoints
    final sortedByDuration =
        metrics.where((m) => m['durationMs'] != null).toList()..sort(
          (a, b) => (b['durationMs'] as int).compareTo(a['durationMs'] as int),
        );
    final slowest = sortedByDuration.take(5).toList();

    return ListView(
      key: const PageStorageKey('envoy_stats'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        // Overview
        const _SectionHeader(label: 'OVERVIEW'),
        _MetricRow(
          label: 'Total requests',
          value: '$total',
          valueColor: Colors.white70,
        ),
        _MetricRow(
          label: 'Success',
          value:
              '$successes (${(successes / total * 100).toStringAsFixed(1)}%)',
          valueColor: Colors.tealAccent,
        ),
        _MetricRow(
          label: 'Failures',
          value: '$failures (${(failures / total * 100).toStringAsFixed(1)}%)',
          valueColor: failures > 0 ? Colors.redAccent : Colors.white38,
        ),
        _MetricRow(
          label: 'Cache hits',
          value:
              '$cachedCount (${(cachedCount / total * 100).toStringAsFixed(1)}%)',
          valueColor: cachedCount > 0 ? Colors.blueAccent : Colors.white38,
        ),

        const SizedBox(height: 12),
        const _SectionHeader(label: 'LATENCY'),
        _MetricRow(
          label: 'Average',
          value: '${avgDuration}ms',
          valueColor: _RequestCard._durationColor(avgDuration),
        ),
        _MetricRow(
          label: 'P95',
          value: '${p95Duration}ms',
          valueColor: _RequestCard._durationColor(p95Duration),
        ),
        _MetricRow(
          label: 'Max',
          value: '${maxDuration}ms',
          valueColor: _RequestCard._durationColor(maxDuration),
        ),

        const SizedBox(height: 12),
        const _SectionHeader(label: 'TRANSFER'),
        _MetricRow(
          label: 'Total response data',
          value: _RequestCard._formatBytes(totalBytes),
          valueColor: Colors.white70,
        ),

        // Status distribution
        if (statusGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionHeader(label: 'STATUS CODES'),
          ...statusGroups.entries.map(
            (e) => _MetricRow(
              label: e.key,
              value: '${e.value}',
              valueColor: _statusGroupColor(e.key),
            ),
          ),
        ],

        // Method distribution
        if (methodGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionHeader(label: 'METHODS'),
          ...methodGroups.entries.map(
            (e) => _MetricRow(
              label: e.key,
              value: '${e.value}',
              valueColor: _MethodBadge._methodColor(e.key),
            ),
          ),
        ],

        // Slowest endpoints
        if (slowest.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionHeader(label: 'SLOWEST REQUESTS'),
          ...slowest.map(
            (m) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      '${m['durationMs']}ms',
                      style: TextStyle(
                        color: _RequestCard._durationColor(
                          m['durationMs'] as int,
                        ),
                        fontSize: 10,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _MethodBadge(method: (m['method'] as String?) ?? '?'),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _RequestCard._truncateUrl((m['url'] as String?) ?? ''),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Color _statusGroupColor(String group) {
    switch (group) {
      case '2xx':
        return Colors.tealAccent;
      case '3xx':
        return Colors.lightBlueAccent;
      case '4xx':
        return Colors.amberAccent;
      case '5xx':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }
}

// ---------------------------------------------------------------------------
// Errors tab — failed requests
// ---------------------------------------------------------------------------

class _ErrorsView extends StatelessWidget {
  const _ErrorsView({required this.colossus});

  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    final errors = colossus.apiMetrics
        .where((m) => m['success'] != true)
        .toList()
        .reversed
        .toList();

    if (errors.isEmpty) {
      return const Center(
        child: Text(
          'No errors recorded.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('envoy_errors'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: errors.length,
      itemBuilder: (_, i) {
        final m = errors[i];
        final method = (m['method'] as String?) ?? '?';
        final url = (m['url'] as String?) ?? '';
        final statusCode = m['statusCode'] as int?;
        final error = (m['error'] as String?) ?? 'Unknown error';
        final durationMs = m['durationMs'] as int?;
        final timestamp = m['timestamp'] as String?;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF262636),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.redAccent.withAlpha(80)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _MethodBadge(method: method),
                  const SizedBox(width: 6),
                  if (statusCode != null) ...[
                    _StatusBadge(statusCode: statusCode),
                    const SizedBox(width: 6),
                  ],
                  const Spacer(),
                  if (durationMs != null)
                    Text(
                      '${durationMs}ms',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _RequestCard._truncateUrl(url),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  error,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (timestamp != null) ...[
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    _RequestCard._formatTimestamp(timestamp),
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white70,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 11,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
