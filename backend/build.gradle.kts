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
    //
    // 2026-07-27 — 소켓 경로를 /var/run/docker.sock 로 고정하면, 활성 런타임이 colima/
    // Rancher 인 머신에서 그 심볼릭 링크가 끊겨 있어(Docker Desktop 미실행) 전체 test
    // task 가 Kotest initializationError("Could not find a valid Docker environment") 로
    // 죽는다. `docker info` 는 정상인데 로컬 CI 게이트를 통과할 수 없는 상태가 된다.
    // → 실제로 **존재하는** 소켓을 후보 목록에서 골라 주입한다. (끊긴 심볼릭 링크는
    //   File.exists() == false 로 자동 탈락.)
    val varRunSock = "/var/run/docker.sock"
    val home = System.getProperty("user.home")
    val socketCandidates = listOfNotNull(
        System.getenv("DOCKER_HOST")
            ?.takeIf { it.startsWith("unix://") }
            ?.removePrefix("unix://"),
        varRunSock,
        "$home/.colima/default/docker.sock",
        "$home/.docker/run/docker.sock",
        "$home/.rd/docker.sock",
    )
    // `java.io.File` 은 Kotlin DSL 에서 `java` 확장과 충돌 → 기본 import 된 File 사용.
    val resolvedSocket = socketCandidates.firstOrNull { File(it).exists() }
    val dockerHost = System.getenv("DOCKER_HOST")
        ?: resolvedSocket?.let { "unix://$it" }
        ?: "unix://$varRunSock"
    environment("DOCKER_HOST", dockerHost)
    environment("api.version", "1.44")          // Testcontainers shaded docker-java reads this key
    environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE", varRunSock)
    systemProperty("DOCKER_HOST", dockerHost)
    systemProperty("api.version", "1.44")
}
