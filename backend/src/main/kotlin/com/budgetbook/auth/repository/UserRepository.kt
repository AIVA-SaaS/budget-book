package com.budgetbook.auth.repository

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface UserRepository : JpaRepository<User, UUID> {

    fun findByProviderAndProviderId(provider: AuthProvider, providerId: String): User?

    fun findByEmail(email: String): User?
}
