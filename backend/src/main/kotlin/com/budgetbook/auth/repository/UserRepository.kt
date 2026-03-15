package com.budgetbook.auth.repository

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.Instant
import java.util.UUID

interface UserRepository : JpaRepository<User, UUID> {

    fun findByProviderAndProviderId(provider: AuthProvider, providerId: String): User?

    fun findByEmail(email: String): User?

    @Query("""
        SELECT u FROM User u
        WHERE (:search IS NULL OR LOWER(u.email) LIKE LOWER(CONCAT('%', :search, '%'))
            OR LOWER(u.nickname) LIKE LOWER(CONCAT('%', :search, '%')))
        ORDER BY u.createdAt DESC
    """)
    fun findAllWithSearch(@Param("search") search: String?, pageable: Pageable): Page<User>

    @Query("SELECT COUNT(u) FROM User u WHERE u.createdAt >= :since")
    fun countCreatedSince(@Param("since") since: Instant): Long

}
