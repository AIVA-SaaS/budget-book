import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/app.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';

class MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  testWidgets('BudgetBookApp renders login page with all elements',
      (tester) async {
    final mockAuthBloc = MockAuthBloc();
    when(() => mockAuthBloc.state).thenReturn(const AuthUnauthenticated());

    await GetIt.instance.reset();
    GetIt.instance.registerFactory<AuthBloc>(() => mockAuthBloc);

    await tester.pumpWidget(const BudgetBookApp());
    await tester.pump();

    // App title and subtitle
    expect(find.text('Budget Book'), findsOneWidget);
    expect(find.text('부부 공유 가계부'), findsOneWidget);

    // Login buttons
    expect(find.text('Google(으)로 로그인'), findsOneWidget);
    expect(find.text('카카오(으)로 로그인'), findsOneWidget);

    // Footer
    expect(find.text('소셜 계정으로 간편하게 시작하세요'), findsOneWidget);

    await GetIt.instance.reset();
  });
}
