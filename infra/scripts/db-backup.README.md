# DB 백업 — `db-backup.sh`

aiva-bb 프로덕션 PostgreSQL(`db_postgres_bb`)의 **변경 감지(change-gated) 백업** 스크립트.

## 동작
매일 NAS cron 으로 실행. `pg_dump` 내용의 "지문"(fingerprint)이 직전 백업과 다를 때만 새 백업을 저장하고, 동일하면 기존 백업을 그대로 둔다 → **변경이 없으면 공간 낭비 0**.

- **지문 계산**: plain SQL 덤프에서 `\restrict`/`\unrestrict` 줄(pg_dump 16.x 가 매 실행 삽입하는 랜덤 보안 토큰)을 제외하고 전체를 정렬한 뒤 `sha256`. 정렬이 COPY 행 순서 noise(heap 상태에 따라 변함)를 제거하므로, **논리적 데이터가 같으면 항상 같은 지문**이 된다. 스키마(마이그레이션) 변경 시에는 DDL 줄이 달라져 지문이 바뀌므로 자동으로 백업이 트리거된다.
- **저장 위치**: `/volume2/bb-backups` — live 데이터(`/volume1`)와 물리 디스크 분리.
- **보관**: 최근 30개 변경분(`RETENTION`). 초과분 자동 삭제.
- **안전장치**: 덤프 실패/불완전(끝맺음 마커 없음) 시 기존 백업을 보존하고 종료(손상 덤프로 덮어쓰지 않음).
- 오프사이트(클라우드) 복사는 미적용 — 추후 필요 시 rclone/Hyper Backup 추가.

## 스케줄 (NAS cron)
DSM 7 `/etc/crontab` 에 TAB 구분으로 등록(매일 04:00, root):
```
0	4	*	*	*	root	/volume1/docker/budget-book/infra/scripts/db-backup.sh >/dev/null 2>&1
```
편집 후 반영: `sudo synosystemctl restart crond`

> NAS 의 `/etc/crontab` 은 repo 가 자동 동기화하지 않는다. 신규 NAS 셋업 시 위 줄을 직접 추가하거나 DSM Task Scheduler 로 등록할 것.

## 복구
```bash
gunzip -c /volume2/bb-backups/budgetbook_YYYYMMDD_HHMMSS.sql.gz \
  | sudo /usr/local/bin/docker exec -i db_postgres_bb psql -U budgetbook -d budgetbook
```
덤프는 `--clean --if-exists` 라 기존 객체를 drop 후 재생성한다. 빈 DB 로의 전체 복구도 안전(검증 완료: 11 users / 339 transactions / 122 categories 정확 복구).

> 인덱스 생성 fsync 때문에 NAS 디스크에서 복구가 수십 초~분 단위로 걸릴 수 있다(정상).
