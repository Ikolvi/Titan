import 'package:titan_basalt/titan_basalt.dart';
import 'package:titan_bastion/titan_bastion.dart';

import '../data/quest_api.dart';
import '../models/quest.dart';

/// Quest Detail Pillar — single quest fetching with Quarry.
///
/// Demonstrates: Quarry (SWR, retry, deduplication), Chronicle (logging).
class QuestDetailPillar extends Pillar {
  final QuestApi _api;

  /// The quest ID to fetch.
  late final questId = core<String>('', name: 'questId');

  /// The quest detail — fetched with stale-while-revalidate and retry.
  late final quest = quarry<Quest>(
    fetcher: () => _api.fetchQuest(questId.value),
    staleTime: const Duration(seconds: 30),
    retry: const QuarryRetry(maxAttempts: 3),
    name: 'quest',
  );

  QuestDetailPillar({QuestApi? api}) : _api = api ?? QuestApi.instance;

  // --------------- Actions ---------------

  /// Load a quest by ID.
  Future<void> loadQuest(String id) async {
    questId.value = id;
    quest.invalidate();
    await quest.fetch();
    log.info('Loaded quest detail: $id');
  }

  /// Force refresh the current quest.
  Future<void> refresh() async {
    await quest.refetch();
    log.debug('Quest detail refreshed');
  }
}
