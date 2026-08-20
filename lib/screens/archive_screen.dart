import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/folder_open_route.dart';
import '../widgets/folder_texture.dart';
import '../widgets/index_tab.dart';
import '../widgets/masthead.dart';
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
                    // 표제지는 스크롤에 맞춰 접힙니다.
                    // 다 접히면 얇은 러닝 헤드 한 줄만 화면 위에 붙어 남습니다.
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: DrawerMasthead(
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