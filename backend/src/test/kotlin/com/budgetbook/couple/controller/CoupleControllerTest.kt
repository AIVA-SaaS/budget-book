package com.budgetbook.couple.controller

import com.budgetbook.common.exception.TooManyRequestsException
import com.budgetbook.common.ratelimit.RateLimiter
import com.budgetbook.couple.dto.CoupleResponse
import com.budgetbook.couple.dto.InvitationResponse
import com.budgetbook.couple.dto.UserSummary
import com.budgetbook.couple.service.CoupleService
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.justRun
import io.mockk.mockk
import io.mockk.verify
import org.springframework.http.HttpStatus
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.Authentication
import java.time.Instant
import java.util.UUID

class CoupleControllerTest : FunSpec({

    val coupleService = mockk<CoupleService>()
    val rateLimiter = mockk<RateLimiter>()
    val controller = CoupleController(coupleService, rateLimiter)

    val testUserId = UUID.randomUUID()

    fun createAuthentication(userId: UUID): Authentication {
        return UsernamePasswordAuthenticationToken(userId, null, emptyList())
    }

    test("createInvitation returns 201 with invitation code") {
        val auth = createAuthentication(testUserId)
        val expectedResponse = InvitationResponse(
            code = "ABCD1234",
            expiresAt = Instant.now().plusSeconds(86400)
        )
        every { coupleService.createInvitation(testUserId) } returns expectedResponse

        val result = controller.createInvitation(auth)

        result.statusCode shouldBe HttpStatus.CREATED
        result.body!!.success shouldBe true
        result.body!!.data!!.code shouldBe "ABCD1234"
        verify(exactly = 1) { coupleService.createInvitation(testUserId) }
    }

    test("acceptInvitation returns couple info when rate limit not exceeded") {
        val auth = createAuthentication(testUserId)
        val request = MockHttpServletRequest().apply {
            remoteAddr = "127.0.0.1"
        }
        val partnerId = UUID.randomUUID()
        val expectedResponse = CoupleResponse(
            id = UUID.randomUUID(),
            partner = UserSummary(id = partnerId, nickname = "Partner", profileImageUrl = null),
            status = "ACTIVE",
            createdAt = Instant.now()
        )
        every { rateLimiter.tryAcquire(any(), any(), any()) } returns true
        every { coupleService.acceptInvitation(testUserId, "ABCD1234") } returns expectedResponse

        val result = controller.acceptInvitation(auth, "ABCD1234", request)

        result.success shouldBe true
        result.data!!.status shouldBe "ACTIVE"
        result.data!!.partner.id shouldBe partnerId
        verify(exactly = 1) { coupleService.acceptInvitation(testUserId, "ABCD1234") }
    }

    test("acceptInvitation throws TooManyRequestsException when rate limit exceeded") {
        val auth = createAuthentication(testUserId)
        val request = MockHttpServletRequest().apply {
            remoteAddr = "127.0.0.1"
        }
        every { rateLimiter.tryAcquire(any(), any(), any()) } returns false

        shouldThrow<TooManyRequestsException> {
            controller.acceptInvitation(auth, "ABCD1234", request)
        }
    }

    test("acceptInvitation uses X-Forwarded-For header for IP extraction") {
        val auth = createAuthentication(testUserId)
        val request = MockHttpServletRequest().apply {
            remoteAddr = "10.0.0.1"
            addHeader("X-Forwarded-For", "203.0.113.50, 70.41.3.18")
        }
        val expectedResponse = CoupleResponse(
            id = UUID.randomUUID(),
            partner = UserSummary(id = UUID.randomUUID(), nickname = "Partner", profileImageUrl = null),
            status = "ACTIVE",
            createdAt = Instant.now()
        )
        every { rateLimiter.tryAcquire("invite-accept:203.0.113.50", 5, 60000L) } returns true
        every { coupleService.acceptInvitation(testUserId, "CODE1234") } returns expectedResponse

        val result = controller.acceptInvitation(auth, "CODE1234", request)
        result.success shouldBe true
    }

    test("getMyCouple returns couple info") {
        val auth = createAuthentication(testUserId)
        val partnerId = UUID.randomUUID()
        val expectedResponse = CoupleResponse(
            id = UUID.randomUUID(),
            partner = UserSummary(id = partnerId, nickname = "Partner", profileImageUrl = "https://photo.jpg"),
            status = "ACTIVE",
            createdAt = Instant.now()
        )
        every { coupleService.getMyCouple(testUserId) } returns expectedResponse

        val result = controller.getMyCouple(auth)

        result.success shouldBe true
        result.data!!.partner.nickname shouldBe "Partner"
        verify(exactly = 1) { coupleService.getMyCouple(testUserId) }
    }

    test("dissolveCouple returns 204 No Content") {
        val auth = createAuthentication(testUserId)
        justRun { coupleService.dissolveCouple(testUserId) }

        val result = controller.dissolveCouple(auth)

        result.statusCode shouldBe HttpStatus.NO_CONTENT
        verify(exactly = 1) { coupleService.dissolveCouple(testUserId) }
    }
})
