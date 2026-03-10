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
- Use Korean for user-facing strings, English for code/comments/docs
- All API responses wrap in `ApiResponse<T>` with `success`, `data`, `error` fields
- Database migrations use Flyway with `V{N}__` naming convention
- Flutter state management uses BLoC pattern exclusively
- Backend tests use Kotest (not JUnit) with BehaviorSpec or FunSpec style

## Verification Gate (모든 작업에 필수 적용)

**"완료" = 코드 작성 완료가 아니라, 동작 검증 완료를 의미한다.**

작업 유형에 관계없이, 아래 단계를 모두 통과해야만 "완료"로 보고한다.
하나라도 실패하면 수정 후 재검증. 유저에게 실패 상태를 넘기지 않는다.

### 1. 구현 전 - 사전 분석
- 변경 범위의 **기술 스택 특성**을 먼저 확인 (프레임워크 문서, 프로토콜 스펙 등)
- 기존 코드와의 **통합 지점** 파악 (SecurityConfig, 라우터, DI 등)
- 설정 변경 시 **사이드이펙트** 분석 (lazy-init → Flyway 순서, 메모리 제한 → 시작 시간 등)

### 2. 구현 후 - 로컬 검증
| 변경 대상 | 필수 검증 |
|----------|----------|
| Backend 코드 | `./gradlew test` 전체 통과 |
| Frontend 코드 | `flutter analyze` + `flutter test` + `flutter build web` |
| Infra/설정 | 의존하는 기능의 테스트 재실행 |
| DB 마이그레이션 | 빈 DB에서 전체 마이그레이션 → validate 통과 확인 |
| 머지/리베이스 후 | 충돌 해결 후 반드시 `bash scripts/pre-deploy-check.sh` |

### 3. 배포 후 - 라이브 검증
| 대상 | 검증 방법 |
|------|----------|
| Backend (Render) | `/actuator/health` → DB status UP 확인 |
| Frontend (GitHub Pages) | 배포 URL 접속 → 페이지 로드 확인 |
| Auth 관련 변경 | 실제 OAuth2 로그인 플로우 302 리다이렉트 확인 |
| API 변경 | curl로 실제 엔드포인트 요청/응답 확인 |

### 4. 완료 보고 조건
- 위 1~3 단계를 **모두** 통과했을 때만 유저에게 "완료" 보고
- 검증 중 실패 발견 시: 수정 → 재검증 → 통과 확인 후 보고
- "CI에서 확인될 것이다"는 검증이 아님. 직접 확인한 결과만 신뢰

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

## Git Branch Strategy
- **main**: 프로덕션 배포 브랜치 (main 머지 시 자동 배포)
- **develop**: 개발 통합 브랜치 (CI 자동 실행)
- **feature/\***: 기능 브랜치 (develop에서 분기 → develop으로 PR)
- Branch naming: `feature/{feature-name}`, `fix/{bug-name}`, `chore/{task-name}`
- Commit messages: conventional commits (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`)
- Always create feature branches from `develop`, NOT from `main`
- Feature → develop: CI 통과 + Code Review 필수
- develop → main: 릴리즈 단위, 모든 CI 통과 필수

## Deployment
- **main 머지 시 자동 배포**:
  - `backend/**` 변경 → Render 자동 배포 (deploy-backend.yml)
  - `frontend/**` 변경 → Vercel 자동 배포 (deploy-frontend.yml)
- 배포 확인: BE `/actuator/health`, FE Vercel 프리뷰 URL

## CI Failure Recovery (Automated)
- CI 실패 시 GitHub Issue가 자동 생성됨 (label: `ci-failure`)
- **세션 시작 시 반드시 확인**: `gh issue list --label ci-failure --state open`
- 열린 ci-failure Issue가 있으면 다른 작업보다 우선 처리
- 해당 teammate에게 에러 로그와 함께 수정 할당
- 수정 완료 + CI 통과 후 Issue 자동 close
- 최대 3회 재수정 루프 → 초과 시 Lead 직접 디버깅
- 자세한 프로세스: `docs/agent-playbook.md` 참고

## Build & Test Commands
- Backend: `cd backend && ./gradlew build` / `./gradlew test`
- Frontend: `cd frontend && flutter pub get` / `flutter test` / `flutter build web`
- Local env: `cd infra && docker-compose up -d`
