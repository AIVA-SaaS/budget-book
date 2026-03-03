package com.budgetbook.auth.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.security.CustomOAuth2User
import org.slf4j.LoggerFactory
import org.springframework.security.oauth2.client.oidc.userinfo.OidcUserRequest
import org.springframework.security.oauth2.client.oidc.userinfo.OidcUserService
import org.springframework.security.oauth2.core.oidc.user.OidcUser
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class CustomOidcUserService(
    private val customOAuth2UserService: CustomOAuth2UserService
) : OidcUserService() {

    private val log = LoggerFactory.getLogger(javaClass)

    @Transactional
    override fun loadUser(userRequest: OidcUserRequest): OidcUser {
        val oidcUser = super.loadUser(userRequest)
        val registrationId = userRequest.clientRegistration.registrationId
        val provider = AuthProvider.valueOf(registrationId.uppercase())

        val userInfo = CustomOAuth2UserService.OAuth2UserInfo(
            providerId = oidcUser.subject,
            email = oidcUser.email ?: "",
            name = oidcUser.fullName ?: oidcUser.preferredUsername ?: "Unknown",
            profileImageUrl = oidcUser.picture
        )
        log.debug("OIDC login - provider: {}, email: {}, name: {}", provider, userInfo.email, userInfo.name)

        val user = customOAuth2UserService.findOrCreateUser(provider, userInfo)

        return CustomOidcUser(oidcUser, user)
    }
}
