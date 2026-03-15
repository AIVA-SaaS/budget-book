package com.budgetbook.config

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.LoggingEvent
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldEndWith
import io.kotest.matchers.string.shouldNotContain
import io.kotest.matchers.string.shouldStartWith
import org.slf4j.LoggerFactory
import org.slf4j.MDC

class JsonLogLayoutTest : BehaviorSpec({

    val layout = JsonLogLayout().apply { start() }
    // Use the SLF4J-backed logger so MDC adapter is initialized
    val testLogger = LoggerFactory.getLogger("com.budgetbook.TestLogger") as Logger

    fun createEvent(level: Level, message: String): LoggingEvent {
        return LoggingEvent(
            "com.budgetbook.TestLogger",
            testLogger,
            level,
            message,
            null,
            null
        ).apply {
            threadName = "main"
            timeStamp = 1700000000000L
        }
    }

    Given("a logging event with basic fields") {
        val event = createEvent(Level.INFO, "Test message")

        When("the layout formats the event") {
            val result = layout.doLayout(event)

            Then("it should produce valid JSON with expected fields") {
                result shouldStartWith "{"
                result.trim() shouldEndWith "}"
                result shouldContain "\"timestamp\":"
                result shouldContain "\"level\":\"INFO\""
                result shouldContain "\"logger\":\"com.budgetbook.TestLogger\""
                result shouldContain "\"message\":\"Test message\""
                result shouldContain "\"thread\":\"main\""
            }

            Then("it should end with a newline") {
                result shouldEndWith "\n"
            }
        }
    }

    Given("a logging event created while MDC has correlation and path values") {
        When("the layout formats the event") {
            MDC.put("correlationId", "abc-123")
            MDC.put("requestPath", "/api/v1/test")
            val event = createEvent(Level.WARN, "Slow request")
            val result = layout.doLayout(event)
            MDC.clear()

            Then("it should include correlation_id and request_path") {
                result shouldContain "\"correlation_id\":\"abc-123\""
                result shouldContain "\"request_path\":\"/api/v1/test\""
            }
        }
    }

    Given("a logging event with special characters in the message") {
        val event = createEvent(Level.ERROR, "Error with \"quotes\" and\nnewlines")

        When("the layout formats the event") {
            val result = layout.doLayout(event)

            Then("special characters should be escaped") {
                result shouldContain "\\\"quotes\\\""
                result shouldContain "\\n"
            }
        }
    }

    Given("a logging event without MDC values") {
        MDC.clear()
        val event = createEvent(Level.DEBUG, "No MDC")

        When("the layout formats the event") {
            val result = layout.doLayout(event)

            Then("it should not include correlation_id or request_path fields") {
                result shouldNotContain "correlation_id"
                result shouldNotContain "request_path"
            }

            Then("it should still include standard fields") {
                result shouldContain "\"message\":\"No MDC\""
                result shouldContain "\"level\":\"DEBUG\""
            }
        }
    }
})
