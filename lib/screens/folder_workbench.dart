import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';
import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/folder_style.dart';
import '../widgets/home/folder_preview_card.dart';
import '../widgets/paper_toast.dart';

Future<bool?> openFolderWorkbench(
  BuildContext context, {
  required TicketStore store,
  ArchiveFolder? folder,
  int fileNo = 1,
  List<Ticket> preview = const [],
}) => Navigator.push<bool>(
  context,
  MaterialPageRoute(
    builder: (_) => FolderWorkbench(
      store: store,
      folder: folder,
      fileNo: fileNo,
      preview: preview,
    ),
  ),
);

class FolderWorkbench extends StatefulWidget {
  const FolderWorkbench({
    super.key,
    required this.store,
    this.folder,
    this.fileNo = 1,
    this.preview = const [],
  });
  final TicketStore store;
  final ArchiveFolder? folder;
  final int fileNo;
  final List<Ticket> preview;
  @override
  State<FolderWorkbench> createState() => _FolderWorkbenchState();
}

class _FolderWorkbenchState extends State<FolderWorkbench> {
  late final name = TextEditingController(text: widget.folder?.subtitle ?? '');
  late final label = TextEditingController(text: widget.folder?.label ?? '');
  late Color color = widget.folder?.color ?? AppColors.lavender;
  late FolderFont font = widget.folder?.font ?? FolderFont.serif;
  late FolderTexture texture = widget.folder?.texture ?? FolderTexture.plain;
  @override
  void dispose() {
    name.dispose();
    label.dispose();
    super.dispose();
  }

  void save() {
    if (name.text.trim().isEmpty) {
      PaperToast.warn(context, '서류철 이름을 적어주세요');
      return;
    }
    final f = widget.folder;
    if (f == null) {
      widget.store.addFolder(
        ArchiveFolder(
          id: const Uuid().v4(),
          label: label.text.trim().isEmpty
              ? 'FILE ${widget.fileNo.toString().padLeft(2, '0')}'
              : label.text.trim(),
          subtitle: name.text.trim(),
          color: color,
          font: font,
          texture: texture,
        ),
      );
    } else {
      f.subtitle = name.text.trim();
      f.label = label.text.trim();
      f.color = color;
      f.font = font;
      f.texture = texture;
      widget.store.touch();
    }
    Navigator.pop(context, true);
  }

  Future<void> remove() async {
    final f = widget.folder;
    if (f == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('서류철을 삭제할까요?'),
        content: Text('안에 있는 티켓 ${widget.store.countIn(f.id)}장도 삭제돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('돌아가기'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.store.removeFolder(f.id);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.folder == null ? '서류철 만들기' : '서류철 수정'),
      actions: [
        if (widget.folder != null)
          IconButton(
            tooltip: '서류철 삭제',
            onPressed: remove,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FilledButton(
          onPressed: save,
          child: Text(widget.folder == null ? '서류철 만들기' : '변경 저장'),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: SizedBox(
            width: 230,
            child: FolderPreviewCard(
              folder: ArchiveFolder(
                id: 'preview',
                label: label.text,
                subtitle: name.text.isEmpty ? '나의 서류철' : name.text,
                color: color,
                font: font,
                texture: texture,
              ),
              tickets: widget.preview,
            ),
          ),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: name,
          onChanged: (_) => setState(() {}),
          maxLength: 50,
          decoration: const InputDecoration(
            labelText: '서류철 이름',
            counterText: '',
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: label,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: '라벨 (선택)',
            hintText: '예: FILE 01',
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),
        const Text('색상'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: AppColors.tabColors
              .map(
                (c) => Semantics(
                  label: '서류철 색상',
                  selected: color == c,
                  button: true,
                  child: IconButton(
                    onPressed: () => setState(() => color = c),
                    style: IconButton.styleFrom(backgroundColor: c),
                    icon: Icon(
                      color == c ? Icons.check : Icons.circle,
                      color: color == c ? AppColors.ink : c,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text('글꼴'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: FolderFont.values
              .map(
                (v) => ChoiceChip(
                  label: Text(v.label),
                  selected: font == v,
                  onSelected: (_) => setState(() => font = v),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text('질감'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: FolderTexture.values
              .map(
                (v) => ChoiceChip(
                  label: Text(v.label),
                  selected: texture == v,
                  onSelected: (_) => setState(() => texture = v),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
      ],
    ),
  );
}
