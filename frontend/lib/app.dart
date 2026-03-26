import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/auth_interceptor.dart';
import 'package:budget_book/core/router/app_router.dart';
import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:budget_book/features/settings/presentation/cubit/locale_cubit.dart';

class BudgetBookApp extends StatefulWidget {
  const BudgetBookApp({super.key});

  @override
  State<BudgetBookApp> createState() => _BudgetBookAppState();
}

class _BudgetBookAppState extends State<BudgetBookApp> {
  late final AuthBloc _authBloc;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = getIt<AuthBloc>()..add(const AuthCheckRequested());
    _router = createAppRouter(_authBloc);
  }

  @override
  void dispose() {
    _router.dispose();
    // Singleton BLoCs are disposed via GetIt's dispose callbacks
    // when disposeAllSingletons() is called (e.g., in tests or app shutdown).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: _authBloc),
        BlocProvider<ThemeCubit>.value(value: getIt<ThemeCubit>()),
        BlocProvider<LocaleCubit>.value(value: getIt<LocaleCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale?>(
            builder: (context, locale) {
              return MaterialApp.router(
                title: 'Budget Book',
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: themeMode,
                scaffoldMessengerKey: rootScaffoldMessengerKey,
                routerConfig: _router,
                builder: (context, child) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Mobile: no constraint, Web: centered with max width + background
                      if (constraints.maxWidth <= 768) {
                        return child!;
                      }
                      final bgColor = Theme.of(context).colorScheme.surfaceContainerLowest;
                      return ColoredBox(
                        color: bgColor,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 960),
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 24,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        ),
                      );
                    },
                  );
                },
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('ko'),
                  Locale('en'),
                ],
                locale: locale,
                debugShowCheckedModeBanner: false,
              );
            },
          );
        },
      ),
    );
  }
}
