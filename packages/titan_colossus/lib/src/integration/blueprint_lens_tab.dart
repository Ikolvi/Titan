import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../colossus.dart';
import 'lens.dart';
import '../discovery/gauntlet.dart';
import '../discovery/lineage.dart';
import '../discovery/march.dart';
import '../discovery/outpost.dart';
import '../testing/campaign.dart';
import '../testing/debrief.dart';
import '../testing/stratagem.dart';
import '../testing/verdict.dart';

// ---------------------------------------------------------------------------
// BlueprintLensTab — Lens Plugin for AI Blueprint Generation
// ---------------------------------------------------------------------------

/// A [LensPlugin] that adds a "Blueprint" tab to the Lens debug overlay.
///
/// Provides five sub-tabs for AI-assisted test generation:
/// - **Terrain**: Flow graph visualization with screen/transition counts
/// - **Lineage**: Prerequisite chain viewer for any route
/// - **Gauntlet**: Edge-case test generator for specific screens
/// - **Campaign**: Campaign builder and executor
/// - **Debrief**: Verdict analysis with insights and fix suggestions
///
/// Automatically registered when `Colossus.init(enableLensTab: true)`.
class BlueprintLensTab extends LensPlugin {
  final Colossus _colossus;

  /// Creates a [BlueprintLensTab] for the given [Colossus] instance.
  BlueprintLensTab(this._colossus);

  @override
  String get title => 'Blueprint';

  @override
  IconData get icon => Icons.map_outlined;

  @override
  Widget build(BuildContext context) {
    return _BlueprintTabContent(colossus: _colossus);
  }
}

// ---------------------------------------------------------------------------
// Pillar — Blueprint Tab State & Business Logic
// ---------------------------------------------------------------------------

/// Internal [Pillar] managing all Blueprint tab reactive state.
///
/// Uses [Core] fields for reactive state, keeping the Colossus package
/// aligned with Titan's own architecture.
class _BlueprintPillar extends Pillar {
  final Colossus colossus;

  _BlueprintPillar(this.colossus);

  /// Listener closure stored for cleanup in [onDispose].
  VoidCallback? _terrainListener;

  // -- Reactive state -------------------------------------------------------

  /// Status message displayed at the top of the tab.
  late final status = core('');

  /// Bumped whenever [Colossus.terrainNotifier] fires, causing any
  /// [Vestige] that reads this value to rebuild with fresh Terrain data.
  late final terrainRefresh = core(0);

  /// Selected route for Lineage viewer.
  late final selectedRoute = core<String?>(null);

  /// Lineage result for the selected route.
  late final lineageResult = core<Lineage?>(null);

  /// Selected route for Gauntlet generation.
  late final gauntletRoute = core<String?>(null);

  /// Gauntlet intensity level.
  late final gauntletIntensity = core(GauntletIntensity.standard);

  /// Number of Gauntlet patterns generated.
  late final gauntletCount = core(0);

  /// Generated Gauntlet stratagems.
  late final gauntletStratagems = core<List<Stratagem>>([]);

  /// Campaign JSON input text.
  late final campaignJson = core('');

  /// Campaign execution status.
  late final campaignStatus = core('');

  /// Whether a Campaign is currently executing.
  late final campaignRunning = core(false);

  /// Last Campaign result summary.
  late final campaignResult = core('');

  /// Last Campaign result object.
  late final lastCampaignResult = core<CampaignResult?>(null);

  /// Debrief insights from last analysis.
  late final debriefSummary = core('');

  /// Last debrief report.
  late final lastReport = core<DebriefReport?>(null);

  // -- Actions --------------------------------------------------------------

  /// Copy the Terrain Mermaid diagram to clipboard.
  void copyTerrainMermaid() {
    final mermaid = colossus.terrain.toMermaid();
    Clipboard.setData(ClipboardData(text: mermaid));
    status.value = 'Terrain Mermaid copied to clipboard';
  }

  /// Copy the AI map to clipboard.
  void copyAiMap() {
    final map = colossus.terrain.toAiMap();
    Clipboard.setData(ClipboardData(text: map));
    status.value = 'AI map copied to clipboard';
  }

  /// Resolve Lineage for the currently selected route.
  void resolveLineage() {
    final route = selectedRoute.value;
    if (route == null || route.isEmpty) {
      status.value = 'Select a route first';
      return;
    }

    final lineage = colossus.resolveLineage(route);
    lineageResult.value = lineage;
    status.value = lineage.isEmpty
        ? 'No lineage found for $route'
        : 'Lineage resolved: ${lineage.path.length} steps';
  }

  /// Copy the Lineage setup Stratagem to clipboard.
  void copyLineageStratagem() {
    final lineage = lineageResult.value;
    if (lineage == null || lineage.isEmpty) {
      status.value = 'No lineage to copy';
      return;
    }

    final stratagem = lineage.toSetupStratagem();
    final json = const JsonEncoder.withIndent('  ').convert(stratagem.toJson());
    Clipboard.setData(ClipboardData(text: json));
    status.value = 'Setup Stratagem copied to clipboard';
  }

  /// Copy the Lineage AI summary to clipboard.
  void copyLineageSummary() {
    final lineage = lineageResult.value;
    if (lineage == null) {
      status.value = 'No lineage to copy';
      return;
    }

    Clipboard.setData(ClipboardData(text: lineage.toAiSummary()));
    status.value = 'Lineage summary copied to clipboard';
  }

  /// Generate Gauntlet patterns for the selected route.
  void generateGauntlet() {
    final route = gauntletRoute.value;
    if (route == null || route.isEmpty) {
      status.value = 'Select a route first';
      return;
    }

    final stratagems = colossus.generateGauntlet(
      route,
      intensity: gauntletIntensity.value,
    );

    gauntletCount.value = stratagems.length;
    gauntletStratagems.value = stratagems;
    status.value = stratagems.isEmpty
        ? 'No outpost found for "$route"'
        : 'Generated ${stratagems.length} Gauntlet patterns';
  }

  /// Copy all generated Gauntlet Stratagems as JSON to clipboard.
  void copyGauntletStratagems() {
    final strats = gauntletStratagems.value;
    if (strats.isEmpty) {
      status.value = 'Generate Gauntlet first';
      return;
    }

    final json = const JsonEncoder.withIndent('  ')
        .convert(strats.map((s) => s.toJson()).toList());
    Clipboard.setData(ClipboardData(text: json));
    status.value = '${strats.length} Gauntlet Stratagems copied to clipboard';
  }

  /// Run debrief on verdicts from a Campaign result or manual input.
  void runDebrief(List<Verdict> verdicts) {
    if (verdicts.isEmpty) {
      status.value = 'No verdicts to debrief';
      return;
    }

    final report = colossus.debrief(verdicts);
    lastReport.value = report;
    debriefSummary.value = report.toAiSummary();
    status.value =
        'Debrief: ${report.passedVerdicts}/${report.totalVerdicts} passed, '
        '${report.insights.length} insights';
  }

  /// Copy the debrief AI summary to clipboard.
  void copyDebriefSummary() {
    final summary = debriefSummary.value;
    if (summary.isEmpty) {
      status.value = 'No debrief to copy';
      return;
    }

    Clipboard.setData(ClipboardData(text: summary));
    status.value = 'AI debrief copied to clipboard';
  }

  /// Copy the full AI Blueprint context to clipboard.
  Future<void> copyAiBlueprint() async {
    status.value = 'Generating AI Blueprint...';
    try {
      final blueprint = await colossus.getAiBlueprint();
      final json = const JsonEncoder.withIndent('  ').convert(blueprint);
      await Clipboard.setData(ClipboardData(text: json));
      status.value = 'Full AI Blueprint copied to clipboard';
    } catch (e) {
      status.value = 'Error: $e';
    }
  }

  // -- Lifecycle ------------------------------------------------------------

  @override
  void onInit() {
    super.onInit();
    // Subscribe to terrain updates so the Blueprint tab auto-refreshes
    // when Scout auto-learns from new Shade sessions.
    _terrainListener = () {
      terrainRefresh.value++;
    };
    colossus.terrainNotifier.addListener(_terrainListener!);
  }

  @override
  void onDispose() {
    final listener = _terrainListener;
    if (listener != null) {
      colossus.terrainNotifier.removeListener(listener);
      _terrainListener = null;
    }
    super.onDispose();
  }
}

// ---------------------------------------------------------------------------
// Tab Content
// ---------------------------------------------------------------------------

class _BlueprintTabContent extends StatelessWidget {
  final Colossus colossus;
  const _BlueprintTabContent({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Beacon(
      pillars: [() => _BlueprintPillar(colossus)],
      child: Localizations(
        locale: const Locale('en'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: DefaultTabController(
          length: 5,
          child: Column(
            children: [
              const _SubTabBar(),
              // Status bar
              Vestige<_BlueprintPillar>(
                builder: (context, p) => _StatusBar(status: p.status.value),
              ),
              Expanded(child: _BlueprintTabBody(colossus: colossus)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final String status;
  const _StatusBar({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.tealAccent.withValues(alpha: 0.07),
        border: Border(
          bottom: BorderSide(color: Colors.white10),
        ),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.tealAccent, fontSize: 9),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _SubTabBar extends StatelessWidget {
  const _SubTabBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: TabBar(
        isScrollable: true,
        labelColor: Colors.tealAccent,
        unselectedLabelColor: Colors.white38,
        indicatorColor: Colors.tealAccent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(text: 'Terrain'),
          Tab(text: 'Lineage'),
          Tab(text: 'Gauntlet'),
          Tab(text: 'Campaign'),
          Tab(text: 'Debrief'),
        ],
      ),
    );
  }
}

class _BlueprintTabBody extends StatelessWidget {
  final Colossus colossus;
  const _BlueprintTabBody({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return TabBarView(
      children: [
        _TerrainView(colossus: colossus),
        _LineageView(colossus: colossus),
        _GauntletView(colossus: colossus),
        _CampaignView(colossus: colossus),
        _DebriefView(colossus: colossus),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Terrain View
// ---------------------------------------------------------------------------

class _TerrainView extends StatelessWidget {
  final Colossus colossus;
  const _TerrainView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    // Wrap in Vestige to auto-rebuild when terrainRefresh bumps
    // (triggered by Colossus.terrainNotifier after auto-learn).
    return Vestige<_BlueprintPillar>(builder: (context, p) {
      // Reading terrainRefresh subscribes this Vestige to terrain changes.
      // ignore: unused_local_variable
      final _ = p.terrainRefresh.value;

      final terrain = colossus.terrain;
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          _MetricRow(
            label: 'Discovered screens',
            value: '${terrain.outposts.length}',
          ),
          _MetricRow(
            label: 'Transitions',
            value: '${terrain.marches.length}',
          ),
          _MetricRow(
            label: 'Sessions analyzed',
            value: '${terrain.sessionsAnalyzed}',
          ),
          _MetricRow(
            label: 'Auth-protected routes',
            value: '${terrain.authProtectedScreens.length}',
          ),
          _MetricRow(
            label: 'Dead ends',
            value: '${terrain.deadEnds.length}',
            color: terrain.deadEnds.isNotEmpty
                ? Colors.orangeAccent
                : Colors.white54,
          ),
          _MetricRow(
            label: 'Unreliable transitions',
            value: '${terrain.unreliableMarches.length}',
            color: terrain.unreliableMarches.isNotEmpty
                ? Colors.redAccent
                : Colors.white54,
          ),
          const SizedBox(height: 8),
          // Route list
          if (terrain.outposts.isNotEmpty) ...[
            const _SectionHeader(title: 'DISCOVERED ROUTES'),
            ...terrain.outposts.entries.map((e) => _RouteCard(
                  route: e.key,
                  outpost: e.value,
                )),
          ],
          const SizedBox(height: 8),
          // Action buttons
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _ActionChip(
                label: 'Copy Mermaid',
                icon: Icons.account_tree,
                onTap: p.copyTerrainMermaid,
              ),
              _ActionChip(
                label: 'Copy AI Map',
                icon: Icons.map,
                onTap: p.copyAiMap,
              ),
              _ActionChip(
                label: 'Copy Blueprint',
                icon: Icons.copy_all,
                onTap: p.copyAiBlueprint,
              ),
            ],
          ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// 2. Lineage View
// ---------------------------------------------------------------------------

class _LineageView extends StatelessWidget {
  final Colossus colossus;
  const _LineageView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Vestige<_BlueprintPillar>(builder: (context, p) {
      final routes = colossus.terrain.outposts.keys.toList()..sort();
      final lineage = p.lineageResult.value;

      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          // Route dropdown
          const _SectionHeader(title: 'TARGET ROUTE'),
          _RouteDropdown(
            routes: routes,
            selected: p.selectedRoute.value,
            onChanged: (route) {
              p.selectedRoute.value = route;
              p.lineageResult.value = null;
            },
          ),
          const SizedBox(height: 8),
          _ActionChip(
            label: 'Resolve Lineage',
            icon: Icons.timeline,
            onTap: p.resolveLineage,
          ),
          const SizedBox(height: 12),

          // Result
          if (lineage != null) ...[
            const _SectionHeader(title: 'PREREQUISITE CHAIN'),
            if (lineage.isEmpty)
              const _InfoCard(message: 'No prerequisites needed — '
                  'route is directly accessible.')
            else ...[
              _MetricRow(
                label: 'Hops',
                value: '${lineage.hopCount}',
              ),
              _MetricRow(
                label: 'Auth required',
                value: lineage.requiresAuth ? 'Yes' : 'No',
                color: lineage.requiresAuth
                    ? Colors.orangeAccent
                    : Colors.greenAccent,
              ),
              _MetricRow(
                label: 'Est. setup time',
                value:
                    '${lineage.estimatedSetupTime.inMilliseconds}ms',
              ),
              const SizedBox(height: 4),
              const _SectionHeader(title: 'PATH'),
              ...lineage.path.map((march) => _MarchCard(march: march)),
              if (lineage.prerequisites.isNotEmpty) ...[
                const SizedBox(height: 8),
                const _SectionHeader(title: 'GATES'),
                ...lineage.prerequisites.map(
                  (p) => _PrerequisiteCard(prerequisite: p),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _ActionChip(
                    label: 'Copy Stratagem',
                    icon: Icons.content_copy,
                    onTap: p.copyLineageStratagem,
                  ),
                  _ActionChip(
                    label: 'Copy Summary',
                    icon: Icons.summarize,
                    onTap: p.copyLineageSummary,
                  ),
                ],
              ),
            ],
          ],
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// 3. Gauntlet View
// ---------------------------------------------------------------------------

class _GauntletView extends StatelessWidget {
  final Colossus colossus;
  const _GauntletView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Vestige<_BlueprintPillar>(builder: (context, p) {
      final routes = colossus.terrain.outposts.keys.toList()..sort();

      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const _SectionHeader(title: 'TARGET SCREEN'),
          _RouteDropdown(
            routes: routes,
            selected: p.gauntletRoute.value,
            onChanged: (route) => p.gauntletRoute.value = route,
          ),
          const SizedBox(height: 8),
          const _SectionHeader(title: 'INTENSITY'),
          _IntensitySelector(
            intensity: p.gauntletIntensity.value,
            onChanged: (i) => p.gauntletIntensity.value = i,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _ActionChip(
                label: 'Generate Gauntlet',
                icon: Icons.bolt,
                onTap: p.generateGauntlet,
              ),
              if (p.gauntletStratagems.value.isNotEmpty)
                _ActionChip(
                  label: 'Copy Stratagems',
                  icon: Icons.content_copy,
                  onTap: p.copyGauntletStratagems,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.gauntletStratagems.value.isNotEmpty) ...[
            _SectionHeader(
              title: 'GENERATED (${p.gauntletCount.value})',
            ),
            ...p.gauntletStratagems.value.map(
              (s) => _StratagemCard(stratagem: s),
            ),
            const SizedBox(height: 8),
          ],
          // Catalog preview
          const _SectionHeader(title: 'PATTERN CATALOG'),
          _MetricRow(
            label: 'Available patterns',
            value: '${Gauntlet.catalog.length}',
          ),
          ...GauntletCategory.values.map((cat) {
            final patterns = Gauntlet.patternsForCategory(cat);
            return _MetricRow(
              label: cat.name,
              value: '${patterns.length} patterns',
            );
          }),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// 4. Campaign View
// ---------------------------------------------------------------------------

class _CampaignView extends StatelessWidget {
  final Colossus colossus;
  const _CampaignView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Vestige<_BlueprintPillar>(builder: (context, p) {
      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          const _SectionHeader(title: 'CAMPAIGN JSON'),
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white10),
            ),
            child: TextField(
              maxLines: null,
              expands: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: Colors.white70,
              ),
              decoration: const InputDecoration(
                hintText: 'Paste Campaign JSON here...',
                hintStyle: TextStyle(color: Colors.white24, fontSize: 10),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(8),
              ),
              onChanged: (text) => p.campaignJson.value = text,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _ActionChip(
                label: 'Execute Campaign',
                icon: Icons.play_arrow,
                onTap: p.campaignRunning.value ? null : () async {
                  final json = p.campaignJson.value;
                  if (json.isEmpty) {
                    p.status.value = 'Paste Campaign JSON first';
                    return;
                  }
                  try {
                    final map = jsonDecode(json) as Map<String, dynamic>;
                    p.campaignRunning.value = true;
                    p.campaignStatus.value = 'Running...';
                    final result = await colossus.executeCampaignJson(map);
                    p.campaignResult.value = result.toReport();
                    p.lastCampaignResult.value = result;
                    p.campaignStatus.value =
                        '${result.totalExecuted} executed, '
                        '${result.totalFailed} failed '
                        '(${(result.passRate * 100).toStringAsFixed(1)}%)';
                    p.campaignRunning.value = false;

                    // Auto-debrief the campaign results
                    final allVerdicts = [
                      ...result.verdicts.values,
                      ...result.prerequisiteVerdicts.values,
                      ...?result.gauntletVerdicts?.values,
                    ];
                    p.runDebrief(allVerdicts);
                  } catch (e) {
                    p.campaignStatus.value = 'Error: $e';
                    p.campaignRunning.value = false;
                  }
                },
              ),
              _ActionChip(
                label: 'Copy Template',
                icon: Icons.content_paste,
                onTap: () {
                  final template = const JsonEncoder.withIndent('  ')
                      .convert(Campaign.template);
                  Clipboard.setData(ClipboardData(text: template));
                  p.status.value = 'Campaign template copied to clipboard';
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (p.campaignRunning.value)
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.tealAccent,
                ),
              ),
            ),
          if (p.campaignStatus.value.isNotEmpty)
            _InfoCard(message: p.campaignStatus.value),
          // Campaign result details
          if (p.lastCampaignResult.value != null) ...[
            const SizedBox(height: 8),
            const _SectionHeader(title: 'RESULTS'),
            _MetricRow(
              label: 'Total executed',
              value: '${p.lastCampaignResult.value!.totalExecuted}',
            ),
            _MetricRow(
              label: 'Passed',
              value:
                  '${p.lastCampaignResult.value!.totalExecuted - p.lastCampaignResult.value!.totalFailed}',
              color: Colors.greenAccent,
            ),
            _MetricRow(
              label: 'Failed',
              value: '${p.lastCampaignResult.value!.totalFailed}',
              color: p.lastCampaignResult.value!.totalFailed > 0
                  ? Colors.redAccent
                  : Colors.greenAccent,
            ),
            _MetricRow(
              label: 'Pass rate',
              value:
                  '${(p.lastCampaignResult.value!.passRate * 100).toStringAsFixed(1)}%',
              color: p.lastCampaignResult.value!.passRate >= 0.9
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
            _MetricRow(
              label: 'Duration',
              value:
                  '${p.lastCampaignResult.value!.duration.inMilliseconds}ms',
            ),
            const SizedBox(height: 4),
            const _SectionHeader(title: 'VERDICTS'),
            ...p.lastCampaignResult.value!.verdicts.entries.map(
              (e) => _VerdictRow(name: e.key, verdict: e.value),
            ),
            if (p.lastCampaignResult.value!.prerequisiteVerdicts
                .isNotEmpty) ...[
              const SizedBox(height: 4),
              const _SectionHeader(title: 'PREREQUISITE VERDICTS'),
              ...p.lastCampaignResult.value!.prerequisiteVerdicts.entries
                  .map(
                (e) => _VerdictRow(name: e.key, verdict: e.value),
              ),
            ],
            if (p.lastCampaignResult.value!.gauntletVerdicts
                    ?.isNotEmpty ??
                false) ...[
              const SizedBox(height: 4),
              const _SectionHeader(title: 'GAUNTLET VERDICTS'),
              ...p.lastCampaignResult.value!.gauntletVerdicts!.entries
                  .map(
                (e) => _VerdictRow(name: e.key, verdict: e.value),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _ActionChip(
                  label: 'Copy Report',
                  icon: Icons.description,
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: p.campaignResult.value),
                    );
                    p.status.value = 'Campaign report copied to clipboard';
                  },
                ),
                _ActionChip(
                  label: 'Copy JSON',
                  icon: Icons.data_object,
                  onTap: () {
                    final json = const JsonEncoder.withIndent('  ')
                        .convert(p.lastCampaignResult.value!.toJson());
                    Clipboard.setData(ClipboardData(text: json));
                    p.status.value = 'Campaign result JSON copied';
                  },
                ),
              ],
            ),
          ],
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// 5. Debrief View
// ---------------------------------------------------------------------------

class _DebriefView extends StatelessWidget {
  final Colossus colossus;
  const _DebriefView({required this.colossus});

  @override
  Widget build(BuildContext context) {
    return Vestige<_BlueprintPillar>(builder: (context, p) {
      final report = p.lastReport.value;

      return ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (report != null) ...[
            const _SectionHeader(title: 'DEBRIEF RESULTS'),
            _MetricRow(
              label: 'Verdicts',
              value: '${report.totalVerdicts}',
            ),
            _MetricRow(
              label: 'Passed',
              value: '${report.passedVerdicts}/${report.totalVerdicts}',
              color: report.allPassed ? Colors.greenAccent : Colors.orangeAccent,
            ),
            _MetricRow(
              label: 'Pass rate',
              value: '${(report.passRate * 100).toStringAsFixed(1)}%',
              color: report.passRate >= 0.9
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
            _MetricRow(
              label: 'Insights',
              value: '${report.insights.length}',
            ),
            const SizedBox(height: 8),
            if (report.insights.isNotEmpty) ...[
              const _SectionHeader(title: 'INSIGHTS'),
              ...report.insights.map((insight) => _InsightCard(
                    insight: insight,
                  )),
            ],
            const SizedBox(height: 8),
            if (report.suggestedNextActions.isNotEmpty) ...[
              const _SectionHeader(title: 'SUGGESTED ACTIONS'),
              ...report.suggestedNextActions.map((action) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '→ $action',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 8),
            _ActionChip(
              label: 'Copy AI Debrief',
              icon: Icons.copy,
              onTap: p.copyDebriefSummary,
            ),
          ] else
            const _InfoCard(
              message: 'No debrief data yet.\n'
                  'Execute a Campaign or call debrief() to analyze verdicts.',
            ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------------------
// Shared Widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.tealAccent,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MetricRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: onTap != null
              ? Colors.tealAccent.withValues(alpha: 0.1)
              : Colors.white10,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: onTap != null
                ? Colors.tealAccent.withValues(alpha: 0.3)
                : Colors.white10,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: onTap != null ? Colors.tealAccent : Colors.white24,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: onTap != null ? Colors.tealAccent : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String message;
  const _InfoCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.white54, fontSize: 10),
      ),
    );
  }
}

class _RouteDropdown extends StatelessWidget {
  final List<String> routes;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _RouteDropdown({
    required this.routes,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const _InfoCard(
        message: 'No routes discovered yet. Record sessions or '
            'execute Stratagems to build the Terrain.',
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButton<String>(
        value: selected,
        isExpanded: true,
        dropdownColor: const Color(0xFF1E1E1E),
        hint: const Text(
          'Select route...',
          style: TextStyle(color: Colors.white24, fontSize: 10),
        ),
        style: const TextStyle(color: Colors.white70, fontSize: 10),
        underline: const SizedBox.shrink(),
        items: routes
            .map((r) => DropdownMenuItem(
                  value: r,
                  child: Text(r, overflow: TextOverflow.ellipsis),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _IntensitySelector extends StatelessWidget {
  final GauntletIntensity intensity;
  final ValueChanged<GauntletIntensity> onChanged;

  const _IntensitySelector({
    required this.intensity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GauntletIntensity.values.map((i) {
        final isSelected = i == intensity;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.tealAccent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected
                      ? Colors.tealAccent.withValues(alpha: 0.5)
                      : Colors.white10,
                ),
              ),
              child: Text(
                i.name,
                style: TextStyle(
                  color: isSelected ? Colors.tealAccent : Colors.white38,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final String route;
  final Outpost outpost;

  const _RouteCard({required this.route, required this.outpost});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(
            outpost.requiresAuth ? Icons.lock : Icons.public,
            size: 12,
            color: outpost.requiresAuth
                ? Colors.orangeAccent
                : Colors.greenAccent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              route,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${outpost.interactiveElements.length} elem',
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          const SizedBox(width: 8),
          Text(
            '${outpost.exits.length} exit',
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _MarchCard extends StatelessWidget {
  final March march;
  const _MarchCard({required this.march});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_forward, size: 10, color: Colors.tealAccent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${march.fromRoute} → ${march.toRoute}',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            march.trigger.name,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _PrerequisiteCard extends StatelessWidget {
  final StratagemPrerequisite prerequisite;
  const _PrerequisiteCard({required this.prerequisite});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.orangeAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            prerequisite.isAuthGate ? Icons.lock : Icons.edit_document,
            size: 12,
            color: Colors.orangeAccent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              prerequisite.description,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ),
          Text(
            prerequisite.isAuthGate ? 'Auth gate' : 'Form gate',
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final DebriefInsight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final color = _insightColor(insight.type);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  insight.type.name.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (insight.actionable) ...[
                const SizedBox(width: 6),
                const Icon(Icons.build, size: 10, color: Colors.tealAccent),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            insight.message,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          const SizedBox(height: 2),
          Text(
            insight.suggestion,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
          if (insight.fixSuggestion != null) ...[
            const SizedBox(height: 2),
            Text(
              'FIX: ${insight.fixSuggestion}',
              style: TextStyle(
                color: Colors.tealAccent.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _insightColor(InsightType type) {
    switch (type) {
      case InsightType.elementNotFound:
        return Colors.orangeAccent;
      case InsightType.unexpectedNavigation:
        return Colors.redAccent;
      case InsightType.missingPrerequisite:
        return Colors.deepOrangeAccent;
      case InsightType.wrongScreen:
        return Colors.red;
      case InsightType.performanceIssue:
        return Colors.amber;
      case InsightType.stateCorruption:
        return Colors.purpleAccent;
      case InsightType.general:
        return Colors.blueGrey;
    }
  }
}

class _StratagemCard extends StatelessWidget {
  final Stratagem stratagem;
  const _StratagemCard({required this.stratagem});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          const Icon(Icons.bolt, size: 12, color: Colors.amber),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stratagem.name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (stratagem.description.isNotEmpty)
                  Text(
                    stratagem.description,
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            '${stratagem.steps.length} steps',
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _VerdictRow extends StatelessWidget {
  final String name;
  final Verdict verdict;
  const _VerdictRow({required this.name, required this.verdict});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: verdict.passed
            ? Colors.greenAccent.withValues(alpha: 0.03)
            : Colors.redAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            verdict.passed ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: verdict.passed ? Colors.greenAccent : Colors.redAccent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${verdict.duration.inMilliseconds}ms',
            style: const TextStyle(color: Colors.white38, fontSize: 9),
          ),
        ],
      ),
    );
  }
}
