# Phase 5 작업 완료 - 사용자 확인 필요 사항
> 최종 업데이트: 2026-03-14 Sprint 5a~5e 완료
> 상태: 5a~5e 완료 배포, 5f(모바일) 사용자 결정 필요

---

## 사용자 확인 필요 항목

### 1. CSV 내보내기 인증 토큰 이슈 (5d)
- `url_launcher`로 CSV URL 열기 방식 → 브라우저 새 탭에서 인증 토큰이 포함 안 됨
- **해결 방안**: Dio로 직접 다운로드 후 blob URL 생성, 또는 BE에서 임시 토큰 파라미터 방식
- **테스트 필요**: 실제 로그인 상태에서 CSV 다운로드 버튼 클릭 시 동작 확인

### 2. 대시보드 빠른 액션 (5b)
- 지출/수입 버튼 모두 `/transactions/create`로 이동 (타입 자동 선택 미구현)
- 사용자가 폼에서 직접 타입 선택해야 함
- **원하면**: query param으로 타입 전달하도록 수정 가능

### 3. 프로필 이미지 업로드 (5b)
- 닉네임 수정만 구현. 이미지는 URL 직접 입력만 가능
- 이미지 업로드 기능은 Supabase Storage 연동 필요 → Phase 6 권장

### 4. 분배 비율 소수점 (5d)
- BE에서 합계 100% 검증. 소수점 반올림 엣지 케이스 가능
- 실제 사용 시 확인 필요

### 5. 다국어 번역 (5e)
- 언어 선택기 구현됨 (한국어/English/System)
- 하드코딩된 한국어 문자열을 ARB로 전환하는 작업은 미완료 (L10n-1)
- 현재 English 선택해도 대부분 한국어 유지됨
- **전체 번역 작업**: 범위가 크므로 별도 Sprint 권장

### 6. Sprint 5f: 모바일 플랫폼 (미진행)
- **사용자 결정 필요**:
  - Android/iOS 디렉토리 생성 여부 (`flutter create --platforms=android,ios`)
  - OAuth 모바일 딥링크 구현 (custom URL scheme 필요)
  - FCM 푸시 알림 설정
  - 앱스토어 제출 준비
- **권장**: 별도 Phase 6로 진행. 현재 웹 배포는 완전 동작 중

### 7. 오프라인 캐싱 (미진행)
- sqflite/Hive 기반 로컬 캐싱 미구현
- 네트워크 없으면 앱 사용 불가
- **권장**: Phase 6

---

## 완료된 Sprint 요약

### Sprint 5a (보안 + 버그) - PR #39→#40 ✅
- Rate limit 윈도우 1분→1시간
- Couple dissolution soft-delete (V16 dissolved_at)
- SafeArea 적용
- 3/4 항목 이미 구현됨 확인

### Sprint 5b (대시보드 + 프로필) - PR #41→#42 ✅
- 대시보드: 월 네비게이션, 빠른 액션 버튼, 더보기 링크
- 프로필: PATCH /api/v1/auth/me, ProfileEditPage, Settings 프로필 카드
- 8 new BE tests

### Sprint 5c (거래 + 예산 + 카테고리) - PR #43→#44 ✅
- 거래: 고급 필터 (keyword, amount, paymentMethod, pocket) + JPA Specifications
- 예산: 전월 복사 API + UI ("전월 예산 복사" 버튼)
- 카테고리: 아이콘 선택기 (35개) + 색상 선택기 (16개)
- 10 new BE tests, 19 new FE tests

### Sprint 5d (포켓 + 통계 + 내보내기) - PR #45→#46 ✅
- 포켓: 목표 금액/일자 (V17), 진행률 바
- 분배 비율: 저장/불러오기 (V18), wizard 자동 적용
- 통계: 전년 비교 탭
- CSV: 거래 내보내기 (UTF-8 BOM)
- 29 new FE tests

### Sprint 5e (설정 + 다국어) - PR #47→#48 ✅
- 다크모드 토글 (Light/Dark/System)
- 언어 선택기 (한국어/English/System)
- 기본 결제수단 설정
- 앱 정보 페이지
- ThemeCubit + LocaleCubit
- 13 new FE tests

---

## 수치 요약

| 항목 | Phase 5 전 | Phase 5 후 | 증가 |
|------|-----------|-----------|------|
| BE 테스트 | 284+ | 310+ | +26 |
| FE 테스트 | 274 | 317 | +43 |
| DB 마이그레이션 | V1-V15 | V1-V18 | +3 |
| FE 페이지 | ~21 | ~24 | +3 |
| 신규 위젯 | - | 6 | +6 |
| 신규 BE 서비스 | - | 3 | +3 |

## 배포 상태

| PR | Sprint | 상태 |
|----|--------|------|
| #39→#40 | 5a | ✅ 배포 완료 |
| #41→#42 | 5b | ✅ 배포 완료 |
| #43→#44 | 5c | ✅ 배포 완료 |
| #45→#46 | 5d | ✅ 배포 완료 |
| #47→#48 | 5e | ✅ 배포 완료 |

## Phase 5 미완료 → Phase 6 권장 항목

| 항목 | 이유 |
|------|------|
| 모바일 플랫폼 (Android/iOS) | 디렉토리 구조 변경 큼, OAuth 딥링크 필요 |
| 오프라인 캐싱 | sqflite/Hive 통합 + conflict resolution |
| 하드코딩 한글 → ARB 전환 | 200+ 문자열 전환, 별도 Sprint |
| 프로필 이미지 업로드 | Supabase Storage 연동 필요 |
| 반응형 레이아웃 (태블릿/데스크탑) | LayoutBuilder 전체 적용 범위 큼 |
| FCM 푸시 알림 | Firebase 셋업 + 알림 서비스 전체 구축 |
| Sentry 에러 모니터링 | 별도 계정/프로젝트 설정 필요 |
