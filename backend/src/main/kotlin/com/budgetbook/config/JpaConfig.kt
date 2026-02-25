package com.budgetbook.config

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty
import org.springframework.context.annotation.Configuration
import org.springframework.data.jpa.repository.config.EnableJpaAuditing

@Configuration
@EnableJpaAuditing
@ConditionalOnProperty(name = ["spring.datasource.url"], matchIfMissing = false)
class JpaConfig
