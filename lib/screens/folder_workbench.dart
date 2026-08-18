import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';
import '../widgets/folder_texture.dart';
import '../widgets/index_tab.dart';
import '../widgets/paper.dart';

/// 작업대를 엽니다.
///
/// [folder]가 null이면 새 서류철을 만들고, 아니면 그 서류철을 고칩니다.
/// 저장했으면 true를, 취소했으면 null/false를 돌려줍니다.
Future<bool?> openFolderWorkbench(
    BuildContext context, {
      required TicketStore store,
      ArchiveFolder? folder,
      int fileNo = 1,
      List<Ticket> preview = const [],
    }) {
  return Navigator.of(context).push<bool>(
    PageRouteBuilder<bool>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => FolderWorkbench(
        store: store,
        folder: folder,
        fileNo: fileNo,
        preview: preview,
      ),
      transitionsBuilder: (context, anim, _, child) {
        if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
          return FadeTransition(opacity: anim, child: child);
        }
        final t = Curves.easeOutCubic.transform(anim.value);
        return Opacity(
          opacity: anim.value,
          child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
        );
      },
    ),
  );
}

/// 서류철을 **책상 위에 꺼내 놓고 손으로 고치는** 화면.
///
/// 예전에는 길게 누르면 "고치기 / 버리기" 두 줄짜리 메뉴가 떴습니다.
/// 메뉴는 서류철을 다루는 감각이 아니라 파일 탐색기의 감각이라, 통째로 바꿨습니다.
///
/// - 서류철이 서랍에서 **뽑혀 나와 책상 위에 놓입니다.** 위쪽에 실물 크기로 떠 있고,
///   아래 도구함에서 무엇을 건드리든 **즉시 그 자리에서 바뀝니다.** 미리보기가 따로
///   없고, 고치는 대상 자체가 미리보기입니다.
/// - 이름 · 서체 · 색 · 질감 네 서랍을 옆으로 훑으며 고릅니다.
/// - **버릴 때는 메뉴에서 고르지 않고, 서류철을 아래로 끌어내립니다.** 내릴수록
///   파쇄 구역이 열리고 서류철이 기울며 작아집니다. 손을 놓으면 확인을 묻습니다.
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
  /// 화면에 떠 있는 서류철. 진짜 객체가 아니라 **초안**입니다.
  /// 저장을 눌러야 원본에 옮겨 적습니다.
  late final ArchiveFolder _draft;

  late final TextEditingController _name;
  late final TextEditingController _label;

  /// 아래로 끌어내린 거리. 파쇄 구역이 열리는 정도를 결정합니다.
  double _dragY = 0;

  /// 이 거리를 넘겨 손을 놓으면 버릴지 묻습니다.
  static const _shredAt = 108.0;

  bool get _isNew => widget.folder == null;

  @override
  void initState() {
    super.initState();
    final src = widget.folder;
    _draft = ArchiveFolder(
      id: src?.id ?? const Uuid().v4(),
      label: src?.label ?? '',
      subtitle: src?.subtitle ?? '',
      color: src?.color ?? AppColors.tabColors.first,
      font: src?.font ?? FolderFont.dymo,
      texture: src?.texture ?? FolderTexture.kraft,
    );
    _name = TextEditingController(text: _draft.subtitle);
    _label = TextEditingController(text: _draft.label);

    _name.addListener(() => setState(() => _draft.subtitle = _name.text));
    _label.addListener(() => setState(() => _draft.label = _label.text));
  }

  @override
  void dispose() {
    _name.dispose();
    _label.dispose();
    super.dispose();
  }

  // ── 저장 / 버리기 ────────────────────────────────

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.ink,
          content: Text('서류철 이름을 적어주세요',
              style: AppText.ui(size: 13, color: AppColors.stockLight)),
        ),
      );
      return;
    }

    // 라벨을 비우면 순번으로 자동 생성합니다.
    var label = _label.text.trim();
    if (label.isEmpty) {
      label = 'FILE ${widget.fileNo.toString().padLeft(2, '0')}';
    }

    if (_isNew) {
      widget.store.addFolder(ArchiveFolder(
        id: _draft.id,
        label: label,
        subtitle: name,
        color: _draft.color,
        font: _draft.font,
        texture: _draft.texture,
      ));
    } else {
      widget.folder!
        ..subtitle = name
        ..label = label
        ..color = _draft.color
        ..font = _draft.font
        ..texture = _draft.texture;
      widget.store.touch();
    }

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(true);
  }

  Future<void> _confirmShred() async {
    if (_isNew) {
      // 아직 만들지도 않은 서류철은 그냥 접습니다.
      Navigator.of(context).pop(false);
      return;
    }

    final n = widget.store.countIn(_draft.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.stockLight,
        shape: const RoundedRectangleBorder(),
        title: Text('서류철을 파쇄할까요?',
            style: AppText.ui(size: 16, color: AppColors.ink)),
        content: Text(
          n == 0
              ? '「${_draft.subtitle}」 서류철을 버립니다.'
              : '「${_draft.subtitle}」 안의 티켓 $n장도 함께 버려집니다.\n복구할 수 없습니다.',
          style: AppText.ui(size: 13, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('그대로 두기',
                style: AppText.ui(size: 13, color: AppColors.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('파쇄하기',
                style: AppText.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.oxblood)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (ok == true) {
      HapticFeedback.heavyImpact();
      widget.store.removeFolder(_draft.id);
      Navigator.of(context).pop(true);
    } else {
      setState(() => _dragY = 0);
    }
  }

  // ── 화면 ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    // 끌어내린 정도. 0 → 1.
    final pull = (_dragY / _shredAt).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── 책상 ─────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(false),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.45),
                    radius: 1.1,
                    colors: [
                      AppColors.bg,
                      AppColors.bgDeep,
                      const Color(0xFF2A2118).withValues(alpha: 0.86),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const WallGrain(opacity: 0.06, seed: 41),

          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  isNew: _isNew,
                  onClose: () => Navigator.of(context).pop(false),
                ),

                // ── 책상 위의 서류철 ────────────────
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 파쇄 구역. 끌어내릴수록 열립니다.
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Opacity(
                            opacity: pull,
                            child: _ShredZone(armed: pull >= 1),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Transform.translate(
                          offset: Offset(0, _dragY),
                          child: Transform.rotate(
                            angle: pull * 0.06,
                            child: Transform.scale(
                              scale: 1 - pull * 0.10,
                              child: _DraggableFolder(
                                folder: _draft,
                                fileNo: widget.fileNo,
                                preview: widget.preview,
                                count: _isNew
                                    ? 0
                                    : widget.store.countIn(_draft.id),
                                onDrag: (dy) => setState(() {
                                  _dragY = math.max(0, _dragY + dy);
                                }),
                                onDragEnd: () {
                                  if (_dragY >= _shredAt) {
                                    _confirmShred();
                                  } else {
                                    setState(() => _dragY = 0);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 도구함 ─────────────────────────
                Padding(
                  padding: EdgeInsets.only(bottom: insets),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: size.height * 0.52),
                    child: _ToolDrawer(
                      draft: _draft,
                      name: _name,
                      label: _label,
                      isNew: _isNew,
                      onChanged: () => setState(() {}),
                      onSave: _save,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 위쪽 안내 줄.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.isNew, required this.onClose});

  final bool isNew;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isNew ? 'NEW FOLDER' : 'WORKBENCH',
                    style: AppText.eyebrow(color: AppColors.foil)),
                const SizedBox(height: 4),
                Text(
                  isNew ? '서류철을 한 장 새로 맵니다' : '아래로 끌어내리면 파쇄합니다',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(size: 12, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 22, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

/// 책상 위에 놓인 서류철. 세로로 끌면 파쇄 구역으로 내려갑니다.
class _DraggableFolder extends StatelessWidget {
  const _DraggableFolder({
    required this.folder,
    required this.fileNo,
    required this.preview,
    required this.count,
    required this.onDrag,
    required this.onDragEnd,
  });

  final ArchiveFolder folder;
  final int fileNo;
  final List<Ticket> preview;
  final int count;
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      onVerticalDragEnd: (_) => onDragEnd(),
      onVerticalDragCancel: onDragEnd,
      child: SizedBox(
        height: FolderMetrics.cardHeight,
        child: FolderCard(
          folder: folder,
          count: count,
          tabSlot: 0,
          totalSlots: 1,
          fileNo: fileNo,
          lifted: true,
          preview: preview,
          onTap: () {},
        ),
      ),
    );
  }
}

/// 서류철을 내리면 열리는 파쇄 구역.
class _ShredZone extends StatelessWidget {
  const _ShredZone({required this.armed});

  final bool armed;

  @override
  Widget build(BuildContext context) {
    final c = armed ? AppColors.oxblood : AppColors.inkSoft;
    return Container(
      height: 76,
      margin: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: armed ? 0.16 : 0.07),
        border: Border.all(color: c.withValues(alpha: 0.55), width: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(armed ? Icons.delete_forever : Icons.delete_outline,
              size: 22, color: c),
          const SizedBox(height: 6),
          Text(
            armed ? '손을 놓으면 파쇄합니다' : '여기까지 끌어내리세요',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.data(size: 10, spacing: 1.4, color: c),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 도구함
// ─────────────────────────────────────────────────────────────

class _ToolDrawer extends StatelessWidget {
  const _ToolDrawer({
    required this.draft,
    required this.name,
    required this.label,
    required this.isNew,
    required this.onChanged,
    required this.onSave,
  });

  final ArchiveFolder draft;
  final TextEditingController name;
  final TextEditingController label;
  final bool isNew;
  final VoidCallback onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.stockLight,
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: paperShadow(depth: 0.8),
      ),
      child: Stack(
        children: [
          const WallGrain(opacity: 0.05, seed: 9),
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 이름 ─────────────────────────
                  const _RailTitle('이름', 'NAME'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                    child: _field(name, '예: 올해 다녀온 전시'),
                  ),
                  const _RailTitle('탭 라벨', 'TAB'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                    child: _field(label, '비우면 자동으로 채웁니다'),
                  ),

                  // ── 서체 ─────────────────────────
                  const _RailTitle('서체', 'TYPEFACE'),
                  SizedBox(
                    height: 62,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: FolderFont.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final f = FolderFont.values[i];
                        return _FontChip(
                          font: f,
                          selected: draft.font == f,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            draft.font = f;
                            onChanged();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 색 ──────────────────────────
                  const _RailTitle('색', 'COLOUR'),
                  SizedBox(
                    height: 46,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: AppColors.tabColors.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final c = AppColors.tabColors[i];
                        return _Swatch(
                          color: c,
                          selected: draft.color.toARGB32() == c.toARGB32(),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            draft.color = c;
                            onChanged();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── 질감 ─────────────────────────
                  const _RailTitle('질감', 'TEXTURE'),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: FolderTexture.values.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final t = FolderTexture.values[i];
                        return _TextureChip(
                          texture: t,
                          base: draft.color,
                          seed: draft.id.hashCode + i,
                          selected: draft.texture == t,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            draft.texture = t;
                            onChanged();
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.oxblood,
                          foregroundColor: AppColors.stockLight,
                          shape: const RoundedRectangleBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isNew ? '서류철 만들기' : '저장',
                          style:
                          AppText.ui(size: 14, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String hint) => TextField(
    controller: c,
    style: AppText.ui(size: 15, color: AppColors.ink),
    decoration: InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: AppText.ui(size: 14, color: AppColors.pulp),
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.line),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.foil, width: 1.4),
      ),
    ),
  );
}

class _RailTitle extends StatelessWidget {
  const _RailTitle(this.ko, this.en);

  final String ko;
  final String en;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
      child: Row(
        children: [
          Text(ko,
              style: AppText.ui(
                  size: 12, weight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(width: 8),
          Text(en, style: AppText.eyebrow(color: AppColors.pulp)),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: AppColors.line, height: 1)),
        ],
      ),
    );
  }
}

class _FontChip extends StatelessWidget {
  const _FontChip({
    required this.font,
    required this.selected,
    required this.onTap,
  });

  final FolderFont font;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.stock,
          border: Border.all(
            color: selected ? AppColors.ink : AppColors.line,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '기록 Aa',
              maxLines: 1,
              style: font.style(
                size: 13,
                color: selected ? AppColors.stockLight : AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              font.label,
              maxLines: 1,
              style: AppText.data(
                size: 8.5,
                spacing: 0.8,
                color: selected
                    ? AppColors.stockLight.withValues(alpha: 0.7)
                    : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.ink : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected ? paperShadow(depth: 0.3) : null,
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: AppColors.stockLight)
            : null,
      ),
    );
  }
}

class _TextureChip extends StatelessWidget {
  const _TextureChip({
    required this.texture,
    required this.base,
    required this.seed,
    required this.selected,
    required this.onTap,
  });

  final FolderTexture texture;
  final Color base;
  final int seed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: EdgeInsets.all(selected ? 2 : 0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: selected ? AppColors.ink : Colors.transparent,
                  width: 1.4,
                ),
              ),
              child: SizedBox(
                width: 64,
                height: 38,
                child: FolderSurface(
                  color: base,
                  texture: texture,
                  seed: seed,
                  wear: 0.6,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              texture.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppText.ui(
                size: 10,
                weight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? AppColors.ink : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}