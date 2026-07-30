#!/bin/bash
# Pre-deploy verification script
# Run this BEFORE committing/pushing to ensure CI will pass
set -e

echo "========================================="
echo " Budget Book Pre-Deploy Verification"
echo "========================================="

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Backend tests
echo ""
echo "[1/4] Running Backend tests..."
cd "$ROOT_DIR/backend"
./gradlew test --quiet
echo "✅ Backend tests PASSED"

# 2. Frontend analyze
echo ""
echo "[2/4] Running Flutter analyze..."
cd "$ROOT_DIR/frontend"
# CI(ci-frontend.yml)와 동일한 플래그여야 한다 — 여기만 엄격하면 로컬 게이트가
# 통과 불가능해지고(기존 info 3건), 반대면 CI 에서 처음 터진다. 2026-07-30 정렬.
flutter analyze --no-fatal-infos --no-congratulate
echo "✅ Flutter analyze PASSED"

# 3. Frontend tests
echo ""
echo "[3/4] Running Flutter tests..."
cd "$ROOT_DIR/frontend"
flutter test
echo "✅ Flutter tests PASSED"

# 4. Frontend web build
echo ""
echo "[4/4] Running Flutter web build..."
cd "$ROOT_DIR/frontend"
flutter build web --quiet 2>/dev/null || flutter build web
echo "✅ Flutter web build PASSED"

echo ""
echo "========================================="
echo " ALL CHECKS PASSED - Safe to deploy!"
echo "========================================="
