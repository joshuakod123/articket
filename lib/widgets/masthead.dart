import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'brand_logo.dart';
import 'paper.dart';

/// 서랍 화면 맨 위. **전시 도록의 표제지(title page)** 를 스크롤에 맞춰 접습니다.
///
/// ## 왜 접게 만들었나
///
/// 예전 표제지는 판권 줄 · 이중 괘선 · 표제 · 캡션 · 손글씨 안내까지 다섯 층이
/// 세로로 쌓여 있었습니다. 인쇄물로는 정확한 형식이지만, 화면에서는 **첫 화면의
/// 절반**을 표제가 먹고 정작 주인공인 서류철은 아래로 밀립니다.
/// 스크린샷에서 서류철이 세 개만 겨우 보이던 게 그 결과입니다.
///
/// 종이 도록은 표제지를 넘기면 사라집니다. 여기도 같게 했습니다.
/// 스크롤을 내리면 표제가 위로 밀려 올라가며 사라지고, 그 자리에
/// **얇은 러닝 헤드(running head)** 한 줄만 남습니다. 책의 판심에 인쇄된
/// 그 줄과 같은 역할입니다.
///
/// 접힌 줄에는 [PunchedWordmark]를 아주 작게 넣었습니다. 타공이 물린 워드마크는
/// 그 자체가 티켓 조각이라, 로고와 "지금 티켓 서랍에 있다"는 표시를 한 번에
/// 합니다. 아이콘을 따로 그릴 필요가 없어집니다.
///
/// ## 접히지 않는 것 하나
///
/// 새 서류철 버튼은 **양쪽 상태 모두에** 있습니다. 표제가 접힌 뒤에 버튼이
/// 사라지면, 서류철을 만들려고 맨 위까지 다시 올라가야 합니다.
/// 투명도가 0인 쪽은 [IgnorePointer]로 눌러도 반응하지 않게 막았습니다.
/// (이걸 빼먹으면 보이지 않는 버튼이 화면 위쪽 터치를 가로챕니다)
class DrawerMasthead extends SliverPersistentHeaderDelegate {
  DrawerMasthead({
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

  /// 다 펼쳤을 때 높이. 표제 다섯 층이 들어갑니다.
  @override
  double get maxExtent => 258;

  /// 접혔을 때 남는 러닝 헤드 한 줄.
  @override
  double get minExtent => 60;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final range = maxExtent - minExtent;
    final t = range <= 0 ? 0.0 : (shrinkOffset / range).clamp(0.0, 1.0);

    // 표제는 접힘의 **앞쪽 3/4** 에서 다 사라집니다. 러닝 헤드는 **뒤쪽 절반**에서
    // 나타납니다. 구간을 겹치지 않게 떼어 놓아야 둘이 동시에 흐릿하게 겹쳐
    // 보이는 구간이 없습니다.
    final titleFade = (1 - t / 0.75).clamp(0.0, 1.0);
    final headFade = ((t - 0.5) / 0.5).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 접힐수록 바탕이 조금 짙어집니다. 아래 내용과 헤더가 붙어 보이지
          // 않도록 하는 최소한의 구분입니다.
          Positioned.fill(
            child: ColoredBox(
              color: Color.lerp(
                  AppColors.bg.withValues(alpha: 0), AppColors.bgDeep, t * 0.85)!,
            ),
          ),

          // ── 펼친 표제 ─────────────────────────
          //
          // 스크롤 속도의 45% 로만 밀어 올립니다(패럴랙스). 1:1 로 밀면
          // 표제가 손가락에 붙어 딸려 나가는 것처럼 보입니다.
          Positioned(
            left: 0,
            right: 0,
            top: -shrinkOffset * 0.45,
            height: maxExtent,
            child: IgnorePointer(
              ignoring: titleFade < 0.4,
              child: Opacity(
                opacity: titleFade,
                child: _Expanded(
                  folderCount: folderCount,
                  ticketCount: ticketCount,
                  lastFiled: lastFiled,
                  onAdd: onAdd,
                ),
              ),
            ),
          ),

          // ── 접힌 러닝 헤드 ─────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: minExtent,
            child: IgnorePointer(
              ignoring: headFade < 0.4,
              child: Opacity(
                opacity: headFade,
                child: _RunningHead(count: folderCount, onAdd: onAdd),
              ),
            ),
          ),

          // 접힌 상태에서만 바닥에 괘선 한 줄.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: headFade,
              child: Container(height: 1, color: AppColors.line),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(DrawerMasthead old) =>
      old.folderCount != folderCount ||
          old.ticketCount != ticketCount ||
          old.lastFiled != lastFiled;
}

// ─────────────────────────────────────────────────
// 펼친 표제
// ─────────────────────────────────────────────────

class _Expanded extends StatelessWidget {
  const _Expanded({
    required this.folderCount,
    required this.ticketCount,
    required this.lastFiled,
    required this.onAdd,
  });

  final int folderCount;
  final int ticketCount;
  final DateTime? lastFiled;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // OverflowBox 로 감싸는 이유:
    // 이 위젯은 높이가 못 박힌 자리(Positioned height: maxExtent)에 들어갑니다.
    // 사용자가 시스템 글자 크기를 키우면 Column 이 그 높이를 넘기는데,
    // 그때 노란 줄무늬(RenderFlex overflow) 대신 조용히 잘리는 편이 낫습니다.
    // (바깥 ClipRect 가 잘라 줍니다)
    return OverflowBox(
      alignment: Alignment.topLeft,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. 판권 줄 ──────────────────────
            //
            // 밋밋한 텍스트였던 워드마크를 브랜드 락업(2a)으로 갈았습니다.
            // 타공이 물린 띠라서 이 줄 하나가 티켓 조각처럼 읽힙니다.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const PunchedWordmark(
                  scale: 0.36,
                  notchColor: AppColors.bg,
                  caption: '', // 캡션은 아래 표제가 대신합니다
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: SizedBox(
                      height: 1, child: ColoredBox(color: AppColors.line)),
                ),
                const SizedBox(width: 12),
                Text(romanYear(DateTime.now().year),
                    style: AppText.data(
                        size: 9, spacing: 2.2, color: AppColors.foil)),
              ],
            ),

            const SizedBox(height: 18),
            const CatalogueRule(),
            const SizedBox(height: 18),

            // ── 3. 표제 ────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DebossedText(
                        '티켓 서랍',
                        depth: 0.32,
                        style: AppText.display(
                            size: 36, height: 1.12, color: AppColors.ink),
                      ),
                      const SizedBox(height: 8),
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
                NewFilePlate(onTap: onAdd),
              ],
            ),

            const SizedBox(height: 18),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 10),

            // ── 4. 캡션 줄 ─────────────────────
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

            const SizedBox(height: 6),
            Text(
              '눌러서 펼치기 · 길게 누르면 고치기',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.hand(size: 17, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 접힌 러닝 헤드
// ─────────────────────────────────────────────────

class _RunningHead extends StatelessWidget {
  const _RunningHead({required this.count, required this.onAdd});

  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 14, 0),
      child: Row(
        children: [
          // 타공이 물린 워드마크 조각. 아이콘 대신입니다.
          const PunchedWordmark(
            scale: 0.24,
            notchColor: AppColors.bgDeep,
            caption: '',
          ),
          const SizedBox(width: 12),
          Text('티켓 서랍',
              style: AppText.display(
                  size: 15, height: 1.1, color: AppColors.ink)),
          const SizedBox(width: 10),
          Expanded(
            child: Container(height: 1, color: AppColors.line),
          ),
          const SizedBox(width: 10),
          Text('$count FILES',
              style: AppText.data(
                  size: 9, spacing: 1.4, color: AppColors.inkSoft)),
          const SizedBox(width: 8),
          NewFilePlate(onTap: onAdd, size: 34),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────
// 공통 조각 (예전 archive_screen 안에 있던 것들)
// ─────────────────────────────────────────────────

/// 도록 표제지의 이중 괘선. 굵은 선 아래 가는 실선 한 가닥.
class CatalogueRule extends StatelessWidget {
  const CatalogueRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
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
  Widget build(BuildContext context) => Container(
    width: 4,
    height: 4,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.foil,
    ),
  );
}

/// 새 서류철 버튼. 벽에 박힌 **황동 캡션 플레이트** 모양입니다.
///
/// 머티리얼 아이콘 대신 얇은 선 두 개로 십자를 직접 긋습니다. 이 화면의
/// 다른 선(괘선·절취선)과 같은 굵기라 재질이 어긋나지 않습니다.
class NewFilePlate extends StatelessWidget {
  const NewFilePlate({super.key, required this.onTap, this.size = 46});

  final VoidCallback onTap;
  final double size;

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
          width: size,
          height: size,
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
            painter: _EngravedCross(color: AppColors.ink, arm: size * 0.163),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// 새김 십자. 가는 획 위아래로 명암을 한 겹씩 얹어 판에 판 것처럼 보이게.
class _EngravedCross extends CustomPainter {
  _EngravedCross({required this.color, this.arm = 7.5});

  final Color color;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    void cross(Offset o, Color col, double w) {
      final p = Paint()
        ..color = col
        ..strokeWidth = w
        ..strokeCap = StrokeCap.butt;
      canvas.drawLine(Offset(c.dx - arm + o.dx, c.dy + o.dy),
          Offset(c.dx + arm + o.dx, c.dy + o.dy), p);
      canvas.drawLine(Offset(c.dx + o.dx, c.dy - arm + o.dy),
          Offset(c.dx + o.dx, c.dy + arm + o.dy), p);
    }

    // 파인 자국의 밝은 아래턱 → 그 위에 잉크 획.
    cross(const Offset(0, 1), Colors.white.withValues(alpha: 0.55), 1.1);
    cross(Offset.zero, color.withValues(alpha: 0.82), 1.1);
  }

  @override
  bool shouldRepaint(_EngravedCross old) =>
      old.color != color || old.arm != arm;
}

/// 연도를 로마 숫자로. 도록 판권면의 관용 표기입니다. (2026 → MMXXVI)
String romanYear(int year) {
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