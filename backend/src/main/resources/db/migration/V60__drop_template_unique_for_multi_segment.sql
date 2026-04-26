-- Phase 25 후속 E-4 (2026-04-26)
-- V57 의 `uk_monthly_budgets_template (couple, cat, group) WHERE row_kind=TEMPLATE` 는
-- 한 scope 당 TEMPLATE 1건만 허용했으나, applyToFuture=true 시:
--   1) 기존 TEMPLATE 의 endYearMonth = (대상월-1) 로 "종료"
--   2) 새 TEMPLATE [대상월~∞] 저장
-- 두 단계 사이 트랜잭션 안에서 같은 scope 의 TEMPLATE 두 행이 공존하여 partial unique 위반.
--
-- 다중 세그먼트(non-overlapping) TEMPLATE 허용으로 정책 변경:
--   - 한 scope 의 TEMPLATE 행이 시간 범위로 N 개 가능 (e.g., [Jan~Apr], [May~∞]).
--   - 비중첩 보장은 app 의 BudgetService.terminateConflictingTemplate 가 책임 (DB 차원
--     비중첩 강제는 별도 trigger/range index 필요 — overhead 대비 효용 낮아 채택 보류).
--   - 조회는 MonthlyBudgetRepository 의 `findByCoupleIdAndYearMonth*` 가 시간 범위 조건
--     (yearMonth <= target AND (endYearMonth IS NULL OR endYearMonth >= target)) 으로
--     active TEMPLATE 만 매칭. Resolver 의 OVERRIDE 우선순위 dedup 동작에는 영향 없음.

DROP INDEX IF EXISTS uk_monthly_budgets_template;
