import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EnvoyLensTab', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    test('has correct title and icon', () {
      final tab = EnvoyLensTab(colossus);
      expect(tab.title, 'Envoy');
      expect(tab.icon, Icons.http);
    });

    test('implements LensPlugin', () {
      final tab = EnvoyLensTab(colossus);
      expect(tab, isA<LensPlugin>());
    });

    testWidgets('renders empty traffic state', (tester) async {
      final tab = EnvoyLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('No HTTP traffic recorded.'), findsOneWidget);
    });

    testWidgets('renders request cards in traffic tab', (tester) async {
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/users',
        'statusCode': 200,
        'durationMs': 142,
        'success': true,
        'cached': false,
        'timestamp': '2025-01-15T10:30:00Z',
        'responseSize': 2048,
      });
      colossus.trackApiMetric({
        'method': 'POST',
        'url': 'https://api.example.com/orders',
        'statusCode': 201,
        'durationMs': 320,
        'success': true,
        'cached': false,
        'timestamp': '2025-01-15T10:30:05Z',
      });

      final tab = EnvoyLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      // Method badges
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('POST'), findsOneWidget);

      // Status codes
      expect(find.text('200'), findsOneWidget);
      expect(find.text('201'), findsOneWidget);

      // Durations
      expect(find.text('142ms'), findsOneWidget);
      expect(find.text('320ms'), findsOneWidget);
    });

    testWidgets('shows cached badge for cached responses', (tester) async {
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/cached',
        'statusCode': 200,
        'durationMs': 5,
        'success': true,
        'cached': true,
        'timestamp': '2025-01-15T10:30:00Z',
      });

      final tab = EnvoyLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      expect(find.text('CACHED'), findsOneWidget);
    });

    testWidgets('stats tab shows aggregate metrics', (tester) async {
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/a',
        'statusCode': 200,
        'durationMs': 100,
        'success': true,
        'cached': false,
        'responseSize': 1024,
        'timestamp': '2025-01-15T10:30:00Z',
      });
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/b',
        'statusCode': 500,
        'durationMs': 300,
        'success': false,
        'error': 'Internal error',
        'cached': false,
        'responseSize': 128,
        'timestamp': '2025-01-15T10:30:01Z',
      });

      final tab = EnvoyLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      // Navigate to Stats tab
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();

      // Overview section
      expect(find.text('Total requests'), findsOneWidget);
      expect(find.text('OVERVIEW'), findsOneWidget);

      // Latency section
      expect(find.text('LATENCY'), findsOneWidget);
      expect(find.text('Average'), findsOneWidget);

      // Status codes section
      expect(find.text('STATUS CODES'), findsOneWidget);
    });

    testWidgets('errors tab shows failed requests', (tester) async {
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/ok',
        'statusCode': 200,
        'durationMs': 100,
        'success': true,
        'timestamp': '2025-01-15T10:30:00Z',
      });
      colossus.trackApiMetric({
        'method': 'POST',
        'url': 'https://api.example.com/fail',
        'statusCode': 503,
        'durationMs': 5000,
        'success': false,
        'error': 'Service unavailable',
        'timestamp': '2025-01-15T10:30:01Z',
      });

      final tab = EnvoyLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      // Navigate to Errors tab
      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Service unavailable'), findsOneWidget);
      // Should show method badge for the failed request
      expect(find.text('POST'), findsOneWidget);
      // Should NOT show the successful GET (only errors)
      expect(find.text('GET'), findsNothing);
    });

    testWidgets('errors tab shows empty state when no errors', (tester) async {
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/ok',
        'statusCode': 200,
        'durationMs': 100,
        'success': true,
        'timestamp': '2025-01-15T10:30:00Z',
      });

      final tab = EnvoyLensTab(colossus);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Material(
              child: SizedBox(
                width: 400,
                height: 600,
                child: Builder(builder: (context) => tab.build(context)),
              ),
            ),
          ),
        ),
      );

      // Navigate to Errors tab
      await tester.tap(find.text('Errors'));
      await tester.pumpAndSettle();

      expect(find.text('No errors recorded.'), findsOneWidget);
    });

    test('can be registered and unregistered with Lens', () {
      final tab = EnvoyLensTab(colossus);
      Lens.registerPlugin(tab);
      expect(Lens.plugins, contains(tab));

      Lens.unregisterPlugin(tab);
      expect(Lens.plugins, isNot(contains(tab)));
    });

    test('Colossus.init registers EnvoyLensTab when enableLensTab true', () {
      Colossus.shutdown();
      Colossus.init(enableLensTab: true);

      final envoyTabs = Lens.plugins.whereType<EnvoyLensTab>().toList();
      expect(envoyTabs, hasLength(1));
    });

    test('Colossus.shutdown unregisters EnvoyLensTab', () {
      Colossus.shutdown();
      Colossus.init(enableLensTab: true);

      expect(Lens.plugins.whereType<EnvoyLensTab>(), isNotEmpty);

      Colossus.shutdown();
      expect(Lens.plugins.whereType<EnvoyLensTab>(), isEmpty);
    });
  });
}
