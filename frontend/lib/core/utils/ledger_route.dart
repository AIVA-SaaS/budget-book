/// 장부(거래 탭) 목록 화면으로 가는 URL 을 만드는 **단일 소스**.
///
/// ## 왜 헬퍼인가 (2026-08-10)
///
/// 하네스 `navigation_state` 태그는 인시던트 3건으로 STRUCTURAL_FIX_REQUIRED 상태였고,
/// 3건 모두 뿌리가 같았다 — **화면을 옮길 때 보고 있던 월이 목적지에 따라가지 않는다.**
///
/// - 2026-04-14 예산 3월 → 카드 선택 → 4월 거래 표시
/// - 2026-04-15 홈/예산 월 이동 후 거래 이동 시 현재 월로 리셋
/// - 2026-04-15 월 이동 시 카드 요약이 홈/예산에서 stale
///
/// 두 번째 인시던트가 지정한 재발 방지책이 "year/month 를 **required 파라미터**로 받는
/// 중앙 헬퍼(navigation_helpers.dart) 도입 — 컴파일 타임에 누락 차단" 이었다.
/// 그런데 그 파일은 실제로 만들어진 적이 없었고(2026-08-10 측정: `find lib -name
/// "navigation_helpers*"` → 0건), 각 화면이 URL 을 문자열로 직접 조립하는 상태가
/// 유지됐다. 방지책이 문서로만 남은 것이 3회 재발의 이유다.
///
/// 이 파일이 그 방지책의 실제 이행이다. [ledgerLocation] 의 required [year]/[month]
/// 덕분에 월 누락은 런타임 버그가 아니라 **컴파일 에러**가 된다.
///
/// ## 규칙
///
/// - 장부 목록(`/transactions`)으로 가는 새 진입 경로는 **반드시** 이 함수를 쓴다.
///   `dashboard_page.dart` 에 raw `'/transactions?` 리터럴이 다시 생기면
///   `dashboard_widget_registry_guard_test.dart` 가 실패한다.
/// - `/transactions/create` 와 `/transactions/detail` 은 **다른 라우트**라 대상이 아니다.
///   거래 추가 URL 은 거래 목록 페이지의 `_buildCreateTransactionUrl` 이 단일 소스다.
library;

/// 거래 탭의 뷰 모드. `TransactionListPage` 내부 enum 과 이름이 일치해야 한다
/// (URL 직렬화 값이 `name` 이다).
enum LedgerView { list, calendar, reconciliation }

/// 장부 목록 URL 을 만든다.
///
/// [year]/[month] 는 required — 호출부가 "보고 있던 달" 을 넘기지 않으면 컴파일되지 않는다.
///
/// [view] 를 주면 거래 탭이 그 뷰 모드로 열린다. 주지 않으면 사용자가 마지막으로
/// 쓰던 뷰(SharedPreferences 저장값)가 그대로 유지된다.
String ledgerLocation({
  required int year,
  required int month,
  LedgerView? view,
  String? paymentMethodId,
  String? paymentMethodName,
  String? categoryId,
  String? categoryName,
  String? categoryGroupId,
}) {
  final params = <String, String>{
    'year': '$year',
    'month': '$month',
    if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
    if (paymentMethodName != null) 'paymentMethodName': paymentMethodName,
    if (categoryId != null) 'categoryId': categoryId,
    if (categoryName != null) 'categoryName': categoryName,
    if (categoryGroupId != null) 'categoryGroupId': categoryGroupId,
    if (view != null) 'view': view.name,
  };
  return Uri(path: '/transactions', queryParameters: params).toString();
}

/// URL 의 `view` 값을 [LedgerView] 로 해석한다. 모르는 값은 null (= 저장된 뷰 사용).
LedgerView? parseLedgerView(String? raw) {
  if (raw == null) return null;
  for (final v in LedgerView.values) {
    if (v.name == raw) return v;
  }
  return null;
}

/// 같은 페이지가 새 URL 로 재진입했을 때(=`didUpdateWidget`) 뷰 모드를 바꿔야 하는지 판정.
///
/// 규칙은 이 페이지의 nav 필터 규칙과 **동일**하다(2026-05-26 회귀 fix에서 확립):
/// null→value, value→다른 value 만 변경 신호이고 **value→null 은 무시**한다.
///
/// 왜 value→null 을 무시하나 — 정산 뷰에서 거래를 수정 저장하면
/// `context.go('/transactions?year=Y&month=M')` 로 돌아오는데, 이때 `view` 키가 URL 에서
/// 사라진다. 이것을 "리스트로 돌아가라" 로 해석하면 사용자가 보고 있던 뷰에서 튕긴다.
/// URL 에 nav/view 키가 없다는 것은 "지정하지 않았다" 이지 "초기화하라" 가 아니다.
///
/// 반환값이 null 이면 뷰를 그대로 둔다.
LedgerView? nextLedgerViewOnUpdate({
  required String? previous,
  required String? current,
}) {
  if (current == previous) return null;
  return parseLedgerView(current);
}
