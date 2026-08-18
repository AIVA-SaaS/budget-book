import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/bloc/month_sync_handler.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/auth_interceptor.dart';
import 'package:budget_book/core/router/app_router.dart';
import 'package:budget_book/core/theme/app_theme.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
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
        BlocProvider<MonthCubit>.value(value: getIt<MonthCubit>()),
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
                  // MonthSyncHandler: 월 변경 시 관련 BLoC 자동 reload (중앙화)
                  final wrapped = MonthSyncHandler(child: child!);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobileLayout = constraints.maxWidth <= 768;

                      // ★유효 콘텐츠 폭 — 화면 폭이 아니다. 웹은 아래에서 본문을
                      // kBbContentMaxWidth 칼럼으로 감싸므로, 2560px 화면에서도
                      // 본문이 실제로 쓰는 폭은 960 이다. 이 값으로 판정하지 않으면
                      // 960px 칼럼 안에서 "2560px 데스크톱" 크기로 그린다
                      // (domains/12-ui-scaling.md ★2 — calynda 가 실측한 결함).
                      final contentWidth = isMobileLayout
                          ? constraints.maxWidth
                          : math.min(constraints.maxWidth, kBbContentMaxWidth);

                      // 폭 → 타이포·아이콘·밀도·크롬. 450곳의 `textTheme.*` 가
                      // 코드 변경 없이 여기서 반응하게 된다.
                      final scaled = BbScaleScope(
                        width: contentWidth,
                        child: Builder(
                          builder: (themedContext) => Theme(
                            data: AppTheme.responsive(
                              Theme.of(themedContext),
                              contentWidth,
                            ),
                            child: wrapped,
                          ),
                        ),
                      );

                      // Mobile: no constraint, Web: centered with max width + background
                      if (isMobileLayout) {
                        return scaled;
                      }
                      final bgColor = Theme.of(context).colorScheme.surfaceContainerLowest;
                      return ColoredBox(
                        color: bgColor,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(
                              maxWidth: kBbContentMaxWidth,
                            ),
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
                            child: scaled,
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
