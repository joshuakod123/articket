import 'package:material_ui/material_ui.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Selected identity 05: an AT ribbon monogram, rendered as vector paths.
class ArticketLogo extends StatelessWidget {
  const ArticketLogo({
    super.key,
    this.height = 24,
    this.vertical = false,
    this.symbolOnly = false,
    this.color = AppColors.ink,
  });
  final double height;
  final bool vertical;
  final bool symbolOnly;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final mark = Semantics(
      label: symbolOnly ? 'Articket' : null,
      child: SizedBox(
        width: height * 1.5,
        height: height,
        child: CustomPaint(painter: ATMarkPainter(color)),
      ),
    );
    if (symbolOnly) return mark;
    final label = Text(
      'ARTICKET',
      style: AppText.wordmark(
        size: vertical ? height * .28 : height * .55,
        spacing: height * .12,
        color: color,
      ),
    );
    return Semantics(
      label: 'Articket',
      excludeSemantics: true,
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                mark,
                SizedBox(height: height * .24),
                label,
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                mark,
                SizedBox(width: height * .4),
                label,
              ],
            ),
    );
  }
}

class ATMarkPainter extends CustomPainter {
  const ATMarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 96, size.height / 64);
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(28, 0)
        ..lineTo(93, 0)
        ..lineTo(83, 15)
        ..lineTo(62, 15)
        ..lineTo(92, 64)
        ..lineTo(70, 64)
        ..lineTo(39, 15)
        ..lineTo(19, 15)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(24, 23)
        ..lineTo(44, 23)
        ..lineTo(18, 64)
        ..lineTo(0, 64)
        ..close(),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(41, 36)
        ..lineTo(59, 64)
        ..lineTo(39, 64)
        ..lineTo(31, 51)
        ..close(),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ATMarkPainter oldDelegate) => oldDelegate.color != color;
}

// Compatibility wrappers for existing entry points; there is one identity now.
class PunchedWordmark extends StatelessWidget {
  const PunchedWordmark({
    super.key,
    this.scale = 1,
    this.background = AppColors.bg,
    this.foreground = AppColors.ink,
    this.notchColor,
    this.caption = '',
  });
  final double scale;
  final Color background, foreground;
  final Color? notchColor;
  final String caption;
  @override
  Widget build(BuildContext context) =>
      ArticketLogo(height: 42 * scale, color: foreground);
}

class TitlePlateLogo extends StatelessWidget {
  const TitlePlateLogo({
    super.key,
    this.scale = 1,
    this.eyebrow = '',
    this.subtitle = '',
    this.ink = AppColors.ink,
    this.hairline = AppColors.line,
    this.accent = AppColors.accent,
    this.foil = AppColors.foil,
  });
  final double scale;
  final String eyebrow, subtitle;
  final Color ink, hairline, accent, foil;
  @override
  Widget build(BuildContext context) =>
      ArticketLogo(height: 66 * scale, vertical: true, color: ink);
}
