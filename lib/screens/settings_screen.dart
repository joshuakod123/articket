import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/sync_service.dart';
import '../data/supabase_env.dart';
import '../services/auth_service.dart';
import '../services/guide_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/brand_logo.dart';
import '../widgets/paper_toast.dart';
import 'auth/delete_account_screen.dart';
import 'onboarding/welcome_tour.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  Future<void> rename(BuildContext context) async {
    final controller = TextEditingController(
      text: AuthService.instance.viewer?.name ?? '',
    );
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          MediaQuery.viewInsetsOf(c).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('이름 바꾸기', style: AppText.display(size: 22)),
            const SizedBox(height: 24),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 30,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    Navigator.pop(c, controller.text.trim());
                  }
                },
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name != null) await AuthService.instance.rename(name);
  }

  Future<void> policy(BuildContext context, bool privacy) async {
    const privacyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
    const termsUrl = String.fromEnvironment('TERMS_URL');
    final uri = Uri.tryParse(privacy ? privacyUrl : termsUrl);
    if (uri == null || uri.scheme != 'https') {
      if (context.mounted) PaperToast.show(context, '정책 문서가 아직 등록되지 않았어요');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      PaperToast.warn(context, '문서를 열지 못했어요');
    }
  }

  Future<void> signOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('아직 백업하지 못한 기록은 이 기기에 보관됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok == true) await AuthService.instance.signOut();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('설정')),
    body: ListenableBuilder(
      listenable: Listenable.merge([
        AuthService.instance,
        SyncService.instance,
      ]),
      builder: (context, _) {
        final v = AuthService.instance.viewer;
        final sync = SyncService.instance;
        final backup = !SupabaseEnv.isConfigured
            ? '백업을 사용할 수 없어요'
            : sync.state == SyncState.syncing
            ? '기록을 백업하고 있어요'
            : sync.state == SyncState.offline
            ? '연결되면 다시 백업해요'
            : sync.state == SyncState.error
            ? '백업을 다시 시도해 주세요'
            : sync.hasPendingChanges
            ? '백업할 기록이 있어요'
            : sync.lastSyncedAt == null
            ? '백업 상태 확인하기'
            : '모든 기록이 저장됐어요';
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lavender,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_outline, color: AppColors.ink),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v?.name ?? '나의 계정',
                          style: AppText.display(size: 20),
                        ),
                        Text(v?.email ?? '', style: AppText.ui(size: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '이름 수정',
                    onPressed: () => rename(context),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('계정 정보'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => rename(context),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('비밀번호 변경'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const ChangePasswordScreen(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: const Text('백업 상태'),
              subtitle: Text(backup),
              trailing: const Icon(Icons.refresh),
              onTap: sync.state == SyncState.syncing
                  ? null
                  : () => sync.syncNow(),
            ),
            const Divider(),
            ListTile(
              title: const Text('이용약관'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => policy(context, false),
            ),
            ListTile(
              title: const Text('개인정보 처리방침'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => policy(context, true),
            ),
            ListTile(
              title: const Text('앱 안내 다시 보기'),
              onTap: () async {
                await GuideService.instance.reset();
                if (context.mounted) await showWelcomeTour(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('로그아웃'),
              onTap: () => signOut(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.danger,
              ),
              title: const Text(
                '계정 삭제',
                style: TextStyle(color: AppColors.danger),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
            ),
            const SizedBox(height: 35),
            const Center(child: ArticketLogo(height: 20)),
            const SizedBox(height: 12),
            Text(
              '0.1.0',
              textAlign: TextAlign.center,
              style: AppText.ui(size: 11, color: AppColors.inkSoft),
            ),
          ],
        );
      },
    ),
  );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final form = GlobalKey<FormState>();
  final current = TextEditingController(),
      next = TextEditingController(),
      confirm = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    current.dispose();
    next.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final r = await AuthService.instance.changePassword(
      current: current.text,
      next: next.text,
    );
    if (!mounted) return;
    if (r.isOk) {
      PaperToast.done(context, '비밀번호를 변경했어요');
      Navigator.pop(context);
    } else {
      setState(() {
        busy = false;
        error = r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('비밀번호 변경')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: current,
                obscureText: true,
                decoration: const InputDecoration(labelText: '현재 비밀번호'),
                validator: (v) =>
                    v == null || v.isEmpty ? '현재 비밀번호를 입력해 주세요' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(labelText: '새 비밀번호'),
                validator: (v) =>
                    v == null || v.length < 8 ? '8자 이상 입력해 주세요' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: '새 비밀번호 확인'),
                validator: (v) => v != next.text ? '비밀번호가 일치하지 않아요' : null,
              ),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: busy ? null : save,
          child: Text(busy ? '변경하는 중…' : '비밀번호 변경'),
        ),
      ],
    ),
  );
}
