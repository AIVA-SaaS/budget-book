-- V28: Fix existing WEEKLY budgets that may have incorrect weeklyAmount
--
-- Issue: When creating WEEKLY budgets, the amount field stored the total
-- monthly amount (weeklyAmount * 4), but weeklyAmount was sometimes not
-- stored correctly. Also ensure budgetPeriod is consistent.

-- For WEEKLY budgets where weeklyAmount is NULL, derive it from amount
UPDATE monthly_budgets
SET weekly_amount = amount / 4
WHERE budget_period = 'WEEKLY'
  AND weekly_amount IS NULL;

-- For WEEKLY budgets where weeklyAmount was incorrectly set to amount/4
-- but should be the user's intended per-week value: no change needed
-- (amount/4 IS the correct weekly amount if amount is the monthly total)
