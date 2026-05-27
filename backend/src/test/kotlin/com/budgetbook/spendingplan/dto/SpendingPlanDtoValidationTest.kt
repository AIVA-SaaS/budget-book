package com.budgetbook.spendingplan.dto

import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.booleans.shouldBeTrue
import jakarta.validation.Validation
import jakarta.validation.Validator

/**
 * Guards the create/update amount-validation consistency.
 *
 * A spending plan does not require an amount (WISHLIST plans are stored with amount = 0).
 * The "amount >= 1" rule only applies to PLANNED status and is enforced in the service layer,
 * not via the DTO annotation. Both DTOs must therefore allow amount = 0 (and reject negatives).
 *
 * Regression: UpdateSpendingPlanRequest previously used @Min(1), which rejected editing
 * amount-less plans whose stored amount was 0.
 */
class SpendingPlanDtoValidationTest : FunSpec({

    val validator: Validator = Validation.buildDefaultValidatorFactory().validator

    fun amountViolations(amount: Long?, create: Boolean): Int {
        val violations = if (create) {
            validator.validate(CreateSpendingPlanRequest(name = "Plan", amount = amount))
        } else {
            validator.validate(UpdateSpendingPlanRequest(name = "Plan", amount = amount))
        }
        return violations.count { it.propertyPath.toString() == "amount" }
    }

    context("create request amount") {
        test("allows null (no amount)") { (amountViolations(null, create = true) == 0).shouldBeTrue() }
        test("allows zero (no amount)") { (amountViolations(0, create = true) == 0).shouldBeTrue() }
        test("allows positive") { (amountViolations(100000, create = true) == 0).shouldBeTrue() }
        test("rejects negative") { (amountViolations(-1, create = true) > 0).shouldBeTrue() }
    }

    context("update request amount — must match create semantics") {
        test("allows null (no change)") { (amountViolations(null, create = false) == 0).shouldBeTrue() }
        test("allows zero (no amount)") { (amountViolations(0, create = false) == 0).shouldBeTrue() }
        test("allows positive") { (amountViolations(100000, create = false) == 0).shouldBeTrue() }
        test("rejects negative") { (amountViolations(-1, create = false) > 0).shouldBeTrue() }
    }

    test("create and update agree on every amount boundary") {
        for (amount in listOf(null, 0L, 1L, 100000L, -1L, -5L)) {
            val createOk = amountViolations(amount, create = true) == 0
            val updateOk = amountViolations(amount, create = false) == 0
            (createOk == updateOk).shouldBeTrue()
        }
    }
})
