import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/guide_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/brand_logo.dart';
import '../widgets/loading.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import 'auth/delete_account_screen.dart';
import 'onboarding/ticket_guide.dart';

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
          const WallGrain(opacity: 0.05, seed: 29),
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
                      // 티켓 만드는 법은 앱을 쓰는 내내 다시 보고 싶어지는
                      // 안내입니다. 첫 발권 때 한 번 보여주고 마는 대신
                      // 여기 상시로 걸어둡니다.
                      _Row(
                        title: '티켓 만드는 법',
                        note: '세 단계로 짧게',
                        chevron: true,
                        onTap: () => showTicketWorkshopGuide(context),
                      ),
                      _Row(
                        title: '처음 안내 다시 보기',
                        note: '서랍 탭으로 가면 처음부터 다시 떠요',
                        chevron: true,
                        onTap: () => _replayGuide(context),
                      ),
                      const _Row(title: '버전', value: '0.1.0'),
                      _Row(
                        title: '이용약관',
                        chevron: true,
                        onTap: () => PaperToast.show(context, '아직 준비 중이에요'),
                      ),
                      _Row(
                        title: '개인정보 처리방침',
                        chevron: true,
                        onTap: () => PaperToast.show(context, '아직 준비 중이에요'),
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
                        note: '기록은 기기에 남아요',
                        onTap: () => _signOut(context),
                      ),
                      _Row(
                        title: '계정 삭제',
                        note: '되돌릴 수 없어요',
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

  /// 안내를 처음 상태로 되돌립니다.
  ///
  /// 여기서 바로 투어를 띄우지 않는 이유: 코치 마크는 **서랍 화면의 버튼
  /// 좌표**를 읽어 도려냅니다. 설정 화면 위에서 띄우면 그 버튼들이 화면에
  /// 없어 구멍이 엉뚱한 데 뚫립니다. 표시만 지우고, 서랍으로 돌아갔을 때
  /// `ArchiveScreen`이 평소처럼 안내를 시작하게 둡니다.
  ///
  /// ⚠ [ArchiveScreen]은 `IndexedStack` 안에 살아 있어서 다시 `initState`가
  /// 돌지 않습니다. 그래서 [GuideService]를 듣고 있다가 표시가 지워지면
  /// 스스로 다시 시작합니다.
  Future<void> _replayGuide(BuildContext context) async {
    await GuideService.instance.reset();
    if (!context.mounted) return;
    PaperToast.done(context, '처음으로 되돌렸어요',
        detail: '서랍 탭으로 가시면 다시 떠요');
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
    if (context.mounted) PaperToast.done(context, '이름 바꿨어요');
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
        ? PaperToast.done(context, '비밀번호 바꿨어요')
        : PaperToast.warn(context, result.message);
  }

  Future<void> _signOut(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => _PaperDialog(
        title: '로그아웃할까요',
        confirmLabel: '로그아웃',
        child: Text(
          '기록은 이 기기에 남아 있어요. 다시 들어오면 서랍도 그대로예요.',
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