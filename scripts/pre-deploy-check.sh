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
flutter analyze
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
