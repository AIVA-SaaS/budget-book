plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.spring)
    alias(libs.plugins.kotlin.jpa)
    alias(libs.plugins.spring.boot)
    alias(libs.plugins.spring.dependency.management)
    // 배치 3 G-4 (2026-04-26) — 코드 커버리지. `./gradlew koverHtmlReport` / `koverXmlReport`.
    alias(libs.plugins.kover)
}

// Kover 설정 — XML/HTML 리포트만 활성, 임계치는 별도 enforcement 없음 (단계적 도입).
kover {
    reports {
        verify {
            // 향후 임계치 필요 시 활성화. 현재는 측정만.
            // rule { bound { minValue = 60 } }
        }
        filters {
            excludes {
                classes(
                    "com.budgetbook.BudgetBookApplicationKt",
                    "com.budgetbook.config.*",
                    "com.budgetbook.*.dto.*",
                    "com.budgetbook.*.domain.*"
                )
            }
        }
    }
}

group = "com.budgetbook"
version = "0.0.1-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    // Spring Boot
    implementation(libs.spring.boot.starter.web)
    implementation(libs.spring.boot.starter.data.jpa)
    implementation(libs.spring.boot.starter.security)
    implementation(libs.spring.boot.starter.oauth2.client)
    implementation(libs.spring.boot.starter.websocket)
    implementation(libs.spring.boot.starter.data.redis)
    implementation(libs.spring.boot.starter.validation)
    implementation(libs.spring.boot.starter.actuator)

    // Database
    runtimeOnly(libs.postgresql)
    implementation(libs.flyway.core)
    implementation(libs.flyway.postgresql)

    // JWT
    implementation(libs.jjwt.api)
    runtimeOnly(libs.jjwt.impl)
    runtimeOnly(libs.jjwt.jackson)

    // Cache
    implementation(libs.caffeine)

    // Kotlin
    implementation(libs.jackson.module.kotlin)
    implementation(libs.kotlin.reflect)

    // Metrics (Prometheus)
    implementation(libs.micrometer.registry.prometheus)

    // Task #18: Sentry error monitoring (no-op when SENTRY_DSN env var is absent)
    implementation(libs.sentry.spring.boot.starter)

    // Test
    testImplementation(libs.spring.boot.starter.test)
    testRuntimeOnly("com.h2database:h2")
    testImplementation(libs.kotest.runner.junit5)
    testImplementation(libs.kotest.assertions.core)
    testImplementation(libs.kotest.property)
    testImplementation(libs.kotest.extensions.spring)
    testImplementation(libs.mockk)
    testImplementation(libs.spring.security.test)
    testImplementation(libs.testcontainers.postgresql)
    testImplementation(libs.testcontainers.junit.jupiter)
}

kotlin {
    compilerOptions {
        freeCompilerArgs.addAll("-Xjsr305=strict")
    }
}

tasks.withType<Test> {
    useJUnitPlatform()
    // Pass Docker socket to the forked test JVM so Testcontainers can find Docker Desktop on macOS.
    // Docker Desktop 4.x proxy rejects /v1.32/info (docker-java default) with empty 400.
    // Testcontainers uses its own shaded docker-java which reads API version from "api.version"
    // environment variable (not DOCKER_API_VERSION). Setting this to "1.44" bypasses the v1.32 issue.
    val varRunSock = "/var/run/docker.sock"
    val dockerHost = System.getenv("DOCKER_HOST") ?: "unix://$varRunSock"
    environment("DOCKER_HOST", dockerHost)
    environment("api.version", "1.44")          // Testcontainers shaded docker-java reads this key
    environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE", varRunSock)
    systemProperty("DOCKER_HOST", dockerHost)
    systemProperty("api.version", "1.44")
}
