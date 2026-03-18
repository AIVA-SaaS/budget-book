package com.budgetbook.config

import com.budgetbook.auth.config.AppProperties
import com.budgetbook.auth.security.CookieOAuth2AuthorizationRequestRepository
import com.budgetbook.auth.security.JwtAuthenticationFilter
import com.budgetbook.auth.security.OAuth2AuthenticationFailureHandler
import com.budgetbook.auth.security.OAuth2AuthenticationSuccessHandler
import com.budgetbook.auth.service.CustomOAuth2UserService
import com.budgetbook.auth.service.CustomOidcUserService
import com.fasterxml.jackson.databind.ObjectMapper
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.MediaType
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.core.AuthenticationException
import org.springframework.security.web.AuthenticationEntryPoint
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.CorsConfigurationSource
import org.springframework.web.cors.UrlBasedCorsConfigurationSource

@Configuration
@EnableWebSecurity
class SecurityConfig(
    private val jwtAuthenticationFilter: JwtAuthenticationFilter,
    private val customOAuth2UserService: CustomOAuth2UserService,
    private val customOidcUserService: CustomOidcUserService,
    private val oAuth2AuthenticationSuccessHandler: OAuth2AuthenticationSuccessHandler,
    private val oAuth2AuthenticationFailureHandler: OAuth2AuthenticationFailureHandler,
    private val cookieOAuth2AuthorizationRequestRepository: CookieOAuth2AuthorizationRequestRepository,
    private val appProperties: AppProperties
) {

    @Bean
    fun securityFilterChain(http: HttpSecurity): SecurityFilterChain {
        http
            .cors { it.configurationSource(corsConfigurationSource()) }
            .csrf { it.disable() }
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .authorizeHttpRequests { auth ->
                auth
                    .requestMatchers("/actuator/**").permitAll()
                    .requestMatchers("/api/v1/health").permitAll()
                    .requestMatchers("/oauth2/**").permitAll()
                    .requestMatchers("/login/oauth2/**").permitAll()
                    .requestMatchers("/api/v1/auth/refresh").permitAll()
                    .requestMatchers("/ws/**").permitAll()
                    .requestMatchers("/api/v1/announcements/active").permitAll()
                    .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
                    .anyRequest().authenticated()
            }
            .exceptionHandling { exceptions ->
                // Return 401 JSON for API requests instead of 302 redirect to OAuth login page
                exceptions.authenticationEntryPoint(ApiAwareAuthenticationEntryPoint())
            }
            .oauth2Login { oauth2 ->
                oauth2
                    .authorizationEndpoint { endpoint ->
                        endpoint.authorizationRequestRepository(cookieOAuth2AuthorizationRequestRepository)
                    }
                    .userInfoEndpoint {
                        it.userService(customOAuth2UserService)
                        it.oidcUserService(customOidcUserService)
                    }
                    .successHandler(oAuth2AuthenticationSuccessHandler)
                    .failureHandler(oAuth2AuthenticationFailureHandler)
            }
            .addFilterBefore(jwtAuthenticationFilter, UsernamePasswordAuthenticationFilter::class.java)

        return http.build()
    }

    /**
     * Custom entry point that returns 401 JSON for API requests
     * instead of redirecting to the OAuth2 login page.
     */
    class ApiAwareAuthenticationEntryPoint : AuthenticationEntryPoint {
        override fun commence(
            request: HttpServletRequest,
            response: HttpServletResponse,
            authException: AuthenticationException
        ) {
            response.status = HttpServletResponse.SC_UNAUTHORIZED
            response.contentType = MediaType.APPLICATION_JSON_VALUE
            val body = mapOf(
                "success" to false,
                "data" to null,
                "error" to mapOf(
                    "code" to "UNAUTHORIZED",
                    "message" to "Authentication required"
                )
            )
            ObjectMapper().writeValue(response.outputStream, body)
        }
    }

    @Bean
    fun corsConfigurationSource(): CorsConfigurationSource {
        // Extract origin (scheme + host + port) from frontendUrl which may contain a path
        val uri = java.net.URI(appProperties.frontendUrl)
        val origin = if (uri.port > 0) "${uri.scheme}://${uri.host}:${uri.port}" else "${uri.scheme}://${uri.host}"

        val configuration = CorsConfiguration().apply {
            allowedOrigins = listOf(origin)
            allowedMethods = listOf("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS")
            allowedHeaders = listOf("*")
            allowCredentials = true
            maxAge = 3600L
        }

        return UrlBasedCorsConfigurationSource().apply {
            registerCorsConfiguration("/**", configuration)
        }
    }
}
