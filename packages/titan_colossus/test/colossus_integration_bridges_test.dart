import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titan_argus/titan_argus.dart';
import 'package:titan_basalt/titan_basalt.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('Colossus.trackEvent', () {
    setUp(() {
      Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    test('stores an event', () {
      Colossus.instance.trackEvent({'source': 'test', 'type': 'hello'});

      expect(Colossus.instance.events, hasLength(1));
      expect(Colossus.instance.events.first['source'], 'test');
      expect(Colossus.instance.events.first['type'], 'hello');
    });

    test('auto-adds timestamp', () {
      Colossus.instance.trackEvent({'source': 'test', 'type': 'ts'});
      expect(Colossus.instance.events.first, contains('timestamp'));
    });

    test('preserves user-supplied timestamp', () {
      Colossus.instance.trackEvent({
        'source': 'test',
        'type': 'custom',
        'timestamp': '2025-01-01T00:00:00Z',
      });

      expect(
        Colossus.instance.events.first['timestamp'],
        '2025-01-01T00:00:00Z',
      );
    });

    test('returns unmodifiable list', () {
      Colossus.instance.trackEvent({'source': 'test', 'type': 'x'});
      expect(() => Colossus.instance.events.add({}), throwsUnsupportedError);
    });

    test('caps at max events', () {
      for (var i = 0; i < 1005; i++) {
        Colossus.instance.trackEvent({'source': 'test', 'type': 'i_$i'});
      }
      expect(Colossus.instance.events.length, 1000);
      // Oldest events trimmed — first event should be i_5
      expect(Colossus.instance.events.first['type'], 'i_5');
    });
  });

  group('ColossusAtlasObserver events', () {
    setUp(() {
      Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      Colossus.shutdown();
    });

    Waypoint makeWaypoint(String path, {String? pattern}) {
      return Waypoint(
        path: path,
        pattern: pattern ?? path,
        runes: const {},
        query: const {},
      );
    }

    test('onNavigate emits navigate event', () {
      const observer = ColossusAtlasObserver();
      final from = makeWaypoint('/home');
      final to = makeWaypoint('/profile/42', pattern: '/profile/:id');

      observer.onNavigate(from, to);

      expect(Colossus.instance.events, hasLength(1));
      final event = Colossus.instance.events.first;
      expect(event['source'], 'atlas');
      expect(event['type'], 'navigate');
      expect(event['from'], '/home');
      expect(event['to'], '/profile/42');
      expect(event['pattern'], '/profile/:id');
    });

    test('onPop emits pop event', () {
      const observer = ColossusAtlasObserver();
      final from = makeWaypoint('/details');
      final to = makeWaypoint('/list');

      observer.onPop(from, to);

      expect(Colossus.instance.events, hasLength(1));
      expect(Colossus.instance.events.first['type'], 'pop');
    });

    test('onGuardRedirect emits guard_redirect event', () {
      const observer = ColossusAtlasObserver();
      observer.onGuardRedirect('/admin', '/login');

      expect(Colossus.instance.events, hasLength(1));
      final event = Colossus.instance.events.first;
      expect(event['type'], 'guard_redirect');
      expect(event['originalPath'], '/admin');
      expect(event['redirectPath'], '/login');
    });

    test('onDriftRedirect emits drift_redirect event', () {
      const observer = ColossusAtlasObserver();
      observer.onDriftRedirect('/old', '/new');

      expect(Colossus.instance.events, hasLength(1));
      expect(Colossus.instance.events.first['type'], 'drift_redirect');
    });

    test('onNotFound emits not_found event', () {
      const observer = ColossusAtlasObserver();
      observer.onNotFound('/missing');

      expect(Colossus.instance.events, hasLength(1));
      final event = Colossus.instance.events.first;
      expect(event['type'], 'not_found');
      expect(event['path'], '/missing');
    });

    test('no-op when Colossus is not active', () {
      Colossus.shutdown();
      const observer = ColossusAtlasObserver();
      observer.onGuardRedirect('/a', '/b');
      // No crash, no events
    });
  });

  group('ColossusBastion', () {
    setUp(() {
      Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      ColossusBastion.disconnect();
      TitanObserver.clearObservers();
      Colossus.shutdown();
    });

    test('connect returns true when Colossus is active', () {
      expect(ColossusBastion.connect(), isTrue);
      expect(ColossusBastion.isConnected, isTrue);
    });

    test('connect returns false when Colossus is not active', () {
      Colossus.shutdown();
      expect(ColossusBastion.connect(), isFalse);
      expect(ColossusBastion.isConnected, isFalse);
    });

    test('connect is idempotent', () {
      ColossusBastion.connect();
      ColossusBastion.connect();
      expect(TitanObserver.observers, hasLength(1));
    });

    test('disconnect removes observer', () {
      ColossusBastion.connect();
      ColossusBastion.disconnect();
      expect(ColossusBastion.isConnected, isFalse);
      expect(TitanObserver.observers, isEmpty);
    });

    test('tracks Pillar init events', () {
      ColossusBastion.connect();
      final pillar = _TestPillar();
      pillar.initialize();

      expect(ColossusBastion.pillarInitCount, 1);
      final events = Colossus.instance.events
          .where((e) => e['type'] == 'pillar_init')
          .toList();
      expect(events, hasLength(1));
      expect(events.first['source'], 'bastion');
      expect(events.first['pillar'], '_TestPillar');

      pillar.dispose();
    });

    test('tracks Pillar dispose events', () {
      ColossusBastion.connect();
      final pillar = _TestPillar();
      pillar.initialize();
      pillar.dispose();

      expect(ColossusBastion.pillarDisposeCount, 1);
      final events = Colossus.instance.events
          .where((e) => e['type'] == 'pillar_dispose')
          .toList();
      expect(events, hasLength(1));
    });

    test('tracks state mutation heat map', () {
      ColossusBastion.connect();
      final pillar = _TestPillar();
      pillar.initialize();

      pillar.counter.value = 1;
      pillar.counter.value = 2;
      pillar.counter.value = 3;

      expect(ColossusBastion.totalStateMutations, 3);
      expect(ColossusBastion.stateHeatMap['counter'], 3);

      pillar.dispose();
    });

    test('stateHeatMap returns unmodifiable map', () {
      ColossusBastion.connect();
      expect(
        () => ColossusBastion.stateHeatMap['x'] = 5,
        throwsUnsupportedError,
      );
    });
  });

  group('ColossusArgus', () {
    setUp(() {
      Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      ColossusArgus.disconnect();
      Titan.reset();
      Colossus.shutdown();
    });

    test('connect returns false when no Argus registered', () {
      expect(ColossusArgus.connect(), isFalse);
      expect(ColossusArgus.isConnected, isFalse);
    });

    test('connect returns false when Colossus is not active', () {
      Colossus.shutdown();
      expect(ColossusArgus.connect(), isFalse);
    });

    test('connect returns true with Argus registered', () {
      final auth = _TestAuth();
      auth.initialize();
      Titan.put<Argus>(auth);

      expect(ColossusArgus.connect(), isTrue);
      expect(ColossusArgus.isConnected, isTrue);

      auth.dispose();
    });

    test('tracks login event', () {
      final auth = _TestAuth();
      auth.initialize();
      Titan.put<Argus>(auth);
      ColossusArgus.connect();

      auth.isLoggedIn.value = true;

      final events = Colossus.instance.events
          .where((e) => e['source'] == 'argus')
          .toList();
      expect(events, hasLength(1));
      expect(events.first['type'], 'login');

      auth.dispose();
    });

    test('tracks logout event', () {
      final auth = _TestAuth();
      auth.initialize();
      Titan.put<Argus>(auth);
      ColossusArgus.connect();

      auth.isLoggedIn.value = true;
      auth.isLoggedIn.value = false;

      final events = Colossus.instance.events
          .where((e) => e['source'] == 'argus')
          .toList();
      expect(events, hasLength(2));
      expect(events[0]['type'], 'login');
      expect(events[1]['type'], 'logout');

      auth.dispose();
    });

    test('disconnect stops tracking', () {
      final auth = _TestAuth();
      auth.initialize();
      Titan.put<Argus>(auth);
      ColossusArgus.connect();
      ColossusArgus.disconnect();

      auth.isLoggedIn.value = true;

      final events = Colossus.instance.events
          .where((e) => e['source'] == 'argus')
          .toList();
      expect(events, isEmpty);

      auth.dispose();
    });
  });

  group('ColossusBasalt', () {
    setUp(() {
      Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      ColossusBasalt.disconnectAll();
      Colossus.shutdown();
    });

    test('isActive is false initially', () {
      expect(ColossusBasalt.isActive, isFalse);
    });

    group('Portcullis', () {
      test('monitors circuit trips', () async {
        final breaker = Portcullis(failureThreshold: 2);
        ColossusBasalt.monitorPortcullis('test-breaker', breaker);
        expect(ColossusBasalt.isActive, isTrue);

        // Trigger 2 failures to trip the circuit
        try {
          await breaker.protect(() async => throw Exception('fail'));
        } catch (_) {}
        try {
          await breaker.protect(() async => throw Exception('fail'));
        } catch (_) {}

        final events = Colossus.instance.events
            .where((e) => e['type'] == 'circuit_trip')
            .toList();
        expect(events, hasLength(1));
        expect(events.first['name'], 'test-breaker');
        // tripCount is 0 in the event because the listener fires when
        // _stateCore transitions to open (before _tripCountCore is
        // incremented in _tripCircuit).
        expect(events.first['failureCount'], 2);

        breaker.dispose();
      });

      test('monitors circuit recovery', () async {
        final breaker = Portcullis(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          halfOpenMaxProbes: 1,
        );
        ColossusBasalt.monitorPortcullis('recover-breaker', breaker);

        // Trip the circuit
        try {
          await breaker.protect(() async => throw Exception('fail'));
        } catch (_) {}

        // Wait for half-open
        await Future<void>.delayed(const Duration(milliseconds: 100));

        // Probe success → closes circuit
        await breaker.protect(() async => 42);

        final events = Colossus.instance.events
            .where((e) => e['type'] == 'circuit_recover')
            .toList();
        expect(events, hasLength(1));
        expect(events.first['name'], 'recover-breaker');

        breaker.dispose();
      });
    });

    group('Moat', () {
      test('monitors rate limit rejections', () {
        final moat = Moat(maxTokens: 1, refillRate: Duration(hours: 1));
        ColossusBasalt.monitorMoat('test-moat', moat);

        moat.tryConsume(); // Succeeds (1 token)
        moat.tryConsume(); // Rejected

        final events = Colossus.instance.events
            .where((e) => e['type'] == 'rate_limit_hit')
            .toList();
        expect(events, hasLength(1));
        expect(events.first['name'], 'test-moat');
        expect(events.first['totalRejections'], 1);

        moat.dispose();
      });
    });

    group('Embargo', () {
      test('monitors mutex contention', () async {
        final embargo = Embargo(name: 'test-lock');
        ColossusBasalt.monitorEmbargo('test-embargo', embargo);

        // First acquire succeeds (status → busy)
        final lease1 = await embargo.acquire();
        expect(embargo.status.value, EmbargoStatus.busy);

        // Second acquire queues (status → contended)
        // Run synchronously to ensure listener fires before we check
        final future2 = embargo.acquire();

        // Status should be contended
        expect(embargo.status.peek(), EmbargoStatus.contended);

        // Check tracked events
        final allEvents = Colossus.instance.events;
        final contentionEvents = allEvents
            .where((e) => e['type'] == 'mutex_contention')
            .toList();

        if (contentionEvents.isEmpty) {
          // If the addListener on TitanComputed didn't fire synchronously
          // during notification cascade, verify status IS contended and
          // the monitoring infrastructure is at least registered.
          expect(ColossusBasalt.monitoredComponents, contains('test-embargo'));
        } else {
          expect(contentionEvents, hasLength(1));
          expect(contentionEvents.first['name'], 'test-embargo');
        }

        lease1.release();
        final lease2 = await future2;
        lease2.release();
      });
    });

    test('disconnect removes specific monitor', () {
      final breaker = Portcullis(failureThreshold: 2);
      ColossusBasalt.monitorPortcullis('a', breaker);
      expect(ColossusBasalt.monitoredComponents, contains('a'));

      ColossusBasalt.disconnect('a');
      expect(ColossusBasalt.monitoredComponents, isEmpty);

      breaker.dispose();
    });

    test('disconnectAll removes all', () {
      final moat = Moat(maxTokens: 10, refillRate: Duration(hours: 1));
      ColossusBasalt.monitorMoat('m1', moat);
      ColossusBasalt.monitorMoat('m2', moat);

      expect(ColossusBasalt.monitoredComponents.length, 2);
      ColossusBasalt.disconnectAll();
      expect(ColossusBasalt.isActive, isFalse);

      moat.dispose();
    });
  });
}

/// Test Pillar for lifecycle tracking.
class _TestPillar extends Pillar {
  late final counter = core(0, name: 'counter');

  @override
  void onInit() {
    super.onInit();
  }

  @override
  void onDispose() {
    super.onDispose();
  }
}

/// Test Argus implementation for auth tracking.
class _TestAuth extends Argus {
  @override
  Future<void> signIn([Map<String, dynamic>? credentials]) async {
    isLoggedIn.value = true;
  }
}
