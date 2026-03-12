FROM gradle:8.7-jdk21 AS build
WORKDIR /app
COPY build.gradle.kts settings.gradle.kts ./
COPY gradle ./gradle
RUN gradle dependencies --no-daemon || true
COPY src ./src
RUN gradle bootJar --no-daemon

# Extract Spring Boot jar for exploded layout (faster class loading)
FROM eclipse-temurin:21-jre-alpine AS extract
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar
RUN java -Djarmode=tools -jar app.jar extract --destination extracted

# CDS training - captures JDK/Spring class metadata for faster JVM startup
# DB/Redis connection failure is expected; archive is still created on JVM exit
FROM eclipse-temurin:21-jre-alpine AS cds
WORKDIR /app
COPY --from=extract /app/extracted/ ./
RUN java -XX:ArchiveClassesAtExit=app-cds.jsa \
  -Dspring.context.exit=onRefresh \
  -jar app.jar 2>/dev/null ; true

FROM eclipse-temurin:21-jre-alpine
RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=cds /app/lib/ ./lib/
COPY --from=cds /app/app.jar ./
COPY --from=cds /app/app-cds.jsa ./
USER app
EXPOSE 8080
ENTRYPOINT ["java", \
  "-Xms128m", "-Xmx384m", \
  "-XX:+UseSerialGC", \
  "-XX:+TieredCompilation", "-XX:TieredStopAtLevel=1", \
  "-XX:SharedArchiveFile=app-cds.jsa", \
  "-Dspring.jmx.enabled=false", \
  "-jar", "app.jar"]
