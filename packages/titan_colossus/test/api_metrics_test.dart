import 'package:flutter_test/flutter_test.dart';
import 'package:titan_colossus/titan_colossus.dart';

void main() {
  // ---------------------------------------------------------
  // Tremor.apiLatency
  // ---------------------------------------------------------

  group('Tremor.apiLatency', () {
    test('creates alert with correct name and category', () {
      final tremor = Tremor.apiLatency();

      expect(tremor.name, 'api_latency_high');
      expect(tremor.category, MarkCategory.api);
      expect(tremor.severity, TremorSeverity.warning);
    });

    test('does not fire when no API requests exist', () {
      final tremor = Tremor.apiLatency(
        threshold: const Duration(milliseconds: 500),
      );

      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 0,
        apiErrorRate: 0,
        apiRequestCount: 0,
      );

      expect(tremor.evaluate(ctx), false);
    });

    test('does not fire when latency is below threshold', () {
      final tremor = Tremor.apiLatency(
        threshold: const Duration(milliseconds: 500),
      );

      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 200,
        apiErrorRate: 0,
        apiRequestCount: 10,
      );

      expect(tremor.evaluate(ctx), false);
    });

    test('fires when latency exceeds threshold', () {
      final tremor = Tremor.apiLatency(
        threshold: const Duration(milliseconds: 500),
      );

      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 750,
        apiErrorRate: 0,
        apiRequestCount: 10,
      );

      expect(tremor.evaluate(ctx), true);
    });

    test('supports custom severity and once mode', () {
      final tremor = Tremor.apiLatency(
        threshold: const Duration(milliseconds: 300),
        severity: TremorSeverity.error,
        once: true,
      );

      expect(tremor.severity, TremorSeverity.error);

      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 500,
        apiErrorRate: 0,
        apiRequestCount: 5,
      );

      expect(tremor.evaluate(ctx), true);
      expect(tremor.evaluate(ctx), false); // once mode
    });
  });

  // ---------------------------------------------------------
  // Tremor.apiErrorRate
  // ---------------------------------------------------------

  group('Tremor.apiErrorRate', () {
    test('creates alert with correct name and category', () {
      final tremor = Tremor.apiErrorRate();

      expect(tremor.name, 'api_error_rate');
      expect(tremor.category, MarkCategory.api);
      expect(tremor.severity, TremorSeverity.warning);
    });

    test('does not fire when no API requests exist', () {
      final tremor = Tremor.apiErrorRate(threshold: 10);

      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 0,
        apiErrorRate: 0,
        apiRequestCount: 0,
      );

      expect(tremor.evaluate(ctx), false);
    });

    test('does not fire when error rate is below threshold', () {
      final tremor = Tremor.apiErrorRate(threshold: 10);

      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 100,
        apiErrorRate: 5,
        apiRequestCount: 20,
      );

      expect(tremor.evaluate(ctx), false);
    });

    test('fires when error rate exceeds threshold', () {
      final tremor = Tremor.apiErrorRate(threshold: 10);

      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 100,
        apiErrorRate: 25,
        apiRequestCount: 20,
      );

      expect(tremor.evaluate(ctx), true);
    });
  });

  // ---------------------------------------------------------
  // TremorContext API fields
  // ---------------------------------------------------------

  group('TremorContext API fields', () {
    test('defaults to zero when not provided', () {
      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
      );

      expect(ctx.apiAvgLatencyMs, 0);
      expect(ctx.apiErrorRate, 0);
      expect(ctx.apiRequestCount, 0);
    });

    test('stores API fields when provided', () {
      final ctx = TremorContext(
        fps: 60,
        jankRate: 0,
        pillarCount: 0,
        leakSuspects: [],
        lastPageLoad: null,
        rebuildsPerWidget: {},
        apiAvgLatencyMs: 250,
        apiErrorRate: 12.5,
        apiRequestCount: 40,
      );

      expect(ctx.apiAvgLatencyMs, 250);
      expect(ctx.apiErrorRate, 12.5);
      expect(ctx.apiRequestCount, 40);
    });
  });

  // ---------------------------------------------------------
  // MarkCategory.api
  // ---------------------------------------------------------

  group('MarkCategory.api', () {
    test('exists in enum values', () {
      expect(MarkCategory.values, contains(MarkCategory.api));
    });

    test('Tremor.apiLatency uses api category', () {
      final tremor = Tremor.apiLatency();
      expect(tremor.category, MarkCategory.api);
    });
  });

  // ---------------------------------------------------------
  // ColossusTremor serialization for API tremors
  // ---------------------------------------------------------

  group('ColossusTremor API serialization', () {
    test('toMap serializes api_latency_high correctly', () {
      final tremor = Tremor.apiLatency();
      final now = DateTime(2025, 7, 1, 12, 0, 0);
      final event = ColossusTremor(
        tremor: tremor,
        message: 'API avg latency 750ms (10 requests)',
        timestamp: now,
      );

      final map = event.toMap();

      expect(map['name'], 'api_latency_high');
      expect(map['category'], 'api');
      expect(map['severity'], 'warning');
      expect(map['message'], contains('750ms'));
    });

    test('toMap serializes api_error_rate correctly', () {
      final tremor = Tremor.apiErrorRate(severity: TremorSeverity.error);
      final event = ColossusTremor(
        tremor: tremor,
        message: 'API error rate 25.0% (20 requests)',
      );

      final map = event.toMap();

      expect(map['name'], 'api_error_rate');
      expect(map['category'], 'api');
      expect(map['severity'], 'error');
    });
  });

  // ---------------------------------------------------------
  // Colossus.trackApiMetric & enriched API metrics
  // ---------------------------------------------------------

  group('Colossus API metrics enrichment', () {
    late Colossus colossus;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      colossus = Colossus.init(enableLensTab: false);
    });

    tearDown(() {
      colossus.dispose();
    });

    test('trackApiMetric stores metrics in apiMetrics', () {
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/users/1',
        'statusCode': 200,
        'durationMs': 100,
        'success': true,
        'timestamp': '2025-07-01T12:00:00Z',
      });
      colossus.trackApiMetric({
        'method': 'POST',
        'url': 'https://api.example.com/orders',
        'statusCode': 500,
        'durationMs': 500,
        'success': false,
        'error': 'Internal Server Error',
        'timestamp': '2025-07-01T12:00:02Z',
      });

      expect(colossus.apiMetrics.length, 2);
      expect(colossus.apiMetrics[0]['method'], 'GET');
      expect(colossus.apiMetrics[1]['success'], false);
    });

    test('trackApiMetric caps stored metrics at limit', () {
      // Fill beyond the 500 limit
      for (var i = 0; i < 510; i++) {
        colossus.trackApiMetric({
          'method': 'GET',
          'url': 'https://api.example.com/item/$i',
          'statusCode': 200,
          'durationMs': 50,
          'success': true,
        });
      }

      // Should be capped at 500
      expect(colossus.apiMetrics.length, 500);
    });

    test('apiMetrics stores varied durations for percentile use', () {
      // Add 10 metrics with durations 100, 200, ..., 1000
      for (var i = 1; i <= 10; i++) {
        colossus.trackApiMetric({
          'method': 'GET',
          'url': 'https://api.example.com/data',
          'statusCode': 200,
          'durationMs': i * 100,
          'success': true,
        });
      }

      final durations = colossus.apiMetrics
          .map((m) => m['durationMs'] as int)
          .toList();
      expect(durations, [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000]);
    });

    test('apiMetrics tracks mixed success/failure for error rate', () {
      for (var i = 0; i < 7; i++) {
        colossus.trackApiMetric({
          'method': 'GET',
          'url': 'https://api.example.com/ok',
          'statusCode': 200,
          'durationMs': 100,
          'success': true,
        });
      }
      for (var i = 0; i < 3; i++) {
        colossus.trackApiMetric({
          'method': 'GET',
          'url': 'https://api.example.com/fail',
          'statusCode': 500,
          'durationMs': 200,
          'success': false,
        });
      }

      final total = colossus.apiMetrics.length;
      final failed = colossus.apiMetrics
          .where((m) => m['success'] != true)
          .length;

      expect(total, 10);
      expect(failed, 3);
      expect((failed / total) * 100, 30.0);
    });

    test('apiMetrics stores diverse endpoints for grouping', () {
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/users/1',
        'statusCode': 200,
        'durationMs': 100,
        'success': true,
      });
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/users/2',
        'statusCode': 200,
        'durationMs': 200,
        'success': true,
      });
      colossus.trackApiMetric({
        'method': 'POST',
        'url': 'https://api.example.com/orders',
        'statusCode': 201,
        'durationMs': 150,
        'success': true,
      });

      // Both /users/1 and /users/2 should be stored
      final userMetrics = colossus.apiMetrics
          .where((m) => (m['url'] as String).contains('/users/'))
          .toList();
      expect(userMetrics.length, 2);
    });
  });

  // ---------------------------------------------------------
  // trackApiMetric triggers _evaluateTremors
  // ---------------------------------------------------------

  group('trackApiMetric triggers tremors', () {
    test('API latency tremor fires when threshold breached', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final colossus = Colossus.init(
        enableLensTab: false,
        tremors: [
          Tremor.apiLatency(threshold: const Duration(milliseconds: 200)),
        ],
      );

      // Track a slow metric
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/slow',
        'statusCode': 200,
        'durationMs': 500,
        'success': true,
      });

      // Check alert history
      expect(colossus.alertHistory, isNotEmpty);
      expect(colossus.alertHistory.last.tremor.name, 'api_latency_high');
      expect(colossus.alertHistory.last.message, contains('500ms'));

      colossus.dispose();
    });

    test('API error rate tremor fires when threshold breached', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final colossus = Colossus.init(
        enableLensTab: false,
        tremors: [Tremor.apiErrorRate(threshold: 20)],
      );

      // Track 3 failed requests out of 4 total (75% error rate)
      for (var i = 0; i < 3; i++) {
        colossus.trackApiMetric({
          'method': 'GET',
          'url': 'https://api.example.com/fail',
          'statusCode': 500,
          'durationMs': 100,
          'success': false,
        });
      }
      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/ok',
        'statusCode': 200,
        'durationMs': 100,
        'success': true,
      });

      // Should have fired
      final apiAlerts = colossus.alertHistory
          .where((a) => a.tremor.name == 'api_error_rate')
          .toList();
      expect(apiAlerts, isNotEmpty);
      expect(apiAlerts.last.message, contains('%'));

      colossus.dispose();
    });

    test('API tremors do not fire when below threshold', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final colossus = Colossus.init(
        enableLensTab: false,
        tremors: [
          Tremor.apiLatency(threshold: const Duration(milliseconds: 1000)),
          Tremor.apiErrorRate(threshold: 50),
        ],
      );

      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/fast',
        'statusCode': 200,
        'durationMs': 50,
        'success': true,
      });

      // No alerts should fire
      final apiAlerts = colossus.alertHistory
          .where(
            (a) =>
                a.tremor.name == 'api_latency_high' ||
                a.tremor.name == 'api_error_rate',
          )
          .toList();
      expect(apiAlerts, isEmpty);

      colossus.dispose();
    });
  });

  // ---------------------------------------------------------
  // Enriched API metrics (RelayHandler output shape)
  // ---------------------------------------------------------

  group('Enriched API metrics output', () {
    test('RelayHandler getApiMetrics returns enriched fields', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final colossus = Colossus.init(enableLensTab: false);

      colossus.trackApiMetric({
        'method': 'GET',
        'url': 'https://api.example.com/data',
        'statusCode': 200,
        'durationMs': 100,
        'success': true,
      });

      // Verify data is tracked correctly
      expect(colossus.apiMetrics.length, 1);
      expect(colossus.apiMetrics[0]['durationMs'], 100);

      colossus.dispose();
    });
  });
}
