package com.budgetbook.couple.controller

import com.budgetbook.couple.dto.CoupleResponse
import com.budgetbook.couple.dto.InvitationResponse
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.service.CoupleService
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import java.time.Instant
import java.util.UUID

class CoupleControllerTest : FunSpec({

    val coupleService = mockk<CoupleService>()
    val controller = CoupleController(coupleService)

    val testUserId = UUID.randomUUID()

    test("createInvitation returns 201 with invitation code") {
        val expectedResponse = InvitationResponse(
            code = "ABCD1234",
            expiresAt = Instant.now().plusSeconds(86400)
        )
        every { coupleService.createInvitation(testUserId) } returns expectedResponse

        val result = controller.createInvitation(testUserId)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.code shouldBe "ABCD1234"
        verify(exactly = 1) { coupleService.createInvitation(testUserId) }
    }

    test("acceptInvitation returns couple info") {
        val partnerId = UUID.randomUUID()
        val expectedResponse = CoupleResponse(
            id = UUID.randomUUID(),
            partner = UserSummary(id = partnerId, nickname = "Partner", profileImageUrl = null),
            status = "ACTIVE",
            createdAt = Instant.now()
        )
        every { coupleService.acceptInvitation(testUserId, "ABCD1234") } returns expectedResponse

        val result = controller.acceptInvitation(testUserId, "ABCD1234")

        result.success shouldBe true
        result.data!!.status shouldBe "ACTIVE"
        result.data!!.partner!!.id shouldBe partnerId
        verify(exactly = 1) { coupleService.acceptInvitation(testUserId, "ABCD1234") }
    }

    test("getMyCouple returns couple info") {
        val partnerId = UUID.randomUUID()
        val expectedResponse = CoupleResponse(
            id = UUID.randomUUID(),
            partner = UserSummary(id = partnerId, nickname = "Partner", profileImageUrl = "https://photo.jpg"),
            status = "ACTIVE",
            createdAt = Instant.now()
        )
        every { coupleService.getMyCouple(testUserId) } returns expectedResponse

        val result = controller.getMyCouple(testUserId)

        result.success shouldBe true
        result.data!!.partner!!.nickname shouldBe "Partner"
        verify(exactly = 1) { coupleService.getMyCouple(testUserId) }
    }

    test("dissolveCouple returns 204 No Content") {
        justRun { coupleService.dissolveCouple(testUserId) }

        val result = controller.dissolveCouple(testUserId)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { coupleService.dissolveCouple(testUserId) }
    }
})
