import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:budget_book/app.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/router/app_router.dart';
import 'package:budget_book/core/utils/error_reporter.dart';

void main() async {
  // Sentry disables itself when DSN is empty (built-in behavior).
  await SentryFlutter.init(
    (options) {
      options.dsn =
          const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      options.tracesSampleRate = 0.1;
      options.environment =
          const String.fromEnvironment('ENV', defaultValue: 'local');
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
      usePathUrlStrategy();
      await configureDependencies();
      await initOnboardingFlag();
      Bloc.observer = AppBlocObserver();

      // Global Flutter error handler - catches framework-level errors
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        Sentry.captureException(details.exception, stackTrace: details.stack);
      };

      // Global platform error handler - catches uncaught async errors
      PlatformDispatcher.instance.onError = (error, stack) {
        Sentry.captureException(error, stackTrace: stack);
        return true;
      };

      runApp(const BudgetBookApp());
    },
  );
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
    ErrorReporter.captureException(
      error,
      stackTrace: stackTrace,
      context: 'bloc:${bloc.runtimeType}',
    );
  }
}
