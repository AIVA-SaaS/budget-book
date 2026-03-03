package com.budgetbook.auth.security

import com.budgetbook.auth.config.AppProperties
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldStartWith
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.security.authentication.BadCredentialsException
import org.springframework.security.oauth2.core.OAuth2AuthenticationException
import org.springframework.security.oauth2.core.OAuth2Error

class OAuth2AuthenticationFailureHandlerTest : BehaviorSpec({

    val appProperties = AppProperties(frontendUrl = "https://budget-book.app")
    val handler = OAuth2AuthenticationFailureHandler(appProperties)

    Given("an OAuth2 authentication failure with a message") {
        val exception = BadCredentialsException("Invalid credentials")

        When("onAuthenticationFailure is called") {
            val request = MockHttpServletRequest()
            val response = MockHttpServletResponse()

            handler.onAuthenticationFailure(request, response, exception)

            Then("redirects to frontend login page with error message") {
                val redirectUrl = response.redirectedUrl!!
                redirectUrl.shouldStartWith("https://budget-book.app/login?error=")
                redirectUrl.shouldContain("Invalid+credentials")
            }
        }
    }

    Given("an OAuth2 authentication failure with OAuth2Error") {
        val error = OAuth2Error("invalid_token", "The token is expired", null)
        val exception = OAuth2AuthenticationException(error)

        When("onAuthenticationFailure is called") {
            val request = MockHttpServletRequest()
            val response = MockHttpServletResponse()

            handler.onAuthenticationFailure(request, response, exception)

            Then("redirects with the OAuth2 error description") {
                val redirectUrl = response.redirectedUrl!!
                redirectUrl.shouldStartWith("https://budget-book.app/login?error=")
            }
        }
    }
})
