import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_text.dart';

// ─────────────────────────────────────────────────────────────
// 도장
// ─────────────────────────────────────────────────────────────

/// 도장 테두리 모양.
///
/// 스티커에도 `StickerArt.stamp`(도장 그림)가 있었지만 그건 **아이콘**입니다.
/// 크기가 정해져 있고 글자를 못 넣습니다. 실물 티켓북에 찍는 도장은
/// "관람 완료 / 2026.07.14 / 국립현대미술관" 처럼 **글자가 본체**라서,
/// 아예 다른 레이어 종류로 뺐습니다.
enum StampShape {
  circle('겹동그라미'),
  ring('홑동그라미'),
  square('네모'),
  rounded('둥근네모'),
  banner('띠'),
  scallop('물결테'),
  ticket('티켓');

  const StampShape(this.label);

  final String label;

  /// 아치로 휘는 윗글자를 받을 수 있는 모양인지.
  bool get curved => this == StampShape.circle ||
      this == StampShape.ring ||
      this == StampShape.scallop;

  /// 가로:세로. 동그라미 계열은 정사각, 띠는 납작합니다.
  double get aspect => switch (this) {
    StampShape.banner => 2.9,
    StampShape.ticket => 2.2,
    StampShape.square || StampShape.rounded => 1.35,
    _ => 1.0,
  };

  static StampShape parse(String? name) {
    for (final s in StampShape.values) {
      if (s.name == name) return s;
    }
    return StampShape.circle;
  }
}

/// 도장 한 개의 내용.
///
/// [ScrapLayer.content]는 문자열 한 칸뿐이라 `모양|윗글자|가운데|아랫글자`로
/// 접어 넣습니다. 사용자 입력에서 `|`는 미리 걷어냅니다.
class StampSpec {
  const StampSpec({
    this.shape = StampShape.circle,
    this.top = 'ARTICKET',
    this.center = '관람 완료',
    this.bottom = '',
  });

  final StampShape shape;

  /// 위쪽 아치(또는 윗줄). 짧은 영문이 잘 어울립니다.
  final String top;

  /// 한가운데. 도장의 주인공.
  final String center;

  /// 아래쪽. 날짜를 넣는 자리로 씁니다.
  final String bottom;

  static const _sep = '|';

  static String _clean(String v) => v.replaceAll(_sep, ' ').trim();

  String encode() => [
    shape.name,
    _clean(top),
    _clean(center),
    _clean(bottom),
  ].join(_sep);

  /// 옛 데이터(도장이 없던 시절)나 깨진 문자열이 와도 죽지 않습니다.
  factory StampSpec.decode(String raw) {
    final p = raw.split(_sep);
    return StampSpec(
      shape: StampShape.parse(p.isNotEmpty ? p[0] : null),
      top: p.length > 1 ? p[1] : '',
      center: p.length > 2 ? p[2] : (p.isNotEmpty ? p[0] : ''),
      bottom: p.length > 3 ? p[3] : '',
    );
  }

  StampSpec copyWith({
    StampShape? shape,
    String? top,
    String? center,
    String? bottom,
  }) =>
      StampSpec(
        shape: shape ?? this.shape,
        top: top ?? this.top,
        center: center ?? this.center,
        bottom: bottom ?? this.bottom,
      );

  /// 시트에 늘어놓는 기본 문구.
  static List<StampSpec> presets(DateTime now) {
    final date = '${now.year}.'
        '${now.month.toString().padLeft(2, '0')}.'
        '${now.day.toString().padLeft(2, '0')}';
    return [
      const StampSpec(center: '관람 완료', top: 'ARTICKET', bottom: 'VISITED'),
      StampSpec(center: 'VISITED', top: 'ARTICKET', bottom: date),
      StampSpec(
          shape: StampShape.banner, center: 'FILED', top: '', bottom: date),
      const StampSpec(
          shape: StampShape.rounded, center: 'ADMIT\nONE', top: '', bottom: ''),
      const StampSpec(shape: StampShape.ring, center: '첫 관람', top: 'FIRST'),
      const StampSpec(
          shape: StampShape.scallop, center: '또 보고 싶다', top: 'AGAIN'),
      const StampSpec(
          shape: StampShape.ticket, center: '예매 완료', top: '', bottom: ''),
      StampSpec(
          shape: StampShape.square, center: '기록함', top: 'ARCHIVED', bottom: date),
      const StampSpec(center: '최고', top: 'MASTERPIECE', bottom: '★★★★★'),
      const StampSpec(
          shape: StampShape.banner, center: 'SOLD OUT', top: '', bottom: ''),
      const StampSpec(shape: StampShape.ring, center: '혼자', top: 'ALONE'),
      const StampSpec(
          shape: StampShape.rounded, center: '재관람\n희망', top: '', bottom: ''),
    ];
  }
}

/// 캔버스에 찍히는 도장 한 개.
///
/// 잉크가 고르게 묻지 않은 자국까지 그립니다. 깨끗한 벡터 도형이면
/// "붙인 스티커"로 보이지, "찍은 도장"으로 보이지 않습니다.
class StampMark extends StatelessWidget {
  const StampMark({
    super.key,
    required this.spec,
    required this.color,
    this.size = 96,
    this.seed = 0,
    this.worn = true,
  });

  final StampSpec spec;
  final Color color;

  /// 짧은 변 기준 크기.
  final double size;

  /// 잉크가 벗겨진 자리를 정하는 씨앗. 레이어 id를 넘기면 매번 같은 자국.
  final int seed;

  /// 잉크 번짐 표현. 미리보기 타일에서는 꺼도 됩니다.
  final bool worn;

  @override
  Widget build(BuildContext context) {
    final w = spec.shape.aspect >= 1 ? size * spec.shape.aspect : size;
    final h = spec.shape.aspect >= 1 ? size : size / spec.shape.aspect;

    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(
        painter: _StampPainter(
          spec: spec,
          color: color,
          seed: seed,
          worn: worn,
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter({
    required this.spec,
    required this.color,
    required this.seed,
    required this.worn,
  });

  final StampSpec spec;
  final Color color;
  final int seed;
  final bool worn;

  @override
  void paint(Canvas canvas, Size size) {
    // 잉크 자국을 나중에 **파내야** 해서 레이어를 따로 뜹니다.
    // 그냥 위에 배경색을 덮으면 티켓 무늬가 가려집니다.
    if (worn) canvas.saveLayer(Offset.zero & size, Paint());

    _drawBorder(canvas, size);
    _drawText(canvas, size);

    if (worn) {
      _wear(canvas, size);
      canvas.restore();
    }
  }

  // ── 테두리 ──────────────────────────────────────

  void _drawBorder(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final unit = math.min(w, h);

    switch (spec.shape) {
      case StampShape.circle:
        canvas.drawCircle(
            size.center(Offset.zero), unit * 0.47, line..strokeWidth = unit * 0.055);
        canvas.drawCircle(size.center(Offset.zero), unit * 0.385,
            line..strokeWidth = unit * 0.018);

      case StampShape.ring:
        canvas.drawCircle(size.center(Offset.zero), unit * 0.46,
            line..strokeWidth = unit * 0.06);

      case StampShape.square:
        canvas.drawRect(
          Rect.fromLTWH(w * 0.03, h * 0.04, w * 0.94, h * 0.92),
          line..strokeWidth = unit * 0.06,
        );
        canvas.drawRect(
          Rect.fromLTWH(w * 0.075, h * 0.10, w * 0.85, h * 0.80),
          line..strokeWidth = unit * 0.02,
        );

      case StampShape.rounded:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.03, h * 0.05, w * 0.94, h * 0.90),
            Radius.circular(unit * 0.20),
          ),
          line..strokeWidth = unit * 0.06,
        );

      case StampShape.banner:
      // 양 끝이 안으로 파인 리본 띠.
        final r = Rect.fromLTWH(w * 0.02, h * 0.10, w * 0.96, h * 0.80);
        final p = Path()
          ..moveTo(r.left, r.top)
          ..lineTo(r.right, r.top)
          ..lineTo(r.right - r.height * 0.28, r.center.dy)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.left, r.bottom)
          ..lineTo(r.left + r.height * 0.28, r.center.dy)
          ..close();
        canvas.drawPath(p, line..strokeWidth = unit * 0.075);

      case StampShape.scallop:
        canvas.drawPath(
          _scallop(size.center(Offset.zero), unit * 0.47, 18),
          line..strokeWidth = unit * 0.045,
        );
        canvas.drawCircle(size.center(Offset.zero), unit * 0.355,
            line..strokeWidth = unit * 0.02);

      case StampShape.ticket:
      // 좌우가 반원으로 뜯긴 티켓 조각.
        final r = Rect.fromLTWH(w * 0.03, h * 0.10, w * 0.94, h * 0.80);
        final body = Path()
          ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(unit * 0.10)));
        final bite = Path()
          ..addOval(Rect.fromCircle(
              center: Offset(r.left, r.center.dy), radius: r.height * 0.20))
          ..addOval(Rect.fromCircle(
              center: Offset(r.right, r.center.dy), radius: r.height * 0.20));
        canvas.drawPath(
          Path.combine(PathOperation.difference, body, bite),
          line..strokeWidth = unit * 0.07,
        );
    }
  }

  Path _scallop(Offset c, double r, int teeth) {
    final p = Path();
    final step = math.pi * 2 / teeth;
    final bump = r * 0.11;
    for (var i = 0; i < teeth; i++) {
      final a0 = i * step;
      final a1 = (i + 1) * step;
      final s = Offset(c.dx + math.cos(a0) * r, c.dy + math.sin(a0) * r);
      final e = Offset(c.dx + math.cos(a1) * r, c.dy + math.sin(a1) * r);
      final mid = (a0 + a1) / 2;
      final ctrl = Offset(
        c.dx + math.cos(mid) * (r + bump * 2.4),
        c.dy + math.sin(mid) * (r + bump * 2.4),
      );
      if (i == 0) p.moveTo(s.dx, s.dy);
      p.quadraticBezierTo(ctrl.dx, ctrl.dy, e.dx, e.dy);
    }
    return p..close();
  }

  // ── 글자 ────────────────────────────────────────

  void _drawText(Canvas canvas, Size size) {
    final unit = math.min(size.width, size.height);
    final center = spec.center.trim();
    final top = spec.top.trim();
    final bottom = spec.bottom.trim();

    // 가운데 글자는 상자 안에 **딱 맞게** 줄입니다.
    // 도장은 크기를 바꿔가며 쓰는 물건이라, 글자가 길면 넘치는 게 아니라
    // 작아져야 합니다.
    if (center.isNotEmpty) {
      final lines = center.split('\n').length;
      final box = spec.shape.curved
          ? Size(unit * 0.62, unit * 0.42)
          : Size(size.width * 0.72, size.height * 0.52);
      _fitText(
        canvas,
        text: center,
        style: AppText.display(
          size: unit * (lines > 1 ? 0.20 : 0.26),
          color: color,
          height: 1.12,
          spacing: 0.5,
        ),
        box: box,
        at: Offset(
          size.width / 2,
          size.height / 2 +
              (spec.shape.curved && bottom.isNotEmpty ? -unit * 0.02 : 0),
        ),
      );
    }

    if (top.isNotEmpty) {
      if (spec.shape.curved) {
        _arc(canvas, size, top, unit * 0.30, up: true);
      } else {
        _fitText(
          canvas,
          text: top,
          style: AppText.eyebrow(size: unit * 0.115, color: color),
          box: Size(size.width * 0.7, unit * 0.2),
          at: Offset(size.width / 2, size.height * 0.20),
        );
      }
    }

    if (bottom.isNotEmpty) {
      if (spec.shape.curved) {
        _arc(canvas, size, bottom, unit * 0.30, up: false);
      } else {
        _fitText(
          canvas,
          text: bottom,
          style: AppText.data(
              size: unit * 0.12, color: color, spacing: 1.2, weight: FontWeight.w700),
          box: Size(size.width * 0.72, unit * 0.2),
          at: Offset(size.width / 2, size.height * 0.81),
        );
      }
    }
  }

  /// 상자를 넘지 않도록 배율을 낮춰 가운데 정렬로 찍습니다.
  void _fitText(
      Canvas canvas, {
        required String text,
        required TextStyle style,
        required Size box,
        required Offset at,
      }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
    )..layout();

    final k = math.min(1.0, math.min(box.width / tp.width, box.height / tp.height));

    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(k);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  /// 원 둘레를 따라 한 글자씩 돌려 찍습니다.
  ///
  /// 통짜 텍스트를 회전시키면 아치가 안 됩니다. 글자마다 각도를 따로
  /// 계산해서, 각 글자의 **밑변이 원 바깥을 향하도록** 놓아야 도장처럼 보입니다.
  void _arc(
      Canvas canvas,
      Size size,
      String text,
      double radius, {
        required bool up,
      }) {
    final unit = math.min(size.width, size.height);
    final chars = _graphemes(text);
    if (chars.isEmpty) return;

    final style = AppText.eyebrow(size: unit * 0.108, color: color);

    // 글자마다 실제 폭이 달라서, 폭에 비례해 각도를 나눠 줘야
    // 'I' 옆이 벌어지고 'W' 옆이 붙는 일이 없습니다.
    final painters = [
      for (final c in chars)
        TextPainter(
          text: TextSpan(text: c, style: style),
          textDirection: TextDirection.ltr,
        )..layout()
    ];
    final widths = painters.map((p) => p.width + unit * 0.045).toList();
    final total = widths.fold<double>(0, (a, b) => a + b);
    final sweep = total / radius;

    // 위쪽 아치는 12시에서 좌우로, 아래쪽은 6시에서 좌우로 펼칩니다.
    var angle = (up ? -math.pi / 2 : math.pi / 2) + (up ? -sweep / 2 : sweep / 2);

    for (var i = 0; i < painters.length; i++) {
      final step = widths[i] / radius;
      final a = angle + (up ? step / 2 : -step / 2);

      // 위: 글자 머리가 바깥. 아래: 글자 머리가 안쪽(뒤집히지 않게).
      canvas.save();
      canvas.translate(size.width / 2, size.height / 2);
      canvas.rotate(up ? a + math.pi / 2 : a - math.pi / 2);
      canvas.translate(0, up ? -radius : radius);
      painters[i]
          .paint(canvas, Offset(-painters[i].width / 2, -painters[i].height / 2));
      canvas.restore();

      angle += up ? step : -step;
    }
  }

  /// 서로게이트 쌍(이모지)을 쪼개지 않고 한 글자씩 끊습니다.
  static List<String> _graphemes(String s) {
    final out = <String>[];
    for (var i = 0; i < s.length; i++) {
      final unit = s.codeUnitAt(i);
      if (unit >= 0xD800 && unit <= 0xDBFF && i + 1 < s.length) {
        out.add(s.substring(i, i + 2));
        i++;
      } else {
        out.add(s[i]);
      }
    }
    return out;
  }

  // ── 잉크 자국 ────────────────────────────────────

  /// 찍힌 잉크를 군데군데 **지웁니다**(`dstOut`).
  ///
  /// 배경을 덮는 게 아니라 파내는 방식이라, 도장 아래 티켓 무늬가 그대로
  /// 비칩니다. 티켓 위·스크랩북 위 어디에 찍어도 자연스럽습니다.
  void _wear(Canvas canvas, Size size) {
    final rng = math.Random(seed == 0 ? spec.encode().hashCode : seed);
    final unit = math.min(size.width, size.height);
    final eraser = Paint()..blendMode = BlendMode.dstOut;

    // 1) 잔 얼룩 — 잉크가 안 묻은 미세한 점.
    for (var i = 0; i < 90; i++) {
      eraser.color = Colors.black
          .withValues(alpha: 0.20 + rng.nextDouble() * 0.55);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        unit * (0.006 + rng.nextDouble() * 0.022),
        eraser,
      );
    }

    // 2) 한쪽이 덜 눌린 자국 — 큰 그라디언트 한 덩어리.
    final lean = Offset(
      size.width * (0.2 + rng.nextDouble() * 0.6),
      size.height * (0.2 + rng.nextDouble() * 0.6),
    );
    canvas.drawCircle(
      lean,
      unit * 0.62,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = ui.Gradient.radial(
          lean,
          unit * 0.62,
          [
            Colors.black.withValues(alpha: 0.26),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
    );

    // 3) 전체를 살짝 옅게. 고무 도장은 원래 잉크가 진하지 않습니다.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..color = Colors.black.withValues(alpha: 0.10),
    );
  }

  @override
  bool shouldRepaint(_StampPainter old) =>
      old.color != color ||
          old.seed != seed ||
          old.worn != worn ||
          old.spec.encode() != spec.encode();
}