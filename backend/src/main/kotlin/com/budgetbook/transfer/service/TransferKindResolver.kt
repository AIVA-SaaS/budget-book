package com.budgetbook.transfer.service

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.paymentmethod.domain.PaymentMethodType
import com.budgetbook.transfer.domain.TransferKind
import org.springframework.stereotype.Component

/**
 * 이체 종류 자동 판정 + 결제수단 조합 검증 — **이체를 만드는 모든 경로의 단일 소스**.
 *
 * 이체 생성 경로가 둘로 늘었다 (사용자 등록 `TransferService.createTransfer`,
 * 거래→이체 변환 `TransactionService.convertToTransfer`). 각자 판정 로직을 들고 있으면
 * "등록한 이체는 카드 결제인데 변환한 이체는 일반 이체" 같은 어긋남이 생긴다.
 *
 * 규칙 (Phase 22 §2.1)
 * - `BANK → CREDIT`: 카드 대금 결제 → `CARD_SETTLEMENT`
 * - `CREDIT → CREDIT`: 금지
 * - 그 외: `GENERIC`
 * - `EXPENSE_TRANSFER` / `INCOME_TRANSFER` 는 의미상 자동 판정이 불가능해 사용자가 명시해야 한다
 *   (이 클래스는 그 둘을 리턴하지 않는다).
 */
@Component
class TransferKindResolver {

    fun validateCombination(sourceType: PaymentMethodType, destType: PaymentMethodType) {
        if (sourceType == PaymentMethodType.CREDIT && destType == PaymentMethodType.CREDIT) {
            throw BusinessException("TRANSFER_CREDIT_TO_CREDIT_NOT_ALLOWED", "카드 간 이체는 불가합니다")
        }
    }

    fun resolveDefaultKind(sourceType: PaymentMethodType, destType: PaymentMethodType): TransferKind = when {
        sourceType == PaymentMethodType.BANK && destType == PaymentMethodType.CREDIT ->
            TransferKind.CARD_SETTLEMENT
        else -> TransferKind.GENERIC
    }
}
