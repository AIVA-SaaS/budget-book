package com.budgetbook.common.ratelimit

import com.budgetbook.common.exception.TooManyRequestsException
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.aspectj.lang.ProceedingJoinPoint
import org.aspectj.lang.reflect.MethodSignature
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import java.util.UUID

class RateLimitAspectTest : BehaviorSpec({

    afterEach {
        SecurityContextHolder.clearContext()
    }

    Given("a RateLimitAspect with USER key type") {
        val rateLimiter = RateLimiter()
        val aspect = RateLimitAspect(rateLimiter)
        val userId = UUID.randomUUID()

        val joinPoint = mockk<ProceedingJoinPoint>()
        val signature = mockk<MethodSignature>()
        every { joinPoint.signature } returns signature
        every { signature.name } returns "createTransaction"
        every { joinPoint.proceed() } returns "result"

        val rateLimit = mockk<RateLimit>()
        every { rateLimit.maxRequests } returns 3
        every { rateLimit.windowSeconds } returns 60
        every { rateLimit.keyType } returns RateLimitKeyType.USER

        val auth = UsernamePasswordAuthenticationToken(userId, null, emptyList())
        SecurityContextHolder.getContext().authentication = auth

        When("requests are within the limit") {
            Then("allows all requests") {
                repeat(3) {
                    val result = aspect.checkRateLimit(joinPoint, rateLimit)
                    result shouldBe "result"
                }
            }
        }

        When("requests exceed the limit") {
            val freshLimiter = RateLimiter()
            val freshAspect = RateLimitAspect(freshLimiter)

            repeat(3) {
                freshAspect.checkRateLimit(joinPoint, rateLimit)
            }

            Then("throws TooManyRequestsException") {
                shouldThrow<TooManyRequestsException> {
                    freshAspect.checkRateLimit(joinPoint, rateLimit)
                }
            }
        }
    }

    Given("a RateLimitAspect with different method names") {
        val rateLimiter = RateLimiter()
        val aspect = RateLimitAspect(rateLimiter)
        val userId = UUID.randomUUID()

        val auth = UsernamePasswordAuthenticationToken(userId, null, emptyList())
        SecurityContextHolder.getContext().authentication = auth

        val rateLimit = mockk<RateLimit>()
        every { rateLimit.maxRequests } returns 2
        every { rateLimit.windowSeconds } returns 60
        every { rateLimit.keyType } returns RateLimitKeyType.USER

        When("different methods are called") {
            val joinPoint1 = mockk<ProceedingJoinPoint>()
            val sig1 = mockk<MethodSignature>()
            every { joinPoint1.signature } returns sig1
            every { sig1.name } returns "methodA"
            every { joinPoint1.proceed() } returns "a"

            val joinPoint2 = mockk<ProceedingJoinPoint>()
            val sig2 = mockk<MethodSignature>()
            every { joinPoint2.signature } returns sig2
            every { sig2.name } returns "methodB"
            every { joinPoint2.proceed() } returns "b"

            Then("rate limits are tracked independently per method") {
                repeat(2) { aspect.checkRateLimit(joinPoint1, rateLimit) }
                // methodA is at limit, but methodB should still work
                val result = aspect.checkRateLimit(joinPoint2, rateLimit)
                result shouldBe "b"
            }
        }
    }

    Given("proceed is called on allowed requests") {
        val rateLimiter = RateLimiter()
        val aspect = RateLimitAspect(rateLimiter)
        val userId = UUID.randomUUID()

        val auth = UsernamePasswordAuthenticationToken(userId, null, emptyList())
        SecurityContextHolder.getContext().authentication = auth

        val joinPoint = mockk<ProceedingJoinPoint>()
        val signature = mockk<MethodSignature>()
        every { joinPoint.signature } returns signature
        every { signature.name } returns "testMethod"
        every { joinPoint.proceed() } returns "success"

        val rateLimit = mockk<RateLimit>()
        every { rateLimit.maxRequests } returns 5
        every { rateLimit.windowSeconds } returns 60
        every { rateLimit.keyType } returns RateLimitKeyType.USER

        When("request is allowed") {
            val result = aspect.checkRateLimit(joinPoint, rateLimit)

            Then("joinPoint.proceed() is called and result returned") {
                result shouldBe "success"
                verify(exactly = 1) { joinPoint.proceed() }
            }
        }
    }
})
