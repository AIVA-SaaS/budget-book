package com.budgetbook.auth.service

import com.budgetbook.auth.config.JwtProperties
import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.shouldNotBe
import io.kotest.matchers.string.shouldNotBeBlank
import java.util.UUID

class JwtTokenProviderTest : FunSpec({

    val jwtProperties = JwtProperties(
        secret = "test-secret-key-that-is-at-least-256-bits-long-for-hs256-algorithm",
        accessTokenExpiry = 3600000,
        refreshTokenExpiry = 604800000
    )
    val jwtTokenProvider = JwtTokenProvider(jwtProperties)

    test("generateAccessToken returns a non-blank string") {
        val userId = UUID.randomUUID()
        val email = "test@example.com"

        val token = jwtTokenProvider.generateAccessToken(userId, email)

        token.shouldNotBeBlank()
    }

    test("validateToken returns true for a valid token") {
        val userId = UUID.randomUUID()
        val email = "test@example.com"

        val token = jwtTokenProvider.generateAccessToken(userId, email)
        val isValid = jwtTokenProvider.validateToken(token)

        isValid shouldBe true
    }

    test("validateToken returns false for an expired token") {
        val shortExpiryProperties = JwtProperties(
            secret = "test-secret-key-that-is-at-least-256-bits-long-for-hs256-algorithm",
            accessTokenExpiry = 1, // 1ms - will be expired almost immediately
            refreshTokenExpiry = 1
        )
        val shortExpiryProvider = JwtTokenProvider(shortExpiryProperties)

        val userId = UUID.randomUUID()
        val email = "test@example.com"

        val token = shortExpiryProvider.generateAccessToken(userId, email)

        // Wait a bit to ensure the token is expired
        Thread.sleep(50)

        val isValid = shortExpiryProvider.validateToken(token)

        isValid shouldBe false
    }

    test("validateToken returns false for an invalid/tampered token") {
        val isValid = jwtTokenProvider.validateToken("this.is.an.invalid.token")

        isValid shouldBe false
    }

    test("validateToken returns false for a token signed with a different key") {
        val otherProperties = JwtProperties(
            secret = "a-completely-different-secret-key-that-is-also-long-enough-for-hs256",
            accessTokenExpiry = 3600000,
            refreshTokenExpiry = 604800000
        )
        val otherProvider = JwtTokenProvider(otherProperties)

        val token = otherProvider.generateAccessToken(UUID.randomUUID(), "test@example.com")
        val isValid = jwtTokenProvider.validateToken(token)

        isValid shouldBe false
    }

    test("getUserIdFromToken extracts the correct UUID") {
        val userId = UUID.randomUUID()
        val email = "test@example.com"

        val token = jwtTokenProvider.generateAccessToken(userId, email)
        val extractedId = jwtTokenProvider.getUserIdFromToken(token)

        extractedId shouldBe userId
    }

    test("generateRefreshToken returns a non-blank string") {
        val refreshToken = jwtTokenProvider.generateRefreshToken()

        refreshToken.shouldNotBeBlank()
    }

    test("generateRefreshToken returns unique values on each call") {
        val token1 = jwtTokenProvider.generateRefreshToken()
        val token2 = jwtTokenProvider.generateRefreshToken()

        token1 shouldNotBe token2
    }

    test("getAccessTokenExpiry returns configured value") {
        jwtTokenProvider.getAccessTokenExpiry() shouldBe 3600000L
    }

    test("getRefreshTokenExpiry returns configured value") {
        jwtTokenProvider.getRefreshTokenExpiry() shouldBe 604800000L
    }
})
