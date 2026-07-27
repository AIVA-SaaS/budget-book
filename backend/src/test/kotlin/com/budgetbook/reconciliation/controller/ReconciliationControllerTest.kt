package com.budgetbook.reconciliation.controller

import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.reconciliation.dto.CreateReconciliationRequest
import com.budgetbook.reconciliation.dto.ReconciliationDetailResponse
import com.budgetbook.reconciliation.dto.ReconciliationResponse
import com.budgetbook.reconciliation.dto.ReconciliationSummaryResponse
import com.budgetbook.reconciliation.dto.UpdateReconciliationRequest
import com.budgetbook.reconciliation.service.ReconciliationService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class ReconciliationControllerTest : FunSpec({

    val service = mockk<ReconciliationService>(relaxed = true)
    val controller = ReconciliationController(service)
    val userId = UUID.randomUUID()
    val reconciliationId = UUID.randomUUID()
    val author = UserSummary(id = userId, nickname = "홍길동", profileImageUrl = null)

    fun header(seq: Int) = ReconciliationResponse(
        id = reconciliationId,
        yearMonth = "2026-07",
        seq = seq,
        label = "${seq}차",
        itemCount = 3,
        totalIncome = 0,
        totalExpense = 30000,
        totalTransfer = 0,
        reconciledAt = Instant.parse("2026-07-20T14:03:00Z"),
        reconciledBy = author
    )

    fun detail() = ReconciliationDetailResponse(
        id = reconciliationId,
        yearMonth = "2026-07",
        seq = 1,
        label = "1차",
        itemCount = 3,
        totalIncome = 0,
        totalExpense = 30000,
        totalTransfer = 0,
        reconciledAt = Instant.parse("2026-07-20T14:03:00Z"),
        reconciledBy = author,
        hasChangedItems = false,
        hasDeletedItems = false,
        items = emptyList()
    )

    test("listReconciliations 는 year/month 를 서비스로 전달한다") {
        every { service.listReconciliations(userId, 2026, 7) } returns listOf(header(2), header(1))

        val result = controller.listReconciliations(userId, 2026, 7)

        result.success shouldBe true
        result.data!!.size shouldBe 2
        // 최신 회차 먼저 (서비스 정렬을 그대로 노출).
        result.data!!.first().seq shouldBe 2
        verify { service.listReconciliations(userId, 2026, 7) }
    }

    test("getSummary 는 미기록 집계를 그대로 반환한다") {
        every { service.getSummary(userId, 2026, 7) } returns ReconciliationSummaryResponse(
            yearMonth = "2026-07",
            snapshotCount = 2,
            recordedCount = 23,
            unrecordedCount = 12,
            unrecordedIncome = 0,
            unrecordedExpense = 340000,
            unrecordedTransfer = 50000,
            needsReviewCount = 3
        )

        val result = controller.getSummary(userId, 2026, 7)

        result.data!!.unrecordedCount shouldBe 12
        result.data!!.unrecordedExpense shouldBe 340000
        result.data!!.needsReviewCount shouldBe 3
    }

    test("createReconciliation 은 201 로 응답한다") {
        val request = CreateReconciliationRequest(
            yearMonth = "2026-07",
            label = "1차",
            transactionIds = listOf(UUID.randomUUID())
        )
        every { service.createReconciliation(userId, request) } returns detail()

        val response = controller.createReconciliation(userId, request)

        response.statusCode shouldBe HttpStatus.CREATED
        response.body!!.data!!.seq shouldBe 1
        verify { service.createReconciliation(userId, request) }
    }

    test("updateReconciliation 은 라벨/항목 변경 요청을 위임한다") {
        val request = UpdateReconciliationRequest(label = "수정된 라벨")
        every { service.updateReconciliation(userId, reconciliationId, request) } returns detail()

        val result = controller.updateReconciliation(userId, reconciliationId, request)

        result.success shouldBe true
        verify { service.updateReconciliation(userId, reconciliationId, request) }
    }

    test("deleteReconciliation 은 204 를 반환한다") {
        val response = controller.deleteReconciliation(userId, reconciliationId)

        response.statusCode shouldBe HttpStatus.NO_CONTENT
        verify { service.deleteReconciliation(userId, reconciliationId) }
    }
})
