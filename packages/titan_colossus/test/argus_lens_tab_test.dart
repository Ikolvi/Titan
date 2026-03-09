import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_argus/titan_argus.dart';
import 'package:titan_colossus/titan_colossus.dart';

/// Minimal Argus subclass for testing.
class _TestArgus extends Argus {
  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    isLoggedIn.value = true;
  }

  @override
  Future<void> signOut() async {
    isLoggedIn.value = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArgusLensTab', () {
    late Colossus colossus;

    setUp(() {
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      ColossusArgus.disconnect();
      TitanObserver.clearObservers();
      Titan.reset();
      Colossus.shutdown();
    });

    test('has correct title and icon', () {
      final tab = ArgusLensTab(colossus);
      expect(tab.title, 'Auth');
      expect(tab.icon, Icons.shield);
    });

    test('implements LensPlugin', () {
      final tab = ArgusLensTab(colossus);
      expect(tab, isA<LensPlugin>());
    });

    testWidgets('state tab shows disconnected when bridge not active', (
      tester,
    ) async {
      final tab = ArgusLensTab(colossus);

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

      expect(
        find.textContaining('Argus bridge not connected.'),
        findsOneWidget,
      );
    });

    testWidgets('state tab shows auth status when connected', (tester) async {
      final argus = _TestArgus();
      Titan.put<Argus>(argus);
      ColossusArgus.connect();

      final tab = ArgusLensTab(colossus);

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

      // Should show unauthenticated state initially
      expect(find.text('Unauthenticated'), findsOneWidget);
      expect(find.text('SESSION'), findsOneWidget);
      expect(find.text('BRIDGE'), findsOneWidget);
    });

    testWidgets('history tab shows empty state', (tester) async {
      final tab = ArgusLensTab(colossus);

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

      // Navigate to History tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('No auth events recorded.'), findsOneWidget);
    });

    testWidgets('history tab shows login/logout events', (tester) async {
      final argus = _TestArgus();
      Titan.put<Argus>(argus);
      ColossusArgus.connect();

      await argus.signIn();
      await argus.signOut();

      final tab = ArgusLensTab(colossus);

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

      // Navigate to History tab
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.text('User logged in'), findsOneWidget);
      expect(find.text('User logged out'), findsOneWidget);
    });

    testWidgets('stats tab shows activity counts', (tester) async {
      final argus = _TestArgus();
      Titan.put<Argus>(argus);
      ColossusArgus.connect();

      await argus.signIn();
      await argus.signOut();

      final tab = ArgusLensTab(colossus);

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

      expect(find.text('ACTIVITY'), findsOneWidget);
      expect(find.text('Logins'), findsOneWidget);
      expect(find.text('Logouts'), findsOneWidget);
    });

    testWidgets('stats tab shows empty state when no activity', (tester) async {
      final argus = _TestArgus();
      Titan.put<Argus>(argus);
      ColossusArgus.connect();

      final tab = ArgusLensTab(colossus);

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

      expect(find.text('No auth activity recorded.'), findsOneWidget);
    });

    test('ColossusArgus tracks login and logout counts', () {
      final argus = _TestArgus();
      Titan.put<Argus>(argus);
      ColossusArgus.connect();

      expect(ColossusArgus.loginCount, 0);
      expect(ColossusArgus.logoutCount, 0);

      argus.isLoggedIn.value = true;
      expect(ColossusArgus.loginCount, 1);
      expect(ColossusArgus.lastLoginTime, isNotNull);
      expect(ColossusArgus.currentSessionStart, isNotNull);

      argus.isLoggedIn.value = false;
      expect(ColossusArgus.logoutCount, 1);
      expect(ColossusArgus.lastLogoutTime, isNotNull);
      expect(ColossusArgus.sessionDurations, hasLength(1));
      expect(ColossusArgus.currentSessionStart, isNull);
    });

    test('ColossusArgus.disconnect resets counters', () {
      final argus = _TestArgus();
      Titan.put<Argus>(argus);
      ColossusArgus.connect();

      argus.isLoggedIn.value = true;
      argus.isLoggedIn.value = false;

      ColossusArgus.disconnect();

      expect(ColossusArgus.loginCount, 0);
      expect(ColossusArgus.logoutCount, 0);
      expect(ColossusArgus.lastLoginTime, isNull);
      expect(ColossusArgus.lastLogoutTime, isNull);
      expect(ColossusArgus.sessionDurations, isEmpty);
    });

    test('can be registered and unregistered with Lens', () {
      final tab = ArgusLensTab(colossus);
      Lens.registerPlugin(tab);
      expect(Lens.plugins, contains(tab));

      Lens.unregisterPlugin(tab);
      expect(Lens.plugins, isNot(contains(tab)));
    });

    test('Colossus.init registers ArgusLensTab when enableLensTab true', () {
      Colossus.shutdown();
      Colossus.init(enableLensTab: true);

      final tabs = Lens.plugins.whereType<ArgusLensTab>().toList();
      expect(tabs, hasLength(1));
    });

    test('Colossus.shutdown unregisters ArgusLensTab', () {
      Colossus.shutdown();
      Colossus.init(enableLensTab: true);

      expect(Lens.plugins.whereType<ArgusLensTab>(), isNotEmpty);

      Colossus.shutdown();
      expect(Lens.plugins.whereType<ArgusLensTab>(), isEmpty);
    });
  });
}
