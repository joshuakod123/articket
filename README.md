# Articket — 티켓 다이어리

> 전시를 보고 나온 종이 한 장을, 버리지 않고 철해두는 앱.

미술관·갤러리·공연 관람 기록을 **커스텀 티켓**으로 만들고, 서류철에 철해
스크랩북처럼 꾸며 소장하는 Flutter 앱입니다. 기획서 v2.0의 Phase 1 화면이
전부 돌아가며, 백엔드 없이 인메모리 목업 데이터로 동작합니다.

이미지 에셋이 **하나도 없습니다.** 종이 결, 서류철 질감, 티켓 타공, 스티커,
탭바 심볼까지 전부 `CustomPainter` / `Path`로 그립니다.

---

## 실행

```bash
flutter create . --project-name articket   # 플랫폼 폴더(android/ios) 생성
flutter pub get
flutter run
```

**Flutter 3.27 이상**이 필요합니다 (`Color.withValues`, `Color.toARGB32` 사용).

서체는 `google_fonts`가 첫 실행 때 네트워크로 받아옵니다. 오프라인 첫 빌드에서는
손글씨가 기본 서체로 잠깐 보일 수 있습니다.

```bash
flutter analyze
flutter test        # test/widget_test.dart — 스모크 테스트 5종
```

### 의존성

| 패키지 | 쓰임 |
|---|---|
| `google_fonts` | 서체 5종 |
| `sensors_plus` | 자이로 홀로그램 (없는 기기에서도 동작) |
| `image_picker` | 티켓 포스터 사진 |
| `share_plus` + `path_provider` | 9:16 공유 카드 내보내기 |
| `uuid` | 티켓·레이어 ID |

---

## 화면 지도

앱은 아래 탭바로 묶인 **세 화면**에서 시작합니다 (`root_shell.dart`,
`IndexedStack`이라 탭을 오가도 스크롤 위치와 보던 달이 유지됩니다).

```
                    ┌──────────────┐
                    │  RootShell   │
                    └──────┬───────┘
        ┌──────────────────┼──────────────────┐
   [서랍 DRAWER]      [달력 CALENDAR]     [내 기록 RECORD]
  archive_screen     calendar_screen     profile_screen
        │
        │ 탭 → 표지가 젖혀 열림 (FolderOpenRoute)
        ▼
   folder_screen ─── 스크랩북 / 바인더 그리드 / 목록
        │
        ├─ 티켓 탭 ──▶ ticket_detail_screen ─┬─▶ editor_screen (티켓 위 꾸미기)
        │                                    ├─▶ record_sheet (감상 기록)
        │                                    ├─▶ ticket_style_sheet (프레임·포스터)
        │                                    └─▶ share_card_screen (9:16 내보내기)
        │
        ├─ 꾸미기 ───▶ page_decor_screen (페이지 꾸미기 · 티켓 자유 배치)
        └─ 공유 ─────▶ share_card_screen

   서랍에서 서류철 길게 누름 ──▶ folder_workbench (이름·서체·색·질감 작업대)
```

---

## 파일 구조

```
lib/
├── main.dart                      앱 진입점 (세로 고정)
│
├── theme/
│   ├── app_colors.dart            팔레트 토큰 — "빛바랜 서류철" 웜 톤
│   ├── app_text.dart              서체 7역할 (wordmark/display/plate/data/dymo/ui/hand)
│   ├── app_theme.dart             ThemeData
│   └── folder_style.dart          FolderFont 6종 · FolderTexture 5종
│
├── models/
│   ├── ticket.dart                Ticket · ArchiveFolder · TicketFrame(6) · PosterPalette(12)
│   └── layer.dart                 ScrapLayer(sticker/text/tape/photo) + JSON 직렬화
│
├── data/
│   ├── ticket_store.dart          ChangeNotifier 인메모리 저장소
│   └── mock_data.dart             목업 티켓 / 서류철
│
├── services/
│   └── share_card.dart            RepaintBoundary → PNG → 공유 시트
│
├── widgets/
│   ├── paper.dart                 종이 그레인 · 벽 질감 · 홀로그램 · 종이 그림자
│   ├── folder_texture.dart        FolderSurface(결·빛·비네트·닳음) · DebossedText
│   ├── index_tab.dart             FolderCard(가로 서류철) · FolderCover(전환용 표지)
│   ├── folder_open_route.dart     표지가 젖혀 열리는 화면 전환
│   ├── frame_shapes.dart          티켓 프레임 6종 클리퍼 + 절취선
│   ├── poster.dart                포스터 채우기 (사진 또는 색)
│   ├── ticket_card.dart           TicketFront / TicketBack
│   ├── ticket_canvas.dart         티켓 + 스크랩 레이어를 한 덩어리로 축척
│   ├── ticket_clipper.dart        바코드 페인터
│   ├── scrapbook.dart             NotebookPage · WashiTape · DoodleUnderline · 낙서
│   ├── scrap_page.dart            TapedTicket · ScrapMemo · AutoScrapPage
│   ├── scrap_layers.dart          StickerArt 16종 (전부 Path로 깎음)
│   ├── scaled_canvas.dart         고정 설계 크기로 그린 뒤 통째로 축척
│   ├── bottom_nav_bar.dart        종이 인덱스 탭이 미끄러지는 탭바
│   ├── nav_icons.dart             탭바 심볼 3종 (서류철·달력·회원증)
│   ├── stub_button.dart           빈 티켓 실루엣 버튼
│   └── paper_toast.dart           SnackBar 대신 쓰는 종이 쪽지 알림
│
└── screens/
    ├── root_shell.dart            세 탭을 물고 있는 껍데기
    ├── archive_screen.dart        서랍 — 가로 서류철 스택
    ├── folder_workbench.dart      서류철 작업대 (이름·서체·색·질감)
    ├── folder_screen.dart         서류철 내부 — 스크랩북 / 그리드 / 목록
    ├── page_decor_screen.dart     페이지 꾸미기 + 티켓 자유 배치
    ├── ticket_detail_screen.dart  3D 플립 + 자이로 홀로그램
    ├── editor_screen.dart         티켓 위 레이어 에디터 (되돌리기 지원)
    ├── record_sheet.dart          감상 기록 — 벽 캡션 카드 형태
    ├── ticket_style_sheet.dart    프레임 · 포스터 고르기
    ├── scrap_sheets.dart          스티커 / 글자 / 테이프 고르는 시트
    ├── share_card_screen.dart     9:16 공유 카드 만들기
    ├── calendar_screen.dart       달력 — 그날 본 티켓을 칸에 끼움
    └── profile_screen.dart        내 기록 — 회원증 · 통계
```

---

## 디자인 방향 — "빛바랜 서류철"

차가운 화이트를 걷어내고, 오래된 양장본 속지와 마닐라 서류철의 누런 기운으로
통일했습니다. **화면 어디를 잘라도 종이 위**여야 합니다.

### 색 (`theme/app_colors.dart`)

| 토큰 | 값 | 쓰임 |
|---|---|---|
| `bg` | `#EDE3D0` | 스캐폴드 배경. 빛바랜 속지 |
| `bgDeep` | `#DFD2B8` | 그늘진 면. 서랍 안쪽 |
| `ink` / `inkSoft` | `#251E15` / `#6E6152` | 본문·제목 / 보조 텍스트 |
| `stock` / `stockLight` | `#F6F0E2` / `#FCF8EE` | 티켓·카드 용지 |
| `pulp` | `#C7BBA2` | 종이 두께 · 절취선 · 흐린 글자 |
| `line` | `#D3C6AC` | 헤어라인 구분선 |
| `kraft` / `kraftDeep` | `#B08F5C` / `#8E6F42` | 마닐라 서류철 |
| `oxblood` / `oxbloodDim` | `#6B1F1A` / `#471310` | 시그니처 액센트 |
| `foil` | `#8C7134` | 눌린 황동. 별점 · 캡션 플레이트 |
| `dymo` | `#1E1A15` | 라벨 테이프 |

### 서체 (`theme/app_text.dart`)

역할이 겹치지 않게 못 박습니다. 섞어 쓰지 않습니다.

| 역할 | 서체 | 쓰이는 자리 |
|---|---|---|
| `wordmark` | Bodoni Moda | **로고 전용**. `ARTICKET` 한 자리에만 |
| `display` | 고운바탕 | 제목. 전시명 · 서류철 이름 · 화면 표제 |
| `plate` | Bodoni Moda | 영문 전용 표제. ASCII만 오는 자리 |
| `data` / `eyebrow` | Courier Prime | 발권 번호 · 날짜 · 분류 라벨. 한글 금지 |
| `dymo` | Courier Prime Bold | 라벨 테이프에 눌러 찍은 글자 |
| `ui` | IBM Plex Sans KR | 한글 본문 · 버튼 · 설명 |
| `hand` | 나눔펜스크립트 | 사용자 메모. 한 줄 평, 손으로 쓴 라벨 |

> 제목 서체를 Noto Serif KR에서 **고운바탕**으로 옮겼습니다. Noto는 화면용으로
> 잘 만든 대신 표정이 없어서, 종이 질감 위에 얹으면 혼자만 디지털처럼 보였습니다.

---

## 화면별 핵심 구현

### 1. 서랍 — 가로 서류철 스택 (`archive_screen.dart`, `widgets/index_tab.dart`)

실제 파일 캐비닛처럼 서류철을 **가로로 눕혀 겹쳐 쌓았습니다.** 뒤 서류철이 앞
서류철 밑에 깔리며, 인덱스 탭이 3슬롯을 순환해 서로 가리지 않습니다.

- `FolderShape`(`CustomClipper<Path>`)로 위쪽 한 자리에 사다리꼴 탭을 깎고,
  `PhysicalShape`로 감싸 실루엣을 그대로 따라가는 그림자를 냅니다.
- 탭에는 서류철 이름이 **고른 필기구**(`FolderFont`)로, 몸통 왼쪽엔 최근 티켓의
  포스터 색을 채운 폴라로이드가 비뚤게 삐져나오고, 오른쪽엔 영문 라벨 · 보관 수 ·
  `FILE_01` 정리 번호가 찍힙니다.
- **길게 누르면** 서류철이 책상 위로 뽑혀 나옵니다 → `folder_workbench.dart`.

**헤더는 전시 도록의 표제지(title page)입니다.**

```
A R T I C K E T ──────────────────────── MMXXVI     ← 판권 줄 (연도는 로마 숫자)
═══════════════════════════════════════════════     ← 이중 괘선
───────────────────────────────────────────────

티켓 서랍                                    ┌───┐
THE TICKET DRAWER                           │ ＋ │  ← 황동 캡션 플레이트
───────────────────────────────────────────────
● 5 FILES · 6 TICKETS            FILED 2026.07.14
눌러서 펼치기 · 길게 누르면 고치기
```

배경에는 위쪽 가운데에서 떨어지는 조명(`RadialGradient`)을 한 겹 얹었습니다.
균일하게 밝은 벽은 미술관에 없습니다. 이 그라디언트 하나로 평면이 벽으로 읽힙니다.

### 2. 폴더 열림 전환 (`widgets/folder_open_route.dart`)

`PageRoute`를 커스텀 구현한 `FolderOpenRoute`. 서류철을 탭하면:

1. 눌린 카드의 화면 좌표를 `GlobalKey`로 읽고,
2. 그 자리에서 표지 복제본(`FolderCover`)이 **윗변을 축으로 `rotateX` 회전하며
   젖혀 열리고**, 동시에 카드 영역이 원근과 함께 화면 전체로 번져나가며,
3. 그 아래에서 스크랩북이 살짝 확대되며 차오릅니다.

뒤로 가면 역재생되어 표지가 다시 덮입니다. 모션 축소
(`MediaQuery.disableAnimations`) 사용자는 페이드만 받고, 좌표를 못 읽는 예외
상황에서는 기본 `MaterialPageRoute`로 폴백합니다.

### 3. 서류철 작업대 (`folder_workbench.dart`)

서류철을 만들거나 고치는 화면. 색 팔레트만 있던 걸 네 축으로 넓혔습니다.

| 축 | 선택지 |
|---|---|
| 이름 · 영문 라벨 | 자유 입력 (비우면 `FILE / 06` 자동) |
| 필기구 `FolderFont` | 다이모 라벨 · 타자기 · 도록 명조 · 손글씨 · 포스터 고딕 · 둥근 라벨 |
| 색 `tabColors` | 옥스블러드 · 올리브 · 네이비 · 마닐라 · 다크 크라프트 |
| 질감 `FolderTexture` | 크라프트지 · 리넨 클로스 · 가죽 · 마블 페이퍼 · 프레스보드 |

질감은 전부 `FolderSurface`가 `CustomPainter`로 찍습니다. 바탕색 → 결 →
빛 방향 그라디언트 → 가장자리 비네트 → 모서리 닳음 순서로 얹고, `seed`가 같으면
무늬도 같아서 같은 서류철은 다시 그려도 같은 얼룩을 유지합니다.

### 4. 서류철 내부 — 스크랩북 (`folder_screen.dart`, `widgets/scrap_page.dart`)

폴더를 열면 기본으로 스크랩북이 펼쳐집니다 (앱바 아이콘으로 `FolderView.book` →
`grid` → `list` 순환).

- `NotebookPage`: 크림 속지 + 옅은 모눈 점 + 왼쪽 제본 그늘과 실 박음질.
- 페이지를 넘기면 `PageView` + `rotateY`로 안쪽 제본을 축으로 살짝 젖혀집니다.
- **자동 배치** — 티켓이 두 장씩 마스킹 테이프(`WashiTape`, 톱니로 뜯긴 `ClipPath`)로
  비뚤게 붙고, 옆에 손글씨 메모(`ScrapMemo`)가 붙습니다:
  날짜 → 전시명 → 손그림 밑줄 → 한 줄 평 → 별점 · 장소.
- **자유 배치** (`folder.freeLayout`) — 꾸미기 화면에서 티켓을 처음 끌면 켜지고,
  이후 사용자가 앉힌 자리(`Ticket.px` / `py` / `pscale` / `protation`)에 그립니다.

### 5. 페이지 꾸미기 (`page_decor_screen.dart`)

스크랩북과 **똑같은 위젯**(`AutoScrapPage`, `TapedTicket`, `NotebookPage`)을 써서,
여기서 본 그림이 완성된 페이지와 일치합니다. 티켓을 끌면 자유 배치로 전환되고
두 손가락으로 돌리고 키웁니다. 붙이는 것들은 `scrap_sheets.dart`에서 고릅니다.

### 6. 티켓 (`widgets/ticket_card.dart`, `frame_shapes.dart`)

프레임 6종을 이미지 에셋 없이 `Path.combine`으로 타공·톱니·퍼포레이션을 뚫어
표현합니다.

| 프레임 | 실루엣 | 비율 | 절취선 |
|---|---|---|---|
| 클래식 | 아래 스텁 + 좌우 반원 타공 | 0.58 | O |
| 가로 스텁 | 오른쪽 세로 절취선 | 1.75 | O |
| 영수증 | 좁고 길게 · 아래가 톱니로 찢김 | 0.44 | O |
| 필름 | 양옆 사각 퍼포레이션 | 0.62 | X |
| 우표 | 사방 스캘럽 + 흰 여백 액자 | 0.74 | X |
| 미니멀 | 절취선 없는 라운드 카드 | 0.66 | X |

프레임을 추가하려면 `TicketFrame`에 항목 하나 넣고 `clipperFor`의 `switch`에
`case`를 더하면 됩니다. `switch`가 exhaustive라서 빼먹으면 컴파일 에러로 잡힙니다.

포스터는 `Ticket.hasPhoto` 하나로 갈립니다. 사진(`image_picker` → `posterPath`)이
없으면 `posterTint` 그라디언트로 칠하고, 프리셋 12종은 `PosterPalette.presets`에
있습니다. 리스트에 항목만 추가하면 시트에 자동으로 나타납니다.

프레임·포스터를 고르는 시트(`TicketStyleSheet`)는 두 군데에서 열립니다.

| 진입점 | 열리는 탭 |
|---|---|
| 에디터 툴바 → 프레임 / 포스터 | FRAME / POSTER |
| 상세 화면 우상단 ⛶ | FRAME |

고른 값은 `Ticket` 객체에 바로 쓴 뒤 `TicketStore.touch()`로 갱신합니다.
저장 버튼이 따로 없고 고르는 즉시 반영됩니다.

### 7. 티켓 상세 (`ticket_detail_screen.dart`)

`rotateY` 3D 플립으로 앞/뒷면을 넘기고, 자이로 각도에 따라 홀로그램 펄이 흐릅니다
(`HoloOverlay`). 붙여둔 스크랩 레이어는 **티켓 앞면에 함께 붙어** 있어서
뒤집으면 같이 넘어갑니다.

### 8. 감상 기록 (`record_sheet.dart`)

라벨과 밑줄이 세로로 늘어선 폼 대신 **미술관 벽에 붙은 캡션 카드**로 짰습니다.
라벨은 전부 타자기 고정폭 대문자(`TITLE` / `VENUE` / `DATE`), 별점은 도장 찍듯
큼직하게, 한 줄 평은 **손글씨 서체로 입력**되어 적는 동안 이미 스크랩북 글씨입니다.

### 9. 달력 (`calendar_screen.dart`)

점을 찍는 대신 **그날 본 티켓을 그 칸에 그대로 끼웠습니다.**

- 이 달에 기록이 없으면 **기록이 있는 가장 최근 달**을 펴고 들어옵니다.
- 달 아래 연도 띠가 1~12월 중 어디에 기록이 있는지 점으로 보여주고, 누르면 이동합니다.
- 빈 달에서는 가장 가까운 기록으로 건너뛰는 버튼이 붙습니다.

### 10. 내 기록 (`profile_screen.dart`)

리넨 클로스로 싼 옥스블러드 **회원증**(비율 1.62 — 실제 신용카드), 숫자 넉 칸,
최근 본 것 핀보드, 장르·장소 분포. 회원증의 이름을 누르면 그 자리에서 고칩니다.

### 11. 공유 카드 (`share_card_screen.dart`, `services/share_card.dart`)

스크린샷을 그냥 올리면 앱 UI(앱바·탭바·상태바)까지 같이 나갑니다. 여기서는
**작품만 종이 위에 다시 앉혀서** 스토리 비율로 짭니다.

| 축 | 선택지 |
|---|---|
| 종이 `ShareStock` | 미색 · 모래 · 크라프트 · 장미 · 올리브 · 네이비 · 옥스블러드 · 먹지 |
| 결 | 민무늬 + `FolderTexture` 5종 |
| 소품 `ShareTrim` | 없음 · 테이프 · 도장 · 사진 모서리 |

글자색은 종이마다 대비가 확실한 값으로 **미리 짝지어** 둡니다 (사용자가 고를 일이
없게). `RepaintBoundary` → `toImage` → PNG → `share_plus`로 넘깁니다.

---

## 크기를 다루는 규칙 — `ScaledCanvas`

이 앱에서 반복해서 터졌던 버그가 하나 있습니다. **같은 그림을 다른 크기 상자에
넣을 때 레이아웃이 다시 흐르는 것**입니다. 티켓은 상자에 맞춰 작아지는데
글자 크기(13.5pt)와 여백(18pt)은 그대로라, 결과적으로 글자만 거대해집니다.

그래서 규칙을 하나로 못 박았습니다.

> **인쇄물처럼 보여야 하는 것은, 고정 설계 크기로 한 번 그린 뒤 통째로 축척한다.**

`widgets/scaled_canvas.dart`가 그 역할을 합니다.

```dart
ScaledCanvas(
  design: const Size(360, 640),   // 이 크기 기준으로 글자·여백을 정함
  child: _Card(...),              // 상자가 아무리 작아져도 그림은 동일
)
```

| 자리 | 설계 크기 |
|---|---|
| 공유 카드 전체 | 360 × 640 (9:16) |
| 스크랩북 페이지 (공유) | 340 × 472 |
| 티켓 한 장 (공유) | 300 × (300 / `frame.aspect`) |
| 티켓 + 레이어 | `ticketDesignWidth` (`ticket_canvas.dart`) |

안쪽에서 `MediaQuery.withNoTextScaling`으로 시스템 글자 배율도 끊습니다.
인쇄물이 접근성 설정에 따라 판이 바뀌면 안 되니까요.

내보내기는 `ShareCard.captureToFile(targetWidth: 1080)`로 화면에 그려진 크기와
무관하게 **항상 1080 × 1920**으로 뜹니다.

---

## 저장소 API (`data/ticket_store.dart`)

`ChangeNotifier` 싱글턴 하나가 전부입니다. 화면은 `ListenableBuilder`로 이
객체만 구독하므로, **메서드 본문만 Hive/Isar 호출로 바꾸면** 화면 코드는 손댈
필요가 없습니다.

| 메서드 | 동작 |
|---|---|
| `folders` / `tickets` | 읽기 전용 목록 |
| `ticketsIn(folderId)` | 폴더 안 티켓 (최신순) |
| `countIn(folderId)` / `byId(id)` / `folderById(id)` | 조회 |
| `addFolder(f)` / `removeFolder(id)` | 서류철 추가 / 삭제 (안의 티켓도 함께) |
| `add(ticket)` / `remove(id)` | 티켓 추가 / 삭제 |
| `addLayer` / `removeLayer` / `bringToFront` | 스크랩 레이어 |
| `touch()` | 가변 필드만 바꿨을 때 갱신 알림 |

`Ticket`과 `ArchiveFolder`는 **가변 객체**입니다. 필드를 직접 쓴 뒤 `touch()`를
부르는 방식이라, 시트에 저장 버튼이 따로 없고 고르는 즉시 반영됩니다.

---

## 사진 권한 설정

`image_picker`는 플랫폼 설정이 필요합니다.

`ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>티켓 포스터로 쓸 사진을 고릅니다.</string>
<key>NSCameraUsageDescription</key>
<string>티켓 포스터로 쓸 사진을 촬영합니다.</string>
```

안드로이드는 `compileSdk 34` 이상이면 추가 설정 없이 동작합니다.

---

## 함정 노트

이 프로젝트에서 실제로 터졌던 것들입니다. 같은 실수를 반복하지 않으려고 적어 둡니다.

**`Flexible`은 자리가 모자라면 겹칩니다.** `Flexible(child: Text(...))`에 남은
높이가 0이면, 프레임워크는 "높이 0"이라고 통보하지만 `Text`는 제 높이대로
그려집니다. 결과적으로 **다음 형제가 그 위에 겹쳐 찍힙니다.** 잘린 게 아니라
덮인 겁니다. 좁아질 수 있는 텍스트 묶음은 `Flexible` 대신 자연 높이로 두고
`FittedBox(fit: BoxFit.scaleDown)`으로 통째로 줄이세요.

**`await showDialog`는 다이얼로그가 사라지기 전에 풀립니다.** `Navigator.pop`이
불린 순간 `await`가 풀리지만 닫히는 애니메이션이 150ms 남아 있고, 그동안
`TextField`는 살아서 컨트롤러를 듣고 있습니다. 거기서 `controller.dispose()`를
부르면 `deactivate` 순회가 예외로 끊기고, 끝내 `assert(_dependents.isEmpty)`로
앱이 죽습니다. **컨트롤러는 항상 그걸 쓰는 `State`가 만들고 `State.dispose()`에서
버리세요.**

**`CrossAxisAlignment.stretch`는 스크롤 뷰 안에서 무한 높이를 부릅니다.**
세로 스크롤이 자식에게 주는 높이는 무한대라, stretch가 그대로 물리면 카드가
"높이 = 무한"이 됩니다. `AspectRatio`나 `SizedBox`로 높이를 못 박으세요.

**레이어 좌표는 픽셀이 아니라 캔버스 대비 0.0~1.0 비율입니다.** 기기 화면이
달라져도 배치가 유지되고, 그대로 서버에 올릴 수 있습니다.

**`posterPath`는 기기 로컬 캐시 경로입니다.** 앱을 재설치하면 사라지므로, 실제
저장 단계에서는 사진을 앱 문서 디렉터리로 복사해 두어야 합니다. 웹에서는
`Image.file`을 쓸 수 없어 색으로 폴백합니다.

**자이로는 없는 기기가 많습니다.** `sensors_plus` 호출을 `try/catch`로 감쌌고,
데스크톱·웹·시뮬레이터에서는 홀로그램이 정지 상태로 보입니다.

**접근성.** `MediaQuery.disableAnimations`가 켜져 있으면 티켓 플립과 폴더 열림
전환 둘 다 애니메이션을 건너뜁니다.

---

## 테스트

`test/widget_test.dart`의 스모크 테스트 5종:

1. 서랍 홈에 서류철이 목업 개수만큼 쌓인다
2. 서류철을 누르면 표지가 열리고 스크랩북이 나온다
3. 서류철을 새로 만들 수 있다 (`find.byTooltip('서류철 만들기')`)
4. 아래 탭바로 달력 · 내 기록으로 건너간다
5. 저장소가 폴더별 티켓을 걸러낸다

```bash
flutter test
```

---

## 로드맵

### Phase 1 — MVP (진행 중)

| 할 일 | 방법 |
|---|---|
| 로컬 저장 | `TicketStore`의 메서드 본문만 Hive/Isar로 교체 |
| 사진 영구 보관 | `posterPath`의 파일을 `getApplicationDocumentsDirectory()`로 복사 |
| 폴더 순서 편집 | `TicketStore._folders`에 reorder 메서드 추가, 홈에서 드래그 정렬 |
| ~~9:16 내보내기~~ | 완료 — `share_card_screen.dart` |
| ~~레이어 실행 취소~~ | 완료 — `editor_screen.dart` 스냅샷 스택 |

### Phase 2 — 구독 / 프리미엄

Articket Pro 평생 소장권, 앱 내 유료 에셋 IAP, 클라우드 백업.

### Phase 3 — C2C 크리에이터 마켓

Supabase 연동으로 템플릿·에셋 업로드/다운로드, 마켓플레이스 UI, 수수료 정산.
`ScrapLayer.encodeList`로 직렬화한 JSON을 `layers` 컬럼(jsonb)에 그대로 저장하면
됩니다.

---

## 기술 스택

| 층 | 선택 | 이유 |
|---|---|---|
| 프론트엔드 | Flutter | 복잡한 커스텀 페인팅과 3D 변환을 크로스 플랫폼으로 |
| 로컬 DB | Hive / Isar (예정) | 오프라인에서 즉시 열람 |
| 백엔드 | Supabase / PostgreSQL (Phase 3) | 인증 · 에셋 스토리지 · 마켓 결제 |