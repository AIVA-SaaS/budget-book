package com.budgetbook.auth.security

import com.budgetbook.auth.domain.User
import org.springframework.security.core.GrantedAuthority
import org.springframework.security.oauth2.core.user.OAuth2User

class CustomOAuth2User(
    private val oAuth2User: OAuth2User,
    private val user: User
) : OAuth2User {

    override fun getAttributes(): Map<String, Any> = oAuth2User.attributes

    override fun getAuthorities(): Collection<GrantedAuthority> = oAuth2User.authorities

    override fun getName(): String = oAuth2User.name

    fun getUser(): User = user
}
