package com.budgetbook.common.cache

import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.springframework.data.redis.core.RedisTemplate
import org.springframework.data.redis.core.ValueOperations
import java.time.Duration

class RedisCacheServiceTest : BehaviorSpec({

    Given("RedisCacheService with no Redis template (Redis unavailable)") {
        val service = RedisCacheService()

        When("isAvailable is checked") {
            Then("returns false") {
                service.isAvailable shouldBe false
            }
        }

        When("get is called") {
            val result = service.get("some-key")
            Then("returns null") {
                result shouldBe null
            }
        }

        When("set is called") {
            Then("does nothing (no-op)") {
                service.set("key", "value") // Should not throw
            }
        }

        When("evict is called") {
            Then("does nothing (no-op)") {
                service.evict("key") // Should not throw
            }
        }

        When("evictByPattern is called") {
            Then("does nothing (no-op)") {
                service.evictByPattern("key:*") // Should not throw
            }
        }
    }

    Given("RedisCacheService with a Redis template available") {
        val redisTemplate = mockk<RedisTemplate<String, String>>()
        val valueOps = mockk<ValueOperations<String, String>>()
        every { redisTemplate.opsForValue() } returns valueOps

        val service = RedisCacheService()
        // Use reflection to set the private field since @Autowired(required = false)
        val field = RedisCacheService::class.java.getDeclaredField("redisTemplate")
        field.isAccessible = true
        field.set(service, redisTemplate)

        When("isAvailable is checked") {
            Then("returns true") {
                service.isAvailable shouldBe true
            }
        }

        When("get is called and key exists") {
            every { valueOps.get("test-key") } returns "test-value"
            val result = service.get("test-key")

            Then("returns the cached value") {
                result shouldBe "test-value"
            }
        }

        When("get is called and key does not exist") {
            every { valueOps.get("missing-key") } returns null
            val result = service.get("missing-key")

            Then("returns null") {
                result shouldBe null
            }
        }

        When("set is called") {
            every { valueOps.set("new-key", "new-value", Duration.ofMinutes(5)) } returns Unit
            service.set("new-key", "new-value", Duration.ofMinutes(5))

            Then("delegates to Redis template") {
                verify { valueOps.set("new-key", "new-value", Duration.ofMinutes(5)) }
            }
        }

        When("evict is called") {
            every { redisTemplate.delete("del-key") } returns true
            service.evict("del-key")

            Then("deletes the key") {
                verify { redisTemplate.delete("del-key") }
            }
        }

        When("evictByPattern is called") {
            every { redisTemplate.keys("prefix:*") } returns setOf("prefix:1", "prefix:2")
            every { redisTemplate.delete(setOf("prefix:1", "prefix:2")) } returns 2

            service.evictByPattern("prefix:*")

            Then("finds and deletes matching keys") {
                verify { redisTemplate.keys("prefix:*") }
                verify { redisTemplate.delete(setOf("prefix:1", "prefix:2")) }
            }
        }

        When("get throws an exception") {
            every { valueOps.get("error-key") } throws RuntimeException("Connection lost")
            val result = service.get("error-key")

            Then("returns null gracefully") {
                result shouldBe null
            }
        }
    }
})
