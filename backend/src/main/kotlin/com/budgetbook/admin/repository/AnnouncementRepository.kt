package com.budgetbook.admin.repository

import com.budgetbook.admin.domain.Announcement
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import java.util.UUID

interface AnnouncementRepository : JpaRepository<Announcement, UUID> {

    fun findByIsActiveTrueOrderByCreatedAtDesc(): List<Announcement>

    fun findAllByOrderByCreatedAtDesc(pageable: Pageable): Page<Announcement>
}
