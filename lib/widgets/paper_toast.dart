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

/// 쪽지가 앉는 자리.
enum ToastAnchor {
  /// 상태 바 바로 아래. 기본값입니다.
  top,

  /// 화면 아래. 도구 줄·탭 바를 피해 96pt 띄웁니다.
  bottom,
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
///
/// ## 위쪽에 뜹니다
///
/// 예전에는 화면 **아래**에 떴습니다. 그런데 이 앱에서 아래쪽은 늘 손이
/// 올라가 있는 자리입니다 — 에디터 도구 줄, 서랍 탭 바. 쪽지가 방금 누른
/// 버튼을 그대로 덮었고, 종이 바탕이 칠해지지 않던 버그([PaperSurface] 참고)
/// 까지 겹쳐 그 아래 아이콘이 다 비쳐 보였습니다. 자리를 위로 옮기고,
/// 들어오는 동안에도 반투명한 구간이 거의 없게 다시 맞췄습니다.
class PaperToast {
  PaperToast._();

  static OverlayEntry? _current;

  /// 앱 전체의 기본 자리. 여기 한 줄만 바꾸면 전부 따라옵니다.
  static ToastAnchor anchor = ToastAnchor.top;

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

    // ⚠️ `onGone: dismiss` 로 두면 안 됩니다.
    //
    // 쪽지 A가 사라지는 320ms 사이에 쪽지 B가 뜨면, 뒤늦게 끝난 A의 콜백이
    // `dismiss()` 를 불러 **B를 지웁니다**. 알림이 연달아 뜨는 자리(레이어를
    // 떼고 바로 되돌리기)에서 두 번째 알림이 깜빡이고 사라졌습니다.
    // 자기 자신만 지우게 묶어 둡니다.
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastLayer(
        message: message,
        detail: detail,
        tone: tone,
        duration: duration,
        anchor: anchor,
        onGone: () => _remove(entry),
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
    final entry = _current;
    _current = null;
    if (entry != null && entry.mounted) entry.remove();
  }

  static void _remove(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
    if (identical(_current, entry)) _current = null;
  }
}

class _ToastLayer extends StatefulWidget {
  const _ToastLayer({
    required this.message,
    required this.detail,
    required this.tone,
    required this.duration,
    required this.anchor,
    required this.onGone,
  });

  final String message;
  final String? detail;
  final ToastTone tone;
  final Duration duration;
  final ToastAnchor anchor;
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
    final pad = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final atTop = widget.anchor == ToastAnchor.top;

    return Positioned(
      left: 14,
      right: 14,
      // 상태 바 바로 아래. 아래쪽은 도구 줄과 탭 바가 쓰는 자리라 비워 둡니다.
      top: atTop ? pad.top + 10 : null,
      // 아래에 둘 때도 96pt 는 띄웁니다. 그래야 도구 줄을 덮지 않습니다.
      bottom: atTop ? null : keyboard + pad.bottom + 96,
      child: AnimatedBuilder(
        animation: _in,
        builder: (context, child) {
          final v = _in.value.clamp(0.0, 1.0);
          final t = Curves.easeOutCubic.transform(v);
          return Opacity(
            // 흐릿한 구간을 최대한 짧게 잡습니다. 0.35 만 지나면 완전히
            // 불투명해서, 실제로 읽는 2.6초 내내 종이는 종이입니다.
            // (예전에는 뒤에 있는 툴바 아이콘이 글자 사이로 다 비쳤습니다.)
            opacity: (v / 0.35).clamp(0.0, 1.0),
            child: Transform.translate(
              // 놓인 자리 쪽에서 미끄러져 들어옵니다.
              offset: Offset(0, (t - 1) * (atTop ? 24 : -24)),
              child: Transform.rotate(angle: -0.012 * t, child: child),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _out,
            // 위로 쓸어 올리면 바로 치웁니다.
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (atTop ? v < -120 : v > 120) _out();
            },
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

  /// 한글이 한 자라도 있으면 본문 서체로 씁니다.
  static final _hangul = RegExp(r'[가-힣]');

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
            child: IntrinsicHeight(
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
                            const SizedBox(height: 5),
                            Text(
                              detail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              // `ROADMAP · PHASE 1` 같은 분류 문자열은 타자기체가
                              // 맞습니다. 하지만 한글 안내문을 9pt 고정폭에
                              // 자간까지 벌려 찍으면 그냥 안 읽힙니다.
                              // 글자를 보고 서체를 고릅니다.
                              style: _hangul.hasMatch(detail!)
                                  ? AppText.ui(
                                size: 11.5,
                                height: 1.4,
                                color: AppColors.inkSoft,
                              )
                                  : AppText.data(
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