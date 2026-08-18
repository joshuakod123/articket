import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';
import 'folder_texture.dart';
import 'paper.dart';
import 'ticket_card.dart';

/// 서류철 카드의 세로 배치. 화면과 위젯이 같은 값을 봐야 해서 한곳에 모읍니다.
class FolderMetrics {
  const FolderMetrics._();

  /// 인덱스 탭이 몸통 위로 돌출되는 높이.
  static const tabHeight = 34.0;

  /// 카드 한 장의 전체 높이.
  static const cardHeight = 188.0;

  /// 다음 서류철이 이만큼 아래에서 시작해 앞 서류철 몸통을 덮습니다.
  /// `cardHeight - step`(30pt)만큼이 마지막 장에서만 더 보입니다.
  static const step = 158.0;

  /// 포켓(앞판) 윗변의 y 좌표. 티켓은 이 선 뒤로 들어갑니다.
  static const pocketTop = 114.0;

  /// 겹쳐 있을 때 실제로 눈에 보이는 포켓 띠의 높이.
  static const pocketBand = step - pocketTop; // 44
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

/// 서류철 앞판(포켓). 윗변 오른쪽에 엄지 홈이 파여 있습니다.
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

// ─────────────────────────────────────────────────────────────
// 탭 라벨
// ─────────────────────────────────────────────────────────────

/// 글자 폭을 재서 탭 너비를 잡습니다.
double _measure(String text, TextStyle style) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return tp.width;
}

/// 인덱스 탭 위에 얹히는 이름표.
///
/// [FolderFont.dymo]는 검은 라벨 테이프 위에 눌러 찍고,
/// 나머지 서체는 표지에 **직접 압인**됩니다. 같은 이름이라도
/// "라벨을 붙였나 / 표지에 새겼나"가 달라 보이는 게 핵심입니다.
class FolderTabLabel extends StatelessWidget {
  const FolderTabLabel({
    super.key,
    required this.text,
    required this.font,
    required this.onColor,
    this.fontSize = 11,
  });

  final String text;
  final FolderFont font;

  /// 표지 위에 직접 찍을 때 쓰는 잉크색.
  final Color onColor;
  final double fontSize;

  static const tapeHeight = 22.0;

  /// 이 이름표가 차지할 폭.
  static double widthOf(String text, FolderFont font, {double fontSize = 11}) {
    final w = _measure(text, font.style(size: fontSize));
    return w + (font.onTape ? 26 : 18);
  }

  @override
  Widget build(BuildContext context) {
    if (font.onTape) return _tape();

    // 표지에 직접 새긴 이름. 아래에 황동 헤어라인을 깔아 캡션 플레이트처럼.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DebossedText(
          text,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: font.style(size: fontSize, color: onColor),
        ),
        const SizedBox(height: 3),
        Container(
          height: 1,
          color: AppColors.foil.withValues(alpha: 0.55),
        ),
      ],
    );
  }

  Widget _tape() {
    return Container(
      height: tapeHeight,
      padding: const EdgeInsets.symmetric(horizontal: 13),
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
            height: 9,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
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
            overflow: TextOverflow.clip,
            style: font.style(size: fontSize, color: AppColors.stockLight)
                .copyWith(
              shadows: const [
                // 글자가 눌려 들어간 자국.
                Shadow(
                    color: Colors.black54,
                    offset: Offset(0, 1),
                    blurRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 이전 이름 호환용. 새 코드는 [FolderTabLabel]을 쓰세요.
class DymoLabel extends StatelessWidget {
  const DymoLabel({super.key, required this.text, this.fontSize = 11});

  final String text;
  final double fontSize;

  static double widthOf(String text, {double fontSize = 11}) =>
      FolderTabLabel.widthOf(text, FolderFont.dymo, fontSize: fontSize);

  @override
  Widget build(BuildContext context) => FolderTabLabel(
    text: text,
    font: FolderFont.dymo,
    onColor: AppColors.ink,
    fontSize: fontSize,
  );
}

// ─────────────────────────────────────────────────────────────
// 서류철 카드
// ─────────────────────────────────────────────────────────────

/// 서랍에 겹쳐 꽂힌 가로 서류철 한 장.
///
/// 탭에는 이름표, 몸통에는 실제 티켓의 머리가 포켓 뒤로 삐져나오고,
/// 포켓 띠에는 서류철 이름과 정리 번호가 찍힙니다.
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

  /// 포켓(앞판)은 몸통보다 한 톤 눌러 판이 갈라져 보이게 합니다.
  Color get _pocketColor {
    final hsl = HSLColor.fromColor(folder.color);
    return hsl.withLightness(clampDouble(hsl.lightness * 0.87, 0, 1)).toColor();
  }

  /// 탭에 찍을 이름. 서체에 따라 대문자로 눌러 찍습니다.
  String get _code {
    var s = folder.label
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (s.isEmpty) s = 'FILE $fileNo';
    return folder.font.upperCase ? s.toUpperCase() : s;
  }

  String get _fileNoLabel => 'FILE_${fileNo.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    const tabHeight = FolderMetrics.tabHeight;
    final font = folder.font;

    return LayoutBuilder(
      builder: (context, c) {
        // 글자 길이에 맞춰 탭 너비를 잡습니다. 잘리지 않는 게 우선입니다.
        final labelWidth = FolderTabLabel.widthOf(_code, font);
        final tabWidth = clampDouble(
            labelWidth + 30, 104, clampDouble(c.maxWidth - 24, 104, 420));

        // 남는 폭을 슬롯 수로 나눠 탭 위치를 어긋나게 둡니다.
        final travel =
        clampDouble(c.maxWidth - 24 - tabWidth, 0, double.infinity);
        // 0이 아니라 0.0이어야 전체 식이 double로 잡힙니다.
        final tabStart =
            12 + (totalSlots <= 1 ? 0.0 : travel * tabSlot / (totalSlots - 1));

        return Semantics(
          button: true,
          label: '${folder.subtitle}, 티켓 $count장. 길게 누르면 작업대가 열립니다',
          child: GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0, lifted ? -12 : 0, 0),
              child: PhysicalShape(
                clipper: FolderShape(tabStart: tabStart, tabWidth: tabWidth),
                color: folder.color,
                shadowColor: const Color(0xFF2A2016),
                elevation: lifted ? 18 : 9,
                child: Stack(
                  children: [
                    // ── 표지 표면 ───────────────────────
                    Positioned.fill(
                      child: FolderSurface(
                        color: folder.color,
                        texture: folder.texture,
                        seed: folder.id.hashCode,
                      ),
                    ),

                    // 탭 아래로 이어지는 접힌 선(몸통 윗변의 두께).
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: tabHeight,
                      child: PaperEdge(strength: 0.9),
                    ),

                    // 오른쪽 위 모서리가 접혀 있습니다(dog-ear).
                    // 테이프보다 조용하고, 종이라는 사실을 더 잘 말해줍니다.
                    Positioned(
                      right: 0,
                      top: tabHeight,
                      child: _DogEar(size: 30, base: folder.color),
                    ),

                    // ── 포켓 뒤에서 머리를 내민 티켓들 ──────
                    for (var i = 0; i < preview.length && i < 3; i++)
                      Positioned(
                        left: 20 + i * 48.0,
                        top: tabHeight + 8 + (i.isOdd ? 5 : 0),
                        child: _TicketPeek(
                          ticket: preview[i],
                          angle: (i.isEven ? -1 : 1) * (0.018 + i * 0.006),
                        ),
                      ),

                    if (preview.isEmpty)
                      Positioned(
                        left: 22,
                        top: tabHeight + 26,
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
                      top: FolderMetrics.pocketTop - 14,
                      height: 14,
                      child: LayerShadow(strength: 0.75),
                    ),

                    // ── 포켓(앞판) ─────────────────────
                    Positioned(
                      left: 0,
                      right: 0,
                      top: FolderMetrics.pocketTop,
                      bottom: 0,
                      child: ClipPath(
                        clipper: _PocketClipper(),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: FolderSurface(
                                color: _pocketColor,
                                texture: folder.texture,
                                seed: folder.id.hashCode + 31,
                                wear: 0.7,
                              ),
                            ),
                            // 포켓 윗변의 종이 두께.
                            const Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              child: PaperEdge(strength: 1.0),
                            ),
                            // 겹쳤을 때 실제로 보이는 띠(44pt) 안에 정보를 가둡니다.
                            //
                            // 예전에는 `Positioned.fill` + `Row`(세로 중앙정렬)이라
                            // 글자가 포켓 전체(74pt)의 한가운데, 즉 y≈151에 앉았고,
                            // 다음 서류철이 y=158부터 덮으면서 글자 아랫부분이
                            // 잘려 보였습니다. 높이를 띠 크기로 못 박아 고정합니다.
                            Positioned(
                              left: 0,
                              right: 0,
                              top: 0,
                              height: FolderMetrics.pocketBand,
                              child: Padding(
                                padding:
                                const EdgeInsets.fromLTRB(20, 0, 18, 0),
                                child: _PocketPlate(
                                  title: folder.subtitle,
                                  fileNo: _fileNoLabel,
                                  count: count,
                                  onColor: _onColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── 탭 위의 이름표 ─────────────────
                    Positioned(
                      left: tabStart + (tabWidth - labelWidth) / 2,
                      top: font.onTape ? 6 : 7,
                      width: labelWidth,
                      child: FolderTabLabel(
                        text: _code,
                        font: font,
                        onColor: _onColor,
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

/// 접힌 모서리. 뒤로 접힌 삼각형과 그 아래로 드러난 안쪽 면.
class _DogEar extends StatelessWidget {
  const _DogEar({required this.size, required this.base});

  final double size;
  final Color base;

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(base);
    final inner =
    hsl.withLightness(clampDouble(hsl.lightness * 1.28 + 0.06, 0, 1))
        .toColor();

    return IgnorePointer(
      child: CustomPaint(
        size: Size.square(size),
        painter: _DogEarPainter(inner: inner),
      ),
    );
  }
}

class _DogEarPainter extends CustomPainter {
  _DogEarPainter({required this.inner});

  final Color inner;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 접혀 넘어간 종이의 뒷면.
    final flap = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, 0)
      ..close();

    canvas.drawPath(
      flap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [inner, inner.withValues(alpha: 0.75)],
        ).createShader(Offset.zero & size),
    );

    // 접힌 선에 지는 그늘.
    canvas.drawLine(
      Offset.zero,
      Offset(w, h),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_DogEarPainter old) => old.inner != inner;
}

/// 포켓 띠에 인쇄된 정보 한 줄. 겹쳐 있어도 이 44pt 안에서 다 읽혀야 합니다.
class _PocketPlate extends StatelessWidget {
  const _PocketPlate({
    required this.title,
    required this.fileNo,
    required this.count,
    required this.onColor,
  });

  final String title;
  final String fileNo;
  final int count;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 서류를 꿴 황동 리벳.
        Container(
          width: 9,
          height: 9,
          margin: const EdgeInsets.only(right: 11),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD8BE7C), Color(0xFF7A6028)],
            ),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.25),
              width: 0.7,
            ),
          ),
        ),
        Expanded(
          child: DebossedText(
            title,
            maxLines: 1,
            depth: 0.6,
            style: AppText.ui(
              size: 15,
              weight: FontWeight.w600,
              height: 1.15,
              color: onColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$fileNo · $count',
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: AppText.data(
            size: 9.5,
            spacing: 1.4,
            color: onColor.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

/// 포켓 뒤에 꽂힌 티켓의 머리 부분만 잘라 보여줍니다.
///
/// [TicketFront]가 원도를 축척해 그리므로, 폭만 주면 진짜 축소 인쇄물처럼
/// 비율이 맞습니다. 아래쪽은 포켓에 가려지도록 잘라냅니다.
class _TicketPeek extends StatelessWidget {
  const _TicketPeek({required this.ticket, this.angle = 0});

  final Ticket ticket;
  final double angle;

  static const _width = 62.0;
  static const _visible = 72.0;

  @override
  Widget build(BuildContext context) {
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
                blurRadius: 8,
                offset: const Offset(1, 3),
              ),
            ],
          ),
          // 위에서부터 visible/full 만큼만 남기고 잘라 냅니다.
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: visible / full,
              child: SizedBox(
                width: _width,
                height: full,
                child: RepaintBoundary(
                  child: TicketFront(ticket: ticket, compact: true),
                ),
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
    final font = folder.font;
    var code = folder.label
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (font.upperCase) code = code.toUpperCase();

    final onColor =
    ThemeData.estimateBrightnessForColor(folder.color) == Brightness.dark
        ? AppColors.stockLight
        : AppColors.ink;

    return LayoutBuilder(
      builder: (context, c) {
        final labelWidth = FolderTabLabel.widthOf(code, font);
        final tabWidth = clampDouble(
            labelWidth + 30, 104, clampDouble(c.maxWidth - 24, 104, 420));
        final travel =
        clampDouble(c.maxWidth - 24 - tabWidth, 0, double.infinity);
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
                child: FolderSurface(
                  color: folder.color,
                  texture: folder.texture,
                  seed: folder.id.hashCode,
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                top: FolderMetrics.tabHeight,
                child: PaperEdge(strength: 0.9),
              ),
              Positioned(
                left: tabStart + (tabWidth - labelWidth) / 2,
                top: font.onTape ? 6 : 7,
                width: labelWidth,
                child: FolderTabLabel(
                  text: code,
                  font: font,
                  onColor: onColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}