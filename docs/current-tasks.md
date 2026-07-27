# Current Tasks - Budget Book

> 최종 갱신: 2026-07-27. 이 파일은 **지금 진행 중인 작업**만 담는다.
> 완료된 Phase 목록은 `docs/project-audit.md §1.1`, 미해결 이슈는 `docs/known-issues.md`,
> 세션별 기획/결과는 `docs/sessions/` 를 본다.

## How to Use (Team Coordination)
- Each agent reads this file at session start
- Claim a task by writing your name in the `Owner` field
- Update status: `TODO` → `IN_PROGRESS` → `DONE`
- Pull before editing, commit after updating
- Only edit files in YOUR ownership scope

## Completed (요약 — 상세는 project-audit.md)
- [x] Phase 1: OAuth2 인증(Google/Kakao) + JWT
- [x] Phase 2a: 커플 연결, 카테고리, 거래 CRUD
- [x] Phase 2b: 월 예산, 통계/분석
- [x] Phase 3: 카테고리 그룹, 결제수단, 주간 예산, 리포트, 반복 거래
- [x] Phase 11~13: 보험, 즐겨찾기, 지출 계획, 위시리스트(주차 배정)
- [x] Phase 22: 이체(`transfers.kind`) + 잔액 조정(ADJUSTMENT) + 자산 잔액
- [x] 홈 대시보드 위젯 커스터마이징, 공지사항, 피드백/릴리스노트
- [x] WebSocket 실시간 동기화(STOMP + Caffeine/Redis 2단계 캐시)
- [x] NAS 이전(Render/Supabase/Pages → Synology NAS), PWA 아이콘, DB 백업(오프사이트 암호화)

## Active Sprint (정산 스냅샷 기능 — 기획서 `docs/sessions/2026-07-27_1_plan.md`)

| ID | Task | Owner | Status | Scope |
|----|------|-------|--------|-------|
| PR1-FE | 필터 전파 구조적 수정 (`LoadTransactions` 생성자 봉인 + VO 단일화) | frontend | DONE | transaction/statistics bloc·repo·datasource |
| PR1-FE2 | `needsReviewOnly` 드롭 3곳 fix (sync/탭복귀/URL진입) | frontend | DONE | core/websocket, core/widgets, core/router |
| PR1-BE | `/statistics/summary` 에 `needsReviewOnly` 반영 (합계 ≠ 행 fix) | backend | DONE | statistics controller/service |
| PR1-BE2 | 거래 목록 페이지 상한 100 → 200 (FE `_pageSize` 와 일치) | backend | DONE | TransactionService |
| PR1-INFRA | Testcontainers Docker 소켓 후보 탐색 (colima/Desktop) | devops | DONE | build.gradle.kts, 통합테스트 전략 |
| PR1-DOC | api-spec settlement 응답 정정 / erd.md V13~V64 / KI-007·audit 상태 | contract | DONE | docs/ |
| PR2-BE | 정산 스냅샷 BE (V65 + 6 엔드포인트 + `reconciled` 필터 + 집계) | backend | TODO | reconciliation feature |
| PR3-FE | 정산 뷰(상단 미기록 / 하단 스냅샷별) + 배지 5곳 + sync | frontend | TODO | reconciliation feature |

## Backlog

| ID | Task | Scope |
|----|------|-------|
| RECON-P4 | 월말 "미기록 N건" 인앱 알림 | notification |
| RECON-P6 | 홈 대시보드 "미정산 N건" 위젯 | home |
| KI-007-P2 | 카카오 비즈니스 앱 전환(이메일 필수 동의) — 선택 | auth |
| REL-ANDROID | Android 스토어 배포 | infra |
| ASSET-PRIVATE | 개인 자산(PaymentMethod visibility/owner) + 이체 visibility 파생 | payment_method, transfer |
