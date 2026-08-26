# Budget Book

부부 공유 가계부 앱 (수입/지출·예산·통계·실시간 동기화). 한국어 우선, 영어 지원.

> 🗂 **볼트 배선(2026-08-25 단일 볼트 통합판)**: `~/vault/02-Projects/aiva-bb` 가 이 repo 의 `docs/` 를 비추는 **symlink 거울**이다 — 열람 전용.
> 작업은 반드시 **cwd = 이 repo**. 이 프로젝트는 `.claude/hooks/pre-edit-guard.sh` **project-local 하드게이트**라 다른 cwd 에서는 강제가 아예 뜨지 않는다(`GR1`).
> 등재는 **쌍**이다: `~/vault/01-Harness-System/00-Registry/projects.md`(사람) + `~/vault/.claude/registry.json`(훅). ⚠ 별칭 "가계부" 는 work-saas 선점 → `aiva-bb`/`budget-book` 으로 부른다.

## Tech Stack
- BE: Kotlin + Spring Boot 3.x + Kotest + Gradle (Kotlin DSL)
- DB: PostgreSQL 16 + Redis 7 (Synology NAS Docker)
- FE: Flutter 3.x, BLoC 패턴 (웹+모바일)
- Auth: OAuth2 (Google, Kakao) | Hosting: https://aiva-bb.duckdns.org | CI/CD: GitHub Actions → NAS

## Monorepo
- `backend/` — Spring Boot API
- `frontend/` — Flutter 앱
- `infra/` — Docker·배포 설정
- `docs/` — API 명세·ERD
- `.claude/agents/` — On-demand subagent

## Critical Rules
- API 엔드포인트 생성·수정 전 `docs/api-spec.md` 반드시 참조
- 사용자 노출 문자열 한국어, 코드·주석·문서 영어
- API 응답 `ApiResponse<T>` (`success`, `data`, `error`) 래핑
- DB 마이그레이션: Flyway `V{N}__` 네이밍
- Flutter 상태관리: BLoC 패턴 전용
- 백엔드 테스트: Kotest (JUnit 금지), BehaviorSpec 또는 FunSpec

## 프로젝트 도메인 라우팅

| 요청 유형 | 읽을 파일 |
|---------|---------|
| 에이전트 팀 모드·파일 소유권 | `.claude/domains/agents.md` |
| API 계약·spec 변경 | `.claude/domains/contracts.md` |
| PR·브랜치·배포·CI 실패 | `.claude/domains/git-deploy.md` |
| 빌드·테스트 명령 | `.claude/domains/commands.md` |
