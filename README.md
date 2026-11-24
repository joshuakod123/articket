# Articket

전시와 공연의 기억을 티켓으로 만들고, 서류철에 모아두는 Flutter 앱입니다.
선택한 **05 AT 모노그램**과 밝은 아이보리·코랄·라벤더·버터색 UI를 적용했습니다.

## 실행

Flutter **3.32 이상**, Dart **3.8 이상**이 필요합니다. 검증 SDK는 Flutter 3.32.8 / Dart 3.8.1입니다.

```sh
flutter pub get
flutter run
```

모바일 iOS/Android가 주 대상입니다. 저장·인증은 기존 Supabase 프로젝트와 연결됩니다.
`SUPABASE_URL`, `SUPABASE_ANON_KEY`를 `--dart-define`으로 지정하면 기존 기본 접속값보다 우선합니다.
폰트와 로고는 번들에 포함되어 첫 오프라인 실행에도 표시됩니다.

## 주요 동작

- 홈: 실제 기록만 표시하는 최근 티켓 갤러리, 연도·전시·공연·즐겨찾기 필터, 전체 검색.
- 서류철: 첫 두 개의 미리보기와 전체 서류철 목록, 이름·색·글꼴·질감 편집.
- 기록 생성: 입력 초안을 사용하므로 취소하면 티켓이나 빈 서류철이 저장되지 않습니다.
  첫 저장 시 서류철이 없다면 기본 서류철을 한 개 만듭니다.
- 디자인: 에디토리얼·스크랩북·그래픽의 세 레이아웃과 여섯 프레임을 조합합니다.
  기존 티켓은 `legacy` 디자인으로 읽어 원래 모양과 꾸미기를 보존합니다.
- 꾸미기: 기존 스티커·글자·테이프·도장·사진 편집, 이동·회전·확대·되돌리기를 유지합니다.
- 달력·내 기록: 관람일별 티켓, 회원증, 기록 수와 장르별 집계.
- 공유: 앱 메뉴 없이 결과물만 9:16 PNG로 만들어 네이티브 공유 시트로 전달합니다.
- 계정: 로그인·회원가입·이름 변경·비밀번호 변경/복구·로그아웃·계정 삭제.

## 서버 설정

UI 파일을 교체해도 아래 서비스 설정은 별도로 필요합니다.

1. 기존 `supabase/migrations/20260826000100_init.sql`의 테이블·RPC·스토리지 정책이 배포되어 있어야 합니다.
   이미 적용된 프로젝트에 초기 마이그레이션을 다시 실행하지 않습니다.
2. 비밀번호 복구: Supabase Auth의 Redirect URLs에 `articket://auth-callback`을 추가합니다.
   Android/iOS 앱의 해당 URL scheme은 소스에 등록돼 있습니다. 다른 주소는
   `--dart-define=AUTH_REDIRECT_URL=...`로 지정하되 앱 URL 등록도 맞춰야 합니다.
3. 계정 삭제 함수의 실제 이름은 `delete-account`입니다. 소스 폴더명도 이 이름으로 맞췄습니다.
   사진 삭제 오류가 있으면 계정 삭제 성공으로 처리하지 않고 재시도할 수 있게 합니다.

```sh
supabase functions deploy delete-account
```

4. 확정한 정책 문서의 HTTPS 주소를 `TERMS_URL`, `PRIVACY_POLICY_URL`로 지정합니다.
   미설정 시 문서가 등록되지 않았음을 안내하며, 임의의 법률 문서를 만들어 동의받지 않습니다.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_KEY \
  --dart-define=TERMS_URL=https://YOUR_DOMAIN/terms \
  --dart-define=PRIVACY_POLICY_URL=https://YOUR_DOMAIN/privacy
```

## 데이터와 사진

- `design`, `isFavorite`, 사진 레이어의 `photoKey`는 기존 JSON payload로 동기화합니다.
  이 필드를 위해 별도 SQL 컬럼을 추가하지 않습니다.
- 원본 사진은 앱 문서 폴더에 고유 파일명으로 보관하고 private `posters` 버킷으로 백업합니다.
  다른 기기의 로컬 경로는 서버 payload에 넣지 않습니다.
- 포스터 교체/제거 시 이전 서버 키를 해제합니다. 티켓과 페이지에 붙인 사진도 백업합니다.
- 로컬 쓰기와 메타데이터 쓰기를 순서대로 처리합니다. 업로드 중 추가 수정은 전송한
  스냅샷과 구분하며, 미전송 수정·삭제는 첫 원격 읽기 전에 복원합니다.
- 동기화 커서는 테이블별 `(updated_at, id)`로 관리합니다. 같은 시각에 기록이 많이 바뀌어도
  다음 페이지를 빠뜨리지 않습니다.
- 앱을 다시 활성화하면 동기화를 시도하고, 설정에서 백업 상태를 확인하거나 재시도할 수 있습니다.

## 검증과 실제 화면 캡처

```sh
flutter analyze
flutter test
flutter test test/preview_render_test.dart --dart-define=EXPORT_PREVIEWS=true
```

마지막 명령은 **테스트에만 들어 있는 기록**을 이용해 실제 Flutter 렌더링 PNG를
`work/previews/`에 저장합니다. 사용자 계정에 예시 데이터를 올리지 않습니다.
테스트는 실제 Supabase 계정 변경·삭제를 수행하지 않습니다. 실기기 로그인/메일 복구,
사진 권한, 기기 간 동기화, 네이티브 공유는 배포 환경에서 추가 확인해야 합니다.

## 주요 파일

- `lib/theme/`: 앱 UI 토큰과 티켓 디자인 정의.
- `lib/widgets/brand_logo.dart`: 벡터 AT 로고와 기존 호출부 호환 래퍼.
- `lib/widgets/home/`: 헤더, 최근 티켓 갤러리, 서류철 미리보기.
- `lib/models/ticket_draft.dart`, `lib/widgets/record_form.dart`: 저장 전 초안과 공용 기록 폼.
- `lib/widgets/ticket_face.dart`, `ticket_art.dart`: 새 티켓 레이아웃과 원본 벡터 포스터.
- `lib/data/ticket_query.dart`: 검색·연도·장르·즐겨찾기 필터.
- `assets/brand/`, `assets/fonts/`: 로고, 앱 아이콘, 오프라인 폰트와 OFL 라이선스.
