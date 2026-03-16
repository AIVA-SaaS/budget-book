package com.budgetbook.auth.security

import com.fasterxml.jackson.annotation.JsonCreator
import com.fasterxml.jackson.annotation.JsonProperty
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.security.oauth2.client.web.AuthorizationRequestRepository
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest
import org.springframework.stereotype.Component
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/**
 * Cookie-based OAuth2AuthorizationRequestRepository.
 *
 * Spring Security's default repository stores the OAuth2AuthorizationRequest in the
 * HTTP session, which does not work when session policy is STATELESS.
 * This implementation serializes the request into a secure, HttpOnly cookie using
 * compact JSON instead of Java serialization to keep cookie size well under 4KB.
 *
 * Security measures:
 * - HMAC-SHA256 signature prevents deserialization of tampered cookie data
 * - HttpOnly + Secure + SameSite=Lax cookie attributes
 *
 * The HMAC key is generated at startup via SecureRandom. Since OAuth2 flows are
 * short-lived (3 minute cookie TTL), the key does not need to persist across restarts.
 *
 * Note: HttpCookieOAuth2AuthorizationRequestRepository is available in Spring Security 6.4+,
 * but this project uses Spring Boot 3.2.5 (Spring Security 6.2.x), so we need a custom impl.
 */
@Component
class CookieOAuth2AuthorizationRequestRepository : AuthorizationRequestRepository<OAuth2AuthorizationRequest> {

    private val log = LoggerFactory.getLogger(javaClass)

    private val objectMapper: ObjectMapper = jacksonObjectMapper()

    private val hmacKey: SecretKeySpec = SecretKeySpec(
        ByteArray(32).also { SecureRandom().nextBytes(it) },
        HMAC_ALGORITHM
    )

    companion object {
        const val COOKIE_NAME = "oauth2_auth_request"
        const val COOKIE_MAX_AGE_SECONDS = 180 // 3 minutes -- enough for OAuth2 round trip
        internal const val HMAC_ALGORITHM = "HmacSHA256"
        internal const val HMAC_LENGTH = 32 // HMAC-SHA256 produces 32 bytes
    }

    /**
     * Compact DTO that captures only the essential fields of OAuth2AuthorizationRequest.
     * Serialized as JSON (~500-1500 bytes) instead of Java serialization (~2-4KB).
     */
    internal data class OAuth2AuthorizationRequestData @JsonCreator constructor(
        @JsonProperty("au") val authorizationUri: String,
        @JsonProperty("ci") val clientId: String,
        @JsonProperty("ru") val redirectUri: String?,
        @JsonProperty("sc") val scopes: Set<String>,
        @JsonProperty("st") val state: String?,
        @JsonProperty("gt") val authorizationGrantType: String,
        @JsonProperty("ap") val additionalParameters: Map<String, String>,
        @JsonProperty("at") val attributes: Map<String, String>
    ) {
        fun toOAuth2AuthorizationRequest(): OAuth2AuthorizationRequest {
            // Only authorization_code grant type is used in this application
            val builder = OAuth2AuthorizationRequest.authorizationCode()

            return builder
                .authorizationUri(authorizationUri)
                .clientId(clientId)
                .apply { redirectUri?.let { redirectUri(it) } }
                .scopes(scopes)
                .apply { state?.let { state(it) } }
                .additionalParameters(additionalParameters)
                .attributes { attrs -> attrs.putAll(this@OAuth2AuthorizationRequestData.attributes) }
                .build()
        }

        companion object {
            fun from(request: OAuth2AuthorizationRequest): OAuth2AuthorizationRequestData {
                // Filter attributes to only String values (registration_id, code_verifier, etc.)
                val stringAttributes = request.attributes
                    .filter { (_, v) -> v is String }
                    .mapValues { (_, v) -> v as String }

                // Filter additionalParameters to only String values
                val stringAdditionalParams = request.additionalParameters
                    .filter { (_, v) -> v is String }
                    .mapValues { (_, v) -> v as String }

                return OAuth2AuthorizationRequestData(
                    authorizationUri = request.authorizationUri,
                    clientId = request.clientId,
                    redirectUri = request.redirectUri,
                    scopes = request.scopes,
                    state = request.state,
                    authorizationGrantType = request.grantType.value,
                    additionalParameters = stringAdditionalParams,
                    attributes = stringAttributes
                )
            }
        }
    }

    override fun loadAuthorizationRequest(request: HttpServletRequest): OAuth2AuthorizationRequest? {
        return getCookie(request, COOKIE_NAME)?.let { cookie ->
            deserialize(cookie.value)
        }
    }

    override fun saveAuthorizationRequest(
        authorizationRequest: OAuth2AuthorizationRequest?,
        request: HttpServletRequest,
        response: HttpServletResponse
    ) {
        if (authorizationRequest == null) {
            removeCookie(response)
            return
        }

        val serialized = serialize(authorizationRequest)
        val cookie = Cookie(COOKIE_NAME, serialized).apply {
            path = "/"
            isHttpOnly = true
            secure = true
            maxAge = COOKIE_MAX_AGE_SECONDS
            // SameSite=Lax is needed for OAuth2 redirects (GET requests from external IdP)
            setAttribute("SameSite", "Lax")
        }
        response.addCookie(cookie)
    }

    @Deprecated("Deprecated in interface", replaceWith = ReplaceWith("loadAuthorizationRequest(request)"))
    override fun removeAuthorizationRequest(
        request: HttpServletRequest,
        response: HttpServletResponse
    ): OAuth2AuthorizationRequest? {
        val authorizationRequest = loadAuthorizationRequest(request)
        if (authorizationRequest != null) {
            removeCookie(response)
        }
        return authorizationRequest
    }

    private fun removeCookie(response: HttpServletResponse) {
        val cookie = Cookie(COOKIE_NAME, "").apply {
            path = "/"
            isHttpOnly = true
            secure = true
            maxAge = 0
        }
        response.addCookie(cookie)
    }

    private fun getCookie(request: HttpServletRequest, name: String): Cookie? {
        return request.cookies?.firstOrNull { it.name == name }
    }

    internal fun serialize(request: OAuth2AuthorizationRequest): String {
        val dto = OAuth2AuthorizationRequestData.from(request)
        val data = objectMapper.writeValueAsBytes(dto)
        val signature = computeHmac(data)

        // Prepend HMAC signature to the JSON data
        val combined = ByteArray(HMAC_LENGTH + data.size)
        System.arraycopy(signature, 0, combined, 0, HMAC_LENGTH)
        System.arraycopy(data, 0, combined, HMAC_LENGTH, data.size)

        return Base64.getUrlEncoder().withoutPadding().encodeToString(combined)
    }

    internal fun deserialize(value: String): OAuth2AuthorizationRequest? {
        return try {
            val combined = Base64.getUrlDecoder().decode(value)

            if (combined.size <= HMAC_LENGTH) {
                log.warn("Cookie data too short to contain HMAC signature")
                return null
            }

            val signature = combined.copyOfRange(0, HMAC_LENGTH)
            val data = combined.copyOfRange(HMAC_LENGTH, combined.size)

            // Verify HMAC before any deserialization
            if (!verifyHmac(data, signature)) {
                log.warn("Cookie HMAC verification failed - rejecting potentially tampered data")
                return null
            }

            val dto = objectMapper.readValue(data, OAuth2AuthorizationRequestData::class.java)
            dto.toOAuth2AuthorizationRequest()
        } catch (e: Exception) {
            log.warn("Failed to deserialize OAuth2AuthorizationRequest from cookie: {}", e.message)
            null
        }
    }

    private fun computeHmac(data: ByteArray): ByteArray {
        val mac = Mac.getInstance(HMAC_ALGORITHM)
        mac.init(hmacKey)
        return mac.doFinal(data)
    }

    private fun verifyHmac(data: ByteArray, expectedSignature: ByteArray): Boolean {
        val actualSignature = computeHmac(data)
        // Constant-time comparison to prevent timing attacks
        return java.security.MessageDigest.isEqual(actualSignature, expectedSignature)
    }
}
