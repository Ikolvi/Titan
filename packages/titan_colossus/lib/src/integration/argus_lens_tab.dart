import 'package:flutter/material.dart';

import 'colossus_argus.dart';
import 'lens.dart';
import '../colossus.dart';

/// Lens plugin tab that visualizes authentication state and events
/// from the [ColossusArgus] bridge.
///
/// Three sub-tabs:
/// - **State**: Current auth status, session timer, connection info
/// - **History**: Chronological login/logout event feed
/// - **Stats**: Aggregate auth metrics — login/logout counts,
///   average session duration, guard redirects
///
/// Registered automatically when `enableLensTab: true` on `ColossusPlugin`.
///
/// ```dart
/// // Manual usage:
/// final tab = ArgusLensTab(colossus);
/// Lens.registerPlugin(tab);
/// ```
class ArgusLensTab extends LensPlugin {
  /// Creates an Argus Lens tab backed by [colossus] integration events.
  ArgusLensTab(this.colossus);

  /// The Colossus instance supplying auth event data.
  final Colossus colossus;

  @override
  String get title => 'Auth';

  @override
  IconData get icon => Icons.shield;

  @override
  Widget build(BuildContext context) {
    return _ArgusLensContent(colossus: colossus);
  }
}

/// Root content widget with three sub-tabs.
class _ArgusLensContent extends StatelessWidget {
  const _ArgusLensContent({required this.colossus});

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
            const _SubTabBar(tabs: ['State', 'History', 'Stats']),
            Expanded(
              child: TabBarView(
                children: [
                  _StateView(colossus: colossus),
                  _HistoryView(colossus: colossus),
                  _StatsView(colossus: colossus),
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
// State tab — current auth status
// ---------------------------------------------------------------------------

class _StateView extends StatelessWidget {
  const _StateView({required this.colossus});

  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    if (!ColossusArgus.isConnected) {
      return const Center(
        child: Text(
          'Argus bridge not connected.\n'
          'Enable autoArgusMetrics in ColossusPlugin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    // Determine current state from counters
    final isLoggedIn = ColossusArgus.loginCount > ColossusArgus.logoutCount;
    final sessionStart = ColossusArgus.currentSessionStart;

    return ListView(
      key: const PageStorageKey('argus_state'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        // Auth status indicator
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isLoggedIn
                  ? Colors.tealAccent.withAlpha(20)
                  : Colors.redAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isLoggedIn
                    ? Colors.tealAccent.withAlpha(80)
                    : Colors.redAccent.withAlpha(80),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLoggedIn ? Icons.lock_open : Icons.lock,
                  color: isLoggedIn ? Colors.tealAccent : Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isLoggedIn ? 'Authenticated' : 'Unauthenticated',
                  style: TextStyle(
                    color: isLoggedIn ? Colors.tealAccent : Colors.redAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const _SectionHeader(label: 'SESSION'),
        if (isLoggedIn && sessionStart != null)
          _MetricRow(
            label: 'Session started',
            value: _formatDateTime(sessionStart),
            valueColor: Colors.white70,
          ),
        if (isLoggedIn && sessionStart != null)
          _MetricRow(
            label: 'Duration',
            value: _formatDuration(DateTime.now().difference(sessionStart)),
            valueColor: Colors.tealAccent,
          ),
        if (!isLoggedIn)
          const _MetricRow(
            label: 'Status',
            value: 'No active session',
            valueColor: Colors.white38,
          ),

        const SizedBox(height: 12),
        const _SectionHeader(label: 'RECENT'),
        if (ColossusArgus.lastLoginTime != null)
          _MetricRow(
            label: 'Last login',
            value: _formatDateTime(ColossusArgus.lastLoginTime!),
            valueColor: Colors.tealAccent,
          ),
        if (ColossusArgus.lastLogoutTime != null)
          _MetricRow(
            label: 'Last logout',
            value: _formatDateTime(ColossusArgus.lastLogoutTime!),
            valueColor: Colors.orangeAccent,
          ),
        if (ColossusArgus.lastLoginTime == null &&
            ColossusArgus.lastLogoutTime == null)
          const _MetricRow(
            label: 'Activity',
            value: 'No events yet',
            valueColor: Colors.white38,
          ),

        const SizedBox(height: 12),
        const _SectionHeader(label: 'BRIDGE'),
        const _MetricRow(
          label: 'Connected',
          value: 'Yes',
          valueColor: Colors.tealAccent,
        ),
        _MetricRow(
          label: 'Total events tracked',
          value: '${ColossusArgus.loginCount + ColossusArgus.logoutCount}',
          valueColor: Colors.white70,
        ),
      ],
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }

  static String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    }
    return '${d.inSeconds}s';
  }
}

// ---------------------------------------------------------------------------
// History tab — login/logout event feed
// ---------------------------------------------------------------------------

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.colossus});

  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    final authEvents = colossus.events
        .where((e) => e['source'] == 'argus')
        .toList()
        .reversed
        .toList();

    if (authEvents.isEmpty) {
      return const Center(
        child: Text(
          'No auth events recorded.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      key: const PageStorageKey('argus_history'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: authEvents.length,
      itemBuilder: (_, i) => _AuthEventCard(event: authEvents[i]),
    );
  }
}

/// Card for a single auth event.
class _AuthEventCard extends StatelessWidget {
  const _AuthEventCard({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final type = (event['type'] as String?) ?? '?';
    final isLogin = type == 'login';
    final timestamp = event['timestamp'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF262636),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLogin
              ? Colors.tealAccent.withAlpha(60)
              : Colors.orangeAccent.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLogin ? Icons.login : Icons.logout,
            color: isLogin ? Colors.tealAccent : Colors.orangeAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLogin ? 'User logged in' : 'User logged out',
                  style: TextStyle(
                    color: isLogin ? Colors.tealAccent : Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (timestamp != null)
            Text(
              _formatTimestamp(timestamp),
              style: const TextStyle(color: Colors.white24, fontSize: 9),
            ),
        ],
      ),
    );
  }

  static String _formatTimestamp(String timestamp) {
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return timestamp;
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}:'
        '${dt.second.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// Stats tab — aggregate auth metrics
// ---------------------------------------------------------------------------

class _StatsView extends StatelessWidget {
  const _StatsView({required this.colossus});

  final Colossus colossus;

  @override
  Widget build(BuildContext context) {
    final loginCount = ColossusArgus.loginCount;
    final logoutCount = ColossusArgus.logoutCount;
    final sessions = ColossusArgus.sessionDurations;

    // Guard redirects from Atlas bridge
    final guardRedirects = colossus.events
        .where((e) => e['source'] == 'atlas' && e['type'] == 'guard_redirect')
        .length;

    // Session duration stats
    Duration? avgSession;
    Duration? longestSession;
    Duration? shortestSession;
    if (sessions.isNotEmpty) {
      final totalMs = sessions
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b);
      avgSession = Duration(milliseconds: totalMs ~/ sessions.length);
      longestSession = sessions.reduce((a, b) => a > b ? a : b);
      shortestSession = sessions.reduce((a, b) => a < b ? a : b);
    }

    if (loginCount == 0 && logoutCount == 0) {
      return const Center(
        child: Text(
          'No auth activity recorded.',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView(
      key: const PageStorageKey('argus_stats'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        const _SectionHeader(label: 'ACTIVITY'),
        _MetricRow(
          label: 'Logins',
          value: '$loginCount',
          valueColor: Colors.tealAccent,
        ),
        _MetricRow(
          label: 'Logouts',
          value: '$logoutCount',
          valueColor: Colors.orangeAccent,
        ),
        _MetricRow(
          label: 'Guard redirects',
          value: '$guardRedirects',
          valueColor: guardRedirects > 0 ? Colors.amberAccent : Colors.white38,
        ),

        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionHeader(label: 'SESSIONS'),
          _MetricRow(
            label: 'Completed',
            value: '${sessions.length}',
            valueColor: Colors.white70,
          ),
          if (avgSession != null)
            _MetricRow(
              label: 'Average duration',
              value: _StateView._formatDuration(avgSession),
              valueColor: Colors.tealAccent,
            ),
          if (longestSession != null)
            _MetricRow(
              label: 'Longest',
              value: _StateView._formatDuration(longestSession),
              valueColor: Colors.amberAccent,
            ),
          if (shortestSession != null)
            _MetricRow(
              label: 'Shortest',
              value: _StateView._formatDuration(shortestSession),
              valueColor: Colors.white54,
            ),
        ],
      ],
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
