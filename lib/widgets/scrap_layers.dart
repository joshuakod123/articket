import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/layer.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';

// ─────────────────────────────────────────────────────────────
// 벡터 스티커
// ─────────────────────────────────────────────────────────────

/// 직접 그린 스티커.
///
/// 이모지는 기기마다 모양이 달라지고 색을 못 바꿔서, 앱 톤과 겉돕니다.
/// 여기 있는 것들은 전부 `Path`로 깎아서 **사용자가 고른 색이 그대로 먹습니다.**
enum StickerArt {
  star('별'),
  sparkle('반짝'),
  heart('하트'),
  flower('꽃'),
  leaf('잎'),
  moon('달'),
  ribbon('리본'),
  stamp('도장'),
  pin('압정'),
  clip('클립'),
  arrow('화살표'),
  check('체크'),
  ticketStub('티켓 조각'),
  quote('따옴표'),
  burst('빛살'),
  frame('액자');

  const StickerArt(this.label);

  final String label;

  static StickerArt? parse(String content) {
    if (!content.startsWith('art:')) return null;
    final name = content.substring(4);
    for (final a in StickerArt.values) {
      if (a.name == name) return a;
    }
    return null;
  }

  String get content => 'art:$name';
}

class StickerPainter extends CustomPainter {
  StickerPainter({required this.art, required this.color});

  final StickerArt art;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (art) {
      case StickerArt.star:
        canvas.drawPath(_star(w, h, 5, 0.48, 0.20), fill);
      case StickerArt.sparkle:
        canvas.drawPath(_sparkle(w, h), fill);
      case StickerArt.heart:
        canvas.drawPath(_heart(w, h), fill);
      case StickerArt.flower:
        for (var i = 0; i < 6; i++) {
          final a = i / 6 * math.pi * 2;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(w / 2 + math.cos(a) * w * 0.22,
                  h / 2 + math.sin(a) * h * 0.22),
              width: w * 0.30,
              height: h * 0.30,
            ),
            fill,
          );
        }
        canvas.drawCircle(
          Offset(w / 2, h / 2),
          w * 0.13,
          Paint()..color = AppColors.stockLight,
        );
      case StickerArt.leaf:
        final p = Path()
          ..moveTo(w * 0.18, h * 0.84)
          ..quadraticBezierTo(w * 0.10, h * 0.24, w * 0.84, h * 0.14)
          ..quadraticBezierTo(w * 0.90, h * 0.80, w * 0.18, h * 0.84)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawLine(
          Offset(w * 0.22, h * 0.80),
          Offset(w * 0.74, h * 0.24),
          Paint()
            ..color = AppColors.stockLight.withValues(alpha: 0.7)
            ..strokeWidth = w * 0.05,
        );
      case StickerArt.moon:
        final outer = Path()
          ..addOval(Rect.fromCircle(
              center: Offset(w * 0.50, h * 0.50), radius: w * 0.40));
        final bite = Path()
          ..addOval(Rect.fromCircle(
              center: Offset(w * 0.68, h * 0.38), radius: w * 0.36));
        canvas.drawPath(
            Path.combine(PathOperation.difference, outer, bite), fill);
      case StickerArt.ribbon:
        final p = Path()
          ..moveTo(w * 0.5, h * 0.5)
          ..lineTo(w * 0.10, h * 0.22)
          ..lineTo(w * 0.10, h * 0.78)
          ..close()
          ..moveTo(w * 0.5, h * 0.5)
          ..lineTo(w * 0.90, h * 0.22)
          ..lineTo(w * 0.90, h * 0.78)
          ..close();
        canvas.drawPath(p, fill);
        canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.11, fill);
      case StickerArt.stamp:
      // 고무 도장. 이중 원 + 가운데 별.
        canvas.drawCircle(
            Offset(w / 2, h / 2), w * 0.42, stroke..strokeWidth = w * 0.07);
        canvas.drawCircle(
            Offset(w / 2, h / 2), w * 0.32, stroke..strokeWidth = w * 0.035);
        canvas.save();
        canvas.translate(w * 0.5, h * 0.5);
        canvas.scale(0.42);
        canvas.translate(-w * 0.5, -h * 0.5);
        canvas.drawPath(_star(w, h, 5, 0.48, 0.20), fill);
        canvas.restore();
      case StickerArt.pin:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: Offset(w * 0.5, h * 0.36),
                width: w * 0.52,
                height: h * 0.30),
            Radius.circular(w * 0.10),
          ),
          fill,
        );
        canvas.drawLine(Offset(w * 0.5, h * 0.50), Offset(w * 0.5, h * 0.90),
            stroke..strokeWidth = w * 0.07);
      case StickerArt.clip:
        final p = Path()
          ..moveTo(w * 0.32, h * 0.86)
          ..lineTo(w * 0.32, h * 0.26)
          ..arcToPoint(Offset(w * 0.68, h * 0.26),
              radius: Radius.circular(w * 0.18))
          ..lineTo(w * 0.68, h * 0.74)
          ..arcToPoint(Offset(w * 0.46, h * 0.74),
              radius: Radius.circular(w * 0.11), clockwise: false)
          ..lineTo(w * 0.46, h * 0.34);
        canvas.drawPath(p, stroke..strokeWidth = w * 0.075);
      case StickerArt.arrow:
        canvas.drawLine(Offset(w * 0.14, h * 0.72), Offset(w * 0.84, h * 0.30),
            stroke..strokeWidth = w * 0.08);
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.88, h * 0.26)
            ..lineTo(w * 0.58, h * 0.30)
            ..lineTo(w * 0.80, h * 0.56)
            ..close(),
          fill,
        );
      case StickerArt.check:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.16, h * 0.52)
            ..lineTo(w * 0.40, h * 0.76)
            ..lineTo(w * 0.86, h * 0.22),
          stroke..strokeWidth = w * 0.12,
        );
      case StickerArt.ticketStub:
        final body = Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.08, h * 0.28, w * 0.84, h * 0.44),
            Radius.circular(w * 0.05),
          ));
        final holes = Path()
          ..addOval(Rect.fromCircle(
              center: Offset(w * 0.36, h * 0.28), radius: w * 0.07))
          ..addOval(Rect.fromCircle(
              center: Offset(w * 0.36, h * 0.72), radius: w * 0.07));
        canvas.drawPath(
            Path.combine(PathOperation.difference, body, holes), fill);
      case StickerArt.quote:
        for (final dx in [0.22, 0.58]) {
          canvas.drawPath(
            Path()
              ..moveTo(w * dx, h * 0.30)
              ..lineTo(w * (dx + 0.20), h * 0.30)
              ..lineTo(w * (dx + 0.10), h * 0.66)
              ..lineTo(w * dx, h * 0.66)
              ..close(),
            fill,
          );
        }
      case StickerArt.burst:
        for (var i = 0; i < 12; i++) {
          final a = i / 12 * math.pi * 2;
          final r0 = w * (i.isEven ? 0.16 : 0.22);
          final r1 = w * (i.isEven ? 0.44 : 0.34);
          canvas.drawLine(
            Offset(w / 2 + math.cos(a) * r0, h / 2 + math.sin(a) * r0),
            Offset(w / 2 + math.cos(a) * r1, h / 2 + math.sin(a) * r1),
            stroke..strokeWidth = w * 0.055,
          );
        }
      case StickerArt.frame:
        canvas.drawRect(
          Rect.fromLTWH(w * 0.12, h * 0.16, w * 0.76, h * 0.68),
          stroke..strokeWidth = w * 0.10,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.24, h * 0.28, w * 0.52, h * 0.44),
          stroke..strokeWidth = w * 0.03,
        );
    }
  }

  Path _star(double w, double h, int points, double outer, double inner) {
    final p = Path();
    for (var i = 0; i < points * 2; i++) {
      final r = (i.isEven ? outer : inner) * w;
      final a = -math.pi / 2 + i * math.pi / points;
      final pt = Offset(w / 2 + math.cos(a) * r, h / 2 + math.sin(a) * r);
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  /// 원 두 개 + 아래로 모이는 삼각형. 손으로 그린 하트에 가깝게 살짝 통통합니다.
  Path _heart(double w, double h) {
    final p = Path()..moveTo(w * 0.5, h * 0.86);
    p.cubicTo(w * 0.02, h * 0.54, w * 0.14, h * 0.12, w * 0.5, h * 0.32);
    p.cubicTo(w * 0.86, h * 0.12, w * 0.98, h * 0.54, w * 0.5, h * 0.86);
    return p..close();
  }

  Path _sparkle(double w, double h) {
    final p = Path();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final tip = Offset(
          w / 2 + math.cos(a) * w * 0.46, h / 2 + math.sin(a) * h * 0.46);
      final l = Offset(w / 2 + math.cos(a + math.pi / 4) * w * 0.11,
          h / 2 + math.sin(a + math.pi / 4) * h * 0.11);
      if (i == 0) {
        p.moveTo(tip.dx, tip.dy);
      } else {
        p.lineTo(tip.dx, tip.dy);
      }
      p.lineTo(l.dx, l.dy);
    }
    return p..close();
  }

  @override
  bool shouldRepaint(StickerPainter old) =>
      old.art != art || old.color != color;
}

// ─────────────────────────────────────────────────────────────
// 마스킹 테이프
// ─────────────────────────────────────────────────────────────

/// 테이프 무늬. `ScrapLayer.content`에 이름으로 저장합니다.
enum TapePattern {
  plain('민무늬'),
  stripe('사선'),
  dot('물방울'),
  grid('모눈'),
  wave('물결'),
  torn('찢은 종이');

  const TapePattern(this.label);

  final String label;

  static TapePattern parse(String content) {
    for (final p in TapePattern.values) {
      if (p.name == content) return p;
    }
    return TapePattern.plain;
  }
}

/// 캔버스에 붙이는 테이프 한 조각. 짧은 변이 톱니로 뜯겨 있습니다.
class TapeStrip extends StatelessWidget {
  const TapeStrip({
    super.key,
    required this.color,
    this.pattern = TapePattern.plain,
    this.width = 104,
    this.height = 27,
  });

  final Color color;
  final TapePattern pattern;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _TornEdge(),
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          painter: _TapePainter(color: color, pattern: pattern),
        ),
      ),
    );
  }
}

class _TornEdge extends CustomClipper<Path> {
  static const _teeth = 6;
  static const _bite = 3.0;

  @override
  Path getClip(Size size) {
    final step = size.height / _teeth;
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0);
    for (var i = 1; i <= _teeth; i++) {
      p.lineTo(size.width - (i.isOdd ? _bite : 0.0), step * i);
    }
    p.lineTo(0, size.height);
    for (var i = _teeth - 1; i >= 0; i--) {
      p.lineTo(i.isOdd ? _bite : 0.0, step * i);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_TornEdge old) => false;
}

class _TapePainter extends CustomPainter {
  _TapePainter({required this.color, required this.pattern});

  final Color color;
  final TapePattern pattern;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 반투명 테이프 바탕.
    canvas.drawRect(Offset.zero & size, Paint()..color = color);

    // 표면 광택.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.26),
            Colors.white.withValues(alpha: 0.02),
            Colors.white.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );

    final ink = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    switch (pattern) {
      case TapePattern.plain:
        break;
      case TapePattern.stripe:
        for (double x = -h; x < w + h; x += 9) {
          canvas.drawLine(Offset(x, h), Offset(x + h, 0), ink);
        }
      case TapePattern.dot:
        final dot = Paint()..color = Colors.white.withValues(alpha: 0.36);
        for (double x = 6; x < w; x += 13) {
          for (double y = 7; y < h; y += 12) {
            canvas.drawCircle(Offset(x + (y > h / 2 ? 6 : 0), y), 2.1, dot);
          }
        }
      case TapePattern.grid:
        for (double x = 0; x < w; x += 10) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), ink..strokeWidth = 1.0);
        }
        for (double y = 0; y < h; y += 10) {
          canvas.drawLine(Offset(0, y), Offset(w, y), ink..strokeWidth = 1.0);
        }
      case TapePattern.wave:
        final p = Path()..moveTo(0, h / 2);
        for (double x = 0; x <= w; x += 4) {
          p.lineTo(x, h / 2 + math.sin(x * 0.28) * h * 0.24);
        }
        canvas.drawPath(p, ink..strokeWidth = 1.8);
      case TapePattern.torn:
      // 종이를 손으로 찢은 결. 세로 섬유 자국.
        final fib = Paint()..strokeWidth = 0.9;
        final rng = math.Random(7);
        for (var i = 0; i < 40; i++) {
          final x = rng.nextDouble() * w;
          final y = rng.nextDouble() * h;
          fib.color = Colors.white.withValues(alpha: rng.nextDouble() * 0.30);
          canvas.drawLine(Offset(x, y), Offset(x + 3, y + 1), fib);
        }
    }
  }

  @override
  bool shouldRepaint(_TapePainter old) =>
      old.color != color || old.pattern != pattern;
}

// ─────────────────────────────────────────────────────────────
// 레이어 렌더러
// ─────────────────────────────────────────────────────────────

/// 레이어 종류별 실제 그림. **에디터와 상세 화면이 같은 함수를 씁니다.**
///
/// 둘이 각자 그리면 편집 화면과 완성본이 달라 보이므로 한 군데로 모았습니다.
Widget buildLayerContent(ScrapLayer layer) {
  final color = Color(layer.color);

  switch (layer.kind) {
  // ── 스티커 ─────────────────────────────────────
    case LayerKind.sticker:
      final art = StickerArt.parse(layer.content);
      if (art == null) {
        // 이모지 스티커.
        return Text(
          layer.content,
          style: TextStyle(fontSize: layer.fontSize + 12),
        );
      }
      final side = layer.fontSize + 20;
      return SizedBox.square(
        dimension: side,
        child: CustomPaint(painter: StickerPainter(art: art, color: color)),
      );

  // ── 글자 ──────────────────────────────────────
    case LayerKind.text:
      return Text(
        layer.content,
        textAlign: TextAlign.center,
        style: FolderFont.parse(layer.font)
            .style(size: layer.fontSize, color: color),
      );

  // ── 테이프 ─────────────────────────────────────
    case LayerKind.tape:
      return TapeStrip(
        color: color,
        pattern: TapePattern.parse(layer.content),
      );

  // ── 폴라로이드 ──────────────────────────────────
    case LayerKind.photo:
      return _Polaroid(layer: layer, tint: color);
  }
}

/// 폴라로이드 한 장. 아래 여백이 넓고, 사진이 없으면 색으로 채웁니다.
class _Polaroid extends StatelessWidget {
  const _Polaroid({required this.layer, required this.tint});

  final ScrapLayer layer;
  final Color tint;

  static const _w = 108.0;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = layer.content.isNotEmpty && !kIsWeb;

    return Container(
      width: _w,
      padding: const EdgeInsets.fromLTRB(7, 7, 7, 20),
      decoration: BoxDecoration(
        color: AppColors.stockLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 9,
            offset: const Offset(1, 4),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1,
        child: hasPhoto
            ? Image.file(
          File(layer.content),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _block(),
        )
            : _block(),
      ),
    );
  }

  Widget _block() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint,
          HSLColor.fromColor(tint)
              .withLightness(
              (HSLColor.fromColor(tint).lightness * 0.6).clamp(0, 1))
              .toColor(),
        ],
      ),
    ),
    child: Center(
      child: Icon(
        Icons.image_outlined,
        size: 22,
        color: AppColors.stockLight.withValues(alpha: 0.35),
      ),
    ),
  );
}

/// 스티커 시트에서 쓰는 미리보기 타일.
class StickerPreview extends StatelessWidget {
  const StickerPreview({
    super.key,
    required this.art,
    required this.color,
    this.size = 30,
  });

  final StickerArt art;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: StickerPainter(art: art, color: color)),
  );
}

/// 글자 레이어 미리보기에 쓰는 서체 이름.
String fontLabelOf(String? name) => FolderFont.parse(name).label;

/// 시트 제목 등에 재활용하는 작은 라벨 스타일.
TextStyle scrapEyebrow([Color? color]) =>
    AppText.eyebrow(color: color ?? AppColors.oxblood);