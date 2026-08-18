import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'nav_icons.dart';
import 'paper.dart';

/// 아래 탭바.
///
/// 예전 구현은 고른 탭 자리에 흰 상자를 띄우고 그 **안에** 아이콘과 글자를
/// 넣었는데, 상자 크기가 내용에 따라 늘었다 줄었다 하면서 좁은 칸에서
/// 내용이 밀려 사라졌습니다(스크린샷의 빈 흰 상자가 그것입니다).
///
/// 여기서는 순서를 뒤집습니다. **고른 자리로 종이 인덱스 탭이 미끄러져 들어가고**,
/// 아이콘과 글자는 그 위에 항상 같은 자리에 놓입니다. 탭이 움직여도 글자는
/// 흔들리지 않고, 칸 폭은 늘 화면의 1/3로 고정입니다.
class ArticketNavBar extends StatelessWidget {
  const ArticketNavBar({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  /// (심볼, 한글 이름, 영문 정리 라벨)
  static const items = <(NavSymbol, String, String)>[
    (NavSymbol.drawer, '서랍', 'DRAWER'),
    (NavSymbol.calendar, '달력', 'CALENDAR'),
    (NavSymbol.member, '내 기록', 'RECORD'),
  ];

  /// 탭 본체 높이. 아래 홈 인디케이터 여백은 여기에 더해집니다.
  static const barHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: barHeight + safeBottom,
      child: Stack(
        children: [
          // 1) 종이 바탕. 서랍 바닥에 깔린 마닐라지.
          Positioned.fill(
            child: PaperSurface(
              color: AppColors.stock,
              grain: 0.05,
              fiber: 0.6,
              seed: 12,
              child: const SizedBox.expand(),
            ),
          ),

          // 2) 위쪽 두 줄. 잉크 헤어라인 + 황동 한 줄.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 1, child: ColoredBox(color: AppColors.line)),
                SizedBox(
                  height: 1.2,
                  child: ColoredBox(color: Color(0x448C7134)),
                ),
              ],
            ),
          ),

          // 3) 탭 세 칸.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: barHeight,
            child: LayoutBuilder(
              builder: (context, c) {
                final slot = c.maxWidth / items.length;

                return Stack(
                  children: [
                    // 고른 칸으로 미끄러져 들어가는 종이 인덱스 탭.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      left: slot * index + slot * 0.14,
                      width: slot * 0.72,
                      top: 2,
                      height: barHeight - 2,
                      child: const IgnorePointer(
                        child: CustomPaint(painter: _IndexTabPainter()),
                      ),
                    ),

                    Row(
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavItem(
                              symbol: items[i].$1,
                              label: items[i].$2,
                              code: items[i].$3,
                              active: i == index,
                              onTap: () {
                                if (i == index) return;
                                HapticFeedback.selectionClick();
                                onTap(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 고른 자리에 솟는 종이 탭. 위가 좁은 사다리꼴이고 윗변만 황동으로 눌렀습니다.
class _IndexTabPainter extends CustomPainter {
  const _IndexTabPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = 7.0; // 위쪽이 좁아지는 정도.
    const r = 6.0;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(inset, r + 2)
      ..quadraticBezierTo(inset + 1, 0, inset + r + 1, 0)
      ..lineTo(size.width - inset - r - 1, 0)
      ..quadraticBezierTo(size.width - inset - 1, 0, size.width - inset, r + 2)
      ..lineTo(size.width, size.height)
      ..close();

    // 종이.
    canvas.drawPath(path, Paint()..color = AppColors.stockLight);

    // 옆면 헤어라인.
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 윗변 황동. 라벨을 눌러 찍은 자국.
    canvas.drawLine(
      Offset(inset + 2, 0.9),
      Offset(size.width - inset - 2, 0.9),
      Paint()
        ..color = AppColors.foil
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // 종이가 위로 솟은 만큼 아래에 옅은 그늘.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 6, size.width, 6),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x14000000)],
        ).createShader(Rect.fromLTWH(0, size.height - 6, size.width, 6)),
    );
  }

  @override
  bool shouldRepaint(_IndexTabPainter old) => false;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.symbol,
    required this.label,
    required this.code,
    required this.active,
    required this.onTap,
  });

  final NavSymbol symbol;
  final String label;
  final String code;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.oxblood : AppColors.inkSoft;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            const SizedBox(height: 4),
            NavIcon(symbol: symbol, color: color, size: 21, filled: active),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: AppText.ui(
                size: 10,
                height: 1.0,
                weight: active ? FontWeight.w600 : FontWeight.w400,
                color: color,
                spacing: 0.3,
              ),
            ),
            const SizedBox(height: 3),
            // 고른 탭에만 정리 번호가 찍힙니다.
            SizedBox(
              height: 8,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: active ? 1 : 0,
                child: Text(
                  code,
                  maxLines: 1,
                  softWrap: false,
                  style: AppText.data(
                    size: 6.5,
                    height: 1.0,
                    spacing: 1.4,
                    color: AppColors.foil,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}