-- Phase 23 PR-X4: 예산 템플릿 + 오버라이드 모델 (편한 가계부 패턴)
--
-- 기존 monthly_budgets 는 per-month 단일 row 모델이었다.
-- 새 모델:
--   - TEMPLATE  : (couple, category, group) 당 1건. [start_ym, end_ym?] 범위에서 기본 예산 제공.
--                 year_month = 시작월, end_year_month = 종료월(nullable, null=무기한).
--   - OVERRIDE  : 특정 단일 월만 덮어쓰는 row. year_month = end_year_month = 그 월.
--                 같은 (couple, category, group) 에 TEMPLATE 과 공존 가능 — OVERRIDE 우선.
--
-- 기존 row 는 모두 OVERRIDE 로 백필하여 기존 동작(월별 독립) 보존.

-- 1) 컬럼 추가
ALTER TABLE monthly_budgets ADD COLUMN IF NOT EXISTS end_year_month VARCHAR(7);
ALTER TABLE monthly_budgets ADD COLUMN IF NOT EXISTS row_kind VARCHAR(10) NOT NULL DEFAULT 'OVERRIDE';

-- CHECK 제약 (멱등)
ALTER TABLE monthly_budgets DROP CONSTRAINT IF EXISTS ck_monthly_budgets_row_kind;
ALTER TABLE monthly_budgets ADD CONSTRAINT ck_monthly_budgets_row_kind
    CHECK (row_kind IN ('TEMPLATE', 'OVERRIDE'));

-- 2) 백필: end_year_month 가 비어 있으면 year_month 와 동일(단일월) 로 + row_kind = OVERRIDE
UPDATE monthly_budgets
   SET end_year_month = COALESCE(end_year_month, year_month),
       row_kind = COALESCE(row_kind, 'OVERRIDE')
 WHERE end_year_month IS NULL OR row_kind IS NULL;

-- 3) 기존 UK (couple, category, group, year_month) 는 OVERRIDE 전용으로 제한 (partial unique)
--    TEMPLATE 이 추가되면 같은 (couple, cat, group, year_month) 조합에 TEMPLATE + OVERRIDE 가
--    공존해야 하므로 전체 UK 로는 막히면 안 된다.
DROP INDEX IF EXISTS uk_monthly_budgets_couple_cat_group_month;
CREATE UNIQUE INDEX uk_monthly_budgets_override_month
    ON monthly_budgets (
        couple_id,
        COALESCE(category_id, '00000000-0000-0000-0000-000000000000'::UUID),
        COALESCE(group_id,    '00000000-0000-0000-0000-000000000000'::UUID),
        year_month
    )
    WHERE row_kind = 'OVERRIDE';

-- 4) TEMPLATE 은 (couple, category, group) 당 1건 partial unique
CREATE UNIQUE INDEX IF NOT EXISTS uk_monthly_budgets_template
    ON monthly_budgets (
        couple_id,
        COALESCE(category_id, '00000000-0000-0000-0000-000000000000'::UUID),
        COALESCE(group_id,    '00000000-0000-0000-0000-000000000000'::UUID)
    )
    WHERE row_kind = 'TEMPLATE';

-- 5) 템플릿 범위 조회 가속용 인덱스 (start_ym, end_ym)
CREATE INDEX IF NOT EXISTS idx_monthly_budgets_template_range
    ON monthly_budgets (couple_id, year_month, end_year_month)
    WHERE row_kind = 'TEMPLATE';
