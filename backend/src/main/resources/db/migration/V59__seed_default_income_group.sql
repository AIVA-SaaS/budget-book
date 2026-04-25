-- Phase 25 후속 — 기존 사용자에게 INCOME 기본 그룹 자동 시드
--
-- 사용자 보고: "수입에 대한 그룹 카테고리도 별도로 생겨야하는데 제대로
-- 분석이 안된 것 같다"
--
-- V58 백필은 "수입 카테고리가 들어 있는 그룹" 만 INCOME 으로 분류함.
-- 사용자 데이터에서 수입 카테고리("급여" 등) 가 group_id NULL 인 경우
-- INCOME 그룹이 없게 됨. → 이 마이그레이션으로 각 couple 에 INCOME 기본
-- 그룹 1개 생성하고 미할당 수입 카테고리들을 자동 할당.

-- 1) INCOME 그룹이 없는 couple 에 기본 "수입" 그룹 생성
INSERT INTO category_groups (
    id, couple_id, name, icon, color,
    budget_type, category_type, display_order, is_default,
    visibility, created_at, updated_at
)
SELECT
    gen_random_uuid(),
    c.id,
    '수입',
    'attach_money',
    '#4CAF50',
    'NONE',
    'INCOME',
    100,           -- 기존 EXPENSE 그룹 (1, 2, 3) 뒤에
    TRUE,
    'SHARED',
    NOW(),
    NOW()
FROM couples c
WHERE NOT EXISTS (
    SELECT 1 FROM category_groups cg
    WHERE cg.couple_id = c.id AND cg.category_type = 'INCOME'
);

-- 2) 그룹 미할당 INCOME 카테고리들을 새 그룹에 자동 할당
UPDATE categories cat
SET group_id = cg.id
FROM category_groups cg
WHERE cat.couple_id = cg.couple_id
  AND cg.category_type = 'INCOME'
  AND cg.is_default = TRUE
  AND cat.type = 'INCOME'
  AND cat.group_id IS NULL;
