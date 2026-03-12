# Infrastructure - Docker, CI/CD, Deployment

## Local Development
- `docker-compose.yml` runs: PostgreSQL (port 5432), Redis (port 6379)
- Backend connects to local DB via `application-local.yml`
- Frontend dev server: `flutter run -d chrome` (web) or `flutter run` (mobile)

## Production
- **Backend**: Render Web Service (Docker deploy from `backend/Dockerfile`)
- **Database**: Supabase PostgreSQL (managed)
- **Cache**: Upstash Redis (serverless)
- **Frontend Web**: Vercel (static Flutter web build)
- **Frontend Mobile**: App Store / Play Store via CI

## CI/CD (GitHub Actions)
- `ci-backend.yml`: triggers on `backend/**` changes
  - Checkout -> Setup JDK 21 -> Gradle cache -> Build -> Test -> Docker build
- `ci-frontend.yml`: triggers on `frontend/**` changes
  - Checkout -> Setup Flutter -> Pub get -> Analyze -> Test -> Build web
- `deploy-backend.yml`: deploys to Render on merge to `main`
- `deploy-frontend.yml`: deploys Flutter web to Vercel on merge to `main`

## Docker
- Backend Dockerfile: multi-stage (gradle build -> eclipse-temurin JRE 21)
- Frontend Dockerfile: multi-stage (Flutter build web -> nginx serve)
- Always run as non-root user in production containers
- Use `.dockerignore` to exclude `.gradle`, `build/`, `.dart_tool/`

## Render Configuration
- `render.yaml` defines the backend web service
- Health check: `GET /actuator/health`
- Environment variables managed via Render dashboard
- Phase 2c: `REDIS_URL` must be set in Render dashboard for Redis features
  - Format: `rediss://default:PASSWORD@HOST:PORT` (note: `rediss://` with TLS)
  - Create a free Upstash Redis instance at https://console.upstash.com
  - Copy the "Redis URL" (TLS) from the Upstash console
  - Redis is OPTIONAL: app degrades gracefully if `REDIS_URL` is not set
  - See `docs/redis-setup.md` for full setup instructions

## Scripts
- `scripts/setup-local.sh` - Bootstrap local dev environment
- `scripts/deploy.sh` - Manual deployment trigger
- `scripts/db-migrate.sh` - Run Flyway migrations manually
