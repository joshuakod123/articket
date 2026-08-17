import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';

/// 실제 서류철 모양. 상단 한쪽에 인덱스 탭이 돌출됩니다.
class FolderShape extends CustomClipper<Path> {
  FolderShape({
    required this.tabStart,
    required this.tabWidth,
    this.tabHeight = 30,
    this.radius = 10,
    this.slant = 10,
  });

  /// 탭이 시작되는 x 좌표(px).
  final double tabStart;
  final double tabWidth;
  final double tabHeight;
  final double radius;

  /// 탭 옆면 기울기. 서류철 특유의 사다리꼴 각도.
  final double slant;

  @override
  Path getClip(Size size) {
    final t = tabHeight;
    final r = radius;
    final x0 = tabStart;
    final x1 = tabStart + tabWidth;

    return Path()
      ..moveTo(x0, t)
      ..lineTo(x0 + slant, r)
      ..quadraticBezierTo(x0 + slant + 2, 0, x0 + slant + r + 2, 0)
      ..lineTo(x1 - slant - r - 2, 0)
      ..quadraticBezierTo(x1 - slant - 2, 0, x1 - slant, r)
      ..lineTo(x1, t)
      ..lineTo(size.width - r, t)
      ..quadraticBezierTo(size.width, t, size.width, t + r)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..lineTo(0, t + r)
      ..quadraticBezierTo(0, t, r, t)
      ..close();
  }

  @override
  bool shouldReclip(FolderShape old) =>
      old.tabStart != tabStart || old.tabWidth != tabWidth;
}

/// 아카이브 화면에 쌓이는 서류철 한 개.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.folder,
    required this.count,
    required this.tabSlot,
    required this.totalSlots,
    required this.onTap,
    this.lifted = false,
    this.preview = const [],
  });

  final ArchiveFolder folder;
  final int count;

  /// 탭이 붙는 가로 위치 슬롯. 서류철끼리 겹쳐도 라벨이 다 보이게 합니다.
  final int tabSlot;
  final int totalSlots;
  final VoidCallback onTap;
  final bool lifted;

  /// 폴더 몸통에 살짝 삐져나오는 티켓 미리보기 색상.
  final List<Color> preview;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const tabHeight = 30.0;
        final usable = c.maxWidth - 24;
        final tabWidth = (usable / totalSlots).clamp(88.0, 150.0);
        final tabStart = 12 + (tabSlot * (usable / totalSlots));

        return Semantics(
          button: true,
          label: '${folder.subtitle}, 티켓 $count장',
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, lifted ? -10 : 0, 0),
              decoration: BoxDecoration(boxShadow: paperShadow(depth: lifted ? 1.3 : 0.8)),
              child: ClipPath(
                clipper: FolderShape(
                  tabStart: tabStart,
                  tabWidth: tabWidth,
                  tabHeight: tabHeight,
                ),
                child: Stack(
                  children: [
                    // 서류철 몸통
                    Positioned.fill(
                      child: PaperSurface(
                        color: folder.color,
                        grain: 0.09,
                        seed: folder.id.hashCode,
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // 탭 라벨
                    Positioned(
                      left: tabStart + 16,
                      top: 8,
                      width: tabWidth - 32,
                      child: Text(
                        folder.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.data(
                          size: 9,
                          weight: FontWeight.w700,
                          color: AppColors.stockLight.withValues(alpha: .9),
                        ),
                      ),
                    ),

                    // 몸통 내용
                    Positioned(
                      left: 20,
                      right: 20,
                      top: tabHeight + 16,
                      bottom: 14,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.ui(
                                    size: 15,
                                    weight: FontWeight.w600,
                                    color: AppColors.stockLight,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  count == 0 ? '비어 있음' : '$count장 보관',
                                  style: AppText.data(
                                    size: 10,
                                    color: AppColors.stock.withValues(alpha: .6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 폴더에서 삐져나온 티켓 모서리
                          SizedBox(
                            width: 54,
                            height: 34,
                            child: Stack(
                              children: [
                                for (var i = 0; i < preview.length && i < 3; i++)
                                  Positioned(
                                    right: i * 13.0,
                                    top: i * 3.0,
                                    child: Transform.rotate(
                                      angle: -0.04 * i,
                                      child: Container(
                                        width: 26,
                                        height: 32 - i * 2.0,
                                        decoration: BoxDecoration(
                                          color: preview[i],
                                          borderRadius:
                                          BorderRadius.circular(2),
                                          border: Border.all(
                                            color: AppColors.ink
                                                .withValues(alpha: .25),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}