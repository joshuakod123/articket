import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/folder_open_route.dart';
import '../widgets/index_tab.dart';
import '../widgets/nav_icons.dart';
import '../widgets/paper.dart';
import 'folder_screen.dart';
import 'market_screen.dart';

/// 앱의 첫 화면. 가로 서류철이 겹쳐 쌓인 파일 드로어.
///
/// 탭하면 표지가 젖혀 열리며 스크랩북으로 들어가고,
/// 길게 누르면 이름을 고치거나 서류철째 버릴 수 있습니다.
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final store = TicketStore.instance;
  int? _lifted;

  /// 열림 전환에서 서류철의 화면 좌표를 읽기 위한 키.
  final _cardKeys = <String, GlobalKey>{};

  static const _folderHeight = FolderMetrics.cardHeight;

  /// 다음 서류철이 이만큼 아래에서 시작해 앞 서류철 몸통을 덮습니다.
  static const _step = FolderMetrics.step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final folders = store.folders;
                final stackHeight =
                    (folders.length - 1).clamp(0, 999) * _step + _folderHeight;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _Header(
                        total: store.tickets.length,
                        onAdd: () => _editFolder(null),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                        child: SizedBox(
                          height: stackHeight,
                          child: Stack(
                            children: [
                              // 겹친 경계마다 [접촉 그림자 → 서류철] 순서로 쌓습니다.
                              for (var i = 0; i < folders.length; i++) ...[
                                if (i > 0)
                                  Positioned(
                                    top: i * _step +
                                        FolderMetrics.tabHeight -
                                        22,
                                    left: 0,
                                    right: 0,
                                    height: 22,
                                    child: const LayerShadow(),
                                  ),
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 240),
                                  curve: Curves.easeOutCubic,
                                  top: i * _step,
                                  left: 0,
                                  right: 0,
                                  height: _folderHeight,
                                  child: KeyedSubtree(
                                    key: _keyOf(folders[i].id),
                                    child: FolderCard(
                                      folder: folders[i],
                                      count: store.countIn(folders[i].id),
                                      tabSlot: i % 3,
                                      totalSlots: 3,
                                      fileNo: i + 1,
                                      lifted: _lifted == i,
                                      preview: store.ticketsIn(folders[i].id),
                                      onTap: () => _open(folders[i], i),
                                      onLongPress: () =>
                                          _folderMenu(folders[i]),
                                    ),
                                  ),
                                ),
                              ],
                              if (folders.isEmpty)
                                Center(
                                  child: Text('서류철이 없습니다. 오른쪽 위 +로 만드세요',
                                      style: AppText.ui(
                                          size: 13,
                                          color: AppColors.inkSoft)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // 플라스터 벽 질감.
          const WallGrain(opacity: 0.04),
        ],
      ),
      bottomNavigationBar: const _BottomBar(),
    );
  }

  GlobalKey _keyOf(String id) => _cardKeys.putIfAbsent(id, GlobalKey.new);

  // ── 열기 (표지가 젖혀지는 전환) ─────────────────────

  Future<void> _open(ArchiveFolder folder, int index) async {
    setState(() => _lifted = index);
    await Future<void>.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;

    // 누른 서류철의 화면 좌표를 읽습니다. 못 읽으면 기본 전환으로 갑니다.
    final box = _cardKeys[folder.id]?.currentContext?.findRenderObject()
    as RenderBox?;

    if (box == null || !box.hasSize) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FolderScreen(folder: folder)),
      );
    } else {
      final rect = box.localToGlobal(Offset.zero) & box.size;
      await Navigator.of(context).push(
        FolderOpenRoute<void>(
          originRect: rect,
          cover: FolderCover(
            folder: folder,
            tabSlot: store.folders.indexOf(folder) % 3,
            totalSlots: 3,
          ),
          builder: (_) => FolderScreen(folder: folder),
        ),
      );
    }
    if (mounted) setState(() => _lifted = null);
  }

  // ── 서류철 관리 ─────────────────────────────────

  /// 길게 눌렀을 때: 고치기 / 버리기.
  Future<void> _folderMenu(ArchiveFolder folder) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.stockLight,
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Text(folder.subtitle,
                  style: AppText.display(size: 20, color: AppColors.ink)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  size: 20, color: AppColors.ink),
              title: Text('이름·색 고치기',
                  style: AppText.ui(size: 14, color: AppColors.ink)),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.oxblood),
              title: Text('서류철 버리기',
                  style: AppText.ui(size: 14, color: AppColors.oxblood)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'edit') await _editFolder(folder);
    if (action == 'delete') await _deleteFolder(folder);
  }

  Future<void> _deleteFolder(ArchiveFolder folder) async {
    final n = store.countIn(folder.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.stockLight,
        shape: const RoundedRectangleBorder(),
        title: Text('서류철을 버릴까요?',
            style: AppText.ui(size: 16, color: AppColors.ink)),
        content: Text(
            n == 0
                ? '「${folder.subtitle}」 서류철을 버립니다.'
                : '「${folder.subtitle}」 안의 티켓 $n장도 함께 버려집니다.\n복구할 수 없습니다.',
            style: AppText.ui(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('그대로 두기',
                style: AppText.ui(size: 13, color: AppColors.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('버리기',
                style: AppText.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.oxblood)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _cardKeys.remove(folder.id);
      store.removeFolder(folder.id);
    }
  }

  /// [folder]가 null이면 새로 만들고, 아니면 그 서류철을 고칩니다.
  Future<void> _editFolder(ArchiveFolder? folder) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.stockLight,
      shape: const RoundedRectangleBorder(),
      builder: (context) => _FolderForm(folder: folder, store: store),
    );
  }
}

/// 서류철 만들기/고치기 시트. 이름 · 영문 라벨 · 색.
class _FolderForm extends StatefulWidget {
  const _FolderForm({required this.folder, required this.store});

  final ArchiveFolder? folder;
  final TicketStore store;

  @override
  State<_FolderForm> createState() => _FolderFormState();
}

class _FolderFormState extends State<_FolderForm> {
  late final _name = TextEditingController(text: widget.folder?.subtitle ?? '');
  late final _label = TextEditingController(text: widget.folder?.label ?? '');
  late Color _color = widget.folder?.color ?? AppColors.tabColors.first;

  bool get _isNew => widget.folder == null;

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서류철 이름을 적어주세요')),
      );
      return;
    }

    // 라벨을 비우면 순번으로 자동 생성합니다.
    var label = _label.text.trim().toUpperCase();
    if (label.isEmpty) {
      label = 'FILE ${(widget.store.folders.length + 1).toString().padLeft(2, '0')}';
    }

    if (_isNew) {
      widget.store.addFolder(ArchiveFolder(
        id: const Uuid().v4(),
        label: label,
        subtitle: name,
        color: _color,
      ));
    } else {
      widget.folder!
        ..subtitle = name
        ..label = label
        ..color = _color;
      widget.store.touch();
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isNew ? 'NEW FOLDER' : 'EDIT FOLDER',
              style: AppText.eyebrow(color: AppColors.foil)),
          const SizedBox(height: 16),
          _field('이름', _name, hint: '예: 올해 다녀온 전시'),
          _field('탭 라벨 (짧은 영문, 비우면 자동)', _label, hint: '2026 ARCHIVE'),
          const SizedBox(height: 8),
          Text('색', style: AppText.ui(size: 12, color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final c in AppColors.tabColors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == c
                            ? AppColors.ink
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: _color == c
                        ? const Icon(Icons.check,
                        size: 16, color: AppColors.stockLight)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.oxblood,
                foregroundColor: AppColors.stockLight,
                shape: const RoundedRectangleBorder(),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(_isNew ? '서류철 만들기' : '저장',
                  style: AppText.ui(size: 14, weight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          style: AppText.ui(size: 14, color: AppColors.ink),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            hintStyle: AppText.ui(size: 13, color: AppColors.pulp),
            labelStyle: AppText.ui(size: 12, color: AppColors.inkSoft),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.line),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.foil),
            ),
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.total, required this.onAdd});

  final int total;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ARTICKET',
                    style: AppText.eyebrow(color: AppColors.oxblood)),
                Text('$total FILED',
                    style: AppText.data(size: 10, color: AppColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text('나의 티켓북',
                    style: AppText.display(size: 36, color: AppColors.ink)),
              ),
              IconButton(
                tooltip: '서류철 만들기',
                onPressed: onAdd,
                icon: const Icon(Icons.create_new_folder_outlined,
                    size: 24, color: AppColors.ink),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 1, color: AppColors.line),
                const SizedBox(height: 8),
                Text('탭하면 열리고, 길게 누르면 고치거나 버립니다',
                    style: AppText.ui(size: 12, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Stack(
        children: [
          // 탭바도 종이 위입니다.
          const WallGrain(opacity: 0.05, seed: 12),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _item(context, NavSymbol.stamp, '아카이브', true, null),
                  _item(context, NavSymbol.tag, '마켓', false, () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MarketScreen()),
                    );
                  }),
                  _item(context, NavSymbol.dateStamp, '캘린더', false, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('문화 캘린더는 Phase 2에서 붙습니다')),
                    );
                  }),
                  _item(context, NavSymbol.pin, '내 정보', false, null),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, NavSymbol symbol, String label,
      bool active, VoidCallback? onTap) {
    final color = active ? AppColors.oxblood : AppColors.inkSoft;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NavIcon(symbol: symbol, color: color, size: 21, filled: active),
            const SizedBox(height: 5),
            Text(label,
                style: AppText.ui(
                    size: 10,
                    weight: active ? FontWeight.w600 : FontWeight.w400,
                    color: color)),
          ],
        ),
      ),
    );
  }
}