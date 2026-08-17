import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';

/// 가로 서류철 실루엣. 위쪽 한 자리에 인덱스 탭이 돌출됩니다.
class FolderShape extends CustomClipper<Path> {
  FolderShape({
    required this.tabStart,
    required this.tabWidth,
    this.tabHeight = 34,
    this.radius = 12,
    this.slant = 12,
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
    final x0 = tabStart.clamp(0.0, size.width - tabWidth);
    final x1 = x0 + tabWidth;

    return Path()
      ..moveTo(x0, t)
      ..lineTo(x0 + slant, r)
      ..quadraticBezierTo(x0 + slant + 2, 0, x0 + slant + r + 2, 0)
      ..lineTo(x1 - slant - r - 2, 0)
      ..quadraticBezierTo(x1 - slant - 2, 0, x1 - slant, r)
      ..lineTo(x1, t)
      ..lineTo(size.width - r, t)
      ..quadraticBezierTo(size.width, t, size.width, t + r)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, t + r)
      ..quadraticBezierTo(0, t, r, t)
      ..close();
  }

  @override
  bool shouldReclip(FolderShape old) =>
      old.tabStart != tabStart ||
          old.tabWidth != tabWidth ||
          old.tabHeight != tabHeight;
}

/// 서랍에 겹쳐 쌓인 가로 서류철 한 장.
///
/// 탭에는 손글씨 이름, 몸통 왼쪽에는 폴라로이드가 삐져나오고
/// 오른쪽에 라벨과 보관 수가 찍힙니다. 아래 서류철이 몸통을 덮어
/// 위쪽 띠만 보이는 걸 전제로 배치했습니다.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.folder,
    required this.count,
    required this.tabSlot,
    required this.totalSlots,
    required this.onTap,
    this.onLongPress,
    this.lifted = false,
    this.photo = const [],
    this.fileNo = 1,
  });

  final ArchiveFolder folder;
  final int count;

  /// 탭이 붙는 가로 위치 슬롯. 서류철끼리 겹쳐도 탭이 다 보이게 합니다.
  final int tabSlot;
  final int totalSlots;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// 눌린 순간 살짝 뽑혀 올라옵니다.
  final bool lifted;

  /// 폴라로이드에 채울 그라디언트. 최근 티켓의 포스터 색.
  final List<Color> photo;

  /// 몸통 오른쪽에 찍히는 정리 번호.
  final int fileNo;

  static const tabHeight = 34.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final usable = c.maxWidth - 24;
        final tabWidth = (usable / totalSlots).clamp(110.0, 170.0);
        final tabStart = 12 + (tabSlot * (usable / totalSlots));

        return Semantics(
          button: true,
          label: '${folder.subtitle}, 티켓 $count장',
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, lifted ? -10 : 0, 0),
              // PhysicalShape가 실루엣 그대로 그림자를 떨어뜨립니다.
              child: PhysicalShape(
                clipper: FolderShape(
                  tabStart: tabStart,
                  tabWidth: tabWidth,
                  tabHeight: tabHeight,
                ),
                color: folder.color,
                shadowColor: const Color(0xFF3B2F1E),
                elevation: lifted ? 15 : 7,
                child: Stack(
                  children: [
                    // 서류철 표면의 결.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: GrainPainter(
                                opacity: 0.1, seed: folder.id.hashCode),
                          ),
                        ),
                      ),
                    ),

                    // 몸통 상단 모서리의 빛. 종이 두께를 만듭니다.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: tabHeight,
                      height: 2,
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                      ),
                    ),

                    // 탭에 쓴 손글씨 이름.
                    Positioned(
                      left: tabStart + 20,
                      top: 3,
                      width: tabWidth - 40,
                      height: tabHeight - 6,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          folder.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: AppText.hand(
                            size: 19,
                            color: AppColors.stockLight,
                          ),
                        ),
                      ),
                    ),

                    // 삐져나온 폴라로이드.
                    Positioned(
                      left: 18,
                      top: tabHeight + 14,
                      child: _Polaroid(
                        colors: photo,
                        seed: folder.id.hashCode,
                        angle: (fileNo.isOdd ? -1 : 1) * 0.055,
                      ),
                    ),

                    // 라벨 · 보관 수.
                    Positioned(
                      left: 106,
                      right: 16,
                      top: tabHeight + 18,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.data(
                              size: 9,
                              spacing: 2.2,
                              weight: FontWeight.w700,
                              color:
                              AppColors.stockLight.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            count == 0 ? '비어 있음' : '$count장 보관',
                            style: AppText.data(
                              size: 9,
                              color:
                              AppColors.stockLight.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 오른쪽 끝 정리 번호.
                    Positioned(
                      right: 14,
                      top: tabHeight + 18,
                      child: Text(
                        'FILE_${fileNo.toString().padLeft(2, '0')}',
                        style: AppText.data(
                          size: 8,
                          spacing: 1.4,
                          color: AppColors.stockLight.withValues(alpha: 0.35),
                        ),
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

/// 서류철에 끼워 삐져나온 폴라로이드 한 장.
class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.colors,
    required this.seed,
    this.angle = -0.05,
  });

  final List<Color> colors;
  final int seed;
  final double angle;

  @override
  Widget build(BuildContext context) {
    final fill = colors.isEmpty
        ? [AppColors.pulp, AppColors.inkSoft]
        : (colors.length >= 2 ? colors : [colors.first, AppColors.ink]);

    return IgnorePointer(
      child: Transform.rotate(
        angle: angle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 13),
          decoration: BoxDecoration(
            color: AppColors.stockLight,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 7,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            width: 58,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: fill,
              ),
            ),
            child: colors.isEmpty
                ? Center(
              child: Text(
                'NO FILM',
                style: AppText.data(
                  size: 6,
                  spacing: 1.4,
                  color: AppColors.stockLight.withValues(alpha: 0.7),
                ),
              ),
            )
                : IgnorePointer(
              child: CustomPaint(
                painter: GrainPainter(opacity: 0.06, seed: seed + 3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 폴더 열기 전환에 쓰는 표지 복제본.
///
/// [FolderCard]와 같은 실루엣이지만 제스처 없이 그림만 그립니다.
/// 열리는 동안 위로 젖혀지며 사라집니다.
class FolderCover extends StatelessWidget {
  const FolderCover({
    super.key,
    required this.folder,
    required this.tabSlot,
    required this.totalSlots,
  });

  final ArchiveFolder folder;
  final int tabSlot;
  final int totalSlots;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final usable = c.maxWidth - 24;
        final tabWidth = (usable / totalSlots).clamp(110.0, 170.0);
        final tabStart = 12 + (tabSlot * (usable / totalSlots));

        return PhysicalShape(
          clipper: FolderShape(
            tabStart: tabStart,
            tabWidth: tabWidth,
            tabHeight: FolderCard.tabHeight,
          ),
          color: folder.color,
          shadowColor: const Color(0xFF3B2F1E),
          elevation: 12,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter:
                    GrainPainter(opacity: 0.1, seed: folder.id.hashCode),
                  ),
                ),
              ),
              Positioned(
                left: tabStart + 20,
                top: 3,
                width: tabWidth - 40,
                height: FolderCard.tabHeight - 6,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    folder.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style:
                    AppText.hand(size: 19, color: AppColors.stockLight),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}