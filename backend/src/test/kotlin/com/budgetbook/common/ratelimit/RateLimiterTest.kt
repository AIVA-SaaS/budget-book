package com.budgetbook.common.ratelimit

import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe

class RateLimiterTest : BehaviorSpec({

    Given("a RateLimiter with 5 requests per 60 seconds") {
        val rateLimiter = RateLimiter()
        val key = "test-key"
        val maxRequests = 5
        val windowMillis = 60_000L

        When("requests are within the limit") {
            Then("allows all requests up to the limit") {
                repeat(5) { i ->
                    rateLimiter.tryAcquire(key, maxRequests, windowMillis) shouldBe true
                }
            }
        }

        When("requests exceed the limit") {
            val limiter = RateLimiter()
            repeat(5) { limiter.tryAcquire(key, maxRequests, windowMillis) }

            Then("blocks the 6th request") {
                limiter.tryAcquire(key, maxRequests, windowMillis) shouldBe false
            }
        }

        When("different keys are used") {
            val limiter = RateLimiter()
            repeat(5) { limiter.tryAcquire("key-1", maxRequests, windowMillis) }

            Then("allows requests from a different key") {
                limiter.tryAcquire("key-2", maxRequests, windowMillis) shouldBe true
            }

            Then("blocks the original key") {
                limiter.tryAcquire("key-1", maxRequests, windowMillis) shouldBe false
            }
        }
    }

    Given("a RateLimiter after window expiration") {
        val rateLimiter = RateLimiter()
        val key = "expiry-test"
        val maxRequests = 2
        val windowMillis = 1L // 1ms window for testing

        When("the window has expired") {
            repeat(2) { rateLimiter.tryAcquire(key, maxRequests, windowMillis) }
            // Wait for window to expire
            Thread.sleep(5)

            Then("allows new requests after window reset") {
                rateLimiter.tryAcquire(key, maxRequests, windowMillis) shouldBe true
            }
        }
    }

    Given("cleanup is called") {
        val rateLimiter = RateLimiter()
        val key = "cleanup-test"

        When("entries exist and window expired") {
            rateLimiter.tryAcquire(key, 5, 1L)
            Thread.sleep(5)
            rateLimiter.cleanup(1L)

            Then("expired entries are removed and new requests are allowed") {
                rateLimiter.tryAcquire(key, 1, 60_000L) shouldBe true
            }
        }
    }
})
