# Build & Test Commands

| 대상 | 명령 |
|-----|-----|
| Backend 빌드 | `cd backend && ./gradlew build` |
| Backend 테스트 | `cd backend && ./gradlew test` |
| Frontend 의존성 | `cd frontend && flutter pub get` |
| Frontend 분석 | `cd frontend && flutter analyze --no-fatal-infos --no-congratulate` (부분 경로 금지 — CI 와 동일하게 전체) |
| Frontend 테스트 | `cd frontend && flutter test` |
| Frontend 빌드 | `cd frontend && flutter build web` |
| 로컬 인프라 | `cd infra && docker-compose up -d` |

## Backend 테스트와 Docker (Testcontainers)

`./gradlew test` 에는 Testcontainers 통합테스트(`*IntegrationTest`)가 포함되므로 **Docker 데몬이
떠 있어야 한다**. 안 떠 있으면 `Kotest > initializationError` /
`Could not find a valid Docker environment` 로 **테스트 1건도 못 돌고** task 전체가 실패한다.

- 소켓 경로는 `build.gradle.kts` 의 `tasks.withType<Test>` 가 후보 목록에서 **실제 존재하는**
  것을 골라 `DOCKER_HOST` 로 주입한다: `$DOCKER_HOST` → `/var/run/docker.sock` →
  `~/.colima/default/docker.sock` → `~/.docker/run/docker.sock` → `~/.rd/docker.sock`.
- 즉 colima / Docker Desktop / Rancher 어느 쪽이든 데몬만 켜져 있으면 추가 설정이 필요 없다.
  (2026-07-27 이전에는 `/var/run/docker.sock` 하드코딩 → Docker Desktop 미실행 + colima 사용 시
  끊긴 심볼릭 링크를 잡아 로컬 CI 게이트를 통과할 수 없었다.)
- 확인: `docker info --format '{{.ServerVersion}}'` → 값이 나오면 OK.
- 특수 런타임을 강제하려면 `DOCKER_HOST=unix:///path/to/docker.sock ./gradlew test`.
