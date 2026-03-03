package com.budgetbook.auth.service

import com.budgetbook.auth.domain.User
import org.springframework.security.core.GrantedAuthority
import org.springframework.security.oauth2.core.oidc.OidcIdToken
import org.springframework.security.oauth2.core.oidc.OidcUserInfo
import org.springframework.security.oauth2.core.oidc.user.OidcUser

class CustomOidcUser(
    private val oidcUser: OidcUser,
    private val user: User
) : OidcUser {

    override fun getAttributes(): Map<String, Any> = oidcUser.attributes

    override fun getAuthorities(): Collection<GrantedAuthority> = oidcUser.authorities

    override fun getName(): String = oidcUser.name

    override fun getClaims(): Map<String, Any> = oidcUser.claims

    override fun getUserInfo(): OidcUserInfo? = oidcUser.userInfo

    override fun getIdToken(): OidcIdToken = oidcUser.idToken

    fun getUser(): User = user
}
