import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../services/guide_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/coach_marks.dart';
import '../widgets/folder_open_route.dart';
import '../widgets/index_tab.dart';
import '../widgets/masthead.dart';
import '../widgets/paper.dart';
import '../widgets/stub_button.dart';
import 'folder_screen.dart';
import 'folder_workbench.dart';
import 'onboarding/welcome_tour.dart';

/// 앱의 첫 화면. 가로 서류철이 겹쳐 쌓인 파일 드로어.
///
/// 탭하면 표지가 젖혀 열리며 스크랩북으로 들어가고,
/// **길게 누르면 서류철이 책상 위로 뽑혀 나와**(작업대) 이름·서체·색·질감을
/// 그 자리에서 고칠 수 있습니다.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, this.navBarKey, this.active = true});

  /// 하단 탭바의 키. 첫 안내에서 그 자리를 도려내는 데 씁니다.
  /// (`RootShell`이 소유합니다)
  final GlobalKey? navBarKey;

  /// 지금 이 화면이 보이는 탭인가. 안내를 띄울지 판단하는 데만 씁니다.
  final bool active;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final store = TicketStore.instance;
  int? _lifted;

  /// 열림 전환에서 서류철의 화면 좌표를 읽기 위한 키.
  final _cardKeys = <String, GlobalKey>{};

  /// 첫 안내가 도려낼 "새 서류철" 버튼.
  final _newFileKey = GlobalKey();

  /// 안내가 두 번 겹쳐 뜨지 않게 하는 빗장.
  bool _guiding = false;

  static const _folderHeight = FolderMetrics.cardHeight;
  static const _step = FolderMetrics.step;

  @override
  void initState() {
    super.initState();
    // 설정의 "앱 안내 다시 보기"는 표시만 지웁니다. 이 화면은
    // `IndexedStack` 안에 계속 살아 있어서 `initState`가 다시 돌지 않으므로,
    // 표시가 지워졌다는 소식을 여기서 직접 받습니다.
    GuideService.instance.addListener(_onGuideChanged);
    // 첫 프레임이 그려진 **뒤**여야 합니다. 버튼과 탭바의 좌표를 읽어야
    // 하는데, 아직 레이아웃 전이면 좌표가 없습니다.
    _scheduleGuide();
  }

  @override
  void didUpdateWidget(ArchiveScreen old) {
    super.didUpdateWidget(old);
    // 다른 탭에 있다가 서랍으로 돌아왔을 때.
    if (!old.active && widget.active) _scheduleGuide();
  }

  @override
  void dispose() {
    GuideService.instance.removeListener(_onGuideChanged);
    super.dispose();
  }

  void _onGuideChanged() {
    if (GuideService.instance.sawTour) return; // 되돌린 게 아니라 진행된 것
    _scheduleGuide();
  }

  void _scheduleGuide() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _runGuideIfNeeded());
  }

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
                // 빈 서랍은 카드 한 장 높이로는 좁습니다. 안내 문구와
                // 버튼이 들어갈 자리를 따로 줍니다.
                final stackHeight = folders.isEmpty
                    ? 300.0
                    : (folders.length - 1).clamp(0, 999) * _step +
                    _folderHeight;

                return CustomScrollView(
                  slivers: [
                    // 표제지는 스크롤에 맞춰 접힙니다.
                    // 다 접히면 얇은 러닝 헤드 한 줄만 화면 위에 붙어 남습니다.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: DrawerMasthead(
                        folderCount: folders.length,
                        ticketCount: store.tickets.length,
                        lastFiled: _lastFiled(),
                        onAdd: _newFolder,
                        plateKey: _newFileKey,
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
                              if (folders.isEmpty)
                                _EmptyDrawer(onCreate: _newFolder),
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

  // ── 첫 안내 ─────────────────────────────────────
  //
  // 안내를 여기서 띄우는 이유: 서랍이 이 앱의 첫 화면이고, 코치 마크가
  // 가리켜야 하는 것(새 서류철 버튼 · 서류철 카드 · 탭바)이 전부 여기
  // 있습니다. `RootShell`에서 띄우면 좌표를 읽으려고 자식 화면의 키를
  // 위로 끌어올려야 합니다.

  Future<void> _runGuideIfNeeded() async {
    // 보이지 않는 탭 뒤에서 안내를 띄우면, 도려낼 버튼이 화면에 없어
    // 구멍이 엉뚱한 자리에 뚫립니다.
    if (!mounted || _guiding || !widget.active) return;
    _guiding = true;

    try {
      final guide = GuideService.instance;
      // 부팅에서 이미 읽었지만, 순서가 어긋나도 안전하게.
      await guide.load();

      if (!mounted) return;
      if (!guide.sawTour) {
        // `AppGate`가 로그인 화면 → 본 화면을 420ms 페이드로 갈아 끼웁니다.
        // 그 위에 투어를 곧바로 얹으면 두 페이드가 겹쳐 화면이 탁해집니다.
        // 서랍이 자리를 잡는 것을 한 번 보여준 뒤에 얹습니다.
        await Future<void>.delayed(const Duration(milliseconds: 520));
        if (!mounted) return;
        await showWelcomeTour(context);
        await guide.markTourSeen();
      }

      if (!mounted || guide.sawDrawerCoach) return;

      // 투어가 닫히는 전환이 끝나야 아래 화면의 좌표가 제자리입니다.
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;

      await showCoachMarks(context, steps: _coachSteps());
      await guide.markDrawerCoachSeen();
    } finally {
      _guiding = false;
    }
  }

  /// 서랍 화면의 코치 마크.
  ///
  /// 서류철이 **한 장도 없을 수 있습니다**(가입 직후가 정확히 그렇습니다).
  /// 그때는 서류철을 가리키는 단계를 넣지 않습니다. 없는 것을 가리키는
  /// 화살표만큼 사람을 헷갈리게 하는 것도 없습니다.
  List<CoachStep> _coachSteps() {
    final folders = store.folders;

    return [
      CoachStep(
        target: _newFileKey,
        eyebrow: 'STEP 01',
        title: '여기서 서류철을 만듭니다',
        body: folders.isEmpty
            ? '티켓은 서류철 안에 철합니다. 먼저 한 장 만드세요.\n'
            '"2026년", "미디어아트"처럼 마음대로 나누면 됩니다.'
            : '연도별로, 장르별로, 마음대로 나누세요.\n'
            '이름·색·서체·질감을 그 자리에서 고를 수 있습니다.',
        pad: const EdgeInsets.all(9),
        side: CoachSide.below,
      ),
      if (folders.isNotEmpty)
        CoachStep(
          target: _keyOf(folders.first.id),
          eyebrow: 'STEP 02',
          title: '눌러서 펼치고,\n길게 눌러 고치기',
          body: '표지를 누르면 스크랩북이 열립니다.\n'
              '길게 누르면 서류철이 책상 위로 뽑혀 나와, 이름과 색을 바로 고칠 수 있습니다.',
          pad: const EdgeInsets.fromLTRB(6, 6, 6, 0),
        ),
      CoachStep(
        target: widget.navBarKey,
        eyebrow: folders.isEmpty ? 'STEP 02' : 'STEP 03',
        title: '달력과 내 기록',
        body: '관람한 날은 달력에 도장처럼 남습니다.\n'
            '내 기록에는 회원증과 통계가 쌓이고, 오른쪽 위에서 설정으로 갑니다.',
        pad: EdgeInsets.zero,
        radius: 0,
        side: CoachSide.above,
      ),
    ];
  }

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

/// 빈 서랍.
///
/// 가입 직후에 **반드시** 보게 되는 화면입니다(예시 데이터를 더 이상 깔지
/// 않으므로). 그래서 "비었습니다"라고만 말하고 끝내면 안 됩니다. 빈 화면이
/// 할 일은 셋입니다.
///
/// 1. 지금 상태가 **정상**이라고 알려주기 — 고장이 아니라 아직 안 채운 것.
/// 2. **다음 한 걸음**을 손 닿는 데 두기 — 오른쪽 위 아이콘을 찾아 올라가게
///    하지 않고, 여기에 발권 버튼을 그대로 놓습니다.
/// 3. 왜 서류철이 먼저인지 한 줄로 — 티켓은 서류철 **안에** 철합니다.
class _EmptyDrawer extends StatelessWidget {
  const _EmptyDrawer({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라벨이 아직 안 붙은 빈 인덱스 탭 한 장.
          Container(width: 120, height: 3, color: AppColors.line),
          const SizedBox(height: 18),
          Text('서랍이 비었습니다',
              style: AppText.display(size: 21, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          Text(
            '티켓은 서류철 안에 철합니다.\n첫 서류철을 한 장 만들어 보세요.',
            textAlign: TextAlign.center,
            style:
            AppText.ui(size: 12.5, height: 1.7, color: AppColors.pulp),
          ),
          const SizedBox(height: 24),
          TicketStubButton(
            onPressed: onCreate,
            label: '첫 서류철 만들기',
            code: 'NEW',
            width: 224,
          ),
        ],
      ),
    );
  }
}