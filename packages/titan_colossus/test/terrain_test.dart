import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  Outpost createOutpost(
    String route, {
    String? displayName,
    bool requiresAuth = false,
    List<String> tags = const [],
    List<OutpostElement>? interactiveElements,
    List<March>? exits,
    List<March>? entrances,
  }) {
    return Outpost(
      signet: Signet(
        routePattern: route,
        interactiveDescriptors: const [],
        hash: route.hashCode.toRadixString(16),
        identity: route.replaceAll('/', '_'),
      ),
      routePattern: route,
      displayName: displayName ?? route,
      requiresAuth: requiresAuth,
      tags: tags,
      interactiveElements: interactiveElements,
      exits: exits,
      entrances: entrances,
      observationCount: 1,
    );
  }

  /// Build a Terrain with a simple linear flow: A → B → C.
  Terrain buildLinearTerrain() {
    final terrain = Terrain();

    final a = createOutpost('/a');
    final b = createOutpost('/b');
    final c = createOutpost('/c');

    final ab = March(
      fromRoute: '/a',
      toRoute: '/b',
      trigger: MarchTrigger.tap,
      observationCount: 3,
    );
    final bc = March(
      fromRoute: '/b',
      toRoute: '/c',
      trigger: MarchTrigger.tap,
      observationCount: 2,
    );

    a.exits.add(ab);
    b.entrances.add(ab);
    b.exits.add(bc);
    c.entrances.add(bc);

    terrain.outposts['/a'] = a;
    terrain.outposts['/b'] = b;
    terrain.outposts['/c'] = c;

    return terrain;
  }

  /// Build a Terrain with a diamond shape: A → B → D, A → C → D.
  Terrain buildDiamondTerrain() {
    final terrain = Terrain();

    final a = createOutpost('/a');
    final b = createOutpost('/b');
    final c = createOutpost('/c');
    final d = createOutpost('/d');

    final ab = March(
      fromRoute: '/a',
      toRoute: '/b',
      trigger: MarchTrigger.tap,
      observationCount: 2,
    );
    final ac = March(
      fromRoute: '/a',
      toRoute: '/c',
      trigger: MarchTrigger.tap,
      observationCount: 2,
    );
    final bd = March(
      fromRoute: '/b',
      toRoute: '/d',
      trigger: MarchTrigger.tap,
      observationCount: 2,
    );
    final cd = March(
      fromRoute: '/c',
      toRoute: '/d',
      trigger: MarchTrigger.tap,
      observationCount: 2,
    );

    a.exits.addAll([ab, ac]);
    b.entrances.add(ab);
    b.exits.add(bd);
    c.entrances.add(ac);
    c.exits.add(cd);
    d.entrances.addAll([bd, cd]);

    terrain.outposts['/a'] = a;
    terrain.outposts['/b'] = b;
    terrain.outposts['/c'] = c;
    terrain.outposts['/d'] = d;

    return terrain;
  }

  // -------------------------------------------------------------------------
  // Terrain — Flow Graph
  // -------------------------------------------------------------------------

  group('Terrain', () {
    group('constructor', () {
      test('creates empty terrain', () {
        final terrain = Terrain();
        expect(terrain.outposts, isEmpty);
        expect(terrain.screenCount, 0);
        expect(terrain.transitionCount, 0);
        expect(terrain.sessionsAnalyzed, 0);
        expect(terrain.stratagemExecutionsAnalyzed, 0);
        expect(terrain.lastUpdated, isNotNull);
      });

      test('creates with provided outposts', () {
        final terrain = Terrain(
          outposts: {'/a': createOutpost('/a'), '/b': createOutpost('/b')},
        );
        expect(terrain.screenCount, 2);
      });
    });

    group('accessors', () {
      test('screenCount returns outpost count', () {
        final terrain = buildLinearTerrain();
        expect(terrain.screenCount, 3);
      });

      test('transitionCount counts deduplicated marches', () {
        final terrain = buildLinearTerrain();
        expect(terrain.transitionCount, 2);
      });

      test('marches deduplicates by from/to/label', () {
        final terrain = buildLinearTerrain();
        final marches = terrain.marches;
        expect(marches, hasLength(2));
      });
    });

    group('reachableFrom', () {
      test('returns all reachable from start', () {
        final terrain = buildLinearTerrain();
        final reachable = terrain.reachableFrom('/a');
        expect(reachable, hasLength(3));
        expect(
          reachable.map((o) => o.routePattern),
          containsAll(['/a', '/b', '/c']),
        );
      });

      test('returns subset from middle', () {
        final terrain = buildLinearTerrain();
        final reachable = terrain.reachableFrom('/b');
        expect(reachable, hasLength(2));
        expect(reachable.map((o) => o.routePattern), containsAll(['/b', '/c']));
      });

      test('returns only self for dead end', () {
        final terrain = buildLinearTerrain();
        final reachable = terrain.reachableFrom('/c');
        expect(reachable, hasLength(1));
        expect(reachable.first.routePattern, '/c');
      });

      test('returns empty for unknown route', () {
        final terrain = buildLinearTerrain();
        final reachable = terrain.reachableFrom('/unknown');
        expect(reachable, isEmpty);
      });

      test('handles cycles without infinite loop', () {
        final terrain = Terrain();
        final a = createOutpost('/a');
        final b = createOutpost('/b');

        final ab = March(
          fromRoute: '/a',
          toRoute: '/b',
          trigger: MarchTrigger.tap,
        );
        final ba = March(
          fromRoute: '/b',
          toRoute: '/a',
          trigger: MarchTrigger.back,
        );

        a.exits.add(ab);
        b.exits.add(ba);
        b.entrances.add(ab);
        a.entrances.add(ba);

        terrain.outposts['/a'] = a;
        terrain.outposts['/b'] = b;

        final reachable = terrain.reachableFrom('/a');
        expect(reachable, hasLength(2));
      });

      test('handles diamond graph', () {
        final terrain = buildDiamondTerrain();
        final reachable = terrain.reachableFrom('/a');
        expect(reachable, hasLength(4));
      });
    });

    group('shortestPath', () {
      test('returns empty list for same source and dest', () {
        final terrain = buildLinearTerrain();
        final path = terrain.shortestPath('/a', '/a');
        expect(path, isEmpty);
      });

      test('returns direct path A → B', () {
        final terrain = buildLinearTerrain();
        final path = terrain.shortestPath('/a', '/b');
        expect(path, hasLength(1));
        expect(path!.first.fromRoute, '/a');
        expect(path.first.toRoute, '/b');
      });

      test('returns multi-hop path A → B → C', () {
        final terrain = buildLinearTerrain();
        final path = terrain.shortestPath('/a', '/c');
        expect(path, hasLength(2));
        expect(path!.first.fromRoute, '/a');
        expect(path!.first.toRoute, '/b');
        expect(path.last.fromRoute, '/b');
        expect(path.last.toRoute, '/c');
      });

      test('returns null when no path exists', () {
        final terrain = buildLinearTerrain();
        // C has no exits, but path from C to A doesn't exist
        final path = terrain.shortestPath('/c', '/a');
        expect(path, isNull);
      });

      test('returns null for unknown source', () {
        final terrain = buildLinearTerrain();
        expect(terrain.shortestPath('/unknown', '/a'), isNull);
      });

      test('finds shortest path in diamond', () {
        final terrain = buildDiamondTerrain();
        final path = terrain.shortestPath('/a', '/d');
        expect(path, hasLength(2)); // A→B→D or A→C→D (both length 2)
      });
    });

    group('graph queries', () {
      test('authProtectedScreens', () {
        final terrain = Terrain(
          outposts: {
            '/public': createOutpost('/public'),
            '/protected': createOutpost('/protected', requiresAuth: true),
            '/admin': createOutpost('/admin', requiresAuth: true),
          },
        );

        expect(terrain.authProtectedScreens, hasLength(2));
      });

      test('publicScreens', () {
        final terrain = Terrain(
          outposts: {
            '/public': createOutpost('/public'),
            '/protected': createOutpost('/protected', requiresAuth: true),
          },
        );

        expect(terrain.publicScreens, hasLength(1));
        expect(terrain.publicScreens.first.routePattern, '/public');
      });

      test('deadEnds returns screens with no exits', () {
        final terrain = buildLinearTerrain();
        final deadEnds = terrain.deadEnds;
        expect(deadEnds, hasLength(1));
        expect(deadEnds.first.routePattern, '/c');
      });

      test('entryPoints returns screens with no entrances', () {
        final terrain = buildLinearTerrain();
        final entries = terrain.entryPoints;
        expect(entries, hasLength(1));
        expect(entries.first.routePattern, '/a');
      });

      test('unreliableMarches returns transitions with < 2 observations', () {
        final terrain = Terrain();
        final a = createOutpost('/a');
        a.exits.add(
          March(
            fromRoute: '/a',
            toRoute: '/b',
            trigger: MarchTrigger.tap,
            observationCount: 1,
          ),
        );
        a.exits.add(
          March(
            fromRoute: '/a',
            toRoute: '/c',
            trigger: MarchTrigger.tap,
            observationCount: 5,
          ),
        );

        terrain.outposts['/a'] = a;
        terrain.outposts['/b'] = createOutpost('/b');
        terrain.outposts['/c'] = createOutpost('/c');

        expect(terrain.unreliableMarches, hasLength(1));
        expect(terrain.unreliableMarches.first.toRoute, '/b');
      });

      test('hasRoute checks for existence', () {
        final terrain = buildLinearTerrain();
        expect(terrain.hasRoute('/a'), true);
        expect(terrain.hasRoute('/unknown'), false);
      });
    });

    group('toAiMap', () {
      test('includes screen count and metadata', () {
        final terrain = buildLinearTerrain();
        terrain.sessionsAnalyzed = 5;
        final map = terrain.toAiMap();
        expect(map, contains('APP TERRAIN MAP'));
        expect(map, contains('Screens: 3'));
        expect(map, contains('Transitions: 2'));
        expect(map, contains('Sessions analyzed: 5'));
      });

      test('includes dead ends section', () {
        final terrain = buildLinearTerrain();
        final map = terrain.toAiMap();
        expect(map, contains('DEAD ENDS'));
        expect(map, contains('/c'));
      });

      test('includes unreliable transitions', () {
        final terrain = Terrain();
        final a = createOutpost('/a');
        a.exits.add(
          March(
            fromRoute: '/a',
            toRoute: '/b',
            trigger: MarchTrigger.tap,
            observationCount: 1,
          ),
        );
        terrain.outposts['/a'] = a;
        terrain.outposts['/b'] = createOutpost('/b');

        final map = terrain.toAiMap();
        expect(map, contains('UNRELIABLE'));
      });
    });

    group('toMermaid', () {
      test('generates valid Mermaid flowchart', () {
        final terrain = buildLinearTerrain();
        final mermaid = terrain.toMermaid();
        expect(mermaid, startsWith('graph TD'));
        expect(mermaid, contains('-->'));
      });

      test('marks auth-protected screens', () {
        final terrain = Terrain(
          outposts: {
            '/login': createOutpost('/login'),
            '/dashboard': createOutpost('/dashboard', requiresAuth: true),
          },
        );
        final a = terrain.outposts['/login']!;
        a.exits.add(
          March(
            fromRoute: '/login',
            toRoute: '/dashboard',
            trigger: MarchTrigger.formSubmit,
          ),
        );

        final mermaid = terrain.toMermaid();
        expect(mermaid, contains('🔒'));
      });

      test('includes edge labels', () {
        final terrain = Terrain();
        final a = createOutpost('/a');
        a.exits.add(
          March(
            fromRoute: '/a',
            toRoute: '/b',
            trigger: MarchTrigger.tap,
            triggerElementLabel: 'Next',
          ),
        );
        terrain.outposts['/a'] = a;
        terrain.outposts['/b'] = createOutpost('/b');

        final mermaid = terrain.toMermaid();
        expect(mermaid, contains('Next'));
      });
    });

    group('serialization', () {
      test('round-trips through JSON', () {
        final terrain = buildLinearTerrain();
        terrain.sessionsAnalyzed = 3;
        terrain.stratagemExecutionsAnalyzed = 2;

        final json = terrain.toJson();
        final restored = Terrain.fromJson(json);

        expect(restored.screenCount, terrain.screenCount);
        expect(restored.sessionsAnalyzed, terrain.sessionsAnalyzed);
        expect(
          restored.stratagemExecutionsAnalyzed,
          terrain.stratagemExecutionsAnalyzed,
        );
        expect(restored.outposts.keys, containsAll(terrain.outposts.keys));
      });

      test('JSON includes schema marker', () {
        final terrain = Terrain();
        final json = terrain.toJson();
        expect(json[r'$schema'], 'titan://terrain/v1');
      });

      test('toJsonString produces valid JSON string', () {
        final terrain = buildLinearTerrain();
        final jsonStr = terrain.toJsonString();
        expect(jsonStr, isNotEmpty);
        expect(jsonStr, contains('"outposts"'));
      });

      test('empty terrain round-trips cleanly', () {
        final terrain = Terrain();
        final json = terrain.toJson();
        final restored = Terrain.fromJson(json);
        expect(restored.screenCount, 0);
        expect(restored.sessionsAnalyzed, 0);
      });
    });

    group('reset', () {
      test('clears all state', () {
        final terrain = buildLinearTerrain();
        terrain.sessionsAnalyzed = 5;
        terrain.stratagemExecutionsAnalyzed = 3;

        terrain.reset();

        expect(terrain.outposts, isEmpty);
        expect(terrain.sessionsAnalyzed, 0);
        expect(terrain.stratagemExecutionsAnalyzed, 0);
      });

      test('reset invalidates cache', () {
        final terrain = buildLinearTerrain();

        // Prime the cache
        final marchesBefore = terrain.marches;
        expect(marchesBefore, isNotEmpty);

        terrain.reset();

        // After reset with empty outposts, caches should be cleared
        expect(terrain.marches, isEmpty);
        expect(terrain.deadEnds, isEmpty);
        expect(terrain.unreliableMarches, isEmpty);
      });
    });

    group('cache', () {
      test('marches returns same list instance on repeated calls', () {
        final terrain = buildLinearTerrain();
        final first = terrain.marches;
        final second = terrain.marches;
        expect(identical(first, second), isTrue);
      });

      test('deadEnds returns same list instance on repeated calls', () {
        final terrain = buildLinearTerrain();
        final first = terrain.deadEnds;
        final second = terrain.deadEnds;
        expect(identical(first, second), isTrue);
      });

      test('unreliableMarches returns same list on repeated calls', () {
        final terrain = buildLinearTerrain();
        final first = terrain.unreliableMarches;
        final second = terrain.unreliableMarches;
        expect(identical(first, second), isTrue);
      });

      test('invalidateCache clears all cached data', () {
        final terrain = buildLinearTerrain();

        // Prime all caches
        final marches1 = terrain.marches;
        final dead1 = terrain.deadEnds;
        final unreliable1 = terrain.unreliableMarches;

        terrain.invalidateCache();

        // New instances after invalidation
        final marches2 = terrain.marches;
        final dead2 = terrain.deadEnds;
        final unreliable2 = terrain.unreliableMarches;

        expect(identical(marches1, marches2), isFalse);
        expect(identical(dead1, dead2), isFalse);
        expect(identical(unreliable1, unreliable2), isFalse);

        // Same data though
        expect(marches2.length, marches1.length);
      });

      test('cached marches list is unmodifiable', () {
        final terrain = buildLinearTerrain();
        final marches = terrain.marches;
        expect(() => marches.add(marches.first), throwsUnsupportedError);
      });

      test('cached deadEnds list is unmodifiable', () {
        final terrain = buildLinearTerrain();
        final dead = terrain.deadEnds;
        if (dead.isNotEmpty) {
          expect(() => dead.add(dead.first), throwsUnsupportedError);
        }
        // Even empty should be unmodifiable
        final emptyTerrain = Terrain();
        final emptyDead = emptyTerrain.deadEnds;
        expect(emptyDead, isEmpty);
      });
    });

    group('toCompactJsonString', () {
      test('produces valid JSON identical to toJson', () {
        final terrain = buildLinearTerrain();
        final compact = terrain.toCompactJsonString();
        final prettyJson = terrain.toJson();
        final compactParsed = jsonDecode(compact) as Map<String, dynamic>;

        // Same keys
        expect(compactParsed.keys.toSet(), prettyJson.keys.toSet());
        expect(
          compactParsed['sessionsAnalyzed'],
          prettyJson['sessionsAnalyzed'],
        );
      });

      test('does not contain indentation', () {
        final terrain = buildLinearTerrain();
        final compact = terrain.toCompactJsonString();
        expect(compact, isNot(contains('\n  ')));
      });
    });

    test('toString includes summary', () {
      final terrain = buildLinearTerrain();
      terrain.sessionsAnalyzed = 2;
      final str = terrain.toString();
      expect(str, contains('3 screens'));
      expect(str, contains('2 transitions'));
      expect(str, contains('2 sessions'));
    });
  });
}
