import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/folder_open_route.dart';
import '../widgets/folder_texture.dart';
import '../widgets/index_tab.dart';
import '../widgets/nav_icons.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import 'calendar_screen.dart';
import 'folder_screen.dart';
import 'folder_workbench.dart';
import 'profile_screen.dart';

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
      bottomNavigationBar: const _BottomBar(),
    );
  }

  GlobalKey _keyOf(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

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

/// 서랍 안쪽 배경. 위쪽은 그늘지고 아래로 열립니다.
class _DrawerBackdrop extends StatelessWidget {
  const _DrawerBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
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
        child: SizedBox.expand(),
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
          Text('빈 서랍입니다',
              style: AppText.display(size: 20, color: AppColors.inkSoft)),
          const SizedBox(height: 6),
          Text('오른쪽 위에서 서류철을 한 장 매세요',
              style: AppText.ui(size: 12, color: AppColors.pulp)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.folderCount,
    required this.ticketCount,
    required this.onAdd,
  });

  /// 서랍에 꽂힌 서류철 수.
  final int folderCount;

  /// 그 안에 든 티켓 수.
  final int ticketCount;

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 로고. 표지 각인처럼 자간을 벌리고 크기를 키웠습니다.
                Text('ARTICKET',
                    style: AppText.wordmark(size: 18, color: AppColors.oxblood)),
                // 예전에는 티켓 수만 'N FILED'로 찍혀서, 화면의 서류철 수와
                // 안 맞는 것처럼 보였습니다. 무엇을 센 숫자인지 밝힙니다.
                Text('$folderCount FILES · $ticketCount TICKETS',
                    style: AppText.data(size: 9.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DebossedText(
                  '나의 티켓북',
                  depth: 0.35,
                  style: AppText.display(size: 36, color: AppColors.ink),
                ),
              ),
              IconButton(
                tooltip: '서류철 만들기',
                onPressed: onAdd,
                icon: const Icon(Icons.create_new_folder_outlined,
                    size: 24, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1, color: AppColors.line),
                const SizedBox(height: 8),
                Text('탭하면 열리고, ⋯ 를 누르면 책상 위로 꺼내 고칩니다',
                    style: AppText.ui(size: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 아래 탭바.
///
/// 머티리얼 기본 탭바 대신 **서류철 인덱스 탭**을 눕혀놓은 모양입니다.
/// 고른 항목 뒤로 종이 탭이 한 장 솟아오르고, 위에는 황동 헤어라인이 지납니다.
/// 마켓은 아직 붙일 것이 없어 이번에 뺐습니다.
class _BottomBar extends StatefulWidget {
  const _BottomBar();

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  int _active = 0;

  static const _items = [
    (NavSymbol.stamp, '아카이브'),
    (NavSymbol.dateStamp, '캘린더'),
    (NavSymbol.pin, '내 정보'),
  ];

  Future<void> _go(int i) async {
    if (i == 0) return;
    setState(() => _active = i);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
        i == 1 ? const CalendarScreen() : const ProfileScreen(),
      ),
    );
    // 돌아오면 다시 아카이브가 활성입니다.
    if (mounted) setState(() => _active = 0);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.stock),
      child: Stack(
        children: [
          const WallGrain(opacity: 0.05, seed: 12),

          // 위쪽 두 줄. 얇은 잉크선 + 그 아래 황동 헤어라인.
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Column(
              children: [
                Divider(height: 1, thickness: 1, color: AppColors.line),
                SizedBox(
                  height: 1,
                  child: ColoredBox(color: Color(0x338C7134)),
                ),
              ],
            ),
          ),

          SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (var i = 0; i < _items.length; i++)
                    Expanded(
                      child: _Tab(
                        symbol: _items[i].$1,
                        label: _items[i].$2,
                        active: _active == i,
                        onTap: () => _go(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 탭 한 칸. 고르면 뒤로 종이 인덱스 탭이 솟습니다.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.symbol,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final NavSymbol symbol;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.oxblood : AppColors.inkSoft;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: active
                ? AppColors.stockLight
                : AppColors.stockLight.withValues(alpha: 0),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            border: Border(
              top: BorderSide(
                color: active ? AppColors.foil : Colors.transparent,
                width: 1.4,
              ),
              left: BorderSide(
                color: active ? AppColors.line : Colors.transparent,
              ),
              right: BorderSide(
                color: active ? AppColors.line : Colors.transparent,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NavIcon(symbol: symbol, color: color, size: 20, filled: active),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppText.ui(
                  size: 10,
                  weight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}