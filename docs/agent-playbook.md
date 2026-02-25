# Lead Orchestration Playbook

## Agent Team Structure
- **Backend** teammate: Kotlin/Spring Boot API 개발
- **Frontend** teammate: Flutter 웹+앱 UI 개발
- **Contract** teammate: API 명세, DB 마이그레이션, 문서 관리

## On-Demand Subagents
| Subagent | Spawn 시점 |
|----------|-----------|
| DBA | 새 기능의 DB 스키마 변경 필요 시 |
| DevOps | 초기 셋업, CI/CD 파이프라인 수정 시 |
| Code Reviewer | 기능 완료 후, PR 생성 전 |
| Refactorer | 코드 리뷰에서 코드 스멜 발견 시 |
| Security Auditor | Auth/금융 기능 완료 후, 릴리즈 전 |

## Feature Development Workflow

### 1. Lead가 DBA subagent spawn (스키마 변경이 필요한 경우)
```
DBA → 마이그레이션 SQL 작성 → docs/erd.md 업데이트
```

### 2. Lead가 Task 목록 생성 (의존관계 포함)
```
T1: [Contract] api-spec.md에 엔드포인트 정의        (blocked by: 없음)
T2: [Backend]  API 구현 (controller/service/repo)   (blocked by: T1)
T3: [Frontend] UI 구현 (BLoC/pages/widgets)          (blocked by: T1)
T4: [Backend]  Kotest 테스트 작성                    (blocked by: T2)
T5: [Frontend] Widget/BLoC 테스트 작성               (blocked by: T3)
```

### 3. 병렬 실행
- T1 완료 → T2, T3 동시 시작 (BE/FE 병렬)
- T2 완료 → T4 시작, T3 완료 → T5 시작

### 4. 전체 완료 후
- Code Reviewer subagent spawn → 리뷰
- 필요 시 Refactorer subagent spawn → 코드 정리
- Lead가 커밋/PR 생성

## Git Branch Strategy & Deployment Flow

### Branch Structure
```
main          ← 프로덕션 배포 (자동 배포 트리거)
  └── develop ← 개발 통합 브랜치 (CI 자동 실행)
       ├── feature/auth       ← 기능 브랜치
       ├── feature/transaction
       └── fix/login-bug
```

### Feature → Deploy Flow
```
1. develop에서 feature 브랜치 생성
   $ git checkout develop && git checkout -b feature/{name}

2. Teammate들이 feature 브랜치에서 작업 + 커밋

3. feature → develop PR 생성
   - CI 자동 실행 (test, build, analyze)
   - Code Reviewer subagent가 리뷰
   - CI 통과 + 리뷰 통과 시 머지

4. develop → main PR 생성 (릴리즈 단위)
   - 모든 CI 통과 필수
   - Security Auditor subagent 실행 (금융 기능 포함 시)
   - 머지 시 자동 배포 트리거:
     - backend/** 변경 → Render 배포
     - frontend/** 변경 → Vercel 배포

5. 배포 후 확인
   - BE: {RENDER_URL}/actuator/health 체크
   - FE: Vercel 프리뷰 URL 확인
```

### CI 실패 시 재수정 루프
```
┌─ Teammate 작업 완료
│
├─ Lead: 로컬 테스트 실행
│   ├─ 성공 → PR 생성
│   └─ 실패 → 실패 원인 분석
│       │
│       ├─ BE 테스트 실패
│       │   → Backend teammate에게 재할당
│       │   → "테스트 실패: {에러 메시지}. 수정 후 테스트 통과시켜주세요."
│       │
│       ├─ FE 테스트/분석 실패
│       │   → Frontend teammate에게 재할당
│       │   → "flutter analyze 실패: {에러 메시지}. 수정해주세요."
│       │
│       └─ 빌드 실패 (의존성/설정 이슈)
│           → DevOps subagent spawn
│           → "빌드 실패 원인 분석 및 수정해주세요."
│
├─ Teammate 수정 완료 → 다시 테스트 실행 (루프)
│
└─ 테스트 통과 → PR 생성 → CI 실행
    ├─ CI 통과 → 머지
    └─ CI 실패 → 위 루프 반복 (최대 3회)
        └─ 3회 초과 시 Lead가 직접 디버깅 또는 유저에게 보고
```

### Lead의 테스트 실행 명령
```bash
# Backend 테스트
cd backend && ./gradlew test

# Frontend 테스트
cd frontend && flutter test

# Frontend 정적 분석
cd frontend && flutter analyze

# Frontend 웹 빌드
cd frontend && flutter build web
```

## Decision Matrix

| 상황 | 액션 |
|------|------|
| 새 기능에 DB 변경 필요 | DBA subagent spawn 먼저 |
| 기능 구현 완료 | Code Reviewer subagent spawn |
| Auth/금융 기능 완료 | Security Auditor subagent spawn |
| 기술 부채 누적 | Refactorer subagent spawn |
| CI/CD 파이프라인 이슈 | DevOps subagent spawn |
| 릴리즈 전 | Security Auditor + Code Reviewer spawn |
| BE/FE 동시 변경 필요 | Contract teammate가 먼저 api-spec 작성 |
| CI 테스트 실패 (BE) | Backend teammate에게 에러 메시지와 함께 재할당 |
| CI 테스트 실패 (FE) | Frontend teammate에게 에러 메시지와 함께 재할당 |
| CI 빌드 실패 | DevOps subagent spawn으로 빌드 이슈 분석 |
| 3회 이상 재수정 실패 | Lead가 직접 디버깅 또는 유저에게 보고 |

## Communication Protocols

```
[Backend → Contract]: "POST /api/budgets/{id}/alerts 엔드포인트가 필요합니다.
                       api-spec.md에 추가해주세요."

[Frontend → Backend]: "GET /api/transactions에 페이지네이션이 필요합니다.
                       page/size 쿼리 파라미터를 추가해주실 수 있나요?"

[Contract → 전체] (broadcast): "api-spec.md 업데이트: 모든 목록 API에
                       페이지네이션 추가. 양쪽 구현 부탁드립니다."

[Lead → code-reviewer] (subagent): "auth/ 기능의 BE/FE 변경사항 전체 리뷰."
```

## Development Phases

### Phase 1: Auth (OAuth2 소셜 로그인)
### Phase 2: Couple (초대 코드 기반 커플 연결)
### Phase 3: Transaction + Category (수입/지출 CRUD)
### Phase 4: Budget (월별 예산 계획)
### Phase 5: Statistics (통계/차트)
### Phase 6: Export + 보안감사 + 배포
