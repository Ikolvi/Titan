import 'package:test/test.dart';
import 'package:titan/titan.dart';

void main() {
  group('TitanConfig', () {
    tearDown(() {
      TitanConfig.reset();
    });

    test('debugMode defaults to false', () {
      expect(TitanConfig.debugMode, false);
    });

    test('debugMode can be set to true', () {
      TitanConfig.debugMode = true;
      expect(TitanConfig.debugMode, true);
    });

    test('enableLogging sets TitanObserver to TitanLoggingObserver', () {
      expect(TitanObserver.instance, isNull);

      TitanConfig.enableLogging();

      expect(TitanObserver.instance, isA<TitanLoggingObserver>());
    });

    test('enableLogging with custom logger', () {
      final logs = <String>[];
      TitanConfig.enableLogging(logger: logs.add);

      expect(TitanObserver.instance, isA<TitanLoggingObserver>());

      // Trigger a state change to verify custom logger is used
      final state = TitanState(0, name: 'test');
      state.value = 1;
      state.dispose();

      expect(logs, isNotEmpty);
      expect(logs.first, contains('test'));
    });

    test('disableLogging nulls TitanObserver', () {
      TitanConfig.enableLogging();
      expect(TitanObserver.instance, isNotNull);

      TitanConfig.disableLogging();
      expect(TitanObserver.instance, isNull);
    });

    test('reset restores all defaults', () {
      TitanConfig.debugMode = true;
      TitanConfig.enableLogging();

      TitanConfig.reset();

      expect(TitanConfig.debugMode, false);
      expect(TitanObserver.instance, isNull);
    });
  });
}
