# Budget Book - Project Audit Report

> 작성일: 2026-03-12
> 목적: 프로젝트 전후 비교 분석 → 개선/추가/리팩토링 필요사항 정리
> 활용: 추후 개발 요청 시 참고 문서

---

## 1. 프로젝트 현황 요약

### 1.1 구현 완료 기능 (Phase 1-3)

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

### 1.2 테스트 현황

| 영역 | 수량 | 비고 |
|:-----|:-----|:-----|
| Backend (Kotest) | 239+ | BehaviorSpec/FunSpec |
| Frontend (Flutter) | 228+ | BLoC 단위 테스트 중심 |
| 통합 테스트 | 일부 | `@SpringBootTest` |
| 위젯 테스트 | 부족 | FE 위젯 테스트 GAP 존재 |

**알려진 테스트 공백:**
- `CustomOidcUserService` 테스트 없음 (`backend/src/main/kotlin/com/budgetbook/auth/service/CustomOidcUserService.kt`)
- `WeeklyBudgetService` 커버리지 부족 (`backend/src/main/kotlin/com/budgetbook/budget/service/WeeklyBudgetService.kt`)
- Flutter 위젯 테스트: 주요 화면(TransactionFormPage, StatisticsPage 등) 테스트 없음

### 1.3 배포 상태

| 구성요소 | 플랫폼 | URL | 상태 |
|:--------|:-------|:----|:-----|
| Backend API | Render (free tier) | https://budget-book-api.onrender.com | Live |
| Frontend Web | GitHub Pages | https://aiva-saas.github.io/budget-book/ | Live |
| Database | Supabase PostgreSQL | Session Pooler (IPv4) | Live |
| CI/CD | GitHub Actions | 4개 워크플로우 | 동작 중 |

- Flyway 마이그레이션: V1~V10 전체 적용 완료
- 자동 배포: `main` 머지 시 Render(BE) + GitHub Pages(FE) 자동 배포

### 1.4 미구현 계획 (Phase 2c, Phase 4)

| 항목 | 설명 | 우선순위 |
|:-----|:-----|:--------|
| Phase 2c | WebSocket 실시간 동기화 (STOMP) | High |
| Phase 2c | Redis 캐싱/세션 관리 | High |
| Phase 4 | Money Pockets (목적별 저금통) | Medium |
| Phase 4 | AI 거래 자동 분류 (Claude API) | Medium |
| Phase 4 | Claude Reports (AI 소비 인사이트) | Medium |
| Phase 4 | Push Notifications (예산 초과 알림) | Medium |

---

## 2. 보안 취약점 (Critical/High)

### Critical

| # | 위치 | 설명 | 담당 |
|:--|:-----|:-----|:-----|
| S-1 | `backend/src/main/kotlin/com/budgetbook/auth/service/` | **OAuth2 Account Linking 취약점**: 신규 로그인 시 이메일 기반 자동 계정 연결. 악의적 제3자가 동일 이메일로 다른 Provider로 가입 시 계정 탈취 가능. `CustomOAuth2UserService`, `CustomOidcUserService` 모두 해당. | BE |
| S-2 | `backend/src/main/kotlin/com/budgetbook/couple/service/CoupleService.kt` | **초대코드 Brute-force 공격**: 8자리 영숫자 코드에 Rate Limiting 없음. 짧은 시간 내 무차별 시도로 유효 코드 추측 가능. | BE |
| S-3 | `backend/src/main/kotlin/com/budgetbook/auth/` | **JWT 검증 시 매 요청 DB 조회**: Access Token 검증마다 DB hit 발생. Redis 도입 전까지 성능/보안 양쪽에서 취약. | BE |

### High

| # | 위치 | 설명 | 담당 |
|:--|:-----|:-----|:-----|
| S-4 | `backend/src/main/resources/application.yml` | **health show-details: always**: Actuator health 엔드포인트가 DB 연결 정보 등 민감 정보를 프로덕션 환경에 노출. | DevOps |
| S-5 | `.github/workflows/deploy-init.yml` | **JWT Secret 하드코딩**: 워크플로우 파일에 JWT secret 값이 하드코딩. GitHub Secrets로 이동 필요. | DevOps |
| S-6 | `frontend/lib/core/network/auth_interceptor.dart` | **토큰 갱신 실패 미처리**: `AuthInterceptor`에서 토큰 갱신 실패 시 사용자에게 미통보. 자격증명 만료 후 앱이 무한 대기 상태 진입 가능. | FE |

---

## 3. 성능 이슈

### Critical / High

| # | 위치 | 설명 | 심각도 | 담당 |
|:--|:-----|:-----|:-------|:-----|
| P-1 | `backend/src/main/kotlin/com/budgetbook/budget/service/WeeklyBudgetService.kt` | **N+1 쿼리**: 주간 예산 스냅샷 조회 시 각 그룹별 개별 쿼리 발생. `@EntityGraph` 또는 fetch join 도입 필요. | High | BE |
| P-2 | 여러 Repository (5건) | **Pageable.unpaged() OOM 위험**: 전체 데이터를 페이지 없이 로드하는 쿼리 5건 존재. 데이터 증가 시 OOM 발생. 명시적 `LIMIT` 또는 커서 기반 페이지네이션 필요. | High | BE |
| P-3 | `backend/src/main/kotlin/com/budgetbook/report/service/ReportService.kt` | **ReportService 쿼리 중복**: 동일 월 데이터를 여러 메서드에서 반복 조회. 캐싱 또는 단일 쿼리로 통합 필요. | Medium | BE |
| P-4 | `frontend/lib/features/statistics/presentation/bloc/statistics_bloc.dart` | **StatisticsBloc 순차 API 호출**: 통계 화면에서 3개 API를 순차 호출. `Future.wait()` 병렬화로 응답시간 단축 가능. | Medium | FE |
| P-5 | `backend/src/main/kotlin/com/budgetbook/` (9개 서비스) | **getActiveCouple() 중복 호출**: 9개 서비스에서 동일한 커플 조회 로직 반복. 요청당 불필요한 DB 쿼리 증가. | Medium | BE |

---

## 4. 아키텍처 개선

### 4.1 Backend

| # | 위치 | 설명 | 심각도 | 난이도 |
|:--|:-----|:-----|:-------|:-------|
| A-1 | `backend/src/main/kotlin/com/budgetbook/couple/service/CoupleService.kt` | **커플 해산 시 연관 데이터 미처리**: 커플 해산 후 카테고리/거래/예산 데이터 처리 정책 없음. 고아 데이터 발생 가능. | High | M |
| A-2 | `backend/src/main/kotlin/com/budgetbook/` | **getActiveCouple() 공통화 필요**: 9개 서비스에 중복된 `getActiveCouple()` 패턴. `CoupleResolver` 또는 AOP로 추출 권장. | Medium | S |
| A-3 | `backend/src/main/kotlin/com/budgetbook/transaction/` | **TransactionType 문자열 파싱 중복**: `INCOME`/`EXPENSE` 문자열을 여러 곳에서 파싱. Enum converter로 중앙화 권장. | Medium | S |
| A-4 | `backend/src/main/kotlin/com/budgetbook/` | **toResponse() 일관성 없음**: 일부 서비스는 entity에서 직접 변환, 일부는 DTO mapper 사용. 표준 패턴 통일 필요. | Medium | S |
| A-5 | `backend/src/main/kotlin/com/budgetbook/category/service/CategoryGroupService.kt` | **Dead Code**: 사용되지 않는 메서드 다수 존재. 제거 또는 문서화 필요. | Low | S |
| A-6 | `backend/src/main/kotlin/com/budgetbook/transaction/service/RecurringTransactionService.kt` | **반복거래 frequency 변경 불가**: 현재 구현상 frequency(DAILY/WEEKLY/MONTHLY/YEARLY) 수정 API 없음. | Low | M |
| A-7 | `backend/src/main/kotlin/com/budgetbook/transaction/scheduler/RecurringTransactionScheduler.kt` | **스케줄러 트랜잭션 격리**: 스케줄러 실행 중 일부 거래 생성 실패 시 나머지에 영향 줄 수 있음. 개별 거래별 독립 트랜잭션 필요. | Medium | M |

### 4.2 Frontend

| # | 위치 | 설명 | 심각도 | 난이도 |
|:--|:-----|:-----|:-------|:-------|
| A-8 | `frontend/lib/features/` (4곳) | **state.extra 웹 새로고침 유실**: GoRouter `extra`로 전달된 상태가 웹 새로고침 시 유실. URL 파라미터 또는 BLoC 상태로 이전 필요. `transaction_detail_page.dart`, `transaction_form_page.dart` 등 4곳. | Critical | M |
| A-9 | `frontend/lib/core/di/injection.dart` | **AuthBloc LazySingleton close() 미호출**: AuthBloc이 LazySingleton으로 등록되었으나 앱 종료 시 `close()` 미호출. 리소스 누수. | Critical | S |
| A-10 | `frontend/lib/features/transaction/presentation/pages/transaction_form_page.dart` | **BlocListener 로직 결함**: 성공/실패 분기 처리 누락 또는 중복 이벤트 처리 가능성. | Warning | S |
| A-11 | `frontend/lib/features/` | **UseCase 클래스 없음**: Repository를 BLoC에서 직접 호출. Clean Architecture 계층 위반. UseCase 레이어 도입 권장. | Warning | L |
| A-12 | `frontend/lib/features/report/presentation/pages/report_page.dart` | **week=1 고정**: 리포트 페이지에서 주차 파라미터가 1로 하드코딩. 실제 현재 주차 계산 필요. | Warning | S |
| A-13 | `frontend/lib/` | **매직 넘버**: 여러 파일에 의미 없는 숫자 상수 직접 사용. `constants/` 로 추출 필요. | Suggestion | S |
| A-14 | `frontend/lib/features/` | **BLoC 상태 패턴 불일치**: 일부 BLoC은 `status` enum, 일부는 `isLoading bool` 사용. 표준화 필요. | Suggestion | M |

### 4.3 App (모바일/웹 통합)

| # | 위치 | 설명 | 심각도 | 난이도 |
|:--|:-----|:-----|:-------|:-------|
| A-15 | `frontend/` | **android/ios 디렉토리 없음**: 모바일 빌드 불가. `flutter create --platforms=android,ios` 실행 필요. | Critical | M |
| A-16 | `frontend/lib/core/auth/` | **OAuth 모바일 콜백 딥링크 미구현**: 모바일 환경에서 OAuth 콜백 처리용 딥링크 scheme 미등록. `flutter_appauth` 또는 custom scheme 구현 필요. | Critical | L |
| A-17 | `frontend/lib/` | **오프라인 지원 없음**: 로컬 DB(sqflite/Hive) 없음. 네트워크 단절 시 앱 기능 전혀 불가. | Warning | XL |
| A-18 | `frontend/lib/` | **SafeArea 누락**: `LoginPage` 외 대부분의 화면에서 `SafeArea` 미사용. 노치/펀치홀 기기 레이아웃 깨짐. | Warning | S |
| A-19 | `frontend/lib/` | **LayoutBuilder 미사용**: 반응형 레이아웃 미구현. 태블릿/데스크톱 레이아웃 고려 없음. | Suggestion | L |
| A-20 | `frontend/lib/core/di/` | **BLoC 인스턴스 매번 재생성**: 일부 BLoC이 `BlocProvider.value` 없이 위젯 트리 재빌드 시마다 재생성. | Suggestion | S |
| A-21 | `frontend/pubspec.yaml` | **google_fonts 런타임 다운로드**: 앱 첫 실행 시 폰트 네트워크 다운로드. 번들 포함 또는 시스템 폰트 대체 권장. | Suggestion | S |

---

## 5. 기능 개선 및 추가 필요

### 5.1 UX 필수 개선 (Critical 수준)

| # | 설명 | 담당 | 난이도 |
|:--|:-----|:-----|:-------|
| U-1 | **대시보드 부재**: 앱 진입 시 보여줄 홈 화면 없음. 월 요약, 최근 거래, 예산 현황을 한눈에 볼 수 있는 대시보드 필요. `frontend/lib/features/home/` 현재 미사용. | FE | L |
| U-2 | **BottomNavigationBar 없음**: 주요 기능 간 이동 방법 없음. 홈/거래/예산/통계/설정 탭 구조 필요. | FE | M |
| U-3 | **설정 페이지 없음**: `frontend/lib/features/settings/` 디렉토리 구조만 존재, 구현 없음. 프로필 편집, 커플 관리, 앱 설정 등 필요. | FE | L |
| U-4 | **프로필 편집 불가**: 닉네임, 프로필 이미지 변경 API 없음. BE `PATCH /api/users/me` 추가 필요. | BE+FE | M |

### 5.2 기능 완성도

| # | 설명 | 담당 | 난이도 |
|:--|:-----|:-----|:-------|
| U-5 | **거래 검색/필터 미흡**: 현재 월별 필터만 존재. 카테고리별, 결제수단별, 금액 범위, 키워드 검색 필요. `GET /api/transactions` 파라미터 확장 필요. | BE+FE | M |
| U-6 | **데이터 내보내기 없음**: CSV/Excel export 기능 미구현. `backend/src/main/kotlin/com/budgetbook/export/` 패키지 존재하나 미구현. | BE+FE | M |
| U-7 | **반복거래 frequency 변경 불가**: 생성 후 주기 변경 불가. `PATCH /api/recurring-transactions/{id}` 개선 필요. (`backend/.../RecurringTransactionService.kt`) | BE | S |
| U-8 | **다국어(i18n) 미완성**: `AppLocalizations` 호출 0회, 전체 UI 한국어 하드코딩. 영어 지원을 위한 ARB 파일 적용 필요. `frontend/lib/l10n/` | FE | L |

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

| # | 설명 | 심각도 | 난이도 |
|:--|:-----|:-------|:-------|
| D-7 | **Render free tier cold start**: 비활성 후 첫 요청 30~60초 지연. 유료 플랜 업그레이드 또는 keep-alive ping 설정 필요. | High | S |
| D-8 | **롤백 전략 없음**: 배포 실패 시 이전 버전 복원 방법 없음. Render deploy hook + git tag 기반 롤백 스크립트 필요. | High | M |
| D-9 | **Staging 환경 없음**: 프로덕션 직접 배포. `develop` 브랜치 → staging 자동 배포 환경 구성 권장. | Medium | L |
| D-10 | **DB 복구 테스트 없음**: Supabase 7일 자동 백업에 의존하나 복구 절차(runbook) 없음. 분기별 복구 테스트 필요. | Medium | M |

### 7.3 모니터링/로깅

| # | 설명 | 심각도 | 난이도 |
|:--|:-----|:-------|:-------|
| D-11 | **구조화 로깅 없음**: `logback` 기본 설정. JSON 구조화 로깅 + correlation ID 도입 권장. | Medium | S |
| D-12 | **에러 모니터링 없음**: Sentry (또는 Datadog) 미연동. 프로덕션 에러 실시간 감지 불가. | High | S |
| D-13 | **성능 메트릭 없음**: Spring Actuator Prometheus endpoint 미노출 + Grafana 대시보드 없음. | Medium | M |
| D-14 | `backend/src/main/resources/application.yml` | **profiles.active: local 하드코딩**: 환경 변수 또는 Render 환경 설정으로 분리 필요. | Medium | S |

---

## 8. 문서 정비

| # | 설명 | 파일 | 심각도 | 담당 |
|:--|:-----|:-----|:-------|:-----|
| Doc-1 | **ERD Phase 3 테이블 누락**: `docs/erd.md`에 V7~V10 마이그레이션으로 추가된 테이블(`category_groups`, `payment_methods`, `weekly_budget_snapshots`, `recurring_transactions`) 및 `categories.group_id`, `transactions.payment_method_id` 컬럼 누락. | `docs/erd.md` | Critical | Contract |
| Doc-2 | **다국어 전략 문서 없음**: i18n 접근 방식, ARB 파일 관리 방법, 번역 워크플로우 미문서화. | `docs/` | Low | Contract |
| Doc-3 | **모바일 빌드 가이드 없음**: android/ios 플랫폼 추가 후 빌드/배포 절차 문서 필요. | `docs/` | Low | Contract |
| Doc-4 | **API 에러 코드 목록 없음**: `docs/api-spec.md`에 비즈니스 에러 코드 전체 목록 미포함. | `docs/api-spec.md` | Medium | Contract |

---

## 9. 기술 부채 목록 (우선순위 정렬)

| # | 카테고리 | 심각도 | 설명 | 담당 | 난이도 |
|:--|:--------|:-------|:-----|:-----|:-------|
| 1 | 보안 | Critical | OAuth2 이메일 기반 계정 자동 연결 취약점 | BE | M |
| 2 | 보안 | Critical | 초대코드 Rate Limiting 없음 | BE | S |
| 3 | 모바일 | Critical | android/ios 디렉토리 없음 (모바일 빌드 불가) | App | M |
| 4 | 모바일 | Critical | OAuth 모바일 딥링크 콜백 미구현 | App | L |
| 5 | UX | Critical | state.extra 웹 새로고침 유실 (4곳) | FE | M |
| 6 | UX | Critical | 대시보드 화면 없음 | FE | L |
| 7 | UX | Critical | BottomNavigationBar 없음 | FE | M |
| 8 | 보안 | High | JWT 검증 매 요청 DB 조회 | BE | M |
| 9 | 보안 | High | Actuator health show-details: always | DevOps | S |
| 10 | 보안 | High | AuthInterceptor 토큰 갱신 실패 미통보 | FE | S |
| 11 | 성능 | High | WeeklyBudgetService N+1 쿼리 | BE | S |
| 12 | 성능 | High | Pageable.unpaged() OOM 위험 (5건) | BE | M |
| 13 | 안정성 | High | 커플 해산 시 연관 데이터 미처리 | BE | M |
| 14 | 모니터링 | High | Sentry 에러 모니터링 없음 | DevOps | S |
| 15 | 배포 | High | 롤백 전략 없음 | DevOps | M |
| 16 | 문서 | Critical | ERD Phase 3 테이블 누락 (V7-V10) | Contract | S |
| 17 | 기능 | High | 설정 페이지 없음 | FE | L |
| 18 | 기능 | High | 거래 검색/필터 미흡 | BE+FE | M |
| 19 | 성능 | Medium | ReportService 쿼리 중복 | BE | S |
| 20 | 성능 | Medium | StatisticsBloc 순차 API 호출 | FE | S |
| 21 | 아키텍처 | Medium | getActiveCouple() 9개 서비스 중복 | BE | S |
| 22 | 아키텍처 | Medium | UseCase 레이어 없음 | FE | L |
| 23 | 아키텍처 | Medium | BLoC 상태 패턴 불일치 | FE | M |
| 24 | 테스트 | Medium | CustomOidcUserService 테스트 없음 | BE | S |
| 25 | 테스트 | Medium | Flutter 위젯 테스트 GAP | FE | M |
| 26 | 기능 | Medium | 데이터 내보내기 없음 | BE+FE | M |
| 27 | 기능 | Medium | 다국어(i18n) 미완성 | FE | L |
| 28 | 인프라 | Medium | CI 중복 실행 | DevOps | S |
| 29 | 인프라 | Medium | feature/* 브랜치 CI 없음 | DevOps | S |
| 30 | 기능 | Medium | 기능 간 연동 부족 (6건) | BE | M-L |

---

## 10. 액션 아이템 로드맵

### Phase 0 (즉시): 보안/안정성 긴급 처리

> 목표: 프로덕션 보안 취약점 즉시 패치 + 핵심 안정성 확보

- [ ] **[BE/Critical]** OAuth2 계정 연결 취약점 수정: 이메일 자동 연결 제거 → 명시적 계정 병합 플로우로 교체
- [ ] **[BE/Critical]** 초대코드 Rate Limiting 추가: Redis 또는 in-memory 기반 IP/user 레이트 리미터
- [ ] **[DevOps/High]** Actuator health `show-details: when_authorized`로 변경
- [ ] **[DevOps/High]** deploy-init.yml JWT secret을 GitHub Secret으로 이동
- [ ] **[FE/Critical]** AuthInterceptor 토큰 갱신 실패 시 로그아웃 + 사용자 알림
- [ ] **[FE/Critical]** state.extra → BLoC 상태 또는 URL 파라미터로 교체 (4곳)
- [ ] **[BE/High]** 커플 해산 시 데이터 처리 정책 구현 (soft delete 또는 아카이브)
- [ ] **[Contract/Critical]** `docs/erd.md` Phase 3 테이블(V7-V10) 추가

### Phase 2c: WebSocket / Redis (실시간 동기화)

> 목표: 부부 실시간 데이터 동기화 구현

- [ ] **[BE]** Redis (Upstash) 연동: JWT 검증 캐싱, Rate Limiting 스토어
- [ ] **[BE]** WebSocket STOMP 엔드포인트 구현: `/ws`, `/topic/couple/{coupleId}`
- [ ] **[BE]** `SyncEventPublisher`: TRANSACTION_CREATED/UPDATED/DELETED, BUDGET_UPDATED 이벤트
- [ ] **[FE]** WebSocket 클라이언트 연동: BLoC에서 실시간 이벤트 수신 → 자동 UI 갱신
- [ ] **[DevOps]** Redis 연결 설정 Render 환경 변수 등록

### Phase 4: Money Pockets / AI / Push (신규 기능)

> 목표: 차별화 기능으로 앱 가치 증대

- [ ] **[Contract]** Money Pockets API 명세 작성 (`docs/api-spec.md` 업데이트)
- [ ] **[BE]** Money Pockets CRUD + 입출금 관리
- [ ] **[Contract]** AI Classification API 명세 작성 (Claude API 연동)
- [ ] **[BE]** 거래 자동 분류: Claude API 호출 서비스 (`backend/.../ai/`)
- [ ] **[BE]** Claude Reports: 월별 소비 패턴 AI 분석 리포트 생성
- [ ] **[BE]** Push Notifications: 예산 초과 감지 → FCM 발송
- [ ] **[FE]** Money Pockets UI, AI 분류 제안 화면, AI 리포트 화면
- [ ] **[App]** Firebase 초기화 + FCM 토큰 등록 + 알림 수신 처리

### 품질 개선 (병행)

> 개발 사이클 병행 진행 권장

**UX 완성도**
- [ ] **[FE/Critical]** 대시보드 화면 구현 (월 요약 + 최근 거래 + 예산 현황)
- [ ] **[FE/Critical]** BottomNavigationBar 5탭 구조 (홈/거래/예산/통계/설정)
- [ ] **[FE/High]** 설정 페이지 구현 (프로필 편집, 커플 관리, 로그아웃)
- [ ] **[FE/High]** 거래 검색/필터 UI 강화

**아키텍처**
- [ ] **[FE/Medium]** UseCase 레이어 도입 (Repository → UseCase → BLoC)
- [ ] **[BE/Medium]** getActiveCouple() 공통화 (AOP 또는 CoupleResolver)
- [ ] **[BE/Medium]** Pageable.unpaged() → 명시적 LIMIT 쿼리 교체 (5건)
- [ ] **[FE/Medium]** BLoC 상태 패턴 통일 (status enum 표준화)

**모바일**
- [ ] **[App/Critical]** android/ios 플랫폼 추가 + 기본 설정
- [ ] **[App/Critical]** OAuth 딥링크 콜백 구현
- [ ] **[App/Warning]** SafeArea 전체 화면 적용

**DevOps**
- [ ] **[DevOps/High]** Sentry 에러 모니터링 연동 (BE + FE)
- [ ] **[DevOps/Medium]** 구조화 로깅 (JSON + correlation ID)
- [ ] **[DevOps/Medium]** 코드 커버리지 리포트 (Kover + lcov) CI 연동
- [ ] **[DevOps/Medium]** Staging 환경 구성 (develop → staging 자동 배포)

**테스트**
- [ ] **[BE/Medium]** CustomOidcUserService 테스트 추가
- [ ] **[BE/Medium]** WeeklyBudgetService 테스트 강화
- [ ] **[FE/Medium]** 핵심 화면 위젯 테스트 추가 (TransactionFormPage 등)

**기능**
- [ ] **[BE+FE/Medium]** 데이터 내보내기 (CSV/Excel)
- [ ] **[FE/Medium]** 다국어 ARB 파일 적용 (한국어/영어)
- [ ] **[BE/Medium]** 기능 간 연동 강화 (반복거래↔예산, 주간예산↔리포트 등 6건)
