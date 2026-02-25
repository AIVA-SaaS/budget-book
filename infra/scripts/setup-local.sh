#!/bin/bash
set -e

echo "=== Budget Book Local Setup ==="

# Start Docker containers
echo "[1/3] Starting PostgreSQL and Redis..."
cd "$(dirname "$0")/.."
docker-compose up -d

# Wait for services to be healthy
echo "[2/3] Waiting for services..."
sleep 5

# Check if services are running
docker-compose ps

echo "[3/3] Local environment is ready!"
echo ""
echo "  PostgreSQL: localhost:5432 (budgetbook/budgetbook)"
echo "  Redis:      localhost:6379"
echo ""
echo "  Backend:    cd backend && ./gradlew bootRun"
echo "  Frontend:   cd frontend && flutter run -d chrome"
