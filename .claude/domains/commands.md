# Build & Test Commands

| 대상 | 명령 |
|-----|-----|
| Backend 빌드 | `cd backend && ./gradlew build` |
| Backend 테스트 | `cd backend && ./gradlew test` |
| Frontend 의존성 | `cd frontend && flutter pub get` |
| Frontend 테스트 | `cd frontend && flutter test` |
| Frontend 빌드 | `cd frontend && flutter build web` |
| 로컬 인프라 | `cd infra && docker-compose up -d` |
