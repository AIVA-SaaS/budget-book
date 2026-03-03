# Current Tasks - Budget Book

## How to Use (Team Coordination)
- Each agent reads this file at session start
- Claim a task by writing your name in the `Owner` field
- Update status: `TODO` → `IN_PROGRESS` → `DONE`
- Pull before editing, commit after updating
- Only edit files in YOUR ownership scope

## Completed
- [x] Phase 1: OAuth2 Auth (Google/Kakao) - Backend + Frontend + Deploy

## Active Sprint — Phase 1 Cleanup

### Pending Verification
| ID | Task | Owner | Status |
|----|------|-------|--------|
| V1 | Google OAuth end-to-end flow test (frontend → backend → callback) | - | TODO |

### Known Issues to Fix
| ID | Task | Owner | Status | Notes |
|----|------|-------|--------|-------|
| FIX-6 | Fix JWT secret default value in production config | backend | IN_PROGRESS | Task #6 |
| FIX-7 | Add @Transactional to CustomOAuth2UserService.findOrCreateUser | backend | IN_PROGRESS | Task #7 |
| FIX-8 | Add unique constraint on (provider, provider_id), handle duplicate email across providers | backend | TODO | Task #8 |
| FIX-9 | Add missing backend tests: JwtAuthenticationFilter, OAuth2Handlers, GlobalExceptionHandler | backend | TODO | Task #9 |
| FIX-10 | Add missing frontend tests: widget tests, AuthRemoteDataSource, AuthInterceptor | frontend | TODO | Task #10 |
| FIX-11 | Add scheduled cleanup for expired/revoked refresh tokens | backend | TODO | Task #11 |

---

## Phase 2a Sprint — Core Budget Features

> Roadmap: `docs/phase2-roadmap.md`
> API Spec: `docs/api-spec.md` (Couple, Categories, Transactions sections)
> DB Migrations: V3, V4, V5 — ready to apply

### Contract Tasks (contract-teammate)
| ID | Task | Owner | Status |
|----|------|-------|--------|
| CT-P2-spec | API spec written: Couple, Categories, Transactions endpoints | contract | DONE |
| CT-P2-db | DB migrations V3–V5 written: couples, categories, transactions | contract | DONE |

### Backend Tasks (backend-teammate)
| ID | Task | Owner | Status | Blocked By |
|----|------|-------|--------|------------|
| BE-P2-1 | Implement couple domain: entity, invitation flow, couple service/controller | - | TODO | - |
| BE-P2-3 | Implement category domain: entity, CRUD, default seeding on couple activation | - | TODO | BE-P2-1 |
| BE-P2-2 | Implement transaction domain: entity, CRUD, pagination, month filter | - | TODO | BE-P2-1, BE-P2-3 |

#### BE-P2-1 Acceptance Criteria
- `POST /api/v1/couples/invitations` → generates 8-char code, expires 24h
- `POST /api/v1/couples/invitations/{code}/accept` → links users, creates couple, seeds default categories (triggers BE-P2-3 seeding)
- `GET /api/v1/couples/me` → returns couple + partner info
- `DELETE /api/v1/couples/me` → dissolves couple (status = DISSOLVED)
- Entities: `Couple`, `CoupleInvitation`
- Service: validates one active couple per user, handles expiry, cancels previous pending invitation

#### BE-P2-3 Acceptance Criteria
- `GET /api/v1/categories?type=` → returns couple's categories
- `POST /api/v1/categories` → creates custom category
- `PUT /api/v1/categories/{id}` → updates (name/icon/color/displayOrder)
- `DELETE /api/v1/categories/{id}` → soft-delete guard: cannot delete `is_default = true`
- Seed default 8 categories (4 INCOME + 4 EXPENSE) on couple activation

#### BE-P2-2 Acceptance Criteria
- `POST /api/v1/transactions` → creates transaction
- `GET /api/v1/transactions?year=&month=&type=&categoryId=&page=&size=` → paginated list
- `GET /api/v1/transactions/{id}` → single record
- `PUT /api/v1/transactions/{id}` → update fields
- `DELETE /api/v1/transactions/{id}` → delete record
- Caller must be a member of the couple that owns the transaction
- All endpoints return `ApiResponse<T>`

### Frontend Tasks (frontend-teammate)
| ID | Task | Owner | Status | Blocked By |
|----|------|-------|--------|------------|
| FE-P2-1 | Couple linking UI: invite code generation, share screen, accept screen, couple status | - | TODO | BE-P2-1 |
| FE-P2-3 | Category management UI: list with type tabs, create/edit form, delete with guard | - | TODO | BE-P2-3, FE-P2-1 |
| FE-P2-2 | Transaction UI: monthly list screen, create/edit form, filter by type/category | - | TODO | BE-P2-2, FE-P2-3 |

#### FE-P2-1 Acceptance Criteria
- Couple status screen (no couple / pending / active states)
- Generate & share invitation code button
- Enter invitation code screen with accept flow
- BLoC: `CoupleBloc` with states: `CoupleInitial`, `CoupleLoading`, `CoupleNotLinked`, `CoupleLinked`, `CoupleError`

#### FE-P2-3 Acceptance Criteria
- Category list screen with INCOME/EXPENSE tabs
- Add custom category bottom sheet (name, type, icon/color picker)
- Edit/delete swipe actions (delete guard on default categories)
- BLoC: `CategoryBloc`

#### FE-P2-2 Acceptance Criteria
- Transaction list screen: grouped by date, month navigation, income/expense summary bar
- Add/edit transaction screen: type, amount, description, category picker, date
- Delete with confirmation dialog
- BLoC: `TransactionBloc`

---

## Backlog (Phase 2b+)
| ID | Task | Owner | Scope |
|----|------|-------|-------|
| P2-4 | Monthly budget planning | backend + frontend | budget feature |
| P2-5 | Statistics & charts | backend + frontend | statistics feature |
| P2-6 | Real-time sync (WebSocket) | backend + frontend | websocket |
| P2-7 | Redis integration (Upstash) | backend | cache/session |
