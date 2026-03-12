package com.budgetbook.auth.security

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.domain.UserRole
import com.budgetbook.auth.service.JwtTokenProvider
import com.budgetbook.auth.service.UserCacheService
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

    Given("a request with a valid Bearer token") {
        val userId = UUID.randomUUID()
        val token = "valid-jwt-token"
        val user = User(
            id = userId,
            email = "test@example.com",
            nickname = "Test",
            provider = AuthProvider.GOOGLE,
            providerId = "google-123"
        )

        every { jwtTokenProvider.validateToken(token) } returns true
        every { jwtTokenProvider.getUserIdFromToken(token) } returns userId
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
        val adminUser = User(
            id = userId,
            email = "admin@example.com",
            nickname = "Admin",
            provider = AuthProvider.GOOGLE,
            providerId = "google-admin",
            role = UserRole.ADMIN
        )

        every { jwtTokenProvider.validateToken(token) } returns true
        every { jwtTokenProvider.getUserIdFromToken(token) } returns userId
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

        every { jwtTokenProvider.validateToken(token) } returns false

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

        every { jwtTokenProvider.validateToken(token) } returns true
        every { jwtTokenProvider.getUserIdFromToken(token) } returns userId
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

    Given("a valid token but getUserIdFromToken throws an exception") {
        val token = "causes-exception"

        every { jwtTokenProvider.validateToken(token) } returns true
        every { jwtTokenProvider.getUserIdFromToken(token) } throws RuntimeException("parse error")

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
})
