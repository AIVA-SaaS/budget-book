# 예산/지출계획 기능 기획서

## 기능 1: 주간 예산 반복 (기간 미지정 시 자동 적용)

### 현재
- NONE 기간 + WEEKLY 예산: yearMonth별 개별 생성 필요
- 사용자가 매달 수동으로 주간 예산 생성해야 함

### 요구사항
- "매주 10만원 식비" 예산을 한 번 설정하면 모든 달에 자동 적용
- 기간 미지정(NONE) + 주간 예산 → 어떤 달이든 해당 월의 일할 계산된 금액으로 표시

### 구현 방안
- **BE**: `getBudgetsByMonth` / `getBudgetSummary`에서 NONE 기간 WEEKLY 예산을 조회 시 해당 월에 자동 포함
  - `MonthlyBudgetRepository.findByCoupleIdAndYearMonthAndUserId`에 NONE 기간 예산도 포함하는 쿼리 추가
  - 이미 `V51` 마이그레이션에서 유사 로직 존재 (확인 필요)
- **FE**: 변경 없음 (BE 응답만 표시)

### 영향 범위
- `BudgetService.getBudgetsByMonth()`
- `BudgetService.getBudgetSummary()`
- `WeeklyBudgetService.getWeeklyOverview()`

---

## 기능 2: 금액 입력 +/- 계산 및 지우기

### 현재
- `CurrencyInputFormatter`: 숫자 → 콤마 포맷만 지원
- 계산 기능 없음

### 요구사항
- 금액 필드에서 "+5000" 입력 시 현재값 + 5,000
- "-3000" 입력 시 현재값 - 3,000
- 전체 지우기 버튼
- 모든 금액 입력 필드에 공통 적용 (거래, 예산, 이체, 지출계획)

### 구현 방안

#### Option A: 인라인 수식 (권장)
- 금액 필드 옆에 +/- 버튼 추가
- 버튼 클릭 시 "현재값 + ___" 입력 모드 전환
- 숫자 입력 후 확인 → 계산 결과 반영
- 지우기(X) 버튼으로 금액 초기화

#### Option B: 계산기 팝업
- 금액 필드 탭 시 계산기 다이얼로그 표시
- 가계부 앱 스타일 계산기 (0-9, +, -, =, C)
- 결과를 금액 필드에 반영

### 구현 위치
- `core/widgets/amount_input_field.dart` (새 공통 위젯)
- 기존 TextField + CurrencyInputFormatter를 대체
- 적용 대상: `transaction_form_page`, `budget_form_page`, `transfer_form`, `spending_plan_form_page`

---

## 기능 3: 주간 예산 달 이동

### 현재
- `budget_list_page.dart` 주간 탭: 현재 달만 표시, MonthNavigator 없음
- BE `getWeeklyOverview(year, month)` API는 이미 연월 파라미터 지원

### 요구사항
- 주간 예산 탭에서도 < 2026년 3월 > 형태로 달 이동 가능

### 구현 방안
- `budget_list_page.dart`의 주간 탭(`_buildWeeklyContent`)에 `MonthNavigator` 추가
- `WeeklyBudgetBloc`에 year/month 파라미터 전달
- 상태에 year/month 저장하여 탭 전환 시 유지

### 영향 범위
- `frontend/lib/features/budget/presentation/pages/budget_list_page.dart`
- `frontend/lib/features/budget/presentation/bloc/weekly_budget_bloc.dart`
- `frontend/lib/features/budget/presentation/bloc/weekly_budget_event.dart`

---

## 기능 4: 예산에 계획 예정액 포함

### 현재
- `spending_plan`에 `budgetId` 필드로 예산 연결 가능
- 하지만 예산 사용 현황 계산 시 `spending_plan`의 예정 금액 미포함
- 예산 사용 = 실제 지출(거래)만 계산

### 요구사항
- 예산 사용 현황 = 실제 지출 + 계획 예정액
- UI에서 "사용 / 예정 / 남은" 3단 표시
- 진행률 바: 사용(진한색) + 예정(연한색)으로 구분

### 구현 방안

#### BE
- `BudgetService.getBudgetSummary()`에 예산별 계획 예정액 추가
  - `SpendingPlanRepository`에서 budgetId + PLANNED 상태 항목의 금액 합산 쿼리
  - `BudgetSummaryItemResponse`에 `plannedAmount: Long` 필드 추가
- `WeeklyBudgetService`에도 동일 적용

#### FE
- `BudgetSummaryItem` 엔티티에 `plannedAmount` 필드 추가
- 예산 타일 진행률 바: 2-color (사용=빨강, 예정=주황)
- 텍스트: "50,000원 사용 + 30,000원 예정 / 100,000원 (80%)"
- `BudgetSummaryCard`에도 예정 합계 표시

### 영향 범위
- `backend/src/main/kotlin/com/budgetbook/budget/service/BudgetService.kt`
- `backend/src/main/kotlin/com/budgetbook/budget/dto/BudgetDtos.kt`
- `frontend/lib/features/budget/domain/entities/budget.dart`
- `frontend/lib/features/budget/presentation/pages/budget_list_page.dart`

---

## 기능 5: 구매 목록/계획됨 기존 거래 연결

### 현재
- `SpendingPlan`에 `linkedTransactionId` 필드 존재 ✅
- `completePlan()` API에서 `linkedTransactionId` 받아 연결 가능 ✅
- `completeWithTransaction()` API에서 거래 생성 후 자동 연결 ✅

### 추가 요구사항
- 완료 처리 시 **기존 등록된 거래를 검색/선택**하여 연결하는 UI
- "새 거래 생성" 외에 "기존 거래 연결" 옵션 추가

### 구현 방안

#### FE
- 완료 처리 다이얼로그에 "기존 거래 연결" 버튼 추가
- 버튼 클릭 시 거래 검색 다이얼로그 표시
  - 해당 월의 거래 목록에서 검색/선택
  - 금액, 날짜, 설명으로 필터링
- 선택된 거래 ID를 `completePlan(linkedTransactionId: id)`로 전달

### 영향 범위
- `frontend/lib/features/spending_plan/presentation/widgets/complete_plan_dialog.dart`
- 새 위젯: `transaction_search_dialog.dart`
- BE 변경 없음 (API 이미 완성)
