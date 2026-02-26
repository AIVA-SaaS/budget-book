package com.budgetbook.auth.service

import com.budgetbook.auth.config.JwtProperties
import io.jsonwebtoken.ExpiredJwtException
import io.jsonwebtoken.Jwts
import io.jsonwebtoken.MalformedJwtException
import io.jsonwebtoken.UnsupportedJwtException
import io.jsonwebtoken.security.Keys
import io.jsonwebtoken.security.SecurityException
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import java.util.Date
import java.util.UUID
import javax.crypto.SecretKey

@Component
class JwtTokenProvider(
    private val jwtProperties: JwtProperties
) {
    private val log = LoggerFactory.getLogger(javaClass)

    private val key: SecretKey by lazy {
        Keys.hmacShaKeyFor(jwtProperties.secret.toByteArray())
    }

    fun generateAccessToken(userId: UUID, email: String): String {
        val now = Date()
        val expiry = Date(now.time + jwtProperties.accessTokenExpiry)

        return Jwts.builder()
            .subject(userId.toString())
            .claim("email", email)
            .issuedAt(now)
            .expiration(expiry)
            .signWith(key)
            .compact()
    }

    fun generateRefreshToken(): String = UUID.randomUUID().toString()

    fun validateToken(token: String): Boolean {
        return try {
            Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
            true
        } catch (e: SecurityException) {
            log.warn("Invalid JWT signature: {}", e.message)
            false
        } catch (e: MalformedJwtException) {
            log.warn("Malformed JWT token: {}", e.message)
            false
        } catch (e: ExpiredJwtException) {
            log.warn("Expired JWT token: {}", e.message)
            false
        } catch (e: UnsupportedJwtException) {
            log.warn("Unsupported JWT token: {}", e.message)
            false
        } catch (e: IllegalArgumentException) {
            log.warn("JWT claims string is empty: {}", e.message)
            false
        }
    }

    fun getUserIdFromToken(token: String): UUID {
        val claims = Jwts.parser()
            .verifyWith(key)
            .build()
            .parseSignedClaims(token)
            .payload

        return UUID.fromString(claims.subject)
    }

    fun getAccessTokenExpiry(): Long = jwtProperties.accessTokenExpiry

    fun getRefreshTokenExpiry(): Long = jwtProperties.refreshTokenExpiry
}
