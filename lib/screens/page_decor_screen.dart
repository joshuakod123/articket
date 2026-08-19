import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/layer.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/feel.dart';
import '../theme/folder_style.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import '../widgets/scrap_layers.dart';
import '../widgets/scrap_page.dart';
import '../widgets/scrapbook.dart';
import '../widgets/snap.dart';
import '../widgets/spring.dart';
import '../widgets/ticket_canvas.dart';
import 'scrap_sheets.dart';

/// 스크랩북 페이지를 손으로 꾸미는 화면.
///
/// 예전에는 **빈 종이 한 장만** 띄워놓고 스티커를 붙이라고 했습니다.
/// 정작 그 페이지에 이미 붙어 있는 티켓이 어디 있는지 안 보이니,
/// 눈 감고 붙이는 것과 다르지 않았습니다. 이번에 세 가지를 고쳤습니다.
///
/// 1. **티켓이 그대로 보입니다.** 스크랩북과 똑같은 위젯([AutoScrapPage],
///    [TapedTicket])을 써서, 여기서 본 그림이 완성된 페이지와 일치합니다.
/// 2. **티켓 자리를 옮길 수 있습니다.** 티켓을 끌면 자동 배치가 풀리고
///    핀터레스트처럼 자유롭게 앉힐 수 있습니다. 두 손가락으로 돌리고 키웁니다.
/// 3. 종이는 [NotebookPage] 그대로라, 결·얼룩·제본·뜯긴 가장자리가 다 살아 있습니다.
class PageDecorScreen extends StatefulWidget {
  const PageDecorScreen({super.key, required this.folderId});

  final String folderId;

  @override
  State<PageDecorScreen> createState() => _PageDecorScreenState();
}

class _PageDecorScreenState extends State<PageDecorScreen>
    with TickerProviderStateMixin {
  final store = TicketStore.instance;
  final _uuid = const Uuid();
  final _picker = ImagePicker();

  /// 지금 고른 것. 레이어면 layer:<id>, 티켓이면 ticket:<id>.
  String? _selected;

  /// 지금 손에 들려 있는 것. 그림자와 크기가 여기에 반응합니다.
  String? _dragging;

  /// 회전·자리·크기 눈금.
  final _snap = SnapEngine();

  /// 지금 걸려 있는 축. 가이드선용.
  Set<SnapAxis> _guides = const <SnapAxis>{};

  /// 던진 티켓이 속도를 이어받아 멎게 합니다.
  late final SpringSettle _settle = SpringSettle(vsync: this);

  double _startScale = 1;
  double _startRotation = 0;

  final List<String> _undo = [];
  final List<String> _redo = [];

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  ArchiveFolder? get _folder => store.folderById(widget.folderId);

  List<ScrapLayer> get _layers => _folder?.pageLayers ?? [];

  List<Ticket> get _tickets => store.ticketsIn(widget.folderId);

  // ── 되돌리기 ─────────────────────────────────────
  //
  // 레이어뿐 아니라 **티켓 자리**도 함께 되감아야 합니다.
  // 둘을 한 문자열에 담아 한 번에 스냅샷합니다.

  String _stateString() {
    final places = <String, List<double?>>{
      for (final t in _tickets) t.id: [t.px, t.py, t.pscale, t.protation],
    };
    return '${ScrapLayer.encodeList(_layers)}\u0000${jsonEncode(places)}';
  }

  void _snapshot() {
    _undo.add(_stateString());
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void _restore(String raw) {
    final parts = raw.split('\u0000');
    _layers
      ..clear()
      ..addAll(ScrapLayer.decodeList(parts[0]));

    final places = jsonDecode(parts[1]) as Map<String, dynamic>;
    for (final t in _tickets) {
      final v = places[t.id] as List<dynamic>?;
      if (v == null) continue;
      t
        ..px = (v[0] as num?)?.toDouble()
        ..py = (v[1] as num?)?.toDouble()
        ..pscale = (v[2] as num?)?.toDouble() ?? 1.0
        ..protation = (v[3] as num?)?.toDouble() ?? 0.0;
    }
    _selected = null;
    store.touch();
  }

  void _undoOnce() {
    if (_undo.isEmpty) return;
    Feel.pick();
    _redo.add(_stateString());
    _restore(_undo.removeLast());
    setState(() {});
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    Feel.pick();
    _undo.add(_stateString());
    _restore(_redo.removeLast());
    setState(() {});
  }

  /// 아무것도 안 바뀐 제스처는 히스토리에서 도로 뺍니다.
  void _endGesture() {
    if (_undo.isNotEmpty && _undo.last == _stateString()) _undo.removeLast();
    store.touch();
    setState(() {});
  }

  // ── 배치 ────────────────────────────────────────

  /// 자유 배치로 넘어갑니다. 지금 자동 배치로 보이던 자리를 그대로 물려받습니다.
  void _goFree({bool silent = false}) {
    final folder = _folder;
    if (folder == null || folder.freeLayout) return;

    _snapshot();
    final list = _tickets;
    for (var i = 0; i < list.length; i++) {
      final at = defaultTicketPlacement(i);
      list[i]
        ..px ??= at.dx
        ..py ??= at.dy;
    }
    folder.freeLayout = true;
    store.touch();
    setState(() {});

    if (!silent && mounted) {
      PaperToast.show(context, '자유 배치로 바꿨습니다',
          detail: '티켓을 끌어 옮기고, 두 손가락으로 돌리세요');
    }
  }

  void _backToAuto() {
    final folder = _folder;
    if (folder == null) return;
    _snapshot();
    for (final t in _tickets) {
      t
        ..px = null
        ..py = null
        ..pscale = 1.0
        ..protation = 0.0;
    }
    folder.freeLayout = false;
    store.touch();
    setState(() => _selected = null);
    PaperToast.show(context, '자동 배치로 되돌렸습니다');
  }

  // ── 붙이기 ──────────────────────────────────────

  void _place(ScrapLayer layer) {
    _snapshot();
    _layers.add(layer);
    store.touch();
    Feel.place();
    setState(() => _selected = 'layer:${layer.id}');
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
    Feel.tear();
    setState(() => _selected = null);
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

        final tickets = _tickets;

        ScrapLayer? pickedLayer;
        for (final l in folder.pageLayers) {
          if (_selected == 'layer:${l.id}') pickedLayer = l;
        }
        Ticket? pickedTicket;
        for (final t in tickets) {
          if (_selected == 'ticket:${t.id}') pickedTicket = t;
        }

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
                    color: _undo.isEmpty ? AppColors.pulp : AppColors.ink),
              ),
              IconButton(
                tooltip: '다시 하기',
                onPressed: _redo.isEmpty ? null : _redoOnce,
                icon: Icon(Icons.redo,
                    size: 20,
                    color: _redo.isEmpty ? AppColors.pulp : AppColors.ink),
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
              _LayoutBanner(
                free: folder.freeLayout,
                hasTickets: tickets.isNotEmpty,
                onFree: _goFree,
                onAuto: _backToAuto,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selected = null),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: DecoratedBox(
                      decoration:
                      BoxDecoration(boxShadow: paperShadow(depth: 0.9)),
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final canvas = Size(c.maxWidth, c.maxHeight);
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // ── 종이 + (자동 배치일 때) 티켓 ────
                              Positioned.fill(
                                child: NotebookPage(
                                  eyebrow: folder.subtitle,
                                  title: folder.label,
                                  footer: folder.freeLayout
                                      ? 'FREE LAYOUT'
                                      : 'PAGE 01',
                                  seed: folder.id.hashCode,
                                  child: folder.freeLayout
                                      ? const SizedBox.expand()
                                      : AutoScrapPage(
                                    tickets: tickets.take(2).toList(),
                                    pageIndex: 0,
                                  ),
                                ),
                              ),

                              // ── 눈금 안내선 ────────────────
                              if (_guides.isNotEmpty)
                                Positioned.fill(
                                  child: SnapGuides(engaged: _guides),
                                ),

                              // ── 자유 배치 티켓 ─────────────
                              if (folder.freeLayout)
                                for (var i = 0; i < tickets.length; i++)
                                  _FreeTicket(
                                    key: ValueKey(tickets[i].id),
                                    ticket: tickets[i],
                                    index: i,
                                    canvas: canvas,
                                    selected:
                                    _selected == 'ticket:${tickets[i].id}',
                                    onSelect: () => setState(() =>
                                    _selected = 'ticket:${tickets[i].id}'),
                                    dragging: _dragging ==
                                        'ticket:${tickets[i].id}',
                                    onStart: () {
                                      _settle.stop();
                                      _snapshot();
                                      _snap.begin();
                                      _startScale = tickets[i].pscale;
                                      _startRotation = tickets[i].protation;
                                      Feel.lift();
                                      setState(() => _dragging =
                                      'ticket:${tickets[i].id}');
                                    },
                                    onUpdate: (d) {
                                      final t = tickets[i];
                                      final twoFinger = d.pointerCount > 1;

                                      final rawX = ((t.px ?? 0.5) +
                                          d.focalPointDelta.dx /
                                              canvas.width)
                                          .clamp(0.05, 0.95);
                                      final rawY = ((t.py ?? 0.5) +
                                          d.focalPointDelta.dy /
                                              canvas.height)
                                          .clamp(0.05, 0.95);

                                      final rawScale = twoFinger
                                          ? (_startScale * d.scale)
                                          .clamp(0.45, 2.2)
                                          : t.pscale;
                                      final rawRotation = twoFinger
                                          ? _startRotation + d.rotation
                                          : t.protation;

                                      final snapped = _snap.apply(
                                        dx: rawX,
                                        dy: rawY,
                                        rotation: rawRotation,
                                        scale: rawScale,
                                        xGuides: SnapEngine.kPageGuides,
                                        yGuides: SnapEngine.kPageGuides,
                                        scaleGuides: [
                                          for (final o in tickets)
                                            if (o.id != t.id) o.pscale
                                        ],
                                        snapRotation: twoFinger,
                                        snapScale: twoFinger,
                                      );

                                      if (snapped.justEngaged) Feel.snap();

                                      setState(() {
                                        _guides = snapped.engaged;
                                        t.px = snapped.dx;
                                        t.py = snapped.dy;
                                        t.pscale = snapped.scale;
                                        t.protation = snapped.rotation;
                                      });
                                    },
                                    // 놓은 속도를 이어받아 미끄러져 멎습니다.
                                    // 여기가 이 앱에서 스프링을 쓰는 유일한 자리입니다.
                                    onEnd: (velocity) {
                                      final t = tickets[i];
                                      _snap.end();
                                      setState(() {
                                        _dragging = null;
                                        _guides = const <SnapAxis>{};
                                      });
                                      _settle.fling(
                                        from: Offset(t.px ?? 0.5, t.py ?? 0.5),
                                        velocity: Offset(
                                          velocity.dx / canvas.width,
                                          velocity.dy / canvas.height,
                                        ),
                                        bounds: const Rect.fromLTRB(
                                            0.05, 0.05, 0.95, 0.95),
                                        onUpdate: (at) => setState(() {
                                          t.px = at.dx;
                                          t.py = at.dy;
                                        }),
                                        onSettled: _endGesture,
                                      );
                                    },
                                  ),

                              // ── 장식 레이어 ────────────────
                              for (final layer in folder.pageLayers)
                                _Editable(
                                  key: ValueKey(layer.id),
                                  layer: layer,
                                  canvas: canvas,
                                  selected: _selected == 'layer:${layer.id}',
                                  onSelect: () {
                                    setState(
                                            () => _selected = 'layer:${layer.id}');
                                    folder.pageLayers
                                      ..removeWhere((l) => l.id == layer.id)
                                      ..add(layer);
                                    store.touch();
                                  },
                                  dragging:
                                  _dragging == 'layer:${layer.id}',
                                  onScaleStart: () {
                                    _snapshot();
                                    _snap.begin();
                                    _startScale = layer.scale;
                                    _startRotation = layer.rotation;
                                    Feel.lift();
                                    setState(() =>
                                    _dragging = 'layer:${layer.id}');
                                  },
                                  onScaleUpdate: (d) {
                                    final twoFinger = d.pointerCount > 1;

                                    final rawX = (layer.dx +
                                        d.focalPointDelta.dx / canvas.width)
                                        .clamp(0.0, 1.0);
                                    final rawY = (layer.dy +
                                        d.focalPointDelta.dy / canvas.height)
                                        .clamp(0.0, 1.0);
                                    final rawScale = twoFinger
                                        ? (_startScale * d.scale)
                                        .clamp(0.3, 4.0)
                                        : layer.scale;
                                    final rawRotation = twoFinger
                                        ? _startRotation + d.rotation
                                        : layer.rotation;

                                    final snapped = _snap.apply(
                                      dx: rawX,
                                      dy: rawY,
                                      rotation: rawRotation,
                                      scale: rawScale,
                                      xGuides: SnapEngine.kPageGuides,
                                      yGuides: SnapEngine.kPageGuides,
                                      scaleGuides: [
                                        for (final o in folder.pageLayers)
                                          if (o.id != layer.id) o.scale
                                      ],
                                      snapRotation: twoFinger,
                                      snapScale: twoFinger,
                                    );

                                    if (snapped.justEngaged) Feel.snap();

                                    setState(() {
                                      _guides = snapped.engaged;
                                      layer.dx = snapped.dx;
                                      layer.dy = snapped.dy;
                                      layer.scale = snapped.scale;
                                      layer.rotation = snapped.rotation;
                                    });
                                  },
                                  onScaleEnd: () {
                                    _snap.end();
                                    setState(() {
                                      _dragging = null;
                                      _guides = const <SnapAxis>{};
                                    });
                                    _endGesture();
                                  },
                                  onDelete: () => _remove(layer),
                                  onEdit: () => _edit(layer),
                                ),

                              if (folder.pageLayers.isEmpty &&
                                  tickets.isEmpty)
                                const Positioned.fill(child: _EmptyHint()),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),

              if (pickedLayer != null)
                _SelectedBar(
                  name: switch (pickedLayer.kind) {
                    LayerKind.sticker => '스티커',
                    LayerKind.text => '글자',
                    LayerKind.tape => '테이프',
                    LayerKind.photo => '폴라로이드',
                  },
                  onEdit: () => _edit(pickedLayer!),
                  onDelete: () => _remove(pickedLayer!),
                  onDone: () => setState(() => _selected = null),
                )
              else if (pickedTicket != null)
                _TicketBar(
                  ticket: pickedTicket,
                  onReset: () {
                    _snapshot();
                    setState(() {
                      pickedTicket!
                        ..pscale = 1.0
                        ..protation = 0.0;
                    });
                    store.touch();
                  },
                  onDone: () => setState(() => _selected = null),
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

/// 배치 방식을 알려주고 바꾸는 띠.
class _LayoutBanner extends StatelessWidget {
  const _LayoutBanner({
    required this.free,
    required this.hasTickets,
    required this.onFree,
    required this.onAuto,
  });

  final bool free;
  final bool hasTickets;
  final void Function({bool silent}) onFree;
  final VoidCallback onAuto;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 9, 10, 9),
        child: Row(
          children: [
            Icon(free ? Icons.open_with : Icons.auto_awesome_motion_outlined,
                size: 16, color: AppColors.foil),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                free
                    ? '티켓을 끌어 옮기고, 두 손가락으로 돌리세요'
                    : (hasTickets
                    ? '티켓은 자동으로 놓여 있습니다'
                    : '티켓을 만들면 이 페이지에 붙습니다'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(size: 12, color: AppColors.inkSoft),
              ),
            ),
            if (hasTickets)
              TextButton(
                onPressed: free ? onAuto : () => onFree(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.oxblood,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(free ? '자동 배치' : '자유 배치',
                    style:
                    AppText.ui(size: 12, weight: FontWeight.w600)),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('빈 페이지입니다',
                style: AppText.hand(size: 24, color: AppColors.pulp)),
            const SizedBox(height: 6),
            const DoodleUnderline(width: 120),
            const SizedBox(height: 10),
            Text('아래에서 스티커·글자·테이프를 골라 붙이세요',
                style: AppText.ui(size: 12, color: AppColors.pulp)),
          ],
        ),
      ),
    );
  }
}

/// 자유 배치된 티켓 한 장.
class _FreeTicket extends StatelessWidget {
  const _FreeTicket({
    super.key,
    required this.ticket,
    required this.index,
    required this.canvas,
    required this.selected,
    required this.onSelect,
    required this.dragging,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Ticket ticket;
  final int index;
  final Size canvas;
  final bool selected;
  final VoidCallback onSelect;

  /// 지금 손에 들려 있는지.
  final bool dragging;

  final VoidCallback onStart;
  final ValueChanged<ScaleUpdateDetails> onUpdate;

  /// 놓는 순간의 속도(픽셀/초)를 넘깁니다. 스프링이 이걸 이어받습니다.
  final ValueChanged<Offset> onEnd;

  @override
  Widget build(BuildContext context) {
    final at = defaultTicketPlacement(index);
    final x = (ticket.px ?? at.dx) * canvas.width;
    final y = (ticket.py ?? at.dy) * canvas.height;
    final width = canvas.width * freeTicketWidthFactor * ticket.pscale;

    return Positioned(
      left: x,
      top: y,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: GestureDetector(
          onTap: onSelect,
          onScaleStart: (_) {
            onSelect();
            onStart();
          },
          onScaleUpdate: onUpdate,
          onScaleEnd: (d) => onEnd(d.velocity.pixelsPerSecond),
          child: Transform.rotate(
            angle: ticket.protation,
            // 들어올리면 3%만. 그림자는 TapedTicket 안쪽이 이미 갖고 있어서
            // 여기서는 크기만 건드립니다.
            child: Transform.scale(
              scale: dragging ? 1.03 : 1.0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected
                        ? AppColors.foil.withValues(alpha: 0.9)
                        : Colors.transparent,
                  ),
                ),
                child: TapedTicket(
                  ticket: ticket,
                  width: width,
                  angle: 0,
                  tapeColor: scrapTapes[index % scrapTapes.length],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 페이지 위에서 옮기고 돌리고 키우는 장식 레이어.
class _Editable extends StatelessWidget {
  const _Editable({
    super.key,
    required this.layer,
    required this.canvas,
    required this.selected,
    required this.dragging,
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

  /// 지금 손에 들려 있는지.
  final bool dragging;

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
              scale: layer.scale * (dragging ? 1.03 : 1.0),
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
    required this.name,
    required this.onEdit,
    required this.onDelete,
    required this.onDone,
  });

  final String name;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _Bar(
      name: name,
      actions: [
        _BarAction(Icons.tune, '고치기', onEdit),
        _BarAction(Icons.delete_outline, '떼어내기', onDelete,
            color: AppColors.oxblood),
        _BarAction(Icons.check, '완료', onDone),
      ],
    );
  }
}

class _TicketBar extends StatelessWidget {
  const _TicketBar({
    required this.ticket,
    required this.onReset,
    required this.onDone,
  });

  final Ticket ticket;
  final VoidCallback onReset;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _Bar(
      name: ticket.title.replaceAll('\n', ' '),
      actions: [
        _BarAction(Icons.restart_alt, '크기·각도 초기화', onReset),
        _BarAction(Icons.check, '완료', onDone),
      ],
    );
  }
}

class _BarAction {
  const _BarAction(this.icon, this.tip, this.onTap, {this.color});

  final IconData icon;
  final String tip;
  final VoidCallback onTap;
  final Color? color;
}

class _Bar extends StatelessWidget {
  const _Bar({required this.name, required this.actions});

  final String name;
  final List<_BarAction> actions;

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
        padding: const EdgeInsets.fromLTRB(16, 5, 8, 5),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 18,
              margin: const EdgeInsets.only(right: 10),
              color: AppColors.foil,
            ),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(
                    size: 12, weight: FontWeight.w600, color: AppColors.ink),
              ),
            ),
            for (final a in actions)
              IconButton(
                tooltip: a.tip,
                onPressed: a.onTap,
                visualDensity: VisualDensity.compact,
                icon: Icon(a.icon, size: 19, color: a.color ?? AppColors.ink),
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