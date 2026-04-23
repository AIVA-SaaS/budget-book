import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';
import 'package:budget_book/features/preference/domain/entities/favorites.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_event.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_state.dart';

class _MockCategoryGroupBloc
    extends MockBloc<CategoryGroupEvent, CategoryGroupState>
    implements CategoryGroupBloc {}

class _MockCategoryBloc extends MockBloc<CategoryEvent, CategoryState>
    implements CategoryBloc {}

class _MockFavoritesBloc extends MockBloc<FavoritesEvent, FavoritesState>
    implements FavoritesBloc {}

class _MockCoupleBloc extends MockBloc<CoupleEvent, CoupleState>
    implements CoupleBloc {}

/// Phase 23 PR-X3 — tests for the pinned "잔액 조정" virtual option in the
/// category selector sheet.
void main() {
  late _MockCategoryGroupBloc groupBloc;
  late _MockCategoryBloc categoryBloc;
  late _MockFavoritesBloc favoritesBloc;
  late _MockCoupleBloc coupleBloc;

  final now = DateTime(2026, 4, 22);

  final foodCat = Category(
    id: 'c-food-1',
    name: '카페',
    type: 'EXPENSE',
    isDefault: false,
    displayOrder: 0,
    groupId: 'g-food',
    createdAt: now,
  );
  final foodGroup = CategoryGroup(
    id: 'g-food',
    name: '식비',
    budgetType: 'MONTHLY',
    displayOrder: 0,
    isDefault: false,
    categories: [foodCat],
    createdAt: now,
  );

  setUpAll(() {
    registerFallbackValue(const LoadCategoryGroups());
    registerFallbackValue(const LoadCategories());
    registerFallbackValue(const LoadFavorites());
    registerFallbackValue(const LoadCouple());
  });

  setUp(() {
    groupBloc = _MockCategoryGroupBloc();
    categoryBloc = _MockCategoryBloc();
    favoritesBloc = _MockFavoritesBloc();
    coupleBloc = _MockCoupleBloc();

    when(() => groupBloc.state).thenReturn(CategoryGroupLoaded([foodGroup]));
    when(() => categoryBloc.state).thenReturn(const CategoryInitial());
    when(() => favoritesBloc.state)
        .thenReturn(const FavoritesLoaded(Favorites.empty));
    when(() => coupleBloc.state).thenReturn(const CoupleInitial());

    if (getIt.isRegistered<CategoryGroupBloc>()) {
      getIt.unregister<CategoryGroupBloc>();
    }
    if (getIt.isRegistered<CategoryBloc>()) {
      getIt.unregister<CategoryBloc>();
    }
    if (getIt.isRegistered<FavoritesBloc>()) {
      getIt.unregister<FavoritesBloc>();
    }
    if (getIt.isRegistered<CoupleBloc>()) {
      getIt.unregister<CoupleBloc>();
    }

    getIt.registerSingleton<CategoryGroupBloc>(groupBloc);
    getIt.registerSingleton<CategoryBloc>(categoryBloc);
    getIt.registerSingleton<FavoritesBloc>(favoritesBloc);
    getIt.registerSingleton<CoupleBloc>(coupleBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<CategoryGroupBloc>()) {
      getIt.unregister<CategoryGroupBloc>();
    }
    if (getIt.isRegistered<CategoryBloc>()) {
      getIt.unregister<CategoryBloc>();
    }
    if (getIt.isRegistered<FavoritesBloc>()) {
      getIt.unregister<FavoritesBloc>();
    }
    if (getIt.isRegistered<CoupleBloc>()) {
      getIt.unregister<CoupleBloc>();
    }
  });

  Future<void> showSheet(
    WidgetTester tester, {
    required bool showAdjustmentOption,
    required ValueChanged<Category?> onSelected,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => CategoryGroupSelectorSheet(
                  categoryType: 'EXPENSE',
                  showAdjustmentOption: showAdjustmentOption,
                  onSelected: onSelected,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'pinned "잔액 조정" option is rendered when showAdjustmentOption=true',
    (tester) async {
      await showSheet(
        tester,
        showAdjustmentOption: true,
        onSelected: (_) {},
      );

      expect(find.byKey(const Key('adjustment-pinned-option')), findsOneWidget);
      expect(find.text('잔액 조정'), findsOneWidget);
    },
  );

  testWidgets(
    'pinned option is NOT rendered when showAdjustmentOption=false',
    (tester) async {
      await showSheet(
        tester,
        showAdjustmentOption: false,
        onSelected: (_) {},
      );

      expect(find.byKey(const Key('adjustment-pinned-option')), findsNothing);
      expect(find.text('잔액 조정'), findsNothing);
    },
  );

  testWidgets(
    'tapping "잔액 조정" fires onSelected with sentinel category',
    (tester) async {
      Category? captured;
      await showSheet(
        tester,
        showAdjustmentOption: true,
        onSelected: (c) => captured = c,
      );

      await tester.tap(find.byKey(const Key('adjustment-pinned-option')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.id, kAdjustmentSentinel);
      expect(captured!.type, 'ADJUSTMENT');
      expect(captured!.name, '잔액 조정');
    },
  );
}
