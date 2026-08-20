import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 브랜드 락업 두 종.
///
/// - [PunchedWordmark]  시안 2a. 옥스블러드 띠에 이름을 얹고 위·아래 가운데를
///   반원 타공이 물어 워드마크 자체가 티켓 조각이 됩니다.
///   앱바 타이틀 · 스플래시 · 온보딩 표제에.
/// - [TitlePlateLogo]   시안 2e. 도록 표제지 형식(이중 괘선 + 황동 소제목 +
///   옥스블러드 마름모)을 접어 넣은 락업. 스플래시 · 공유 카드 · 설정 하단에.
///
/// 두 위젯 모두 색은 [AppColors], 서체는 [AppText]만 씁니다.
/// 크기는 `scale` 하나로 조절합니다 — 안에서 폰트·여백·타공이 같은 비율로 커집니다.

// ─────────────────────────────────────────────────────────────
// 2a — PUNCHED WORDMARK
// ─────────────────────────────────────────────────────────────

class PunchedWordmark extends StatelessWidget {
  const PunchedWordmark({
    super.key,
    this.scale = 1.0,
    this.background = AppColors.oxblood,
    this.foreground = AppColors.stock,
    this.notchColor,
    this.caption = 'ADMIT ONE · KEEP THIS STUB',
  });

  /// 1.0 = 워드마크 34pt / 타공 지름 26. 아이콘·앱바에서는 0.45~0.6.
  final double scale;

  final Color background;
  final Color foreground;

  /// 타공으로 비쳐 보이는 **뒷면 색**. 지정하지 않으면 타공을 뚫지 않고
  /// [ClipPath]로 잘라내 실제 구멍을 냅니다(배경이 무엇이든 안전).
  final Color? notchColor;

  /// 띠 아래 황동 캡션. 빈 문자열이면 그리지 않습니다.
  final String caption;

  @override
  Widget build(BuildContext context) {
    final band = _Band(
      scale: scale,
      background: background,
      foreground: foreground,
      notchColor: notchColor,
    );

    if (caption.isEmpty) return band;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        band,
        SizedBox(height: 16 * scale),
        Text(
          caption,
          style: AppText.eyebrow(color: AppColors.foil, size: 10 * scale)
              .copyWith(letterSpacing: 3 * scale),
        ),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.scale,
    required this.background,
    required this.foreground,
    this.notchColor,
  });

  final double scale;
  final Color background;
  final Color foreground;
  final Color? notchColor;

  @override
  Widget build(BuildContext context) {
    final radius = 13.0 * scale;

    final label = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 44 * scale,
        vertical: 20 * scale,
      ),
      child: Text(
        'ARTICKET',
        style: AppText.wordmark(
          size: 34 * scale,
          spacing: 11 * scale,
          color: foreground,
        ),
      ),
    );

    // 뒷면 색을 아는 경우엔 그 색 원을 얹는 편이 저렴합니다(클립 없음).
    if (notchColor != null) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ColoredBox(color: background, child: label),
          Positioned(
            top: -radius,
            child: _Dot(radius: radius, color: notchColor!),
          ),
          Positioned(
            bottom: -radius,
            child: _Dot(radius: radius, color: notchColor!),
          ),
        ],
      );
    }

    return ClipPath(
      clipper: _NotchClipper(radius: radius),
      child: ColoredBox(color: background, child: label),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// 띠 위·아래 가운데를 반원으로 물어냅니다.
class _NotchClipper extends CustomClipper<Path> {
  _NotchClipper({required this.radius});

  final double radius;

  @override
  Path getClip(Size size) {
    final body = Path()..addRect(Offset.zero & size);
    final holes = Path()
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, 0),
        radius: radius,
      ))
      ..addOval(Rect.fromCircle(
        center: Offset(size.width / 2, size.height),
        radius: radius,
      ));
    return Path.combine(PathOperation.difference, body, holes);
  }

  @override
  bool shouldReclip(_NotchClipper old) => old.radius != radius;
}

// ─────────────────────────────────────────────────────────────
// 2e — TITLE PAGE FRAME
// ─────────────────────────────────────────────────────────────

class TitlePlateLogo extends StatelessWidget {
  const TitlePlateLogo({
    super.key,
    this.scale = 1.0,
    this.eyebrow = 'THE TICKET DRAWER',
    this.subtitle = '티켓 다이어리',
    this.ink = AppColors.ink,
    this.hairline = AppColors.pulp,
    this.accent = AppColors.oxblood,
    this.foil = AppColors.foil,
  });

  final double scale;

  /// 괘선 위 황동 소제목. ASCII만 (Courier Prime).
  final String eyebrow;

  /// 마름모 아래 한글 부제. 고운바탕.
  final String subtitle;

  final Color ink;
  final Color hairline;
  final Color accent;
  final Color foil;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 46 * scale,
        vertical: 26 * scale,
      ),
      decoration: BoxDecoration(border: Border.all(color: ink, width: 1)),
      child: Container(
        padding: EdgeInsets.all(5 * scale),
        decoration: BoxDecoration(border: Border.all(color: hairline, width: 1)),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                eyebrow,
                style: AppText.eyebrow(color: foil, size: 9 * scale)
                    .copyWith(letterSpacing: 3.2 * scale),
              ),
              SizedBox(height: 12 * scale),
              Text(
                'ARTICKET',
                style: AppText.wordmark(
                  size: 33 * scale,
                  spacing: 10 * scale,
                  color: ink,
                ),
              ),
              SizedBox(height: 12 * scale),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40 * scale, height: 1, color: hairline),
                  SizedBox(width: 9 * scale),
                  Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 5 * scale,
                      height: 5 * scale,
                      color: accent,
                    ),
                  ),
                  SizedBox(width: 9 * scale),
                  Container(width: 40 * scale, height: 1, color: hairline),
                ],
              ),
              SizedBox(height: 12 * scale),
            Text(
                subtitle,
                style: AppText.display(
                  size: 14 * scale,
                  weight: FontWeight.w400,
                  color: AppColors.inkSoft,
                  spacing: 3 * scale,
                ),
              ),
            ],
        ),
      ),
    );
  }
}
