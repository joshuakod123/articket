import 'package:material_ui/material_ui.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key, this.recovering = false});
  final bool recovering;
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false, sent = false;
  String? error;
  @override
  void dispose() {
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
    final result = widget.recovering
        ? await AuthService.instance.finishPasswordReset(password.text)
        : await AuthService.instance.requestPasswordReset(email.text);
    if (mounted) {
      setState(() {
        busy = false;
        sent = result.isOk;
        error = result.isOk ? null : result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.recovering ? '새 비밀번호 설정' : '비밀번호 찾기')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.recovering
              ? '사용할 새 비밀번호를 입력해 주세요.'
              : '가입한 이메일로 비밀번호 재설정 링크를 보내드려요.',
        ),
        const SizedBox(height: 24),
        Form(
          key: form,
          child: Column(
            children: [
              if (!widget.recovering)
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: '이메일'),
                  validator: (v) =>
                      v == null ||
                          !RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(v.trim())
                      ? '이메일 주소를 확인해 주세요'
                      : null,
                ),
              if (widget.recovering) ...[
                TextFormField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '새 비밀번호'),
                  validator: (v) =>
                      v == null || v.length < 8 ? '8자 이상 입력해 주세요' : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: confirm,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                  validator: (v) =>
                      v != password.text ? '비밀번호가 일치하지 않아요' : null,
                ),
              ],
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        if (sent && !widget.recovering)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('이메일을 확인해 주세요. 메일이 없다면 스팸함도 확인해 주세요.'),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(
            busy
                ? '처리하는 중…'
                : widget.recovering
                ? '비밀번호 저장'
                : sent
                ? '이메일 다시 보내기'
                : '재설정 이메일 보내기',
          ),
        ),
        if (widget.recovering)
          TextButton(
            onPressed: busy ? null : () => AuthService.instance.signOut(),
            child: const Text('로그인 화면으로'),
          ),
      ],
    ),
  );
}
