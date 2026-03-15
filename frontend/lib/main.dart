import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:budget_book/app.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/router/app_router.dart';

// Task #18: SENTRY_DSN is injected at build time via --dart-define=SENTRY_DSN=<dsn>
// or via CI/CD environment (never hardcoded). Leave empty to disable Sentry.
const _sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await configureDependencies();
  await initOnboardingFlag();
  Bloc.observer = AppBlocObserver();

  if (_sentryDsn.isNotEmpty) {
    await SentryFlutter.init(
      (options) {
        options.dsn = _sentryDsn;
        options.tracesSampleRate = 0.1;
        options.environment =
            const String.fromEnvironment('APP_ENV', defaultValue: 'production');
      },
      appRunner: () => runApp(const BudgetBookApp()),
    );
  } else {
    runApp(const BudgetBookApp());
  }
}

class AppBlocObserver extends BlocObserver {
  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    debugPrint('${bloc.runtimeType} $transition');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    super.onError(bloc, error, stackTrace);
    debugPrint('${bloc.runtimeType} $error $stackTrace');
  }
}
