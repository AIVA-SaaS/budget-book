# Current Tasks - Budget Book

## How to Use (Team Coordination)
- Each agent reads this file at session start
- Claim a task by writing your name in the `Owner` field
- Update status: `TODO` → `IN_PROGRESS` → `DONE`
- Pull before editing, commit after updating
- Only edit files in YOUR ownership scope

## Completed
- [x] Phase 1: OAuth2 Auth (Google/Kakao) - Backend + Frontend + Deploy
- [x] Phase 1 Cleanup: JWT secret fix, @Transactional, email-first linking, missing tests, refresh token scheduler
- [x] Phase 2a: Couple linking, Category management, Transaction CRUD - Backend + Frontend

## Active Sprint (Phase 2b)

| ID | Task | Owner | Status | Scope |
|----|------|-------|--------|-------|
| CT-P2b-spec | API spec for budget + statistics endpoints | contract-teammate | DONE | docs/api-spec.md |
| CT-P2b-db | DB migration V6 (monthly_budgets) | contract-teammate | DONE | db/migration |
| BE-P2-4 | Backend: Budget domain (entity, CRUD, summary) | backend-teammate | TODO | budget feature |
| BE-P2-5 | Backend: Statistics domain (summary, by-category, trend) | backend-teammate | TODO | statistics feature |
| FE-P2-4 | Frontend: Budget UI (plan screen, per-category budgets) | frontend-teammate | TODO | budget feature |
| FE-P2-5 | Frontend: Statistics UI (charts, trend) | frontend-teammate | TODO | statistics feature |

## Backlog (Phase 2c+)
| ID | Task | Owner | Scope |
|----|------|-------|-------|
| P2-6 | Real-time sync (WebSocket) | backend + frontend | websocket |
| P2-7 | Redis integration (Upstash) | backend | cache/session |
