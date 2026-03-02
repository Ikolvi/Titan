import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  late Decree decree;

  setUp(() {
    decree = Decree(
      sessionStart: DateTime(2025, 1, 15, 10, 0, 0),
      generatedAt: DateTime(2025, 1, 15, 10, 5, 30),
      totalFrames: 3000,
      jankFrames: 90,
      avgFps: 58.5,
      avgBuildTime: const Duration(microseconds: 4200),
      avgRasterTime: const Duration(microseconds: 3100),
      pageLoads: [
        PageLoadMark(
          path: '/home',
          duration: const Duration(milliseconds: 120),
          pattern: '/home',
          timestamp: DateTime(2025, 1, 15, 10, 0, 5),
        ),
        PageLoadMark(
          path: '/quest/42',
          duration: const Duration(milliseconds: 350),
          pattern: '/quest/:id',
          timestamp: DateTime(2025, 1, 15, 10, 1, 0),
        ),
        PageLoadMark(
          path: '/settings',
          duration: const Duration(milliseconds: 80),
          timestamp: DateTime(2025, 1, 15, 10, 3, 0),
        ),
      ],
      pillarCount: 12,
      totalInstances: 25,
      leakSuspects: [
        LeakSuspect(
          typeName: 'OldPillar',
          firstSeen: DateTime(2025, 1, 15, 9, 50, 0),
        ),
      ],
      rebuildsPerWidget: {
        'QuestCard': 45,
        'HeroAvatar': 12,
        'NavBar': 88,
        'Footer': 3,
      },
    );
  });

  group('Inscribe.markdown', () {
    test('includes header with health', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('# Colossus Performance Decree'));
      expect(md, contains('POOR'));
    });

    test('includes session info', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('2025-01-15'));
      expect(md, contains('330s'));
    });

    test('includes Pulse metrics', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('## Pulse'));
      expect(md, contains('58.5'));
      expect(md, contains('3000'));
      expect(md, contains('90'));
      expect(md, contains('4200'));
      expect(md, contains('3100'));
    });

    test('includes Stride metrics', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('## Stride'));
      expect(md, contains('/home'));
      expect(md, contains('/quest/42'));
      expect(md, contains('350ms'));
    });

    test('includes slowest page load', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('/quest/42'));
      expect(md, contains('350ms'));
    });

    test('includes Vessel metrics with leak suspects', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('## Vessel'));
      expect(md, contains('12'));
      expect(md, contains('25'));
      expect(md, contains('OldPillar'));
    });

    test('includes Echo rebuilds', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('## Echo'));
      expect(md, contains('NavBar'));
      expect(md, contains('88'));
      expect(md, contains('QuestCard'));
    });

    test('includes footer', () {
      final md = Inscribe.markdown(decree);
      expect(md, contains('Titan Performance Monitoring'));
    });

    test('handles empty decree', () {
      final empty = Decree(
        sessionStart: DateTime(2025, 1, 1),
        totalFrames: 0,
        jankFrames: 0,
        avgFps: 0,
        avgBuildTime: Duration.zero,
        avgRasterTime: Duration.zero,
        pageLoads: [],
        pillarCount: 0,
        totalInstances: 0,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );
      final md = Inscribe.markdown(empty);
      expect(md, contains('GOOD'));
      expect(md, isNotEmpty);
    });
  });

  group('Inscribe.json', () {
    test('produces valid JSON', () {
      final jsonStr = Inscribe.json(decree);
      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      expect(parsed, isA<Map<String, dynamic>>());
    });

    test('contains all top-level keys', () {
      final parsed = jsonDecode(Inscribe.json(decree)) as Map<String, dynamic>;
      expect(parsed, containsPair('health', 'poor'));
      expect(parsed, contains('sessionStart'));
      expect(parsed, contains('generatedAt'));
      expect(parsed, contains('durationSeconds'));
      expect(parsed, contains('pulse'));
      expect(parsed, contains('stride'));
      expect(parsed, contains('vessel'));
      expect(parsed, contains('echo'));
    });

    test('pulse section has correct values', () {
      final parsed = jsonDecode(Inscribe.json(decree)) as Map<String, dynamic>;
      final pulse = parsed['pulse'] as Map<String, dynamic>;
      expect(pulse['totalFrames'], 3000);
      expect(pulse['jankFrames'], 90);
      expect(pulse['avgFps'], 58.5);
      expect(pulse['avgBuildTimeUs'], 4200);
      expect(pulse['avgRasterTimeUs'], 3100);
    });

    test('stride section includes page loads', () {
      final parsed = jsonDecode(Inscribe.json(decree)) as Map<String, dynamic>;
      final stride = parsed['stride'] as Map<String, dynamic>;
      expect(stride['totalPageLoads'], 3);
      final loads = stride['pageLoads'] as List;
      expect(loads.length, 3);
    });

    test('vessel section includes leak suspects', () {
      final parsed = jsonDecode(Inscribe.json(decree)) as Map<String, dynamic>;
      final vessel = parsed['vessel'] as Map<String, dynamic>;
      expect(vessel['pillarCount'], 12);
      expect(vessel['totalInstances'], 25);
      final suspects = vessel['leakSuspects'] as List;
      expect(suspects.length, 1);
      expect(suspects.first['typeName'], 'OldPillar');
    });

    test('echo section includes rebuilds', () {
      final parsed = jsonDecode(Inscribe.json(decree)) as Map<String, dynamic>;
      final echo = parsed['echo'] as Map<String, dynamic>;
      expect(echo['totalRebuilds'], 148);
      final rebuilds = echo['rebuildsPerWidget'] as Map<String, dynamic>;
      expect(rebuilds['NavBar'], 88);
    });

    test('is compact JSON', () {
      final jsonStr = Inscribe.json(decree);
      // Compact encoding — no newlines for minimal size
      expect(jsonStr, isNot(contains('\n')));
      // Valid JSON that can be decoded
      expect(() => jsonDecode(jsonStr), returnsNormally);
    });
  });

  group('Inscribe.html', () {
    test('produces valid HTML document', () {
      final html = Inscribe.html(decree);
      expect(html, contains('<!DOCTYPE html>'));
      expect(html, contains('<html'));
      expect(html, contains('</html>'));
      expect(html, contains('<head>'));
      expect(html, contains('<body>'));
    });

    test('includes embedded CSS', () {
      final html = Inscribe.html(decree);
      expect(html, contains('<style>'));
      expect(html, contains('</style>'));
      expect(html, contains('.card'));
      expect(html, contains('.health-badge'));
    });

    test('includes health badge with correct color', () {
      final html = Inscribe.html(decree);
      // POOR → red (leakSuspects not empty)
      expect(html, contains('#ef4444'));
      expect(html, contains('POOR'));
    });

    test('includes Pulse section', () {
      final html = Inscribe.html(decree);
      expect(html, contains('Pulse'));
      expect(html, contains('58.5'));
      expect(html, contains('Jank Rate'));
    });

    test('includes jank bar visualization', () {
      final html = Inscribe.html(decree);
      expect(html, contains('bar-fill'));
      expect(html, contains('width:'));
    });

    test('includes Stride page loads', () {
      final html = Inscribe.html(decree);
      expect(html, contains('Stride'));
      expect(html, contains('/home'));
      expect(html, contains('/quest/42'));
    });

    test('includes Vessel leak alerts', () {
      final html = Inscribe.html(decree);
      expect(html, contains('Vessel'));
      expect(html, contains('OldPillar'));
      expect(html, contains('alert-item'));
    });

    test('includes Echo rebuilds table', () {
      final html = Inscribe.html(decree);
      expect(html, contains('Echo'));
      expect(html, contains('NavBar'));
      expect(html, contains('88'));
    });

    test('escapes HTML entities', () {
      final decreeWithSpecialChars = Decree(
        sessionStart: DateTime(2025, 1, 1),
        totalFrames: 0,
        jankFrames: 0,
        avgFps: 0,
        avgBuildTime: Duration.zero,
        avgRasterTime: Duration.zero,
        pageLoads: [
          PageLoadMark(
            path: '/page?a=1&b=2',
            duration: const Duration(milliseconds: 100),
          ),
        ],
        pillarCount: 0,
        totalInstances: 0,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );
      final html = Inscribe.html(decreeWithSpecialChars);
      expect(html, contains('&amp;'));
    });

    test('is self-contained (no external deps)', () {
      final html = Inscribe.html(decree);
      // No link or script tags referencing external resources
      expect(html, isNot(contains('href="http')));
      expect(html, isNot(contains('src="http')));
    });

    test('includes footer', () {
      final html = Inscribe.html(decree);
      expect(html, contains('Colossus'));
      expect(html, contains('Titan Performance Monitoring'));
    });

    test('good health shows green', () {
      final good = Decree(
        sessionStart: DateTime(2025, 1, 1),
        totalFrames: 1000,
        jankFrames: 10,
        avgFps: 60,
        avgBuildTime: const Duration(microseconds: 2000),
        avgRasterTime: const Duration(microseconds: 1500),
        pageLoads: [],
        pillarCount: 5,
        totalInstances: 10,
        leakSuspects: [],
        rebuildsPerWidget: {},
      );
      final html = Inscribe.html(good);
      expect(html, contains('#22c55e')); // green
      expect(html, contains('GOOD'));
    });

    test('poor health shows red', () {
      final poor = Decree(
        sessionStart: DateTime(2025, 1, 1),
        totalFrames: 100,
        jankFrames: 20,
        avgFps: 30,
        avgBuildTime: const Duration(microseconds: 20000),
        avgRasterTime: const Duration(microseconds: 15000),
        pageLoads: [],
        pillarCount: 50,
        totalInstances: 100,
        leakSuspects: [
          LeakSuspect(typeName: 'LeakyPillar', firstSeen: DateTime(2025, 1, 1)),
        ],
        rebuildsPerWidget: {},
      );
      final html = Inscribe.html(poor);
      expect(html, contains('#ef4444')); // red
      expect(html, contains('POOR'));
    });
  });

  group('Decree.toMap', () {
    test('produces correct structure', () {
      final map = decree.toMap();
      expect(map['health'], 'poor');
      expect(map['durationSeconds'], 330);
      expect(map['pulse'], isA<Map<String, dynamic>>());
      expect(map['stride'], isA<Map<String, dynamic>>());
      expect(map['vessel'], isA<Map<String, dynamic>>());
      expect(map['echo'], isA<Map<String, dynamic>>());
    });

    test('pulse values are correct', () {
      final pulse = decree.toMap()['pulse'] as Map<String, dynamic>;
      expect(pulse['totalFrames'], 3000);
      expect(pulse['jankFrames'], 90);
    });

    test('stride includes slowest page load', () {
      final stride = decree.toMap()['stride'] as Map<String, dynamic>;
      expect(stride, contains('slowestPageLoad'));
    });
  });

  group('Mark.toMap', () {
    test('Mark base toMap', () {
      final mark = Mark(
        name: 'test',
        category: MarkCategory.custom,
        duration: const Duration(milliseconds: 100),
        timestamp: DateTime(2025, 1, 1),
      );
      final map = mark.toMap();
      expect(map['name'], 'test');
      expect(map['category'], 'custom');
      expect(map['durationUs'], 100000);
      expect(map['timestamp'], contains('2025'));
    });

    test('FrameMark toMap includes frame data', () {
      final frame = FrameMark(
        buildDuration: const Duration(microseconds: 4000),
        rasterDuration: const Duration(microseconds: 3000),
        totalDuration: const Duration(microseconds: 7000),
      );
      final map = frame.toMap();
      expect(map['buildDurationUs'], 4000);
      expect(map['rasterDurationUs'], 3000);
      expect(map['totalDurationUs'], 7000);
      expect(map['isJank'], false);
    });

    test('PageLoadMark toMap includes path', () {
      final load = PageLoadMark(
        path: '/test',
        duration: const Duration(milliseconds: 200),
        pattern: '/test',
      );
      final map = load.toMap();
      expect(map['path'], '/test');
      expect(map['pattern'], '/test');
      expect(map['durationMs'], 200);
    });

    test('MemoryMark toMap includes memory data', () {
      final mem = MemoryMark(
        pillarCount: 10,
        totalInstances: 20,
        leakSuspects: ['LeakyType'],
      );
      final map = mem.toMap();
      expect(map['pillarCount'], 10);
      expect(map['totalInstances'], 20);
    });

    test('LeakSuspect toMap', () {
      final suspect = LeakSuspect(
        typeName: 'TestPillar',
        firstSeen: DateTime(2025, 1, 1),
      );
      final map = suspect.toMap();
      expect(map['typeName'], 'TestPillar');
      expect(map['firstSeen'], contains('2025'));
      expect(map['ageSeconds'], isA<int>());
    });
  });
}
