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
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: MaterialApp.router(
        title: 'Budget Book',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        routerConfig: _router,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
        ],
        locale: const Locale('ko'),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
