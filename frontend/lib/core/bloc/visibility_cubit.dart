import 'package:flutter_bloc/flutter_bloc.dart';

/// 전역 공개범위(visibility) 상태 — 커플 모드 전용.
///
/// 상태 값:
///   - `null`  = "모두" (= BE 기본 동작, 공유 + 본인 개인 동시 표시)
///   - `'SHARED'`  = 공유
///   - `'PRIVATE'` = 내 것(본인 개인)
///
/// Phase 23 PR-X8 범위: **3-옵션** (`모두 / 공유 / 내 것`).
/// "상대 것"(partner's private)은 현재 백엔드가 지원하지 않아 Phase-2 로 연기.
///
/// 모든 월·필터 의존 BLoC은 `VisibilitySyncHandler` 를 통해 이 Cubit 상태 변화에
/// 반응하여 재조회한다. 개인 모드(비-커플)에선 UI 가 이 Cubit 을 렌더하지 않고
/// 상태도 null 에 고정되므로 기존 동작과 동일하다.
class VisibilityCubit extends Cubit<String?> {
  VisibilityCubit() : super(null);

  /// 공개범위 변경. 같은 값이면 emit 생략.
  void change(String? visibility) {
    if (state == visibility) return;
    emit(visibility);
  }

  /// "모두"로 초기화.
  void clear() {
    if (state == null) return;
    emit(null);
  }
}
