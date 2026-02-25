# Budget Book - 부부 공유 가계부

## Project Overview
부부가 함께 사용하는 공유 가계부 앱. 수입/지출 관리, 카테고리별 예산 계획, 통계/분석, 실시간 동기화를 제공합니다.
한국어 우선, 영어 지원.

## Tech Stack
- **BE**: Kotlin + Spring Boot 3.x + Kotest + Gradle (Kotlin DSL)
- **DB**: PostgreSQL (Supabase) + Redis (Upstash)
- **FE/App**: Flutter 3.x (웹+모바일 통합, BLoC 패턴)
- **Auth**: OAuth2 소셜 로그인 (Google, Kakao)
- **Hosting**: Render (BE) + Supabase (DB) + Vercel (Flutter Web)
- **CI/CD**: GitHub Actions

## Monorepo Structure
- `backend/` - Kotlin Spring Boot API 서버
- `frontend/` - Flutter 앱 (웹+모바일 통합)
- `infra/` - Docker, 배포 설정, 스크립트
- `docs/` - API 명세, ERD, 아키텍처 결정
- `.claude/agents/` - On-demand subagent 정의
- `.github/workflows/` - CI/CD 파이프라인

## Critical Rules
- NEVER commit secrets, API keys, or .env files
- ALWAYS reference `docs/api-spec.md` before creating or modifying API endpoints
- ALWAYS run tests before marking tasks complete: `cd backend && ./gradlew test` or `cd frontend && flutter test`
- Use Korean for user-facing strings, English for code/comments/docs
- All API responses wrap in `ApiResponse<T>` with `success`, `data`, `error` fields
- Database migrations use Flyway with `V{N}__` naming convention
- Flutter state management uses BLoC pattern exclusively
- Backend tests use Kotest (not JUnit) with BehaviorSpec or FunSpec style

## File Ownership (Agent Teams)
When running in agent team mode:
- **Backend teammate**: owns `backend/src/**`, `backend/*.gradle.kts`
- **Frontend teammate**: owns `frontend/lib/**`, `frontend/test/**`, `frontend/pubspec.yaml`
- **Contract teammate**: owns `docs/**`, `backend/src/main/resources/db/migration/**`, `README.md`
- IMPORTANT: Do NOT edit files outside your ownership. Message the owning teammate instead.

## Shared Contract
- `docs/api-spec.md` is the single source of truth for API contracts
- Any API change MUST update api-spec.md FIRST, then implement
- Both BE and FE must conform to api-spec.md

## Git Conventions
- Branch naming: `feature/{feature-name}`, `fix/{bug-name}`, `chore/{task-name}`
- Commit messages: conventional commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`)
- Always create feature branches from `main`

## Build & Test Commands
- Backend: `cd backend && ./gradlew build` / `./gradlew test`
- Frontend: `cd frontend && flutter pub get` / `flutter test` / `flutter build web`
- Local env: `cd infra && docker-compose up -d`
