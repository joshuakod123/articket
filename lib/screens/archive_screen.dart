import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/folder_open_route.dart';
import '../widgets/folder_texture.dart';
import '../widgets/index_tab.dart';
import '../widgets/paper.dart';
import 'folder_screen.dart';
import 'folder_workbench.dart';

/// 앱의 첫 화면. 가로 서류철이 겹쳐 쌓인 파일 드로어.
///
/// 탭하면 표지가 젖혀 열리며 스크랩북으로 들어가고,
/// **길게 누르면 서류철이 책상 위로 뽑혀 나와**(작업대) 이름·서체·색·질감을
/// 그 자리에서 고칠 수 있습니다.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final store = TicketStore.instance;
  int? _lifted;

  /// 열림 전환에서 서류철의 화면 좌표를 읽기 위한 키.
  final _cardKeys = <String, GlobalKey>{};

  static const _folderHeight = FolderMetrics.cardHeight;
  static const _step = FolderMetrics.step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 서랍 안쪽. 위가 어둡고 아래로 갈수록 밝아지는 깊이감.
          const Positioned.fill(child: _DrawerBackdrop()),

          SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final folders = store.folders;
                final stackHeight =
                    (folders.length - 1).clamp(0, 999) * _step + _folderHeight;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(
                        folderCount: folders.length,
                        ticketCount: store.tickets.length,
                        lastFiled: _lastFiled(),
                        onAdd: _newFolder,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 56),
                        child: SizedBox(
                          height: stackHeight,
                          child: Stack(
                            children: [
                              // 겹친 경계마다 [접촉 그림자 → 서류철] 순서로 쌓습니다.
                              for (var i = 0; i < folders.length; i++) ...[
                                if (i > 0)
                                  Positioned(
                                    top: i * _step +
                                        FolderMetrics.tabHeight -
                                        24,
                                    left: 0,
                                    right: 0,
                                    height: 24,
                                    child: const LayerShadow(),
                                  ),
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  top: i * _step,
                                  left: 0,
                                  right: 0,
                                  height: _folderHeight,
                                  child: KeyedSubtree(
                                    key: _keyOf(folders[i].id),
                                    child: FolderCard(
                                      folder: folders[i],
                                      count: store.countIn(folders[i].id),
                                      tabSlot: i % 3,
                                      totalSlots: 3,
                                      fileNo: i + 1,
                                      lifted: _lifted == i,
                                      preview: store.ticketsIn(folders[i].id),
                                      onTap: () => _open(folders[i], i),
                                      onLongPress: () =>
                                          _editFolder(folders[i], i),
                                      onEdit: () =>
                                          _editFolder(folders[i], i),
                                    ),
                                  ),
                                ),
                              ],
                              if (folders.isEmpty) const _EmptyDrawer(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 종이 질감 한 겹.
          const WallGrain(opacity: 0.045),
        ],
      ),
    );
  }

  GlobalKey _keyOf(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  /// 가장 최근에 철해둔 날. 서랍 라벨에 찍습니다.
  DateTime? _lastFiled() {
    final ts = store.tickets;
    if (ts.isEmpty) return null;
    return ts.map((t) => t.visitedAt).reduce((a, b) => a.isAfter(b) ? a : b);
  }

  // ── 열기 (표지가 젖혀지는 전환) ─────────────────────

  Future<void> _open(ArchiveFolder folder, int index) async {
    setState(() => _lifted = index);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;

    // 누른 서류철의 화면 좌표를 읽습니다. 못 읽으면 기본 전환으로 갑니다.
    final box = _cardKeys[folder.id]?.currentContext?.findRenderObject()
    as RenderBox?;

    if (box == null || !box.hasSize) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FolderScreen(folder: folder)),
      );
    } else {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      await Navigator.of(context).push(
        FolderOpenRoute<void>(
          originRect: rect,
          cover: FolderCover(
            folder: folder,
            tabSlot: store.folders.indexOf(folder) % 3,
            totalSlots: 3,
          ),
          builder: (_) => FolderScreen(folder: folder),
        ),
      );
    }
    if (mounted) setState(() => _lifted = null);
  }

  // ── 서류철 관리 ─────────────────────────────────

  /// 길게 누르면 서류철이 책상 위로 뽑혀 나옵니다.
  Future<void> _editFolder(ArchiveFolder folder, int index) async {
    HapticFeedback.mediumImpact();
    setState(() => _lifted = index);

    await openFolderWorkbench(
      context,
      store: store,
      folder: folder,
      fileNo: index + 1,
      preview: store.ticketsIn(folder.id),
    );

    if (!mounted) return;
    setState(() => _lifted = null);
    // 파쇄된 서류철의 키는 정리합니다.
    if (store.folderById(folder.id) == null) _cardKeys.remove(folder.id);
  }

  Future<void> _newFolder() async {
    await openFolderWorkbench(
      context,
      store: store,
      fileNo: store.folders.length + 1,
    );
  }
}

/// 서랍 안쪽 배경.
///
/// 두 겹입니다. 아래는 위가 그늘지고 아래로 열리는 세로 그라디언트,
/// 위는 **전시장 벽을 위에서 비추는 조명**입니다. 미술관 벽이 균일하게
/// 밝은 경우는 없습니다. 위쪽 가운데가 살짝 뜨고 가장자리로 갈수록
/// 떨어져야 평면이 벽으로 읽힙니다.
class _DrawerBackdrop extends StatelessWidget {
  const _DrawerBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.bgDeep,
                    AppColors.bg,
                    AppColors.bg,
                  ],
                  stops: [0.0, 0.28, 1.0],
                ),
              ),
            ),
          ),
          // 표제 위로 떨어지는 조명.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -1.05),
                  radius: 1.25,
                  colors: [
                    Color(0x40FFF8EA),
                    Color(0x14FFF8EA),
                    Color(0x00FFF8EA),
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDrawer extends StatelessWidget {
  const _EmptyDrawer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 3,
            color: AppColors.line,
          ),
          const SizedBox(height: 16),
          Text('서랍이 비었네요',
              style: AppText.display(size: 20, color: AppColors.inkSoft)),
          const SizedBox(height: 6),
          Text('오른쪽 위 아이콘으로 서류철 만들기',
              style: AppText.ui(size: 12, color: AppColors.pulp)),
        ],
      ),
    );
  }
}

/// 화면 맨 위. **전시 도록의 표제지(title page)** 를 그대로 옮겼습니다.
///
/// 예전에는 로고 · 큰 제목 · 폴더 아이콘이 한 줄씩 쌓여 있어서, 예쁘긴 해도
/// "앱 헤더"였습니다. 도록이 표제지에서 쓰는 장치를 그대로 씁니다.
///
/// 1. **판권 줄** — 워드마크와 발행 연도(로마 숫자)를 가는 괘선으로 잇습니다.
/// 2. **이중 괘선** — 굵은 선 + 실선 한 가닥. 도록 표제지의 관용 표현입니다.
/// 3. **표제 + 원제** — 한글 큰 제목 아래 영문 부제를 자간 넓혀 깝니다.
///    미술관 벽 라벨이 한국어 제목 밑에 원제를 다는 방식입니다.
/// 4. **캡션 줄** — 소장 수량 · 최종 정리일. 도록의 판권 정보 자리입니다.
///
/// 새 서류철 버튼도 머티리얼 아이콘 대신 **황동 캡션 플레이트**로 바꿨습니다.
/// 이 화면에 머티리얼 아이콘은 이것 하나뿐이었고, 혼자만 다른 재질이었습니다.
class _Header extends StatelessWidget {
  const _Header({
    required this.folderCount,
    required this.ticketCount,
    required this.lastFiled,
    required this.onAdd,
  });

  /// 서랍에 꽂힌 서류철 수.
  final int folderCount;

  /// 그 안에 든 티켓 수.
  final int ticketCount;

  /// 마지막으로 철해둔 관람일. 없으면 라벨을 비웁니다.
  final DateTime? lastFiled;

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. 판권 줄 ──────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('ARTICKET',
                  style: AppText.wordmark(
                      size: 16, spacing: 7.5, color: AppColors.oxblood)),
              const SizedBox(width: 12),
              const Expanded(
                child: SizedBox(
                  height: 1,
                  child: ColoredBox(color: AppColors.line),
                ),
              ),
              const SizedBox(width: 12),
              Text(_roman(DateTime.now().year),
                  style: AppText.data(
                      size: 9, spacing: 2.2, color: AppColors.foil)),
            ],
          ),

          const SizedBox(height: 20),

          // ── 2. 이중 괘선 ────────────────────────────
          const _CatalogueRule(),

          const SizedBox(height: 20),

          // ── 3. 표제 ────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DebossedText(
                      '티켓 서랍',
                      depth: 0.32,
                      style: AppText.display(
                          size: 38, height: 1.12, color: AppColors.ink),
                    ),
                    const SizedBox(height: 9),
                    // 벽 라벨의 원제 자리. 한 글자씩 떨어뜨려 각인처럼 보이게.
                    Text('THE TICKET DRAWER',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.data(
                            size: 9.5,
                            spacing: 3.6,
                            color: AppColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _NewFilePlate(onTap: onAdd),
            ],
          ),

          const SizedBox(height: 20),

          // ── 4. 캡션 줄 ─────────────────────────────
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 11),
          // 좁은 화면에서 숫자가 길어져도 넘치지 않도록, 양쪽 묶음을
          // 각각 scaleDown 으로 감쌉니다. 잘리는 대신 아주 조금 작아집니다.
          Row(
            children: [
              const _FoilDot(),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$folderCount FILES',
                          style: AppText.data(
                              size: 9.5,
                              spacing: 1.4,
                              color: AppColors.inkSoft)),
                      Text('  ·  ',
                          style:
                          AppText.data(size: 9.5, color: AppColors.pulp)),
                      Text('$ticketCount TICKETS',
                          style: AppText.data(
                              size: 9.5,
                              spacing: 1.4,
                              color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (lastFiled != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('FILED',
                        style: AppText.data(
                            size: 8.5, spacing: 1.6, color: AppColors.pulp)),
                    const SizedBox(width: 6),
                    Text(
                      '${lastFiled!.year}.'
                          '${lastFiled!.month.toString().padLeft(2, '0')}.'
                          '${lastFiled!.day.toString().padLeft(2, '0')}',
                      style: AppText.data(
                          size: 9.5, spacing: 0.6, color: AppColors.foil),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '눌러서 펼치기 · 길게 누르면 고치기',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.hand(size: 17, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// 도록 표제지의 이중 괘선. 굵은 선 아래 가는 실선 한 가닥.
class _CatalogueRule extends StatelessWidget {
  const _CatalogueRule();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: 1.6, color: AppColors.ink.withValues(alpha: 0.78)),
        const SizedBox(height: 3.5),
        Container(height: 0.8, color: AppColors.ink.withValues(alpha: 0.30)),
      ],
    );
  }
}

/// 캡션 앞에 찍는 작은 황동 점.
class _FoilDot extends StatelessWidget {
  const _FoilDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.foil,
      ),
    );
  }
}

/// 새 서류철 버튼. 벽에 박힌 **황동 캡션 플레이트** 모양입니다.
///
/// 머티리얼 아이콘 대신 얇은 선 두 개로 십자를 직접 긋습니다. 이 화면의
/// 다른 선(괘선·절취선)과 같은 굵기라 재질이 어긋나지 않습니다.
class _NewFilePlate extends StatelessWidget {
  const _NewFilePlate({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Tooltip 은 접근성 라벨과 길게 누름 안내를 겸합니다.
    // (스모크 테스트도 `find.byTooltip('서류철 만들기')` 로 이 버튼을 찾습니다)
    return Tooltip(
      message: '서류철 만들기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.stock.withValues(alpha: 0.62),
            border: Border.all(color: AppColors.foil.withValues(alpha: 0.55)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B2F1E).withValues(alpha: 0.10),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _EngravedCross(color: AppColors.ink),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// 새김 십자. 가는 획 위아래로 명암을 한 겹씩 얹어 판에 판 것처럼 보이게.
class _EngravedCross extends CustomPainter {
  _EngravedCross({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 7.5;
    final c = Offset(size.width / 2, size.height / 2);

    void cross(Offset o, Color col, double w) {
      final p = Paint()
        ..color = col
        ..strokeWidth = w
        ..strokeCap = StrokeCap.butt;
      canvas.drawLine(
          Offset(c.dx - arm + o.dx, c.dy + o.dy),
          Offset(c.dx + arm + o.dx, c.dy + o.dy),
          p);
      canvas.drawLine(
          Offset(c.dx + o.dx, c.dy - arm + o.dy),
          Offset(c.dx + o.dx, c.dy + arm + o.dy),
          p);
    }

    // 파인 자국의 밝은 아래턱 → 그 위에 잉크 획.
    cross(const Offset(0, 1), Colors.white.withValues(alpha: 0.55), 1.1);
    cross(Offset.zero, color.withValues(alpha: 0.82), 1.1);
  }

  @override
  bool shouldRepaint(_EngravedCross old) => old.color != color;
}

/// 연도를 로마 숫자로. 도록 판권면의 관용 표기입니다. (2026 → MMXXVI)
String _roman(int year) {
  const table = <(int, String)>[
    (1000, 'M'),
    (900, 'CM'),
    (500, 'D'),
    (400, 'CD'),
    (100, 'C'),
    (90, 'XC'),
    (50, 'L'),
    (40, 'XL'),
    (10, 'X'),
    (9, 'IX'),
    (5, 'V'),
    (4, 'IV'),
    (1, 'I'),
  ];

  var left = year;
  final out = StringBuffer();
  for (final (value, glyph) in table) {
    while (left >= value) {
      out.write(glyph);
      left -= value;
    }
  }
  return out.toString();
}