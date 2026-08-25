import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/loading.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_toast.dart';
import '../../widgets/stub_button.dart';

/// 로그인 · 회원가입.
///
/// 두 화면으로 나누지 않고 하나에서 모드만 바꿉니다. 필드가 이름 하나
/// 차이라서, 화면을 나누면 같은 코드를 두 벌 관리하게 됩니다.
///
/// 폼은 **입국 심사대 서류**처럼 생겼습니다. 라벨은 대문자 타자기체로 위에
/// 얹고, 입력 칸은 밑줄 한 줄입니다.
///
/// ## 이번에 고친 것
///
/// 1. **모드 전환이 화면 맨 아래 텍스트 버튼에 숨어 있었습니다.** 회원가입을
///    하려면 폼 전체를 지나쳐 내려가야 보였습니다. 이제 워드마크 바로 아래
///    **종이 인덱스 탭 두 칸**으로 올렸습니다. 밑줄이 미끄러지며 옮겨가는
///    모양은 하단 탭바(`bottom_nav_bar.dart`)와 같은 어법입니다.
/// 2. **틀린 곳을 알려주지 않았습니다.** 예전에는 제출하고 나서야 토스트 한
///    줄이 떴고, 그 줄은 어느 칸이 틀렸는지 말하지 않았습니다. 이제 오류는
///    **틀린 칸 바로 아래에** 적히고, 라벨과 밑줄이 옥스블러드로 바뀌며,
///    첫 번째 오류 칸으로 포커스가 옮겨갑니다. 폼 전체가 한 번 흔들립니다.
/// 3. **첫 시도 전에는 잔소리하지 않습니다.** 검사는 한 번 제출한 뒤부터
///    실시간으로 돕니다. 타이핑 중에 빨간 글씨가 따라붙는 폼은 초조합니다.
/// 4. 비밀번호 **확인 칸**과 **강도 막대**를 붙였습니다. 이 앱은 서버가 없어
///    비밀번호를 되찾을 방법이 없습니다. 오타 한 글자가 곧 계정 분실입니다.
/// 5. 이 기기에 저장된 계정이 있으면 **이메일을 미리 채웁니다.**
/// 6. 키보드가 올라오면 워드마크가 접히고 폼이 그 자리를 씁니다.
/// 7. 배경 조명을 스플래시와 같은 값으로 맞췄습니다. `AppGate`의
///    `AnimatedSwitcher`가 넘어갈 때 배경이 이어져 종이 한 장이 얹히는
///    것처럼 보입니다.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode {
  signIn('로그인', 'IN'),
  signUp('가입하기', 'NEW');

  const AuthMode(this.label, this.code);

  /// 탭과 발권 버튼에 같은 말을 씁니다. 버튼이 "들어가기"인데 탭이
  /// "로그인"이면 같은 동작이 이름 두 개를 갖게 됩니다.
  final String label;

  /// 버튼 절취 조각에 찍히는 코드.
  final String code;
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late AuthMode _mode = widget.initialMode;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  final _nameNode = FocusNode();
  final _emailNode = FocusNode();
  final _passwordNode = FocusNode();
  final _confirmNode = FocusNode();

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  /// 한 번이라도 제출했는가. 이 전에는 검사하지 않습니다.
  bool _touched = false;

  bool _obscure = true;

  /// 화면에 들어오면서 요소가 차례로 올라옵니다.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..forward();

  /// 제출이 막혔을 때 폼을 한 번 흔듭니다.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool get _isSignUp => _mode == AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _password, _confirm]) {
      c.addListener(_liveCheck);
    }
    // 강도 막대는 비밀번호 칸에 손이 닿아 있을 때만 보입니다.
    _passwordNode.addListener(_repaint);
    _prefillEmail();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    for (final f in [_nameNode, _emailNode, _passwordNode, _confirmNode]) {
      f.dispose();
    }
    _intro.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  /// 이 기기에 계정이 있으면 이메일을 미리 적어 둡니다.
  ///
  /// 계정이 하나뿐인 기기 저장 방식이라 "누구로 로그인할지"는 물어볼 필요가
  /// 없습니다. 비밀번호 칸으로 바로 보냅니다.
  Future<void> _prefillEmail() async {
    final saved = await AuthService.instance.knownEmail();
    if (!mounted) return;
    if (saved == null || saved.isEmpty) return;
    if (_mode != AuthMode.signIn || _email.text.isNotEmpty) return;

    _email.text = saved;
    setState(() {});
  }

  // ── 검사 ──────────────────────────────────────────

  static final _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _liveCheck() {
    if (!_touched) return;
    setState(_check);
  }

  /// 네 칸을 한 번에 훑고 오류 문구를 적어 둡니다.
  ///
  /// 문구는 **무엇이 잘못됐는지가 아니라 무엇을 하면 되는지** 말합니다.
  /// "이메일 형식이 올바르지 않습니다"보다 "@가 빠졌어요"가 짧고 정확합니다.
  void _check() {
    final signUp = _isSignUp;
    final email = _email.text.trim();
    final pw = _password.text;

    _nameError = signUp && _name.text.trim().isEmpty ? '이름을 적어주세요' : null;

    if (email.isEmpty) {
      _emailError = '이메일을 적어주세요';
    } else if (!email.contains('@')) {
      _emailError = '@가 빠졌어요';
    } else if (!_emailShape.hasMatch(email)) {
      _emailError = '이메일 주소를 다시 봐주세요';
    } else {
      _emailError = null;
    }

    if (pw.isEmpty) {
      _passwordError = '비밀번호를 적어주세요';
    } else if (signUp && pw.length < 8) {
      _passwordError = '8자 이상으로 해주세요';
    } else {
      _passwordError = null;
    }

    _confirmError =
    signUp && _confirm.text != pw ? '위에 적은 것과 달라요' : null;
  }

  bool get _clean =>
      _nameError == null &&
          _emailError == null &&
          _passwordError == null &&
          _confirmError == null;

  void _focusFirstError() {
    if (_isSignUp && _nameError != null) return _nameNode.requestFocus();
    if (_emailError != null) return _emailNode.requestFocus();
    if (_passwordError != null) return _passwordNode.requestFocus();
    if (_confirmError != null) _confirmNode.requestFocus();
  }

  /// 비밀번호 강도. -1 = 아직 안 적음, 0~3.
  int get _strength {
    final p = _password.text;
    if (p.isEmpty) return -1;
    if (p.length < 8) return 0;

    final kinds = <RegExp>[
      RegExp(r'[a-z]'),
      RegExp(r'[A-Z]'),
      RegExp(r'\d'),
      RegExp(r'[^A-Za-z0-9]'),
    ].where((r) => r.hasMatch(p)).length;

    var s = 1;
    if (p.length >= 12) s++;
    if (kinds >= 3) s++;
    return math.min(s, 3);
  }

  // ── 동작 ──────────────────────────────────────────

  void _setMode(AuthMode next) {
    if (next == _mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      // 순서 중요. `_touched`를 먼저 내려야 아래 clear()가 부르는
      // _liveCheck 가 오류를 다시 적지 않습니다.
      _touched = false;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
      _mode = next;
      _password.clear();
      _confirm.clear();
    });
  }

  void _reject() {
    HapticFeedback.heavyImpact();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduced) _shake.forward(from: 0);
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _touched = true;
      _check();
    });

    if (!_clean) {
      _reject();
      _focusFirstError();
      return;
    }

    final result = await runWithLoader<AuthResult>(
      context,
      label: _isSignUp ? '계정 만드는 중' : '확인하는 중',
      task: () => _isSignUp
          ? AuthService.instance.signUp(
        email: _email.text,
        password: _password.text,
        name: _name.text,
      )
          : AuthService.instance.signIn(
        email: _email.text,
        password: _password.text,
      ),
    );

    if (!mounted) return;

    if (result.isOk) {
      // 비밀번호 관리자에게 "저장할까요?"를 띄울 마지막 기회입니다.
      TextInput.finishAutofillContext();
      // 화면은 직접 밀지 않습니다. AppGate 가 AuthService 를 구독하고
      // 있어서 알아서 갈아 끼웁니다.
      return;
    }

    // 서버(지금은 로컬)가 돌려준 실패를 **해당 칸 아래로** 내려보냅니다.
    // 토스트만 띄우면 어느 칸을 고쳐야 하는지 알 수 없습니다.
    setState(() {
      switch (result.failure!) {
        case AuthFailure.emptyName:
          _nameError = result.message;
        case AuthFailure.badEmail:
        case AuthFailure.alreadyExists:
          _emailError = result.message;
        case AuthFailure.weakPassword:
        case AuthFailure.wrongCredentials:
          _passwordError = result.message;
      }
    });
    _reject();
    _focusFirstError();

    // 이미 계정이 있다는 건 "가입 실패"가 아니라 "로그인하러 가야 함"입니다.
    if (result.failure == AuthFailure.alreadyExists) {
      PaperToast.warn(context, result.message, detail: '위 탭에서 로그인으로 바꿔주세요');
    } else {
      PaperToast.warn(context, result.message);
    }
  }

  // ── 화면 ──────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // 키보드가 올라온 상태. 워드마크를 접어 폼에 자리를 내줍니다.
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 스플래시와 **같은 조명**. 화면이 갈아 끼워질 때 배경이 이어집니다.
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
          const Positioned.fill(child: WallGrain(opacity: 0.05, seed: 11)),

          SafeArea(
            child: AutofillGroup(
              child: CustomScrollView(
                // 폼이 짧으면 가운데, 키보드로 좁아지면 스크롤.
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _brand(compact, reduced),
                          _Rise(
                            animation: _intro,
                            order: 1,
                            reduced: reduced,
                            child: _ModeTabs(mode: _mode, onPick: _setMode),
                          ),
                          const SizedBox(height: 20),
                          _Rise(
                            animation: _intro,
                            order: 2,
                            reduced: reduced,
                            child: _helper(),
                          ),
                          const SizedBox(height: 30),
                          _shakeable(
                            _Rise(
                              animation: _intro,
                              order: 3,
                              reduced: reduced,
                              child: _fields(),
                            ),
                          ),
                          const SizedBox(height: 34),
                          _Rise(
                            animation: _intro,
                            order: 4,
                            reduced: reduced,
                            child: Center(
                              child: TicketStubButton(
                                onPressed: _submit,
                                label: _mode.label,
                                code: _mode.code,
                                width: 240,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _Rise(
                            animation: _intro,
                            order: 5,
                            reduced: reduced,
                            child: _footnote(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand(bool compact, bool reduced) {
    return AnimatedSize(
      duration: Duration(milliseconds: reduced ? 0 : 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.bottomCenter,
      child: compact
          ? const SizedBox(height: 4, width: double.infinity)
          : Padding(
        padding: const EdgeInsets.only(bottom: 42),
        child: _Rise(
          animation: _intro,
          order: 0,
          reduced: reduced,
          // notchColor 를 주지 않아 **진짜 구멍**으로 뚫습니다.
          // 배경에 조명 그라디언트가 깔려 있어서, 단색 원을 얹으면
          // 그 두 점만 색이 어긋납니다.
          child: const Center(child: PunchedWordmark(scale: 0.58)),
        ),
      ),
    );
  }

  /// 탭이 이미 "로그인 / 가입하기"라고 말하고 있으므로 큰 표제는 두지
  /// 않습니다. 대신 **이 화면이 실제로 무엇을 하는지** 한 줄만 적습니다.
  Widget _helper() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: SizedBox(
        key: ValueKey(_mode),
        width: double.infinity,
        child: Text(
          _isSignUp
              ? '이메일과 비밀번호만 있으면 됩니다.'
              : '이 기기에 저장된 계정으로 들어갑니다.',
          style: AppText.ui(size: 12.5, height: 1.5, color: AppColors.inkSoft),
        ),
      ),
    );
  }

  Widget _shakeable(Widget child) {
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, inner) {
        if (_shake.value == 0) return inner!;
        final t = _shake.value;
        final dx = math.sin(t * math.pi * 5) * 7 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: inner);
      },
      child: child,
    );
  }

  Widget _fields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 이름 — 가입할 때만. 접히고 펴집니다.
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _isSignUp
              ? Column(
            children: [
              _Field(
                label: 'NAME',
                hint: '뭐라고 부를까요',
                controller: _name,
                focusNode: _nameNode,
                error: _nameError,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                onSubmitted: (_) => _emailNode.requestFocus(),
              ),
              const SizedBox(height: 22),
            ],
          )
              : const SizedBox(width: double.infinity),
        ),

        _Field(
          label: 'EMAIL',
          hint: 'you@example.com',
          controller: _email,
          focusNode: _emailNode,
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _passwordNode.requestFocus(),
        ),
        const SizedBox(height: 22),

        _Field(
          label: 'PASSWORD',
          hint: _isSignUp ? '8자 이상' : '',
          controller: _password,
          focusNode: _passwordNode,
          error: _passwordError,
          obscure: _obscure,
          textInputAction:
          _isSignUp ? TextInputAction.next : TextInputAction.done,
          onSubmitted: (_) =>
          _isSignUp ? _confirmNode.requestFocus() : _submit(),
          autofillHints: [
            _isSignUp ? AutofillHints.newPassword : AutofillHints.password,
          ],
          trailing: _EyeToggle(
            hidden: _obscure,
            onTap: () => setState(() => _obscure = !_obscure),
          ),
          // 강도 막대는 가입할 때, 칸에 손이 닿아 있을 때만.
          // 로그인 화면에서 남의 비밀번호를 채점할 이유는 없습니다.
          footer: _isSignUp && (_passwordNode.hasFocus || _strength >= 0)
              ? _StrengthMeter(score: _strength)
              : null,
        ),

        // 비밀번호 확인 — 가입할 때만.
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _isSignUp
              ? Column(
            children: [
              const SizedBox(height: 22),
              _Field(
                label: 'CONFIRM',
                hint: '한 번 더',
                controller: _confirm,
                focusNode: _confirmNode,
                error: _confirmError,
                obscure: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _footnote() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _isSignUp
          ? Text(
        '가입하면 이용약관과 개인정보 처리방침에 동의한 것으로 봅니다.\n'
            '계정은 설정에서 언제든 지울 수 있어요.',
        textAlign: TextAlign.center,
        style: AppText.ui(size: 11, height: 1.7, color: AppColors.pulp),
      )
          : const SizedBox(width: double.infinity),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 모드 탭
// ─────────────────────────────────────────────────────────────

/// 로그인 / 가입 두 칸. 밑줄이 미끄러져 옮겨갑니다.
///
/// 하단 탭바와 같은 어법입니다. 종이 서류철에 꽂힌 인덱스 탭 두 장을
/// 위에서 내려다본 모양.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onPick});

  final AuthMode mode;
  final ValueChanged<AuthMode> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final m in AuthMode.values)
              Expanded(
                child: Semantics(
                  button: true,
                  selected: m == mode,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onPick(m),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                          style: AppText.ui(
                            size: 13.5,
                            weight:
                            m == mode ? FontWeight.w700 : FontWeight.w500,
                            color: m == mode ? AppColors.ink : AppColors.pulp,
                            spacing: m == mode ? 0.4 : 0,
                          ),
                          child: Text(m.label),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 2,
          child: Stack(
            children: [
              const Positioned.fill(child: ColoredBox(color: AppColors.line)),
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                alignment: mode == AuthMode.signIn
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: const FractionallySizedBox(
                  widthFactor: 0.5,
                  child: SizedBox(
                    height: 2,
                    child: ColoredBox(color: AppColors.oxblood),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 입력 한 칸
// ─────────────────────────────────────────────────────────────

/// 서류 양식처럼 생긴 입력 한 칸.
///
/// 오류가 있으면 라벨·밑줄·문구가 모두 옥스블러드로 넘어갑니다. 색 하나가
/// 세 군데에서 동시에 바뀌므로, 눈이 어디를 봐도 그 칸을 찾습니다.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.focusNode,
    this.hint = '',
    this.error,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.trailing,
    this.footer,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode? focusNode;

  /// null 이면 정상. 문자열이면 칸 아래에 그대로 찍힙니다.
  final String? error;

  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  /// 오류가 없을 때 칸 아래에 붙는 것(강도 막대 등).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final bad = error != null;
    final accent = bad ? AppColors.oxblood : AppColors.foil;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 160),
          style: AppText.eyebrow(color: accent, size: 9),
          child: Text(label),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscure,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                autofillHints: autofillHints,
                onSubmitted: onSubmitted,
                cursorColor: AppColors.oxblood,
                cursorWidth: 1.4,
                style: AppText.ui(size: 15, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: AppText.ui(size: 14, color: AppColors.pulp),
                  contentPadding: const EdgeInsets.only(bottom: 8),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: bad ? AppColors.oxblood : AppColors.line,
                      width: bad ? 1.4 : 1,
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide:
                    BorderSide(color: AppColors.oxblood, width: 1.4),
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        // 오류 문구와 부가물이 같은 자리를 씁니다. 둘 다 보이면 칸 간격이
        // 들쭉날쭉해집니다.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: bad
              ? Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              error!,
              style: AppText.ui(
                size: 11.5,
                height: 1.3,
                color: AppColors.oxblood,
              ),
            ),
          )
              : (footer ?? const SizedBox(width: double.infinity)),
        ),
      ],
    );
  }
}

/// 비밀번호 보이기/숨기기.
class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.hidden, required this.onTap});

  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: hidden ? '비밀번호 보기' : '비밀번호 숨기기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        // 아이콘만 두면 터치 영역이 18px 입니다. 손가락에 안 걸립니다.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 2, 6),
          child: Icon(
            hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: AppColors.pulp,
          ),
        ),
      ),
    );
  }
}

/// 비밀번호 강도 막대 세 칸.
///
/// 점수를 매기려는 게 아니라, **이 앱에는 비밀번호 찾기가 없다**는 사실을
/// 대신 말해 줍니다. 서버가 없어서 잊으면 그것으로 끝입니다.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.score});

  /// -1 = 안 적음, 0 = 8자 미만, 1~3.
  final int score;

  static const _labels = ['8자 미만', '보통', '괜찮음', '튼튼함'];

  @override
  Widget build(BuildContext context) {
    if (score < 0) return const SizedBox(width: double.infinity);

    final color = switch (score) {
      0 => AppColors.pulp,
      1 => AppColors.foil,
      2 => AppColors.kraftDeep,
      _ => const Color(0xFF44503F), // 올리브
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                height: 3,
                color: i < score ? color : AppColors.line,
              ),
            ),
            const SizedBox(width: 5),
          ],
          SizedBox(
            width: 54,
            child: Text(
              _labels[score.clamp(0, 3)],
              textAlign: TextAlign.right,
              style: AppText.data(size: 9.5, spacing: 0.6, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 등장
// ─────────────────────────────────────────────────────────────

/// 화면에 들어올 때 순서대로 8px 올라오며 나타납니다.
///
/// 한꺼번에 페이드하면 화면이 "켜지고", 순서가 있으면 "놓입니다".
/// 모션 축소 설정에서는 그냥 바로 보입니다.
class _Rise extends StatelessWidget {
  const _Rise({
    required this.animation,
    required this.order,
    required this.child,
    this.reduced = false,
  });

  final Animation<double> animation;
  final int order;
  final Widget child;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    if (reduced) return child;

    final begin = math.min(order * 0.075, 0.5);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, math.min(begin + 0.55, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, inner) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - curved.value)),
          child: inner,
        ),
      ),
      child: child,
    );
  }
}