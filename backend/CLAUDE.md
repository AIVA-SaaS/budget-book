# Backend - Kotlin Spring Boot API

## Stack
- Kotlin 1.9+, Spring Boot 3.2+, Java 21
- Spring Data JPA (PostgreSQL via Supabase)
- Spring Security + OAuth2 Client (Google, Kakao)
- Spring WebSocket (STOMP) for real-time sync
- Redis (Upstash) for session management and caching
- Flyway for database migrations
- Kotest 5.x for testing
- Gradle with Kotlin DSL and Version Catalog

## Package Structure
Package-by-feature under `com.budgetbook`:
- `auth/` - Authentication & user management
- `couple/` - Couple linking & invitation codes
- `transaction/` - Income/expense CRUD
- `category/` - Category management
- `budget/` - Monthly budget planning
- `statistics/` - Analytics & aggregation queries
- `notification/` - Budget alerts & push notifications
- `export/` - CSV/Excel data export
- `websocket/` - Real-time sync events
- `common/` - Shared exception handlers, base entities, utilities

## Conventions
- Each feature has: `controller/`, `service/`, `domain/`, `repository/`, `dto/`
- Controllers handle HTTP concerns only; delegate to services
- Services contain business logic; inject repositories
- Domain entities are JPA entities with `@Entity`
- DTOs are Kotlin data classes; map to/from domain with extension functions
- All entities extend `BaseTimeEntity` (createdAt, updatedAt)
- Use `ApiResponse<T>` wrapper for all REST responses
- Use `@Transactional` on service methods that write
- Exceptions are domain-specific (extend `BusinessException`)
- `GlobalExceptionHandler` maps exceptions to proper HTTP status codes

## Testing
- Use Kotest BehaviorSpec for service tests
- Use Kotest FunSpec for controller tests with MockMvc
- Use `@SpringBootTest` for integration tests
- Test files mirror source structure under `src/test/kotlin/`
- Test fixtures in `fixtures/TestFixtures.kt`
- Run tests: `./gradlew test`

## Auth Flow
1. Frontend redirects to `/oauth2/authorization/{provider}`
2. Spring Security handles OAuth2 dance
3. `OAuth2UserService` creates/updates user in DB
4. JWT token pair (access + refresh) returned to frontend
5. Access token in Authorization header, refresh token in httpOnly cookie

## Real-time Sync
- WebSocket endpoint: `/ws`
- STOMP destination: `/topic/couple/{coupleId}`
- Events: TRANSACTION_CREATED, TRANSACTION_UPDATED, TRANSACTION_DELETED, BUDGET_UPDATED
- `SyncEventPublisher` broadcasts changes to couple channel
