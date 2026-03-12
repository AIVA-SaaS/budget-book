# Redis Setup (Upstash)

Phase 2c adds Redis for session management and caching via Upstash serverless Redis.

## Redis is Optional

The application runs without Redis (graceful degradation). Spring Boot's
`RedisAutoConfiguration` is excluded by default in `application.yml`. The backend
re-enables it only when `spring.data.redis.url` is configured (prod profile).

If `REDIS_URL` is not set in production, Redis-backed features (WebSocket session
store, caching) fall back to in-memory or database-backed alternatives.

## Create a Free Upstash Instance

1. Go to https://console.upstash.com and sign up / log in.
2. Click **Create Database**.
3. Choose a name (e.g. `budget-book-prod`), region closest to your Render region
   (e.g. `us-east-1`), and type **Regional** (free tier).
4. Click **Create**.
5. On the database detail page, copy the **Redis URL** under the "Connect" tab.
   - The TLS URL starts with `rediss://` (double-s). Use this one.
   - Format: `rediss://default:PASSWORD@HOST:PORT`

## Configure Render (Production)

1. Open the Render dashboard at https://dashboard.render.com.
2. Select the `budget-book-api` service.
3. Go to **Environment** tab.
4. Add an environment variable:
   - **Key**: `REDIS_URL`
   - **Value**: paste the Upstash TLS URL (`rediss://default:PASSWORD@HOST:PORT`)
5. Click **Save Changes**. Render will redeploy automatically.

## Configure GitHub Secrets (CI/CD)

The deploy workflow (`deploy-backend.yml`) does not pass `REDIS_URL` to Render —
Render reads it directly from its dashboard. No GitHub Secret is required for
`REDIS_URL` unless you add Render API-based env var updates to the workflow.

If needed in the future, add it at:
**Repository Settings** → **Secrets and variables** → **Actions** → **New repository secret**
- Name: `REDIS_URL`
- Value: the Upstash TLS URL

## CI Behavior (No Redis in CI)

The backend CI workflow (`ci-backend.yml`) intentionally does NOT include a Redis
service container. `application.yml` globally excludes `RedisAutoConfiguration` and
`RedisRepositoriesAutoConfiguration`, so all tests pass without a running Redis instance.

Any Redis-dependent code in the backend must use `@ConditionalOnProperty` or test
profiles to disable Redis beans during test execution.

## Local Development

`infra/docker-compose.yml` runs a local Redis 7 container on port 6379.
`application-local.yml` connects to it via `localhost:6379`.

```bash
# Start local Redis (and Postgres)
cd infra && docker-compose up -d

# Verify Redis is up
docker exec budgetbook-redis redis-cli ping
# Expected: PONG
```

## Environment Variable Summary

| Variable   | Where to set          | Format                                   | Required |
|------------|-----------------------|------------------------------------------|----------|
| `REDIS_URL`| Render dashboard      | `rediss://default:PASS@HOST:PORT`        | Optional |

## Notes

- Always use `rediss://` (TLS) for Upstash, never `redis://` in production.
- Upstash free tier: 10,000 commands/day, 256 MB max data size.
- Upstash auto-pauses after inactivity — this is fine; it wakes on first command.
- The keep-alive workflow (`keep-alive.yml`) pings the backend every 14 minutes,
  but does NOT ping Redis. Upstash handles cold-start transparently.
