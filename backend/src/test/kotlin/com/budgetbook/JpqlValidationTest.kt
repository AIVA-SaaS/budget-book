package com.budgetbook

import io.kotest.core.spec.style.FunSpec
import io.kotest.matchers.shouldNotBe
import org.springframework.boot.test.autoconfigure.orm.jpa.DataJpaTest
import org.springframework.test.context.ActiveProfiles
import jakarta.persistence.EntityManager
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.test.context.TestPropertySource

/**
 * Validates all JPQL queries by starting the JPA context with H2.
 * Hibernate validates JPQL at EntityManagerFactory creation time.
 * If any query is invalid, this test will fail with a startup error.
 */
@DataJpaTest
@ActiveProfiles("test")
@TestPropertySource(properties = [
    "spring.datasource.url=jdbc:h2:mem:jpql-validation;DB_CLOSE_DELAY=-1;MODE=PostgreSQL",
    "spring.jpa.hibernate.ddl-auto=create-drop",
    "spring.flyway.enabled=false",
    "spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.H2Dialect"
])
class JpqlValidationTest(
    @Autowired private val entityManager: EntityManager
) : FunSpec({

    test("JPA context starts successfully — all JPQL queries are valid") {
        entityManager shouldNotBe null
    }
})
