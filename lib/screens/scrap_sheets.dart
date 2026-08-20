import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';
import '../widgets/paper.dart';
import '../widgets/scrap_layers.dart';
import '../widgets/stamp.dart';

// ─────────────────────────────────────────────────────────────
// 팔레트
// ─────────────────────────────────────────────────────────────

/// 스크랩에 쓰는 색. 앱 팔레트에서 뻗어 나온 톤만 씁니다.
class ScrapPalette {
  ScrapPalette._();

  /// 스티커·글자용 잉크. 불투명.
  static const inks = <Color>[
    Color(0xFF251E15), // 잉크
    Color(0xFF6B1F1A), // 옥스블러드
    Color(0xFF8C7134), // 황동
    Color(0xFF44503F), // 올리브
    Color(0xFF2F3D4C), // 네이비
    Color(0xFF7C6047), // 다크 크라프트
    Color(0xFFB08F5C), // 마닐라
    Color(0xFFC2513A), // 벽돌
    Color(0xFFD08A2E), // 감귤
    Color(0xFF3B2E5A), // 자수정
    Color(0xFF6E8B7A), // 세이지
    Color(0xFF7FA6A0), // 청자
    Color(0xFFB8A9D9), // 라벤더
    Color(0xFFE0B8B0), // 살구
    Color(0xFF6E6152), // 바랜 잉크
    Color(0xFFFCF8EE), // 백지
  ];

  /// 테이프용. 알파를 낮춰 아래가 비칩니다.
  static const tapes = <Color>[
    Color(0x998C7134),
    Color(0x993F4A3C),
    Color(0x996B1F1A),
    Color(0x992E3B4E),
    Color(0x99B08F5C),
    Color(0x99C2513A),
    Color(0x996E8B7A),
    Color(0x997FA6A0),
    Color(0x99B8A9D9),
    Color(0x99E0B8B0),
    Color(0x99C7BBA2),
    Color(0x66251E15),
  ];

  /// 도장 잉크. 실제 인주·스탬프 패드에 있는 색만 씁니다.
  /// 스티커 잉크와 달리 **알파를 살짝 낮춰** 아래 글자가 비칩니다.
  static const stampInks = <Color>[
    Color(0xE6A5321F), // 주인 (붉은 인주)
    Color(0xE66B1F1A), // 옥스블러드
    Color(0xE62F3D4C), // 감청
    Color(0xE6251E15), // 먹
    Color(0xE644503F), // 짙은 올리브
    Color(0xE68C7134), // 황동
    Color(0xE63B2E5A), // 자수정
    Color(0xE6C2513A), // 벽돌
    Color(0xE66E8B7A), // 세이지
    Color(0xE6B08F5C), // 마닐라
  ];

  /// 이모지 스티커. 벡터로 안 만든 것들만 남겼습니다.
  static const emoji = <String>[
    '🎟️', '🖼️', '✂️', '📎', '📌', '🕯️', '🗝️', '🎨',
    '☕', '🌙', '⭐', '🧾', '📷', '🪞', '🍃', '✦',
    '🌷', '🍷', '🎧', '📖', '🚃', '🗿', '🧦', '🫖',
  ];
}

// ─────────────────────────────────────────────────────────────
// 시트 껍데기
// ─────────────────────────────────────────────────────────────

/// 모든 스크랩 시트가 같은 종이를 씁니다.
class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.eyebrow,
    required this.child,
    this.preview,
    this.action,
  });

  final String eyebrow;
  final Widget child;

  /// 위쪽 고정 미리보기.
  final Widget? preview;

  /// 아래 고정 버튼.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Stack(
        children: [
          Positioned.fill(
            child: PaperSurface(
              color: AppColors.stockLight,
              grain: 0.05,
              seed: eyebrow.hashCode,
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(eyebrow, style: scrapEyebrow()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(height: 1, color: AppColors.line),
                      ),
                    ],
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: 16),
                  preview!,
                ],
                const SizedBox(height: 14),
                Flexible(child: child),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                    child: SizedBox(width: double.infinity, child: action!),
                  ),
                ] else
                  const SizedBox(height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _primaryButton(String label, VoidCallback onTap) => FilledButton(
  onPressed: onTap,
  style: FilledButton.styleFrom(
    backgroundColor: AppColors.oxblood,
    foregroundColor: AppColors.stockLight,
    shape: const RoundedRectangleBorder(),
    padding: const EdgeInsets.symmetric(vertical: 15),
  ),
  child: Text(label, style: AppText.ui(size: 14, weight: FontWeight.w600)),
);

/// 가로로 훑는 색 고르기 줄.
class _ColorRail extends StatelessWidget {
  const _ColorRail({
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;

  /// 견본 한 칸의 지름 + 여백.
  static const height = 44.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final c = colors[i];
          final on = c.toARGB32() == selected.toARGB32();
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onPick(c);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: height - 6,
              height: height - 6,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: on ? AppColors.ink : AppColors.line,
                  width: on ? 2.4 : 1,
                ),
              ),
              child: on
                  ? Icon(Icons.check,
                  size: 15,
                  color:
                  ThemeData.estimateBrightnessForColor(c) ==
                      Brightness.dark
                      ? AppColors.stockLight
                      : AppColors.ink)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _RailTitle extends StatelessWidget {
  const _RailTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    child: Text(
      text,
      style: AppText.ui(
          size: 12, weight: FontWeight.w600, color: AppColors.inkSoft),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// 스티커
// ─────────────────────────────────────────────────────────────

class StickerChoice {
  const StickerChoice(this.content, this.color);

  final String content;
  final Color color;
}

/// 스티커 고르기. 직접 그린 것 16종 + 이모지 24종, 색은 16가지.
Future<StickerChoice?> pickSticker(BuildContext context,
    {Color initial = AppColors.oxblood}) {
  return showModalBottomSheet<StickerChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StickerSheet(initial: initial),
  );
}

class _StickerSheet extends StatefulWidget {
  const _StickerSheet({required this.initial});

  final Color initial;

  @override
  State<_StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<_StickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late Color _color = widget.initial;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.72,
      child: _SheetShell(
        eyebrow: 'STICKER',
        child: Column(
          children: [
            _ColorRail(
              colors: ScrapPalette.inks,
              selected: _color,
              onPick: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 6),
            TabBar(
              controller: _tabs,
              indicatorColor: AppColors.oxblood,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppColors.ink,
              unselectedLabelColor: AppColors.inkSoft,
              labelStyle: AppText.eyebrow(),
              tabs: const [Tab(text: 'DRAWN'), Tab(text: 'EMOJI')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [_drawn(), _emoji()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile({required Widget child, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.stock,
            border: Border.all(color: AppColors.line),
          ),
          child: child,
        ),
      );

  Widget _drawn() => GridView.builder(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    ),
    itemCount: StickerArt.values.length,
    itemBuilder: (context, i) {
      final art = StickerArt.values[i];
      return _tile(
        onTap: () =>
            Navigator.pop(context, StickerChoice(art.content, _color)),
        child: StickerPreview(art: art, color: _color, size: 34),
      );
    },
  );

  Widget _emoji() => GridView.builder(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 5,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
    ),
    itemCount: ScrapPalette.emoji.length,
    itemBuilder: (context, i) {
      final g = ScrapPalette.emoji[i];
      return _tile(
        onTap: () => Navigator.pop(context, StickerChoice(g, _color)),
        child: Text(g, style: const TextStyle(fontSize: 26)),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────
// 글자
// ─────────────────────────────────────────────────────────────

class TextChoice {
  const TextChoice(this.text, this.font, this.color, this.size);

  final String text;
  final FolderFont font;
  final Color color;
  final double size;
}

/// 글자 넣기 / 고치기. 서체 6종 · 색 16가지 · 크기를 그 자리에서 봅니다.
///
/// 예전에는 회색 `AlertDialog` 하나에 입력칸만 있었는데,
/// 무엇이 어떻게 찍히는지 넣어보기 전엔 알 수 없었습니다.
/// 이제 위쪽에 **실제로 찍힐 모습이 그대로** 떠 있습니다.
Future<TextChoice?> editScrapText(
    BuildContext context, {
      String initial = '',
      FolderFont font = FolderFont.hand,
      Color color = AppColors.oxblood,
      double size = 22,
    }) {
  return showModalBottomSheet<TextChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TextSheet(
      initial: initial,
      font: font,
      color: color,
      size: size,
    ),
  );
}

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.initial,
    required this.font,
    required this.color,
    required this.size,
  });

  final String initial;
  final FolderFont font;
  final Color color;
  final double size;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  late FolderFont _font = widget.font;
  late Color _color = widget.color;
  late double _size = widget.size;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _done() {
    final t = _controller.text.trim();
    if (t.isEmpty) {
      Navigator.pop(context);
      return;
    }
    Navigator.pop(context, TextChoice(t, _font, _color, _size));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _controller.text.trim();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.76,
      child: _SheetShell(
        eyebrow: 'LETTERING',
        preview: Container(
          height: 96,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.stock,
            border: Border.all(color: AppColors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              preview.isEmpty ? '여기에 적힙니다' : preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: _font.style(
                size: _size,
                color: preview.isEmpty ? AppColors.pulp : _color,
              ),
            ),
          ),
        ),
        action: _primaryButton(widget.initial.isEmpty ? '붙이기' : '고치기', _done),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _controller,
                autofocus: widget.initial.isEmpty,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: AppText.ui(size: 15, color: AppColors.ink),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '한 줄이든 두 줄이든',
                  hintStyle: AppText.ui(size: 14, color: AppColors.pulp),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.line),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.foil, width: 1.4),
                  ),
                ),
              ),
            ),
            const _RailTitle('서체'),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: FolderFont.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 9),
                itemBuilder: (context, i) {
                  final f = FolderFont.values[i];
                  final on = f == _font;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _font = f);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: on ? AppColors.ink : AppColors.stock,
                        border: Border.all(
                            color: on ? AppColors.ink : AppColors.line),
                      ),
                      child: Text(
                        f.label,
                        maxLines: 1,
                        style: f.style(
                          size: 12,
                          color: on ? AppColors.stockLight : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const _RailTitle('색'),
            _ColorRail(
              colors: ScrapPalette.inks,
              selected: _color,
              onPick: (c) => setState(() => _color = c),
            ),
            const _RailTitle('크기'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.foil,
                  inactiveTrackColor: AppColors.line,
                  thumbColor: AppColors.ink,
                  overlayColor: AppColors.foil.withValues(alpha: 0.12),
                  trackHeight: 2,
                ),
                child: Slider(
                  value: _size,
                  min: 12,
                  max: 44,
                  divisions: 16,
                  label: _size.round().toString(),
                  onChanged: (v) => setState(() => _size = v),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 테이프
// ─────────────────────────────────────────────────────────────

class TapeChoice {
  const TapeChoice(this.pattern, this.color);

  final TapePattern pattern;
  final Color color;
}

/// 테이프 고르기. 무늬 6종 · 색 12가지.
Future<TapeChoice?> pickTape(
    BuildContext context, {
      TapePattern pattern = TapePattern.plain,
      Color color = const Color(0x998C7134),
    }) {
  return showModalBottomSheet<TapeChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TapeSheet(pattern: pattern, color: color),
  );
}

class _TapeSheet extends StatefulWidget {
  const _TapeSheet({required this.pattern, required this.color});

  final TapePattern pattern;
  final Color color;

  @override
  State<_TapeSheet> createState() => _TapeSheetState();
}

class _TapeSheetState extends State<_TapeSheet> {
  late TapePattern _pattern = widget.pattern;
  late Color _color = widget.color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.62,
      child: _SheetShell(
        eyebrow: 'MASKING TAPE',
        preview: Container(
          height: 78,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.stock,
            border: Border.all(color: AppColors.line),
          ),
          child: Transform.rotate(
            angle: -0.06,
            child: TapeStrip(
              color: _color,
              pattern: _pattern,
              width: 190,
              height: 32,
            ),
          ),
        ),
        action: _primaryButton(
          '붙이기',
              () => Navigator.pop(context, TapeChoice(_pattern, _color)),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _RailTitle('무늬'),
            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: TapePattern.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = TapePattern.values[i];
                  final on = p == _pattern;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _pattern = p);
                    },
                    child: SizedBox(
                      width: 84,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(on ? 2 : 0),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: on ? AppColors.ink : Colors.transparent,
                                width: 1.4,
                              ),
                            ),
                            child: TapeStrip(
                              color: _color,
                              pattern: p,
                              width: 76,
                              height: 26,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            p.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              size: 10,
                              weight: on ? FontWeight.w600 : FontWeight.w400,
                              color: on ? AppColors.ink : AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const _RailTitle('색'),
            _ColorRail(
              colors: ScrapPalette.tapes,
              selected: _color,
              onPick: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 도장
// ─────────────────────────────────────────────────────────────

class StampChoice {
  const StampChoice(this.spec, this.color, this.size);

  final StampSpec spec;
  final Color color;

  /// 짧은 변 지름. `ScrapLayer.fontSize`에 담깁니다.
  final double size;
}

/// 도장 고르기 / 고치기.
///
/// 미리 만든 문구를 고르고 끝낼 수도 있고, 글자를 직접 파 넣을 수도 있습니다.
/// 위쪽 미리보기는 **실제로 찍힐 모습 그대로**입니다(잉크 벗겨진 자국 포함).
Future<StampChoice?> pickStamp(
    BuildContext context, {
      StampSpec? initial,
      Color color = const Color(0xE6A5321F),
      double size = 92,
    }) {
  return showModalBottomSheet<StampChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StampSheet(initial: initial, color: color, size: size),
  );
}

class _StampSheet extends StatefulWidget {
  const _StampSheet({
    required this.initial,
    required this.color,
    required this.size,
  });

  final StampSpec? initial;
  final Color color;
  final double size;

  @override
  State<_StampSheet> createState() => _StampSheetState();
}

class _StampSheetState extends State<_StampSheet> {
  late StampSpec _spec = widget.initial ?? StampSpec.presets(DateTime.now()).first;
  late Color _color = widget.color;
  late double _size = widget.size;

  /// 직접 파 넣기 칸을 펼쳤는지.
  bool _carving = false;

  late final _center = TextEditingController(text: _spec.center);
  late final _top = TextEditingController(text: _spec.top);
  late final _bottom = TextEditingController(text: _spec.bottom);

  @override
  void initState() {
    super.initState();
    for (final c in [_center, _top, _bottom]) {
      c.addListener(_sync);
    }
  }

  void _sync() => setState(() {
    _spec = _spec.copyWith(
      center: _center.text,
      top: _top.text,
      bottom: _bottom.text,
    );
  });

  @override
  void dispose() {
    for (final c in [_center, _top, _bottom]) {
      c.dispose();
    }
    super.dispose();
  }

  void _usePreset(StampSpec p) {
    HapticFeedback.selectionClick();
    setState(() {
      _spec = p;
      _center.text = p.center;
      _top.text = p.top;
      _bottom.text = p.bottom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final presets = StampSpec.presets(DateTime.now());

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: _SheetShell(
        eyebrow: 'RUBBER STAMP',
        preview: Container(
          height: 132,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.stock,
            border: Border.all(color: AppColors.line),
          ),
          child: Transform.rotate(
            // 도장은 반듯하게 찍히는 법이 없습니다.
            angle: -0.09,
            child: StampMark(spec: _spec, color: _color, size: 100, seed: 7),
          ),
        ),
        action: _primaryButton(
          widget.initial == null ? '찍기' : '고치기',
              () {
            if (_spec.center.trim().isEmpty &&
                _spec.top.trim().isEmpty &&
                _spec.bottom.trim().isEmpty) {
              Navigator.pop(context);
              return;
            }
            Navigator.pop(context, StampChoice(_spec, _color, _size));
          },
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _RailTitle('문구'),
            SizedBox(
              height: 86,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final p = presets[i];
                  final on = p.encode() == _spec.encode();
                  return GestureDetector(
                    onTap: () => _usePreset(p),
                    child: Container(
                      width: 96,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.stock,
                        border: Border.all(
                          color: on ? AppColors.ink : AppColors.line,
                          width: on ? 1.6 : 1,
                        ),
                      ),
                      // 미리보기 타일에서는 잉크 자국을 끕니다.
                      // 작게 줄이면 자국이 때처럼 보입니다.
                      child: FittedBox(
                        child: StampMark(
                          spec: p,
                          color: _color,
                          size: 62,
                          worn: false,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const _RailTitle('테두리'),
            SizedBox(
              height: 74,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: StampShape.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final shape = StampShape.values[i];
                  final on = shape == _spec.shape;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _spec = _spec.copyWith(shape: shape));
                    },
                    child: SizedBox(
                      width: 74,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 46,
                            width: 74,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: on ? AppColors.ink : AppColors.line,
                                width: on ? 1.6 : 1,
                              ),
                            ),
                            child: FittedBox(
                              child: StampMark(
                                spec: StampSpec(
                                    shape: shape, top: '', center: '', bottom: ''),
                                color: AppColors.ink,
                                size: 34,
                                worn: false,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            shape.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              size: 10,
                              weight: on ? FontWeight.w600 : FontWeight.w400,
                              color: on ? AppColors.ink : AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── 직접 파 넣기 ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(
                children: [
                  Text('글자 직접 넣기',
                      style: AppText.ui(
                          size: 12,
                          weight: FontWeight.w600,
                          color: AppColors.inkSoft)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _carving = !_carving),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.oxblood,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(_carving ? '접기' : '펼치기',
                        style: AppText.ui(size: 12, weight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            if (_carving)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
                child: Column(
                  children: [
                    _field(_center, '가운데', '관람 완료'),
                    _field(_top, _spec.shape.curved ? '위 (둥글게)' : '위', 'ARTICKET'),
                    _field(_bottom, _spec.shape.curved ? '아래 (둥글게)' : '아래',
                        '2026.07.14'),
                  ],
                ),
              ),

            const _RailTitle('잉크'),
            _ColorRail(
              colors: ScrapPalette.stampInks,
              selected: _color,
              onPick: (c) => setState(() => _color = c),
            ),

            const _RailTitle('크기'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.foil,
                  inactiveTrackColor: AppColors.line,
                  thumbColor: AppColors.ink,
                  overlayColor: AppColors.foil.withValues(alpha: 0.12),
                  trackHeight: 2,
                ),
                child: Slider(
                  value: _size,
                  min: 48,
                  max: 150,
                  divisions: 17,
                  label: _size.round().toString(),
                  onChanged: (v) => setState(() => _size = v),
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 78,
          child: Text(label,
              style: AppText.ui(size: 11, color: AppColors.pulp)),
        ),
        Expanded(
          child: TextField(
            controller: c,
            maxLines: 1,
            style: AppText.ui(size: 14, color: AppColors.ink),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: AppText.ui(size: 13, color: AppColors.pulp),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.line),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.foil, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// 폴라로이드 — 어디서 가져올지 먼저 묻기
// ─────────────────────────────────────────────────────────────

/// 폴라로이드에 넣을 사진을 **어디서** 가져올지.
enum PhotoSource {
  gallery('갤러리에서 고르기', '앨범을 엽니다', Icons.photo_library_outlined),
  camera('지금 찍기', '카메라를 엽니다', Icons.photo_camera_outlined),
  blank('비워 두기', '색만 채운 채 붙이고, 나중에 사진을 넣습니다',
      Icons.crop_original_outlined);

  const PhotoSource(this.label, this.detail, this.icon);

  final String label;
  final String detail;
  final IconData icon;
}

/// 폴라로이드 출처 고르기.
///
/// ## 왜 한 단계를 더 뒀나
///
/// 예전에는 툴바의 '폴라로이드'를 누르는 즉시 시스템 갤러리가 떴습니다.
/// 그래서 **툴바를 훑어보기만 해도** 앨범 권한창과 로딩이 튀어나왔고,
/// 되돌아오려면 시스템 화면을 닫아야 했습니다. 도구를 구경하는 것과
/// 사진을 고르겠다고 결정하는 건 다른 일입니다.
///
/// 이 시트는 얇고 즉시 뜨며, 아래로 쓸어내리면 아무 일도 없이 닫힙니다.
Future<PhotoSource?> pickPhotoSource(BuildContext context) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SheetShell(
      eyebrow: 'POLAROID',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in PhotoSource.values)
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, s);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                child: Row(
                  children: [
                    Icon(s.icon, size: 21, color: AppColors.foil),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.label,
                              style: AppText.ui(
                                  size: 14,
                                  weight: FontWeight.w600,
                                  color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text(s.detail,
                              style: AppText.ui(
                                  size: 11.5, color: AppColors.inkSoft)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.pulp),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}