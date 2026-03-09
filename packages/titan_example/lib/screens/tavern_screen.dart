import 'package:flutter/material.dart';
import 'package:titan_atlas/titan_atlas.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../models/tale.dart';
import '../pillars/tavern_pillar.dart';

// ---------------------------------------------------------------------------
// TavernScreen — Paginated tales list with search & create
// ---------------------------------------------------------------------------
//
// Demonstrates:
//   Vestige            — Reactive widget consumer
//   Codex + Envoy      — HTTP-backed paginated list
//   Recall             — Cancel token for search
//   POST via Envoy     — Creating a new tale
//   DELETE via Envoy   — Removing a tale
//   EnvoyMetric        — Live request metrics display
//   Atlas navigation   — Push to tale detail screen
// ---------------------------------------------------------------------------

/// The Tavern — a bulletin board of hero tales fetched via HTTP.
///
/// Shows a paginated list of tales from JSONPlaceholder with search,
/// create, and a live network metrics dashboard.
class TavernScreen extends StatelessWidget {
  const TavernScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Vestige<TavernPillar>(
      builder: (context, pillar) {
        final isSearchActive = pillar.isSearchActive.value;
        final searchResults = pillar.searchResults.value;
        final items = pillar.tales.items.value;
        final isLoading = pillar.tales.isLoading.value;
        final hasMore = pillar.tales.hasMore.value;
        final error = pillar.tales.error.value;
        final displayItems = isSearchActive ? searchResults : items;

        return Column(
          children: [
            // Network metrics banner
            _MetricsBanner(pillar: pillar),

            // Search bar with Recall
            _SearchBar(pillar: pillar),

            // Error display
            if (error != null)
              MaterialBanner(
                content: Text('Network error: $error'),
                backgroundColor: Colors.red.shade50,
                actions: [
                  TextButton(
                    onPressed: pillar.refreshTales,
                    child: const Text('Retry'),
                  ),
                ],
              ),

            // Tales list
            Expanded(
              child: isLoading && items.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : displayItems.isEmpty && isSearchActive
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No tales match your search',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: pillar.refreshTales,
                      child: ListView.builder(
                        itemCount:
                            displayItems.length +
                            (!isSearchActive && hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= displayItems.length) {
                            pillar.loadMore();
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final tale = displayItems[index];
                          return _TaleTile(
                            tale: tale,
                            onTap: () => context.atlas.to('/tale/${tale.id}'),
                            onDelete: () =>
                                _confirmDelete(context, pillar, tale),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, TavernPillar pillar, Tale tale) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tale?'),
        content: Text('Remove "${tale.title}" from the board?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              pillar.deleteTale(tale.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Network Metrics Banner
// ---------------------------------------------------------------------------

class _MetricsBanner extends StatelessWidget {
  final TavernPillar pillar;

  const _MetricsBanner({required this.pillar});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = pillar.totalRequests.value;
    final avg = pillar.avgLatency.value;
    final cached = pillar.cacheHits.value;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.tertiaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi, size: 20, color: theme.colorScheme.onSurface),
          const SizedBox(width: 8),
          Text(
            'Envoy Stats',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _MetricChip(icon: Icons.send, label: '$total req'),
          const SizedBox(width: 8),
          _MetricChip(icon: Icons.timer, label: '${avg.inMilliseconds}ms'),
          const SizedBox(width: 8),
          _MetricChip(icon: Icons.cached, label: '$cached hits'),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search Bar with Recall
// ---------------------------------------------------------------------------

class _SearchBar extends StatefulWidget {
  final TavernPillar pillar;
  const _SearchBar({required this.pillar});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Search tales...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: widget.pillar.isSearchActive.value
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          widget.pillar.clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                isDense: true,
              ),
              onChanged: widget.pillar.updateSearch,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            onPressed: () => _showCreateDialog(context),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post a New Tale'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'The Dragon of Ember Peak...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              decoration: const InputDecoration(
                labelText: 'Tale',
                hintText: 'Tell your tale, hero...',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && bodyCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                widget.pillar.createTale(
                  title: titleCtrl.text,
                  body: bodyCtrl.text,
                );
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tale Tile
// ---------------------------------------------------------------------------

class _TaleTile extends StatelessWidget {
  final Tale tale;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _TaleTile({required this.tale, this.onTap, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(
                      (tale.authorName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tale.authorName ?? 'Unknown Hero',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '#${tale.id}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Delete Tale',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _capitalize(tale.title),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                tale.body,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
