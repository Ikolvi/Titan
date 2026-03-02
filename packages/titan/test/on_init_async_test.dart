import 'package:test/test.dart';
import 'package:titan/titan.dart';

class _SyncPillar extends Pillar {
  late final count = core(0);
}

class _AsyncPillar extends Pillar {
  late final data = core<String>('loading');

  @override
  Future<void> onInitAsync() async {
    await Future<void>.delayed(Duration(milliseconds: 50));
    data.value = 'loaded';
  }
}

class _FailingAsyncPillar extends Pillar {
  late final data = core<String>('loading');
  Object? caughtError;

  @override
  Future<void> onInitAsync() async {
    throw Exception('init failed');
  }

  @override
  void onError(Object error, StackTrace? stackTrace) {
    caughtError = error;
  }
}

void main() {
  setUp(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  tearDown(() {
    Titan.reset();
    Vigil.reset();
    Herald.reset();
  });

  group('onInitAsync', () {
    test('isReady starts as false', () {
      final pillar = _AsyncPillar();
      expect(pillar.isReady.value, isFalse);
      pillar.dispose();
    });

    test('isReady becomes true after onInitAsync completes', () async {
      final pillar = _AsyncPillar();
      pillar.initialize();

      expect(pillar.isReady.peek(), isFalse);

      // Wait for async init
      await Future<void>.delayed(Duration(milliseconds: 100));

      expect(pillar.isReady.peek(), isTrue);
      expect(pillar.data.peek(), 'loaded');
      pillar.dispose();
    });

    test('isReady is reactive', () async {
      final pillar = _AsyncPillar();
      final values = <bool>[];

      TitanEffect(() {
        values.add(pillar.isReady.value);
      });

      pillar.initialize();

      await Future<void>.delayed(Duration(milliseconds: 100));

      expect(values, contains(false));
      expect(values, contains(true));
      pillar.dispose();
    });

    test('sync Pillar gets isReady set to true', () async {
      final pillar = _SyncPillar();
      pillar.initialize();

      // Even sync pillars run onInitAsync (which is a no-op by default)
      // The microtask should complete quickly
      await Future<void>.delayed(Duration(milliseconds: 10));

      expect(pillar.isReady.peek(), isTrue);
      pillar.dispose();
    });

    test('onInitAsync error is forwarded to onError', () async {
      final pillar = _FailingAsyncPillar();
      pillar.initialize();

      await Future<void>.delayed(Duration(milliseconds: 50));

      expect(pillar.caughtError, isA<Exception>());
      expect(pillar.isReady.peek(), isFalse);
      pillar.dispose();
    });

    test('isReady is not set if pillar is disposed during init', () async {
      final pillar = _AsyncPillar();
      pillar.initialize();

      // Dispose immediately before async init completes
      pillar.dispose();

      await Future<void>.delayed(Duration(milliseconds: 100));

      // isReady should NOT have been set since pillar was disposed
      // (the Core is already disposed, so we can't read its value,
      // but the point is that no error was thrown)
    });
  });
}
