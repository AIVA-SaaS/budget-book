package com.budgetbook.common.filter

import com.budgetbook.common.exception.BusinessException
import com.budgetbook.transaction.domain.TransactionType

/**
 * `transactionTypes` 파싱의 **단일 진입점**.
 *
 * ## `TRANSFER` 는 이제 계약 값이다 (2026-08-12)
 *
 * 장부의 타입 칩은 지출 / 수입 / **이체** 3종이다. 그런데 `TRANSFER` 는 `TransactionType`
 * 이 아니어서, 예전에는 FE 가 전송 직전에 `TRANSFER` 를 **잘라내고** 보냈다. 그 결과:
 *  - 서버는 "타입 필터 없음" 으로 해석해 거래 전체를 세고,
 *  - FE 가 클라이언트에서 다시 타입 게이팅을 했다 → 판정이 두 곳 = drift 원인.
 *
 * 이제 FE 는 `TRANSFER` 를 **그대로 보내고**, 서버가 두 스트림 모두를 판정한다.
 *  - 거래: [transactionTypes] 로 필터. 선택에 거래 타입이 하나도 없으면 [matchesNoTransaction]
 *    = true → 거래는 **0건**이어야 한다("이체만 보기").
 *  - 이체: [includesTransfer] 가 false 면 이체를 전량 제외
 *    ([com.budgetbook.transfer.service.TransferGating]).
 *
 * 유효하지 않은 값(예: `FOO`)은 여전히 `VALIDATION_ERROR` 다.
 */
data class LedgerTypeSelection(
    /** 선택된 거래 타입. 빈 Set 이고 [hasSelection] 이면 "거래 없음" 을 뜻한다. */
    val transactionTypes: Set<TransactionType>,
    /** 선택에 `TRANSFER` 가 포함됐는지. */
    val includesTransfer: Boolean,
    /** 타입 필터가 하나라도 켜져 있는지. false = 전체(필터 없음). */
    val hasSelection: Boolean,
) {
    /** 타입 필터는 켜졌지만 거래 타입이 하나도 없다 → 거래는 0건이 정답. */
    val matchesNoTransaction: Boolean
        get() = hasSelection && transactionTypes.isEmpty()

    /** 이체를 노출해야 하는지. 필터 없음 = 전체 노출. */
    val includesTransfers: Boolean
        get() = !hasSelection || includesTransfer

    companion object {
        /** FE 의사-타입. `TransactionType` 에는 없고 이체 스트림을 가리킨다. */
        const val TRANSFER = "TRANSFER"

        fun parse(rawTypes: List<String>?): LedgerTypeSelection {
            val raw = rawTypes?.filter { it.isNotBlank() }?.map { it.trim().uppercase() } ?: emptyList()
            if (raw.isEmpty()) {
                return LedgerTypeSelection(
                    transactionTypes = emptySet(),
                    includesTransfer = false,
                    hasSelection = false,
                )
            }
            val txTypes = mutableSetOf<TransactionType>()
            var transfer = false
            for (value in raw) {
                if (value == TRANSFER) {
                    transfer = true
                    continue
                }
                txTypes.add(
                    try {
                        TransactionType.valueOf(value)
                    } catch (e: IllegalArgumentException) {
                        throw BusinessException("VALIDATION_ERROR", "Invalid transaction type: $value")
                    }
                )
            }
            return LedgerTypeSelection(
                transactionTypes = txTypes,
                includesTransfer = transfer,
                hasSelection = true,
            )
        }
    }
}
