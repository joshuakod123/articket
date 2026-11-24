import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../models/ticket_draft.dart';
import '../services/poster_storage.dart';
import '../theme/app_colors.dart';
import '../theme/folder_style.dart';
import '../theme/ticket_design.dart';
import '../widgets/record_form.dart';
import '../widgets/paper_toast.dart';
import 'ticket_detail_screen.dart';

class TicketCreateScreen extends StatefulWidget {
  const TicketCreateScreen({super.key, this.folderId});
  final String? folderId;
  @override
  State<TicketCreateScreen> createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends State<TicketCreateScreen> {
  late final draft = TicketDraft(folderId: widget.folderId);
  final _form = GlobalKey<FormState>();
  final _id = const Uuid().v4();
  bool _saving = false;
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (draft.posterPath != null) {
        draft.posterPath = await PosterStorage.instance.adopt(
          draft.posterPath!,
          _id,
        );
      }
      if (!mounted) return;
      final store = TicketStore.instance;
      var folderId = draft.folderId;
      if (folderId == null || store.folderById(folderId) == null) {
        if (store.folders.isNotEmpty) {
          folderId = store.folders.first.id;
        } else {
          folderId = const Uuid().v4();
          store.addFolder(
            ArchiveFolder(
              id: folderId,
              label: 'FILE 01',
              subtitle: '올해의 전시',
              color: AppColors.lavender,
              font: FolderFont.serif,
              texture: FolderTexture.plain,
            ),
          );
        }
      }
      final ticket = draft.build(id: _id, folderId: folderId);
      store.add(ticket);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        PaperToast.warn(context, '티켓을 저장하지 못했어요. 다시 시도해 주세요');
      }
    }
  }

  Future<void> _photo() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (photo != null && mounted) {
        setState(() => draft.posterPath = photo.path);
      }
    } catch (_) {
      if (mounted) PaperToast.warn(context, '앨범 접근 권한을 확인해 주세요');
    }
  }

  @override
  Widget build(BuildContext context) {
    final folders = TicketStore.instance.folders;
    return Scaffold(
      appBar: AppBar(title: const Text('새 관람 기록')),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '저장하는 중…' : '티켓 만들기'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            onPressed: _saving ? null : _photo,
            icon: Icon(
              draft.posterPath == null
                  ? Icons.add_photo_alternate_outlined
                  : Icons.check_circle_outline,
            ),
            label: Text(
              draft.posterPath == null ? '포스터 사진 추가 (선택)' : '사진 선택됨 · 바꾸기',
            ),
          ),
          if (draft.posterPath != null)
            TextButton(
              onPressed: () => setState(() => draft.posterPath = null),
              child: const Text('사진 빼기'),
            ),
          const SizedBox(height: 20),
          if (folders.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              value: draft.folderId ?? folders.first.id,
              decoration: const InputDecoration(labelText: '보관할 서류철'),
              items: folders
                  .map(
                    (f) => DropdownMenuItem(
                      value: f.id,
                      child: Text(f.subtitle.isEmpty ? f.label : f.subtitle),
                    ),
                  )
                  .toList(),
              onChanged: (v) => draft.folderId = v,
            ),
            const SizedBox(height: 20),
          ],
          RecordForm(draft: draft, formKey: _form),
          const Text('티켓 디자인', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: TicketDesign.selectable
                .map(
                  (v) => ChoiceChip(
                    label: Text(v.label),
                    selected: draft.design == v,
                    onSelected: (_) => setState(() => draft.design = v),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
