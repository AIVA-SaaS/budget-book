package com.budgetbook.category.repository

import com.budgetbook.category.domain.Category
import com.budgetbook.category.domain.CategoryType
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.UUID

interface CategoryRepository : JpaRepository<Category, UUID> {

    @Query("""
        SELECT c FROM Category c
        LEFT JOIN FETCH c.group
        WHERE c.couple.id = :coupleId
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<Category>

    @Query("""
        SELECT c FROM Category c
        LEFT JOIN FETCH c.group
        WHERE c.couple.id = :coupleId
        AND c.type = :type
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndTypeAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("type") type: CategoryType,
        @Param("userId") userId: UUID
    ): List<Category>

    @Query("""
        SELECT c FROM Category c
        WHERE c.couple.id = :coupleId
        AND c.group.id = :groupId
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndGroupIdAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("groupId") groupId: UUID,
        @Param("userId") userId: UUID
    ): List<Category>

    @Query("""
        SELECT c FROM Category c
        WHERE c.couple.id = :coupleId
        AND c.group IS NULL
        AND (c.visibility = com.budgetbook.common.entity.Visibility.SHARED OR c.owner.id = :userId)
    """)
    fun findByCoupleIdAndGroupIsNullAndUserId(
        @Param("coupleId") coupleId: UUID,
        @Param("userId") userId: UUID
    ): List<Category>

    // Keep original methods for internal use (seeding, migrations, etc.)
    @Query("""
        SELECT c FROM Category c
        LEFT JOIN FETCH c.group
        WHERE c.couple.id = :coupleId
    """)
    fun findByCoupleId(@Param("coupleId") coupleId: UUID): List<Category>

    fun findByCoupleIdAndType(coupleId: UUID, type: CategoryType): List<Category>

    fun findByCoupleIdAndGroupId(coupleId: UUID, groupId: UUID): List<Category>

    fun findByCoupleIdAndGroupIsNull(coupleId: UUID): List<Category>

    fun findByCoupleIdAndNameIn(coupleId: UUID, names: List<String>): List<Category>

    /**
     * 다중 그룹 ID 로 속한 카테고리 일괄 조회 (PR-C2 다중/그룹 필터).
     * 필터에서 "식비 그룹 전체" 같은 그룹 선택 시 하위 카테고리를 펼치기 위해 사용.
     * 빈 리스트로 호출 시 빈 결과 반환 (호출부에서 체크하여 쿼리 호출 자체를 스킵하는 것을 권장).
     */
    fun findByGroupIdIn(groupIds: List<UUID>): List<Category>
}
