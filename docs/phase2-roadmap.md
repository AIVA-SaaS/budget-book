# Budget Book - Full Roadmap

> Created: 2026-02-26
> Updated: 2026-03-10
> Status: Phase 2b Complete, Phase 2c Planning

---

## Overview

Phase 1 delivered OAuth2 authentication (Google/Kakao) with JWT tokens. Phase 2 builds the core budget-sharing features on top of that foundation.

## Backlog Items

| ID   | Feature                       | Business Value | Complexity | Dependencies |
|:-----|:------------------------------|:--------------|:-----------|:-------------|
| P2-1 | Couple linking & invitation codes | High (shared=couple) | Medium | None |
| P2-2 | Transaction CRUD (income/expense) | High (core feature) | Medium | P2-1, P2-3 |
| P2-3 | Category management           | High (organize transactions) | Low | P2-1 |
| P2-4 | Monthly budget planning       | Medium (planning layer) | Medium | P2-2, P2-3 |
| P2-5 | Statistics & charts           | Medium (insights) | High | P2-2 |
| P2-6 | Real-time sync (WebSocket)    | Medium (live feel) | High | P2-2 |
| P2-7 | Redis integration (Upstash)   | Low (perf) | Medium | None |

## Dependency Graph

```
P2-1 (Couple) ──┬──► P2-3 (Categories) ──┬──► P2-2 (Transactions) ──┬──► P2-4 (Budget)
                │                         │                           ├──► P2-5 (Statistics)
                │                         └──► P2-2 (Transactions) ──└──► P2-6 (WebSocket)
P2-7 (Redis) ──── (independent, can be added any time)
```

---

## Phase 2a — Sprint 1 (Core Budget Features)

**Goal:** Enable a couple to link accounts, create categories, and record transactions.

### Included
- **P2-1**: Couple linking & invitation codes
- **P2-3**: Category management (couple-scoped, with system defaults)
- **P2-2**: Transaction CRUD (income/expense)

### Sprint 1 Task Breakdown

#### Backend (backend-teammate)
| Task ID | Task | Blocked By |
|:--------|:-----|:-----------|
| BE-P2-1 | Implement couple domain (entity, invitation flow, couple service/controller) | Contract done |
| BE-P2-3 | Implement category domain (entity, CRUD, default seeding on couple creation) | BE-P2-1 |
| BE-P2-2 | Implement transaction domain (entity, CRUD, pagination, filtering) | BE-P2-1, BE-P2-3 |

#### Frontend (frontend-teammate)
| Task ID | Task | Blocked By |
|:--------|:-----|:-----------|
| FE-P2-1 | Couple linking UI (invite code generation, accept screen, couple status) | BE-P2-1 |
| FE-P2-3 | Category management UI (list, create, edit, delete) | BE-P2-3, FE-P2-1 |
| FE-P2-2 | Transaction UI (list screen, create/edit form, filter by month) | BE-P2-2, FE-P2-3 |

#### Contract (contract-teammate)
| Task ID | Task |
|:--------|:-----|
| CT-P2-spec | API spec for couple, category, transaction endpoints |
| CT-P2-db | DB migrations V3 (couples), V4 (categories), V5 (transactions) |

### Sprint 1 Delivery Order
1. Contract teammate writes API spec + migrations (parallel, no blocks)
2. Backend teammate implements couple domain (BE-P2-1)
3. Backend teammate implements category domain (BE-P2-3), in parallel with Frontend starting FE-P2-1
4. Backend teammate implements transaction domain (BE-P2-2)
5. Frontend teammate integrates all three features once backend endpoints are ready

---

## Phase 2b — Sprint 2 (Budget Planning & Analytics)

**Goal:** Allow couples to plan monthly budgets per category and view spending analytics.

### Included
- **P2-4**: Monthly budget planning
- **P2-5**: Statistics & charts

### Sprint 2 Task Breakdown

#### Backend (backend-teammate)
| Task ID  | Task | Blocked By |
|:---------|:-----|:-----------|
| BE-P2-4  | Implement budget domain (MonthlyBudget entity, BudgetRepository, BudgetService, BudgetController, Kotest tests) | Contract done |
| BE-P2-5  | Implement statistics domain (StatisticsService with summary/by-category/trend queries, StatisticsController, Kotest tests) | Contract done |

#### Frontend (frontend-teammate)
| Task ID  | Task | Blocked By |
|:---------|:-----|:-----------|
| FE-P2-4  | Budget UI (budget plan screen: list budgets per month, create/edit/delete, fl_chart donut for usage) | BE-P2-4 |
| FE-P2-5  | Statistics UI (monthly summary card, category breakdown pie chart, month-over-month bar chart using fl_chart) | BE-P2-5, FE-P2-4 |

#### Contract (contract-teammate)
| Task ID      | Task |
|:-------------|:-----|
| CT-P2b-spec  | API spec for budget + statistics endpoints (done) |
| CT-P2b-db    | DB migration V6 (monthly_budgets table) (done) |

### Sprint 2 Delivery Order
1. Contract teammate writes API spec + V6 migration (parallel, no blocks)
2. Backend teammate implements budget domain (BE-P2-4)
3. Backend teammate implements statistics domain (BE-P2-5), in parallel with Frontend starting FE-P2-4
4. Frontend teammate integrates both features once backend endpoints are ready (FE-P2-5)

---

## Phase 2c — Sprint 3 (Real-time & Performance)

**Goal:** Add live sync between couple devices and improve performance with Redis caching.

### Included
- **P2-6**: Real-time sync (WebSocket/STOMP)
- **P2-7**: Redis integration (Upstash, for caching and session optimization)

### Sprint 3 Task Breakdown (TBD after Sprint 2)
- WebSocket STOMP endpoint (`/ws`)
- Couple channel (`/topic/couple/{coupleId}`)
- Events: `TRANSACTION_CREATED`, `TRANSACTION_UPDATED`, `TRANSACTION_DELETED`, `BUDGET_UPDATED`
- Redis caching for frequently read data (couple info, categories)

---

## DB Schema Overview (Phase 2)

### New Tables (Phase 2a)

```
couples
├── id (UUID PK)
├── user1_id (FK → users)
├── user2_id (FK → users, nullable until accepted)
├── status (PENDING | ACTIVE | DISSOLVED)
└── timestamps

couple_invitations
├── id (UUID PK)
├── inviter_id (FK → users)
├── invitation_code (VARCHAR(8), UNIQUE)
├── status (PENDING | ACCEPTED | EXPIRED | CANCELLED)
├── expires_at (TIMESTAMPTZ)
└── timestamps

categories
├── id (UUID PK)
├── couple_id (FK → couples)
├── name (VARCHAR(50))
├── type (INCOME | EXPENSE)
├── icon (VARCHAR(50), nullable)
├── color (VARCHAR(7), nullable, hex)
├── is_default (BOOLEAN)
├── display_order (INTEGER)
└── timestamps

transactions
├── id (UUID PK)
├── couple_id (FK → couples)
├── author_id (FK → users)
├── category_id (FK → categories, nullable)
├── type (INCOME | EXPENSE)
├── amount (BIGINT, in KRW)
├── description (VARCHAR(255))
├── memo (TEXT, nullable)
├── transaction_date (DATE)
└── timestamps
```

### New Tables (Phase 2b)

```
monthly_budgets
├── id (UUID PK)
├── couple_id (FK → couples)
├── category_id (FK → categories, nullable = total budget)
├── year_month (VARCHAR(7), e.g. "2024-01")
├── amount (BIGINT, in KRW)
└── timestamps
```

---

---

## Architectural Decision: Multi-Provider Account Linking (Task #8)

> **Status:** Decision made — Option A1 adopted for Phase 2a

### Problem

`users.email` has a UNIQUE constraint. If a user registers with Google (`user@gmail.com`) and later logs in with Kakao using the same email, the DB INSERT fails with a duplicate key error.

Current constraints:
- `uk_users_email` — UNIQUE on `email` ← causes the crash
- `uk_users_provider_provider_id` — UNIQUE on `(provider, provider_id)` ← works correctly

### Options Considered

#### Option A1 — Same email = same account, email-first lookup (✅ Adopted)

**Logic in `CustomOAuth2UserService`:**
1. `findByProviderAndProviderId(provider, providerId)` → if found, return user (normal path)
2. `findByEmail(email)` → if found with **different** provider, return existing user as-is (no error)
3. If not found → create new user

**What changes:**
- Service logic only — no DB migration needed
- `users.email` UNIQUE constraint stays (still correct: one email = one account identity)
- If user A signed up with Google then logs in with Kakao (same email), they land in the same account
- Their stored `provider`/`provider_id` reflects whichever they originally signed up with

**Pros:** Zero schema change, good UX (single identity), correct behavior for a couples app
**Cons:** Secondary provider credentials not stored (can't distinguish "logged in as Google vs Kakao")

#### Option A2 — Full multi-provider support (Future / Phase 2b+)

Add a `user_providers` table:

```sql
CREATE TABLE user_providers (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    provider    VARCHAR(20) NOT NULL,
    provider_id VARCHAR(255) NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_user_providers UNIQUE (provider, provider_id)
);
```

Move `provider`/`provider_id` from `users` to this table. Allows one account to have both Google and Kakao credentials stored. Requires migration + entity refactor.

**Not needed for Phase 2a.** Revisit if users report needing it.

#### Option B — Separate accounts per provider (❌ Rejected)

Remove `uk_users_email` and allow duplicate emails across providers. Two separate budget histories for the same person — bad UX for a shared couples app.

### Decision: Option A1

**Phase 2a fix (no migration, service-only):**
- `CustomOAuth2UserService.findOrCreateUser()`: if `findByEmail()` returns a user with a different provider, return that existing user without throwing `DUPLICATE_RESOURCE`
- This is a service logic fix — backend-teammate handles in Task #8

**Future upgrade path:**
- If multi-provider credential storage is needed → implement Option A2 with a `user_providers` migration in Phase 2b+

---

## Success Criteria

### Phase 2a ✅ Complete (2026-03-03)
- [x] Two users can link as a couple via invitation code
- [x] Couple can view, create, edit, and delete categories
- [x] Couple can record income and expense transactions
- [x] Transactions are visible to both members of the couple
- [x] Transactions can be filtered by month, type, and category
- [x] All endpoints covered by tests (Backend: Kotest, Frontend: widget tests)
- [x] CI passing on `develop` branch

### Phase 2b ✅ Complete (2026-03-10)
- [x] Couple can set monthly budgets per category
- [x] Budget vs actual spending comparison with progress bars
- [x] Monthly summary (income/expense/balance) statistics
- [x] Category breakdown with pie chart
- [x] Monthly trend with line chart (6 months)
- [x] 171 frontend tests, all backend tests passing

---

## Phase 2c — Sprint 3 (Real-time & Performance)

**Goal:** Add live sync between couple devices and improve performance with Redis caching.
**Priority:** High — real-time UX differentiator for couples app.
**Estimated Complexity:** High

### Included
- **P2-6**: Real-time sync (WebSocket/STOMP)
- **P2-7**: Redis integration (Upstash)

### Sprint 3 Task Breakdown

#### Contract (contract-teammate)
| Task ID | Task |
|:--------|:-----|
| CT-P2c-spec | WebSocket event spec + Redis cache strategy doc |

#### Backend (backend-teammate)
| Task ID | Task | Blocked By |
|:--------|:-----|:-----------|
| BE-P2-6a | WebSocket STOMP config (`/ws` endpoint, Spring WebSocket + STOMP) | Contract done |
| BE-P2-6b | SyncEventPublisher: broadcast events to `/topic/couple/{coupleId}` on CRUD operations | BE-P2-6a |
| BE-P2-6c | Event types: TRANSACTION_CREATED/UPDATED/DELETED, BUDGET_UPDATED, CATEGORY_UPDATED | BE-P2-6b |
| BE-P2-7a | Upstash Redis config (Spring Data Redis, connection pool) | Contract done |
| BE-P2-7b | Cache couple info, categories (read-heavy, rarely updated) | BE-P2-7a |
| BE-P2-7c | Cache invalidation on write operations | BE-P2-7b |

#### Frontend (frontend-teammate)
| Task ID | Task | Blocked By |
|:--------|:-----|:-----------|
| FE-P2-6a | WebSocket client (STOMP over SockJS) | BE-P2-6b |
| FE-P2-6b | Auto-refresh transaction/budget lists on WebSocket event | FE-P2-6a |
| FE-P2-6c | Connection status indicator (connected/reconnecting) | FE-P2-6a |

### Sprint 3 Delivery Order
1. Contract: WebSocket event spec + Redis cache keys definition
2. Backend: WebSocket config → Event publisher → Event types (parallel with Redis setup)
3. Frontend: WebSocket client → Auto-refresh on events → Connection indicator

---

## Phase 3 — Advanced Features

**Goal:** Add recurring transactions, receipt capture, and push notifications.
**Target:** After Phase 2c stabilization

### P3-1: Recurring Transactions (자동 반복 거래)
**Business Value:** High — 월급, 월세, 구독료 등 반복 지출 자동 기록
**Complexity:** Medium

- New table: `recurring_transactions` (frequency: DAILY/WEEKLY/MONTHLY/YEARLY, next_run_date)
- Scheduler: Spring `@Scheduled` job to create transactions on due date
- UI: "반복" 토글 on transaction form, recurring list management page
- Notifications: "이번 달 자동 기록 N건" summary

### P3-2: Receipt Photo Upload (영수증 촬영)
**Business Value:** Medium — 편의성 향상, 증빙 보관
**Complexity:** High

- Storage: Supabase Storage (S3-compatible, free tier 1GB)
- Backend: multipart upload endpoint, image URL stored in transactions
- Frontend: camera/gallery picker, image preview in transaction detail
- Optional future: OCR integration for auto-fill (amount, date, store name)

### P3-3: Push Notifications (예산 초과 알림)
**Business Value:** High — 예산 관리 핵심 기능
**Complexity:** Medium

- FCM (Firebase Cloud Messaging) integration
- Trigger conditions:
  - Budget exceeded (지출 > 예산 100%)
  - Budget warning (지출 > 예산 80%)
  - Partner recorded a transaction (실시간 알림)
  - Weekly spending summary (주간 리포트)
- Backend: notification service + FCM sender
- Frontend: notification permission, settings page for toggle on/off per type
- DB: `notification_preferences` table, `notification_log` table

### P3-4: Data Export (CSV/Excel)
**Business Value:** Medium — 데이터 백업, 세무 신고 활용
**Complexity:** Low

- Backend: `/api/v1/export/transactions?year=2026&format=csv|xlsx`
- Apache POI for Excel, OpenCSV for CSV
- Frontend: export button on transaction list, download trigger

---

## Phase 4 — Growth & Intelligence

**Goal:** AI 기반 인사이트, 다중 통화, 저축 목표 등 고급 기능.
**Target:** Product-market fit 확인 후

### P4-1: Financial Goals (저축 목표)
**Business Value:** High — 부부 공동 목표 설정
**Complexity:** Medium

- Goal entity: name, target amount, deadline, current saved amount
- Monthly auto-tracking: balance surplus → goal contribution
- UI: goal list with progress, milestone celebrations
- Gamification: streaks, badges for consistent saving

### P4-2: AI-Powered Insights (소비 패턴 분석)
**Business Value:** High — 차별화 핵심
**Complexity:** High

- Claude API integration for spending pattern analysis
- Monthly AI report: "이번 달 식비가 지난달 대비 30% 증가했습니다"
- Anomaly detection: unusual spending alerts
- Budget recommendation: AI-suggested budgets based on history
- Privacy: all analysis on aggregated data, no raw transaction text sent

### P4-3: Multi-Currency Support (다중 통화)
**Business Value:** Low (한국 타겟) → Medium (글로벌 확장 시)
**Complexity:** Medium

- Currency field in transactions (default: KRW)
- Exchange rate API integration (한국은행 or Fixer.io)
- Converted amounts for statistics/budgets
- UI: currency picker, converted amount display

### P4-4: Family Mode (가족 공유)
**Business Value:** Medium — TAM 확장
**Complexity:** High

- Expand couple → group (2+ members)
- Role-based permissions (admin, member, viewer)
- Group budgets and shared categories
- Per-member spending limits
- Requires significant schema refactoring (couple_id → group_id)

---

## Phase 5 — Platform & Scale

**Target:** 사용자 1,000+ 이후

### P5-1: Premium Subscription (유료 플랜)
- Free: basic CRUD, 1 couple, 6-month history
- Premium: unlimited history, AI insights, receipt OCR, export, priority support
- Payment: Stripe or TossPayments integration

### P5-2: Mobile Native Optimization
- Offline mode with local SQLite + sync on reconnect
- Biometric auth (fingerprint/face)
- Home screen widgets (today's spending summary)
- Dark mode

### P5-3: Admin Dashboard
- User analytics (DAU/MAU, retention)
- Error monitoring (Sentry integration)
- Feature flags for gradual rollout
- A/B testing framework

---

## Release Timeline (Estimated)

| Phase | Content | Status |
|:------|:--------|:-------|
| Phase 1 | OAuth2 Auth (Google/Kakao) | ✅ Deployed |
| Phase 2a | Couple + Category + Transaction | ✅ Deployed |
| Phase 2b | Budget Planning + Statistics | ✅ Complete, deploying |
| Phase 2c | WebSocket + Redis | 📋 Next sprint |
| Phase 3 | Recurring + Receipt + Push + Export | 📋 Planned |
| Phase 4 | Goals + AI + Multi-currency + Family | 💡 Future |
| Phase 5 | Premium + Native + Admin | 💡 Long-term |
