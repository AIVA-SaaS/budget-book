package com.budgetbook.auth.service

import com.budgetbook.auth.domain.AuthProvider
import com.budgetbook.auth.domain.User
import com.budgetbook.auth.repository.UserRepository
import com.budgetbook.auth.security.CustomOAuth2User
import org.slf4j.LoggerFactory
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest
import org.springframework.security.oauth2.core.user.OAuth2User
import org.springframework.stereotype.Service

@Service
class CustomOAuth2UserService(
    private val userRepository: UserRepository
) : DefaultOAuth2UserService() {

    private val log = LoggerFactory.getLogger(javaClass)

    override fun loadUser(userRequest: OAuth2UserRequest): OAuth2User {
        val oAuth2User = super.loadUser(userRequest)
        val registrationId = userRequest.clientRegistration.registrationId
        val provider = AuthProvider.valueOf(registrationId.uppercase())

        val userInfo = extractUserInfo(provider, oAuth2User.attributes)
        log.debug("OAuth2 login - provider: {}, email: {}, name: {}", provider, userInfo.email, userInfo.name)

        val user = findOrCreateUser(provider, userInfo)

        return CustomOAuth2User(oAuth2User, user)
    }

    private fun extractUserInfo(provider: AuthProvider, attributes: Map<String, Any>): OAuth2UserInfo {
        return when (provider) {
            AuthProvider.GOOGLE -> extractGoogleUserInfo(attributes)
            AuthProvider.KAKAO -> extractKakaoUserInfo(attributes)
        }
    }

    private fun extractGoogleUserInfo(attributes: Map<String, Any>): OAuth2UserInfo {
        return OAuth2UserInfo(
            providerId = attributes["sub"] as String,
            email = attributes["email"] as String,
            name = attributes["name"] as? String ?: "Unknown",
            profileImageUrl = attributes["picture"] as? String
        )
    }

    @Suppress("UNCHECKED_CAST")
    private fun extractKakaoUserInfo(attributes: Map<String, Any>): OAuth2UserInfo {
        val kakaoAccount = attributes["kakao_account"] as? Map<String, Any> ?: emptyMap()
        val profile = kakaoAccount["profile"] as? Map<String, Any> ?: emptyMap()

        return OAuth2UserInfo(
            providerId = attributes["id"].toString(),
            email = kakaoAccount["email"] as? String ?: "",
            name = profile["nickname"] as? String ?: "Unknown",
            profileImageUrl = profile["thumbnail_image_url"] as? String
        )
    }

    private fun findOrCreateUser(provider: AuthProvider, userInfo: OAuth2UserInfo): User {
        val existingUser = userRepository.findByProviderAndProviderId(provider, userInfo.providerId)

        return if (existingUser != null) {
            existingUser.nickname = userInfo.name
            existingUser.profileImageUrl = userInfo.profileImageUrl
            userRepository.save(existingUser)
        } else {
            val newUser = User(
                email = userInfo.email,
                nickname = userInfo.name,
                profileImageUrl = userInfo.profileImageUrl,
                provider = provider,
                providerId = userInfo.providerId
            )
            userRepository.save(newUser)
        }
    }

    private data class OAuth2UserInfo(
        val providerId: String,
        val email: String,
        val name: String,
        val profileImageUrl: String?
    )
}
