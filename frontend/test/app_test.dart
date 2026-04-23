import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/app.dart';
import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:budget_book/features/settings/presentation/cubit/locale_cubit.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  testWidgets('BudgetBookApp renders login page with all elements',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());

    await GetIt.instance.reset();
    GetIt.instance.registerFactory<AuthBloc>(() => mockAuthBloc);
    GetIt.instance.registerLazySingleton<ThemeCubit>(() => ThemeCubit());
    GetIt.instance.registerLazySingleton<LocaleCubit>(() => LocaleCubit());
    GetIt.instance.registerLazySingleton<MonthCubit>(() => MonthCubit());

    await tester.pumpWidget(const BudgetBookApp());
    await tester.pump();

    // App title and subtitle
    expect(find.text('Budget Book'), findsOneWidget);
    expect(find.text('스마트 가계부'), findsOneWidget);

    // Login buttons
    expect(find.text('Google(으)로 로그인'), findsOneWidget);
    expect(find.text('카카오(으)로 로그인'), findsOneWidget);

    // Footer
    expect(find.text('소셜 계정으로 간편하게 시작하세요'), findsOneWidget);

    await GetIt.instance.reset();
  });
}
