package com.budgetbook.pocket.repository

import com.budgetbook.pocket.domain.PocketTransfer
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface PocketTransferRepository : JpaRepository<PocketTransfer, UUID> {

    @Query("""
        SELECT t FROM PocketTransfer t
        WHERE t.couple.id = :coupleId
        ORDER BY t.transferDate DESC, t.createdAt DESC
    """)
    fun findByCoupleId(@Param("coupleId") coupleId: UUID): List<PocketTransfer>

    fun findByFromPocketIdOrToPocketId(fromPocketId: UUID, toPocketId: UUID): List<PocketTransfer>

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0)
        FROM PocketTransfer t
        WHERE t.toPocket.id = :pocketId
    """)
    fun sumAmountByToPocketId(@Param("pocketId") pocketId: UUID): Long

    @Query("""
        SELECT COALESCE(SUM(t.amount), 0)
        FROM PocketTransfer t
        WHERE t.fromPocket.id = :pocketId
    """)
    fun sumAmountByFromPocketId(@Param("pocketId") pocketId: UUID): Long

    @Query("""
        SELECT t.toPocket.id, COALESCE(SUM(t.amount), 0)
        FROM PocketTransfer t
        WHERE t.toPocket.id IN :pocketIds
        GROUP BY t.toPocket.id
    """)
    fun sumAmountByToPocketIdIn(@Param("pocketIds") pocketIds: Set<UUID>): List<Array<Any>>

    @Query("""
        SELECT t.fromPocket.id, COALESCE(SUM(t.amount), 0)
        FROM PocketTransfer t
        WHERE t.fromPocket.id IN :pocketIds
        GROUP BY t.fromPocket.id
    """)
    fun sumAmountByFromPocketIdIn(@Param("pocketIds") pocketIds: Set<UUID>): List<Array<Any>>
}
