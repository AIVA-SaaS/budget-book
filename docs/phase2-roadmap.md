# Phase 2 Roadmap - Budget Book

> Created: 2026-02-26
> Status: Planning

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

### Sprint 2 Task Breakdown (TBD after Sprint 1)
- Monthly budget CRUD per category per month
- Summary statistics: total income, total expense, balance, by-category breakdown
- Month-over-month comparison
- Flutter charts integration (fl_chart)

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

## Success Criteria for Phase 2a

- [ ] Two users can link as a couple via invitation code
- [ ] Couple can view, create, edit, and delete categories
- [ ] Couple can record income and expense transactions
- [ ] Transactions are visible to both members of the couple
- [ ] Transactions can be filtered by month, type, and category
- [ ] All endpoints covered by tests (Backend: Kotest, Frontend: widget tests)
- [ ] CI passing on `develop` branch
