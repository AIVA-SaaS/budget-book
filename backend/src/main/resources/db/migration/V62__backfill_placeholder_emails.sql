-- Backfill placeholder emails for users who have blank or null email.
-- The system account (00000000-0000-0000-0000-000000000001) has email='system@budgetbook.internal'
-- and is not affected by the WHERE condition below.
UPDATE users
SET email = lower(provider) || '_' || provider_id || '@no-email.local'
WHERE email = ''
   OR email IS NULL;
