-- V64: Unify weekly↔monthly budget conversion (fix usage-% drift)
--
-- Background: WEEKLY budgets stored `amount` as an approximation — the client sent
-- weeklyAmount*4, and the BE fallback used amount / numberOfWeeks (4 or 5). Every
-- display path, however, computes the monthly-equivalent as `weekly_amount * daysInMonth / 7`
-- (≈ 4.28–4.43 weeks). Those two conventions are NOT inverse, so the displayed monthly
-- total and usage % drifted from what the user set — worsened by the prorated partial
-- first/last weeks.
--
-- New model: `weekly_amount` is the source of truth; `amount` is DERIVED as
-- ROUND(weekly_amount * daysInMonth / 7), the exact inverse of the display formula.
-- This migration re-derives `amount` for all existing WEEKLY budgets so the stored
-- value and every displayed value agree (the usage % then matches across views).
--
-- Constraints checked: ck_monthly_budgets_amount CHECK (amount >= 0) — recomputed
-- amount is always >= 0. weekly_amount has no CHECK constraint.

-- 1) Defensive backfill: any WEEKLY row still missing weekly_amount (legacy) gets a
--    per-week value back-derived from the stored monthly amount with the canonical inverse.
UPDATE monthly_budgets
SET weekly_amount = ROUND(
        amount * 7.0
        / EXTRACT(DAY FROM (date_trunc('month', to_date(year_month, 'YYYY-MM'))
                            + interval '1 month' - interval '1 day'))
    )
WHERE budget_period = 'WEEKLY'
  AND weekly_amount IS NULL;

-- 2) Re-derive monthly `amount` = ROUND(weekly_amount * daysInMonth / 7) for every WEEKLY
--    row so stored amount == the effective budget every display path computes.
UPDATE monthly_budgets
SET amount = ROUND(
        weekly_amount
        * EXTRACT(DAY FROM (date_trunc('month', to_date(year_month, 'YYYY-MM'))
                            + interval '1 month' - interval '1 day'))
        / 7.0
    )
WHERE budget_period = 'WEEKLY'
  AND weekly_amount IS NOT NULL;
