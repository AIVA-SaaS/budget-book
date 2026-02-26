package com.budgetbook.auth.security

import com.budgetbook.auth.config.AppProperties
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.security.core.AuthenticationException
import org.springframework.security.web.authentication.AuthenticationFailureHandler
import org.springframework.stereotype.Component
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

@Component
class OAuth2AuthenticationFailureHandler(
    private val appProperties: AppProperties
) : AuthenticationFailureHandler {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun onAuthenticationFailure(
        request: HttpServletRequest,
        response: HttpServletResponse,
        exception: AuthenticationException
    ) {
        val errorMessage = URLEncoder.encode(
            exception.localizedMessage ?: "Authentication failed",
            StandardCharsets.UTF_8
        )

        val redirectUrl = "${appProperties.frontendUrl}/login?error=$errorMessage"

        log.warn("OAuth2 login failure: {}", exception.message)
        response.sendRedirect(redirectUrl)
    }
}
