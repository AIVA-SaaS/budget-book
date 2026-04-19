# Period + Filter Propagation CODEMAP

> 과거 인시던트(navigation_state 3회, filter_propagation 1회)의 **구조적 재발 방지 계약서**.
> 신규 period/filter 의존 BLoC 추가 시 이 문서의 체크리스트를 반드시 완료.

## 핵심 원칙
1. **단일 소스 오브 트루스**: period 상태는 `UnifiedPeriodCubit` 만. 페이지 로컬 state 복제 금지.
2. **필터는 value object 로**: 각 BLoC 의 흩어진 `_currentXxx` 필드 직접 노출 금지 → `currentFilter` getter 로 **전체 필터** 단일 객체 노출.
3. **월 변경 시 필터 drop 금지**: MonthSyncHandler 는 반드시 `currentFilter` 전체를 전파. 선택 필드만 꺼내지 말 것.
4. **컴파일 타임 강제**: value object 에 필드 추가 → event 시그니처 추가 → `currentFilter` getter 업데이트 — 세 지점 동시 수정 하지 않으면 round-trip 테스트 실패.

## 계층 구조

```
┌────────────────────────────────────────────────────────┐
│  UnifiedPeriodCubit (core/bloc/unified_period_cubit.dart)│
│  • year / month                                         │
│  • dateFrom / dateTo (optional, range mode)             │
│  • week (optional)                                      │
└────────────────────────────────────────────────────────┘
             │ emit on change
             ▼
┌────────────────────────────────────────────────────────┐
│  MonthSyncHandler (core/bloc/month_sync_handler.dart)   │
│  • listen to MonthCubit + UnifiedPeriodCubit            │
│  • dispatch reload to 9+ BLoCs with FULL period+filter  │
└────────────────────────────────────────────────────────┘
             │ add(LoadXxx(period, filter))
             ▼
┌────────────────────────────────────────────────────────┐
│  Feature BLoCs (Transaction / Statistics / Report / ...) │
│  • store _currentXxx fields in _onLoadXxx               │
│  • expose `currentFilter: XxxFilter` getter             │
│  • never be called without full filter/period context   │
└────────────────────────────────────────────────────────┘
```

## Value Objects (필터 state)

| Feature | Value Object | 경로 |
|---------|--------------|------|
| Transaction | `TransactionFilter` | `features/transaction/domain/entities/transaction_filter.dart` |
| Statistics | (TODO 후속 회차) `StatisticsFilter` | `features/statistics/domain/entities/statistics_filter.dart` |
| Report | (TODO 후속 회차) `ReportFilter` | `features/report/domain/entities/report_filter.dart` |

### 필드 추가 체크리스트 (예: Transaction 에 `merchant` 필드 추가 시)

- [ ] `TransactionFilter.merchant` 필드 추가 + `copyWith`, `props`, `hasAny` 반영
- [ ] `LoadTransactions` event 에 `merchant` named param 추가
- [ ] `TransactionBloc._onLoadTransactions` 에서 `_currentMerchant = event.merchant` 저장
- [ ] `currentFilter` getter 에 `merchant: _currentMerchant` 포함
- [ ] `MonthSyncHandler` 는 자동 반영 (currentFilter 전체 전달 중) — 코드 수정 불필요 ✓
- [ ] `transaction_filter_test.dart` 의 `round-trip preserves ALL filter fields` 에 merchant 추가
- [ ] 새 필터 UI 위젯 → filter 업데이트 시 dispatch `LoadTransactions(..., merchant: x)`

## Period 모드 규칙 (UnifiedPeriodCubit)

| 상황 | 동작 |
|------|------|
| `changeMonth(y, m)` | month 모드, 기존 dateRange 자동 clear |
| `setDateRange(from, to)` | range 모드, year/month 는 from 기준 자동 동기화 |
| `clearRange()` | month 모드 복귀, year/month 유지 |
| `setWeek(w)` | 주간 리포트용 선택 (month 모드 유지) |

**API 호출 포맷**:
- month 모드: `?year=2026&month=4`
- range 모드: `?dateFrom=2026-03-05&dateTo=2026-04-20` (BE 는 year/month 무시)

## MonthSyncHandler 등록부

신규 period 의존 BLoC 추가 시 `_syncAllMonthDependentBlocs()` 내에 try/catch 블록 추가.
**반드시** 해당 BLoC 의 `currentFilter` getter 사용 (개별 field 꺼내지 말 것).

현재 등록된 BLoCs:
- BudgetBloc, DashboardBloc, PaymentMethodBloc, TransactionBloc, TransferBloc
- StatisticsBloc, WeeklyBudgetBloc, ReportBloc, AiInsightBloc, SpendingPlanBloc

## Regression 테스트

`test/features/transaction/domain/entities/transaction_filter_test.dart`:
- `round-trip preserves ALL filter fields` — 필터 필드 추가 후 테스트 추가 의무

`test/core/bloc/unified_period_cubit_test.dart`:
- changeMonth → range clear
- setDateRange → year/month sync
- same month → no emit
- clearRange → month 모드, year/month 보존

## 과거 인시던트 (하네스 scope_audit 로그)

1. **2026-04-14** (`navigation_state`): 예산 3월 → 카드 선택 → 4월 거래 표시
   - 원인: BE controller 에서 year/month 하드코딩
   - 방지: BE API 도 query param 필수화 / FE 는 현재 월 required 전달
2. **2026-04-15** (`navigation_state`): 홈/예산 월 이동 후 거래 이동 시 현재 월로 리셋
   - 원인: 페이지간 navigation 시 year/month 파라미터 누락
   - 방지: `navigation_helpers.dart` 중앙 헬퍼 + required named params
3. **2026-04-15** (`navigation_state`): 월 이동 시 카드 요약이 stale
   - 원인: 각 페이지에서 수동 reload — 월 변경 브로드캐스트 없음
   - 방지: `MonthCubit` + `MonthSyncHandler` 중앙화 (Phase 20-F)
4. **2026-04-20** (`filter_propagation`): 월 이동 시 거래내역 필터(dateFrom/To 등) drop
   - 원인: MonthSyncHandler 가 categoryId/paymentMethodId 만 재주입
   - 방지: `TransactionFilter` value object + `currentFilter` getter 전체 전파

## 향후 로드맵

- [ ] StatisticsBloc / ReportBloc 에 같은 패턴 확장 (`StatisticsFilter`, `ReportFilter`)
- [ ] analysis_options.yaml custom lint: `year: int, month: int` 개별 파라미터 사용 경고
- [ ] MonthCubit deprecated 제거 (UnifiedPeriodCubit 이 확실히 모든 usage 커버 후)
- [ ] 모든 페이지의 page-local year/month/filter state 제거 → UnifiedPeriodCubit 바라보게 마이그레이션
