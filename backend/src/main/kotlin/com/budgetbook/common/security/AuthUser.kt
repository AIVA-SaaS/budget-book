package com.budgetbook.common.security

/**
 * Annotation to inject the authenticated user's UUID into controller methods.
 * Replaces the pattern: `val userId = authentication.principal as UUID`
 *
 * Usage:
 * ```kotlin
 * @GetMapping
 * fun getItems(@AuthUser userId: UUID): ApiResponse<List<Item>> { ... }
 * ```
 */
@Target(AnnotationTarget.VALUE_PARAMETER)
@Retention(AnnotationRetention.RUNTIME)
annotation class AuthUser
