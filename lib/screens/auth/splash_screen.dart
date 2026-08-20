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
  static const minimumHold = Duration(milliseconds: 900);

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
          const Positioned.fill(child: WallGrain(opacity: 0.05, seed: 3)),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),

                // 브랜드 락업 2e. 도록 표제지 형식이라 첫 화면에 어울립니다.
                const TitlePlateLogo(scale: 1.0),

                const Spacer(flex: 4),

                // 기다림은 언제나 티켓 조각이 쌓이는 모양으로.
                StackingLoader(size: 96, label: label),

                const Spacer(flex: 3),

                Text(
                  'ADMIT ONE · KEEP THIS STUB',
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