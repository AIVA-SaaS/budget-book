package com.budgetbook.auth.security

import com.budgetbook.auth.service.JwtTokenProvider
import com.budgetbook.auth.service.UserCacheService
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.authority.SimpleGrantedAuthority
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter

@Component
class JwtAuthenticationFilter(
    private val jwtTokenProvider: JwtTokenProvider,
    private val userCacheService: UserCacheService
) : OncePerRequestFilter() {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun shouldNotFilter(request: HttpServletRequest): Boolean {
        val path = request.servletPath
        return path.startsWith("/actuator/") ||
               path.startsWith("/oauth2/") ||
               path.startsWith("/login/oauth2/") ||
               path == "/api/v1/health" ||
               path == "/api/v1/announcements/active"
    }

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain
    ) {
        val token = extractBearerToken(request)

        if (token != null) {
            val claims = jwtTokenProvider.parseAndValidateToken(token)
            if (claims != null) {
                try {
                    val userId = jwtTokenProvider.getUserIdFromClaims(claims)
                    val user = userCacheService.findById(userId)

                    if (user != null) {
                        val authorities = listOf(SimpleGrantedAuthority("ROLE_${user.role.name}"))
                        val authentication = UsernamePasswordAuthenticationToken(
                            user.id,
                            null,
                            authorities
                        )
                        authentication.details = WebAuthenticationDetailsSource().buildDetails(request)
                        SecurityContextHolder.getContext().authentication = authentication
                    }
                } catch (e: Exception) {
                    log.warn("Failed to set user authentication: {}", e.message)
                }
            }
        }

        filterChain.doFilter(request, response)
    }

    private fun extractBearerToken(request: HttpServletRequest): String? {
        val bearerToken = request.getHeader("Authorization")
        return if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            bearerToken.substring(7)
        } else {
            null
        }
    }
}
