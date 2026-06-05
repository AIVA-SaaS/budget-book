#!/bin/bash
# db-backup.sh — change-gated PostgreSQL backup for budget-book (aiva-bb)
#
# 매일 NAS cron 으로 실행. pg_dump 내용 "지문"(전체 정렬 후 sha256)이 직전 백업과
# 다를 때만 새 백업을 저장한다. 동일하면 기존 백업을 그대로 두어 공간 낭비를 막는다.
#
# 지문 원리: pg_dump plain 출력은 타임스탬프가 없어 거의 결정적이지만 두 가지 noise 가
# 있다 — (1) COPY 데이터 행 순서가 heap 상태(UPDATE/autovacuum)에 따라 달라지고,
# (2) pg_dump 16.x 는 보안용 \restrict / \unrestrict 메타커맨드를 매 실행 랜덤 토큰으로
# 삽입한다. → restrict 줄을 제외하고 전체를 정렬하면, 논리적 데이터가 같으면 항상 같은
# 지문이 된다. 스키마(마이그레이션) 변경 시 DDL 줄이 달라져 지문이 바뀌므로 자동 백업.
# (\restrict 줄은 지문에서만 제외하고, 저장되는 백업 파일에는 그대로 보존한다.)
#
# 저장 위치: /volume2/bb-backups (live 데이터는 /volume1 → 디스크 분리)
# 보관: 최근 N개 변경분만 (RETENTION)
#
# 복구:
#   gunzip -c budgetbook_YYYYMMDD_HHMMSS.sql.gz \
#     | sudo /usr/local/bin/docker exec -i db_postgres_bb psql -U budgetbook -d budgetbook
#   (덤프는 --clean --if-exists 라 기존 객체를 drop 후 재생성. 빈 DB 복구도 안전.)

set -euo pipefail

# ── config ──
CONTAINER="db_postgres_bb"
DOCKER="/usr/local/bin/docker"
DB="budgetbook"
DB_USER="budgetbook"
BACKUP_DIR="/volume2/bb-backups"
RETENTION=30

# root 면 docker 직접, 아니면 sudo -n (cron 이 admin 으로 돌 때 대비)
if [ "$(id -u)" = "0" ]; then
  DEXEC="$DOCKER"
else
  DEXEC="sudo -n $DOCKER"
fi

LOG="${BACKUP_DIR}/backup.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

mkdir -p "$BACKUP_DIR"

TMP="$(mktemp /tmp/bb_dump.XXXXXX.sql)"
trap 'rm -f "$TMP"' EXIT

# ── 1) dump (plain SQL) ──
if ! $DEXEC exec "$CONTAINER" pg_dump -U "$DB_USER" \
      --clean --if-exists --no-owner --no-privileges "$DB" > "$TMP" 2>>"$LOG"; then
  log "ERROR: pg_dump 실패 — 기존 백업 보존, 종료"
  exit 1
fi

# 덤프 완결성 가드: 끝맺음 마커 없으면 손상/중단으로 보고 기존 백업 보존
if [ ! -s "$TMP" ] || ! grep -q "PostgreSQL database dump complete" "$TMP"; then
  log "ERROR: 덤프 불완전(빈 파일/미완료) — 기존 백업 보존, 종료"
  exit 1
fi

# ── 2) 내용 지문 (\restrict 제외 + 전체 정렬 sha256 → 행순서·랜덤토큰 noise 제거) ──
FP="$(grep -vE '^\\(un)?restrict ' "$TMP" | LC_ALL=C sort | sha256sum | awk '{print $1}')"
LAST_FILE="${BACKUP_DIR}/latest.sha256"
LAST="$(cat "$LAST_FILE" 2>/dev/null || echo '')"

if [ "$FP" = "$LAST" ]; then
  log "no change (fp=${FP:0:12}) — 백업 스킵"
  exit 0
fi

# ── 3) 변경 감지 → gzip 저장 + 지문 갱신 ──
TS="$(date '+%Y%m%d_%H%M%S')"
OUT="${BACKUP_DIR}/budgetbook_${TS}.sql.gz"
gzip -c "$TMP" > "$OUT"
echo "$FP" > "$LAST_FILE"
log "backup 생성: $(basename "$OUT") ($(du -h "$OUT" | awk '{print $1}'), fp=${FP:0:12})"

# ── 4) 보관: 최근 RETENTION 개 변경분만 유지 ──
ls -1t "${BACKUP_DIR}"/budgetbook_*.sql.gz 2>/dev/null | tail -n +$((RETENTION + 1)) | while read -r old; do
  rm -f "$old" && log "보관초과 삭제: $(basename "$old")"
done

exit 0
