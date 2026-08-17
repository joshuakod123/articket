import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/index_tab.dart';
import '../widgets/paper.dart';
import 'folder_screen.dart';
import 'market_screen.dart';

/// 앱의 첫 화면.
///
/// 서류철을 눕혀 쌓는 대신, 실제 파일 캐비닛처럼 **세워 꽂아** 옆으로 넘깁니다.
/// 맨 앞에 아카이브 표지가 서 있고 그 뒤로 폴더들이 겹쳐 꽂힙니다.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final store = TicketStore.instance;
  int? _lifted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final folders = store.folders;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(total: store.tickets.length),
                    Expanded(child: _drawer(folders)),
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

  Widget _drawer(List<ArchiveFolder> folders) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = math.max(
          SpineMetrics.drawerWidth(folders.length),
          c.maxWidth,
        );

        return Stack(
          children: [
            // 서랍 안쪽의 그늘.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: 26,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.bgDeep,
                        AppColors.bgDeep.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                width: width,
                height: c.maxHeight,
                child: Stack(
                  children: [
                    // 오른쪽 서류철부터 그려서 왼쪽 것이 앞에 오게 합니다.
                    for (var i = folders.length - 1; i >= 0; i--)
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        left: SpineMetrics.xOf(i),
                        width: SpineMetrics.width,
                        top: 14 +
                            SpineMetrics.stagger(i) -
                            (_lifted == i ? 12 : 0),
                        bottom: 0,
                        child: FolderSpine(
                          folder: folders[i],
                          count: store.countIn(folders[i].id),
                          lifted: _lifted == i,
                          fileNo: i + 1,
                          photo: _photoOf(folders[i].id),
                          onTap: () => _open(folders[i], i),
                        ),
                      ),

                    // 표지는 맨 앞.
                    Positioned(
                      left: SpineMetrics.leftPad,
                      width: SpineMetrics.coverWidth,
                      top: 6,
                      bottom: 0,
                      child: ArchiveCover(
                        total: store.tickets.length,
                        folders: folders.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 서류철 사진 창에 쓸 색. 가장 최근 티켓의 포스터에서 가져옵니다.
  List<Color> _photoOf(String folderId) {
    final tickets = store.ticketsIn(folderId);
    if (tickets.isEmpty) return const [];
    return tickets.first.posterTint;
  }

  Future<void> _open(ArchiveFolder folder, int index) async {
    setState(() => _lifted = index);
    await Future<void>.delayed(const Duration(milliseconds: 170));
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
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
          const SizedBox(height: 12),
          Text('나의 티켓북',
              style: AppText.display(size: 34, color: AppColors.ink)),
          const SizedBox(height: 12),
          // 미술관 캡션 플레이트처럼: 헤어라인 + 작은 안내.
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 8),
          Text('옆으로 밀어 넘기고, 탭을 눌러 펼칩니다',
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