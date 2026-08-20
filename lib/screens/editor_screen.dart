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
import '../widgets/snap.dart';
import '../widgets/stamp.dart';
import '../widgets/ticket_card.dart';
import 'record_sheet.dart';
import 'scrap_sheets.dart';
import 'ticket_style_sheet.dart';

/// 스크랩북 에디터.
///
/// 캔버스 위 레이어를 한 손가락으로 옮기고, 두 손가락으로 돌리고 키웁니다.
/// 좌표는 캔버스 비율로 저장되어 기기 크기가 달라도 배치가 유지됩니다.
///
/// **되돌리기** — 붙였다가 마음에 안 들면 되돌릴 방법이 없던 게 가장 큰 문제였습니다.
/// 이제 레이어를 건드리는 모든 동작 직전에 스냅샷을 쌓아서, 앱바의 ↩︎ / ↪︎ 로
/// 몇 단계든 되감을 수 있습니다. 선택한 레이어는 ✕ 로 바로 뗄 수도 있고,
/// 길게 누르면 곧장 떨어집니다.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final store = TicketStore.instance;
  final _uuid = const Uuid();
  final _picker = ImagePicker();

  String? _selectedId;

  // 제스처 시작 시점의 값을 붙잡아 둡니다.
  double _startScale = 1;
  double _startRotation = 0;

  /// 지금 끌고 있는 레이어. 들어올림 그림자를 이 아이에게만 겁니다.
  String? _draggingId;

  /// 회전·자리·크기 눈금.
  final _snap = SnapEngine();

  /// 지금 걸려 있는 눈금. 가이드선을 그릴 때 씁니다.
  Set<SnapAxis> _guides = const <SnapAxis>{};

  /// 레이어 전체를 직렬화한 스냅샷 스택. 가볍고(문자열) 되돌리기가 정확합니다.
  final List<String> _undo = [];
  final List<String> _redo = [];
  static const _maxHistory = 40;

  Ticket get _ticket => store.byId(widget.ticketId)!;

  // ── 되돌리기 ─────────────────────────────────────

  /// 레이어를 바꾸기 **직전에** 부릅니다.
  void _snapshot() {
    _undo.add(ScrapLayer.encodeList(_ticket.layers));
    if (_undo.length > _maxHistory) _undo.removeAt(0);
    _redo.clear();
  }

  void _restore(String raw) {
    final layers = ScrapLayer.decodeList(raw);
    _ticket.layers
      ..clear()
      ..addAll(layers);
    // 사라진 레이어를 계속 선택하고 있으면 안 됩니다.
    if (!_ticket.layers.any((l) => l.id == _selectedId)) _selectedId = null;
    store.touch();
  }

  /// 제스처가 끝났는데 아무것도 안 바뀌었으면, 방금 쌓은 스냅샷은 버립니다.
  /// (그냥 톡 눌러 선택만 해도 되돌리기 단계가 쌓이면 곤란합니다)
  void _endGesture() {
    if (_undo.isNotEmpty &&
        _undo.last == ScrapLayer.encodeList(_ticket.layers)) {
      _undo.removeLast();
    }
    store.touch();
    setState(() {});
  }

  void _undoOnce() {
    if (_undo.isEmpty) return;
    Feel.pick();
    _redo.add(ScrapLayer.encodeList(_ticket.layers));
    _restore(_undo.removeLast());
    setState(() {});
  }

  void _redoOnce() {
    if (_redo.isEmpty) return;
    Feel.pick();
    _undo.add(ScrapLayer.encodeList(_ticket.layers));
    _restore(_redo.removeLast());
    setState(() {});
  }

  // ── 화면 ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ticket = store.byId(widget.ticketId);
        if (ticket == null) {
          return const Scaffold(body: Center(child: Text('삭제된 티켓입니다')));
        }

        // 루프에서 바로 쓰면 널 승격(promotion)이 안 걸려서
        // `_LayerBar(layer: selected)`가 ScrapLayer? 로 남습니다.
        // 찾은 값을 final 지역 변수에 한 번 옮겨 담아 확정합니다.
        ScrapLayer? found;
        for (final l in ticket.layers) {
          if (l.id == _selectedId) found = l;
        }
        final selected = found;

        return Scaffold(
          appBar: AppBar(
            title: const Text('EDITOR'),
            actions: [
              _HistoryButton(
                icon: Icons.undo,
                tooltip: '되돌리기',
                enabled: _undo.isNotEmpty,
                onTap: _undoOnce,
              ),
              _HistoryButton(
                icon: Icons.redo,
                tooltip: '다시 하기',
                enabled: _redo.isNotEmpty,
                onTap: _redoOnce,
              ),
              // 눈금을 끄면 완전 자유각이 됩니다. 정밀 배치를 원하는
              // 사용자를 위한 탈출구입니다.
              _HistoryButton(
                icon: _snap.enabled
                    ? Icons.grid_on
                    : Icons.grid_off,
                tooltip: _snap.enabled ? '눈금 끄기' : '눈금 켜기',
                enabled: true,
                onTap: () {
                  Feel.pick();
                  setState(() {
                    _snap.enabled = !_snap.enabled;
                    _guides = const <SnapAxis>{};
                  });
                },
              ),
              const SizedBox(width: 4),
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
                  // 빈 곳을 누르면 선택 해제.
                  onTap: () => setState(() => _selectedId = null),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    children: [
                      const WallGrain(opacity: 0.04, seed: 17),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 28),
                          child: AspectRatio(
                            aspectRatio: ticket.frame.aspect,
                            // 레이어의 기준 사각형을 **티켓 자신**으로 잡습니다.
                            // 화면을 기준으로 잡으면 티켓을 뒤집거나 프레임을
                            // 바꿨을 때 붙여둔 것만 배경에 남습니다.
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final canvas = Size(c.maxWidth, c.maxHeight);
                                return Stack(
                                  // 티켓 밖으로 조금 삐져나오는 건 자연스럽습니다.
                                  clipBehavior: Clip.none,
                                  children: [
                                    // 레이어를 집어 들면 티켓 자체도 살짝
                                    // 가라앉습니다. 들린 건 레이어지 티켓이
                                    // 아니라는 걸 그림자 대비로 알립니다.
                                    Positioned.fill(
                                      child: PaperLift(
                                        lifted: false,
                                        depth: _draggingId == null ? 0.9 : 0.6,
                                        child: TicketFront(ticket: ticket),
                                      ),
                                    ),
                                    // 눈금에 걸린 축만 실선으로 비칩니다.
                                    if (_guides.isNotEmpty)
                                      Positioned.fill(
                                        child: SnapGuides(engaged: _guides),
                                      ),

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
                                        dragging: _draggingId == layer.id,
                                        onScaleStart: () {
                                          _snapshot();
                                          _snap.begin();
                                          _startScale = layer.scale;
                                          _startRotation = layer.rotation;
                                          Feel.lift();
                                          setState(
                                                  () => _draggingId = layer.id);
                                        },
                                        onScaleUpdate: (details) {
                                          // 1) 손가락이 민 만큼 날것으로 옮깁니다.
                                          final rawX = (layer.dx +
                                              details.focalPointDelta.dx /
                                                  canvas.width)
                                              .clamp(0.0, 1.0);
                                          final rawY = (layer.dy +
                                              details.focalPointDelta.dy /
                                                  canvas.height)
                                              .clamp(0.0, 1.0);

                                          var rawScale = layer.scale;
                                          var rawRotation = layer.rotation;
                                          final twoFinger =
                                              details.pointerCount > 1;

                                          if (twoFinger) {
                                            rawScale =
                                                (_startScale * details.scale)
                                                    .clamp(0.3, 4.0);
                                            rawRotation = _startRotation +
                                                details.rotation;
                                          }

                                          // 2) 눈금에 붙입니다. 형제 레이어의
                                          //    배율을 넘겨, 옆 것과 같은 크기에도 걸리게.
                                          final snapped = _snap.apply(
                                            dx: rawX,
                                            dy: rawY,
                                            rotation: rawRotation,
                                            scale: rawScale,
                                            scaleGuides: [
                                              for (final l in ticket.layers)
                                                if (l.id != layer.id) l.scale
                                            ],
                                            snapRotation: twoFinger,
                                            snapScale: twoFinger,
                                          );

                                          // 3) 눈금에 **새로** 들어간 순간에만 울립니다.
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
                                            _draggingId = null;
                                            _guides = const <SnapAxis>{};
                                          });
                                          _endGesture();
                                        },
                                        onDelete: () => _removeLayer(layer),
                                        onEdit: () => _editLayer(layer),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 선택된 레이어를 다루는 줄. 없으면 자리를 차지하지 않습니다.
              if (selected != null)
                _LayerBar(
                  layer: selected,
                  onEdit: () => _editLayer(selected),
                  onDuplicate: () => _duplicate(selected),
                  onDelete: () => _removeLayer(selected),
                  onRotate: (d) => _nudgeRotation(selected, d),
                  onStraighten: () => _straighten(selected),
                  onDone: () => setState(() => _selectedId = null),
                ),

              _Toolbar(
                onFrame: () => _openStyle(0),
                onPoster: () => _openStyle(1),
                onSticker: _addSticker,
                onStamp: _addStamp,
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
    _snapshot();
    store.addLayer(widget.ticketId, layer);
    Feel.place();
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
      dy: 0.4,
      color: picked.color.toARGB32(),
      fontSize: 18,
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
      dy: 0.35,
      color: picked.color.toARGB32(),
      fontSize: picked.size,
      font: picked.font.name,
    ));
  }

  /// 도장은 **크기 자체가 표현**이라, 시트에서 고른 지름을 fontSize에 담습니다.
  /// 스케일로 키우면 테두리 두께까지 같이 굵어져 도장처럼 안 보입니다.
  Future<void> _addStamp() async {
    final picked = await pickStamp(context);
    if (picked == null) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.stamp,
      content: picked.spec.encode(),
      dx: 0.72,
      dy: 0.72,
      // 반듯한 도장은 없습니다. 살짝 비뚤게 찍힙니다.
      rotation: -0.14,
      color: picked.color.toARGB32(),
      fontSize: picked.size,
    ));
    Feel.stamp(); // 붙인 게 아니라 찍은 것. 손끝에도 그렇게 전합니다.
  }

  Future<void> _addTape() async {
    final picked = await pickTape(context);
    if (picked == null) return;
    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.tape,
      content: picked.pattern.name,
      dx: 0.34,
      dy: 0.22,
      rotation: -0.3,
      color: picked.color.toARGB32(),
    ));
  }

  /// 폴라로이드 붙이기.
  ///
  /// **툴바를 누르자마자 갤러리가 뜨지 않습니다.** 어디서 가져올지 먼저
  /// 묻고, 시트를 그냥 내리면 아무 일도 일어나지 않습니다. 도구를 구경하다
  /// 시스템 앨범에 갇히던 문제를 여기서 끊습니다.
  Future<void> _addPhoto() async {
    final source = await pickPhotoSource(context);
    if (source == null || !mounted) return;

    final path = await _pickImagePath(source);
    if (!mounted) return;

    // 갤러리를 열었다가 아무것도 안 고르고 나온 경우 = 취소.
    // 빈 폴라로이드를 몰래 붙여 놓으면 사용자가 지워야 합니다.
    if (source != PhotoSource.blank && path == null) return;

    _place(ScrapLayer(
      id: _uuid.v4(),
      kind: LayerKind.photo,
      content: path ?? '',
      dx: 0.68,
      dy: 0.6,
      rotation: 0.12,
      color: AppColors.oxbloodDim.toARGB32(),
    ));

    if (path == null || path.isEmpty) {
      PaperToast.show(context, '빈 폴라로이드를 붙였습니다',
          detail: '두 번 누르면 사진을 넣을 수 있습니다');
    }
  }

  /// 실제로 사진 한 장을 가져옵니다. 취소하면 null.
  Future<String?> _pickImagePath(PhotoSource source) async {
    if (source == PhotoSource.blank) return null;
    try {
      final shot = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1400,
        imageQuality: 88,
      );
      return shot?.path;
    } catch (e) {
      if (mounted) {
        PaperToast.warn(context, '사진을 불러오지 못했습니다', detail: '$e');
      }
      return null;
    }
  }

  // ── 레이어 조작 ───────────────────────────────────

  void _removeLayer(ScrapLayer layer) {
    _snapshot();
    store.removeLayer(widget.ticketId, layer.id);
    Feel.stamp();
    setState(() => _selectedId = null);
    PaperToast.show(context, '한 겹 떼어냈습니다', detail: '↩︎ 로 되돌릴 수 있습니다');
  }

  /// 선택한 레이어를 한 칸(7.5°) 돌립니다.
  ///
  /// 두 손가락 회전은 이미 되지만, 작은 스티커 위에서 두 손가락을 벌리면
  /// 손가락이 대상을 다 가립니다. 한 손으로 각도를 다듬을 길이 필요합니다.
  void _nudgeRotation(ScrapLayer layer, double delta) {
    _snapshot();
    Feel.pick();
    setState(() => layer.rotation += delta);
    _endGesture();
  }

  /// 각도만 0으로. 크기와 자리는 건드리지 않습니다.
  void _straighten(ScrapLayer layer) {
    if (layer.rotation == 0) return;
    _snapshot();
    Feel.snap();
    setState(() => layer.rotation = 0);
    _endGesture();
  }

  void _duplicate(ScrapLayer layer) {
    _snapshot();
    final copy = layer.copyWith(id: _uuid.v4())
      ..dx = (layer.dx + 0.06).clamp(0.0, 1.0)
      ..dy = (layer.dy + 0.06).clamp(0.0, 1.0);
    store.addLayer(widget.ticketId, copy);
    Feel.lift();
    setState(() => _selectedId = copy.id);
  }

  /// 레이어 종류에 맞는 시트를 열어 내용을 고칩니다.
  Future<void> _editLayer(ScrapLayer layer) async {
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

      case LayerKind.stamp:
        final picked = await pickStamp(
          context,
          initial: StampSpec.decode(layer.content),
          color: Color(layer.color),
          size: layer.fontSize,
        );
        if (picked == null) return;
        _snapshot();
        layer
          ..content = picked.spec.encode()
          ..color = picked.color.toARGB32()
          ..fontSize = picked.size;

      case LayerKind.photo:
        final source = await pickPhotoSource(context);
        if (source == null || !mounted) return;
        final path = await _pickImagePath(source);
        if (source != PhotoSource.blank && path == null) return;
        _snapshot();
        layer.content = path ?? '';
    }

    store.touch();
    if (mounted) setState(() {});
  }

  // ── 티켓 정보 편집 ────────────────────────────────

  /// 프레임(0) 또는 포스터(1) 탭으로 스타일 시트를 엽니다.
  void _openStyle(int tab) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.stockLight,
      builder: (context) => TicketStyleSheet(
        ticket: _ticket,
        store: store,
        initialTab: tab,
      ),
    );
  }

  void _editInfo() =>
      openRecordSheet(context, ticket: _ticket, store: store);
}

/// 앱바의 되돌리기 버튼. 쓸 수 없을 땐 흐려집니다.
class _HistoryButton extends StatelessWidget {
  const _HistoryButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(
        icon,
        size: 20,
        color: enabled ? AppColors.ink : AppColors.pulp,
      ),
    );
  }
}

/// 선택한 레이어에 바로 손을 대는 줄.
class _LayerBar extends StatelessWidget {
  const _LayerBar({
    required this.layer,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onRotate,
    required this.onStraighten,
    required this.onDone,
  });

  final ScrapLayer layer;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  /// 라디안 증분. 길게 누르면 각도를 0으로 되돌립니다.
  final ValueChanged<double> onRotate;
  final VoidCallback onStraighten;
  final VoidCallback onDone;

  /// 한 번에 도는 각도. 7.5°씩이면 24번에 한 바퀴입니다.
  static const _step = 0.1309;

  String get _name => switch (layer.kind) {
    LayerKind.sticker => '스티커',
    LayerKind.text => '글자',
    LayerKind.tape => '테이프',
    LayerKind.photo => '폴라로이드',
    LayerKind.stamp => '도장',
  };

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
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              color: AppColors.foil,
            ),
            // 버튼이 여섯 개라, 이름 쪽이 먼저 양보해야 좁은 화면에서
            // 노란 오버플로 줄무늬가 뜨지 않습니다.
            Flexible(
              child: Text(_name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.ink)),
            ),
            const Spacer(),
            _act(Icons.rotate_left, '왼쪽으로 돌리기', () => onRotate(-_step),
                onLongPress: onStraighten),
            _act(Icons.rotate_right, '오른쪽으로 돌리기', () => onRotate(_step),
                onLongPress: onStraighten),
            _act(Icons.tune, '고치기', onEdit),
            _act(Icons.copy_all_outlined, '복제', onDuplicate),
            _act(Icons.delete_outline, '떼어내기', onDelete,
                color: AppColors.oxblood),
            _act(Icons.check, '완료', onDone),
          ],
        ),
      ),
    );
  }

  Widget _act(IconData icon, String tip, VoidCallback onTap,
      {Color? color, VoidCallback? onLongPress}) {
    final button = IconButton(
      tooltip: tip,
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      icon: Icon(icon, size: 19, color: color ?? AppColors.ink),
    );
    if (onLongPress == null) return button;
    // 길게 누르면 '똑바로'. 회전 버튼 옆에 초기화 버튼을 하나 더 두면
    // 줄이 길어져서, 같은 자리에 겹쳐 둡니다.
    return GestureDetector(onLongPress: onLongPress, child: button);
  }
}

/// 한 손가락 = 이동, 두 손가락 = 회전 + 확대.
class _EditableLayer extends StatelessWidget {
  const _EditableLayer({
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

  /// 지금 손에 들려 있는지. 그림자와 크기가 여기에 반응합니다.
  final bool dragging;

  final VoidCallback onSelect;
  final VoidCallback onScaleStart;
  final ValueChanged<ScaleUpdateDetails> onScaleUpdate;
  final VoidCallback onScaleEnd;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  /// 레이어를 아무리 줄여도 손잡이는 손끝만 하게 남깁니다.
  /// (0.5배로 줄인 스티커의 ✕가 13픽셀이면 아무도 못 누릅니다)
  double get _handleScale => (1 / layer.scale).clamp(0.55, 2.0);

  /// 손잡이가 Stack 안에 온전히 들어앉는 데 필요한 여백.
  double get _handlePad => _Handle.diameter * _handleScale / 2 + 2;

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
          // 길게 누르면 바로 떨어집니다. 되돌리기가 있으니 안심하고 뗄 수 있습니다.
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
              // 들어올리면 3%만 커집니다. 그 이상은 확대로 읽힙니다.
              scale: layer.scale * (dragging ? 1.03 : 1.0),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 손잡이가 **앉을 자리**를 미리 비워 둡니다.
                  //
                  // 예전에는 손잡이를 `right: -13, top: -13`으로 Stack 밖에
                  // 내걸었습니다. `Clip.none` 덕분에 보이기는 했지만,
                  // Flutter의 `RenderBox.hitTest`는 **자기 크기 밖의 좌표를
                  // 먼저 걸러냅니다.** 그래서 ✕는 그려지기만 하고 탭이 한 번도
                  // 닿지 않았습니다. 이게 "X를 눌러도 안 지워진다"의 정체입니다.
                  Padding(
                    padding: EdgeInsets.all(_handlePad),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected
                              ? AppColors.foil.withValues(alpha: 0.9)
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: buildLayerContent(layer),
                    ),
                  ),

                  // 선택했을 때만 나오는 손잡이 두 개.
                  // 레이어 배율을 되돌려서, 아주 작게 줄인 스티커에서도
                  // 손끝만 한 크기를 지킵니다.
                  if (selected) ...[
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _Handle(
                        icon: Icons.close,
                        color: AppColors.oxblood,
                        scale: _handleScale,
                        onTap: onDelete,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _Handle(
                        icon: Icons.tune,
                        color: AppColors.ink,
                        scale: _handleScale,
                        onTap: onEdit,
                      ),
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

/// 레이어 모서리에 붙는 작고 확실한 버튼.
class _Handle extends StatelessWidget {
  const _Handle({
    required this.icon,
    required this.color,
    required this.onTap,
    this.scale = 1,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// 바깥 `Transform.scale`을 상쇄하는 배율.
  final double scale;

  /// 손잡이 지름. 여백 계산이 이 값을 참조합니다.
  static const diameter = 28.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      // 작은 아이콘이라 히트 영역을 넉넉히 잡습니다.
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: diameter * scale,
        height: diameter * scale,
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
        child: Icon(icon, size: 15 * scale, color: AppColors.stockLight),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onFrame,
    required this.onPoster,
    required this.onSticker,
    required this.onStamp,
    required this.onText,
    required this.onTape,
    required this.onPhoto,
    required this.onInfo,
  });

  final VoidCallback onFrame;
  final VoidCallback onPoster;
  final VoidCallback onSticker;
  final VoidCallback onStamp;
  final VoidCallback onText;
  final VoidCallback onTape;
  final VoidCallback onPhoto;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Stack(
        children: [
          const WallGrain(opacity: 0.05, seed: 31),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  _tool(Icons.crop_free, '프레임', onFrame),
                  _tool(Icons.wallpaper_outlined, '포스터', onPoster),
                  _tool(Icons.auto_awesome_outlined, '스티커', onSticker),
                  _tool(Icons.approval_outlined, '도장', onStamp),
                  _tool(Icons.text_fields, '글자', onText),
                  _tool(Icons.horizontal_rule, '테이프', onTape),
                  _tool(Icons.photo_outlined, '폴라로이드', onPhoto),
                  _tool(Icons.edit_note, '기록', onInfo),
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
          Text(label, style: AppText.ui(size: 10, color: AppColors.inkSoft)),
        ],
      ),
    ),
  );
}