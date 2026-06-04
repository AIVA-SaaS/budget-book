package com.budgetbook.auth.domain

/**
 * Central authority for placeholder email policy.
 * All email generation, detection, and validation must use these helpers.
 * Never define the placeholder domain elsewhere.
 */
object EmailPolicy {

    const val PLACEHOLDER_EMAIL_DOMAIN = "no-email.local"

    /**
     * Generates a deterministic placeholder email from provider and providerId.
     * Format: {provider_lowercase}_{providerId}@no-email.local
     */
    fun buildPlaceholderEmail(provider: AuthProvider, providerId: String): String =
        "${provider.name.lowercase()}_${providerId}@$PLACEHOLDER_EMAIL_DOMAIN"

    /**
     * Returns true if the email is a real, user-provided email address.
     * An email is NOT real if it is blank or ends with the placeholder domain.
     */
    fun isRealEmail(email: String): Boolean =
        email.isNotBlank() && !email.endsWith("@$PLACEHOLDER_EMAIL_DOMAIN")

    /**
     * Returns true if the email is a placeholder.
     */
    fun isPlaceholderEmail(email: String): Boolean = !isRealEmail(email)
}
