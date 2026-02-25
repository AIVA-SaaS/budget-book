import 'package:get_it/get_it.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/storage/secure_storage.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Core
  getIt.registerLazySingleton<SecureStorageService>(
    () => SecureStorageService(),
  );
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(),
  );

  // Repositories and BLoCs will be registered here per feature
}
