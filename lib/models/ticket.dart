import 'package:flutter/material.dart';

import '../theme/folder_style.dart';
import 'layer.dart';

/// 티켓 실루엣 프리셋.
///
/// [aspect]는 가로/세로 비율(width / height), [flexPoster]는 포스터가 차지하는 비중,
/// [horizontal]은 정보를 옆에 붙일지 아래에 붙일지 결정합니다.
enum TicketFrame {
  classic('클래식', '아래 스텁 + 좌우 타공', 0.58, 68, false),
  stub('가로 스텁', '오른쪽 절취선', 1.75, 66, true),
  receipt('영수증', '길고 좁은 · 아래가 찢김', 0.44, 40, false),
  filmStrip('필름', '양옆 퍼포레이션', 0.62, 78, false),
  stamp('우표', '사방 스캘럽 테두리', 0.74, 72, false),
  minimal('미니멀', '절취선 없는 카드', 0.66, 80, false);

  const TicketFrame(
      this.label,
      this.hint,
      this.aspect,
      this.flexPoster,
      this.horizontal,
      );

  final String label;
  final String hint;
  final double aspect;
  final int flexPoster;
  final bool horizontal;

  /// 절취선을 그릴지. 미니멀·우표·필름은 없습니다.
  bool get hasPerforation =>
      this == TicketFrame.classic ||
          this == TicketFrame.stub ||
          this == TicketFrame.receipt;

  /// 우표는 흰 여백 안에 포스터가 액자처럼 들어갑니다.
  bool get matted => this == TicketFrame.stamp;

  static TicketFrame parse(String? name) => TicketFrame.values.firstWhere(
        (f) => f.name == name,
    orElse: () => TicketFrame.classic,
  );
}

/// 포스터 색 프리셋. 사진을 올리지 않았을 때 쓰는 배경입니다.
class PosterPalette {
  const PosterPalette(this.name, this.colors);

  final String name;
  final List<Color> colors;

  static const presets = <PosterPalette>[
    // 붉은 계열
    PosterPalette('심야 극장', [Color(0xFF6E1F1B), Color(0xFF2A1210)]),
    PosterPalette('선셋', [Color(0xFFD2643A), Color(0xFF5A1E14)]),
    PosterPalette('벽돌', [Color(0xFFA24A38), Color(0xFF3A1712)]),
    PosterPalette('장밋빛', [Color(0xFFC98A86), Color(0xFF6B3A3A)]),
    PosterPalette('말린 장미', [Color(0xFF8E5C5C), Color(0xFF2E1A1C)]),

    // 푸른 계열
    PosterPalette('미드나잇', [Color(0xFF2E3B4E), Color(0xFF121821)]),
    PosterPalette('청자', [Color(0xFF7FA6A0), Color(0xFF23383A)]),
    PosterPalette('심해', [Color(0xFF1E3A44), Color(0xFF08151A)]),
    PosterPalette('하늘 인쇄', [Color(0xFF9FB8CC), Color(0xFF41586C)]),
    PosterPalette('군청', [Color(0xFF34406E), Color(0xFF141833)]),

    // 초록 계열
    PosterPalette('올리브 아카이브', [Color(0xFF3F4A3C), Color(0xFF1A1F19)]),
    PosterPalette('세이지', [Color(0xFF6E8B7A), Color(0xFF24312A)]),
    PosterPalette('이끼', [Color(0xFF55603A), Color(0xFF20240F)]),
    PosterPalette('전나무', [Color(0xFF2C4438), Color(0xFF0E1A15)]),

    // 노랑·갈색 계열
    PosterPalette('황동 인쇄', [Color(0xFFB08B3E), Color(0xFF4A3417)]),
    PosterPalette('크라프트', [Color(0xFF7A5C48), Color(0xFF3A2A20)]),
    PosterPalette('감귤', [Color(0xFFD9973A), Color(0xFF6B4413)]),
    PosterPalette('모래', [Color(0xFFCDB68C), Color(0xFF6F5C3C)]),
    PosterPalette('카라멜', [Color(0xFF9A6B3C), Color(0xFF3B2413)]),

    // 보라 계열
    PosterPalette('자수정', [Color(0xFF3B2E5A), Color(0xFF15102A)]),
    PosterPalette('라벤더 홀로', [Color(0xFFB8A9D9), Color(0xFF5A4A7A)]),
    PosterPalette('포도', [Color(0xFF5A3A62), Color(0xFF1E1226)]),

    // 무채색
    PosterPalette('잉크', [Color(0xFF3A3430), Color(0xFF0D0B0A)]),
    PosterPalette('뉴스프린트', [Color(0xFFC9C2B2), Color(0xFF6E6A5E)]),
    PosterPalette('은염', [Color(0xFF8E8E88), Color(0xFF2B2B28)]),
    PosterPalette('백지', [Color(0xFFF2ECDD), Color(0xFFBFB49B)]),
    PosterPalette('먹', [Color(0xFF2A2A2A), Color(0xFF000000)]),
    PosterPalette('석고', [Color(0xFFDCD3C0), Color(0xFF8B8272)]),
  ];
}

/// 관람 기록 한 건 = 티켓 한 장.
class Ticket {
  Ticket({
    required this.id,
    required this.folderId,
    required this.title,
    required this.venue,
    required this.visitedAt,
    this.serial = '',
    this.genre = '미술',
    this.frame = TicketFrame.classic,
    this.rating = 0,
    this.oneLiner = '',
    this.note = '',
    this.companion = '',
    this.holographic = false,
    this.posterPath,
    this.px,
    this.py,
    this.pscale = 1.0,
    this.protation = 0.0,
    List<Color>? posterTint,
    List<ScrapLayer>? layers,
  })  : posterTint = posterTint ?? PosterPalette.presets.first.colors,
        layers = layers ?? [];

  final String id;
  String folderId;
  String title;
  String venue;
  DateTime visitedAt;

  /// 발권 번호(`AK-2026-014`). 고정폭으로 렌더링합니다.
  ///
  /// **여기에 직접 쓰지 마세요.** 이 값은 [TicketStore]가 티켓 목록 전체를 보고
  /// 다시 매깁니다(`lib/data/serial.dart` 참고). 만들 때 비워두면 됩니다.
  /// 종이 결·바코드처럼 "변하면 안 되는" 씨앗은 [serial]이 아니라 [id]를 씁니다.
  String serial;

  String genre;
  TicketFrame frame;

  int rating;
  String oneLiner;
  String note;
  String companion;
  bool holographic;

  /// 사용자가 고른 사진의 로컬 경로. null이면 [posterTint]로 칠합니다.
  String? posterPath;

  /// 사진이 없을 때 쓰는 그라디언트.
  List<Color> posterTint;

  /// 티켓 위에 붙인 스티커·글자·테이프·폴라로이드.
  final List<ScrapLayer> layers;

  // ── 스크랩북 페이지에서의 자리 ───────────────────
  //
  // 서류철이 자유 배치(`ArchiveFolder.freeLayout`)일 때만 씁니다.
  // 자동 배치에서는 무시되고, 자동으로 되돌리면 다시 null로 비웁니다.

  /// 페이지 대비 가로 위치(0.0~1.0). null이면 아직 손대지 않은 것이고,
  /// `defaultTicketPlacement(index)`가 정해준 자리에 놓입니다.
  ///
  /// 픽셀이 아니라 비율이라 기기 화면이 달라져도 배치가 유지됩니다.
  double? px;

  /// 페이지 대비 세로 위치(0.0~1.0).
  double? py;

  /// 자유 배치에서 사용자가 키운 배율.
  double pscale;

  /// 자유 배치에서 사용자가 돌린 각도(라디안).
  double protation;

  bool get hasPhoto => posterPath != null && posterPath!.isNotEmpty;

  /// 자유 배치에서 사용자가 자리를 잡아둔 티켓인지.
  bool get isPlaced => px != null && py != null;

  String get dateLabel =>
      '${visitedAt.year}.${_two(visitedAt.month)}.${_two(visitedAt.day)}';

  String get shortDate => '${_two(visitedAt.month)}/${_two(visitedAt.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 로컬 DB나 서버로 옮길 때 쓸 직렬화.
  /// enum은 인덱스가 아니라 **이름**으로 저장합니다(항목 순서가 바뀌어도 안전).
  Map<String, dynamic> toJson() => {
    'id': id,
    'folderId': folderId,
    'title': title,
    'venue': venue,
    'visitedAt': visitedAt.toIso8601String(),
    'serial': serial,
    'genre': genre,
    'frame': frame.name,
    'rating': rating,
    'oneLiner': oneLiner,
    'note': note,
    'companion': companion,
    'holographic': holographic,
    'posterPath': posterPath,
    'posterTint': posterTint.map((c) => c.toARGB32()).toList(),
    'px': px,
    'py': py,
    'pscale': pscale,
    'protation': protation,
    'layers': ScrapLayer.encodeList(layers),
  };

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
    id: j['id'] as String,
    folderId: j['folderId'] as String,
    title: j['title'] as String? ?? '',
    venue: j['venue'] as String? ?? '',
    visitedAt: DateTime.parse(j['visitedAt'] as String),
    serial: j['serial'] as String? ?? '',
    genre: j['genre'] as String? ?? '미술',
    frame: TicketFrame.parse(j['frame'] as String?),
    rating: j['rating'] as int? ?? 0,
    oneLiner: j['oneLiner'] as String? ?? '',
    note: j['note'] as String? ?? '',
    companion: j['companion'] as String? ?? '',
    holographic: j['holographic'] as bool? ?? false,
    posterPath: j['posterPath'] as String?,
    px: (j['px'] as num?)?.toDouble(),
    py: (j['py'] as num?)?.toDouble(),
    pscale: (j['pscale'] as num?)?.toDouble() ?? 1.0,
    protation: (j['protation'] as num?)?.toDouble() ?? 0.0,
    posterTint: (j['posterTint'] as List?)
        ?.map((v) => Color(v as int))
        .toList(),
    layers: j['layers'] == null
        ? null
        : ScrapLayer.decodeList(j['layers'] as String),
  );
}

/// 인덱스 탭 하나 = 서류철 하나.
///
/// 이름·라벨·색에 더해 **서체([font])와 표지 질감([texture])** 까지 가변입니다.
/// 한 번 만들고 못 바꾸던 값이 없도록 전부 `final`을 떼어냈습니다.
class ArchiveFolder {
  ArchiveFolder({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.color,
    this.font = FolderFont.dymo,
    this.texture = FolderTexture.kraft,
    this.freeLayout = false,
    List<ScrapLayer>? pageLayers,
  }) : pageLayers = pageLayers ?? [];

  final String id;
  String label;
  String subtitle;
  Color color;
  FolderFont font;
  FolderTexture texture;

  /// 스크랩북 페이지에 티켓을 어떻게 놓을지.
  ///
  /// - `false` — 자동 배치. 티켓이 두 장씩 테이프로 붙고 옆에 손글씨 메모가 붙습니다.
  /// - `true` — 자유 배치. 사용자가 꾸미기 화면에서 직접 앉힌 자리
  ///   ([Ticket.px] / [Ticket.py])에 그대로 그립니다.
  ///
  /// 꾸미기 화면에서 티켓을 처음 끌면 자동으로 `true`가 됩니다.
  bool freeLayout;

  /// 스크랩북 **페이지 배경**에 붙인 것들. 티켓이 아니라 서류철에 딸립니다.
  /// 티켓을 지워도 남고, 페이지를 넘겨도 같은 장식이 깔립니다.
  final List<ScrapLayer> pageLayers;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'subtitle': subtitle,
    'color': color.toARGB32(),
    'font': font.name,
    'texture': texture.name,
    'freeLayout': freeLayout,
    'pageLayers': ScrapLayer.encodeList(pageLayers),
  };

  factory ArchiveFolder.fromJson(Map<String, dynamic> j) => ArchiveFolder(
    id: j['id'] as String,
    label: j['label'] as String? ?? '',
    subtitle: j['subtitle'] as String? ?? '',
    color: Color(j['color'] as int),
    font: FolderFont.parse(j['font'] as String?),
    texture: FolderTexture.parse(j['texture'] as String?),
    freeLayout: j['freeLayout'] as bool? ?? false,
    pageLayers: j['pageLayers'] == null
        ? null
        : ScrapLayer.decodeList(j['pageLayers'] as String),
  );
}