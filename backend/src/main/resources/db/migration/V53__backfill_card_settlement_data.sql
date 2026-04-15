-- Phase 20-C (V51/V52) 배포 이전에 생성된 데이터 정리.
-- 기존 BANK→CREDIT 이체를 카드 결제로 표시 + 대응 거래 paid_at 자동 설정.

-- Step 1: 기존 BANK→CREDIT 이체를 카드 결제로 표시
-- 근거: BANK→CREDIT 조합 이체는 99% 카드 결제 용도. 일반 이체 가능성 매우 낮음.
UPDATE transfers tr
SET is_card_settlement = true
FROM payment_methods src, payment_methods dst
WHERE tr.source_payment_method_id = src.id
  AND tr.destination_payment_method_id = dst.id
  AND src.type = 'BANK'
  AND dst.type = 'CREDIT'
  AND tr.is_card_settlement = false;

-- Step 2: 기존 결제 이체의 대응 거래에 paid_at 자동 설정
-- 각 결제 이체에 대해: destination 카드에서 transferDate 월에 settlementDate가 있는
-- 거래들의 paid_at을 해당 이체의 transferDate로 설정.
-- 같은 월에 결제 이체가 여러 번이면 가장 최근 날짜 사용.
UPDATE transactions t
SET paid_at = sub.transfer_date
FROM (
    SELECT DISTINCT ON (t_inner.id)
        t_inner.id AS txn_id,
        tr.transfer_date
    FROM transactions t_inner
    JOIN transfers tr ON tr.destination_payment_method_id = t_inner.payment_method_id
    WHERE t_inner.paid_at IS NULL
      AND t_inner.settlement_date IS NOT NULL
      AND tr.is_card_settlement = true
      AND EXTRACT(YEAR FROM tr.transfer_date) = EXTRACT(YEAR FROM t_inner.settlement_date)
      AND EXTRACT(MONTH FROM tr.transfer_date) = EXTRACT(MONTH FROM t_inner.settlement_date)
    ORDER BY t_inner.id, tr.transfer_date DESC
) sub
WHERE t.id = sub.txn_id;
