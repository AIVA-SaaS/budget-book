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

void main() {
  late _MockCategoryGroupBloc groupBloc;
  late _MockCategoryBloc categoryBloc;
  late _MockFavoritesBloc favoritesBloc;
  late _MockCoupleBloc coupleBloc;

  final now = DateTime(2026, 4, 20);

  final foodCat1 = Category(
    id: 'c-food-1',
    name: '카페',
    type: 'EXPENSE',
    isDefault: false,
    displayOrder: 0,
    groupId: 'g-food',
    createdAt: now,
  );
  final foodCat2 = Category(
    id: 'c-food-2',
    name: '식당',
    type: 'EXPENSE',
    isDefault: false,
    displayOrder: 1,
    groupId: 'g-food',
    createdAt: now,
  );
  final transportCat = Category(
    id: 'c-transport-1',
    name: '택시',
    type: 'EXPENSE',
    isDefault: false,
    displayOrder: 0,
    groupId: 'g-transport',
    createdAt: now,
  );

  final foodGroup = CategoryGroup(
    id: 'g-food',
    name: '식비',
    budgetType: 'MONTHLY',
    displayOrder: 0,
    isDefault: false,
    categories: [foodCat1, foodCat2],
    createdAt: now,
  );
  final transportGroup = CategoryGroup(
    id: 'g-transport',
    name: '교통',
    budgetType: 'MONTHLY',
    displayOrder: 1,
    isDefault: false,
    categories: [transportCat],
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

    when(() => groupBloc.state)
        .thenReturn(CategoryGroupLoaded([foodGroup, transportGroup]));
    when(() => categoryBloc.state).thenReturn(const CategoryInitial());
    when(() => favoritesBloc.state)
        .thenReturn(const FavoritesLoaded(Favorites.empty));
    when(() => coupleBloc.state).thenReturn(const CoupleInitial());

    for (final type in [CategoryGroupBloc, CategoryBloc, FavoritesBloc, CoupleBloc]) {
      // no-op placeholder for future typed unregister
      type.toString();
    }

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

  Future<void> showMulti(
    WidgetTester tester, {
    Set<String> initialCategoryIds = const {},
    Set<String> initialGroupIds = const {},
    required void Function(Set<String>, Set<String>) onApplyMulti,
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
                  mode: CategorySelectionMode.multiCategoryWithGroup,
                  initialCategoryIds: initialCategoryIds,
                  initialGroupIds: initialGroupIds,
                  onApplyMulti: onApplyMulti,
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

  Future<void> showSingle(
    WidgetTester tester, {
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

  testWidgets('multi: group checkbox cascades to child categories',
      (tester) async {
    Set<String>? captureCats;
    Set<String>? captureGroups;
    await showMulti(
      tester,
      onApplyMulti: (cats, groups) {
        captureCats = cats;
        captureGroups = groups;
      },
    );

    // Food group row is visible; find its Checkbox (first Checkbox in group row).
    // Food group has 2 children → count starts 0.
    expect(find.text('적용 (0)'), findsOneWidget);

    // Tap group header's Checkbox by tapping on "식비" folder row's checkbox.
    // There are 2 group checkboxes (식비, 교통). Tap the first by tapping the
    // Checkbox widget whose ancestor Row contains the text '식비'.
    final foodGroupCheckbox = find.descendant(
      of: find.ancestor(
        of: find.text('식비'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Checkbox),
    );
    await tester.tap(foodGroupCheckbox.first);
    await tester.pumpAndSettle();

    // Group id 'g-food' + 2 child cats = 3 selected
    expect(find.text('적용 (3)'), findsOneWidget);

    await tester.tap(find.text('적용 (3)'));
    await tester.pumpAndSettle();

    expect(captureGroups, {'g-food'});
    expect(captureCats, {'c-food-1', 'c-food-2'});
  });

  testWidgets('multi: individual category checkbox updates temp set',
      (tester) async {
    Set<String>? captureCats;
    Set<String>? captureGroups;
    await showMulti(
      tester,
      onApplyMulti: (cats, groups) {
        captureCats = cats;
        captureGroups = groups;
      },
    );

    // Expand 교통 group first by tapping the header.
    await tester.tap(find.text('교통'));
    await tester.pumpAndSettle();

    // Now 택시 tile is visible → tap it to toggle.
    await tester.tap(find.text('택시'));
    await tester.pumpAndSettle();

    expect(find.text('적용 (1)'), findsOneWidget);

    await tester.tap(find.text('적용 (1)'));
    await tester.pumpAndSettle();

    expect(captureCats, {'c-transport-1'});
    expect(captureGroups, isEmpty);
  });

  testWidgets('multi: apply fires with both sets correctly', (tester) async {
    int callCount = 0;
    late Set<String> cats;
    late Set<String> groups;
    await showMulti(
      tester,
      initialCategoryIds: const {'c-food-1'},
      initialGroupIds: const {'g-transport'},
      onApplyMulti: (c, g) {
        callCount++;
        cats = c;
        groups = g;
      },
    );

    // initial count: 1 cat + 1 group = 2
    expect(find.text('적용 (2)'), findsOneWidget);

    await tester.tap(find.text('적용 (2)'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(cats, {'c-food-1'});
    expect(groups, {'g-transport'});
  });

  testWidgets('singleCategory regression: tap on category fires onSelected',
      (tester) async {
    Category? selected;
    await showSingle(tester, onSelected: (c) => selected = c);

    // Expand food group
    await tester.tap(find.text('식비'));
    await tester.pumpAndSettle();

    // Apply button should NOT be present in single mode
    expect(find.textContaining('적용 ('), findsNothing);

    await tester.tap(find.text('카페'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'c-food-1');
  });
}
