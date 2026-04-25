-- Phase 25 후속 — 카테고리 그룹 지출/수입 분리
--
-- 사용자 보고: "카테고리 관리가 지출/수입 별로 별도로 되어야하는데 현재는
-- 거의 같은 그룹을 가지는 문제가 존재한다. 두 개는 완전 다른 개념이기 때문에
-- 각각 설정이 가능해야하며 서로 영향을 미치지 않는다."
--
-- category_groups 에 category_type (EXPENSE/INCOME) 컬럼 추가.
-- 기존 row 백필 — 그룹 안 카테고리 type 의 majority. 동률 또는 카테고리 없는
-- 그룹은 EXPENSE 기본값 (사용자 나중에 수정 가능).

-- 1) 컬럼 추가 (멱등)
ALTER TABLE category_groups ADD COLUMN IF NOT EXISTS category_type VARCHAR(10);

-- 2) 백필: 그룹 안 카테고리 type 의 majority
WITH group_type_stats AS (
    SELECT
        group_id,
        COUNT(*) FILTER (WHERE type = 'EXPENSE') AS expense_count,
        COUNT(*) FILTER (WHERE type = 'INCOME') AS income_count
    FROM categories
    WHERE group_id IS NOT NULL
    GROUP BY group_id
)
UPDATE category_groups cg
SET category_type = CASE
    WHEN gts.income_count > gts.expense_count THEN 'INCOME'
    ELSE 'EXPENSE'
END
FROM group_type_stats gts
WHERE cg.id = gts.group_id
  AND cg.category_type IS NULL;

-- 3) 카테고리 없는 그룹 또는 백필 미적용 row 는 EXPENSE 기본
UPDATE category_groups SET category_type = 'EXPENSE' WHERE category_type IS NULL;

-- 4) NOT NULL constraint
ALTER TABLE category_groups ALTER COLUMN category_type SET NOT NULL;

-- 5) CHECK constraint (멱등)
ALTER TABLE category_groups DROP CONSTRAINT IF EXISTS ck_category_groups_category_type;
ALTER TABLE category_groups ADD CONSTRAINT ck_category_groups_category_type
    CHECK (category_type IN ('EXPENSE', 'INCOME'));

-- 6) 인덱스 — type 별 조회 빈번
CREATE INDEX IF NOT EXISTS idx_category_groups_couple_type
    ON category_groups (couple_id, category_type, display_order);
