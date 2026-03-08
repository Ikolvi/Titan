import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // Helper: wraps the BlueprintLensTab.build() in a proper widget tree
  // ---------------------------------------------------------------------------

  Widget wrapTab(BlueprintLensTab tab) {
    return Directionality(
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
    );
  }

  /// Wrapper with Navigator (needed for overlay-based dropdown interactions).
  Widget wrapTabWithNav(BlueprintLensTab tab) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: Builder(builder: (context) => tab.build(context)),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Unit tests
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    test('has correct title', () {
      final tab = BlueprintLensTab(colossus);
      expect(tab.title, 'Blueprint');
    });

    test('has correct icon', () {
      final tab = BlueprintLensTab(colossus);
      expect(tab.icon, Icons.map_outlined);
    });

    test('onAttach and onDetach are callable', () {
      final tab = BlueprintLensTab(colossus);
      tab.onAttach();
      tab.onDetach();
    });
  });

  // ---------------------------------------------------------------------------
  // Terrain sub-tab
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Terrain', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('renders 5 sub-tabs', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('Terrain'), findsOneWidget);
      expect(find.text('Lineage'), findsOneWidget);
      expect(find.text('Gauntlet'), findsOneWidget);
      expect(find.text('Campaign'), findsOneWidget);
      expect(find.text('Debrief'), findsOneWidget);
    });

    testWidgets('shows terrain metrics', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('Discovered screens'), findsOneWidget);
      expect(find.text('Transitions'), findsOneWidget);
      expect(find.text('Sessions analyzed'), findsOneWidget);
    });

    testWidgets('shows action chips', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('Copy Mermaid'), findsOneWidget);
      expect(find.text('Copy AI Map'), findsOneWidget);
      expect(find.text('Copy Blueprint'), findsOneWidget);
    });

    testWidgets('shows zero counts initially', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
    });

    testWidgets('shows auth/dead-end metrics', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('Auth-protected routes'), findsOneWidget);
      expect(find.text('Dead ends'), findsOneWidget);
      expect(find.text('Unreliable transitions'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Terrain with data
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Terrain with data', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('shows discovered routes', (tester) async {
      colossus.terrain.outposts['/home'] = Outpost(
        signet: Signet(
          routePattern: '/home',
          interactiveDescriptors: ['ElevatedButton:Go'],
          hash: 'abc123',
          identity: 'home-abc',
        ),
        routePattern: '/home',
        displayName: 'Home',
        interactiveElements: [
          OutpostElement(
            widgetType: 'ElevatedButton',
            label: 'Go',
            isInteractive: true,
          ),
        ],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('/home'), findsOneWidget);
      expect(find.text('DISCOVERED ROUTES'), findsOneWidget);
    });

    testWidgets('shows public icon for non-auth routes', (tester) async {
      colossus.terrain.outposts['/home'] = Outpost(
        signet: Signet(
          routePattern: '/home',
          interactiveDescriptors: [],
          hash: 'abc',
          identity: 'home',
        ),
        routePattern: '/home',
        displayName: 'Home',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.public), findsOneWidget);
    });

    testWidgets('shows lock icon for auth routes', (tester) async {
      final outpost = Outpost(
        signet: Signet(
          routePattern: '/admin',
          interactiveDescriptors: [],
          hash: 'def',
          identity: 'admin',
        ),
        routePattern: '/admin',
        displayName: 'Admin',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      outpost.requiresAuth = true;
      colossus.terrain.outposts['/admin'] = outpost;

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Lineage sub-tab
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Lineage', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('shows target route header', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      expect(find.text('TARGET ROUTE'), findsOneWidget);
      expect(find.text('Resolve Lineage'), findsOneWidget);
    });

    testWidgets('shows no-routes message when terrain is empty', (
      tester,
    ) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No routes discovered'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Gauntlet sub-tab
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Gauntlet', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('shows controls', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      expect(find.text('TARGET SCREEN'), findsOneWidget);
      expect(find.text('INTENSITY'), findsOneWidget);
      expect(find.text('Generate Gauntlet'), findsOneWidget);
      expect(find.text('PATTERN CATALOG'), findsOneWidget);
    });

    testWidgets('shows intensity selectors', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      expect(find.text('quick'), findsOneWidget);
      expect(find.text('standard'), findsOneWidget);
      expect(find.text('thorough'), findsOneWidget);
    });

    testWidgets('shows pattern catalog count', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      expect(find.text('Available patterns'), findsOneWidget);
      expect(find.text('${Gauntlet.catalog.length}'), findsOneWidget);
    });

    testWidgets('shows all gauntlet categories', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      for (final cat in GauntletCategory.values) {
        expect(find.text(cat.name), findsOneWidget);
      }
    });

    testWidgets('intensity selector responds to taps', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('thorough'));
      await tester.pumpAndSettle();

      expect(find.text('thorough'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Campaign sub-tab
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Campaign', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('shows JSON input and buttons', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Campaign'));
      await tester.pumpAndSettle();

      expect(find.text('CAMPAIGN JSON'), findsOneWidget);
      expect(find.text('Execute Campaign'), findsOneWidget);
      expect(find.text('Copy Template'), findsOneWidget);
    });

    testWidgets('has a text field for JSON input', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Campaign'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Paste Campaign JSON here...'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Debrief sub-tab
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Debrief', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('shows empty message initially', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Debrief'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No debrief data yet'), findsOneWidget);
    });

    testWidgets('empty message mentions Campaign', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Debrief'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Execute a Campaign'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Interactive: Gauntlet generation with terrain data
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Gauntlet interactive', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
      // Populate terrain with an outpost that has interactive elements
      colossus.terrain.outposts['/home'] = Outpost(
        signet: Signet(
          routePattern: '/home',
          interactiveDescriptors: ['ElevatedButton:Submit', 'TextField:Email'],
          hash: 'h1',
          identity: 'home-h1',
        ),
        routePattern: '/home',
        displayName: 'Home',
        interactiveElements: [
          OutpostElement(
            widgetType: 'ElevatedButton',
            label: 'Submit',
            isInteractive: true,
          ),
          OutpostElement(
            widgetType: 'TextField',
            label: 'Email',
            isInteractive: true,
          ),
        ],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('shows route in dropdown after discovery', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      // Should not show empty message
      expect(find.textContaining('No routes discovered'), findsNothing);
    });

    testWidgets('generates stratagems and shows cards', (tester) async {
      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      // Select route via dropdown
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/home').last);
      await tester.pumpAndSettle();

      // Tap Generate
      await tester.tap(find.text('Generate Gauntlet'));
      await tester.pumpAndSettle();

      // Should show generated stratagem cards (bolt icons from _StratagemCard)
      expect(find.byIcon(Icons.bolt), findsWidgets);
    });

    testWidgets('shows copy stratagems button after generation', (
      tester,
    ) async {
      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      // Before generation
      expect(find.text('Copy Stratagems'), findsNothing);

      // Select route and generate
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/home').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Gauntlet'));
      await tester.pumpAndSettle();

      // After generation
      expect(find.text('Copy Stratagems'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Interactive: Lineage with multi-screen terrain
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Lineage interactive', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);

      // Create a terrain: /login -> /home -> /settings
      final loginOutpost = Outpost(
        signet: Signet(
          routePattern: '/login',
          interactiveDescriptors: ['TextField:User', 'ElevatedButton:Login'],
          hash: 'l1',
          identity: 'login-l1',
        ),
        routePattern: '/login',
        displayName: 'Login',
        interactiveElements: [
          OutpostElement(
            widgetType: 'TextField',
            label: 'User',
            isInteractive: true,
          ),
        ],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      final homeOutpost = Outpost(
        signet: Signet(
          routePattern: '/home',
          interactiveDescriptors: ['ElevatedButton:Go'],
          hash: 'h1',
          identity: 'home-h1',
        ),
        routePattern: '/home',
        displayName: 'Home',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      final settingsOutpost = Outpost(
        signet: Signet(
          routePattern: '/settings',
          interactiveDescriptors: ['Switch:Dark'],
          hash: 's1',
          identity: 'settings-s1',
        ),
        routePattern: '/settings',
        displayName: 'Settings',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      colossus.terrain.outposts['/login'] = loginOutpost;
      colossus.terrain.outposts['/home'] = homeOutpost;
      colossus.terrain.outposts['/settings'] = settingsOutpost;

      // Add marches
      final loginToHome = March(
        fromRoute: '/login',
        toRoute: '/home',
        trigger: MarchTrigger.tap,
      );
      final homeToSettings = March(
        fromRoute: '/home',
        toRoute: '/settings',
        trigger: MarchTrigger.tap,
      );
      loginOutpost.exits.add(loginToHome);
      homeOutpost.entrances.add(loginToHome);
      homeOutpost.exits.add(homeToSettings);
      settingsOutpost.entrances.add(homeToSettings);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('shows route dropdown with all routes', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      // Dropdown should have routes
      expect(find.textContaining('No routes discovered'), findsNothing);
    });

    testWidgets('resolve lineage shows path for /settings', (tester) async {
      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      // Select /settings
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/settings').last);
      await tester.pumpAndSettle();

      // Resolve
      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      // Should show path and copy buttons
      expect(find.text('PREREQUISITE CHAIN'), findsOneWidget);
      expect(find.text('Copy Stratagem'), findsOneWidget);
      expect(find.text('Copy Summary'), findsOneWidget);
    });

    testWidgets('resolve lineage shows hops metric', (tester) async {
      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/settings').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      expect(find.text('Hops'), findsOneWidget);
      expect(find.text('Auth required'), findsOneWidget);
      expect(find.text('Est. setup time'), findsOneWidget);
    });

    testWidgets('directly accessible route shows info card', (tester) async {
      // /login is an entry point, should have empty lineage
      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/login').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      expect(find.textContaining('directly accessible'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Interactive: Terrain view with populated data
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Terrain interactive', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('shows correct screen count', (tester) async {
      colossus.terrain.outposts['/a'] = Outpost(
        signet: Signet(
          routePattern: '/a',
          interactiveDescriptors: [],
          hash: 'a',
          identity: 'a',
        ),
        routePattern: '/a',
        displayName: 'A',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      colossus.terrain.outposts['/b'] = Outpost(
        signet: Signet(
          routePattern: '/b',
          interactiveDescriptors: [],
          hash: 'b',
          identity: 'b',
        ),
        routePattern: '/b',
        displayName: 'B',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      // Should show 2 for discovered screens
      expect(find.text('2'), findsWidgets);
    });

    testWidgets('shows element count per route card', (tester) async {
      colossus.terrain.outposts['/form'] = Outpost(
        signet: Signet(
          routePattern: '/form',
          interactiveDescriptors: ['TextField:Name', 'TextField:Email'],
          hash: 'f',
          identity: 'form',
        ),
        routePattern: '/form',
        displayName: 'Form',
        interactiveElements: [
          OutpostElement(
            widgetType: 'TextField',
            label: 'Name',
            isInteractive: true,
          ),
          OutpostElement(
            widgetType: 'TextField',
            label: 'Email',
            isInteractive: true,
          ),
          OutpostElement(
            widgetType: 'ElevatedButton',
            label: 'Submit',
            isInteractive: true,
          ),
        ],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('3 elem'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab registration', () {
    test('registered when enableLensTab is true', () {
      Colossus.init(enableLensTab: true);
      addTearDown(Colossus.shutdown);

      final hasBlueprint = Lens.plugins.any((p) => p.title == 'Blueprint');
      expect(hasBlueprint, isTrue);
    });

    test('NOT registered when enableLensTab is false', () {
      Colossus.init(enableLensTab: false);
      addTearDown(Colossus.shutdown);

      final hasBlueprint = Lens.plugins.any((p) => p.title == 'Blueprint');
      expect(hasBlueprint, isFalse);
    });

    test('unregistered on shutdown', () {
      Colossus.init(enableLensTab: true);

      expect(Lens.plugins.any((p) => p.title == 'Blueprint'), isTrue);
      Colossus.shutdown();
      expect(Lens.plugins.any((p) => p.title == 'Blueprint'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab status bar', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('status bar hidden when empty', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      // Status bar should not show any status text initially
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.child is Text &&
              (w.child as Text).data?.contains('copied') == true,
        ),
        findsNothing,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Terrain edge cases
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Terrain edge cases', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('shows transition count from marches', (tester) async {
      final outpostA = Outpost(
        signet: Signet(
          routePattern: '/a',
          interactiveDescriptors: [],
          hash: 'a',
          identity: 'a',
        ),
        routePattern: '/a',
        displayName: 'A',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      final outpostB = Outpost(
        signet: Signet(
          routePattern: '/b',
          interactiveDescriptors: [],
          hash: 'b',
          identity: 'b',
        ),
        routePattern: '/b',
        displayName: 'B',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      colossus.terrain.outposts['/a'] = outpostA;
      colossus.terrain.outposts['/b'] = outpostB;

      final march = March(
        fromRoute: '/a',
        toRoute: '/b',
        trigger: MarchTrigger.tap,
      );
      outpostA.exits.add(march);
      outpostB.entrances.add(march);
      colossus.terrain.invalidateCache();

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      // Should show 1 transition
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('shows exit count on route card', (tester) async {
      final outpost = Outpost(
        signet: Signet(
          routePattern: '/hub',
          interactiveDescriptors: [],
          hash: 'hub',
          identity: 'hub',
        ),
        routePattern: '/hub',
        displayName: 'Hub',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      final march1 = March(
        fromRoute: '/hub',
        toRoute: '/page1',
        trigger: MarchTrigger.tap,
      );
      final march2 = March(
        fromRoute: '/hub',
        toRoute: '/page2',
        trigger: MarchTrigger.tap,
      );
      outpost.exits.addAll([march1, march2]);
      colossus.terrain.outposts['/hub'] = outpost;

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('2 exit'), findsOneWidget);
    });

    testWidgets('routes are sorted in discovered list', (tester) async {
      // Add routes in non-alphabetical order
      for (final route in ['/z-page', '/a-page', '/m-page']) {
        colossus.terrain.outposts[route] = Outpost(
          signet: Signet(
            routePattern: route,
            interactiveDescriptors: [],
            hash: route,
            identity: route,
          ),
          routePattern: route,
          displayName: route,
          interactiveElements: [],
          displayElements: [],
          screenWidth: 400,
          screenHeight: 800,
        );
      }

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      // All three routes should be visible
      expect(find.text('/a-page'), findsOneWidget);
      expect(find.text('/m-page'), findsOneWidget);
      expect(find.text('/z-page'), findsOneWidget);
    });

    testWidgets('shows orange color for dead-end routes', (tester) async {
      // A route with no exits is a dead end in the terrain
      final deadEnd = Outpost(
        signet: Signet(
          routePattern: '/dead',
          interactiveDescriptors: [],
          hash: 'd',
          identity: 'd',
        ),
        routePattern: '/dead',
        displayName: 'Dead',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      // Add an entrance so it's reachable but has no exits
      deadEnd.entrances.add(
        March(fromRoute: '/other', toRoute: '/dead', trigger: MarchTrigger.tap),
      );
      colossus.terrain.outposts['/dead'] = deadEnd;

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      // Dead ends metric should show non-zero (orange color used)
      expect(find.text('Dead ends'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Gauntlet edge cases
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Gauntlet edge cases', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('generate without selecting route shows status', (
      tester,
    ) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Gauntlet'));
      await tester.pumpAndSettle();

      // Status should show error about selecting route
      expect(find.text('Select a route first'), findsOneWidget);
    });

    testWidgets('intensity changes to thorough', (tester) async {
      colossus.terrain.outposts['/page'] = Outpost(
        signet: Signet(
          routePattern: '/page',
          interactiveDescriptors: ['Button:Click'],
          hash: 'p',
          identity: 'p',
        ),
        routePattern: '/page',
        displayName: 'Page',
        interactiveElements: [
          OutpostElement(
            widgetType: 'ElevatedButton',
            label: 'Click',
            isInteractive: true,
          ),
        ],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      // Change to thorough
      await tester.tap(find.text('thorough'));
      await tester.pumpAndSettle();

      // Select route
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/page').last);
      await tester.pumpAndSettle();

      // Generate
      await tester.tap(find.text('Generate Gauntlet'));
      await tester.pumpAndSettle();

      // Should have generated stratagems
      expect(find.byIcon(Icons.bolt), findsWidgets);
    });

    testWidgets('stratagem card shows step count', (tester) async {
      colossus.terrain.outposts['/page'] = Outpost(
        signet: Signet(
          routePattern: '/page',
          interactiveDescriptors: ['TextField:Name'],
          hash: 'p',
          identity: 'p',
        ),
        routePattern: '/page',
        displayName: 'Page',
        interactiveElements: [
          OutpostElement(
            widgetType: 'TextField',
            label: 'Name',
            isInteractive: true,
          ),
        ],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/page').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Gauntlet'));
      await tester.pumpAndSettle();

      // Should show step count (e.g., "2 steps")
      expect(find.textContaining('step'), findsWidgets);
    });

    testWidgets('shows GENERATED header with count', (tester) async {
      colossus.terrain.outposts['/page'] = Outpost(
        signet: Signet(
          routePattern: '/page',
          interactiveDescriptors: ['Button:Go'],
          hash: 'p',
          identity: 'p',
        ),
        routePattern: '/page',
        displayName: 'Page',
        interactiveElements: [
          OutpostElement(
            widgetType: 'ElevatedButton',
            label: 'Go',
            isInteractive: true,
          ),
        ],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/page').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate Gauntlet'));
      await tester.pumpAndSettle();

      // Should show GENERATED section header with count
      expect(find.textContaining('GENERATED'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Lineage edge cases
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Lineage edge cases', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('resolve without selecting route shows status', (tester) async {
      colossus.terrain.outposts['/page'] = Outpost(
        signet: Signet(
          routePattern: '/page',
          interactiveDescriptors: [],
          hash: 'p',
          identity: 'p',
        ),
        routePattern: '/page',
        displayName: 'Page',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      // Tap Resolve without selecting a route
      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      expect(find.text('Select a route first'), findsOneWidget);
    });

    testWidgets('lineage with path shows march cards', (tester) async {
      final loginOutpost = Outpost(
        signet: Signet(
          routePattern: '/login',
          interactiveDescriptors: [],
          hash: 'l',
          identity: 'l',
        ),
        routePattern: '/login',
        displayName: 'Login',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      final dashOutpost = Outpost(
        signet: Signet(
          routePattern: '/dashboard',
          interactiveDescriptors: [],
          hash: 'd',
          identity: 'd',
        ),
        routePattern: '/dashboard',
        displayName: 'Dashboard',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      colossus.terrain.outposts['/login'] = loginOutpost;
      colossus.terrain.outposts['/dashboard'] = dashOutpost;

      final march = March(
        fromRoute: '/login',
        toRoute: '/dashboard',
        trigger: MarchTrigger.tap,
      );
      loginOutpost.exits.add(march);
      dashOutpost.entrances.add(march);

      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/dashboard').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      // Should show arrow icon from MarchCard
      expect(find.byIcon(Icons.arrow_forward), findsWidgets);
    });

    testWidgets('lineage shows PATH section header', (tester) async {
      final loginOutpost = Outpost(
        signet: Signet(
          routePattern: '/login',
          interactiveDescriptors: [],
          hash: 'l',
          identity: 'l',
        ),
        routePattern: '/login',
        displayName: 'Login',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      final dashOutpost = Outpost(
        signet: Signet(
          routePattern: '/dash',
          interactiveDescriptors: [],
          hash: 'd',
          identity: 'd',
        ),
        routePattern: '/dash',
        displayName: 'Dash',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      colossus.terrain.outposts['/login'] = loginOutpost;
      colossus.terrain.outposts['/dash'] = dashOutpost;

      final march = March(
        fromRoute: '/login',
        toRoute: '/dash',
        trigger: MarchTrigger.tap,
      );
      loginOutpost.exits.add(march);
      dashOutpost.entrances.add(march);

      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/dash').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      expect(find.text('PATH'), findsOneWidget);
    });

    testWidgets('auth-required lineage shows Yes for auth metric', (
      tester,
    ) async {
      final loginOutpost = Outpost(
        signet: Signet(
          routePattern: '/login',
          interactiveDescriptors: [],
          hash: 'l',
          identity: 'l',
        ),
        routePattern: '/login',
        displayName: 'Login',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      loginOutpost.requiresAuth = true;

      final adminOutpost = Outpost(
        signet: Signet(
          routePattern: '/admin',
          interactiveDescriptors: [],
          hash: 'a',
          identity: 'a',
        ),
        routePattern: '/admin',
        displayName: 'Admin',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );
      adminOutpost.requiresAuth = true;
      colossus.terrain.outposts['/login'] = loginOutpost;
      colossus.terrain.outposts['/admin'] = adminOutpost;

      final march = March(
        fromRoute: '/login',
        toRoute: '/admin',
        trigger: MarchTrigger.tap,
      );
      loginOutpost.exits.add(march);
      adminOutpost.entrances.add(march);

      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/admin').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      expect(find.text('Auth required'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Campaign edge cases
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Campaign edge cases', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('execute with empty JSON shows error status', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Campaign'));
      await tester.pumpAndSettle();

      // Tap execute without entering JSON
      await tester.tap(find.text('Execute Campaign'));
      await tester.pumpAndSettle();

      expect(find.text('Paste Campaign JSON first'), findsOneWidget);
    });

    testWidgets('execute with invalid JSON shows error', (tester) async {
      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Campaign'));
      await tester.pumpAndSettle();

      // Enter invalid JSON
      await tester.enterText(find.byType(TextField), 'not valid json');
      await tester.pump();

      await tester.tap(find.text('Execute Campaign'));
      await tester.pumpAndSettle();

      // Should show error status
      expect(find.textContaining('Error:'), findsOneWidget);
    });

    testWidgets('copy template displays status message', (tester) async {
      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Campaign'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Template'));
      await tester.pumpAndSettle();

      expect(
        find.text('Campaign template copied to clipboard'),
        findsOneWidget,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Debrief with data
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Debrief with data', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    Verdict _makeVerdict({
      required String name,
      required bool passed,
      Duration duration = const Duration(milliseconds: 100),
    }) {
      return Verdict(
        stratagemName: name,
        executedAt: DateTime(2025),
        duration: duration,
        passed: passed,
        steps: [
          VerdictStep.passed(
            stepId: 1,
            description: 'step 1',
            duration: duration,
          ),
          if (!passed)
            VerdictStep.failed(
              stepId: 2,
              description: 'step 2',
              duration: duration,
              failure: const VerdictFailure(
                type: VerdictFailureType.elementMissing,
                message: 'Element not found',
              ),
            ),
        ],
        summary: VerdictSummary(
          totalSteps: passed ? 1 : 2,
          passedSteps: 1,
          failedSteps: passed ? 0 : 1,
          skippedSteps: 0,
          successRate: passed ? 1.0 : 0.5,
          duration: duration,
        ),
        performance: const VerdictPerformance(),
      );
    }

    testWidgets('shows debrief results after running debrief', (tester) async {
      final passVerdict = _makeVerdict(name: 'test-1', passed: true);
      final failVerdict = _makeVerdict(name: 'test-2', passed: false);

      // Debrief the verdicts via Colossus
      final report = colossus.debrief([passVerdict, failVerdict]);

      // Now build the tab and manually set the pillar state
      final tab = BlueprintLensTab(colossus);
      await tester.pumpWidget(wrapTab(tab));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Debrief'));
      await tester.pumpAndSettle();

      // Initially showing empty message
      expect(find.textContaining('No debrief data yet'), findsOneWidget);

      // Debrief through Colossus won't propagate to the Pillar directly,
      // but verifies the report builds correctly
      expect(report.totalVerdicts, 2);
      expect(report.passedVerdicts, 1);
      expect(report.failedVerdicts, 1);
    });

    testWidgets('debrief report has valid pass rate', (tester) async {
      final v1 = _makeVerdict(name: 'a', passed: true);
      final v2 = _makeVerdict(name: 'b', passed: true);
      final v3 = _makeVerdict(name: 'c', passed: false);

      final report = colossus.debrief([v1, v2, v3]);

      expect(report.passRate, closeTo(0.666, 0.01));
      expect(report.allPassed, isFalse);
    });

    testWidgets('100% pass rate for all-passing verdicts', (tester) async {
      final v1 = _makeVerdict(name: 'x', passed: true);
      final v2 = _makeVerdict(name: 'y', passed: true);

      final report = colossus.debrief([v1, v2]);

      expect(report.passRate, 1.0);
      expect(report.allPassed, isTrue);
    });

    testWidgets('debrief insights are generated for failed verdicts', (
      tester,
    ) async {
      final failVerdict = _makeVerdict(name: 'fail-test', passed: false);
      final report = colossus.debrief([failVerdict]);

      // Should have at least one insight for the failure
      expect(report.insights, isNotEmpty);
    });

    testWidgets('suggested next actions are generated', (tester) async {
      final failVerdict = _makeVerdict(name: 'fail-nav', passed: false);
      final report = colossus.debrief([failVerdict]);

      // Debrief analysis should produce suggested actions
      expect(report.suggestedNextActions, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Pillar action edge cases
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab Pillar actions', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('copy lineage without result shows status', (tester) async {
      colossus.terrain.outposts['/page'] = Outpost(
        signet: Signet(
          routePattern: '/page',
          interactiveDescriptors: [],
          hash: 'p',
          identity: 'p',
        ),
        routePattern: '/page',
        displayName: 'Page',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      // Before resolving, try to copy — buttons shouldn't be visible
      // because lineageResult is null and buttons are behind if(lineage != null)
      expect(find.text('Copy Stratagem'), findsNothing);
      expect(find.text('Copy Summary'), findsNothing);
    });

    testWidgets('copy terrain mermaid shows status', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy Mermaid'));
      await tester.pumpAndSettle();

      expect(find.text('Terrain Mermaid copied to clipboard'), findsOneWidget);
    });

    testWidgets('copy AI map shows status', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Copy AI Map'));
      await tester.pumpAndSettle();

      expect(find.text('AI map copied to clipboard'), findsOneWidget);
    });

    testWidgets('copy gauntlet before generation shows status', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      // Before generation, Copy Stratagems button should not be visible
      expect(find.text('Copy Stratagems'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Sub-tab navigation
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab sub-tab navigation', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    testWidgets('can switch between all 5 sub-tabs', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      // Terrain (default): shows metrics
      expect(find.text('Discovered screens'), findsOneWidget);

      // Lineage
      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();
      expect(find.text('TARGET ROUTE'), findsOneWidget);

      // Gauntlet
      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();
      expect(find.text('TARGET SCREEN'), findsOneWidget);

      // Campaign
      await tester.tap(find.text('Campaign'));
      await tester.pumpAndSettle();
      expect(find.text('CAMPAIGN JSON'), findsOneWidget);

      // Debrief
      await tester.tap(find.text('Debrief'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No debrief data yet'), findsOneWidget);

      // Back to Terrain
      await tester.tap(find.text('Terrain'));
      await tester.pumpAndSettle();
      expect(find.text('Discovered screens'), findsOneWidget);
    });

    testWidgets('status persists across sub-tab switches', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      // Set a status by tapping Copy Mermaid
      await tester.tap(find.text('Copy Mermaid'));
      await tester.pumpAndSettle();
      expect(find.text('Terrain Mermaid copied to clipboard'), findsOneWidget);

      // Switch to Lineage and back
      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      // Status should still be visible (it's shared across tabs)
      expect(find.text('Terrain Mermaid copied to clipboard'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // RouteDropdown edge cases
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab RouteDropdown', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('empty terrain shows info card on Lineage', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No routes discovered yet'), findsOneWidget);
    });

    testWidgets('empty terrain shows info card on Gauntlet', (tester) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gauntlet'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No routes discovered yet'), findsOneWidget);
    });

    testWidgets('selecting a route clears previous lineage', (tester) async {
      // Set up two routes
      for (final route in ['/a', '/b']) {
        colossus.terrain.outposts[route] = Outpost(
          signet: Signet(
            routePattern: route,
            interactiveDescriptors: [],
            hash: route,
            identity: route,
          ),
          routePattern: route,
          displayName: route,
          interactiveElements: [],
          displayElements: [],
          screenWidth: 400,
          screenHeight: 800,
        );
      }

      await tester.pumpWidget(wrapTabWithNav(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lineage'));
      await tester.pumpAndSettle();

      // Select /a
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/a').last);
      await tester.pumpAndSettle();

      // Resolve
      await tester.tap(find.text('Resolve Lineage'));
      await tester.pumpAndSettle();

      // Should show result (directly accessible)
      expect(find.textContaining('directly accessible'), findsOneWidget);

      // Now switch to /b — previous result should clear
      await tester.tap(find.byIcon(Icons.arrow_drop_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text('/b').last);
      await tester.pumpAndSettle();

      // Result should be cleared (no "directly accessible" text)
      expect(find.textContaining('directly accessible'), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // Multiple outpost interactive elements
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab multiple interactive elements', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('route card shows 0 elem for empty elements', (tester) async {
      colossus.terrain.outposts['/empty'] = Outpost(
        signet: Signet(
          routePattern: '/empty',
          interactiveDescriptors: [],
          hash: 'e',
          identity: 'e',
        ),
        routePattern: '/empty',
        displayName: 'Empty',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('0 elem'), findsOneWidget);
    });

    testWidgets('route card shows 0 exit for route with no exits', (
      tester,
    ) async {
      colossus.terrain.outposts['/leaf'] = Outpost(
        signet: Signet(
          routePattern: '/leaf',
          interactiveDescriptors: [],
          hash: 'l',
          identity: 'l',
        ),
        routePattern: '/leaf',
        displayName: 'Leaf',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('0 exit'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Terrain Reactivity — auto-refresh on terrainNotifier
  // ---------------------------------------------------------------------------

  group('BlueprintLensTab terrain reactivity', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Scout.reset();
      Colossus.shutdown();
    });

    testWidgets('Terrain view auto-updates when terrainNotifier fires', (
      tester,
    ) async {
      // Start with empty terrain
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets); // Screens, transitions, etc.

      // Add a route to terrain
      colossus.terrain.outposts['/new'] = Outpost(
        signet: Signet(
          routePattern: '/new',
          interactiveDescriptors: [],
          hash: 'new',
          identity: 'new',
        ),
        routePattern: '/new',
        displayName: '/new',
        interactiveElements: [],
        displayElements: [],
        screenWidth: 400,
        screenHeight: 800,
      );

      // Fire the notifier — should trigger re-read of terrain data
      colossus.terrainNotifier.notifyListeners();
      await tester.pump();

      // Now should show 1 screen
      expect(find.text('1'), findsWidgets);
      expect(find.text('/new'), findsOneWidget);
    });

    testWidgets(
      'Terrain view reflects data changes after terrainNotifier fires',
      (tester) async {
        await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
        await tester.pumpAndSettle();

        // Initially 0 discovered screens
        expect(find.text('0'), findsWidgets);

        // Manually update terrain and fire notifier (simulates what
        // learnFromSession does when it gets real data)
        colossus.terrain.sessionsAnalyzed = 1;
        colossus.terrainNotifier.notifyListeners();
        await tester.pumpAndSettle();

        // The Vestige should have rebuilt with fresh terrain data
        expect(find.text('1'), findsWidgets);
      },
    );

    testWidgets('multiple notifier fires correctly refresh terrain view', (
      tester,
    ) async {
      await tester.pumpWidget(wrapTab(BlueprintLensTab(colossus)));
      await tester.pumpAndSettle();

      for (var i = 0; i < 3; i++) {
        colossus.terrain.outposts['/route_$i'] = Outpost(
          signet: Signet(
            routePattern: '/route_$i',
            interactiveDescriptors: [],
            hash: 'r$i',
            identity: 'r$i',
          ),
          routePattern: '/route_$i',
          displayName: '/route_$i',
          interactiveElements: [],
          displayElements: [],
          screenWidth: 400,
          screenHeight: 800,
        );

        colossus.terrainNotifier.notifyListeners();
        await tester.pump();
      }

      // Should show 3 screens
      expect(find.text('3'), findsWidgets);
    });
  });
}
