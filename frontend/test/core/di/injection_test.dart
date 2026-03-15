import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:budget_book/core/di/injection.dart';

void main() {
  group('disposeAllSingletons', () {
    test('resets GetIt instance and disposes all registered singletons',
        () async {
      // Register a dummy singleton to verify reset behavior
      final getItInstance = GetIt.instance;
      await getItInstance.reset();

      var disposed = false;
      getItInstance.registerLazySingleton<String>(
        () => 'test',
        dispose: (_) => disposed = true,
      );

      // Force creation so dispose callback will fire
      getItInstance<String>();
      expect(getItInstance.isRegistered<String>(), isTrue);

      await disposeAllSingletons();

      // After reset, previously registered types should no longer be available
      expect(getItInstance.isRegistered<String>(), isFalse);
      expect(disposed, isTrue);
    });
  });
}
