import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'paper.dart';
import 'stacking_loader.dart';

/// 앱 안의 **모든** 기다림을 [StackingLoader] 하나로 통일하는 진입점.
///
/// 예전에는 두 자리(`share_card_screen`, `ticket_style_sheet`)에서
/// `CircularProgressIndicator`가 돌았습니다. 종이 위에 머티리얼 스피너가
/// 하나만 떠 있어도, 그 순간 앱이 "앱"으로 보입니다.
///
/// 쓰는 법은 세 가지입니다.
///
/// * [ArticketLoadingView] — 화면 전체가 비어 있는 동안 (스플래시, 첫 로드)
/// * [InlineLoader] — 카드 · 시트 안의 작은 자리 (미리보기 렌더 중)
/// * [runWithLoader] — 오래 걸리는 작업을 감싸는 모달 (저장, 내보내기, 탈퇴)
class ArticketLoadingView extends StatelessWidget {
  const ArticketLoadingView({super.key, this.label = '서랍을 여는 중'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: WallGrain(opacity: 0.05)),
          Center(child: StackingLoader(label: label)),
        ],
      ),
    );
  }
}

/// 시트나 카드 안에 들어가는 작은 로더.
///
/// 라벨은 붙이지 않습니다. 좁은 자리에서는 글자가 뭉치보다 더 눈에 띕니다.
class InlineLoader extends StatelessWidget {
  const InlineLoader({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) =>
      Center(child: StackingLoader(size: size));
}

/// 오래 걸리는 작업을 반투명 종이 막 뒤에서 돌립니다.
///
/// ```dart
/// final file = await runWithLoader(
///   context,
///   label: '카드를 굽는 중',
///   task: () => renderShareCard(...),
/// );
/// ```
///
/// * 작업이 끝나면 막을 **반드시** 걷습니다 (예외가 나도).
/// * 막이 떠 있는 동안 뒤로 가기를 막습니다. 반쯤 저장된 상태로 나가는 걸
///   방지하기 위해서입니다.
/// * 150ms 안에 끝나는 작업에는 막을 아예 띄우지 않습니다. 깜빡임이
///   기다림보다 더 거슬리기 때문입니다.
Future<T> runWithLoader<T>(
    BuildContext context, {
      required Future<T> Function() task,
      String label = '정리하는 중',
      Duration delay = const Duration(milliseconds: 150),
    }) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var shown = false;

  final timer = Future<void>.delayed(delay).then((_) {
    if (!navigator.mounted) return;
    shown = true;
    navigator.push(_LoaderRoute(label: label));
  });

  try {
    return await task();
  } finally {
    await timer;
    if (shown && navigator.mounted) navigator.pop();
  }
}

class _LoaderRoute extends PageRouteBuilder<void> {
  _LoaderRoute({required this.label})
      : super(
    opaque: false,
    barrierDismissible: false,
    barrierColor: const Color(0xB3EDE3D0), // AppColors.bg 70%
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, anim, _) => PopScope(
      canPop: false,
      child: Center(child: StackingLoader(label: label)),
    ),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );

  final String label;
}