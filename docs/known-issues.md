# Known Issues & Feature Requests Tracker

> 사용자 요청 사항과 구현 상태를 추적하여 반복 요청을 방지합니다.
> 상태: 🔴 미해결 | 🟡 진행중 | 🟢 완료(사용자 확인) | ⚪ 사용자 취소

---

## 🟢 KI-001: 날짜 팝업 — "Select date" 헤더 제거
- **요청**: 달력 그리드만 팝업 표시, 좌측 헤더 패널 제거
- **해결**: `showDatePicker` → 커스텀 `showCalendarPickerDialog` (CalendarDatePicker + Dialog)
- **적용 위치**: `core/widgets/calendar_picker_dialog.dart` 신규, 전체 11곳 교체
- **사용자 확인 대기**

## 🟢 KI-002: FAB → 거래 폼 상단 3탭 (지출/수입/이체)
- **요청**: BottomSheet 선택 대신 폼 내 TabBar, 홈 퀵액션 연동
- **해결**: TransactionFormPage에 TabBar[지출|수입|이체] 추가, 이체 폼 통합. FAB 직접 이동. 퀵액션 `?tab=` 파라미터.
- **적용 위치**: `transaction_form_page.dart` (TabBar+TransferForm), `dashboard_page.dart` (FAB/퀵액션), `transaction_list_page.dart` (FAB), `app_router.dart` (tab param)
- **사용자 확인 대기**

## 🟢 KI-003: 홈 탭 위젯 커스터마이징 (ON/OFF + 드래그 순서)
- **요청**: 자산 현황 기본 OFF, 설정에서 위젯 표시/순서 커스텀
- **해결**: `DashboardWidgetConfig` + SharedPreferences 저장 + 설정 > "홈 화면 구성" 드래그+토글 페이지
- **적용 위치**: `dashboard_widget_config.dart`, `home_config_service.dart`, `home_config_page.dart`, `dashboard_page.dart` (동적 렌더링)
- **사용자 확인 대기**

## 🟢 KI-004: 홈/예산 탭 주간 예산 금액 불일치
- **요청**: 주간 생활비(주 200,000)가 100만원으로 표시
- **해결**: `BudgetService.getBudgetSummary()`에 WEEKLY pro-rata 적용 완료. 홈/예산 탭 동일 API 사용 확인.
- **적용 위치**: `BudgetService.kt:336-341`
- **NAS 배포 완료** — 새로고침 시 정상 표시

## 🟢 KI-005: 카테고리/결제수단 순서 관리
- **요청**: displayOrder 변경 UI 필요, 팝업 내 정렬 적용
- **해결**:
  - BE: `PUT /api/v1/categories/reorder` + `PUT /api/v1/payment-methods/reorder` 추가
  - FE 선택 팝업: displayOrder 정렬 적용 + "순서 관리 >" 링크
  - FE 자산관리: 카테고리 상/하 이동 버튼 + 결제수단 드래그 재정렬
- **적용 위치**: BE(CategoryController, PaymentMethodController, Service), FE(selector sheets, asset_management_page, BLoC events)
- **사용자 확인 대기**
