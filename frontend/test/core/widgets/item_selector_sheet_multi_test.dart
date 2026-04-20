import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/features/preference/domain/entities/favorites.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_event.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_state.dart';

class _MockFavoritesBloc extends MockBloc<FavoritesEvent, FavoritesState>
    implements FavoritesBloc {}

void main() {
  late _MockFavoritesBloc favoritesBloc;

  setUpAll(() {
    registerFallbackValue(const LoadFavorites());
  });

  setUp(() {
    favoritesBloc = _MockFavoritesBloc();
    when(() => favoritesBloc.state)
        .thenReturn(const FavoritesLoaded(Favorites.empty));

    if (getIt.isRegistered<FavoritesBloc>()) {
      getIt.unregister<FavoritesBloc>();
    }
    getIt.registerSingleton<FavoritesBloc>(favoritesBloc);
  });

  tearDown(() {
    if (getIt.isRegistered<FavoritesBloc>()) {
      getIt.unregister<FavoritesBloc>();
    }
  });

  final sampleItems = const [
    SelectorItem(id: 'a', label: 'Alpha', leadingIcon: Icons.label, displayOrder: 0),
    SelectorItem(id: 'b', label: 'Bravo', leadingIcon: Icons.label, displayOrder: 1),
    SelectorItem(id: 'c', label: 'Charlie', leadingIcon: Icons.label, displayOrder: 2),
  ];

  Future<void> showMulti(
    WidgetTester tester, {
    Set<String> initial = const {},
    required void Function(Set<String>) onApply,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ItemSelectorSheet(
                  title: '테스트',
                  items: sampleItems,
                  mode: SelectionMode.multi,
                  initialSelectedIds: initial,
                  onApplyMulti: onApply,
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
    required ValueChanged<SelectorItem?> onSelected,
    String? selectedId,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => ItemSelectorSheet(
                  title: '테스트',
                  items: sampleItems,
                  selectedId: selectedId,
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

  testWidgets('multi: checkbox tap adds id to temp set', (tester) async {
    Set<String>? applied;
    await showMulti(tester, onApply: (ids) => applied = ids);

    // Apply button starts at "적용 (0)"
    expect(find.text('적용 (0)'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(find.text('적용 (1)'), findsOneWidget);

    await tester.tap(find.text('Bravo'));
    await tester.pump();
    expect(find.text('적용 (2)'), findsOneWidget);

    await tester.tap(find.text('적용 (2)'));
    await tester.pumpAndSettle();

    expect(applied, {'a', 'b'});
  });

  testWidgets('multi: apply is called exactly once with correct set', (tester) async {
    int callCount = 0;
    Set<String>? captured;
    await showMulti(
      tester,
      initial: const {'c'},
      onApply: (ids) {
        callCount++;
        captured = ids;
      },
    );

    expect(find.text('적용 (1)'), findsOneWidget);

    await tester.tap(find.text('Alpha'));
    await tester.pump();
    expect(find.text('적용 (2)'), findsOneWidget);

    await tester.tap(find.text('적용 (2)'));
    await tester.pumpAndSettle();

    expect(callCount, 1);
    expect(captured, {'a', 'c'});
  });

  testWidgets('multi: "전체 해제" clears temp set', (tester) async {
    Set<String>? applied;
    await showMulti(
      tester,
      initial: const {'a', 'b', 'c'},
      onApply: (ids) => applied = ids,
    );
    expect(find.text('적용 (3)'), findsOneWidget);

    await tester.tap(find.text('전체 해제'));
    await tester.pump();
    expect(find.text('적용 (0)'), findsOneWidget);

    await tester.tap(find.text('적용 (0)'));
    await tester.pumpAndSettle();
    expect(applied, isEmpty);
  });

  testWidgets('single regression: tap fires onSelected and pops', (tester) async {
    SelectorItem? selected;
    bool called = false;
    await showSingle(
      tester,
      onSelected: (item) {
        called = true;
        selected = item;
      },
    );

    // Sheet is visible
    expect(find.text('Bravo'), findsOneWidget);
    // Apply bar should NOT appear in single mode
    expect(find.textContaining('적용 ('), findsNothing);

    await tester.tap(find.text('Bravo'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(selected?.id, 'b');
    // Dialog popped
    expect(find.text('Bravo'), findsNothing);
  });
}
