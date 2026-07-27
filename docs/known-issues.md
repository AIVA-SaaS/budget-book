# Known Issues & Feature Requests Tracker

> 사용자 요청 사항과 구현 상태를 추적하여 반복 요청을 방지합니다.
> 상태: 🔴 미해결 | 🟡 확인 필요 | 🟢 완료(사용자 확인) | ⚪ 사용자 취소

---

## 🟢 KI-007: 카카오 OAuth 빈 email → 가입 실패 + 식별 불가 (2026-06-04 발견 / 2026-07-27 코드 확인)
- **발견**: 카카오는 이메일이 선택 동의 → 미동의 시 `CustomOAuth2UserService` 가 `?: ""` 로 빈 문자열 저장
- **버그**: `email` 이 `NOT NULL UNIQUE` 라 빈 문자열도 1명만 가능 + 중복가입 체크 `findByEmail("")` 가 기존
  빈-email 유저를 반환 → **2번째 email-미동의 카카오 가입이 "이미 등록된 이메일"로 차단**
- **사실 정정**: 파트너 연결은 email 이 아니라 8자리 초대코드(`CoupleService`). email 용도는
  ① cross-provider 중복가입 방지 ② 어드민 식별뿐
- **조치 결과 (2026-07-27 코드 확인)**
  - Phase 1 **완료** — `auth/domain/EmailPolicy.kt` 가 `{provider}_{providerId}@no-email.local`
    placeholder 를 생성하고 중복체크에서 placeholder 를 skip. `V62__backfill_placeholder_emails.sql`
    로 기존 빈-email row 백필 (라이브 적용 완료)
  - Phase 3 **완료** — `settings/.../profile_edit_page.dart` 가 `hasRegisteredEmail` 기준으로
    이메일 등록을 유도하고 `UpdateProfile(email:)` 로 저장
  - Phase 2 **미착수(선택)** — 카카오 비즈니스 앱 전환 + 이메일 필수 동의 검수. placeholder 가
    본질 문제를 해결했으므로 필수 아님
- **남은 확인**: 이메일 미동의 카카오 계정 2개 동시 가입 라이브 재현 (사용자 검증 미수행)

## 🟡 KI-006: 완료 처리 시 거래 자동 등록 + 상태 변경
- **요청**: 지출 계획 완료 처리 시 거래 자동 등록 + COMPLETED 상태 전환
- **현재**: FE/BE 코드 정상. NAS에 최신 FE 재배포 후 확인 필요
- **조치**: 2026-03-30 NAS deploy-nas 트리거됨. 배포 완료 후 사용자 확인 대기

## 🟢 KI-001~005: 해결 완료
- KI-001: 날짜 팝업 헤더 제거 → showCalendarPickerDialog
- KI-002: FAB → 3탭 폼 (지출/수입/이체)
- KI-003: 홈 위젯 커스터마이징 + 이전 wishlist ID 자동 정리
- KI-004: 주간 예산 일할 계산
- KI-005: 카테고리/결제수단 순서 관리 (드래그)

## 🟢 전체 UI 일관성 (감사 완료 2026-03-30)
- 카테고리 선택: 전체 6개 폼 CategoryGroupSelectorSheet (showDialog) 통일
- 결제수단 선택: 전체 5개 폼 ItemSelectorSheet + 타입 그룹핑 통일
- 결제수단 정렬: CASH→BANK→DEBIT→CREDIT (전역)
- FAB 하단 패딩: 전체 16개 페이지 88px
- 캘린더: 전체 showCalendarPickerDialog

## 세션 교훈 (2026-03-28~30)
1. 코드 검사만으로 부족 — NAS 배포 상태 + 런타임 데이터 확인 필수
2. ID/key 변경 시 기존 저장 데이터 마이그레이션 포함
3. 동일 파일 다중 에이전트 수정 금지
4. BLoC 관련 데이터 원자적 로딩 (별도 이벤트 분리 금지)
5. 에이전트 지시 시 기존 패턴을 구체 코드 참조로 명시
