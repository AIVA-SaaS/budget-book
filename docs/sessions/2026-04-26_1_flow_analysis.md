# Phase 25 종합 — FE/BE/Flow 분석 + 사용자 검증 체크리스트
> 날짜: 2026-04-26 | 회차: 1 | 상태: 분석 완료, 사용자 검증 대기

## 0. 현재 상태 요약

### 머지된 작업 (main = e17f5c0 직후)
- Phase 25 메인 (7→4탭 전환) Step 1~14: 완료
- E 시리즈 (카테고리 EXPENSE/INCOME 분리): E-1/E-2/E-3/E-4 모두 머지
- C 시리즈 C-1 (MonthlyBudget 도메인 V57 매핑): 머지

### 미머지 브랜치 (gh CLI 인증 단절로 PR 미작성)
1. `origin/session3-budget-tap-filter-and-c2` (0b60151)
   - 예산 onTap → 거래 탭 필터 이동
   - 거래 탭 categoryGroupId query 지원
   - C-2 DTO (BudgetRequest.endYearMonth, BudgetUpdateRequest.applyToFuture, BudgetResponse.endYearMonth/rowKind)
   - C-2 createBudget 의 endYearMonth/rowKind 결정 로직
2. `origin/session3-c2-budget-update-delete-and-harness` (14a9971)
   - C-2 updateBudget(applyToFuture) — TEMPLATE 승격 + endYearMonth=null
   - C-2 deleteBudget(applyToFuture) — TEMPLATE 종료(endYearMonth=yearMonth-1)
   - 하네스 audit-patterns.json + lessons-learned.jsonl 업데이트

→ **사용자 액션 필요**: `! gh auth login` 후 두 브랜치 PR 생성/머지, 또는 GitHub UI 에서 직접 머지.

## 1. 흐름이 이상한 부분 — 사용자 검증 체크리스트

### A. 예산 TEMPLATE/OVERRIDE 모델 — 조회 측 미완성 ⚠️ 심각
**증상**: TEMPLATE 으로 예산 만들고 미래 월로 이동하면 보이지 않을 가능성.

**원인**: `MonthlyBudgetRepository.findByCoupleIdAndYearMonthAndUserId` 쿼리가 다음 조건 사용:
```sql
WHERE b.yearMonth = :yearMonth OR (b.periodType = NONE AND b.yearMonth <= :yearMonth)
```
- `rowKind`/`endYearMonth` 필드를 사용하지 않음
- 즉, 4월에 만든 TEMPLATE 이 5월 조회 시 안 보임

**예상 사용자 검증**:
1. 4월 예산 생성 시 `endYearMonth` 미지정 (or `endYearMonth=2026-12`) → BE 에서 TEMPLATE 으로 저장됨 (확인 가능)
2. 5월로 이동 → 4월 TEMPLATE 이 5월에도 보여야 하는데 보일까?
3. **현재 코드: 안 보일 것** — C-2 다음 PR 에서 query 보강 필요

**조치 후보**:
- C-2.5 (조회 측): `findByCoupleIdAndYearMonthAndUserId` 를 TEMPLATE 범위 + OVERRIDE 우선순위 처리하도록 변경
- 또는 C-3 FE 와 함께 진행

### B. applyToFuture 의 OVERRIDE 측면 모호함 ⚠️ 중요
**증상**: 사용자가 OVERRIDE 행에 `applyToFuture=true` 누르면 어떻게 되어야 하나?

**현재 코드** (BudgetService.updateBudget):
- 행을 TEMPLATE 으로 승격 + endYearMonth=null
- → 4월 OVERRIDE 가 4월부터 무기한 TEMPLATE 으로 변환됨

**문제 시나리오**:
- 사용자가 4월에 OVERRIDE 30만원 + 기존 TEMPLATE 25만원 (3월~12월) 있는 상태
- 4월 OVERRIDE 를 30만→35만으로 변경하면서 applyToFuture 체크
- **현재 코드 결과**: 4월 OVERRIDE 가 TEMPLATE 으로 승격 (35만, 4월~무기한)
- **남는 문제**: 기존 TEMPLATE (25만, 3월~12월) 도 그대로 → 4월부터 두 개의 TEMPLATE 충돌

**예상 사용자 검증**:
1. TEMPLATE 만 있는 상태에서 applyToFuture: OK 동작
2. OVERRIDE 만 있는 상태에서 applyToFuture: 단일월이 무기한으로 바뀜 — 의도와 부합
3. TEMPLATE+OVERRIDE 같은 월 공존 + OVERRIDE 에 applyToFuture: **이중 TEMPLATE 충돌 발생** ❌

**조치 후보**:
- C-2.6: applyToFuture 시 같은 scope 의 다른 TEMPLATE 자동 종료 (`endYearMonth = (target-1)`) 로직 추가
- 또는 FE 에서 applyToFuture 체크 시 기존 TEMPLATE 알림 + 사용자 선택

### C. deleteBudget(applyToFuture) — OVERRIDE 측 무처리 ⚠️ 중간
**현재 코드**:
- TEMPLATE 인 경우 endYearMonth=(target-1) 로 종료
- OVERRIDE 인 경우 그냥 삭제

**문제**: OVERRIDE 를 "이후 모든 일정에 반영해서 삭제" 누르면 단일월 OVERRIDE 만 삭제. 사용자 의도는 "이후 TEMPLATE 도 종료해줘" 일 수 있음.

**예상 사용자 검증**:
1. TEMPLATE delete + applyToFuture: TEMPLATE 종료 — OK
2. OVERRIDE delete + applyToFuture: OVERRIDE 만 삭제 — 사용자 의도와 다를 수 있음

**조치 후보**:
- OVERRIDE 삭제 + applyToFuture=true 시 같은 scope 의 활성 TEMPLATE 도 종료
- 또는 FE 에서 OVERRIDE 행은 applyToFuture 체크박스 비활성화

### D. categoryGroupId 필터 — 필터 칩 표시 ⓘ 확인
**증상**: 예산 → 그룹 예산 클릭 → /transactions?categoryGroupId=X 이동.

**검증 포인트**:
1. 거래 탭 상단 필터 바에 "카테고리 그룹: 식비" 칩이 표시되는가?
2. 거래 목록이 그 그룹 하위 카테고리만 표시하는가?
3. 합계(수입/지출) 가 그룹 필터 적용된 합으로 보이는가?

**현재 코드 확인**: 
- `transaction_list_page.dart` 가 `_filterState.categoryGroupIds` 초기화 ✅
- `unified_filter_bar.dart` 가 `state.categoryGroupIds.isNotEmpty` 처리 ✅
- BE TransactionService 가 group → category 펼침 ✅
- → 동작할 가능성 높음, 사용자 라이브 검증 필요

### E. 카테고리 EXPENSE/INCOME 분리 — INCOME 그룹 표시 ⓘ 확인
**증상**: 카테고리 추가 dialog 에서 type=INCOME 선택 시 그룹 dropdown 이 INCOME 그룹만 보여야 함.

**검증 포인트**:
1. 카테고리 관리 화면에서 type 토글 → 그룹 selector 갱신되는가?
2. 거래 등록 시 INCOME 선택 → INCOME 그룹만 보이는가?
3. 분석 탭 → 카테고리별 → INCOME 그룹/카테고리 정상 분리되는가?

### F. 폰트 로딩 (자산 측면이 아닌 정상 동작 확인) ⓘ 확인
**증상**: 첫 로드 폰트 시간 1.2MB 까지 줄어든 상태.

**검증 포인트**:
1. 첫 페이지 로드 시 폰트 깜빡임 (FOIT/FOUT) 발생하는가?
2. 한글 표시 제대로 되는가?

### G. 분석 탭 sub-tab 회색화면 회귀 ⓘ 확인
**검증 포인트**:
1. 분석 → 예산 → 통계 → 예산 → 통계 (반복) 시 회색화면 발생하지 않는가?
2. 9개 라우트 (couple, weekly-budgets, weekly-settlement, reports, period-summary, recurring 등) 동일 패턴 모두 .value 변경 — 사용자가 이 화면들 진입 시 잘 동작하는가?

### H. 자산 탭 첫 진입 시 결제수단 우선 ⓘ 확인
**검증 포인트**:
1. 자산 탭 클릭 → 결제수단이 가장 먼저 보이는가?
2. 자산 내역 클릭 시 해당 자산에 해당하는 거래(필터) 적용되어 보이는가?

## 2. 아직 진행 안 된 후속 작업

| # | 작업 | 우선순위 |
|---|------|---------|
| C-2.5 | 예산 조회 쿼리에 TEMPLATE 범위 + OVERRIDE 우선순위 적용 | **높음** (A 항목 해결) |
| C-2.6 | applyToFuture 시 다른 TEMPLATE 자동 종료 | 중간 (B 항목) |
| C-3 | FE 예산 편집 sheet '이후 모든 일정에 반영' 체크박스 | 중간 |
| 머지 | 미머지 브랜치 2개 PR 생성/머지 | **높음** |

## 3. 라이브 검증 요청 (사용자 직접 확인)

### 거래/예산 탭
- [ ] (D) 예산 카테고리 항목 클릭 → 거래 탭 필터 이동 + 칩 표시
- [ ] (D) 예산 그룹 항목 클릭 → 거래 탭 그룹 필터 이동
- [ ] (D) 예산 전체(미할당) 항목 클릭 → 거래 탭 (필터 없음, 해당 월)
- [ ] (A) 예산 페이지에서 TEMPLATE 으로 예산 등록 (BE 호출 시 endYearMonth 미지정) → 다음 월 이동 시 보이는지

### 카테고리 분리
- [ ] (E) 카테고리 추가 → INCOME 선택 → 그룹 dropdown 이 INCOME 그룹만
- [ ] (E) 거래 등록 → INCOME 선택 → 카테고리 selector 가 INCOME 만

### 분석 탭
- [ ] (G) 예산 ↔ 통계 sub-tab 4회 이상 반복 — 회색화면 없음
- [ ] (G) 다른 페이지(주간예산/리포트/주기/커플) 진입 → 빈 화면 없음

### 자산 탭
- [ ] (H) 자산 탭 첫 진입 시 결제수단 sub-tab 활성
- [ ] (H) 자산 내역 클릭 → 거래 탭 필터 이동
- [ ] 결제수단 재정렬 → 새로고침 후 순서 유지

## 4. 다음 PR 후보 (사용자 승인 시)

1. **PR-A** (긴급): 미머지 브랜치 2개 머지 — `! gh auth login` 후 진행
2. **PR-B** (C-2.5): 예산 조회 쿼리 TEMPLATE 범위 처리
3. **PR-C** (C-2.6): applyToFuture 시 TEMPLATE 충돌 자동 해소
4. **PR-D** (C-3): FE 예산 편집 sheet '이후 모든 일정에 반영' UI

## 5. 롤백 정보
- C-2 update/delete 롤백: `git revert 14a9971`
- C-2 DTO+create+예산onTap 롤백: `git revert 0b60151` (PR 머지 후)
- C-1 롤백: `git revert e17f5c0` (PR #175)

## 6. gh CLI 재인증 안내
사용자가 다음 한 줄 실행:
```
! gh auth login
```
이후 PR 생성/머지/이슈 처리가 다시 자동화됨. 인증 상태는 다음과 같이 검증:
```
gh auth status
```
