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

## Root Cause Prevention (반복 버그 방지 — 모든 작업에 최우선 적용)

개발 전 아래 4가지 패턴에 해당하는지 반드시 점검. 해당되면 기획서에 명시적 대응 포함.

### P1. 클라이언트 상태 ≠ 서버 상태 (Client-Server Truth Mismatch)
- 네비게이션/권한/비즈니스 로직의 진실은 **반드시 서버 응답 기준**
- 클라이언트 캐시(SharedPreferences, 로컬 변수)는 UX 최적화용일 뿐, 의사결정 근거가 되면 안 됨
- **체크**: "이 조건 분기가 클라이언트 캐시만 보는가? 서버 상태를 확인하는가?"
- 예시: 온보딩 완료 여부 → SharedPreferences만 보면 안 됨, 서버의 coupleId도 확인

### P2. 프레임워크 설정 간 상충 (Framework Config Contradiction)
- 프레임워크 설정 변경 시 **암묵적으로 의존하는 모든 기능** 감사
- **체크**: "이 설정을 바꾸면 어떤 다른 기능이 깨지는가?" → 영향 기능 목록 작성
- 예시: STATELESS 세션 ↔ OAuth2 세션 기반 state 저장, lazy-init ↔ Flyway 순서

### P3. CI ≠ 프로덕션 환경 (Environment Parity Gap)
- CI에서 **반드시 prod 프로필 빌드 검증** 포함
- "로컬 통과 = 배포 가능"이 아님. 환경 차이(DB, 메모리, TLS 등)를 CI에서 잡아야 함
- **체크**: CI workflow에 prod profile 검증 step이 있는가?

### P4. 구현 존재 ≠ 사용자 발견 가능 (Feature Discoverability Gap)
- 모든 사용자 액션에 **명시적 UI 어포던스** 필수
- 제스처 전용(스와이프 등)은 반드시 대체 UI(버튼, 메뉴) 병행
- API 에러는 반드시 사용자에게 표시 (콘솔 출력만으로는 불충분)
- **체크**: "이 기능을 처음 쓰는 사용자가 3초 안에 찾을 수 있는가?"

---

## Verification Gate (모든 작업에 필수 적용)

**"완료" = 코드 작성 완료가 아니라, 동작 검증 완료를 의미한다.**

작업 유형에 관계없이, 아래 단계를 모두 통과해야만 "완료"로 보고한다.
하나라도 실패하면 수정 후 재검증. 유저에게 실패 상태를 넘기지 않는다.

### 1. 구현 전 - 사전 분석
- 변경 범위의 **기술 스택 특성**을 먼저 확인 (프레임워크 문서, 프로토콜 스펙 등)
- 기존 코드와의 **통합 지점** 파악 (SecurityConfig, 라우터, DI 등)
- 설정 변경 시 **사이드이펙트** 분석 (lazy-init → Flyway 순서, 메모리 제한 → 시작 시간 등)
- **Root Cause Prevention P1~P4 체크리스트 적용** (위 섹션 참조)

### 2. 구현 후 - 로컬 검증

#### 2a. 자동 검증 (테스트/빌드)
| 변경 대상 | 필수 검증 |
|----------|----------|
| Backend 코드 | `./gradlew test` 전체 통과 |
| Frontend 코드 | `flutter analyze` + `flutter test` + `flutter build web` |
| Infra/설정 | 의존하는 기능의 테스트 재실행 |
| DB 마이그레이션 | 빈 DB에서 전체 마이그레이션 → validate 통과 확인 |
| 머지/리베이스 후 | 충돌 해결 후 반드시 `bash scripts/pre-deploy-check.sh` |

#### 2b. 유저 플로우 검증 (테스트 통과와 별개 — 필수)
**테스트 통과 ≠ 동작 검증. 아래를 반드시 시뮬레이션할 것.**
- [ ] **생성 → 표시?**: 만든 데이터가 목록/대시보드에 즉시 나타나는가
- [ ] **수정 → 반영?**: 변경 후 되돌아가면 최신 데이터가 보이는가
- [ ] **삭제 → 전체 탭에서 사라짐?**: 관련된 모든 화면에서 제거되는가
- [ ] **네비게이션**: 앱 첫 실행 → 로그인 → 기능 사용 → 뒤로가기 → 탭 전환 전체 경로
- [ ] **엣지 케이스**: 데이터 없는 첫 사용자, 이미 데이터 있는 기존 사용자, 네트워크 오류
- [ ] **발견성(P4)**: 새 기능을 처음 보는 사용자가 찾고 사용할 수 있는가
- [ ] **서버 진실(P1)**: 클라이언트 캐시를 지워도(새 기기) 정상 동작하는가

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
