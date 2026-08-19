import 'package:flutter/material.dart';

/// **고정 설계 크기**로 한 번 그린 뒤, 통째로 확대/축소해 상자에 맞춥니다.
///
/// ## 왜 필요한가
///
/// 공유 카드처럼 "화면에서 보던 그림을 그대로 다른 비율의 종이에 옮겨 앉히는"
/// 자리에서, 그냥 작은 상자에 넣으면 **레이아웃이 다시 흐릅니다.**
/// 티켓은 상자에 맞춰 작아지는데 글자 크기(13.5pt)와 여백(18pt)은 그대로라,
/// 결과적으로 글자만 거대해지고 줄이 겹쳐 보입니다. 사용자가 본 "비율이 깨진"
/// 화면이 정확히 이 현상입니다.
///
/// [ScaledCanvas]는 반대로 갑니다. 자식을 **항상 [design] 크기로 레이아웃한 뒤**
/// 그 결과를 사진처럼 균일 배율로 줄입니다. 그러면 글자·여백·티켓이 전부 같은
/// 비율로 작아지므로, 어떤 기기·어떤 상자에 넣어도 그림이 똑같습니다.
///
/// 시스템 글자 배율([MediaQuery.textScaler])도 안쪽에서 끊습니다. 인쇄물은
/// 접근성 설정에 따라 판이 바뀌면 안 되니까요.
class ScaledCanvas extends StatelessWidget {
  const ScaledCanvas({
    super.key,
    required this.design,
    required this.child,
    this.alignment = Alignment.center,
    this.fit = BoxFit.contain,
  });

  /// 자식이 레이아웃될 논리 크기. 여기에 맞춰 글자 크기를 정하면 됩니다.
  final Size design;

  final Widget child;
  final Alignment alignment;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: fit,
      alignment: alignment,
      child: SizedBox(
        width: design.width,
        height: design.height,
        child: MediaQuery.withNoTextScaling(child: child),
      ),
    );
  }
}