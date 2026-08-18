import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/layer.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import '../widgets/scrap_layers.dart';
import '../widgets/scrapbook.dart';
import 'scrap_sheets.dart';

/// 스크랩북 **페이지 자체**를 꾸미는 화면.
///
/// 지금까지 꾸미기는 티켓 한 장 위에서만 가능했습니다. 그런데 실제 스크랩북에서
/// 재미있는 건 티켓 사이의 여백입니다 — 표를 붙이고 남은 자리에 스티커를 붙이고,
/// 옆에 뭔가 적고, 사진을 끼우는 그 여백이요.
///
/// 여기서 붙인 것은 `ArchiveFolder.pageLayers`에 서류철 단위로 저장되어,
/// 폴더를 열 때마다 티켓 **뒤에 깔린 배경**으로 함께 펼쳐집니다.
class PageDecorScreen extends StatefulWidget {
  const PageDecorScreen({super.key, required this.folderId});

  final String folderId;

  @override
  State<PageDecorScreen> createState() => _PageDecorScreenState();
}

class _PageDecorScreenState extends State<PageDecorScreen> {
  final store = TicketStore.instance;
  final _uuid = const Uuid();
  final _picker = ImagePicker();

  String? _selectedId;
  double _startScale = 1;
  double _startRotation = 0;

  final List<String> _undo = [];
  final List<String> _redo = [];

  ArchiveFolder? get _folder => store.folderById(widget.folderId);

  List<ScrapLayer> get _layers => _folder?.pageLayers ?? [];

  // ── 되돌리기 ─────────────────────────────────────

  void _snapshot() {
    _undo.add(ScrapLayer.encodeList(_layers));
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void _restore(String raw) {
    _layers
      ..clear()
      ..addAll(ScrapLayer.decodeList(raw));
    if (!_layers.any((l) => l.id == _selectedId)) _selectedId = null;
    store.touch();
  }

  void _undoOnce() {
    if (_undo.isEmpty) return;
    HapticFeedback.selectionClick();
    _redo.add(ScrapLayer.encodeList(_layers));
    _restore(_undo.removeLast());
    setState(() {});
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    HapticFeedback.selectionClick();
    _undo.add(ScrapLayer.encodeList(_layers));
    _restore(_redo.removeLast());
    setState(() {});
  }

  /// 아무것도 안 바뀐 제스처는 히스토리에서 도로 뺍니다.
  void _endGesture() {
    if (_undo.isNotEmpty && _undo.last == ScrapLayer.encodeList(_layers)) {
      _undo.removeLast();
    }
    store.touch();
    setState(() {});
  }

  // ── 붙이기 ──────────────────────────────────────

  void _place(ScrapLayer layer) {
    _snapshot();
    _layers.add(layer);
    store.touch();
    HapticFeedback.lightImpact();
    setState(() => _selectedId = layer.id);
  }

  Future<void> _addSticker() async {
    final picked = await pickSticker(context);
    if (picked == null) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.sticker,
      content: picked.content,
      dx: 0.5,
      dy: 0.45,
      color: picked.color.toARGB32(),
      fontSize: 22,
    ));
  }

  Future<void> _addText() async {
    final picked = await editScrapText(context);
    if (picked == null) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.text,
      content: picked.text,
      dx: 0.5,
      dy: 0.3,
      color: picked.color.toARGB32(),
      fontSize: picked.size,
      font: picked.font.name,
    ));
  }

  Future<void> _addTape() async {
    final picked = await pickTape(context);
    if (picked == null) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.tape,
      content: picked.pattern.name,
      dx: 0.32,
      dy: 0.2,
      rotation: -0.3,
      color: picked.color.toARGB32(),
    ));
  }

  Future<void> _addPhoto() async {
    var path = '';
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        imageQuality: 88,
      );
      path = shot?.path ?? '';
    } catch (e) {
      if (mounted) PaperToast.warn(context, '사진을 불러오지 못했습니다', detail: '$e');
    }
    if (!mounted) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.photo,
      content: path,
      dx: 0.68,
      dy: 0.62,
      rotation: 0.1,
      color: AppColors.oxbloodDim.toARGB32(),
    ));
  }

  void _remove(ScrapLayer layer) {
    _snapshot();
    _layers.removeWhere((l) => l.id == layer.id);
    store.touch();
    HapticFeedback.mediumImpact();
    setState(() => _selectedId = null);
    PaperToast.show(context, '한 겹 떼어냈습니다', detail: '↩︎ 로 되돌릴 수 있습니다');
  }

  Future<void> _edit(ScrapLayer layer) async {
    switch (layer.kind) {
      case LayerKind.text:
        final picked = await editScrapText(
          context,
          initial: layer.content,
          font: FolderFont.parse(layer.font),
          color: Color(layer.color),
          size: layer.fontSize,
        );
        if (picked == null) return;
        _snapshot();
        layer
          ..content = picked.text
          ..color = picked.color.toARGB32()
          ..fontSize = picked.size
          ..font = picked.font.name;

      case LayerKind.sticker:
        final picked = await pickSticker(context, initial: Color(layer.color));
        if (picked == null) return;
        _snapshot();
        layer
          ..content = picked.content
          ..color = picked.color.toARGB32();

      case LayerKind.tape:
        final picked = await pickTape(
          context,
          pattern: TapePattern.parse(layer.content),
          color: Color(layer.color),
        );
        if (picked == null) return;
        _snapshot();
        layer
          ..content = picked.pattern.name
          ..color = picked.color.toARGB32();

      case LayerKind.photo:
        try {
          final shot = await _picker.pickImage(
            source: ImageSource.gallery,
            maxWidth: 1400,
            imageQuality: 88,
          );
          if (shot == null) return;
          _snapshot();
          layer.content = shot.path;
        } catch (_) {
          if (mounted) PaperToast.warn(context, '사진을 불러오지 못했습니다');
          return;
        }
    }
    store.touch();
    if (mounted) setState(() {});
  }

  // ── 화면 ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final folder = _folder;
        if (folder == null) {
          return const Scaffold(body: Center(child: Text('삭제된 서류철입니다')));
        }

        ScrapLayer? found;
        for (final l in folder.pageLayers) {
          if (l.id == _selectedId) found = l;
        }
        final selected = found;

        return Scaffold(
          appBar: AppBar(
            title: Text('PAGE',
                style: AppText.eyebrow(size: 12, color: AppColors.ink)),
            actions: [
              IconButton(
                tooltip: '되돌리기',
                onPressed: _undo.isEmpty ? null : _undoOnce,
                icon: Icon(Icons.undo,
                    size: 20,
                    color:
                    _undo.isEmpty ? AppColors.pulp : AppColors.ink),
              ),
              IconButton(
                tooltip: '다시 하기',
                onPressed: _redo.isEmpty ? null : _redoOnce,
                icon: Icon(Icons.redo,
                    size: 20,
                    color:
                    _redo.isEmpty ? AppColors.pulp : AppColors.ink),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('완료',
                    style: AppText.ui(
                        size: 14,
                        weight: FontWeight.w600,
                        color: AppColors.oxblood)),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedId = null),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: DecoratedBox(
                      decoration:
                      BoxDecoration(boxShadow: paperShadow(depth: 0.9)),
                      // 좌표 기준은 **페이지 한 장**입니다.
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final canvas = Size(c.maxWidth, c.maxHeight);
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: NotebookPage(
                                  eyebrow: folder.subtitle,
                                  title: folder.label,
                                  footer: 'DECORATE',
                                  seed: folder.id.hashCode,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                              for (final layer in folder.pageLayers)
                                _Editable(
                                  key: ValueKey(layer.id),
                                  layer: layer,
                                  canvas: canvas,
                                  selected: _selectedId == layer.id,
                                  onSelect: () {
                                    setState(() => _selectedId = layer.id);
                                    // 마지막에 그려지도록 맨 뒤로 옮깁니다.
                                    folder.pageLayers
                                      ..removeWhere((l) => l.id == layer.id)
                                      ..add(layer);
                                    store.touch();
                                  },
                                  onScaleStart: () {
                                    _snapshot();
                                    _startScale = layer.scale;
                                    _startRotation = layer.rotation;
                                  },
                                  onScaleUpdate: (d) {
                                    setState(() {
                                      layer.dx += d.focalPointDelta.dx /
                                          canvas.width;
                                      layer.dy += d.focalPointDelta.dy /
                                          canvas.height;
                                      layer.dx = layer.dx.clamp(0.0, 1.0);
                                      layer.dy = layer.dy.clamp(0.0, 1.0);
                                      if (d.pointerCount > 1) {
                                        layer.scale =
                                            (_startScale * d.scale)
                                                .clamp(0.3, 4.0);
                                        layer.rotation =
                                            _startRotation + d.rotation;
                                      }
                                    });
                                  },
                                  onScaleEnd: _endGesture,
                                  onDelete: () => _remove(layer),
                                  onEdit: () => _edit(layer),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              if (selected != null)
                _SelectedBar(
                  onEdit: () => _edit(selected),
                  onDelete: () => _remove(selected),
                  onDone: () => setState(() => _selectedId = null),
                ),

              _Toolbar(
                onSticker: _addSticker,
                onText: _addText,
                onTape: _addTape,
                onPhoto: _addPhoto,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 페이지 위에서 옮기고 돌리고 키우는 레이어.
class _Editable extends StatelessWidget {
  const _Editable({
    super.key,
    required this.layer,
    required this.canvas,
    required this.selected,
    required this.onSelect,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onScaleEnd,
    required this.onDelete,
    required this.onEdit,
  });

  final ScrapLayer layer;
  final Size canvas;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onScaleStart;
  final ValueChanged<ScaleUpdateDetails> onScaleUpdate;
  final VoidCallback onScaleEnd;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

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
          onDoubleTap: onEdit,
          onLongPress: onDelete,
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
                        color: selected
                            ? AppColors.foil.withValues(alpha: 0.9)
                            : Colors.transparent,
                      ),
                    ),
                    child: buildLayerContent(layer),
                  ),
                  if (selected) ...[
                    Positioned(
                      right: -13,
                      top: -13,
                      child: _Handle(
                          icon: Icons.close,
                          color: AppColors.oxblood,
                          onTap: onDelete),
                    ),
                    Positioned(
                      left: -13,
                      top: -13,
                      child: _Handle(
                          icon: Icons.tune,
                          color: AppColors.ink,
                          onTap: onEdit),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.stockLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 14, color: AppColors.stockLight),
      ),
    );
  }
}

class _SelectedBar extends StatelessWidget {
  const _SelectedBar({
    required this.onEdit,
    required this.onDelete,
    required this.onDone,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(
          top: BorderSide(color: AppColors.line),
          bottom: BorderSide(color: AppColors.line),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: [
            Text('고른 조각',
                style: AppText.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: AppColors.ink)),
            const Spacer(),
            IconButton(
              tooltip: '고치기',
              onPressed: onEdit,
              icon: const Icon(Icons.tune, size: 19, color: AppColors.ink),
            ),
            IconButton(
              tooltip: '떼어내기',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  size: 19, color: AppColors.oxblood),
            ),
            IconButton(
              tooltip: '완료',
              onPressed: onDone,
              icon: const Icon(Icons.check, size: 19, color: AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onSticker,
    required this.onText,
    required this.onTape,
    required this.onPhoto,
  });

  final VoidCallback onSticker;
  final VoidCallback onText;
  final VoidCallback onTape;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Stack(
        children: [
          const WallGrain(opacity: 0.05, seed: 51),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _tool(Icons.auto_awesome_outlined, '스티커', onSticker),
                  _tool(Icons.text_fields, '글자', onText),
                  _tool(Icons.horizontal_rule, '테이프', onTape),
                  _tool(Icons.photo_outlined, '폴라로이드', onPhoto),
                ],
              ),
            ),
          ),
        ],
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
          Icon(icon, size: 21, color: AppColors.ink),
          const SizedBox(height: 5),
          Text(label,
              style: AppText.ui(size: 10, color: AppColors.inkSoft)),
        ],
      ),
    ),
  );
}