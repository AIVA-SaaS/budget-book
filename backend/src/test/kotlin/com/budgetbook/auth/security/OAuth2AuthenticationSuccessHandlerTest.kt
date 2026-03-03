package com.budgetbook.auth.security

import com.budgetbook.auth.config.AppProperties
import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.RefreshToken
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.RefreshTokenRepository
import com.budgetbook.auth.service.JwtTokenProvider
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldStartWith
import io.mockk.every
import io.mockk.mockk
import io.mockk.slot
import io.mockk.verify
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.oauth2.core.user.DefaultOAuth2User
import org.springframework.security.oauth2.core.user.OAuth2UserAuthority
import java.util.UUID

class OAuth2AuthenticationSuccessHandlerTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val jwtTokenProvider = mockk<JwtTokenProvider>()
    val refreshTokenRepository = mockk<RefreshTokenRepository>()
    val appProperties = AppProperties(frontendUrl = "https://budget-book.app")
    val handler = OAuth2AuthenticationSuccessHandler(jwtTokenProvider, refreshTokenRepository, appProperties)

    Given("a successful OAuth2 authentication") {
        val userId = UUID.randomUUID()
        val user = User(
            id = userId,
            email = "user@example.com",
            nickname = "Test User",
            provider = AuthProvider.GOOGLE,
            providerId = "google-123"
        )

        val attributes = mapOf<String, Any>("sub" to "google-123", "email" to "user@example.com")
        val authorities = listOf(OAuth2UserAuthority(attributes))
        val oAuth2User = DefaultOAuth2User(authorities, attributes, "sub")
        val customOAuth2User = CustomOAuth2User(oAuth2User, user)

        val authentication = UsernamePasswordAuthenticationToken(customOAuth2User, null, customOAuth2User.authorities)

        every { jwtTokenProvider.generateAccessToken(userId, "user@example.com") } returns "generated-access-token"
        every { jwtTokenProvider.generateRefreshToken() } returns "generated-refresh-token"
        every { jwtTokenProvider.getRefreshTokenExpiry() } returns 604800000L

        val refreshTokenSlot = slot<RefreshToken>()
        every { refreshTokenRepository.save(capture(refreshTokenSlot)) } answers { refreshTokenSlot.captured }

        When("onAuthenticationSuccess is called") {
            val request = MockHttpServletRequest()
            val response = MockHttpServletResponse()

            handler.onAuthenticationSuccess(request, response, authentication)

            Then("generates access and refresh tokens") {
                verify(exactly = 1) { jwtTokenProvider.generateAccessToken(userId, "user@example.com") }
                verify(exactly = 1) { jwtTokenProvider.generateRefreshToken() }
            }

            Then("saves the refresh token to the database") {
                verify(exactly = 1) { refreshTokenRepository.save(any()) }
                val savedToken = refreshTokenSlot.captured
                savedToken.user shouldBe user
                savedToken.token shouldBe "generated-refresh-token"
                savedToken.revoked shouldBe false
            }

            Then("redirects to frontend with encoded tokens") {
                val redirectUrl = response.redirectedUrl!!
                redirectUrl.shouldStartWith("https://budget-book.app/auth/callback?")
                redirectUrl.shouldContain("accessToken=generated-access-token")
                redirectUrl.shouldContain("refreshToken=generated-refresh-token")
            }
        }
    }
})
