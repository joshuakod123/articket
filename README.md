# Articket — 프론트엔드 스캐폴드

명세서 v2.0 기준으로 Phase 1 화면을 전부 돌려볼 수 있는 Flutter 프로젝트입니다.
백엔드 연결 없이 인메모리 목업 데이터로 동작합니다.

## 실행

```bash
flutter create . --project-name articket   # 플랫폼 폴더(android/ios) 생성
flutter pub get
flutter run
```

Flutter 3.27 이상이 필요합니다 (`Color.withValues`, `toARGB32` 사용).

## 파일 구조

```
lib/
├── main.dart                     앱 진입점
├── theme/
│   ├── app_colors.dart           팔레트 토큰
│   ├── app_text.dart             서체 3종 (display / data / ui)
│   └── app_theme.dart            ThemeData
├── models/
│   ├── ticket.dart               Ticket, ArchiveFolder, TicketFrame, PosterPalette
│   └── layer.dart                ScrapLayer + JSON 직렬화
├── data/
│   ├── ticket_store.dart         ChangeNotifier 저장소
│   └── mock_data.dart            목업 티켓/폴더
├── widgets/
│   ├── frame_shapes.dart         프레임 6종 클리퍼 + 절취선 점선
│   ├── poster.dart               포스터 채우기 (사진 또는 색)
│   ├── ticket_card.dart          티켓 앞면 / 뒷면
│   ├── ticket_clipper.dart       바코드 페인터
│   ├── paper.dart                종이 그레인, 홀로그램, 그림자
│   └── index_tab.dart            서류철 셰이프 + 폴더 카드
└── screens/
    ├── archive_screen.dart       홈 — 인덱스 탭 파일 드로어
    ├── folder_screen.dart        폴더 내부 — 3열 바인더 그리드 / 목록
    ├── ticket_detail_screen.dart 3D 플립 + 자이로 홀로그램
    ├── editor_screen.dart        스크랩북 에디터
    ├── ticket_style_sheet.dart   프레임 · 포스터 선택 시트
    └── market_screen.dart        C2C 마켓 (Phase 3 뼈대)
```

`test/widget_test.dart`에는 홈 렌더링과 폴더 진입을 확인하는 스모크 테스트가 있습니다.

## 디자인 방향

참고 이미지의 전시 인쇄물 톤에서 뽑았습니다.

| 토큰 | 값 | 쓰임 |
|---|---|---|
| `ink` | `#14110F` | 갤러리 벽 배경 |
| `stock` | `#E8E2D4` | 티켓 용지 (회녹빛 언더톤) |
| `oxblood` | `#6E1F1B` | 시그니처 액센트 |
| `foil` | `#B08B3E` | 눌린 황동, 별점·강조 |
| `pulp` | `#C9C2B2` | 종이 두께, 절취선 |

서체는 역할별로 셋:
- **Bodoni Moda** — 전시 제목. 미술관 포스터의 고대비 세리프
- **Space Mono** — 발권 번호, 날짜, 라벨. 발권기가 찍은 듯한 고정폭
- **IBM Plex Sans KR** — 한글 본문과 UI

시그니처는 **진짜 종이처럼 그린 티켓**입니다. 이미지 에셋 없이
`Path.combine`으로 좌우 타공을 뚫고, 문자열 해시로 바코드를 그리고,
`CustomPainter`로 종이 섬유 노이즈를 뿌립니다.
서류철도 마찬가지로 사다리꼴 탭이 붙은 실제 폴더 모양을 Path로 잘랐습니다.

## 티켓 모양 고르기 · 포스터 넣기

### 어디서 여나

두 군데에서 같은 시트(`TicketStyleSheet`)가 열립니다.

| 진입점 | 위치 | 열리는 탭 |
|---|---|---|
| 에디터 툴바 → **프레임** | `editor_screen.dart` `_openStyle(0)` | FRAME |
| 에디터 툴바 → **포스터** | `editor_screen.dart` `_openStyle(1)` | POSTER |
| 상세 화면 우상단 ⛶ 아이콘 | `ticket_detail_screen.dart` AppBar actions | FRAME |

시트는 `showModalBottomSheet`로 띄우고, 안에서 고른 값은 `Ticket` 객체에 바로 쓴 뒤
`TicketStore.touch()`를 불러 화면을 갱신합니다. 저장 버튼이 따로 없고 고르는 즉시 반영됩니다.

### 파일이 어떻게 나뉘어 있나

```
models/ticket.dart          TicketFrame(6종) · PosterPalette(12종) 정의
        │                   ↓ 프레임 이름을 넘기면
widgets/frame_shapes.dart   clipperFor(frame) → 실루엣 CustomClipper
        │                   ↓ ClipPath로 감싸고
widgets/poster.dart         Poster → 사진(posterPath) 또는 색(posterTint)으로 채움
        │                   ↓ 둘을 조립해서
widgets/ticket_card.dart    TicketFront / TicketBack
        │                   ↑ 고르는 UI는 여기
screens/ticket_style_sheet.dart  FRAME 탭 · POSTER 탭
```

`Poster`는 `TicketFront` 안에서만 쓰이는 게 아니라 `TicketStyleSheet`의 프레임 미리보기
6칸에도 그대로 들어갑니다. 그래서 미리보기가 지금 티켓의 실제 사진·색으로 그려집니다.

### 프레임 6종

전부 이미지 에셋 없이 `Path`로 깎은 실루엣입니다.

| 프레임 | 실루엣 | 비율 | 정보 배치 |
|---|---|---|---|
| 클래식 | 아래 스텁 + 좌우 반원 타공 | 0.58 | 하단 가로 스텁 |
| 가로 스텁 | 오른쪽 세로 절취선 | 1.75 | 우측 세로 스텁, 바코드를 눕혀 세움 |
| 영수증 | 좁고 길게 · 아래가 톱니로 찢김 | 0.44 | 하단, 포스터 비중 40% |
| 필름 | 양옆 사각 퍼포레이션 | 0.62 | 하단, 절취선 없음 |
| 우표 | 사방 스캘럽 + 흰 여백 액자 | 0.74 | 포스터가 여백 안에 들어감 |
| 미니멀 | 절취선 없는 라운드 카드 | 0.66 | 하단 얇게 |

비율·포스터 비중·가로형 여부는 전부 `TicketFrame` enum의 필드입니다. 화면들은
`ticket.frame.aspect`를 읽어 `AspectRatio`를 맞추므로, 프레임을 바꾸면 상세·에디터·그리드가
동시에 따라옵니다.

**프레임을 추가하려면** `TicketFrame`에 항목 하나 넣고 `clipperFor`의 `switch`에
`case`를 더하면 됩니다. `switch`가 exhaustive라서 빼먹으면 컴파일 에러로 잡힙니다.

### 포스터

둘 중 하나로 채워집니다. 분기는 `Ticket.hasPhoto` 하나입니다.

- **사진** — `image_picker`로 가져와 `posterPath`에 경로 저장. 글씨가 묻히지 않게
  아래쪽 45%부터 어두운 그라디언트를 한 겹 깝니다.
- **색** — 사진이 없으면 `posterTint` 그라디언트. 프리셋 12종은
  `PosterPalette.presets`에 있고, 리스트에 항목만 추가하면 시트에 자동으로 나타납니다.

색을 고르면 `posterPath`를 `null`로 지웁니다. 사진과 색이 동시에 걸려 있는 상태를
아예 만들지 않기 위해서입니다. 반대로 사진을 넣어도 `posterTint`는 남겨두므로,
"사진 빼고 색으로"를 누르면 이전에 고른 색으로 돌아갑니다.

### 사진 권한 설정

`image_picker`는 플랫폼 설정이 필요합니다.

`ios/Runner/Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>티켓 포스터로 쓸 사진을 고릅니다.</string>
<key>NSCameraUsageDescription</key>
<string>티켓 포스터로 쓸 사진을 촬영합니다.</string>
```

안드로이드는 `compileSdk 34` 이상이면 추가 설정 없이 동작합니다.

## 다음에 붙을 것

| 할 일 | 방법 |
|---|---|
| 로컬 저장 | `TicketStore`의 메서드 본문만 Hive/Isar로 교체 (화면 코드는 그대로) |
| 사진 영구 보관 | `posterPath`의 파일을 `getApplicationDocumentsDirectory()`로 복사 |
| 폴라로이드 레이어에 사진 | `image_picker` → `ScrapLayer(kind: photo)`의 `content`에 경로 저장 |
| 9:16 내보내기 | 티켓을 `RepaintBoundary`로 감싸고 `toImage(pixelRatio: 3)` |
| 실행 취소 | `TicketStore`에 레이어 스냅샷 스택 추가 |
| Supabase | `ScrapLayer.encodeList`로 직렬화한 JSON을 `layers` 컬럼(jsonb)에 저장 |

## 알아둘 것

- 자이로는 `sensors_plus`로 읽되 없는 기기에서도 죽지 않게 `try/catch`로 감쌌습니다.
  데스크톱·웹에서는 홀로그램이 정지 상태로 보입니다.
- 레이어 좌표는 픽셀이 아니라 캔버스 대비 **0.0~1.0 비율**로 저장합니다.
  기기 화면이 달라져도 배치가 유지되고, 그대로 서버에 올릴 수 있습니다.
- 접근성: `MediaQuery.disableAnimations`가 켜져 있으면 플립 애니메이션을 건너뜁니다.
- `posterPath`는 기기 로컬 경로입니다. 웹에서는 `Image.file`을 쓸 수 없어 색으로 폴백합니다.
  앱을 재설치하면 캐시 경로가 사라지므로, 실제 저장 단계에서는 사진을
  앱 문서 디렉터리로 복사해 두는 편이 안전합니다.