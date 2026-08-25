import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/paper.dart';
import '../../widgets/stacking_loader.dart';

/// 앱을 켜고 서랍을 꺼내는 동안.
///
/// 여기서 실제로 기다리는 것은 두 가지입니다.
/// `AuthService.restore()` (세션 읽기)와 `TicketStore.load()` (티켓 읽기).
/// 둘 다 보통 100ms 안에 끝나므로, 화면은 **최소 노출 시간**을 따로 둡니다.
/// 안 그러면 로고가 한 프레임 번쩍이고 사라져서 깜빡임으로만 보입니다.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.label = '서랍을 여는 중'});

  final String label;

  /// 로고가 최소한 이만큼은 머뭅니다.
  static const minimumHold = Duration(milliseconds: 1600);

  /// 표제 액자가 화면 가장자리에서 최소한 이만큼 떨어집니다.
  static const _margin = 46.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // 서랍 안쪽과 같은 조명. 스플래시에서 첫 화면으로 넘어갈 때
          // 배경이 이어져서 화면이 갈아 끼워진 느낌이 덜합니다.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 1.1,
                  colors: [Color(0x33FFF8EA), Color(0x00FFF8EA)],
                ),
              ),
            ),
          ),
          const WallGrain(opacity: 0.05, seed: 3),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),

                // 브랜드 락업 2e. 도록 표제지 형식이라 첫 화면에 어울립니다.
                //
                // ⚠️ `TitlePlateLogo(scale: 1.0)` 만 놓으면 안 됩니다.
                // 이 락업의 좌우 여백은 `46 * scale` 로 **고정**인데, 안쪽
                // `ARTICKET` 의 실제 폭은 Bodoni 의 글자 실측치라 기기·글꼴
                // 로딩 상태에 따라 달라집니다. 둘을 더한 값이 화면 폭을 넘으면
                // 액자가 가장자리에 딱 붙고, 워드마크만 혼자 커 보입니다.
                //
                // Padding 을 **바깥**에, FittedBox 를 **안쪽**에 두는 순서가
                // 중요합니다. 반대로 하면 여백까지 같이 축소돼서 결국 또 붙습니다.
                // scaleDown 이라 좁은 기기에서만 줄어들고, 넓은 기기에서는
                // 원래 크기 그대로입니다. 액자 안쪽 비율은 어느 쪽이든 그대로입니다.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: _margin),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: TitlePlateLogo(scale: 0.92),
                  ),
                ),

                const Spacer(flex: 4),

                // 기다림은 언제나 티켓 조각이 쌓이는 모양으로.
                StackingLoader(size: 96, label: label),

                const Spacer(flex: 3),

                // 판심(判心)에 인쇄된 한 줄.
                //
                // 예전 문구는 'ADMIT ONE · KEEP THIS STUB' 이었습니다.
                // 티켓 위에 찍히기엔 맞는 말이지만 **앱 이름이 없어서**,
                // 첫 화면 맨 아래에 두면 이게 무슨 앱인지 말해주지 않습니다.
                //
                // Courier Prime 이라 ASCII 만 넣습니다. 한글을 섞으면 그
                // 글자만 대체 글꼴로 떨어져서 이 줄 혼자 다르게 보입니다.
                Text(
                  'COLLECT · KEEP · REMEMBER',
                  style: AppText.eyebrow(color: AppColors.pulp, size: 9)
                      .copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ],
      ),
    );
  }
}