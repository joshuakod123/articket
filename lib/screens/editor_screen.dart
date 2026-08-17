import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/layer.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/ticket_card.dart';
import 'ticket_detail_screen.dart' show buildLayerContent;
import 'ticket_style_sheet.dart';

/// 스크랩북 에디터.
///
/// 캔버스 위 레이어를 한 손가락으로 옮기고, 두 손가락으로 돌리고 키웁니다.
/// 좌표는 캔버스 비율로 저장되어 기기 크기가 달라도 배치가 유지됩니다.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final store = TicketStore.instance;
  final _uuid = const Uuid();

  String? _selectedId;

  // 제스처 시작 시점의 값을 붙잡아 둡니다.
  double _startScale = 1;
  double _startRotation = 0;

  Ticket get _ticket => store.byId(widget.ticketId)!;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ticket = store.byId(widget.ticketId);
        if (ticket == null) {
          return const Scaffold(body: Center(child: Text('삭제된 티켓입니다')));
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('EDITOR'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('완료',
                    style: AppText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.foil)),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final canvas = Size(c.maxWidth, c.maxHeight);
                    return GestureDetector(
                      // 빈 곳을 누르면 선택 해제.
                      onTap: () => setState(() => _selectedId = null),
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        children: [
                          // 티켓 본체 (배경, 편집 대상 아님)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 44, vertical: 24),
                              child: AspectRatio(
                                aspectRatio: ticket.frame.aspect,
                                child: Opacity(
                                  opacity: 0.92,
                                  child: TicketFront(ticket: ticket),
                                ),
                              ),
                            ),
                          ),

                          // 편집 가능한 레이어들
                          for (final layer in ticket.layers)
                            _EditableLayer(
                              key: ValueKey(layer.id),
                              layer: layer,
                              canvas: canvas,
                              selected: _selectedId == layer.id,
                              onSelect: () {
                                setState(() => _selectedId = layer.id);
                                store.bringToFront(ticket.id, layer.id);
                              },
                              onScaleStart: () {
                                _startScale = layer.scale;
                                _startRotation = layer.rotation;
                              },
                              onScaleUpdate: (details) {
                                setState(() {
                                  layer.dx +=
                                      details.focalPointDelta.dx / canvas.width;
                                  layer.dy += details.focalPointDelta.dy /
                                      canvas.height;
                                  layer.dx = layer.dx.clamp(0.0, 1.0);
                                  layer.dy = layer.dy.clamp(0.0, 1.0);

                                  if (details.pointerCount > 1) {
                                    layer.scale = (_startScale * details.scale)
                                        .clamp(0.3, 4.0);
                                    layer.rotation =
                                        _startRotation + details.rotation;
                                  }
                                });
                              },
                              onScaleEnd: store.touch,
                              onDelete: () {
                                store.removeLayer(ticket.id, layer.id);
                                setState(() => _selectedId = null);
                              },
                              onEditText: layer.kind == LayerKind.text
                                  ? () => _editText(layer)
                                  : null,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              _Toolbar(
                onFrame: () => _openStyle(0),
                onPoster: () => _openStyle(1),
                onSticker: _addSticker,
                onText: _addText,
                onTape: _addTape,
                onPhoto: _addPhoto,
                onInfo: _editInfo,
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 레이어 추가 ───────────────────────────────────

  void _place(ScrapLayer layer) {
    store.addLayer(widget.ticketId, layer);
    setState(() => _selectedId = layer.id);
  }

  Future<void> _addSticker() async {
    const glyphs = [
      '🎟️', '🖼️', '✂️', '📎', '📌', '🕯️', '🗝️', '🎨',
      '☕', '🌙', '⭐', '🧾', '📷', '🪞', '🍃', '✦',
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.ink,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('STICKER', style: AppText.eyebrow(color: AppColors.foil)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final g in glyphs)
                    InkWell(
                      onTap: () => Navigator.pop(context, g),
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.inkSoft),
                        ),
                        child: Text(g, style: const TextStyle(fontSize: 24)),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.sticker,
      content: picked,
      dx: 0.5,
      dy: 0.4,
    ));
  }

  Future<void> _addText() async {
    final text = await _promptText('');
    if (text == null || text.isEmpty) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.text,
      content: text,
      dx: 0.5,
      dy: 0.35,
      color: AppColors.oxblood.toARGB32(),
      fontSize: 20,
    ));
  }

  void _addTape() {
    const colors = [0xCC3F4A3C, 0xCC6E1F1B, 0xCCB08B3E, 0xCC2E3B4E];
    final c = colors[_ticket.layers.length % colors.length];
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.tape,
      content: 'tape',
      dx: 0.3,
      dy: 0.2,
      rotation: -0.3,
      color: c,
    ));
  }

  void _addPhoto() {
    // 실제 구현에서는 image_picker로 갤러리를 엽니다.
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.photo,
      content: '',
      dx: 0.68,
      dy: 0.6,
      rotation: 0.12,
      color: AppColors.oxbloodDim.toARGB32(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('갤러리 연동은 image_picker로 붙입니다')),
    );
  }

  Future<void> _editText(ScrapLayer layer) async {
    final text = await _promptText(layer.content);
    if (text == null) return;
    setState(() => layer.content = text);
    store.touch();
  }

  Future<String?> _promptText(String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.ink,
        title: Text('글자 넣기',
            style: AppText.ui(size: 15, color: AppColors.stock)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: AppText.ui(size: 14, color: AppColors.stock),
          decoration: InputDecoration(
            hintText: '한 줄이든 여러 줄이든',
            hintStyle: AppText.ui(size: 14, color: AppColors.inkSoft),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkSoft),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소',
                style: AppText.ui(size: 13, color: AppColors.inkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('넣기',
                style: AppText.ui(size: 13, color: AppColors.foil)),
          ),
        ],
      ),
    );
  }

  // ── 티켓 정보 편집 ────────────────────────────────

  /// 프레임(0) 또는 포스터(1) 탭으로 스타일 시트를 엽니다.
  void _openStyle(int tab) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink,
      builder: (context) => TicketStyleSheet(
        ticket: _ticket,
        store: store,
        initialTab: tab,
      ),
    );
  }

  void _editInfo() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ink,
      builder: (context) => _InfoSheet(ticket: _ticket, store: store),
    );
  }
}

/// 한 손가락 = 이동, 두 손가락 = 회전 + 확대.
class _EditableLayer extends StatelessWidget {
  const _EditableLayer({
    super.key,
    required this.layer,
    required this.canvas,
    required this.selected,
    required this.onSelect,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onDelete,
    this.onEditText,
  });

  final ScrapLayer layer;
  final Size canvas;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onScaleStart;
  final ValueChanged<ScaleUpdateDetails> onScaleUpdate;
  final VoidCallback onScaleEnd;
  final VoidCallback onDelete;
  final VoidCallback? onEditText;

  @override
  Widget build(BuildContext context) {
    final pos = layer.offsetIn(canvas);

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: onSelect,
          onDoubleTap: onEditText,
          onScaleStart: (_) {
            onSelect();
            onScaleStart();
          },
          onScaleUpdate: onScaleUpdate,
          onScaleEnd: (_) => onScaleEnd(),
          child: Transform.rotate(
            angle: layer.rotation,
            child: Transform.scale(
              scale: layer.scale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected ? AppColors.foil : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: buildLayerContent(layer),
                  ),
                  if (selected)
                    Positioned(
                      right: -10,
                      top: -10,
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.oxblood,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              size: 13, color: AppColors.stockLight),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onFrame,
    required this.onPoster,
    required this.onSticker,
    required this.onText,
    required this.onTape,
    required this.onPhoto,
    required this.onInfo,
  });

  final VoidCallback onFrame;
  final VoidCallback onPoster;
  final VoidCallback onSticker;
  final VoidCallback onText;
  final VoidCallback onTape;
  final VoidCallback onPhoto;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.inkSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          // 항목이 7개라 좁은 화면에서도 넘치지 않도록 가로 스크롤로 둡니다.
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _tool(Icons.crop_free, '프레임', onFrame),
                _tool(Icons.wallpaper_outlined, '포스터', onPoster),
                _tool(Icons.emoji_emotions_outlined, '스티커', onSticker),
                _tool(Icons.text_fields, '글자', onText),
                _tool(Icons.horizontal_rule, '테이프', onTape),
                _tool(Icons.photo_outlined, '폴라로이드', onPhoto),
                _tool(Icons.edit_note, '기록', onInfo),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tool(IconData icon, String label, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: AppColors.stock),
          const SizedBox(height: 5),
          Text(label,
              style: AppText.ui(size: 10, color: AppColors.inkSoft)),
        ],
      ),
    ),
  );
}

/// 전시명 · 장소 · 별점 · 감상문을 고치는 시트.
class _InfoSheet extends StatefulWidget {
  const _InfoSheet({required this.ticket, required this.store});

  final Ticket ticket;
  final TicketStore store;

  @override
  State<_InfoSheet> createState() => _InfoSheetState();
}

class _InfoSheetState extends State<_InfoSheet> {
  late final _title = TextEditingController(text: widget.ticket.title);
  late final _venue = TextEditingController(text: widget.ticket.venue);
  late final _oneLiner = TextEditingController(text: widget.ticket.oneLiner);
  late final _note = TextEditingController(text: widget.ticket.note);
  late final _companion = TextEditingController(text: widget.ticket.companion);
  late int _rating = widget.ticket.rating;

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _oneLiner.dispose();
    _note.dispose();
    _companion.dispose();
    super.dispose();
  }

  void _save() {
    // pop 이후에는 이 위젯의 context가 죽으므로 미리 붙잡아 둡니다.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final t = widget.ticket
      ..title = _title.text.trim()
      ..venue = _venue.text.trim()
      ..oneLiner = _oneLiner.text.trim()
      ..note = _note.text.trim()
      ..companion = _companion.text.trim()
      ..rating = _rating;
    widget.store.touch();

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('${t.serial} 저장했습니다')),
    );
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RECORD', style: AppText.eyebrow(color: AppColors.foil)),
            const SizedBox(height: 18),
            _field('전시명', _title, lines: 2),
            _field('장소', _venue),
            const SizedBox(height: 6),
            Text('별점',
                style: AppText.ui(size: 12, color: AppColors.inkSoft)),
            const SizedBox(height: 6),
            Row(
              children: List.generate(
                5,
                    (i) => IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 38),
                  onPressed: () => setState(() => _rating = i + 1),
                  icon: Icon(
                    i < _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: i < _rating ? AppColors.foil : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
            _field('한 줄 평', _oneLiner),
            _field('감상문', _note, lines: 5),
            _field('함께한 사람', _companion),
            const SizedBox(height: 18),
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
                child: Text('저장',
                    style: AppText.ui(size: 14, weight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          maxLines: lines,
          style: AppText.ui(size: 14, color: AppColors.stock),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: AppText.ui(size: 12, color: AppColors.inkSoft),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.inkSoft),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.foil),
            ),
          ),
        ),
      );
}