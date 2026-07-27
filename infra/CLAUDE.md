# Infrastructure - Docker, CI/CD, Deployment

## Deployment Target: Synology NAS
- **Domain**: https://aiva-bb.duckdns.org
- **SSH**: `ssh tiggle` (Synology NAS, configured in ~/.ssh/config)
- **SSL**: Let's Encrypt via Synology, certs at `/usr/syno/etc/certificate/_archive/AIVABB/`

## Architecture
```
[Client] → [nginx :443 SSL]
              ├── /api/*, /oauth2/*, /login/*, /actuator/*, /ws → [bb_app :8081]
              └── /* (SPA) → /var/services/web_bb/index.html
```

## Docker Containers on NAS
| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| bb_app | bb-backend | 8081→8080 | Spring Boot API |
| db_postgres_bb | postgres:16-alpine | 5433→5432 | PostgreSQL |
| redis_bb | redis:7-alpine | 6380→6379 | Redis cache |

## NAS File Locations
- **App repo**: `/volume1/docker/budget-book` (main branch)
- **Frontend build**: `/var/services/web_bb` (static files served by nginx)
- **nginx config**: `/usr/local/etc/nginx/sites-available/aiva-bb.conf` (sites-enabled 에 symlink).
  **단일 소스는 repo 의 `ops/nas-nginx/aiva-bb.conf`** — `deploy-nas.yml`(sync-nginx job)이 배포하고,
  `verify-live` job 이 배포마다 NAS 파일과 diff 해 drift 를 잡는다. NAS 에서 직접 고치지 말 것.
  캐시 정책은 `infra/scripts/verify-cache-headers.sh` 가 실제 응답 헤더로 검증한다
  (해시 없는 Flutter 산출물에 `immutable` 금지 — 2026-06-05 / 2026-07-27 아이콘 미노출 사고).
- **SSL certs**: `/usr/syno/etc/certificate/_archive/AIVABB/`

## CI/CD (GitHub Actions)
- **CI**: `ci-backend.yml`, `ci-frontend.yml` — runs on push to develop/feature branches
- **Deploy**: `deploy-nas.yml` — triggers on push to `main`
  - Backend: SSH into NAS → git pull → docker build → docker run
  - Frontend: Flutter build web on GitHub runner → SCP to NAS `/var/services/web_bb`
  - Verification: health check + site load test

### Required GitHub Secrets
| Secret | Description |
|--------|-------------|
| NAS_HOST | NAS public hostname/IP (DuckDNS) |
| NAS_USERNAME | SSH username |
| NAS_SSH_KEY | SSH private key for NAS access |
| NAS_SSH_PORT | SSH port (default 22) |
| NAS_DB_PASSWORD | PostgreSQL password |
| NAS_JWT_SECRET | JWT signing secret |
| GOOGLE_CLIENT_ID | Google OAuth2 client ID |
| GOOGLE_CLIENT_SECRET | Google OAuth2 client secret |
| KAKAO_CLIENT_ID | Kakao OAuth2 REST API key (선택: 미등록 시 카카오 로그인 비활성) |
| KAKAO_CLIENT_SECRET | Kakao OAuth2 client secret (선택) |

## Local Development
- `docker-compose.yml` runs: PostgreSQL (5433), Redis (6380), Backend (8081)
- Backend connects to local DB via `application-local.yml`
- Frontend dev server: `flutter run -d chrome` (web)

## Manual Deploy (without CI)
```bash
# Backend
ssh tiggle
cd /volume1/docker/budget-book
git pull origin main
cd backend && docker build -t bb-backend .
docker stop bb_app && docker rm bb_app
docker run -d --name bb_app --restart unless-stopped \
  --add-host=host.docker.internal:host-gateway \
  -p 8081:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  ... (env vars) \
  bb-backend

# Frontend (from local machine)
cd frontend && flutter build web --release --dart-define=API_BASE_URL=https://aiva-bb.duckdns.org
scp -r build/web/* tiggle:/var/services/web_bb/
```

## DEPRECATED
- ~~Render (BE hosting)~~ → replaced by NAS Docker
- ~~Supabase (DB)~~ → replaced by local PostgreSQL on NAS
- ~~GitHub Pages (FE)~~ → replaced by NAS nginx
- ~~Vercel (FE)~~ → replaced by NAS nginx
