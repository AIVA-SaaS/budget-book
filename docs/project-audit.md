# Budget Book - Project Audit Report

> 작성일: 2026-03-12
> 최종 검증일: 2026-04-01
> 목적: 프로젝트 전후 비교 분석 → 개선/추가/리팩토링 필요사항 정리
> 활용: 추후 개발 요청 시 참고 문서

---

## 1. 프로젝트 현황 요약

### 1.1 구현 완료 기능

| Phase | 기능 | 상태 |
|:------|:-----|:-----|
| Phase 1 | OAuth2 인증 (Google, Kakao), JWT 발급/갱신/로그아웃 | 완료 |
| Phase 1 | 커플 연결 (초대코드 생성/수락/해산) | 완료 |
| Phase 2a | 거래 내역 CRUD (수입/지출) | 완료 |
| Phase 2a | 카테고리 관리 (기본 카테고리 자동 시드) | 완료 |
| Phase 2b | 월별 예산 계획 (카테고리별 예산, 예산 요약) | 완료 |
| Phase 2b | 통계/분석 (월 요약, 카테고리별 내역, 월별 트렌드) | 완료 |
| Phase 3 | 카테고리 그룹 (계층적 분류) | 완료 |
| Phase 3 | 결제수단 관리 (현금/체크카드/신용카드) | 완료 |
| Phase 3 | 주간 예산 스냅샷 | 완료 |
| Phase 3 | 리포트 (월별 리포트, 트렌드 분석) | 완료 |
| Phase 3 | 반복 거래 (스케줄러 자동 생성) | 완료 |
| Phase 11 | 보험 관리, 즐겨찾기, UI 일관성, 주간 예산 일할 계산 | 완료 |
| Phase 12 | 지출 계획 CRUD + 상태 추적 | 완료 |
| Phase 13 | 구매 목록 확장 (위시리스트 + 주차 배정) | 완료 |
| - | 홈 대시보드 (6위젯 커스터마이징) | 완료 |
| - | 설정 페이지 (테마, 언어, 프로필) | 완료 |
| - | 공지사항 (관리자 CRUD + 배너) | 완료 |
| - | WebSocket (STOMP + Caffeine/Redis 2단계 캐시) | 완료 |

### 1.2 테스트 현황

| 영역 | 수량 | 비고 |
|:-----|:-----|:-----|
| Backend (Kotest) | 586+ | BehaviorSpec/FunSpec |
| Frontend (Flutter) | 471 | BLoC 단위 테스트 중심, 전체 통과 |
| 통합 테스트 | 일부 | `@SpringBootTest` |
| 위젯 테스트 | 부족 | FE 위젯 테스트 GAP 존재 |

**알려진 테스트 공백:**
- `CustomOidcUserService` 테스트 없음 (`backend/src/main/kotlin/com/budgetbook/auth/service/CustomOidcUserService.kt`)
- Flutter 위젯 테스트: 주요 화면(TransactionFormPage, StatisticsPage 등) 테스트 없음

### 1.3 배포 상태

| 구성요소 | 플랫폼 | URL/포트 | 상태 |
|:--------|:-------|:---------|:-----|
| Backend API | NAS Docker (bb_app) | https://aiva-bb.duckdns.org/api, 내부 8081→8080 | Live |
| Frontend Web | NAS nginx | https://aiva-bb.duckdns.org | Live |
| Database | NAS PostgreSQL 16 (bb_postgres) | 내부 5433 | Live |
| Redis | NAS Redis 7 (redis_bb) | 내부 6380 | Live |
| CI/CD | GitHub Actions (deploy-nas.yml) | SSH + tar/docker | 동작 중 |

- Flyway 마이그레이션: V1~V41 전체 적용 완료
- 자동 배포: `main` 머지 시 SSH → NAS docker build + run (BE) / SCP 전송 (FE)
- 배포 URL: https://aiva-bb.duckdns.org

### 1.4 미구현 계획

| 항목 | 설명 | 우선순위 |
|:-----|:-----|:--------|
| Phase 4 | AI 거래 자동 분류 (Claude API) | Medium |
| Phase 4 | Claude Reports (AI 소비 인사이트) | Medium |
| Phase 4 | Push Notifications (예산 초과 알림) | Medium |
| 피드백 게시판 | 설계 완료, 구현 대기 (`docs/sessions/2026-03-29_3_plan.md`) | High |
| 인앱 알림 | 미구현 | Medium |
| Android 앱 배포 | 모바일 플랫폼 추가 필요 | Medium |

---

## 2. 보안 취약점 (Critical/High)

### Critical

| # | 위치 | 설명 | 담당 | 상태 |
|:--|:-----|:-----|:-----|:-----|
| S-1 | `backend/src/main/kotlin/com/budgetbook/auth/service/` | ~~OAuth2 Account Linking 취약점: 신규 로그인 시 이메일 기반 자동 계정 연결.~~ | BE | ✅ FIXED - `account_exists` 에러를 throw하여 크로스 프로바이더 이메일 자동 연결 차단 |
| S-2 | `backend/src/main/kotlin/com/budgetbook/couple/service/CoupleService.kt` | **초대코드 Brute-force 공격**: 초대코드 수락에만 Rate Limiting(5/hour) 적용. 로그인/계정 생성 등 다른 엔드포인트는 미적용. | BE | PARTIAL - 초대코드 수락 한정 적용, 확장 필요 |
| S-3 | `backend/src/main/kotlin/com/budgetbook/auth/` | **JWT 검증 캐싱**: Access Token 검증 시 Caffeine 캐시(TTL 5분, max 1000개) 적용으로 DB hit 최소화. | BE | ACCEPTABLE - 캐시로 완화, Redis 분산 캐시 고도화 가능 |

### High

| # | 위치 | 설명 | 담당 | 상태 |
|:--|:-----|:-----|:-----|:-----|
| S-4 | `backend/src/main/resources/application.yml` | ~~health show-details: always~~ | DevOps | ✅ FIXED - `when_authorized`로 변경 (application.yml + application-prod.yml 모두) |
| S-5 | `.github/workflows/` | ~~JWT Secret 하드코딩~~ | DevOps | ✅ FIXED - `deploy-nas.yml`에서 `${{ secrets.NAS_JWT_SECRET }}` 사용 |
| S-6 | `frontend/lib/core/network/auth_interceptor.dart` | ~~토큰 갱신 실패 미처리~~ | FE | ✅ FIXED - 갱신 실패 시 snackbar 표시 + AuthSessionExpired 이벤트 + 토큰 클리어 |

---

## 3. 성능 이슈

### Critical / High

| # | 위치 | 설명 | 심각도 | 담당 | 상태 |
|:--|:-----|:-----|:-------|:-----|:-----|
| P-1 | `backend/src/main/kotlin/com/budgetbook/budget/service/WeeklyBudgetService.kt` | ~~N+1 쿼리~~ | High | BE | ✅ FIXED - ID 선수집 후 배치 쿼리 패턴으로 교체 |
| P-2 | 여러 Repository | ~~Pageable.unpaged() OOM 위험~~ | High | BE | ✅ FIXED - 코드베이스에서 제거됨 |
| P-3 | `backend/src/main/kotlin/com/budgetbook/report/service/ReportService.kt` | **ReportService 쿼리 중복**: 동일 월 데이터를 여러 메서드에서 반복 조회(`sumByCategoryForCouple` 중복 호출). 캐싱 또는 단일 쿼리로 통합 필요. | Medium | BE | OPEN |
| P-4 | `frontend/lib/features/statistics/presentation/bloc/statistics_bloc.dart` | ~~StatisticsBloc 순차 API 호출~~ | Medium | FE | ✅ FIXED - `Future.wait()` 병렬 호출로 교체 |
| P-5 | `backend/src/main/kotlin/com/budgetbook/` (22개 서비스, 83곳) | **getActiveCouple() 중복 호출**: 22개 서비스 83곳에서 동일한 커플 조회 반복. RequestScope 캐싱 도입 필요. | Medium | BE | OPEN - 규모 증가 (9→22 서비스) |
| P-6 | `frontend/web` (NotoSansKR-VF.ttf) | **한글 폰트 로딩 9초**: `NotoSansKR-VF.ttf` 가변 폰트 2.2MB가 압축·캐시 미적용으로 초기 진입 시 9초 소요. 2026-04-25 사용자 보고. nginx vhost `gzip on` 이미 적용되었으나 `.ttf` MIME 미포함 가능성, 또는 Cache-Control 미설정. `ops/nas-nginx/aiva-bb.conf`에 font MIME gzip + long-term cache 추가 필요. 또는 `fonts.google.com` → 로컬 번들화. | High | FE/DevOps | OPEN |

---

## 4. 아키텍처 개선

### 4.1 Backend

| # | 위치 | 설명 | 심각도 | 난이도 | 상태 |
|:--|:-----|:-----|:-------|:-------|:-----|
| A-1 | `backend/src/main/kotlin/com/budgetbook/couple/service/CoupleService.kt` | ~~커플 해산 시 연관 데이터 미처리~~ | High | M | ✅ FIXED - status 변경 + 양쪽 유저 캐시 eviction 구현 |
| A-2 | `backend/src/main/kotlin/com/budgetbook/` | **getActiveCouple() 공통화 필요**: 22개 서비스에 중복된 패턴. `CoupleResolver` 또는 AOP로 추출 권장. | Medium | S | OPEN |
| A-3 | `backend/src/main/kotlin/com/budgetbook/transaction/` | **TransactionType 문자열 파싱 중복**: `INCOME`/`EXPENSE` 문자열을 여러 곳에서 파싱. Enum converter로 중앙화 권장. | Medium | S | OPEN |
| A-4 | `backend/src/main/kotlin/com/budgetbook/` | **toResponse() 일관성 없음**: 일부 서비스는 entity에서 직접 변환, 일부는 DTO mapper 사용. 표준 패턴 통일 필요. | Medium | S | OPEN |
| A-5 | `backend/src/main/kotlin/com/budgetbook/category/service/CategoryGroupService.kt` | **Dead Code**: 사용되지 않는 메서드 다수 존재. 제거 또는 문서화 필요. | Low | S | OPEN |
| A-6 | `backend/src/main/kotlin/com/budgetbook/transaction/service/RecurringTransactionService.kt` | **반복거래 frequency 변경 불가**: 현재 구현상 frequency(DAILY/WEEKLY/MONTHLY/YEARLY) 수정 API 없음. | Low | M | OPEN |
| A-7 | `backend/src/main/kotlin/com/budgetbook/transaction/scheduler/RecurringTransactionScheduler.kt` | **스케줄러 트랜잭션 격리**: 스케줄러 실행 중 일부 거래 생성 실패 시 나머지에 영향. 개별 거래별 `REQUIRES_NEW` 독립 트랜잭션 필요. | Medium | M | OPEN |

### 4.2 Frontend

| # | 위치 | 설명 | 심각도 | 난이도 | 상태 |
|:--|:-----|:-----|:-------|:-------|:-----|
| A-8 | `frontend/lib/features/` | **state.extra 웹 새로고침 유실**: GoRouter `extra`로 전달된 상태가 웹 새로고침 시 유실. 현재 거래 복사 1곳만 사용 — 저위험이나 URL 파라미터 전환 권장. | Warning | M | LOW RISK (1곳만 사용) |
| A-9 | `frontend/lib/core/di/injection.dart` | ~~AuthBloc LazySingleton close() 미호출~~ | Critical | S | ✅ FIXED - dispose 콜백 등록 완료 |
| A-10 | `frontend/lib/features/transaction/presentation/pages/transaction_form_page.dart` | **BlocListener 로직 결함**: 성공/실패 분기 처리 누락 또는 중복 이벤트 처리 가능성. | Warning | S | OPEN |
| A-11 | `frontend/lib/features/` | **UseCase 클래스 없음**: Repository를 BLoC에서 직접 호출. Clean Architecture 계층 위반. UseCase 레이어 도입 권장. | Warning | L | OPEN |
| A-12 | `frontend/lib/features/report/presentation/pages/report_page.dart` | **week=1 고정**: 리포트 페이지에서 주차 파라미터가 1로 하드코딩. 실제 현재 주차 계산 필요. | Warning | S | OPEN |
| A-13 | `frontend/lib/` | **매직 넘버**: 여러 파일에 의미 없는 숫자 상수 직접 사용. `constants/`로 추출 필요. | Suggestion | S | OPEN |
| A-14 | `frontend/lib/features/` | **BLoC 상태 패턴 불일치**: 일부 BLoC은 `status` enum, 일부는 `isLoading bool` 사용. 표준화 필요. | Suggestion | M | OPEN |
| A-22 | `frontend/lib/core/router/app_router.dart` | **라우트별 BlocProvider 공급 비일관**: 공통 위젯이 내부적으로 `BlocBuilder<T>`를 쓸 때 일부 라우트에서만 Provider가 공급됨. 2026-04-25 Step 6 회귀(TotalAssetMiniCard의 BlocBuilder<PaymentMethodBloc>이 /transactions 라우트에서 Provider 미공급으로 렌더 실패) 발생. 공용 위젯의 의존 Bloc 목록을 문서화하고 각 라우트 MultiBlocProvider에 일괄 공급하는 base set 도입 검토. | Critical | M | OPEN |

### 4.3 App (모바일/웹 통합)

| # | 위치 | 설명 | 심각도 | 난이도 |
|:--|:-----|:-----|:-------|:-------|
| A-15 | `frontend/` | **android/ios 디렉토리 없음**: 모바일 빌드 불가. `flutter create --platforms=android,ios` 실행 필요. | Critical | M |
| A-16 | `frontend/lib/core/auth/` | **OAuth 모바일 콜백 딥링크 미구현**: 모바일 환경에서 OAuth 콜백 처리용 딥링크 scheme 미등록. `flutter_appauth` 또는 custom scheme 구현 필요. | Critical | L |
| A-17 | `frontend/lib/` | **오프라인 지원 없음**: 로컬 DB(sqflite/Hive) 없음. 네트워크 단절 시 앱 기능 전혀 불가. | Warning | XL |
| A-18 | `frontend/lib/` | **SafeArea 누락**: 일부 화면에서 `SafeArea` 미사용. 노치/펀치홀 기기 레이아웃 깨짐 가능. | Warning | S |
| A-19 | `frontend/lib/` | **LayoutBuilder 미사용**: 반응형 레이아웃 미구현. 태블릿/데스크톱 레이아웃 고려 없음. | Suggestion | L |
| A-20 | `frontend/lib/core/di/` | **BLoC 인스턴스 매번 재생성**: 일부 BLoC이 `BlocProvider.value` 없이 위젯 트리 재빌드 시마다 재생성. | Suggestion | S |
| A-21 | `frontend/pubspec.yaml` | **google_fonts 런타임 다운로드**: 앱 첫 실행 시 폰트 네트워크 다운로드. 번들 포함 또는 시스템 폰트 대체 권장. | Suggestion | S |

---

## 5. 기능 개선 및 추가 필요

### 5.1 UX 개선 현황

| # | 설명 | 담당 | 상태 |
|:--|:-----|:-----|:-----|
| U-1 | ~~대시보드 부재~~ | FE | ✅ FIXED - 6위젯 커스터마이징 대시보드 구현 완료 |
| U-2 | ~~BottomNavigationBar 없음~~ | FE | ✅ FIXED - 5탭 구조 (홈/거래/예산/통계/설정) |
| U-3 | ~~설정 페이지 없음~~ | FE | ✅ FIXED - 프로필, 커플 관리, 테마, 언어 구현 |
| U-4 | **프로필 편집 불가**: 닉네임, 프로필 이미지 변경 API 없음. BE `PATCH /api/users/me` 추가 필요. | BE+FE | OPEN |

### 5.2 기능 완성도

| # | 설명 | 담당 | 난이도 |
|:--|:-----|:-----|:-------|
| U-5 | **거래 검색/필터 미흡**: 현재 월별 필터만 존재. 카테고리별, 결제수단별, 금액 범위, 키워드 검색 필요. | BE+FE | M |
| U-6 | **데이터 내보내기 없음**: CSV/Excel export 기능 미구현. | BE+FE | M |
| U-7 | **반복거래 frequency 변경 불가**: 생성 후 주기 변경 불가. `PATCH /api/recurring-transactions/{id}` 개선 필요. | BE | S |
| U-8 | **다국어(i18n) 미완성**: `AppLocalizations` 호출 0회, 전체 UI 한국어 하드코딩. ARB 파일 적용 필요. | FE | L |
| U-9 | **잔액 수정 시 수입/지출 포함 옵션 부재**: 결제수단 잔액 조정 시 수입/지출로 반영할지, 순수 잔액 보정(영향 없음)으로 할지 선택 UI 없음. 현재 모두 수입/지출 거래로 기록되거나 모두 조정으로 기록되는 문제. Phase 25 Step 4 "balance_adjustment_sheet" 확장 또는 ADJUSTMENT 카테고리 선택 UX 개선 필요. | FE | M |

### 5.3 기능 간 연동 강화

| # | 미연동 기능 쌍 | 설명 | 담당 | 난이도 |
|:--|:-------------|:-----|:-----|:-------|
| I-1 | 반복거래 → 예산 | 반복거래 생성 시 해당 카테고리 예산에 자동 반영 없음 | BE | M |
| I-2 | 카테고리그룹 ↔ 예산 | 카테고리그룹 단위 예산 설정/조회 미연동 | BE | M |
| I-3 | 주간예산 ↔ 리포트 | 주간 예산 실적이 월간 리포트에 미반영 | BE | S |
| I-4 | 결제수단 필터 | 결제수단별 거래 필터링 API 미구현 | BE | S |
| I-5 | 통계 ↔ 결제수단 | 결제수단별 통계 분석 없음 | BE | M |
| I-6 | 리포트 ↔ 알림 | 예산 초과 리포트 기반 알림 트리거 없음 | BE | M |

---

## 6. 코드 품질 / 리팩토링

### 6.1 Backend 리팩토링

| # | 위치 | 설명 | 심각도 | 난이도 |
|:--|:-----|:-----|:-------|:-------|
| R-1 | `backend/src/main/kotlin/com/budgetbook/auth/service/CustomOidcUserService.kt` | 테스트 없음. Google 로그인 핵심 경로임에도 테스트 커버리지 0%. | Medium | S |
| R-2 | `backend/src/main/kotlin/com/budgetbook/budget/service/WeeklyBudgetService.kt` | 테스트 부족. 주간 예산 계산 로직 엣지케이스 미검증. | Medium | S |
| R-3 | 여러 Repository 파일 | `List<Array<Any>>` 반환 타입 사용. 타입 안전 DTO Projection으로 교체 권장. | Low | S |
| R-4 | `backend/src/main/kotlin/com/budgetbook/` | Unused import 다수. IDE 정리 or lint 규칙 추가 필요. | Low | S |
| R-5 | `backend/src/main/kotlin/com/budgetbook/transaction/` | `@EnableScheduling` 위치 확인: 프로덕션 환경에서만 활성화되는지 검증 필요. | Low | S |

### 6.2 Frontend 리팩토링

| # | 위치 | 설명 | 심각도 | 난이도 |
|:--|:-----|:-----|:-------|:-------|
| R-6 | `frontend/lib/features/` | **DioException만 catch**: 네트워크 에러만 처리하고 파싱 오류, 상태 이상 등 미처리. 에러 핸들링 범위 확대 필요. | Warning | S |
| R-7 | `frontend/lib/` | **에러 핸들링 UX**: 에러 발생 시 사용자 친화적 메시지 없음. `SnackBar` 또는 `ErrorWidget` 표준화 필요. | Warning | M |
| R-8 | `frontend/lib/features/settings/` | **깨진 디렉토리명**: `settings/{presentation/pages}` 구조 불일치. 정리 필요. | Warning | S |
| R-9 | `frontend/lib/` | **접근성(a11y) 미고려**: `Semantics` 위젯, 스크린리더 지원, 충분한 터치 타겟 크기 없음. | Suggestion | L |
| R-10 | `frontend/lib/` | **위젯 테스트 GAP**: 주요 화면 위젯 테스트 없음. `TransactionFormPage`, `StatisticsPage`, `ReportPage` 최소 골든 테스트 추가 권장. | Suggestion | M |

---

## 7. 인프라 / DevOps 개선

### 7.1 CI/CD 최적화

| # | 위치 | 설명 | 심각도 | 난이도 |
|:--|:-----|:-----|:-------|:-------|
| D-1 | `.github/workflows/ci.yml` | **CI 중복 실행**: build + test가 별도 job으로 실행되어 동일 코드 2회 컴파일. `./gradlew build`에 테스트 포함으로 통합 권장. | Medium | S |
| D-2 | `.github/workflows/` | **Flutter 버전 미고정**: `flutter-version` 미지정 시 latest 사용으로 버전 드리프트 위험. `3.x` 명시 권장. | Medium | S |
| D-3 | `.github/workflows/` | **feature/* 브랜치 CI 없음**: PR 생성 전 feature 브랜치에서 CI 미실행. `push: branches: ['feature/**']` 추가 필요. | Medium | S |
| D-4 | `.github/workflows/` | **의존성 취약점 스캔 없음**: `dependabot` 또는 OWASP dependency-check 미설정. | Medium | M |
| D-5 | `.github/workflows/` | **코드 커버리지 리포트 없음**: Kover (Kotlin) + lcov (Flutter) 연동하여 PR마다 커버리지 델타 확인 필요. | Suggestion | M |
| D-6 | `.github/workflows/` | **모바일 빌드 CI 없음**: android/ios 빌드 검증 CI 없음 (현재 모바일 플랫폼 파일 자체 없음). | Low | L |

### 7.2 배포 전략

| # | 설명 | 심각도 | 난이도 | 상태 |
|:--|:-----|:-------|:-------|:-----|
| D-7 | ~~Render free tier cold start~~ | High | S | ✅ RESOLVED - NAS Docker 이전 완료 (콜드스타트 없음) |
| D-8 | **롤백 전략 없음**: 배포 실패 시 이전 버전 복원 방법 없음. git tag 기반 롤백 스크립트 필요. | High | M | OPEN |
| D-9 | **Staging 환경 없음**: 프로덕션 직접 배포. `develop` 브랜치 → staging 자동 배포 환경 구성 권장. | Medium | L | OPEN |
| D-10 | **DB 복구 테스트 없음**: NAS PostgreSQL 백업에 의존하나 복구 절차(runbook) 없음. 분기별 복구 테스트 필요. | Medium | M | OPEN |

### 7.3 모니터링/로깅

| # | 설명 | 심각도 | 난이도 |
|:--|:-----|:-------|:-------|
| D-11 | **구조화 로깅 없음**: `logback` 기본 설정. JSON 구조화 로깅 + correlation ID 도입 권장. | Medium | S |
| D-12 | **에러 모니터링 없음**: Sentry (또는 Datadog) 미연동. 프로덕션 에러 실시간 감지 불가. | High | S |
| D-13 | **성능 메트릭 없음**: Spring Actuator Prometheus endpoint 미노출 + Grafana 대시보드 없음. | Medium | M |
| D-14 | `backend/src/main/resources/application.yml` | **profiles.active 환경 변수화**: 환경 변수로 분리 권장. | Medium | S |

---

## 8. 문서 정비

| # | 설명 | 파일 | 심각도 | 담당 |
|:--|:-----|:-----|:-------|:-----|
| Doc-1 | **ERD 최신화 필요**: `docs/erd.md`에 V11~V41 마이그레이션으로 추가된 테이블 및 컬럼 반영 필요. (지출 계획, 위시리스트, 보험, WebSocket 관련 테이블 등) | `docs/erd.md` | Critical | Contract |
| Doc-2 | **다국어 전략 문서 없음**: i18n 접근 방식, ARB 파일 관리 방법, 번역 워크플로우 미문서화. | `docs/` | Low | Contract |
| Doc-3 | **모바일 빌드 가이드 없음**: android/ios 플랫폼 추가 후 빌드/배포 절차 문서 필요. | `docs/` | Low | Contract |
| Doc-4 | **API 에러 코드 목록 없음**: `docs/api-spec.md`에 비즈니스 에러 코드 전체 목록 미포함. | `docs/api-spec.md` | Medium | Contract |

---

## 9. 기술 부채 목록 (우선순위 정렬)

| # | 카테고리 | 심각도 | 설명 | 담당 | 난이도 |
|:--|:--------|:-------|:-----|:-----|:-------|
| 1 | 보안 | Critical | 초대코드 Rate Limiting 부분 적용 (로그인/생성 엔드포인트 미적용) | BE | S |
| 2 | 모바일 | Critical | android/ios 디렉토리 없음 (모바일 빌드 불가) | App | M |
| 3 | 모바일 | Critical | OAuth 모바일 딥링크 콜백 미구현 | App | L |
| 4 | UX | Warning | state.extra 웹 새로고침 유실 (1곳 - 거래 복사) | FE | M |
| 5 | 성능 | Medium | ReportService 쿼리 중복 (sumByCategoryForCouple 중복 호출) | BE | S |
| 6 | 성능 | Medium | getActiveCouple() 22개 서비스 83곳 중복 | BE | S |
| 7 | 안정성 | Medium | 스케줄러 트랜잭션 격리 미비 (REQUIRES_NEW 필요) | BE | M |
| 8 | 문서 | Critical | ERD V11-V41 테이블 누락 | Contract | S |
| 9 | 모니터링 | High | Sentry 에러 모니터링 없음 | DevOps | S |
| 10 | 배포 | High | 롤백 전략 없음 | DevOps | M |
| 11 | 기능 | Medium | 거래 검색/필터 미흡 | BE+FE | M |
| 12 | 아키텍처 | Medium | UseCase 레이어 없음 | FE | L |
| 13 | 아키텍처 | Medium | BLoC 상태 패턴 불일치 | FE | M |
| 14 | 테스트 | Medium | CustomOidcUserService 테스트 없음 | BE | S |
| 15 | 테스트 | Medium | Flutter 위젯 테스트 GAP | FE | M |
| 16 | 기능 | Medium | 데이터 내보내기 없음 | BE+FE | M |
| 17 | 기능 | Medium | 다국어(i18n) 미완성 | FE | L |
| 18 | 인프라 | Medium | CI 중복 실행 | DevOps | S |
| 19 | 인프라 | Medium | feature/* 브랜치 CI 없음 | DevOps | S |
| 20 | 기능 | Medium | 기능 간 연동 부족 (6건) | BE | M-L |
| 21 | 기능 | Medium | 프로필 편집 불가 (닉네임/이미지 변경) | BE+FE | M |
| 22 | 아키텍처 | Warning | report page week=1 하드코딩 | FE | S |

---

## 10. 액션 아이템 로드맵

### 피드백 게시판 (설계 완료, 우선 구현 대상)

> 설계서: `docs/sessions/2026-03-29_3_plan.md`

- [ ] **[Contract]** 피드백 게시판 API 명세 작성 (`docs/api-spec.md` 업데이트)
- [ ] **[BE]** 피드백/공지 CRUD + 카테고리 + 좋아요 구현
- [ ] **[FE]** 피드백 목록/상세/작성 화면 구현

### Phase 4: AI / Push (신규 기능)

> 목표: 차별화 기능으로 앱 가치 증대

- [ ] **[Contract]** AI Classification API 명세 작성 (Claude API 연동)
- [ ] **[BE]** 거래 자동 분류: Claude API 호출 서비스 (`backend/.../ai/`)
- [ ] **[BE]** Claude Reports: 월별 소비 패턴 AI 분석 리포트 생성
- [ ] **[BE]** Push Notifications: 예산 초과 감지 → FCM 발송
- [ ] **[FE]** AI 분류 제안 화면, AI 리포트 화면
- [ ] **[App]** Firebase 초기화 + FCM 토큰 등록 + 알림 수신 처리

### 보안 강화

- [ ] **[BE/Critical]** Rate Limiting 확장: 로그인/계정 생성 엔드포인트 추가 적용

### 품질 개선 (병행)

**아키텍처**
- [ ] **[FE/Medium]** UseCase 레이어 도입 (Repository → UseCase → BLoC)
- [ ] **[BE/Medium]** getActiveCouple() RequestScope 캐싱 도입
- [ ] **[BE/Medium]** ReportService 중복 쿼리 통합
- [ ] **[BE/Medium]** 스케줄러 REQUIRES_NEW 트랜잭션 격리 적용
- [ ] **[FE/Medium]** BLoC 상태 패턴 통일 (status enum 표준화)
- [ ] **[FE/Warning]** report week=1 하드코딩 → 실제 현재 주차 계산

**모바일**
- [ ] **[App/Critical]** android/ios 플랫폼 추가 + 기본 설정
- [ ] **[App/Critical]** OAuth 딥링크 콜백 구현
- [ ] **[App/Warning]** SafeArea 전체 화면 적용

**DevOps**
- [ ] **[DevOps/High]** Sentry 에러 모니터링 연동 (BE + FE)
- [ ] **[DevOps/High]** 롤백 전략 수립 (git tag 기반 스크립트)
- [ ] **[DevOps/Medium]** 구조화 로깅 (JSON + correlation ID)
- [ ] **[DevOps/Medium]** 코드 커버리지 리포트 (Kover + lcov) CI 연동

**테스트**
- [ ] **[BE/Medium]** CustomOidcUserService 테스트 추가
- [ ] **[BE/Medium]** WeeklyBudgetService 테스트 강화
- [ ] **[FE/Medium]** 핵심 화면 위젯 테스트 추가 (TransactionFormPage 등)

**기능**
- [ ] **[BE+FE/Medium]** 데이터 내보내기 (CSV/Excel)
- [ ] **[BE+FE/Medium]** 거래 검색/필터 강화 (카테고리, 결제수단, 금액 범위, 키워드)
- [ ] **[Contract/Critical]** `docs/erd.md` V11-V41 테이블 업데이트
