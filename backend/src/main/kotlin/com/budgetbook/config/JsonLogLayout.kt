package com.budgetbook.config

import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.classic.spi.ThrowableProxyUtil
import ch.qos.logback.core.LayoutBase
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * Custom JSON layout for structured logging in production.
 * Outputs one JSON object per line with: timestamp, level, logger, message,
 * correlation_id, request_path, and optional stack_trace.
 *
 * This avoids pulling in the logstash-logback-encoder dependency.
 */
class JsonLogLayout : LayoutBase<ILoggingEvent>() {

    private val formatter = DateTimeFormatter.ISO_INSTANT

    override fun doLayout(event: ILoggingEvent): String {
        val sb = StringBuilder(256)
        sb.append('{')
        appendField(sb, "timestamp", formatTimestamp(event.timeStamp), first = true)
        appendField(sb, "level", event.level.toString())
        appendField(sb, "logger", event.loggerName)
        appendField(sb, "message", escapeJson(event.formattedMessage ?: event.message ?: ""))
        appendField(sb, "thread", event.threadName)

        val mdc = try { event.mdcPropertyMap } catch (_: Exception) { null }
        if (mdc != null) {
            val correlationId = mdc["correlationId"]
            if (!correlationId.isNullOrEmpty()) {
                appendField(sb, "correlation_id", correlationId)
            }

            val requestPath = mdc["requestPath"]
            if (!requestPath.isNullOrEmpty()) {
                appendField(sb, "request_path", requestPath)
            }
        }

        if (event.throwableProxy != null) {
            appendField(sb, "stack_trace", escapeJson(ThrowableProxyUtil.asString(event.throwableProxy)))
        }

        sb.append("}\n")
        return sb.toString()
    }

    private fun formatTimestamp(epochMillis: Long): String {
        return Instant.ofEpochMilli(epochMillis).atOffset(ZoneOffset.UTC).format(formatter)
    }

    private fun appendField(sb: StringBuilder, key: String, value: String, first: Boolean = false) {
        if (!first) sb.append(',')
        sb.append('"').append(key).append("\":\"").append(value).append('"')
    }

    private fun escapeJson(text: String): String {
        return text
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t")
    }
}
