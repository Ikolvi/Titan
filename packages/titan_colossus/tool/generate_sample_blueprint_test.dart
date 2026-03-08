@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  test('generate sample blueprint', () {
    final terrain = Terrain();

    void addOutpost(String route, String name, int visits, List<March> exits) {
      terrain.outposts[route] = Outpost(
        signet: Signet(
          routePattern: route,
          interactiveDescriptors: const [],
          hash: route.hashCode.toRadixString(16),
          identity: 'screen:$route',
        ),
        routePattern: route,
        displayName: name,
        observationCount: visits,
        exits: exits,
      );
    }

    March march(
      String from,
      String to,
      MarchTrigger trigger,
      int count, {
      String? label,
    }) {
      return March(
        fromRoute: from,
        toRoute: to,
        trigger: trigger,
        triggerElementLabel: label,
        observationCount: count,
      );
    }

    addOutpost('/', 'Home (Quest List)', 15, [
      march('/', '/quest/:id', MarchTrigger.tap, 12, label: 'View Quest'),
      march('/', '/settings', MarchTrigger.tap, 3, label: 'Settings'),
      march('/', '/shade-demo', MarchTrigger.tap, 5, label: 'Shade Demo'),
      march('/', '/enterprise', MarchTrigger.tap, 3, label: 'Enterprise'),
      march('/', '/form-demo', MarchTrigger.tap, 2, label: 'Forms'),
    ]);

    addOutpost('/quest/:id', 'Quest Detail', 12, [
      march('/quest/:id', '/', MarchTrigger.back, 8),
      march('/quest/:id', '/quest/:id/edit', MarchTrigger.tap, 4,
          label: 'Edit'),
    ]);

    addOutpost('/quest/:id/edit', 'Quest Edit', 4, [
      march('/quest/:id/edit', '/quest/:id', MarchTrigger.back, 3),
    ]);

    addOutpost('/settings', 'Settings', 3, [
      march('/settings', '/', MarchTrigger.back, 3),
    ]);

    addOutpost('/shade-demo', 'Shade Demo', 5, [
      march('/shade-demo', '/', MarchTrigger.back, 4),
    ]);

    addOutpost('/enterprise', 'Enterprise Demo', 3, [
      march('/enterprise', '/', MarchTrigger.back, 3),
    ]);

    // Dead end — no exits
    addOutpost('/form-demo', 'Scroll & Form Demo', 2, []);

    terrain.sessionsAnalyzed = 5;
    terrain.invalidateCache();

    final scout = Scout.withTerrain(terrain);

    // Generate Stratagems
    final stratagems = <Stratagem>[];
    for (final outpost in terrain.outposts.values) {
      stratagems.addAll(Gauntlet.generateFor(outpost));
    }

    // Create BlueprintExport
    final export = BlueprintExport(
      terrain: terrain,
      stratagems: stratagems,
      verdicts: const [],
      routePatterns: {'/quest/:id', '/quest/:id/edit'},
      exportedAt: DateTime.now(),
      metadata: {
        'appName': 'Questboard',
        'package': 'titan_example',
        'framework': 'Titan + Atlas',
      },
    );

    // Write files
    final outputDir = '../../.titan';
    Directory(outputDir).createSync(recursive: true);

    final jsonStr = export.toJsonString();
    File('$outputDir/blueprint.json').writeAsStringSync(jsonStr);

    final compactStr = export.toCompactJsonString();
    File('$outputDir/blueprint-compact.json').writeAsStringSync(compactStr);

    final prompt = export.toAiPrompt();
    File('$outputDir/blueprint-prompt.md').writeAsStringSync(prompt);

    // ignore: avoid_print
    print('Generated blueprint.json (${jsonStr.length} bytes)');
    // ignore: avoid_print
    print('Generated blueprint-compact.json (${compactStr.length} bytes)');
    // ignore: avoid_print
    print('Generated blueprint-prompt.md (${prompt.length} bytes)');
    // ignore: avoid_print
    print('${stratagems.length} Stratagems');
    // ignore: avoid_print
    print('${terrain.screenCount} screens, '
        '${terrain.transitionCount} transitions');
    // ignore: avoid_print
    print('${terrain.deadEnds.length} dead ends');

    expect(terrain.screenCount, 7);
    expect(stratagems, isNotEmpty);

    Scout.reset();
  });
}
