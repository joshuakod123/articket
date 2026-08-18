import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/folder_style.dart';

/// 서류철 표면 한 장.
///
/// 바탕색 위에 [texture]별 결 → 빛 방향 그라디언트 → 가장자리 비네트 →
/// 모서리 닳음 순서로 얹습니다. 전부 `CustomPainter`라 이미지 에셋이 없습니다.
/// [seed]가 같으면 무늬도 같아서, 같은 서류철은 다시 그려도 같은 얼룩을 유지합니다.
class FolderSurface extends StatelessWidget {
  const FolderSurface({
    super.key,
    required this.color,
    required this.texture,
    required this.seed,
    this.child,
    this.wear = 1.0,
  });

  final Color color;
  final FolderTexture texture;
  final int seed;
  final Widget? child;

  /// 닳음의 세기. 0이면 새 서류철.
  final double wear;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        // 1) 바탕. 위에서 빛이 드는 아주 옅은 세로 그라디언트.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _lift(color, 0.06),
                    color,
                    _lift(color, -0.05),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 2) 질감.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: FolderTexturePainter(
                  texture: texture,
                  base: color,
                  seed: seed,
                ),
              ),
            ),
          ),
        ),

        // 3) 표면 광택. 왼쪽 위에서 들어온 빛이 넓게 번집니다.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.7, -1.1),
                  radius: 1.5,
                  colors: [
                    Colors.white.withValues(alpha: texture.sheen),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 4) 가장자리 비네트 + 모서리 닳음.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: EdgeWearPainter(seed: seed, strength: wear),
              ),
            ),
          ),
        ),

        if (child != null) child!,
      ],
    );
  }

  static Color _lift(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}

/// 질감 5종을 한 페인터에서 분기합니다.
class FolderTexturePainter extends CustomPainter {
  FolderTexturePainter({
    required this.texture,
    required this.base,
    required this.seed,
  });

  final FolderTexture texture;
  final Color base;
  final int seed;

  /// 밝은 표지엔 어두운 결을, 어두운 표지엔 밝은 결을 넣어야 무늬가 보입니다.
  bool get _darkBase =>
      ThemeData.estimateBrightnessForColor(base) == Brightness.dark;

  Color _ink(double a) =>
      (_darkBase ? Colors.white : Colors.black).withValues(alpha: a);

  Color _counter(double a) =>
      (_darkBase ? Colors.black : Colors.white).withValues(alpha: a);

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    switch (texture) {
      case FolderTexture.kraft:
        _kraft(canvas, size, rng);
      case FolderTexture.linen:
        _linen(canvas, size, rng);
      case FolderTexture.leather:
        _leather(canvas, size, rng);
      case FolderTexture.marble:
        _marble(canvas, size, rng);
      case FolderTexture.pressboard:
        _pressboard(canvas, size, rng);
    }
  }

  /// 마닐라 크라프트. 반점 + 눕힌 섬유.
  void _kraft(Canvas canvas, Size size, math.Random rng) {
    final area = size.width * size.height;
    final dot = Paint();

    final speckles = (area / 120).clamp(60, 2200).toInt();
    for (var i = 0; i < speckles; i++) {
      dot.color = (rng.nextBool() ? _ink(0.10) : _counter(0.07))
          .withValues(alpha: rng.nextDouble() * 0.10);
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.0,
        dot,
      );
    }

    final strand = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final strands = (area / 700).clamp(0, 900).toInt();
    for (var i = 0; i < strands; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = 4 + rng.nextDouble() * 12;
      final tilt = (rng.nextDouble() - 0.5) * 0.45;
      strand
        ..strokeWidth = 0.45 + rng.nextDouble() * 0.55
        ..color = (rng.nextDouble() < 0.55 ? _ink(0.09) : _counter(0.08))
            .withValues(alpha: rng.nextDouble() * 0.09);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + math.cos(tilt) * len, y + math.sin(tilt) * len),
        strand,
      );
    }
  }

  /// 리넨 클로스. 가로/세로 실이 교차하는 촘촘한 격자.
  void _linen(Canvas canvas, Size size, math.Random rng) {
    final warp = Paint()..strokeWidth = 0.9;
    const step = 3.0;

    for (double y = 0; y < size.height; y += step) {
      warp.color = _ink(0.030 + rng.nextDouble() * 0.022);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), warp);
      warp.color = _counter(0.030);
      canvas.drawLine(Offset(0, y + 1.2), Offset(size.width, y + 1.2), warp);
    }
    for (double x = 0; x < size.width; x += step) {
      warp.color = _ink(0.026 + rng.nextDouble() * 0.018);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), warp);
    }

    // 실이 뭉친 자리.
    final slub = Paint();
    for (var i = 0; i < (size.width * size.height / 2400).toInt(); i++) {
      slub.color = _ink(0.05 * rng.nextDouble());
      canvas.drawRect(
        Rect.fromLTWH(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height,
          2 + rng.nextDouble() * 5,
          1.4,
        ),
        slub,
      );
    }
  }

  /// 가죽. 불규칙한 세포 무늬 + 모공.
  void _leather(Canvas canvas, Size size, math.Random rng) {
    final cell = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final n = (size.width * size.height / 900).clamp(20, 700).toInt();
    for (var i = 0; i < n; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 4 + rng.nextDouble() * 9;
      cell.color = _ink(0.035 + rng.nextDouble() * 0.045);
      final path = Path();
      for (var k = 0; k <= 6; k++) {
        final a = k / 6 * math.pi * 2;
        final rr = r * (0.72 + rng.nextDouble() * 0.5);
        final p = Offset(cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.78);
        k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path..close(), cell);
    }

    final pore = Paint();
    for (var i = 0; i < (size.width * size.height / 260).toInt(); i++) {
      pore.color = _ink(0.05 * rng.nextDouble());
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        0.5 + rng.nextDouble() * 0.7,
        pore,
      );
    }
  }

  /// 마블 페이퍼. 물결처럼 흐르는 결.
  void _marble(Canvas canvas, Size size, math.Random rng) {
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final lines = (size.height / 4).clamp(10, 140).toInt();
    for (var i = 0; i < lines; i++) {
      final y0 = rng.nextDouble() * size.height;
      final amp = 3 + rng.nextDouble() * 12;
      final freq = 0.012 + rng.nextDouble() * 0.03;
      final phase = rng.nextDouble() * math.pi * 2;

      vein
        ..strokeWidth = 0.6 + rng.nextDouble() * 1.6
        ..color = (rng.nextDouble() < 0.5 ? _ink(0.07) : _counter(0.07))
            .withValues(alpha: 0.035 + rng.nextDouble() * 0.06);

      final path = Path()..moveTo(0, y0);
      for (double x = 0; x <= size.width; x += 6) {
        path.lineTo(x, y0 + math.sin(x * freq + phase) * amp);
      }
      canvas.drawPath(path, vein);
    }
  }

  /// 프레스보드. 눌러 굳힌 판지의 잡티.
  void _pressboard(Canvas canvas, Size size, math.Random rng) {
    final fleck = Paint();
    final n = (size.width * size.height / 55).clamp(200, 5000).toInt();
    for (var i = 0; i < n; i++) {
      final dark = rng.nextDouble() < 0.6;
      fleck.color = (dark ? _ink(0.12) : _counter(0.10))
          .withValues(alpha: rng.nextDouble() * 0.13);
      final w = 0.6 + rng.nextDouble() * 2.6;
      canvas.drawRect(
        Rect.fromLTWH(
          rng.nextDouble() * size.width,
          rng.nextDouble() * size.height,
          w,
          w * (0.4 + rng.nextDouble() * 0.6),
        ),
        fleck,
      );
    }
  }

  @override
  bool shouldRepaint(FolderTexturePainter old) =>
      old.texture != texture || old.base != base || old.seed != seed;
}

/// 가장자리 비네트와 모서리 닳음.
///
/// 종이는 손이 닿는 자리부터 밝게 벗겨지고, 안으로 들어갈수록 그늘집니다.
/// 이 한 겹이 "인쇄된 사각형"을 "손에 쥐던 물건"으로 바꿔줍니다.
class EdgeWearPainter extends CustomPainter {
  EdgeWearPainter({required this.seed, this.strength = 1.0});

  final int seed;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rng = math.Random(seed ^ 0x5EED);
    final rect = Offset.zero & size;

    // 가장자리 그늘.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.92,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.06 * strength),
            Colors.black.withValues(alpha: 0.17 * strength),
          ],
          stops: const [0.55, 0.85, 1.0],
        ).createShader(rect),
    );

    // 모서리·가장자리가 하얗게 일어난 자국.
    final wear = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 90; i++) {
      final onSide = rng.nextInt(4);
      final t = rng.nextDouble();
      final depth = rng.nextDouble() * 3.2;
      final p = switch (onSide) {
        0 => Offset(t * size.width, depth),
        1 => Offset(size.width - depth, t * size.height),
        2 => Offset(t * size.width, size.height - depth),
        _ => Offset(depth, t * size.height),
      };
      wear
        ..color = Colors.white.withValues(alpha: rng.nextDouble() * 0.18 * strength)
        ..strokeWidth = 0.6 + rng.nextDouble() * 1.3;
      canvas.drawLine(p, p.translate(rng.nextDouble() * 5 - 2.5, 0), wear);
    }
  }

  @override
  bool shouldRepaint(EdgeWearPainter old) =>
      old.seed != seed || old.strength != strength;
}

/// 종이 두께 한 줄. 윗면은 빛을, 아랫면은 그늘을 받습니다.
///
/// 접힌 선·포켓 윗변처럼 "두께가 있는 경계"에 깔면 판이 갈라져 보입니다.
class PaperEdge extends StatelessWidget {
  const PaperEdge({super.key, this.strength = 1.0});

  final double strength;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 3,
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.16 * strength),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.22 * strength),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 눌러 찍은 글자. 잉크 아래로 파인 자국과 위쪽 하이라이트를 같이 넣습니다.
///
/// 라벨·표제를 이걸로 감싸면 인쇄가 아니라 **압인(deboss)** 처럼 보입니다.
class DebossedText extends StatelessWidget {
  const DebossedText(
      this.text, {
        super.key,
        required this.style,
        this.maxLines = 1,
        this.textAlign,
        this.depth = 1.0,
      });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign? textAlign;
  final double depth;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      softWrap: maxLines > 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style.copyWith(
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.30 * depth),
            offset: const Offset(0, -0.6),
            blurRadius: 0.8,
          ),
          Shadow(
            color: Colors.white.withValues(alpha: 0.34 * depth),
            offset: const Offset(0, 1.0),
            blurRadius: 1.0,
          ),
        ],
      ),
    );
  }
}