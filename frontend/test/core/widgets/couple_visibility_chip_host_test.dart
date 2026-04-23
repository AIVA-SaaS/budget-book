import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/bloc/visibility_cubit.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/main_shell_page.dart';
import 'package:budget_book/features/couple/domain/entities/couple.dart';
import 'package:budget_book/features/couple/domain/entities/user_summary.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';

class _MockCoupleBloc extends MockBloc<CoupleEvent, CoupleState>
    implements CoupleBloc {}

Couple _coupleWithPartner() => Couple(
      id: 'c1',
      partner: const UserSummary(id: 'u2', nickname: '파트너'),
      status: 'ACTIVE',
      createdAt: DateTime(2026, 1, 1),
    );

Couple _coupleWithoutPartner() => Couple(
      id: 'c1',
      partner: null,
      status: 'ACTIVE',
      createdAt: DateTime(2026, 1, 1),
    );

Widget _harness(VisibilityCubit cubit) => MaterialApp(
      home: Scaffold(
        body: BlocProvider<VisibilityCubit>.value(
          value: cubit,
          child: const CoupleVisibilityChipHost(),
        ),
      ),
    );

void main() {
  late _MockCoupleBloc mockCoupleBloc;
  late VisibilityCubit visibilityCubit;

  setUp(() {
    mockCoupleBloc = _MockCoupleBloc();
    visibilityCubit = VisibilityCubit();

    if (getIt.isRegistered<CoupleBloc>()) {
      getIt.unregister<CoupleBloc>();
    }
    getIt.registerSingleton<CoupleBloc>(mockCoupleBloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<CoupleBloc>()) {
      getIt.unregister<CoupleBloc>();
    }
    await visibilityCubit.close();
  });

  group('CoupleVisibilityChipHost', () {
    testWidgets('renders chip row when in couple mode', (tester) async {
      when(() => mockCoupleBloc.state)
          .thenReturn(CoupleLinked(_coupleWithPartner()));

      await tester.pumpWidget(_harness(visibilityCubit));

      expect(find.byKey(const ValueKey('global-visibility-chip-row')),
          findsOneWidget);
      expect(find.text('모두'), findsOneWidget);
      expect(find.text('공유'), findsOneWidget);
      expect(find.text('내 것'), findsOneWidget);
    });

    testWidgets('hides chip row when NOT in couple mode (self-couple)',
        (tester) async {
      when(() => mockCoupleBloc.state)
          .thenReturn(CoupleLinked(_coupleWithoutPartner()));

      await tester.pumpWidget(_harness(visibilityCubit));

      expect(find.byKey(const ValueKey('global-visibility-chip-row')),
          findsNothing);
      expect(find.byKey(const ValueKey('global-visibility-chip-row-hidden')),
          findsOneWidget);
      expect(find.text('모두'), findsNothing);
      expect(find.text('공유'), findsNothing);
    });

    testWidgets('hides chip row when CoupleNotLinked', (tester) async {
      when(() => mockCoupleBloc.state).thenReturn(const CoupleNotLinked());

      await tester.pumpWidget(_harness(visibilityCubit));

      expect(find.byKey(const ValueKey('global-visibility-chip-row')),
          findsNothing);
      expect(find.byKey(const ValueKey('global-visibility-chip-row-hidden')),
          findsOneWidget);
    });

    testWidgets(
        'tapping "공유" chip updates VisibilityCubit state to SHARED',
        (tester) async {
      when(() => mockCoupleBloc.state)
          .thenReturn(CoupleLinked(_coupleWithPartner()));

      await tester.pumpWidget(_harness(visibilityCubit));
      expect(visibilityCubit.state, isNull);

      await tester.tap(find.text('공유'));
      await tester.pumpAndSettle();

      expect(visibilityCubit.state, 'SHARED');
    });

    testWidgets(
        'tapping "내 것" then "모두" returns VisibilityCubit state to null',
        (tester) async {
      when(() => mockCoupleBloc.state)
          .thenReturn(CoupleLinked(_coupleWithPartner()));

      await tester.pumpWidget(_harness(visibilityCubit));

      await tester.tap(find.text('내 것'));
      await tester.pumpAndSettle();
      expect(visibilityCubit.state, 'PRIVATE');

      await tester.tap(find.text('모두'));
      await tester.pumpAndSettle();
      expect(visibilityCubit.state, isNull);
    });
  });
}
