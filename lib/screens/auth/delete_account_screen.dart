import 'package:material_ui/material_ui.dart';
import '../../data/ticket_store.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final password = TextEditingController();
  bool confirmed = false, busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> remove() async {
    if (!confirmed || password.text.isEmpty || busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('정말 삭제할까요?'),
        content: const Text('계정과 관람 기록, 사진이 영구 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('돌아가기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    final r = await AuthService.instance.deleteAccount(password: password.text);
    if (mounted) {
      setState(() {
        busy = false;
        error = r.isOk ? null : r.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('계정 삭제')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.lavender,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '저장한 기록과 사진이\n모두 삭제돼요.',
            textAlign: TextAlign.center,
            style: AppText.display(size: 21),
          ),
        ),
        const SizedBox(height: 24),
        Text('삭제되는 내용', style: AppText.ui(weight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Card(
                color: AppColors.butter,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('티켓 ${TicketStore.instance.tickets.length}장'),
                ),
              ),
            ),
            Expanded(
              child: Card(
                color: AppColors.lavender,
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('서류철 ${TicketStore.instance.folders.length}개'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(
          controller: password,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: '현재 비밀번호'),
        ),
        const SizedBox(height: 20),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: confirmed,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: busy
              ? null
              : (v) => setState(() => confirmed = v ?? false),
          title: Text('삭제한 기록은 복구할 수 없음을 확인했어요', style: AppText.ui(size: 12)),
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: confirmed && password.text.isNotEmpty && !busy
              ? remove
              : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          child: Text(busy ? '삭제하는 중…' : '계정 삭제'),
        ),
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('돌아가기'),
        ),
      ],
    ),
  );
}
