import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 이체 ↔ 거래 변환 배선 가드 (2026-08-09).
///
/// 두 폼 페이지를 실제로 띄우려면 BLoC 6종 + DI + 라우터가 필요해, 선언 자체를 고정한다
/// (`calendar_day_sheet_add_test.dart` / `view_mode_toggle_guard_test.dart` 와 같은 방식).
///
/// 지키려는 것은 **양방향 대칭**이다. 과거 정방향(거래 → 이체)은 거래·이체 BLoC 만 리로드하고
/// 대시보드·결제수단은 빠뜨려, 변환 직후 월 합계와 자산 잔액이 갱신되지 않았다. 역방향만
/// 고치면 또 갈라지므로 두 방향이 같은 헬퍼를 쓰도록 강제한다.
void main() {
  final transactionForm = File(
    'lib/features/transaction/presentation/pages/transaction_form_page.dart',
  ).readAsStringSync();
  final transferForm = File(
    'lib/features/transfer/presentation/pages/transfer_form_page.dart',
  ).readAsStringSync();

  String bodyOf(String source, String signature) {
    final start = source.indexOf(signature);
    expect(start, isNonNegative, reason: '$signature 를 찾지 못했다');
    // 클래스 멤버의 닫는 중괄호(들여쓰기 2칸 + 단독 줄)까지를 본문으로 본다.
    // `\n  }` 만 찾으면 여러 줄 파라미터 목록의 `  }) async {` 에 먼저 걸린다.
    final end = source.indexOf('\n  }\n', start + signature.length);
    return source.substring(start, end == -1 ? source.length : end);
  }

  group('변환 성공 후 리로드', () {
    test('양방향 모두 _reloadAfterConversion 을 경유한다', () {
      expect(bodyOf(transactionForm, 'Future<void> _convertToTransfer(')
          .contains('_reloadAfterConversion('), isTrue,
          reason: '정방향이 공통 헬퍼를 안 쓰면 대시보드·결제수단 리로드가 다시 빠진다');
      expect(bodyOf(transactionForm, 'Future<void> _convertToTransaction(')
          .contains('_reloadAfterConversion('), isTrue,
          reason: '역방향이 공통 헬퍼를 안 쓰면 두 방향이 갈라진다');
    });

    test('헬퍼가 네 BLoC 을 모두 갱신한다', () {
      final helper = bodyOf(transactionForm, 'void _reloadAfterConversion(');
      // 거래·이체: 장부는 두 스트림 병합 / 대시보드: 월 합계 / 결제수단: 자산 잔액.
      expect(helper.contains('LoadTransactions.fromFilter('), isTrue);
      expect(helper.contains('LoadTransfers('), isTrue);
      expect(helper.contains('LoadDashboard('), isTrue);
      expect(helper.contains('LoadPaymentMethods('), isTrue);
    });
  });

  group('이체 폼 유형 선택기', () {
    test('지출/수입 선택은 거래 폼으로 보낸다 (피커 복제 금지)', () {
      final body = bodyOf(transferForm, 'void _onTypeSelected(');
      expect(body.contains('/transactions/create'), isTrue,
          reason: '이체 폼에서 직접 변환하면 카테고리·포켓 피커가 두 벌이 된다');
      expect(body.contains('convertFromTransferId='), isTrue,
          reason: 'query param 이 아니면 새로고침 시 변환 대상이 유실된다');
      expect(body.contains('tab='), isTrue,
          reason: '탭을 지정하지 않으면 지출/수입 선택이 폼에 반영되지 않는다');
    });

    test('카드 결제 이체에는 선택기를 노출하지 않는다', () {
      final body = bodyOf(transferForm, 'bool get _showsTypeSelector =>');
      expect(body.contains('TransferKind.cardSettlement'), isTrue,
          reason: '서버가 400 으로 막는 경로를 UI 가 열어두면 안 된다');
    });
  });

  group('역변환 모드 폼', () {
    test('저장은 CreateTransaction 이 아니라 변환 API 를 탄다', () {
      final body = bodyOf(transactionForm, 'void _onSubmit() {');
      final convertIdx = body.indexOf('_isConvertingFromTransfer');
      final createIdx = body.indexOf('CreateTransaction(');
      expect(convertIdx, isNonNegative,
          reason: '역변환 분기가 없으면 이체와 거래가 둘 다 남아 이중 계상된다');
      expect(convertIdx < createIdx, isTrue,
          reason: '분기가 CreateTransaction 뒤에 있으면 도달하지 않는다');
    });

    test('역변환 모드에서는 이체 탭을 숨긴다', () {
      expect(transactionForm.contains(
          'bool get _hidesTransferTab => isEditing || _isConvertingFromTransfer'),
          isTrue,
          reason: 'TabController.length 와 tabs 목록이 같은 조건을 써야 한다');
    });
  });
}
