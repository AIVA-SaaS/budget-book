# Budget Book - Full Roadmap

> Created: 2026-02-26
> Updated: 2026-03-11
> Status: Phase 3 Complete (All 5 features)

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

## Phase 3 — Advanced Features (Redesigned 2026-03-11)

**Goal:** 사용자 실제 가계부 운용 패턴 기반 기능 확장. 카테고리 계층화, 결제수단 추적, 주간 예산, 리포트.
**Target:** Phase 2c 이후 순차 진행

### P3-1: Category Groups (카테고리 그룹) ✅ Complete
**Business Value:** High — 생활비/고정지출/기타 등 2단계 계층 구조
**Complexity:** Medium

- New table: `category_groups` (budget_type: WEEKLY/MONTHLY/NONE)
- `categories.group_id` FK 추가 (nullable, backward compatible)
- BE: CategoryGroupService/Controller + CRUD + seedDefaultCategoryGroups
- FE: CategoryGroupPage + CategoryGroupBloc + form sheet
- 기본 3개 그룹 시드: 생활비(WEEKLY), 고정지출(MONTHLY), 기타(NONE)
- 카테고리 자동 할당: 식비/교통비/쇼핑 → 생활비, 기타/의료/문화 → 기타

### P3-2: Weekly Budget Cycle (주간 예산 사이클) ✅ Complete
**Business Value:** High — 주간 생활비 예산 추적, 초과/절약 기록
**Complexity:** Medium

- `monthly_budgets` 확장: budget_period (WEEKLY/MONTHLY), weekly_amount
- New table: `weekly_budget_snapshots` (주간 실적 추적)
- BE: WeeklyBudgetService — 주간 예산 분배, 주간 실적 조회, 현재 주 요약
- FE: WeeklyBudgetPage + WeeklyBudgetBloc + week_summary_card

### P3-3: Payment Methods & Card Tracking (결제수단 + 카드 미결제 추적) ✅ Complete
**Business Value:** High — 카드 결제 시점 vs 출금 시점 괴리 해결
**Complexity:** Medium

- New table: `payment_methods` (type: CASH/DEBIT/CREDIT, settlement_day, closing_day)
- `transactions` 확장: payment_method_id, settlement_date
- BE: PaymentMethodService/Controller + CRUD + seedDefaults + cardPendingSummary
- FE: PaymentMethodPage + PaymentMethodBloc + transaction form 결제수단 선택
- 신용카드 settlement_date 자동 계산 (마감일/결제일 기반)

### P3-4: Rule-based Reports (규칙 기반 주간/월간 리포트) ✅ Complete
**Business Value:** Medium — AI 없이 즉시 가치 제공
**Complexity:** Medium

- 주간 리포트: 예산 대비 초과 카테고리, 4주 평균 대비 deviation, 요일별 지출 패턴
- 월간 리포트: 그룹별 소계, 전월 대비 변동률, 카드 미결제 요약, 요일별 패턴
- BE: ReportService/Controller with aggregation queries
- FE: ReportPage (탭 뷰) + overspend_category_tile, daily_spending_chart, month_comparison_card

### P3-5: Recurring Transactions (자동 반복 거래) ✅ Complete
**Business Value:** High — 월급, 월세, 구독료 등 반복 지출 자동 기록
**Complexity:** Medium

- New table: `recurring_transactions` (frequency: DAILY/WEEKLY/MONTHLY/YEARLY, next_run_date)
- Scheduler: Spring `@Scheduled` 매일 06:00 실행, 자동 거래 생성
- BE: RecurringTransactionService/Controller + CRUD + executeRecurringTransactions
- FE: RecurringListPage + RecurringFormPage + RecurringBloc

---

## Phase 4 — Growth & Intelligence (Redesigned 2026-03-11)

**Goal:** 머니 포켓, AI 분석, 푸시 알림 등 지능화 기능.
**Target:** Phase 3 안정화 후
**Estimated Sprints:** 4 sprints

### P4-1: Money Pockets (머니 포켓 / 가상 통장) — Sprint 1
**Business Value:** High — 월급 분배 + 실질 잔액 관리
**Complexity:** Medium

**DB:**
- `money_pockets` (id, couple_id, name, type: LIVING/FIXED/CARD_PENDING/SAVINGS/CUSTOM, allocated_amount, icon, color, display_order, is_active)
- `pocket_transfers` (id, couple_id, from_pocket_id, to_pocket_id, amount, description, transfer_date, is_recurring)
- `transactions.pocket_id` FK 추가

**BE Tasks:**
- MoneyPocketService: CRUD + seedDefaults (생활비/고정지출/카드대기/저축)
- PocketTransferService: 포켓 간 이동 기록 + 조회
- MoneyPocketSummaryService: 포켓별 잔액 계산 (배정액 - 지출합계)
- 월급 분배 API: POST /api/v1/pockets/distribute (수입 → 각 포켓에 분배)

**FE Tasks:**
- MoneyPocketBloc/Page: 포켓 목록, 잔액 표시, CRUD
- 월급 분배 위자드: 스텝 바이 스텝으로 수입을 포켓에 할당
- 대시보드: "진짜 남은 돈" = 전체 포켓 잔액 합계

### P4-2: AI Auto-Classification + Feedback Loop (AI 자동 분류) — Sprint 2
**Business Value:** High — 차별화 핵심
**Complexity:** High

**DB:**
- `ai_classification_rules` (id, couple_id, keyword, suggested_category_id, confidence, source: AI/USER/SYSTEM, feedback_count, correct_count)
- `ai_classification_logs` (id, transaction_id, suggested_category_id, actual_category_id, was_correct, user_action: ACCEPTED/CORRECTED/SKIPPED)

**BE Tasks:**
- ClassificationService: keyword 기반 카테고리 매칭 (초기엔 규칙 기반, 이후 Claude API)
- FeedbackService: 사용자 피드백 수집 → rule confidence 업데이트
- TransactionService 연동: 거래 생성 시 auto-suggest 카테고리

**FE Tasks:**
- 거래 입력 시 AI 제안 배너: "식비로 분류할까요?" [✅ 수락] [✏️ 수정]
- 설정 페이지: AI 분류 ON/OFF, 자동 적용 임계값 (90%+), 미분류 처리
- 분류 정확도 대시보드 (선택적)

### P4-3: Claude API Deep Reports (Claude API 심층 리포트) — Sprint 3
**Business Value:** High — 개인화된 절약 제안
**Complexity:** High

**BE Tasks:**
- ClaudeReportService: 월간 집계 데이터를 Claude API에 전송 → 자연어 인사이트 생성
- Prompt engineering: 지출 패턴 분석, 절약 제안, 이상 감지
- 캐싱: 생성된 리포트를 Redis/DB에 캐시 (API 비용 절감)
- Privacy: raw 거래 내용 미전송, 카테고리별 합계만 전달

**FE Tasks:**
- AI 인사이트 카드: 리포트 페이지에 AI 분석 섹션 추가
- 로딩 UX: AI 분석 생성 중 스켈레톤 UI
- 피드백: "이 인사이트가 도움이 되었나요?" 평가

### P4-4: Push Notifications (예산 초과 알림) — Sprint 4
**Business Value:** High — 예산 관리 핵심 기능
**Complexity:** Medium

**DB:**
- `notification_preferences` (id, user_id, type, is_enabled, threshold)
- `notification_log` (id, user_id, type, title, body, is_read, sent_at)

**BE Tasks:**
- FCM integration (firebase-admin SDK)
- NotificationService: 알림 생성 + 발송
- Trigger 조건: 예산 80% 경고, 100% 초과, 파트너 거래, 주간 요약
- NotificationPreferenceService: 사용자별 알림 설정

**FE Tasks:**
- FCM token 등록 (firebase_messaging 패키지)
- 알림 설정 페이지: 각 트리거 ON/OFF
- 인앱 알림 목록 (NotificationListPage)
- Push 수신 시 해당 화면으로 네비게이션

### Phase 4 Sprint Delivery Order
```
Sprint 1: P4-1 Money Pockets      ← 기반 인프라, 사용자 체감 가장 높음
Sprint 2: P4-2 AI Classification   ← 핵심 차별화, classification rules 축적 시작
Sprint 3: P4-3 Claude Reports      ← AI 분류 데이터 활용, 리포트 고도화
Sprint 4: P4-4 Push Notifications  ← 리텐션 핵심, 위 기능들과 시너지
```

### Phase 4 Success Criteria
- [ ] 포켓별 잔액이 정확히 계산되고, 월급 분배 위자드가 동작
- [ ] AI 자동 분류 정확도 80%+ (50건 이상 피드백 후)
- [ ] Claude AI 리포트가 의미 있는 절약 제안을 제공
- [ ] Push 알림이 모바일/웹 모두 정상 수신

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
| Phase 3 | Category Groups + Payment Methods + Weekly Budget + Reports + Recurring | ✅ Complete |
| Phase 4 | Money Pockets + AI Classification + Claude Reports + Push | 💡 Future |
| Phase 5 | Premium + Native + Admin | 💡 Long-term |
