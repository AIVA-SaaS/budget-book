package com.budgetbook.common.dto

import com.fasterxml.jackson.core.JsonParser
import com.fasterxml.jackson.databind.DeserializationContext
import com.fasterxml.jackson.databind.JsonDeserializer
import java.util.UUID

/**
 * Wrapper to distinguish "field absent" from "field explicitly set to null" in PUT/PATCH requests.
 *
 * Usage in DTO: `@JsonDeserialize(using = StringPatchValueDeserializer::class) val memo: PatchValue<String>? = null`
 * - JSON field absent  → null           (don't change)
 * - JSON "memo": null  → PatchValue(null)  (clear the field)
 * - JSON "memo": "txt" → PatchValue("txt") (set to value)
 */
data class PatchValue<T>(val value: T?)

class StringPatchValueDeserializer : JsonDeserializer<PatchValue<String>>() {
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext): PatchValue<String> {
        return PatchValue(p.valueAsString)
    }

    override fun getNullValue(ctxt: DeserializationContext): PatchValue<String> {
        return PatchValue(null)
    }
}

class UUIDPatchValueDeserializer : JsonDeserializer<PatchValue<UUID>>() {
    override fun deserialize(p: JsonParser, ctxt: DeserializationContext): PatchValue<UUID> {
        val text = p.valueAsString
        return PatchValue(if (text != null) UUID.fromString(text) else null)
    }

    override fun getNullValue(ctxt: DeserializationContext): PatchValue<UUID> {
        return PatchValue(null)
    }
}
