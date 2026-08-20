import 'package:flutter/material.dart';

/// 인쇄물(티켓 · 회원증)을 **절대 찌그러뜨리지 않고** 상자에 앉히는 스케일러.
///
/// ## 왜 필요한가
///
/// 예전 [TicketFront] · [TicketCanvas]는 이렇게 그렸습니다.
///
/// ```dart
/// SizedBox(
///   width: c.maxWidth,          // 부모가 준 상자 그대로
///   height: c.maxHeight,        // 부모가 준 상자 그대로
///   child: FittedBox(
///     fit: BoxFit.fill,         // ← 원도를 상자에 억지로 늘림
///     child: SizedBox(width: 300, height: 300 / aspect, child: ...),
///   ),
/// )
/// ```
///
/// `BoxFit.fill`은 **가로·세로 배율을 따로 잡습니다.** 부모가 준 상자의 비율이
/// 티켓 비율과 조금이라도 다르면 그 차이가 그대로 왜곡으로 나옵니다.
/// 지금까지는 호출부가 전부 `AspectRatio`로 감싸 준 덕분에 우연히 맞았을 뿐입니다.
/// 그리고 다음 자리에서는 그 전제가 깨집니다.
///
/// * **Hero 비행 중** — 오버레이가 출발 사각형과 도착 사각형을 보간해 물립니다.
///   중간 프레임의 비율은 어느 쪽과도 다릅니다.
/// * **tight 제약** — `AspectRatio`는 `constraints.isTight`이면 계산을 포기하고
///   `constraints.smallest`를 그대로 돌려줍니다. 즉 `Positioned.fill`,
///   `SizedBox.expand` 아래에서는 `AspectRatio`가 **아무 일도 하지 않습니다.**
/// * 호출부가 하나라도 `AspectRatio`를 빠뜨리는 순간.
///
/// [PrintBox]는 규칙을 뒤집습니다. **비율은 위젯 자신이 지키고, 부모는 최대 크기만
/// 알려줍니다.** 안에서 비율을 지키는 가장 큰 사각형을 직접 구하므로,
/// 호출부가 무엇으로 감싸든 티켓은 절대 늘어나지 않습니다.
///
/// 시스템 글자 배율도 안쪽에서 끊습니다. 인쇄물은 접근성 설정에 따라 판이
/// 바뀌면 안 됩니다.
class PrintBox extends StatelessWidget {
  const PrintBox({
    super.key,
    required this.design,
    required this.child,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.none,
  });

  /// 자식이 레이아웃될 논리 크기. 글자 크기·여백을 여기에 맞춰 적으면 됩니다.
  final Size design;

  final Widget child;

  /// 상자가 원도보다 넉넉할 때 남는 여백에서 어느 쪽에 붙일지.
  final Alignment alignment;

  /// 스티커가 티켓 밖으로 삐져나오는 게 자연스러운 자리에서는 [Clip.none].
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final aspect = design.width / design.height;

    return LayoutBuilder(
      builder: (context, c) {
        final bw = c.hasBoundedWidth;
        final bh = c.hasBoundedHeight;

        double w;
        double h;
        if (bw && bh) {
          // 두 변 다 정해졌으면 BoxFit.contain 과 같은 계산.
          w = c.maxWidth;
          h = w / aspect;
          if (h > c.maxHeight) {
            h = c.maxHeight;
            w = h * aspect;
          }
        } else if (bw) {
          w = c.maxWidth;
          h = w / aspect;
        } else if (bh) {
          h = c.maxHeight;
          w = h * aspect;
        } else {
          // 무한 제약(스크롤 뷰 안 등)에서는 원도 크기로 폴백합니다.
          w = design.width;
          h = design.height;
        }

        // Align 을 한 겹 두는 이유:
        // 부모가 tight 제약을 걸어도 Align 은 자식에게 loose 를 넘겨줍니다.
        // 덕분에 안쪽 SizedBox 가 계산한 크기를 지킬 수 있습니다.
        // (Align 은 무한 축을 만나면 스스로 shrink-wrap 하므로 여기서도 안전)
        return Align(
          alignment: alignment,
          child: SizedBox(
            width: w,
            height: h,
            child: FittedBox(
              // 이 시점에서 상자와 원도의 비율이 **정확히 같으므로**
              // fill 이어도 가로·세로 배율이 동일합니다. 왜곡이 없습니다.
              fit: BoxFit.fill,
              clipBehavior: clipBehavior,
              child: SizedBox(
                width: design.width,
                height: design.height,
                child: MediaQuery.withNoTextScaling(child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 남은 높이에 **줄 단위로** 들어가는 만큼만 본문을 흘립니다.
///
/// 예전 티켓 뒷면은 감상문을 `Expanded` + `TextOverflow.fade`로 그렸습니다.
/// `Expanded`가 준 높이가 두 줄 반이면 세 번째 줄이 **글자 중간에서 잘려서**
/// 아래 `WITH` 줄과 겹쳐 보였습니다. (스크린샷의 "좋았음"이 반쯤 잘린 자리)
///
/// 이 위젯은 실제 줄 높이로 몇 줄이 들어가는지 세어서 `maxLines`를 정합니다.
/// 잘릴 때는 말줄임표로 끝나므로 "여기서 끊겼다"가 눈에 보입니다.
class FittedParagraph extends StatelessWidget {
  const FittedParagraph({
    super.key,
    required this.text,
    required this.style,
    this.alignment = Alignment.topLeft,
  });

  final String text;

  /// `height`(줄 간격 배수)가 반드시 지정된 스타일이어야 합니다.
  final TextStyle style;

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final lineHeight = (style.fontSize ?? 14) * (style.height ?? 1.4);
        final lines = (c.maxHeight / lineHeight).floor();
        if (lines < 1) return const SizedBox.shrink();

        return Align(
          alignment: alignment,
          child: Text(
            text,
            maxLines: lines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        );
      },
    );
  }
}