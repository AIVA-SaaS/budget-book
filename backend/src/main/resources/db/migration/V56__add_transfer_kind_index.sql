-- Phase 22 후속 (T4): TransferKind 기반 집계 쿼리 성능 인덱스
--
-- ExpenseCalculator / TransferRepository.sumAmountBy...ByKind 쿼리가
-- 기간 + kind 필터를 결합하므로 복합 인덱스 제공.
--
-- 현 데이터 규모(커플당 월 ~20건, 년 ~240건)에선 full-scan 도 수 ms 이지만
-- 커플 수·월 누적 증가 시 선형 성장 → 조기 인덱스 선행 배치.
--
-- 주의: Flyway V54 에 is_card_settlement 인덱스가 없었으므로 회귀 위험 없음.

CREATE INDEX IF NOT EXISTS idx_transfers_couple_date_kind
    ON transfers (couple_id, transfer_date, kind);

-- 카드 결제 제외 집계가 빈번하므로 부분 인덱스도 추가 (선택성 상승).
CREATE INDEX IF NOT EXISTS idx_transfers_couple_date_non_settlement
    ON transfers (couple_id, transfer_date)
    WHERE kind <> 'CARD_SETTLEMENT';
