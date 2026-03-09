import 'package:flutter_test/flutter_test.dart';
import 'package:titan/titan.dart';
import 'package:titan_colossus/titan_colossus.dart';
import 'package:titan_envoy/titan_envoy.dart';

/// A [Courier] that intercepts all requests and returns a mock response,
/// preventing real HTTP calls (which Flutter tests block at 400).
class _MockCourier extends Courier {
  final List<Missive> captured = [];

  @override
  Future<Dispatch> intercept(Missive missive, CourierChain chain) async {
    captured.add(missive);
    return Dispatch(
      statusCode: 200,
      headers: {'content-type': 'application/json'},
      data: {'ok': true},
      rawBody: '{"ok":true}',
      missive: missive,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ColossusEnvoy', () {
    setUp(() {
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    tearDown(() {
      ColossusEnvoy.disconnect();
      Colossus.shutdown();
      Titan.reset();
      Herald.reset();
      Vigil.reset();
      Chronicle.reset();
    });

    test('isConnected starts as false', () {
      expect(ColossusEnvoy.isConnected, isFalse);
    });

    test('connect returns false when no Envoy registered', () {
      Colossus.init(enableLensTab: false);

      expect(ColossusEnvoy.connect(), isFalse);
      expect(ColossusEnvoy.isConnected, isFalse);
    });

    test('connect returns false when Colossus not active', () {
      final envoy = Envoy(baseUrl: 'https://example.com');
      Titan.put<Envoy>(envoy);

      expect(ColossusEnvoy.connect(), isFalse);
      expect(ColossusEnvoy.isConnected, isFalse);

      envoy.close();
    });

    test('connect succeeds when both Envoy and Colossus available', () {
      final envoy = Envoy(baseUrl: 'https://example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);

      expect(ColossusEnvoy.connect(), isTrue);
      expect(ColossusEnvoy.isConnected, isTrue);
    });

    test('connect is idempotent', () {
      final envoy = Envoy(baseUrl: 'https://example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);

      expect(ColossusEnvoy.connect(), isTrue);
      expect(ColossusEnvoy.connect(), isTrue);
      expect(ColossusEnvoy.isConnected, isTrue);
    });

    test('forwards metrics from Envoy to Colossus', () async {
      final mock = _MockCourier();
      final envoy = Envoy(baseUrl: 'https://api.example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);
      ColossusEnvoy.connect();
      // Mock must be added AFTER MetricsCourier so chain order is:
      // MetricsCourier → Mock (returns response) → metric recorded.
      envoy.addCourier(mock);

      await envoy.get('/users');

      final metrics = Colossus.instance.apiMetrics;
      expect(metrics, hasLength(1));
      expect(metrics.first['method'], 'GET');
      expect(metrics.first['statusCode'], 200);
      expect(metrics.first['success'], isTrue);
      expect(metrics.first['url'], contains('/users'));
    });

    test('tracks multiple requests', () async {
      final mock = _MockCourier();
      final envoy = Envoy(baseUrl: 'https://api.example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);
      ColossusEnvoy.connect();
      envoy.addCourier(mock);

      await envoy.get('/a');
      await envoy.get('/b');
      await envoy.post('/c', data: {'key': 'value'});

      expect(Colossus.instance.apiMetrics, hasLength(3));
      expect(mock.captured, hasLength(3));
    });

    test('disconnect stops metric forwarding', () async {
      final mock = _MockCourier();
      final envoy = Envoy(baseUrl: 'https://api.example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);
      ColossusEnvoy.connect();
      envoy.addCourier(mock);
      expect(ColossusEnvoy.isConnected, isTrue);

      // Make one request before disconnecting.
      await envoy.get('/before');
      expect(Colossus.instance.apiMetrics, hasLength(1));

      ColossusEnvoy.disconnect();
      expect(ColossusEnvoy.isConnected, isFalse);

      // Request after disconnect — not tracked by Colossus.
      await envoy.get('/after');
      expect(Colossus.instance.apiMetrics, hasLength(1)); // Still 1.
    });

    test('disconnect is safe when not connected', () {
      ColossusEnvoy.disconnect();
      expect(ColossusEnvoy.isConnected, isFalse);
    });

    test('reconnect after disconnect works', () async {
      final mock = _MockCourier();
      final envoy = Envoy(baseUrl: 'https://api.example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);

      // First connect + disconnect cycle.
      expect(ColossusEnvoy.connect(), isTrue);
      expect(ColossusEnvoy.isConnected, isTrue);
      ColossusEnvoy.disconnect();
      expect(ColossusEnvoy.isConnected, isFalse);

      // Reconnect — MetricsCourier re-added, then mock after it.
      ColossusEnvoy.connect();
      envoy.addCourier(mock);

      await envoy.get('/reconnected');

      expect(Colossus.instance.apiMetrics, hasLength(1));
    });

    test('graceful when Colossus shuts down mid-tracking', () async {
      final mock = _MockCourier();
      final envoy = Envoy(baseUrl: 'https://api.example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);
      ColossusEnvoy.connect();
      envoy.addCourier(mock);

      // Shutdown Colossus while courier is still attached.
      Colossus.shutdown();

      // Should not throw — metric callback checks isActive.
      await envoy.get('/after-shutdown');
    });

    test('metric includes all expected fields', () async {
      final mock = _MockCourier();
      final envoy = Envoy(baseUrl: 'https://api.example.com');
      Titan.put<Envoy>(envoy);
      Colossus.init(enableLensTab: false);
      ColossusEnvoy.connect();
      envoy.addCourier(mock);

      await envoy.get('/details');

      final metric = Colossus.instance.apiMetrics.first;
      expect(metric.containsKey('method'), isTrue);
      expect(metric.containsKey('url'), isTrue);
      expect(metric.containsKey('statusCode'), isTrue);
      expect(metric.containsKey('durationMs'), isTrue);
      expect(metric.containsKey('success'), isTrue);
      expect(metric.containsKey('timestamp'), isTrue);
      expect(metric.containsKey('cached'), isTrue);
    });

    test('works with EnvoyModule.install', () async {
      final mock = _MockCourier();
      EnvoyModule.install(baseUrl: 'https://api.example.com');
      Colossus.init(enableLensTab: false);
      ColossusEnvoy.connect();
      // Add mock AFTER MetricsCourier so chain proceeds through it.
      Titan.get<Envoy>().addCourier(mock);

      await Titan.get<Envoy>().get('/via-module');

      expect(Colossus.instance.apiMetrics, hasLength(1));
      expect(
        Colossus.instance.apiMetrics.first['url'],
        contains('/via-module'),
      );
    });
  });
}
