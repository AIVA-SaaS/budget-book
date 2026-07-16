# Git · Deployment · CI

## Branch Strategy
- main: 프로덕션 배포 (push 시 자동 배포)
- 기능 브랜치: main 분기 → main으로 PR
- Branch naming: `feature/{name}` / `fix/{name}` / `chore/{name}`
- Commit: conventional commits (`feat:` / `fix:` / `chore:` / `docs:` / `test:` / `refactor:`)
- Feature → main: CI 통과 필수

## Deployment (Synology NAS)
자동 배포 (`deploy-nas.yml`, main 머지 시):
- `backend/**` → SSH: git pull + docker build + docker run
- `frontend/**` → GitHub runner: Flutter build → SCP 전송
- 배포 URL: https://aiva-bb.duckdns.org
- 배포 확인: `/actuator/health` (BE), 사이트 접속 (FE)

## CI Failure Recovery
- 세션 시작 시 확인: `gh issue list --label ci-failure --state open`
- ci-failure issue 있으면 최우선 처리
- 해당 teammate에게 에러 로그와 함께 수정 할당
- 수정 완료 + CI 통과 후 issue 자동 close
- 최대 3회 루프 → 초과 시 Lead 직접 디버깅
- 상세: `docs/agent-playbook.md`
