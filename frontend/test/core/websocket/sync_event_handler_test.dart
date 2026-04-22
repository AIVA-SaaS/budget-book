import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dartz/dartz.dart';

import 'package:budget_book/core/websocket/sync_event.dart';
import 'package:budget_book/core/websocket/sync_event_handler.dart';
import 'package:budget_book/core/error/failure.dart';

import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/domain/repositories/category_repository.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/domain/repositories/payment_method_repository.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/domain/repositories/category_group_repository.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart'
    as tx;
import 'package:budget_book/features/transaction/domain/entities/page_response.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';

class MockTransactionRepository extends Mock
    implements TransactionRepository {}

class MockBudgetRepository extends Mock implements BudgetRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockPaymentMethodRepository extends Mock
    implements PaymentMethodRepository {}

class MockCategoryGroupRepository extends Mock
    implements CategoryGroupRepository {}

void main() {
  late GetIt testGetIt;
  late SyncEventHandler handler;
  late MockTransactionRepository mockTransactionRepo;
  late MockBudgetRepository mockBudgetRepo;
  late MockCategoryRepository mockCategoryRepo;
  late MockPaymentMethodRepository mockPaymentMethodRepo;
  late MockCategoryGroupRepository mockCategoryGroupRepo;
  late TransactionBloc transactionBloc;
  late BudgetBloc budgetBloc;
  late CategoryBloc categoryBloc;
  late PaymentMethodBloc paymentMethodBloc;
  late CategoryGroupBloc categoryGroupBloc;

  setUp(() {
    testGetIt = GetIt.asNewInstance();

    mockTransactionRepo = MockTransactionRepository();
    mockBudgetRepo = MockBudgetRepository();
    mockCategoryRepo = MockCategoryRepository();
    mockPaymentMethodRepo = MockPaymentMethodRepository();
    mockCategoryGroupRepo = MockCategoryGroupRepository();

    // Stub all repository methods using mocktail's `any()`
    when(() => mockTransactionRepo.getTransactions(
          year: any(named: 'year'),
          month: any(named: 'month'),
          type: any(named: 'type'),
          transactionTypes: any(named: 'transactionTypes'),
          categoryId: any(named: 'categoryId'),
          page: any(named: 'page'),
          size: any(named: 'size'),
        )).thenAnswer((_) async => const Right(
          PageResponse<tx.Transaction>(
            content: [],
            page: 0,
            size: 20,
            totalElements: 0,
            totalPages: 0,
            first: true,
            last: true,
          ),
        ));

    when(() => mockBudgetRepo.getBudgets(
          year: any(named: 'year'),
          month: any(named: 'month'),
        )).thenAnswer(
        (_) async => const Right<Failure, List<Budget>>([]));

    when(() => mockBudgetRepo.getBudgetSummary(
          year: any(named: 'year'),
          month: any(named: 'month'),
        )).thenAnswer((_) async => const Right<Failure, BudgetSummary>(
          BudgetSummary(
            yearMonth: '2026-03',
            totalBudget: 0,
            totalSpent: 0,
            items: [],
          ),
        ));

    when(() => mockCategoryRepo.getCategories(type: any(named: 'type')))
        .thenAnswer(
            (_) async => const Right<Failure, List<Category>>([]));

    when(() => mockPaymentMethodRepo.getPaymentMethods()).thenAnswer(
        (_) async => const Right<Failure, List<PaymentMethod>>([]));

    when(() => mockCategoryGroupRepo.getCategoryGroups()).thenAnswer(
        (_) async => const Right<Failure, List<CategoryGroup>>([]));

    transactionBloc = TransactionBloc(
      transactionRepository: mockTransactionRepo,
    );
    budgetBloc = BudgetBloc(
      budgetRepository: mockBudgetRepo,
    );
    categoryBloc = CategoryBloc(
      categoryRepository: mockCategoryRepo,
    );
    paymentMethodBloc = PaymentMethodBloc(
      paymentMethodRepository: mockPaymentMethodRepo,
    );
    categoryGroupBloc = CategoryGroupBloc(
      categoryGroupRepository: mockCategoryGroupRepo,
    );

    testGetIt.registerFactory<TransactionBloc>(() => transactionBloc);
    testGetIt.registerFactory<BudgetBloc>(() => budgetBloc);
    testGetIt.registerFactory<CategoryBloc>(() => categoryBloc);
    testGetIt.registerFactory<PaymentMethodBloc>(() => paymentMethodBloc);
    testGetIt.registerFactory<CategoryGroupBloc>(() => categoryGroupBloc);

    handler = SyncEventHandler(getIt: testGetIt);
  });

  tearDown(() async {
    await transactionBloc.close();
    await budgetBloc.close();
    await categoryBloc.close();
    await paymentMethodBloc.close();
    await categoryGroupBloc.close();
    testGetIt.reset();
  });

  SyncEvent createEvent(String entityType, {String authorId = 'user-2'}) {
    return SyncEvent(
      type: 'CREATED',
      entityType: entityType,
      entityId: 'entity-1',
      coupleId: 'couple-1',
      authorId: authorId,
      timestamp: DateTime.parse('2026-03-12T10:00:00Z'),
    );
  }

  group('SyncEventHandler', () {
    test('skips self-authored events', () async {
      final event = createEvent('TRANSACTION', authorId: 'user-1');

      handler.handle(event, 'user-1');

      await Future.delayed(const Duration(milliseconds: 100));

      // TransactionRepository should NOT be called for self-authored events
      verifyZeroInteractions(mockTransactionRepo);
    });

    test('handles TRANSACTION entity type', () async {
      handler.handle(createEvent('TRANSACTION'), 'user-1');
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockTransactionRepo.getTransactions(
            year: any(named: 'year'),
            month: any(named: 'month'),
            type: any(named: 'type'),
            transactionTypes: any(named: 'transactionTypes'),
            categoryId: any(named: 'categoryId'),
            page: any(named: 'page'),
            size: any(named: 'size'),
          )).called(1);
    });

    test('handles BUDGET entity type', () async {
      handler.handle(createEvent('BUDGET'), 'user-1');
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockBudgetRepo.getBudgets(
            year: any(named: 'year'),
            month: any(named: 'month'),
          )).called(1);
    });

    test('handles CATEGORY entity type', () async {
      handler.handle(createEvent('CATEGORY'), 'user-1');
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockCategoryRepo.getCategories(
            type: any(named: 'type'),
          )).called(1);
    });

    test('handles PAYMENT_METHOD entity type', () async {
      handler.handle(createEvent('PAYMENT_METHOD'), 'user-1');
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockPaymentMethodRepo.getPaymentMethods()).called(1);
    });

    test('handles CATEGORY_GROUP entity type', () async {
      handler.handle(createEvent('CATEGORY_GROUP'), 'user-1');
      await Future.delayed(const Duration(milliseconds: 100));

      verify(() => mockCategoryGroupRepo.getCategoryGroups()).called(1);
    });

    test('handles unknown entity type without error', () {
      handler.handle(createEvent('UNKNOWN_TYPE'), 'user-1');
      // Should not throw
    });
  });
}
