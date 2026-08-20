import 'package:flutter/material.dart';

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
/// 얹고, 입력 칸은 밑줄 한 줄입니다. 머티리얼 기본 `OutlineInputBorder`를
/// 쓰면 이 화면만 다른 앱처럼 보입니다.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signIn});

  final AuthMode initialMode;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { signIn, signUp }

class _AuthScreenState extends State<AuthScreen> {
  late AuthMode _mode = widget.initialMode;

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _isSignUp => _mode == AuthMode.signUp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: WallGrain(opacity: 0.05, seed: 11)),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 34, 28, 40),
              children: [
                // 워드마크 자체가 티켓 조각인 락업(2a). 폼 위에 도장처럼.
                const Center(
                  child: PunchedWordmark(scale: 0.62, notchColor: AppColors.bg),
                ),
                const SizedBox(height: 40),

                Text(
                  _isSignUp ? '표를 받으러 오셨군요' : '다시 오셨네요',
                  style: AppText.display(size: 27, color: AppColors.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSignUp
                      ? '계정을 만들면 기록이 기기 밖으로도 따라갑니다.'
                      : '서랍은 그대로 있습니다.',
                  style: AppText.ui(size: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 34),

                if (_isSignUp) ...[
                  _Field(
                    label: 'NAME',
                    hint: '뭐라고 부를까요',
                    controller: _name,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 24),
                ],

                _Field(
                  label: 'EMAIL',
                  hint: 'you@example.com',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 24),

                _Field(
                  label: 'PASSWORD',
                  hint: _isSignUp ? '8자 이상' : '',
                  controller: _password,
                  obscure: _obscure,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  autofillHints: [
                    _isSignUp ? AutofillHints.newPassword : AutofillHints.password
                  ],
                  trailing: GestureDetector(
                    onTap: () => setState(() => _obscure = !_obscure),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: AppColors.pulp,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Center(
                  child: TicketStubButton(
                    onPressed: _submit,
                    label: _isSignUp ? '계정 만들기' : '들어가기',
                    code: _isSignUp ? 'NEW' : 'IN',
                    width: 236,
                  ),
                ),

                const SizedBox(height: 26),

                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _mode = _isSignUp ? AuthMode.signIn : AuthMode.signUp;
                      _password.clear();
                    }),
                    child: Text(
                      _isSignUp ? '이미 계정이 있어요' : '아직 계정이 없어요',
                      style: AppText.ui(
                        size: 13,
                        color: AppColors.oxblood,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                if (_isSignUp) ...[
                  const SizedBox(height: 18),
                  Text(
                    '계정을 만들면 이용약관과 개인정보 처리방침에 동의하는 것으로 봅니다.\n'
                        '언제든 설정에서 계정을 영구 삭제할 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: AppText.ui(size: 11, height: 1.6, color: AppColors.pulp),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final result = await runWithLoader<AuthResult>(
      context,
      label: _isSignUp ? '표를 끊는 중' : '확인하는 중',
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
    if (!result.isOk) {
      PaperToast.warn(context, result.message);
      return;
    }
    // 성공하면 화면을 직접 밀지 않습니다.
    // AppGate 가 AuthService 를 구독하고 있어서 알아서 갈아 끼웁니다.
  }
}

/// 서류 양식처럼 생긴 입력 한 칸.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint = '',
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.trailing,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.eyebrow(color: AppColors.foil, size: 9)),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: obscure,
                keyboardType: keyboardType,
                textInputAction: textInputAction,
                autofillHints: autofillHints,
                onSubmitted: onSubmitted,
                cursorColor: AppColors.oxblood,
                style: AppText.ui(size: 15, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hint,
                  hintStyle: AppText.ui(size: 14, color: AppColors.pulp),
                  contentPadding: const EdgeInsets.only(bottom: 8),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.oxblood, width: 1.4),
                  ),
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ],
    );
  }
}