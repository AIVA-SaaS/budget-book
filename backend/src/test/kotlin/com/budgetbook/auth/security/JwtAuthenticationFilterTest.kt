package com.budgetbook.auth.security

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.domain.UserRole
import com.budgetbook.auth.service.JwtTokenProvider
import com.budgetbook.auth.service.UserCacheService
import io.jsonwebtoken.Claims
import io.kotest.core.spec.IsolationMode
import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.nulls.shouldBeNull
import io.kotest.matchers.nulls.shouldNotBeNull
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import jakarta.servlet.FilterChain
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import org.springframework.security.core.context.SecurityContextHolder
import java.util.UUID

class JwtAuthenticationFilterTest : BehaviorSpec({

    isolationMode = IsolationMode.InstancePerLeaf

    val jwtTokenProvider = mockk<JwtTokenProvider>()
    val userCacheService = mockk<UserCacheService>()
    val filterChain = mockk<FilterChain>(relaxed = true)
    val filter = JwtAuthenticationFilter(jwtTokenProvider, userCacheService)

    afterEach {
        SecurityContextHolder.clearContext()
    }

    fun mockClaims(userId: UUID): Claims {
        val claims = mockk<Claims>()
        every { claims.subject } returns userId.toString()
        return claims
    }

    Given("a request with a valid Bearer token") {
        val userId = UUID.randomUUID()
        val token = "valid-jwt-token"
        val claims = mockClaims(userId)
        val user = User(
            id = userId,
            email = "test@example.com",
            nickname = "Test",
            provider = AuthProvider.GOOGLE,
            providerId = "google-123"
        )

        every { jwtTokenProvider.parseAndValidateToken(token) } returns claims
        every { jwtTokenProvider.getUserIdFromClaims(claims) } returns userId
        every { userCacheService.findById(userId) } returns user

        When("the filter processes the request") {
            val request = MockHttpServletRequest().apply {
                addHeader("Authorization", "Bearer $token")
            }
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("sets authentication in SecurityContext with correct principal and authority") {
                val auth = SecurityContextHolder.getContext().authentication
                auth.shouldNotBeNull()
                auth.principal shouldBe userId
                auth.authorities.first().authority shouldBe "ROLE_USER"
            }

            Then("continues the filter chain") {
                verify(exactly = 1) { filterChain.doFilter(request, response) }
            }
        }
    }

    Given("a request with a valid token for an ADMIN user") {
        val userId = UUID.randomUUID()
        val token = "admin-jwt-token"
        val claims = mockClaims(userId)
        val adminUser = User(
            id = userId,
            email = "admin@example.com",
            nickname = "Admin",
            provider = AuthProvider.GOOGLE,
            providerId = "google-admin",
            role = UserRole.ADMIN
        )

        every { jwtTokenProvider.parseAndValidateToken(token) } returns claims
        every { jwtTokenProvider.getUserIdFromClaims(claims) } returns userId
        every { userCacheService.findById(userId) } returns adminUser

        When("the filter processes the request") {
            val request = MockHttpServletRequest().apply {
                addHeader("Authorization", "Bearer $token")
            }
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("sets ROLE_ADMIN authority") {
                val auth = SecurityContextHolder.getContext().authentication
                auth.shouldNotBeNull()
                auth.authorities.first().authority shouldBe "ROLE_ADMIN"
            }
        }
    }

    Given("a request without an Authorization header") {
        When("the filter processes the request") {
            val request = MockHttpServletRequest()
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("does not set authentication in SecurityContext") {
                SecurityContextHolder.getContext().authentication.shouldBeNull()
            }

            Then("continues the filter chain") {
                verify(exactly = 1) { filterChain.doFilter(request, response) }
            }
        }
    }

    Given("a request with a non-Bearer Authorization header") {
        When("the filter processes the request") {
            val request = MockHttpServletRequest().apply {
                addHeader("Authorization", "Basic dXNlcjpwYXNz")
            }
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("does not set authentication") {
                SecurityContextHolder.getContext().authentication.shouldBeNull()
            }

            Then("continues the filter chain") {
                verify(exactly = 1) { filterChain.doFilter(request, response) }
            }
        }
    }

    Given("a request with an invalid JWT token") {
        val token = "invalid-token"

        every { jwtTokenProvider.parseAndValidateToken(token) } returns null

        When("the filter processes the request") {
            val request = MockHttpServletRequest().apply {
                addHeader("Authorization", "Bearer $token")
            }
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("does not set authentication") {
                SecurityContextHolder.getContext().authentication.shouldBeNull()
            }

            Then("continues the filter chain") {
                verify(exactly = 1) { filterChain.doFilter(request, response) }
            }
        }
    }

    Given("a valid token but user not found in DB") {
        val userId = UUID.randomUUID()
        val token = "valid-but-no-user"
        val claims = mockClaims(userId)

        every { jwtTokenProvider.parseAndValidateToken(token) } returns claims
        every { jwtTokenProvider.getUserIdFromClaims(claims) } returns userId
        every { userCacheService.findById(userId) } returns null

        When("the filter processes the request") {
            val request = MockHttpServletRequest().apply {
                addHeader("Authorization", "Bearer $token")
            }
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("does not set authentication") {
                SecurityContextHolder.getContext().authentication.shouldBeNull()
            }

            Then("continues the filter chain") {
                verify(exactly = 1) { filterChain.doFilter(request, response) }
            }
        }
    }

    Given("a valid token but getUserIdFromClaims throws an exception") {
        val token = "causes-exception"
        val claims = mockk<Claims>()

        every { jwtTokenProvider.parseAndValidateToken(token) } returns claims
        every { jwtTokenProvider.getUserIdFromClaims(claims) } throws RuntimeException("parse error")

        When("the filter processes the request") {
            val request = MockHttpServletRequest().apply {
                addHeader("Authorization", "Bearer $token")
            }
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("does not set authentication") {
                SecurityContextHolder.getContext().authentication.shouldBeNull()
            }

            Then("still continues the filter chain") {
                verify(exactly = 1) { filterChain.doFilter(request, response) }
            }
        }
    }

    Given("public endpoints that should skip JWT filtering") {
        val publicPaths = listOf(
            "/actuator/health",
            "/oauth2/authorization/google",
            "/login/oauth2/code/google",
            "/api/v1/health"
        )

        publicPaths.forEach { path ->
            When("the request is for $path with a Bearer token") {
                val request = MockHttpServletRequest().apply {
                    servletPath = path
                    addHeader("Authorization", "Bearer some-token")
                }
                val response = MockHttpServletResponse()

                filter.doFilter(request, response, filterChain)

                Then("skips JWT validation and continues the filter chain") {
                    verify(exactly = 0) { jwtTokenProvider.parseAndValidateToken(any()) }
                    verify(exactly = 1) { filterChain.doFilter(request, response) }
                    SecurityContextHolder.getContext().authentication.shouldBeNull()
                }
            }
        }

        When("the request is for a regular API endpoint /api/v1/transactions") {
            val token = "test-token"
            every { jwtTokenProvider.parseAndValidateToken(token) } returns null

            val request = MockHttpServletRequest().apply {
                servletPath = "/api/v1/transactions"
                addHeader("Authorization", "Bearer $token")
            }
            val response = MockHttpServletResponse()

            filter.doFilter(request, response, filterChain)

            Then("does apply JWT filtering") {
                verify(exactly = 1) { jwtTokenProvider.parseAndValidateToken(token) }
            }
        }
    }
})
