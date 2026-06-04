package com.budgetbook.auth.domain

import io.kotest.core.spec.style.BehaviorSpec
import io.kotest.matchers.shouldBe
import io.kotest.matchers.string.shouldContain
import io.kotest.matchers.string.shouldEndWith

class EmailPolicyTest : BehaviorSpec({

    Given("EmailPolicy.buildPlaceholderEmail") {
        When("called with KAKAO and a providerId") {
            val result = EmailPolicy.buildPlaceholderEmail(AuthProvider.KAKAO, "12345678")

            Then("generates lowercase provider_providerId@no-email.local") {
                result shouldBe "kakao_12345678@no-email.local"
                result shouldEndWith "@${EmailPolicy.PLACEHOLDER_EMAIL_DOMAIN}"
            }
        }

        When("called with GOOGLE and a providerId") {
            val result = EmailPolicy.buildPlaceholderEmail(AuthProvider.GOOGLE, "google-sub-999")

            Then("generates google_ prefixed placeholder") {
                result shouldBe "google_google-sub-999@no-email.local"
            }
        }

        When("called with SYSTEM and a providerId") {
            val result = EmailPolicy.buildPlaceholderEmail(AuthProvider.SYSTEM, "system-001")

            Then("generates system_ prefixed placeholder") {
                result shouldBe "system_system-001@no-email.local"
            }
        }
    }

    Given("EmailPolicy.isRealEmail") {
        When("given a real email address") {
            Then("returns true") {
                EmailPolicy.isRealEmail("user@example.com") shouldBe true
                EmailPolicy.isRealEmail("user@gmail.com") shouldBe true
                EmailPolicy.isRealEmail("user@kakao.com") shouldBe true
            }
        }

        When("given a placeholder email") {
            Then("returns false") {
                EmailPolicy.isRealEmail("kakao_12345678@no-email.local") shouldBe false
                EmailPolicy.isRealEmail("google_abc@no-email.local") shouldBe false
            }
        }

        When("given a blank string") {
            Then("returns false") {
                EmailPolicy.isRealEmail("") shouldBe false
                EmailPolicy.isRealEmail("   ") shouldBe false
            }
        }
    }

    Given("EmailPolicy.isPlaceholderEmail") {
        When("given a placeholder email") {
            Then("returns true") {
                EmailPolicy.isPlaceholderEmail("kakao_12345678@no-email.local") shouldBe true
            }
        }

        When("given a real email") {
            Then("returns false") {
                EmailPolicy.isPlaceholderEmail("user@example.com") shouldBe false
            }
        }

        When("given a blank string") {
            Then("returns true (not a real email)") {
                EmailPolicy.isPlaceholderEmail("") shouldBe true
            }
        }
    }

    Given("User.hasRealEmail extension function") {
        When("user has a real email") {
            val user = User(
                email = "real@example.com",
                nickname = "RealUser",
                provider = AuthProvider.GOOGLE,
                providerId = "google-1"
            )
            Then("returns true") {
                user.hasRealEmail() shouldBe true
            }
        }

        When("user has a placeholder email") {
            val user = User(
                email = "kakao_99999@no-email.local",
                nickname = "PlaceholderUser",
                provider = AuthProvider.KAKAO,
                providerId = "99999"
            )
            Then("returns false") {
                user.hasRealEmail() shouldBe false
            }
        }

        When("user has a blank email (legacy)") {
            val user = User(
                email = "",
                nickname = "LegacyUser",
                provider = AuthProvider.KAKAO,
                providerId = "legacy-1"
            )
            Then("returns false") {
                user.hasRealEmail() shouldBe false
            }
        }
    }
})
