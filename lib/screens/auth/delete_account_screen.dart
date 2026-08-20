import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ticket_store.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/loading.dart';
import '../../widgets/paper.dart';
import '../../widgets/paper_toast.dart';

/// 계정 영구 삭제.
///
/// ## 왜 한 화면을 통째로 쓰나
///
/// 다이얼로그 하나로 끝내면 "확인"을 습관적으로 누릅니다. 그리고 이건
/// 되돌릴 수 없습니다. 그래서 세 단계를 지나야 합니다.
///
/// 1. **무엇이 사라지는지 숫자로** 보여줍니다. "티켓 6장"은 "모든 데이터"보다
///    훨씬 무겁게 읽힙니다.
/// 2. 안내 문구를 **손으로 따라 적습니다.** 확인 버튼과 달리 오타 없이
///    적으려면 문장을 읽어야 합니다.
/// 3. 마지막으로 비밀번호를 넣습니다. 잠금 해제된 남의 기기로 남의 계정을
///    날리는 걸 막습니다.
///
/// ## 애플 심사 (Guideline 5.1.1(v))
///
/// 계정을 만들 수 있는 앱은 **앱 안에서** 계정을 삭제할 수 있어야 합니다.
/// 웹 페이지로 보내거나 "고객센터로 문의하세요"로 넘기면 리젝입니다.
/// 비활성화(deactivate)만 제공하는 것도 안 됩니다 — 계정 자체와 그에 딸린
/// 데이터가 실제로 지워져야 합니다.
///
/// 또 하나 자주 놓치는 부분: **이 화면에 닿기까지 너무 깊으면 안 됩니다.**
/// 설정 안에 "계정" 안에 "고급" 안에 숨겨두면 지적받습니다. 지금은
/// 설정 첫 화면에서 한 번만 누르면 됩니다.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const _phrase = '기록을 모두 버립니다';

  final _confirm = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready =>
      _confirm.text.trim() == _phrase && _password.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final store = TicketStore.instance;
    final viewer = AuthService.instance.viewer;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('계정 삭제',
            style: AppText.ui(size: 14, weight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: WallGrain(opacity: 0.05, seed: 41)),
          ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 44),
            children: [
              // ── 1. 무엇이 사라지는가 ──────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.stock,
                  border: Border.all(color: AppColors.oxblood, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PERMANENT · 되돌릴 수 없음',
                        style: AppText.eyebrow(
                            color: AppColors.oxblood, size: 9)),
                    const SizedBox(height: 12),
                    Text('아래가 전부 사라집니다',
                        style:
                        AppText.display(size: 20, color: AppColors.ink)),
                    const SizedBox(height: 16),
                    _Line('티켓', '${store.tickets.length}장'),
                    _Line('서류철', '${store.folders.length}개'),
                    _Line('붙여둔 것',
                        '${store.tickets.fold<int>(0, (n, t) => n + t.layers.length)}개'),
                    _Line('계정', viewer?.email ?? '—'),
                    const SizedBox(height: 14),
                    Container(height: 1, color: AppColors.line),
                    const SizedBox(height: 12),
                    Text(
                      '발권 번호도 함께 회수됩니다. 같은 이메일로 다시 가입해도 '
                          '이전 기록은 복구되지 않습니다.',
                      style: AppText.ui(
                          size: 12, height: 1.65, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ── 2. 문구 받아 적기 ────────────────
              Text('CONFIRM', style: AppText.eyebrow(color: AppColors.foil, size: 9)),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: AppText.ui(size: 13, color: AppColors.inkSoft),
                  children: [
                    const TextSpan(text: '아래 문장을 그대로 적어주세요 — '),
                    TextSpan(
                      text: _phrase,
                      style: AppText.ui(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _Underlined(controller: _confirm, hint: _phrase),

              const SizedBox(height: 28),

              // ── 3. 비밀번호 ─────────────────────
              Text('PASSWORD',
                  style: AppText.eyebrow(color: AppColors.foil, size: 9)),
              const SizedBox(height: 10),
              _Underlined(controller: _password, hint: '', obscure: true),

              const SizedBox(height: 40),

              // ── 실행 ────────────────────────────
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _ready ? _delete : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.oxblood,
                    disabledBackgroundColor: AppColors.line,
                    foregroundColor: AppColors.stockLight,
                    disabledForegroundColor: AppColors.pulp,
                    shape: const RoundedRectangleBorder(),
                  ),
                  child: Text('영구 삭제',
                      style: AppText.ui(size: 15, weight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('그만두기',
                      style: AppText.ui(size: 13, color: AppColors.inkSoft)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    HapticFeedback.heavyImpact();

    final result = await runWithLoader<AuthResult>(
      context,
      label: '기록을 파쇄하는 중',
      task: () =>
          AuthService.instance.deleteAccount(password: _password.text),
    );

    if (!mounted) return;
    if (!result.isOk) {
      PaperToast.warn(context, result.message);
      return;
    }
    // 삭제가 끝나면 AuthService 의 stage 가 signedOut 으로 떨어지고,
    // AppGate 가 로그인 화면으로 갈아 끼웁니다. 여기서 pop 할 필요가 없습니다.
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label,
              style: AppText.ui(size: 12.5, color: AppColors.inkSoft)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(
                size: 12.5, weight: FontWeight.w700, color: AppColors.ink),
          ),
        ),
      ],
    ),
  );
}

class _Underlined extends StatelessWidget {
  const _Underlined({
    required this.controller,
    required this.hint,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    cursorColor: AppColors.oxblood,
    style: AppText.ui(size: 15, color: AppColors.ink),
    decoration: InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppText.ui(size: 14, color: AppColors.pulp),
      contentPadding: const EdgeInsets.only(bottom: 8),
      enabledBorder:
      const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
      focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.oxblood, width: 1.4)),
    ),
  );
}