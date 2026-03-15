package com.budgetbook.config

import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldContain
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import jakarta.servlet.FilterChain
import org.slf4j.MDC
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse

class RequestLoggingFilterTest : BehaviorSpec({

    val filter = RequestLoggingFilter()

    Given("a normal HTTP request without X-Correlation-Id header") {
        val request = MockHttpServletRequest("GET", "/api/v1/transactions")
        val response = MockHttpServletResponse()
        val filterChain = mockk<FilterChain>(relaxed = true)

        When("the filter processes the request") {
            filter.doFilter(request, response, filterChain)

            Then("a correlation ID should be generated and added to the response header") {
                val correlationId = response.getHeader("X-Correlation-Id")
                correlationId shouldNotBe null
                correlationId!!.length shouldBe 36 // UUID format
            }

            Then("the filter chain should be invoked") {
                verify(exactly = 1) { filterChain.doFilter(any(), any()) }
            }

            Then("MDC should be cleared after the request") {
                MDC.get("correlationId") shouldBe null
                MDC.get("requestPath") shouldBe null
            }
        }
    }

    Given("a request with an existing X-Correlation-Id header") {
        val existingCorrelationId = "test-correlation-id-123"
        val request = MockHttpServletRequest("POST", "/api/v1/transactions")
        request.addHeader("X-Correlation-Id", existingCorrelationId)
        val response = MockHttpServletResponse()
        val filterChain = mockk<FilterChain>(relaxed = true)

        When("the filter processes the request") {
            filter.doFilter(request, response, filterChain)

            Then("the existing correlation ID should be preserved in the response") {
                response.getHeader("X-Correlation-Id") shouldBe existingCorrelationId
            }
        }
    }

    Given("an actuator request") {
        val request = MockHttpServletRequest("GET", "/actuator/health")
        val response = MockHttpServletResponse()
        val filterChain = mockk<FilterChain>(relaxed = true)

        When("the filter processes the request") {
            filter.doFilter(request, response, filterChain)

            Then("the filter chain should still be invoked (filter is skipped for actuator)") {
                verify(exactly = 1) { filterChain.doFilter(any(), any()) }
            }

            Then("no correlation ID header should be set on the response (filter was skipped)") {
                response.getHeader("X-Correlation-Id") shouldBe null
            }
        }
    }

    Given("a slow request that takes more than 1000ms") {
        val request = MockHttpServletRequest("GET", "/api/v1/statistics")
        val response = MockHttpServletResponse()
        val filterChain = mockk<FilterChain>()
        every { filterChain.doFilter(any(), any()) } answers {
            Thread.sleep(50) // We can't easily simulate 1s+ in unit tests
        }

        When("the filter processes the request") {
            filter.doFilter(request, response, filterChain)

            Then("MDC should still be cleared after completion") {
                MDC.get("correlationId") shouldBe null
            }
        }
    }
})
