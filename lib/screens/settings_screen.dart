import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/brand_logo.dart';
import '../widgets/loading.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import 'auth/delete_account_screen.dart';

/// 설정.
///
/// 서류철 색인 카드처럼 **묶음(section)** 으로 나눕니다. 각 묶음 위에는
/// 타자기체 대문자 라벨이 붙고, 항목 사이는 헤어라인 한 줄입니다.
/// 머티리얼 `ListTile` 기본 스타일을 그대로 쓰면 이 화면만 튑니다.
///
/// 위험한 항목(로그아웃 · 계정 삭제)은 맨 아래 별도 묶음으로 내리고,
/// 계정 삭제만 옥스블러드로 칠합니다. 색이 두 개 이상이면 경고가 아니라
/// 장식이 됩니다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('설정', style: AppText.ui(size: 14, weight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: WallGrain(opacity: 0.05, seed: 29)),
          ListenableBuilder(
            listenable: auth,
            builder: (context, _) {
              final v = auth.viewer;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 46),
                children: [
                  // ── 계정 ─────────────────────────
                  _Section(
                    label: 'ACCOUNT',
                    children: [
                      _Row(
                        title: '이름',
                        value: v?.name ?? '—',
                        onTap: () => _rename(context, v?.name ?? ''),
                      ),
                      _Row(title: '이메일', value: v?.email ?? '—'),
                      _Row(
                        title: '비밀번호 바꾸기',
                        chevron: true,
                        onTap: () => _changePassword(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ── 앱 ──────────────────────────
                  _Section(
                    label: 'ABOUT',
                    children: [
                      const _Row(title: '버전', value: '0.1.0'),
                      _Row(
                        title: '이용약관',
                        chevron: true,
                        onTap: () => PaperToast.show(context, '준비 중입니다'),
                      ),
                      _Row(
                        title: '개인정보 처리방침',
                        chevron: true,
                        onTap: () => PaperToast.show(context, '준비 중입니다'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ── 위험 구역 ────────────────────
                  _Section(
                    label: 'DANGER',
                    children: [
                      _Row(
                        title: '로그아웃',
                        note: '기록은 기기에 남습니다',
                        onTap: () => _signOut(context),
                      ),
                      _Row(
                        title: '계정 삭제',
                        note: '되돌릴 수 없습니다',
                        danger: true,
                        chevron: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DeleteAccountScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 48),
                  const Center(child: TitlePlateLogo(scale: 0.52)),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final next = await showDialog<String>(
      context: context,
      builder: (context) => _PaperDialog(
        title: '뭐라고 부를까요',
        child: TextField(
          controller: controller,
          autofocus: true,
          cursorColor: AppColors.oxblood,
          style: AppText.ui(size: 15, color: AppColors.ink),
          decoration: const InputDecoration(
            isDense: true,
            enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.oxblood)),
          ),
        ),
        onConfirm: () => Navigator.of(context).pop(controller.text),
      ),
    );

    if (next == null || next.trim().isEmpty) return;
    await AuthService.instance.rename(next);
    if (context.mounted) PaperToast.done(context, '이름을 고쳤습니다');
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();

    final go = await showDialog<bool>(
      context: context,
      builder: (context) => _PaperDialog(
        title: '비밀번호 바꾸기',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MiniField(controller: current, label: '지금 비밀번호'),
            const SizedBox(height: 18),
            _MiniField(controller: next, label: '새 비밀번호 (8자 이상)'),
          ],
        ),
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (go != true || !context.mounted) return;

    final result = await runWithLoader<AuthResult>(
      context,
      label: '바꾸는 중',
      task: () => AuthService.instance
          .changePassword(current: current.text, next: next.text),
    );

    if (!context.mounted) return;
    result.isOk
        ? PaperToast.done(context, '비밀번호를 바꿨습니다')
        : PaperToast.warn(context, result.message);
  }

  Future<void> _signOut(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => _PaperDialog(
        title: '로그아웃할까요',
        confirmLabel: '로그아웃',
        child: Text(
          '기록은 이 기기에 그대로 남습니다. 다시 로그인하면 서랍이 그대로 열립니다.',
          style: AppText.ui(size: 13, height: 1.6, color: AppColors.inkSoft),
        ),
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (go == true) await AuthService.instance.signOut();
  }
}

// ── 조각들 ────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(label,
              style: AppText.eyebrow(color: AppColors.foil, size: 9)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.stock,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  const Divider(height: 1, thickness: 1, color: AppColors.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    this.value,
    this.note,
    this.onTap,
    this.danger = false,
    this.chevron = false,
  });

  final String title;
  final String? value;
  final String? note;
  final VoidCallback? onTap;
  final bool danger;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final ink = danger ? AppColors.oxblood : AppColors.ink;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: AppText.ui(
                          size: 14,
                          weight: danger ? FontWeight.w700 : FontWeight.w500,
                          color: ink)),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(note!,
                        style:
                        AppText.ui(size: 11.5, color: AppColors.inkSoft)),
                  ],
                ],
              ),
            ),
            if (value != null)
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppText.ui(size: 13, color: AppColors.inkSoft),
                ),
              ),
            if (chevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right,
                  size: 18, color: danger ? AppColors.oxblood : AppColors.pulp),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.ui(size: 11.5, color: AppColors.inkSoft)),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        obscureText: true,
        cursorColor: AppColors.oxblood,
        style: AppText.ui(size: 15, color: AppColors.ink),
        decoration: const InputDecoration(
          isDense: true,
          enabledBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
          focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.oxblood)),
        ),
      ),
    ],
  );
}

/// 종이 위에 얹힌 다이얼로그. 둥근 모서리와 그림자를 걷어냈습니다.
class _PaperDialog extends StatelessWidget {
  const _PaperDialog({
    required this.title,
    required this.child,
    required this.onConfirm,
    this.confirmLabel = '저장',
  });

  final String title;
  final Widget child;
  final VoidCallback onConfirm;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.stock,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.display(size: 19, color: AppColors.ink)),
            const SizedBox(height: 18),
            child,
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('그만두기',
                      style: AppText.ui(size: 13, color: AppColors.inkSoft)),
                ),
                TextButton(
                  onPressed: onConfirm,
                  child: Text(confirmLabel,
                      style: AppText.ui(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.oxblood)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}