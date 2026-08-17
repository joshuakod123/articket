import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';
import 'scrapbook.dart' show WashiTape;
import 'ticket_card.dart';

/// 서류철 카드의 세로 배치. 화면과 위젯이 같은 값을 봐야 해서 한곳에 모읍니다.
class FolderMetrics {
  const FolderMetrics._();

  /// 인덱스 탭이 몸통 위로 돌출되는 높이.
  static const tabHeight = 34.0;

  /// 카드 한 장의 전체 높이.
  static const cardHeight = 178.0;

  /// 다음 서류철이 이만큼 아래에서 시작해 앞 서류철 몸통을 덮습니다.
  static const step = 150.0;

  /// 포켓(앞판) 윗변의 y 좌표. 티켓은 이 선 뒤로 들어갑니다.
  static const pocketTop = 116.0;
}

/// 가로 서류철 실루엣. 위쪽 한 자리에 사다리꼴 인덱스 탭이 돌출됩니다.
class FolderShape extends CustomClipper<Path> {
  FolderShape({
    required this.tabStart,
    required this.tabWidth,
    this.tabHeight = FolderMetrics.tabHeight,
    this.radius = 10,
    this.slant = 10,
  });

  final double tabStart;
  final double tabWidth;
  final double tabHeight;
  final double radius;

  /// 탭 옆면 기울기.
  final double slant;

  @override
  Path getClip(Size size) {
    final t = tabHeight;
    final r = radius;
    final x0 = clampDouble(
        tabStart, 0, clampDouble(size.width - tabWidth, 0, double.infinity));
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

/// 서류철 앞판(포켓). 윗변 가운데 오른쪽에 엄지 홈이 파여 있습니다.
class _PocketClipper extends CustomClipper<Path> {
  static const _notchR = 26.0;

  @override
  Path getClip(Size size) {
    final cx = size.width * 0.68;
    final body = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // 엄지 홈. 뒤에 꽂힌 티켓이 이 사이로 더 보입니다.
    final notch = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, 0), radius: _notchR));

    return Path.combine(PathOperation.difference, body, notch);
  }

  @override
  bool shouldReclip(_PocketClipper old) => false;
}

/// 다이모 라벨 테이프. 엠보싱된 검은 띠에 흰 대문자가 눌려 찍힙니다.
class DymoLabel extends StatelessWidget {
  const DymoLabel({super.key, required this.text, this.fontSize = 10});

  final String text;
  final double fontSize;

  /// 이 라벨이 차지할 폭. 탭 너비를 글자 길이에 맞추는 데 씁니다.
  static double widthOf(String text, {double fontSize = 10}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: AppText.dymo(size: fontSize)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width + 24;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.dymo,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 테이프 위쪽 광택.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 8,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: AppText.dymo(size: fontSize, color: AppColors.stockLight)
                .copyWith(
              shadows: [
                // 글자가 눌려 들어간 자국.
                const Shadow(
                    color: Colors.black54, offset: Offset(0, 1), blurRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 서랍에 겹쳐 꽂힌 가로 서류철 한 장.
///
/// 탭에는 다이모 라벨, 몸통에는 실제 티켓의 머리가 포켓 뒤로 삐져나옵니다.
/// 아래 서류철이 몸통 대부분을 덮는 걸 전제로 위쪽 150pt 안에 정보를 넣습니다.
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
    this.preview = const [],
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

  /// 포켓 뒤에서 머리만 내보일 실제 티켓들. 앞에서 3장까지 씁니다.
  final List<Ticket> preview;

  final int fileNo;

  /// 서류철 색이 밝으면 잉크로, 어두우면 종이색으로 찍습니다.
  Color get _onColor =>
      ThemeData.estimateBrightnessForColor(folder.color) == Brightness.dark
          ? AppColors.stockLight
          : AppColors.ink;

  Color get _pocketColor {
    final hsl = HSLColor.fromColor(folder.color);
    return hsl.withLightness(clampDouble(hsl.lightness * 0.88, 0, 1)).toColor();
  }

  /// 탭에 찍을 짧은 코드. 말줄임 없이 다 보이도록 길이를 줄여 씁니다.
  String get _code {
    var s = folder.label.replaceAll('/', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) s = 'FILE $fileNo';
    return s.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const tabHeight = FolderMetrics.tabHeight;

    return LayoutBuilder(
      builder: (context, c) {
        // 글자 길이에 맞춰 탭 너비를 잡습니다. 잘리지 않는 게 우선입니다.
        final labelWidth = DymoLabel.widthOf(_code);
        final tabWidth = clampDouble(
            labelWidth + 32, 104, clampDouble(c.maxWidth - 24, 104, 400));

        // 남는 폭을 슬롯 수로 나눠 탭 위치를 어긋나게 둡니다.
        final travel = clampDouble(c.maxWidth - 24 - tabWidth, 0, double.infinity);
        // 0이 아니라 0.0이어야 전체 식이 double로 잡힙니다(0이면 num이 되어 컴파일 에러).
        final tabStart =
            12 + (totalSlots <= 1 ? 0.0 : travel * tabSlot / (totalSlots - 1));

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
              child: PhysicalShape(
                clipper: FolderShape(tabStart: tabStart, tabWidth: tabWidth),
                color: folder.color,
                shadowColor: const Color(0xFF2A2016),
                elevation: lifted ? 16 : 9,
                child: Stack(
                  children: [
                    // 크라프트지 결.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: GrainPainter(
                              opacity: 0.13,
                              seed: folder.id.hashCode,
                              fiber: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 몸통 윗변의 종이 두께.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: tabHeight,
                      height: 1.5,
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                    ),

                    // 오른쪽 위 모서리에 붙인 마스킹 테이프.
                    Positioned(
                      right: -14,
                      top: tabHeight + 4,
                      child: const WashiTape(
                        width: 74,
                        height: 19,
                        color: Color(0x66F0E6CE),
                        angle: -0.62,
                      ),
                    ),

                    // 포켓 뒤에서 머리를 내민 실제 티켓들.
                    for (var i = 0; i < preview.length && i < 3; i++)
                      Positioned(
                        left: 18 + i * 46.0,
                        top: tabHeight + 10 + (i.isOdd ? 4 : 0),
                        child: _TicketPeek(
                          ticket: preview[i],
                          angle: (i.isEven ? -1 : 1) * (0.018 + i * 0.006),
                        ),
                      ),

                    if (preview.isEmpty)
                      Positioned(
                        left: 20,
                        top: tabHeight + 30,
                        child: Text(
                          '비어 있는 서류철',
                          style: AppText.ui(
                            size: 12,
                            color: _onColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                    // 포켓이 티켓 위로 떨구는 그림자.
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: FolderMetrics.pocketTop - 12,
                      height: 12,
                      child: LayerShadow(strength: 0.7),
                    ),

                    // 포켓(앞판).
                    Positioned(
                      left: 0,
                      right: 0,
                      top: FolderMetrics.pocketTop,
                      bottom: 0,
                      child: ClipPath(
                        clipper: _PocketClipper(),
                        child: PaperSurface(
                          color: _pocketColor,
                          grain: 0.12,
                          fiber: 1.0,
                          seed: folder.id.hashCode + 5,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 9, 18, 0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    folder.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.display(
                                      size: 16,
                                      weight: FontWeight.w600,
                                      color: _onColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'FILE_${fileNo.toString().padLeft(2, '0')}  ·  $count',
                                  style: AppText.data(
                                    size: 9,
                                    spacing: 0.6,
                                    color: _onColor.withValues(alpha: 0.62),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 포켓 윗변의 종이 단면.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: FolderMetrics.pocketTop,
                      height: 1.5,
                      child: IgnorePointer(
                        child: ColoredBox(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    ),

                    // 탭 위의 다이모 라벨.
                    Positioned(
                      left: tabStart + (tabWidth - labelWidth) / 2,
                      top: 6,
                      width: labelWidth,
                      child: DymoLabel(text: _code),
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

/// 포켓 뒤에 꽂힌 티켓의 머리 부분만 잘라 보여줍니다.
class _TicketPeek extends StatelessWidget {
  const _TicketPeek({required this.ticket, this.angle = 0});

  final Ticket ticket;
  final double angle;

  static const _width = 62.0;
  static const _visible = 84.0;

  @override
  Widget build(BuildContext context) {
    // 프레임 비율대로 전체 크기를 잡은 뒤, 위에서 _visible 만큼만 남깁니다.
    final full = _width / ticket.frame.aspect;
    final visible = full < _visible ? full : _visible;

    return IgnorePointer(
      child: Transform.rotate(
        angle: angle,
        alignment: Alignment.bottomCenter,
        child: Container(
          width: _width,
          height: visible,
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 7,
                offset: const Offset(1, 3),
              ),
            ],
          ),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: _width,
              maxWidth: _width,
              minHeight: full,
              maxHeight: full,
              child: RepaintBoundary(
                child: TicketFront(ticket: ticket, compact: true),
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
    final code = folder.label
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();

    return LayoutBuilder(
      builder: (context, c) {
        final labelWidth = DymoLabel.widthOf(code);
        final tabWidth = clampDouble(
            labelWidth + 32, 104, clampDouble(c.maxWidth - 24, 104, 400));
        final travel = clampDouble(c.maxWidth - 24 - tabWidth, 0, double.infinity);
        // 0이 아니라 0.0이어야 전체 식이 double로 잡힙니다(0이면 num이 되어 컴파일 에러).
        final tabStart =
            12 + (totalSlots <= 1 ? 0.0 : travel * tabSlot / (totalSlots - 1));

        return PhysicalShape(
          clipper: FolderShape(tabStart: tabStart, tabWidth: tabWidth),
          color: folder.color,
          shadowColor: const Color(0xFF2A2016),
          elevation: 14,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: GrainPainter(
                      opacity: 0.13,
                      seed: folder.id.hashCode,
                      fiber: 1.2,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: tabStart + (tabWidth - labelWidth) / 2,
                top: 6,
                width: labelWidth,
                child: DymoLabel(text: code),
              ),
            ],
          ),
        );
      },
    );
  }
}