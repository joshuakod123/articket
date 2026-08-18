import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';
import 'scrapbook.dart' show WashiTape;

/// 알림의 성격. 색과 도장 문구만 달라집니다.
enum ToastTone {
  /// 그냥 알려주는 말.
  note('MEMO', AppColors.foil),

  /// 잘 끝났다는 확인 도장.
  done('FILED', Color(0xFF44503F)),

  /// 안 된 일.
  warn('VOID', AppColors.oxblood);

  const ToastTone(this.stamp, this.accent);

  final String stamp;
  final Color accent;
}

/// 책상에 툭 놓인 **종이 쪽지**.
///
/// 머티리얼 SnackBar의 검은 알약은 이 앱 어디에도 없는 재질이라, 화면 위에
/// 이물질처럼 떴습니다. 대신 다른 모든 것과 같은 종이를 씁니다.
///
/// - 미색 용지 + 종이 결 + 얕은 그림자
/// - 왼쪽 위에 마스킹 테이프 한 조각
/// - 왼쪽에 성격별 색 띠, 위에 타자기 도장 문구(`MEMO` / `FILED` / `VOID`)
/// - 살짝 비뚤게(−0.012 rad) 앉아서 "붙여 놓은 쪽지"처럼 보입니다
///
/// `Overlay`에 직접 띄우므로 `Scaffold`가 없어도, 모달 시트 위에서도 뜹니다.
class PaperToast {
  PaperToast._();

  static OverlayEntry? _current;

  static void show(
      BuildContext context,
      String message, {
        ToastTone tone = ToastTone.note,
        String? detail,
        Duration duration = const Duration(milliseconds: 2600),
      }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    dismiss();
    HapticFeedback.selectionClick();

    final entry = OverlayEntry(
      builder: (context) => _ToastLayer(
        message: message,
        detail: detail,
        tone: tone,
        duration: duration,
        onGone: dismiss,
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  /// 잘 끝났을 때.
  static void done(BuildContext context, String message, {String? detail}) =>
      show(context, message, tone: ToastTone.done, detail: detail);

  /// 안 됐을 때.
  static void warn(BuildContext context, String message, {String? detail}) =>
      show(context, message, tone: ToastTone.warn, detail: detail);

  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer({
    required this.message,
    required this.detail,
    required this.tone,
    required this.duration,
    required this.onGone,
  });

  final String message;
  final String? detail;
  final ToastTone tone;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_ToastLayer> createState() => _ToastLayerState();
}

class _ToastLayerState extends State<_ToastLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.duration, _out);
  }

  Future<void> _out() async {
    if (!mounted) return;
    await _in.reverse();
    if (mounted) widget.onGone();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: bottom + MediaQuery.paddingOf(context).bottom + 22,
      child: AnimatedBuilder(
        animation: _in,
        builder: (context, child) {
          final t = Curves.easeOutBack.transform(_in.value.clamp(0.0, 1.0));
          return Opacity(
            opacity: _in.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * 26),
              child: Transform.rotate(angle: -0.012 * t, child: child),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _out,
            child: _Slip(
              message: widget.message,
              detail: widget.detail,
              tone: widget.tone,
            ),
          ),
        ),
      ),
    );
  }
}

class _Slip extends StatelessWidget {
  const _Slip({
    required this.message,
    required this.detail,
    required this.tone,
  });

  final String message;
  final String? detail;
  final ToastTone tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.7)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PaperSurface(
            color: AppColors.stockLight,
            grain: 0.07,
            seed: message.hashCode,
            fiber: 0.7,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 왼쪽 색 띠. 서류에 그은 형광펜 자리.
                Container(width: 4, color: tone.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StampMark(text: tone.stamp, color: tone.accent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.line,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.ui(
                            size: 13.5,
                            height: 1.45,
                            color: AppColors.ink,
                          ),
                        ),
                        if (detail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.data(
                              size: 9,
                              spacing: 0.8,
                              color: AppColors.pulp,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 왼쪽 위 모서리에 붙인 마스킹 테이프.
          const Positioned(
            left: -10,
            top: -9,
            child: WashiTape(
              width: 58,
              height: 17,
              color: Color(0x99C7B79A),
              angle: -0.42,
            ),
          ),
        ],
      ),
    );
  }
}

/// 고무 도장으로 찍은 듯한 작은 라벨. 테두리가 살짝 어긋나 있습니다.
class _StampMark extends StatelessWidget {
  const _StampMark({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.03,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.75), width: 1.2),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: AppText.data(
            size: 9,
            spacing: 2.2,
            weight: FontWeight.w700,
            color: color.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}