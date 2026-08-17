import 'package:flutter/material.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/index_tab.dart';
import '../widgets/paper.dart';
import 'folder_screen.dart';
import 'market_screen.dart';

/// 앱의 첫 화면. 미색 벽 앞에 서류철이 세로로 철해진 파일 드로어.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final store = TicketStore.instance;
  int? _lifted;

  static const _folderHeight = 156.0;
  static const _gap = 104.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final folders = store.folders;
                final stackHeight = (folders.length - 1) * _gap + _folderHeight;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                        child: _Header(total: store.tickets.length)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                        child: SizedBox(
                          height: stackHeight,
                          child: Stack(
                            children: [
                              for (var i = 0; i < folders.length; i++)
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutCubic,
                                  top: i * _gap,
                                  left: 0,
                                  right: 0,
                                  height: _folderHeight,
                                  child: FolderCard(
                                    folder: folders[i],
                                    count: store.countIn(folders[i].id),
                                    tabSlot: i % 3,
                                    totalSlots: 3,
                                    lifted: _lifted == i,
                                    preview: _previewColors(folders[i].id),
                                    onTap: () => _open(folders[i], i),
                                  ),
                                ),
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
          // 플라스터 벽 질감.
          const WallGrain(),
        ],
      ),
      bottomNavigationBar: const _BottomBar(),
    );
  }

  List<Color> _previewColors(String folderId) => store
      .ticketsIn(folderId)
      .take(3)
      .map((t) => t.posterTint.first)
      .toList();

  Future<void> _open(ArchiveFolder folder, int index) async {
    setState(() => _lifted = index);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FolderScreen(folder: folder)),
    );
    if (mounted) setState(() => _lifted = null);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.total});
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ARTICKET', style: AppText.eyebrow(color: AppColors.oxblood)),
              Text('$total FILED',
                  style: AppText.data(size: 10, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 18),
          Text('나의\n티켓북',
              style: AppText.display(size: 42, color: AppColors.ink)),
          const SizedBox(height: 16),
          // 미술관 캡션 플레이트처럼: 헤어라인 + 작은 안내.
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 10),
          Text('탭을 눌러 서류철을 엽니다',
              style: AppText.ui(size: 12, color: AppColors.inkSoft)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.stockLight,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              _item(context, Icons.folder_copy_outlined, '아카이브', true, null),
              _item(context, Icons.storefront_outlined, '마켓', false, () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MarketScreen()),
                );
              }),
              _item(context, Icons.calendar_today_outlined, '캘린더', false, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('문화 캘린더는 Phase 2에서 붙습니다')),
                );
              }),
              _item(context, Icons.person_outline, '내 정보', false, null),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, bool active,
      VoidCallback? onTap) {
    final color = active ? AppColors.oxblood : AppColors.inkSoft;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: AppText.ui(
                    size: 10,
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                    color: color)),
          ],
        ),
      ),
    );
  }
}