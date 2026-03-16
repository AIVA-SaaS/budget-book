package com.budgetbook.auth.security

import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import jakarta.servlet.http.Cookie
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.security.oauth2.core.endpoint.OAuth2AuthorizationRequest
import java.util.Base64

class CookieOAuth2AuthorizationRequestRepositoryTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val repository = CookieOAuth2AuthorizationRequestRepository()

    fun buildAuthorizationRequest(state: String = "test-state"): OAuth2AuthorizationRequest {
        return OAuth2AuthorizationRequest.authorizationCode()
            .clientId("test-client-id")
            .authorizationUri("https://accounts.google.com/o/oauth2/auth")
            .redirectUri("http://localhost:8080/login/oauth2/code/google")
            .scopes(setOf("openid", "profile", "email"))
            .state(state)
            .build()
    }

    Given("saveAuthorizationRequest") {
        When("a non-null authorization request is provided") {
            val request = MockHttpServletRequest()
            val response = MockHttpServletResponse()
            val authRequest = buildAuthorizationRequest()

            repository.saveAuthorizationRequest(authRequest, request, response)

            Then("sets an oauth2_auth_request cookie in the response") {
                val cookie = response.getCookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME)
                cookie.shouldNotBeNull()
                cookie.isHttpOnly shouldBe true
                cookie.secure shouldBe true
                cookie.path shouldBe "/"
                cookie.maxAge shouldBe CookieOAuth2AuthorizationRequestRepository.COOKIE_MAX_AGE_SECONDS
            }
        }

        When("a null authorization request is provided") {
            val request = MockHttpServletRequest()
            val response = MockHttpServletResponse()

            repository.saveAuthorizationRequest(null, request, response)

            Then("sets a cookie with maxAge=0 to clear it") {
                val cookie = response.getCookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME)
                cookie.shouldNotBeNull()
                cookie.maxAge shouldBe 0
            }
        }
    }

    Given("loadAuthorizationRequest") {
        When("the cookie exists with a valid serialized request") {
            // First save to get a valid cookie value
            val saveRequest = MockHttpServletRequest()
            val saveResponse = MockHttpServletResponse()
            val authRequest = buildAuthorizationRequest("load-test-state")

            repository.saveAuthorizationRequest(authRequest, saveRequest, saveResponse)

            val savedCookie = saveResponse.getCookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME)!!

            // Now load from a new request that has the cookie
            val loadRequest = MockHttpServletRequest()
            loadRequest.setCookies(Cookie(savedCookie.name, savedCookie.value))

            val loaded = repository.loadAuthorizationRequest(loadRequest)

            Then("deserializes and returns the original authorization request") {
                loaded.shouldNotBeNull()
                loaded.clientId shouldBe "test-client-id"
                loaded.state shouldBe "load-test-state"
                loaded.authorizationUri shouldBe "https://accounts.google.com/o/oauth2/auth"
                loaded.redirectUri shouldBe "http://localhost:8080/login/oauth2/code/google"
                loaded.scopes shouldBe setOf("openid", "profile", "email")
            }
        }

        When("no cookie exists") {
            val request = MockHttpServletRequest()

            val loaded = repository.loadAuthorizationRequest(request)

            Then("returns null") {
                loaded.shouldBeNull()
            }
        }

        When("the cookie contains invalid data") {
            val request = MockHttpServletRequest()
            request.setCookies(Cookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME, "invalid-base64-data"))

            val loaded = repository.loadAuthorizationRequest(request)

            Then("returns null without throwing an exception") {
                loaded.shouldBeNull()
            }
        }

        When("the cookie data has been tampered with") {
            // First save a valid cookie
            val saveRequest = MockHttpServletRequest()
            val saveResponse = MockHttpServletResponse()
            val authRequest = buildAuthorizationRequest("tamper-test")

            repository.saveAuthorizationRequest(authRequest, saveRequest, saveResponse)

            val savedCookie = saveResponse.getCookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME)!!

            // Tamper with the cookie value by modifying bytes after decoding
            val originalBytes = Base64.getUrlDecoder().decode(savedCookie.value)
            // Flip a byte in the data portion (after the 32-byte HMAC)
            val tamperedBytes = originalBytes.copyOf()
            if (tamperedBytes.size > CookieOAuth2AuthorizationRequestRepository.HMAC_LENGTH + 1) {
                tamperedBytes[CookieOAuth2AuthorizationRequestRepository.HMAC_LENGTH + 1] =
                    (tamperedBytes[CookieOAuth2AuthorizationRequestRepository.HMAC_LENGTH + 1].toInt() xor 0xFF).toByte()
            }
            val tamperedValue = Base64.getUrlEncoder().withoutPadding().encodeToString(tamperedBytes)

            val loadRequest = MockHttpServletRequest()
            loadRequest.setCookies(Cookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME, tamperedValue))

            val loaded = repository.loadAuthorizationRequest(loadRequest)

            Then("returns null because HMAC verification fails") {
                loaded.shouldBeNull()
            }
        }

        When("the cookie data is too short to contain an HMAC signature") {
            val shortData = Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(16))
            val request = MockHttpServletRequest()
            request.setCookies(Cookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME, shortData))

            val loaded = repository.loadAuthorizationRequest(request)

            Then("returns null") {
                loaded.shouldBeNull()
            }
        }

        When("the cookie was signed by a different instance (different HMAC key)") {
            // Save with one repository instance
            val saveRequest = MockHttpServletRequest()
            val saveResponse = MockHttpServletResponse()
            val authRequest = buildAuthorizationRequest("cross-instance-test")

            repository.saveAuthorizationRequest(authRequest, saveRequest, saveResponse)

            val savedCookie = saveResponse.getCookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME)!!

            // Try to load with a different repository instance (different HMAC key)
            val otherRepository = CookieOAuth2AuthorizationRequestRepository()
            val loadRequest = MockHttpServletRequest()
            loadRequest.setCookies(Cookie(savedCookie.name, savedCookie.value))

            val loaded = otherRepository.loadAuthorizationRequest(loadRequest)

            Then("returns null because the HMAC keys differ") {
                loaded.shouldBeNull()
            }
        }
    }

    Given("removeAuthorizationRequest") {
        When("a cookie exists with a valid request") {
            val saveRequest = MockHttpServletRequest()
            val saveResponse = MockHttpServletResponse()
            val authRequest = buildAuthorizationRequest("remove-test-state")

            repository.saveAuthorizationRequest(authRequest, saveRequest, saveResponse)

            val savedCookie = saveResponse.getCookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME)!!

            val removeRequest = MockHttpServletRequest()
            removeRequest.setCookies(Cookie(savedCookie.name, savedCookie.value))
            val removeResponse = MockHttpServletResponse()

            @Suppress("DEPRECATION")
            val removed = repository.removeAuthorizationRequest(removeRequest, removeResponse)

            Then("returns the authorization request") {
                removed.shouldNotBeNull()
                removed.state shouldBe "remove-test-state"
            }

            Then("clears the cookie by setting maxAge=0") {
                val clearedCookie = removeResponse.getCookie(CookieOAuth2AuthorizationRequestRepository.COOKIE_NAME)
                clearedCookie.shouldNotBeNull()
                clearedCookie.maxAge shouldBe 0
            }
        }

        When("no cookie exists") {
            val request = MockHttpServletRequest()
            val response = MockHttpServletResponse()

            @Suppress("DEPRECATION")
            val removed = repository.removeAuthorizationRequest(request, response)

            Then("returns null") {
                removed.shouldBeNull()
            }
        }
    }
})
