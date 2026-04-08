import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_category.dart';
import 'package:budget_book/features/transaction/presentation/pages/transaction_detail_page.dart';

class MockTransactionBloc
    extends MockBloc<TransactionEvent, TransactionState>
    implements TransactionBloc {}

class MockTransactionRepository extends Mock implements TransactionRepository {}

void main() {
  late MockTransactionBloc mockBloc;
  late MockTransactionRepository mockRepo;

  setUp(() {
    mockBloc = MockTransactionBloc();
    mockRepo = MockTransactionRepository();
    when(() => mockBloc.transactionRepository).thenReturn(mockRepo);
  });

  final testTransaction = Transaction(
    id: 'txn-1',
    coupleId: 'couple-1',
    author: const TransactionAuthor(
      id: 'user-1',
      nickname: '홍길동',
    ),
    category: const TransactionCategory(
      id: 'cat-1',
      name: '식비',
      type: 'EXPENSE',
      icon: 'restaurant',
      color: '#FF5733',
      groupId: 'group-1',
      groupName: '생활',
    ),
    type: 'EXPENSE',
    amount: 35000,
    description: '점심 식사',
    memo: '회사 근처 맛집',
    transactionDate: '2026-03-15',
    paymentMethodName: '신한카드',
    pocketName: '생활비',
    createdAt: DateTime(2026, 3, 15, 12, 30),
    updatedAt: DateTime(2026, 3, 15, 12, 30),
  );

  Widget createTestWidget({String transactionId = 'txn-1'}) {
    return MaterialApp(
      home: BlocProvider<TransactionBloc>.value(
        value: mockBloc,
        child: TransactionDetailPage(transactionId: transactionId),
      ),
    );
  }

  group('TransactionDetailPage', () {
    testWidgets('shows app bar with title and actions', (tester) async {
      when(() => mockBloc.state).thenReturn(TransactionLoaded(
        transactions: [testTransaction],
        year: 2026,
        month: 3,
        totalElements: 1,
        hasMore: false,
      ));
      await tester.pumpWidget(createTestWidget());

      expect(find.text('거래 상세'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });

    testWidgets('shows transaction details correctly', (tester) async {
      when(() => mockBloc.state).thenReturn(TransactionLoaded(
        transactions: [testTransaction],
        year: 2026,
        month: 3,
        totalElements: 1,
        hasMore: false,
      ));
      await tester.pumpWidget(createTestWidget());

      expect(find.text('점심 식사'), findsOneWidget);
      expect(find.text('생활 > 식비'), findsOneWidget);
      expect(find.text('신한카드'), findsOneWidget);
      expect(find.text('생활비'), findsOneWidget);
      expect(find.text('회사 근처 맛집'), findsOneWidget);
      expect(find.text('홍길동'), findsOneWidget);
      expect(find.text('지출'), findsOneWidget);
    });

    testWidgets('falls back to API load when transaction is missing from state',
        (tester) async {
      when(() => mockBloc.state).thenReturn(const TransactionLoaded(
        transactions: [],
        year: 2026,
        month: 3,
        totalElements: 0,
        hasMore: false,
      ));
      when(() => mockRepo.getTransaction('non-existent'))
          .thenAnswer((_) async => Left(ServerFailure('Not found')));
      await tester.pumpWidget(
          createTestWidget(transactionId: 'non-existent'));
      // Initially shows loading spinner (API call in progress)
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // After API responds with failure
      await tester.pumpAndSettle();
      expect(find.text('Not found'), findsOneWidget);
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      when(() => mockBloc.state).thenReturn(TransactionLoaded(
        transactions: [testTransaction],
        year: 2026,
        month: 3,
        totalElements: 1,
        hasMore: false,
      ));
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(find.text('거래 삭제'), findsOneWidget);
      expect(find.text('정말 삭제하시겠습니까?'), findsOneWidget);
      expect(find.text('취소'), findsOneWidget);
      expect(find.text('삭제'), findsOneWidget);
    });
  });
}
