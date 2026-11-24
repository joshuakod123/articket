import 'package:material_ui/material_ui.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/brand_logo.dart';
import 'password_reset_screen.dart';

enum AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode mode = AuthMode.signIn;
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false, obscure = true;
  String? error;
  @override
  void initState() {
    super.initState();
    AuthService.instance.knownEmail().then((v) {
      if (mounted && email.text.isEmpty) email.text = v ?? '';
    });
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final result = mode == AuthMode.signIn
        ? await AuthService.instance.signIn(
            email: email.text,
            password: password.text,
          )
        : await AuthService.instance.signUp(
            email: email.text,
            password: password.text,
            name: name.text,
          );
    if (mounted) {
      setState(() {
        busy = false;
        error = result.isOk ? null : result.message;
      });
    }
  }

  Widget input(
    String label,
    TextEditingController controller, {
    bool secret = false,
    bool isEmail = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: TextFormField(
      controller: controller,
      obscureText: secret && obscure,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      autofillHints: isEmail
          ? const [AutofillHints.email]
          : secret
          ? const [AutofillHints.password]
          : const [AutofillHints.name],
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: secret
            ? IconButton(
                tooltip: obscure ? '비밀번호 보기' : '비밀번호 숨기기',
                onPressed: () => setState(() => obscure = !obscure),
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : null,
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return '$label 입력해 주세요';
        if (isEmail &&
            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) {
          return '이메일 주소를 확인해 주세요';
        }
        if (secret && mode == AuthMode.signUp && v.length < 8) {
          return '8자 이상 입력해 주세요';
        }
        if (controller == confirm && v != password.text) {
          return '비밀번호가 일치하지 않아요';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 34),
              const Center(child: ArticketLogo(height: 58, vertical: true)),
              const SizedBox(height: 34),
              Text(
                mode == AuthMode.signIn ? '다시 만나서 반가워요' : '나만의 기록을 시작해요',
                textAlign: TextAlign.center,
                style: AppText.display(size: 25),
              ),
              const SizedBox(height: 12),
              Text(
                '나의 관람 기록을 이어가보세요.',
                textAlign: TextAlign.center,
                style: AppText.ui(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 28),
              SegmentedButton<AuthMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: AuthMode.signIn, label: Text('로그인')),
                  ButtonSegment(value: AuthMode.signUp, label: Text('회원가입')),
                ],
                selected: {mode},
                onSelectionChanged: busy
                    ? null
                    : (v) => setState(() {
                        mode = v.first;
                        error = null;
                        form.currentState?.reset();
                      }),
              ),
              const SizedBox(height: 24),
              AutofillGroup(
                child: Form(
                  key: form,
                  child: Column(
                    children: [
                      if (mode == AuthMode.signUp) input('이름', name),
                      input('이메일', email, isEmail: true),
                      input('비밀번호', password, secret: true),
                      if (mode == AuthMode.signUp)
                        input('비밀번호 확인', confirm, secret: true),
                    ],
                  ),
                ),
              ),
              if (mode == AuthMode.signIn)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: busy
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const PasswordResetScreen(),
                            ),
                          ),
                    child: const Text('비밀번호를 잊으셨나요?'),
                  ),
                ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: AppText.ui(color: AppColors.danger),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(
                  busy
                      ? '처리하는 중…'
                      : mode == AuthMode.signIn
                      ? '로그인'
                      : '회원가입',
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '기록은 기본적으로 나에게만 보입니다.',
                textAlign: TextAlign.center,
                style: AppText.ui(size: 12, color: AppColors.inkSoft),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
