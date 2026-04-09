package com.budgetbook.couple.repository

import jakarta.persistence.EntityManager
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Repository
import java.util.UUID

/**
 * Repository for bulk couple_id migration during couple join/dissolve.
 * Uses native queries for efficiency (avoids loading all entities into memory).
 */
@Repository
class CoupleDataMigrationRepository(
    private val entityManager: EntityManager
) {
    private val log = LoggerFactory.getLogger(javaClass)

    companion object {
        // Tables with couple_id that need migration during join/dissolve.
        // couple_preferences is handled separately (UNIQUE constraint on couple_id).
        val MIGRATABLE_TABLES = listOf(
            "categories",
            "transactions",
            "monthly_budgets",
            "category_groups",
            "payment_methods",
            "weekly_budget_snapshots",
            "recurring_transactions",
            "money_pockets",
            "pocket_transfers",
            "distribution_ratios",
            "transfers",
            "insurances",
            "spending_plans",
            "weekly_budget_settlements"
        )
    }

    /**
     * Migrates all data from sourceCoupleId to targetCoupleId across all tables.
     * Used when a user joins a couple (their self-couple data moves to the real couple).
     *
     * @return total number of rows updated
     */
    fun migrateAllData(sourceCoupleId: UUID, targetCoupleId: UUID): Int {
        var totalUpdated = 0
        for (table in MIGRATABLE_TABLES) {
            val updated = entityManager.createNativeQuery(
                "UPDATE $table SET couple_id = :targetId WHERE couple_id = :sourceId"
            )
                .setParameter("targetId", targetCoupleId)
                .setParameter("sourceId", sourceCoupleId)
                .executeUpdate()
            if (updated > 0) {
                log.debug("Migrated {} rows in table {} from couple {} to {}", updated, table, sourceCoupleId, targetCoupleId)
            }
            totalUpdated += updated
        }
        log.info("Total data migration: {} rows from couple {} to {}", totalUpdated, sourceCoupleId, targetCoupleId)
        return totalUpdated
    }

    /**
     * Splits data for a specific user from sourceCoupleId to targetCoupleId.
     * Used during couple dissolution. Only moves data owned by the given user.
     * Tables without owner_id will have their data stay with the source couple (user1 keeps shared data).
     *
     * @return total number of rows updated
     */
    fun splitDataByOwner(sourceCoupleId: UUID, targetCoupleId: UUID, ownerId: UUID): Int {
        var totalUpdated = 0

        // Tables that have owner_id column for per-user data separation
        val tablesWithOwner = listOf(
            "categories",
            "category_groups",
            "transactions",
            "monthly_budgets",
            "money_pockets",
            "insurances",
            "spending_plans"
        )

        for (table in tablesWithOwner) {
            val updated = entityManager.createNativeQuery(
                "UPDATE $table SET couple_id = :targetId WHERE couple_id = :sourceId AND owner_id = :ownerId"
            )
                .setParameter("targetId", targetCoupleId)
                .setParameter("sourceId", sourceCoupleId)
                .setParameter("ownerId", ownerId)
                .executeUpdate()
            if (updated > 0) {
                log.debug("Split {} rows in table {} for owner {} from couple {} to {}", updated, table, ownerId, sourceCoupleId, targetCoupleId)
            }
            totalUpdated += updated
        }

        // recurring_transactions uses author_id instead of owner_id
        val recurringUpdated = entityManager.createNativeQuery(
            "UPDATE recurring_transactions SET couple_id = :targetId WHERE couple_id = :sourceId AND author_id = :ownerId"
        )
            .setParameter("targetId", targetCoupleId)
            .setParameter("sourceId", sourceCoupleId)
            .setParameter("ownerId", ownerId)
            .executeUpdate()
        if (recurringUpdated > 0) {
            log.debug("Split {} rows in recurring_transactions for author {} from couple {} to {}", recurringUpdated, ownerId, sourceCoupleId, targetCoupleId)
        }
        totalUpdated += recurringUpdated

        log.info("Total data split: {} rows for owner {} from couple {} to {}", totalUpdated, ownerId, sourceCoupleId, targetCoupleId)
        return totalUpdated
    }

    /**
     * Deletes couple_preferences for a given couple.
     * Called before creating new preferences for the self-couples after dissolution.
     */
    fun deleteCouplePreferences(coupleId: UUID): Int {
        return entityManager.createNativeQuery(
            "DELETE FROM couple_preferences WHERE couple_id = :coupleId"
        )
            .setParameter("coupleId", coupleId)
            .executeUpdate()
    }
}
