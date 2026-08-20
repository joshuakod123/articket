import 'package:flutter/material.dart';

import 'data/ticket_store.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/root_shell.dart';
import 'services/auth_service.dart';

/// 스플래시 → 로그인 → 본 화면을 갈아 끼우는 자리.
///
/// ## 왜 화면을 밀지 않고 **갈아 끼우나**
///
/// 로그인 성공 뒤에 `Navigator.pushReplacement(RootShell())`를 쓰면
/// 로그아웃·탈퇴할 때 "지금 스택 어디까지 쌓여 있지?"를 매번 따져야 합니다.
/// 티켓 상세 → 편집 → 설정에서 탈퇴하면 세 장을 걷어내야 하는데,
/// 한 장이라도 남으면 삭제된 계정의 화면이 그대로 살아 있게 됩니다.
///
/// 대신 [AuthService]를 구독해 **최상위 위젯 하나만 바꿉니다.** 로그아웃되면
/// 그 아래 스택은 통째로 사라집니다. 화면 코드는 아무도 이걸 신경 쓰지 않습니다.
///
/// `AnimatedSwitcher`로 감싼 이유: 서랍이 열리는 앱인데 화면이 툭 바뀌면
/// 그 순간만 다른 앱 같습니다. 종이가 한 장 얹히듯 페이드로 넘깁니다.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  final _auth = AuthService.instance;
  final _store = TicketStore.instance;

  /// 스플래시가 최소 노출 시간을 채웠는지.
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // 세 가지를 **나란히** 기다립니다.
    // 순서대로 기다리면 스플래시가 그만큼 길어집니다.
    await Future.wait([
      _auth.restore(),
      _store.load(),
      Future<void>.delayed(SplashScreen.minimumHold),
    ]);
    if (mounted) setState(() => _held = true);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _auth,
      builder: (context, _) {
        final Widget screen;
        if (!_held || _auth.stage == AuthStage.unknown) {
          screen = const SplashScreen(key: ValueKey('splash'));
        } else if (_auth.stage == AuthStage.signedOut) {
          screen = const AuthScreen(key: ValueKey('auth'));
        } else {
          screen = const RootShell(key: ValueKey('shell'));
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: screen,
        );
      },
    );
  }
}