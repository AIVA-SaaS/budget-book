# 로컬 docker build 용 (배포는 .github/workflows/deploy-nas.yml 가 GitHub Actions
# runner 에서 빌드한 JAR 만 NAS 로 전송 + 인라인 runtime Dockerfile 사용 — E-2 2026-04-26).
# 본 Dockerfile 은 로컬 검증/대체 경로 호환을 위해 기존 multi-stage 형태 유지.
FROM gradle:8.7-jdk21 AS build
WORKDIR /app
COPY build.gradle.kts settings.gradle.kts ./
COPY gradle ./gradle
RUN gradle dependencies --no-daemon || true
COPY src ./src
RUN gradle bootJar --no-daemon

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
USER app
EXPOSE 8080
ENTRYPOINT ["java", \
  "-Xms128m", "-Xmx384m", \
  "-XX:+UseSerialGC", \
  "-XX:+TieredCompilation", "-XX:TieredStopAtLevel=1", \
  "-Dspring.jmx.enabled=false", \
  "-jar", "app.jar"]
