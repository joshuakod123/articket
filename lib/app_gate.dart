import 'package:flutter/material.dart';

import 'data/sync_service.dart';
import 'data/ticket_store.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'screens/root_shell.dart';
import 'screens/onboarding/welcome_tour.dart';
import 'screens/auth/password_reset_screen.dart';
import 'services/auth_service.dart';
import 'services/guide_service.dart';
import 'theme/app_colors.dart';

/// 스플래시 → 로그인 → 본 화면을 갈아 끼우는 자리.
///
/// ## 왜 화면을 밀지 않고 **갈아 끼우나**
///
/// 로그인 성공 뒤에 `Navigator.pushReplacement(RootShell())`를 쓰면
/// 로그아웃·탈퇴할 때 "지금 스택 어디까지 쌓여 있지?"를 매번 따져야 합니다.
/// 티켓 상세 → 편집 → 설정에서 탈퇴하면 세 장을 걷어내야 하는데,
/// 한 장이라도 남으면 삭제된 계정의 화면이 그대로 살아 있게 됩니다.
///
/// 대신 [AuthService]를 구독해 **최상위 한 장만 바꿉니다.**
///
/// ## 예전 구조의 구멍 (이번에 고친 것)
///
/// 예전에는 여기서 [AnimatedSwitcher]로 위젯만 갈아 끼웠습니다. 그런데
/// 이 [AppGate]는 `MaterialApp.home`, 즉 **루트 Navigator의 첫 번째 라우트**
/// 입니다. 화면들이 부르는 `Navigator.of(context).push(...)`는 전부
/// 그 루트 Navigator, 다시 말해 **AppGate 위쪽**에 쌓였습니다.
///
///     루트 Navigator
///       ├─ '/'  →  AppGate  →  AnimatedSwitcher  →  RootShell
///       ├─ SettingsScreen      ← 로그아웃 버튼이 여기 있음
///       └─ …
///
/// 그래서 설정에서 로그아웃하면 밑바닥의 `RootShell`만 `AuthScreen`으로
/// 바뀌고, 그 위에 덮인 `SettingsScreen`은 **그대로 남았습니다.** 화면은
/// 안 바뀌었는데 그 아래에서는 로그인 화면이 통째로 새로 지어지느라
/// 한 프레임이 크게 밀립니다. "메시지가 뜨고 살짝 튀는" 정체가 이것입니다.
///
/// 이제 [AppGate]가 **자기 Navigator를 직접 들고** 있습니다. 화면들이 미는
/// 라우트는 전부 이 안쪽에 쌓이고, `pages` 목록에서 페이지 한 장이 빠지면
/// **그 위에 얹혀 있던 라우트도 함께 걷힙니다**(Navigator가 pageless route를
/// 소속 page에 매답니다). 화면 코드는 여전히 아무것도 신경 쓰지 않습니다.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

/// 지금 무엇을 보여줄지. `AuthStage`와 부팅 상태를 합친 값입니다.
enum _Gate { splash, welcome, auth, recovery, shell }

class _AppGateState extends State<AppGate> {
  final _auth = AuthService.instance;
  final _store = TicketStore.instance;

  final _navigatorKey = GlobalKey<NavigatorState>();

  /// 중첩 Navigator는 `MaterialApp`의 히어로 컨트롤러를 **같이 쓸 수
  /// 없습니다**(하나의 컨트롤러는 Navigator 하나에만 붙습니다). 서류철 →
  /// 티켓 상세의 `Hero`가 죽지 않도록 이 Navigator 전용으로 하나 만듭니다.
  final _heroController = MaterialApp.createMaterialHeroController();

  /// 스플래시가 최소 노출 시간을 채웠는지.
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  /// ## 여기서 순서를 지켜야 하는 이유 (이번에 고친 것)
  ///
  /// 예전에는 셋을 `Future.wait` 로 한꺼번에 돌렸습니다. 그리고 그 목록에
  /// **`SyncService.attach()` 가 아예 빠져 있었습니다.**
  ///
  /// `attach()` 는 문서에 "`AppGate._boot()` 에서 [TicketStore.load] 뒤에
  /// 부릅니다"라고 적혀 있었는데, 실제로는 앱 어디에서도 호출되지 않았습니다.
  /// 그래서 `_attached` 가 영원히 false 였고, 그 결과는
  ///
  ///   · `noteChange()` 가 첫 줄에서 되돌아감  → **수정이 서버에 안 올라감**
  ///   · `_rescan()` 도 마찬가지               → 지운 것도 반영 안 됨
  ///   · 그림자·커서·묘비를 디스크에서 안 읽음 → 동기화가 돌 때마다 전부
  ///     처음부터 다시 올림
  ///
  /// 에러는 한 줄도 안 났습니다. 사용자는 기기를 바꾸고 나서야 알게 됩니다.
  ///
  /// 이제 **읽기 → 붙이기 → 세션 복구** 순서로 줄을 세웁니다. `restore()` 가
  /// 안에서 첫 동기화를 거는데, 그때는 저장소도 그림자도 준비돼 있어야
  /// 합니다. 스플래시 최소 노출 시간만 옆에서 같이 흐릅니다.
  Future<void> _boot() async {
    try {
      final hold = Future<void>.delayed(SplashScreen.minimumHold);

      // 1. 기기에 있는 것부터. (SharedPreferences 라 보통 100ms 아래)
      await _store.load();
      await GuideService.instance.load();

      // 2. 동기화 엔진을 저장소에 붙입니다. 반드시 load() 뒤.
      await SyncService.instance.attach();

      // 3. 세션 복구. 성공하면 여기서 첫 동기화가 걸립니다.
      await Future.wait([_auth.restore(), hold]);
    } catch (e, s) {
      debugPrint('부팅 실패: $e\n$s');
      // 세션을 못 읽었으면 로그아웃 상태로 봅니다. 최소한 로그인 화면은 뜹니다.
      if (_auth.stage == AuthStage.unknown) await _auth.signOut();
    } finally {
      if (mounted) setState(() => _held = true);
    }
  }

  _Gate get _gate {
    if (!_held || _auth.stage == AuthStage.unknown) return _Gate.splash;
    if (_auth.needsPasswordReset) return _Gate.recovery;
    if (_auth.stage == AuthStage.signedOut) {
      return GuideService.instance.introSeen ? _Gate.auth : _Gate.welcome;
    }
    return _Gate.shell;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_auth, GuideService.instance]),
      builder: (context, _) {
        // `_GatePage`도 자식 화면도 const 라, 이름 변경 같은 다른 알림으로
        // 다시 그려도 Navigator 입장에서는 **같은 페이지**입니다.
        // 라우트가 새로 지어지지 않습니다.
        final Page<void> page = switch (_gate) {
          _Gate.splash => _GatePage.splash,
          _Gate.welcome => _GatePage.welcome,
          _Gate.recovery => _GatePage.recovery,
          _Gate.auth => _GatePage.auth,
          _Gate.shell => _GatePage.shell,
        };

        // 안드로이드 뒤로가기를 **안쪽** Navigator로 먼저 보냅니다.
        // 이게 없으면 설정 화면에서 뒤로가기를 눌렀을 때 안쪽이 아니라
        // 루트가 pop 되어 앱이 그대로 닫힙니다.
        //
        // ⚠️ 콜백은 `PopResultCallback<T>` = `void Function(T? result)`,
        // 인자가 **하나**입니다. `PopScope.onPopInvokedWithResult`
        // (`(didPop, result)`)와 헷갈리기 쉽습니다. 여기로 들어왔다는 것
        // 자체가 "안쪽이 처리할 수 있다"는 뜻이라 didPop 이 필요 없습니다.
        return NavigatorPopHandler(
          onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
          // 페이지가 교차되는 아주 짧은 순간에도 흰 바탕이 비치지 않게
          // 바닥에 같은 종이색을 깔아 둡니다.
          child: ColoredBox(
            color: AppColors.bg,
            child: HeroControllerScope(
              controller: _heroController,
              child: Navigator(
                key: _navigatorKey,
                pages: <Page<void>>[page],
                // 페이지 목록은 위 상태에서 파생됩니다. 여기서 따로 되돌릴
                // 것이 없습니다.
                onDidRemovePage: (_) {},
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 서랍이 열리는 앱인데 화면이 툭 바뀌면 그 순간만 다른 앱 같습니다.
/// 종이가 한 장 얹히듯 페이드로 넘깁니다.
class _GatePage extends Page<void> {
  const _GatePage({required super.key, required this.child});

  final Widget child;

  static const splash = _GatePage(
    key: ValueKey('splash'),
    child: SplashScreen(),
  );
  static const welcome = _GatePage(
    key: ValueKey('welcome'),
    child: WelcomeTour(),
  );
  static const recovery = _GatePage(
    key: ValueKey('recovery'),
    child: PasswordResetScreen(recovering: true),
  );
  static const auth = _GatePage(key: ValueKey('auth'), child: AuthScreen());
  static const shell = _GatePage(key: ValueKey('shell'), child: RootShell());

  @override
  Route<void> createRoute(BuildContext context) {
    return PageRouteBuilder<void>(
      settings: this,
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => child,
      transitionsBuilder: (_, animation, __, child) {
        // ⚠️ 여기서 `CurvedAnimation`을 새로 만들면 프레임마다 하나씩
        // 쌓입니다(3.27부터 dispose 대상입니다). `drive`는 그냥 평가만
        // 하는 래퍼라 버릴 것이 없습니다.
        final t = animation.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: t,
          // 0.985 → 1.0. 이 이상 주면 "확대"로 읽혀서 화면이 튑니다.
          child: ScaleTransition(
            scale: t.drive(Tween<double>(begin: 0.985, end: 1.0)),
            child: child,
          ),
        );
      },
    );
  }
}
