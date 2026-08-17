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
손글씨 폰트(나눔펜스크립트)는 `google_fonts`가 첫 실행 때 네트워크로 받아오므로,
오프라인 첫 빌드에서는 손글씨가 기본 서체로 잠깐 보일 수 있습니다.

## 파일 구조

```
lib/
├── main.dart                     앱 진입점
├── theme/
│   ├── app_colors.dart           팔레트 토큰 ("전시장 벽" 라이트 테마)
│   ├── app_text.dart             서체 4종 (display / data / ui / hand)
│   └── app_theme.dart            ThemeData
├── models/
│   ├── ticket.dart                Ticket, ArchiveFolder(가변), TicketFrame, PosterPalette
│   └── layer.dart                ScrapLayer + JSON 직렬화
├── data/
│   ├── ticket_store.dart         ChangeNotifier 저장소 (폴더 CRUD 포함)
│   └── mock_data.dart            목업 티켓/폴더
├── widgets/
│   ├── frame_shapes.dart         티켓 프레임 6종 클리퍼 + 절취선 점선
│   ├── poster.dart               포스터 채우기 (사진 또는 색)
│   ├── ticket_card.dart          티켓 앞면 / 뒷면
│   ├── ticket_clipper.dart       바코드 페인터
│   ├── paper.dart                종이 그레인, 벽 질감, 홀로그램, 그림자
│   ├── scrapbook.dart            노트 속지 · 마스킹 테이프 · 손그림 낙서
│   ├── index_tab.dart            가로 서류철 카드(FolderCard) + 전환용 표지(FolderCover)
│   └── folder_open_route.dart    서류철이 젖혀 열리는 화면 전환(FolderOpenRoute)
└── screens/
    ├── archive_screen.dart       홈 — 가로 서류철 스택 + 폴더 추가/수정/삭제
    ├── folder_screen.dart        폴더 내부 — 스크랩북 / 바인더 그리드 / 목록
    ├── ticket_detail_screen.dart 3D 플립 + 자이로 홀로그램
    ├── editor_screen.dart        스크랩북 에디터
    ├── ticket_style_sheet.dart   프레임 · 포스터 선택 시트
    └── market_screen.dart        C2C 마켓 (Phase 3 뼈대)
```

`test/widget_test.dart`에는 홈 렌더링, 폴더 열림 전환, 폴더 생성, 저장소 필터링을
확인하는 스모크 테스트가 있습니다.

## 디자인 방향 — "전시장 벽"

검은 배경 대신, 미술관 내부처럼 **미색 플라스터 벽 앞에 종이가 걸린 구도**를 씁니다.

| 토큰 | 값 | 쓰임 |
|---|---|---|
| `bg` | `#F1ECE1` | 스캐폴드 배경. 미색 플라스터 벽 |
| `ink` | `#221C14` | 본문 · 제목. 도록 인쇄 잉크 |
| `stock` / `stockLight` | `#F8F4E9` / `#FDFBF4` | 티켓 · 카드 · 시트의 종이 용지 |
| `oxblood` | `#6B1F1A` | 시그니처 액센트 |
| `foil` | `#8C7134` | 눌린 황동. 별점 · 라벨 강조 |
| `pulp` | `#CCC4B0` | 종이 두께, 절취선, 흐린 텍스트 |
| `line` | `#D7CFBC` | 헤어라인 구분선 |

서체는 역할별로 넷:
- **Bodoni Moda** (`display`) — 전시 제목. 미술관 포스터의 고대비 세리프
- **Space Mono** (`data`) — 발권 번호, 날짜, 라벨. 발권기가 찍은 듯한 고정폭
- **IBM Plex Sans KR** (`ui`) — 한글 본문과 UI
- **나눔펜스크립트** (`hand`) — 스크랩북 손글씨. 서류철 탭 이름, 한 줄 평

배경·카드·서류철 표면은 전부 `CustomPainter`로 찍은 종이 노이즈(`GrainPainter`,
`WallGrain`)를 얹어, 이미지 에셋 없이도 인쇄물 같은 질감을 냅니다.

## 화면별 핵심 구현

### 1. 홈 — 가로 서류철 스택 (`archive_screen.dart`, `widgets/index_tab.dart`)

실제 파일 캐비닛처럼 서류철을 **가로로 눕혀 겹쳐 쌓았습니다.** 뒤 서류철이 앞
서류철 밑에 118pt 간격으로 깔리며, 탭이 3슬롯을 순환해 서로 가리지 않습니다.

- `FolderShape`(`CustomClipper<Path>`)로 위쪽 한 자리에 사다리꼴 인덱스 탭을 깎고,
  `PhysicalShape`로 감싸 실루엣을 그대로 따라가는 그림자를 냅니다.
- 탭에는 서류철 이름을 손글씨로, 몸통 왼쪽엔 최근 티켓의 포스터 색을 채운
  **폴라로이드**(`_Polaroid`)가 비뚤게 삐져나오고, 오른쪽엔 영문 라벨 · 보관 수 ·
  `FILE_01` 정리 번호가 찍힙니다.
- 헤더 오른쪽 폴더+ 아이콘으로 **새 서류철**을 만들고(`_FolderForm`), 서류철을
  **길게 누르면** 이름·색 고치기 또는 버리기 메뉴가 뜹니다. 버릴 때는 안의 티켓
  수를 보여주고 확인 후 함께 삭제합니다.

### 2. 폴더 열림 전환 (`widgets/folder_open_route.dart`)

`PageRoute`를 커스텀 구현한 `FolderOpenRoute`. 서류철을 탭하면:

1. 눌린 카드의 화면 좌표를 `GlobalKey`로 읽고,
2. 그 자리에서 표지 복제본(`FolderCover`)이 **윗변(접힌 선)을 축으로 `rotateX`
   회전하며 젖혀 열리고**, 동시에 카드 영역이 원근과 함께 화면 전체로 번져나가며,
3. 그 아래에서 폴더 내용(스크랩북)이 살짝 확대되며 차오릅니다.

뒤로 가기 시 애니메이션이 역재생되어 표지가 다시 덮입니다. 모션 축소
(`MediaQuery.disableAnimations`) 사용자는 페이드 전환만 받고, 좌표를 못 읽는
예외 상황에서는 기본 `MaterialPageRoute`로 폴백합니다.

### 3. 폴더 내부 — 스크랩북 (`folder_screen.dart`, `widgets/scrapbook.dart`)

폴더를 열면 기본으로 **스크랩북**이 펼쳐집니다(앱바 아이콘으로 바인더 그리드 ·
목록과 순환 전환).

- `NotebookPage`: 크림 속지 + 옅은 모눈 점(`DotGridPainter`) + 왼쪽 제본 그늘과
  실 박음질(`BindingGutter`).
- 페이지를 넘기면 `PageView` + `rotateY`로 안쪽 제본을 축으로 살짝 젖혀집니다.
- 티켓은 **마스킹 테이프**(`WashiTape`, 톱니로 뜯긴 `ClipPath`)로 비뚤게 붙고
  (`TapedItem`), 옆에는 손글씨 메모(`_Memo`): 날짜 → 전시명 → 손그림 밑줄
  (`DoodleUnderline`) → 한 줄 평(`AppText.hand`) → 별점 · 장소.
- 티켓을 탭하면 상세로, **길게 누르면 삭제**됩니다.

### 4. 티켓 (`widgets/ticket_card.dart`, `frame_shapes.dart`)

프레임 6종(클래식 · 가로 스텁 · 영수증 · 필름 · 우표 · 미니멀)을 이미지 에셋 없이
`Path.combine`으로 타공·톱니·퍼포레이션을 뚫어 표현합니다. 티켓 내부 글자는
`TextScaler.noScaling`으로 고정해, 사용자의 시스템 글자 배율이 커져도 인쇄물처럼
레이아웃이 깨지지 않습니다.

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

**프레임을 추가하려면** `TicketFrame`에 항목 하나 넣고 `clipperFor`의 `switch`에
`case`를 더하면 됩니다. `switch`가 exhaustive라서 빼먹으면 컴파일 에러로 잡힙니다.

### 포스터

둘 중 하나로 채워집니다. 분기는 `Ticket.hasPhoto` 하나입니다.

- **사진** — `image_picker`로 가져와 `posterPath`에 경로 저장.
- **색** — 사진이 없으면 `posterTint` 그라디언트. 프리셋 12종은
  `PosterPalette.presets`에 있고, 리스트에 항목만 추가하면 시트에 자동으로 나타납니다.

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

## 서류철(폴더) 관리

`ArchiveFolder`의 `label` · `subtitle` · `color`는 가변 필드입니다.
`TicketStore`에 다음 메서드가 있습니다.

| 메서드 | 동작 |
|---|---|
| `addFolder(ArchiveFolder)` | 새 서류철 추가 |
| `removeFolder(id)` | 서류철과 그 안의 티켓을 함께 삭제 |
| `folderById(id)` | 단건 조회 |
| `touch()` | 가변 필드만 바꿨을 때 리스너에 갱신 알림 |

홈 화면(`archive_screen.dart`)의 `_FolderForm`이 만들기/고치기를 겸합니다.
탭 라벨을 비우면 `FILE / 06`처럼 순번으로 자동 채웁니다.

## 다음에 붙을 것

| 할 일 | 방법 |
|---|---|
| 로컬 저장 | `TicketStore`의 메서드 본문만 Hive/Isar로 교체 (화면 코드는 그대로) |
| 사진 영구 보관 | `posterPath`의 파일을 `getApplicationDocumentsDirectory()`로 복사 |
| 폴라로이드 레이어에 사진 | `image_picker` → `ScrapLayer(kind: photo)`의 `content`에 경로 저장 |
| 9:16 내보내기 | 티켓을 `RepaintBoundary`로 감싸고 `toImage(pixelRatio: 3)` |
| 실행 취소 | `TicketStore`에 레이어 스냅샷 스택 추가 |
| Supabase | `ScrapLayer.encodeList`로 직렬화한 JSON을 `layers` 컬럼(jsonb)에 저장 |
| 폴더 순서 편집 | `TicketStore._folders`에 reorder 메서드 추가, 홈에서 드래그 정렬 |

## 알아둘 것

- 자이로는 `sensors_plus`로 읽되 없는 기기에서도 죽지 않게 `try/catch`로 감쌌습니다.
  데스크톱·웹에서는 홀로그램이 정지 상태로 보입니다.
- 레이어 좌표는 픽셀이 아니라 캔버스 대비 **0.0~1.0 비율**로 저장합니다.
  기기 화면이 달라져도 배치가 유지되고, 그대로 서버에 올릴 수 있습니다.
- 접근성: `MediaQuery.disableAnimations`가 켜져 있으면 티켓 플립과 폴더 열림
  전환 둘 다 애니메이션을 건너뜁니다.
- `posterPath`는 기기 로컬 경로입니다. 웹에서는 `Image.file`을 쓸 수 없어 색으로
  폴백합니다. 앱을 재설치하면 캐시 경로가 사라지므로, 실제 저장 단계에서는 사진을
  앱 문서 디렉터리로 복사해 두는 편이 안전합니다.
- 폴더 열림 전환(`FolderOpenRoute`)은 카드의 `GlobalKey`로 화면 좌표를 읽어야
  동작합니다. 좌표를 못 읽는 경우(레이아웃 전이거나 위젯이 아직 안 붙은 경우)는
  자동으로 기본 `MaterialPageRoute`로 대체됩니다.