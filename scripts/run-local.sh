#!/bin/bash
# Budget Book - Local Development Runner
# BE: localhost:8090 (Spring Boot + DevTools auto-restart)
# FE: localhost:3050 (Flutter Web hot-reload)
#
# Usage:
#   ./scripts/run-local.sh        # BE + FE
#   ./scripts/run-local.sh be     # BE only (auto-restart on code change)
#   ./scripts/run-local.sh fe     # FE only (hot-reload)

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env.local"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}Error: .env.local not found${NC}"
  echo "  cp .env.local.example .env.local"
  exit 1
fi

set -a; source "$ENV_FILE"; set +a

for var in DB_HOST DB_USERNAME DB_PASSWORD JWT_SECRET; do
  if [ -z "${!var}" ]; then
    echo -e "${RED}Error: $var not set in .env.local${NC}"; exit 1
  fi
done

PIDS=()

cleanup() {
  echo -e "\n${YELLOW}Shutting down...${NC}"
  for pid in "${PIDS[@]}"; do
    kill $pid 2>/dev/null
  done
  # Kill any remaining gradle daemons for this project
  lsof -ti:8090 2>/dev/null | xargs kill -9 2>/dev/null
  wait 2>/dev/null
  echo -e "${GREEN}Done${NC}"
}
trap cleanup EXIT INT TERM

run_be() {
  echo -e "${GREEN}[BE] Starting on :8090 (DevTools auto-restart enabled)${NC}"
  cd "$PROJECT_DIR/backend"

  # Continuous compilation: watches for changes and recompiles
  SPRING_PROFILES_ACTIVE=local-supabase ./gradlew -t classes -x test --quiet 2>&1 &
  PIDS+=($!)

  # Boot server with DevTools (auto-restarts when classes change)
  sleep 3
  SPRING_PROFILES_ACTIVE=local-supabase ./gradlew bootRun \
    --args='--server.port=8090' 2>&1 &
  PIDS+=($!)
}

run_fe() {
  echo -e "${GREEN}[FE] Starting on :3050 (hot-reload enabled)${NC}"
  cd "$PROJECT_DIR/frontend"
  flutter run -d chrome \
    --web-port=3050 \
    --dart-define=API_BASE_URL=http://localhost:8090 2>&1 &
  PIDS+=($!)
}

MODE="${1:-all}"

case "$MODE" in
  be)
    run_be
    echo -e "\n${GREEN}=== BE Running ===${NC}"
    echo -e "  API:    ${YELLOW}http://localhost:8090${NC}"
    echo -e "  Health: ${YELLOW}http://localhost:8090/actuator/health${NC}"
    echo -e "  ${YELLOW}코드 수정 시 자동 재시작됩니다${NC}"
    echo -e "\nCtrl+C to stop\n"
    wait
    ;;
  fe)
    run_fe
    echo -e "\n${GREEN}=== FE Running ===${NC}"
    echo -e "  Web: ${YELLOW}http://localhost:3050${NC}"
    echo -e "\nCtrl+C to stop\n"
    wait
    ;;
  all|*)
    run_be
    sleep 10
    run_fe
    echo -e "\n${GREEN}=== Local Dev Running ===${NC}"
    echo -e "  BE: ${YELLOW}http://localhost:8090${NC} (auto-restart)"
    echo -e "  FE: ${YELLOW}http://localhost:3050${NC} (hot-reload)"
    echo -e "  ${YELLOW}BE 코드 수정 → 자동 컴파일 → 자동 재시작${NC}"
    echo -e "  ${YELLOW}FE 코드 수정 → r 키로 hot-reload${NC}"
    echo -e "\nCtrl+C to stop\n"
    wait
    ;;
esac
