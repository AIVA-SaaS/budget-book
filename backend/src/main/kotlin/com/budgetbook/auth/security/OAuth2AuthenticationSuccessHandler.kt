package com.budgetbook.auth.security

import com.budgetbook.auth.config.AppProperties
import com.budgetbook.auth.domain.RefreshToken
import com.budgetbook.auth.repository.RefreshTokenRepository
import com.budgetbook.auth.service.JwtTokenProvider
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.security.core.Authentication
import org.springframework.security.web.authentication.AuthenticationSuccessHandler
import org.springframework.stereotype.Component
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.time.Instant

@Component
class OAuth2AuthenticationSuccessHandler(
    private val jwtTokenProvider: JwtTokenProvider,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val appProperties: AppProperties
) : AuthenticationSuccessHandler {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun onAuthenticationSuccess(
        request: HttpServletRequest,
        response: HttpServletResponse,
        authentication: Authentication
    ) {
        val customOAuth2User = authentication.principal as CustomOAuth2User
        val user = customOAuth2User.getUser()

        val accessToken = jwtTokenProvider.generateAccessToken(user.id, user.email)
        val refreshTokenValue = jwtTokenProvider.generateRefreshToken()

        val refreshToken = RefreshToken(
            user = user,
            token = refreshTokenValue,
            expiresAt = Instant.now().plusMillis(jwtTokenProvider.getRefreshTokenExpiry())
        )
        refreshTokenRepository.save(refreshToken)

        val encodedAccessToken = URLEncoder.encode(accessToken, StandardCharsets.UTF_8)
        val encodedRefreshToken = URLEncoder.encode(refreshTokenValue, StandardCharsets.UTF_8)

        val redirectUrl = "${appProperties.frontendUrl}/auth/callback" +
            "?accessToken=$encodedAccessToken" +
            "&refreshToken=$encodedRefreshToken"

        log.debug("OAuth2 login success - redirecting to: {}", appProperties.frontendUrl)
        response.sendRedirect(redirectUrl)
    }
}
