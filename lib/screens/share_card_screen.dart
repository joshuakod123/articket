import 'package:flutter/material.dart';

import '../services/share_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';
import '../widgets/folder_texture.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import '../widgets/scrapbook.dart' show WashiTape;

/// 공유 카드 용지.
///
/// 종이 세 장만 고르게 하니 "내보내기 화면"이 아니라 "포맷 선택창"처럼 보였습니다.
/// 전시 도록에서 실제로 쓰는 지질을 여덟 장으로 늘리고, 글자색은 종이마다
/// 대비가 확실한 값으로 미리 짝지어 둡니다. (사용자가 고를 일이 없게)
enum ShareStock {
  cream('미색', Color(0xFFFCF8EE), Color(0xFF251E15)),
  sand('모래', Color(0xFFE0CFA8), Color(0xFF3A2E1E)),
  kraft('크라프트', Color(0xFFC9B18B), Color(0xFF33261A)),
  blush('장미', Color(0xFFD9C0B6), Color(0xFF4A2A24)),
  olive('올리브', Color(0xFF44503F), Color(0xFFEDE7D6)),
  navy('네이비', Color(0xFF2F3D4C), Color(0xFFE4ECF2)),
  oxblood('옥스블러드', Color(0xFF6B1F1A), Color(0xFFF3E7D8)),
  ink('먹지', Color(0xFF241F1A), Color(0xFFF6F0E2));

  const ShareStock(this.label, this.paper, this.text);

  final String label;
  final Color paper;
  final Color text;

  bool get isDark =>
      this == ShareStock.olive ||
          this == ShareStock.navy ||
          this == ShareStock.oxblood ||
          this == ShareStock.ink;
}

/// 카드 위에 얹는 소품 하나.
enum ShareTrim {
  none('없음'),
  tape('테이프'),
  stamp('도장'),
  corner('사진 모서리');

  const ShareTrim(this.label);

  final String label;
}

/// 결. 서류철에 쓰던 질감 페인터를 그대로 빌려 씁니다.
/// `null`은 무늬 없는 매끈한 종이입니다.
const _grains = <(FolderTexture?, String)>[
  (null, '민무늬'),
  (FolderTexture.kraft, '크라프트'),
  (FolderTexture.linen, '리넨'),
  (FolderTexture.leather, '가죽'),
  (FolderTexture.marble, '마블'),
  (FolderTexture.pressboard, '판지'),
];

/// SNS로 내보낼 9:16 카드를 만드는 화면.
///
/// 스크린샷을 그냥 올리면 앱 UI(앱바·탭바·상태바)까지 같이 나갑니다.
/// 여기서는 **작품만 종이 위에 다시 앉혀서** 스토리 비율로 짭니다.
class ShareCardScreen extends StatefulWidget {
  const ShareCardScreen({
    super.key,
    required this.artwork,
    required this.title,
    required this.subtitle,
    this.meta = '',
    this.fileName = 'articket',
    this.shareText,
  });

  /// 카드 가운데 올라갈 것. 티켓 한 장이든 스크랩북 페이지든 상관없습니다.
  final Widget artwork;

  final String title;
  final String subtitle;

  /// 오른쪽 아래 작은 글씨. 별점이나 장소 등.
  final String meta;

  final String fileName;
  final String? shareText;

  @override
  State<ShareCardScreen> createState() => _ShareCardScreenState();
}

class _ShareCardScreenState extends State<ShareCardScreen> {
  final _boundary = GlobalKey();

  ShareStock _stock = ShareStock.cream;
  FolderTexture? _grain = FolderTexture.kraft;
  ShareTrim _trim = ShareTrim.tape;

  /// 0 = 종이, 1 = 결, 2 = 소품.
  int _tab = 0;

  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      await ShareCard.shareBoundary(
        _boundary,
        name: widget.fileName,
        text: widget.shareText,
      );
    } catch (e) {
      if (mounted) PaperToast.warn(context, '공유하지 못했습니다', detail: '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('SHARE',
            style: AppText.eyebrow(size: 12, color: AppColors.ink)),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: DecoratedBox(
                    decoration:
                    BoxDecoration(boxShadow: paperShadow(depth: 1.1)),
                    // 이 경계 안쪽만 이미지로 떠집니다.
                    child: RepaintBoundary(
                      key: _boundary,
                      child: _Card(
                        stock: _stock,
                        grain: _grain,
                        trim: _trim,
                        artwork: widget.artwork,
                        title: widget.title,
                        subtitle: widget.subtitle,
                        meta: widget.meta,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Bottom(
            stock: _stock,
            grain: _grain,
            trim: _trim,
            tab: _tab,
            busy: _busy,
            onTab: (i) => setState(() => _tab = i),
            onStock: (s) => setState(() => _stock = s),
            onGrain: (g) => setState(() => _grain = g),
            onTrim: (t) => setState(() => _trim = t),
            onShare: _share,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 카드
// ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({
    required this.stock,
    required this.grain,
    required this.trim,
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  final ShareStock stock;
  final FolderTexture? grain;
  final ShareTrim trim;
  final Widget artwork;
  final String title;
  final String subtitle;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final onPaper = stock.text;
    final faint = onPaper.withValues(alpha: 0.55);
    final seed = title.hashCode;

    final content = Stack(
      children: [
        // 소품 한 조각.
        if (trim == ShareTrim.tape)
          Positioned(
            right: -18,
            top: 34,
            child: WashiTape(
              width: 96,
              height: 24,
              color: onPaper.withValues(alpha: 0.16),
              angle: -0.5,
            ),
          ),
        if (trim == ShareTrim.corner)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PhotoCornerPainter(
                  color: onPaper.withValues(alpha: 0.30),
                ),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('ARTICKET',
                      style: AppText.wordmark(
                          size: 13, color: onPaper, spacing: 5)),
                  const Spacer(),
                  Text('TICKET DIARY',
                      style: AppText.eyebrow(size: 8, color: faint)),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: faint.withValues(alpha: 0.35)),

              // 작품.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: artwork),
                ),
              ),

              Container(height: 1, color: faint.withValues(alpha: 0.35)),
              const SizedBox(height: 14),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(size: 21, color: onPaper),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 11.5, color: faint),
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Text(meta,
                        maxLines: 1,
                        style: AppText.data(size: 10, color: faint)),
                  ],
                ],
              ),
            ],
          ),
        ),

        // 도장은 글자 위에 찍혀야 도장처럼 보입니다. 그래서 맨 위.
        if (trim == ShareTrim.stamp)
          Positioned(
            right: 20,
            bottom: 96,
            child: _RubberStamp(color: onPaper.withValues(alpha: 0.42)),
          ),
      ],
    );

    if (grain == null) {
      return PaperSurface(
        color: stock.paper,
        grain: 0.07,
        fiber: 0.8,
        seed: seed,
        child: content,
      );
    }

    return FolderSurface(
      color: stock.paper,
      texture: grain!,
      seed: seed,
      wear: 0.55,
      child: content,
    );
  }
}

/// 네 모서리에 끼운 사진 모서리(포토 코너).
class _PhotoCornerPainter extends CustomPainter {
  _PhotoCornerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const s = 26.0;
    final p = Paint()..color = color;

    void corner(List<Offset> pts) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path..close(), p);
    }

    corner([
      const Offset(0, 0),
      const Offset(s, 0),
      const Offset(0, s),
    ]);
    corner([
      Offset(size.width, 0),
      Offset(size.width - s, 0),
      Offset(size.width, s),
    ]);
    corner([
      Offset(0, size.height),
      Offset(s, size.height),
      Offset(0, size.height - s),
    ]);
    corner([
      Offset(size.width, size.height),
      Offset(size.width - s, size.height),
      Offset(size.width, size.height - s),
    ]);
  }

  @override
  bool shouldRepaint(_PhotoCornerPainter old) => old.color != color;
}

/// 관람 확인 고무 도장.
class _RubberStamp extends StatelessWidget {
  const _RubberStamp({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = '${now.year}.'
        '${now.month.toString().padLeft(2, '0')}.'
        '${now.day.toString().padLeft(2, '0')}';

    return IgnorePointer(
      child: Transform.rotate(
        angle: -0.14,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 1.6),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 0.8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('VISITED',
                    style: AppText.eyebrow(size: 8, color: color)),
                const SizedBox(height: 3),
                Text(date,
                    style: AppText.data(
                        size: 9, spacing: 1.2, color: color)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────
// 아래 조작판
// ─────────────────────────────────────────────────────

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.stock,
    required this.grain,
    required this.trim,
    required this.tab,
    required this.busy,
    required this.onTab,
    required this.onStock,
    required this.onGrain,
    required this.onTrim,
    required this.onShare,
  });

  final ShareStock stock;
  final FolderTexture? grain;
  final ShareTrim trim;
  final int tab;
  final bool busy;

  final ValueChanged<int> onTab;
  final ValueChanged<ShareStock> onStock;
  final ValueChanged<FolderTexture?> onGrain;
  final ValueChanged<ShareTrim> onTrim;
  final VoidCallback onShare;

  static const _tabs = ['종이', '결', '소품'];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 서랍 손잡이 같은 세 칸 전환.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (var i = 0; i < _tabs.length; i++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onTab(i),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: i == tab
                                      ? AppColors.oxblood
                                      : AppColors.line,
                                  width: i == tab ? 1.8 : 1,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _tabs[i],
                                style: AppText.ui(
                                  size: 12,
                                  height: 1.0,
                                  weight: i == tab
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: i == tab
                                      ? AppColors.oxblood
                                      : AppColors.inkSoft,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(
                height: 78,
                child: switch (tab) {
                  0 => _StockRow(stock: stock, onPick: onStock),
                  1 => _GrainRow(
                    stock: stock,
                    grain: grain,
                    onPick: onGrain,
                  ),
                  _ => _TrimRow(trim: trim, onPick: onTrim),
                },
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : onShare,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.oxblood,
                      foregroundColor: AppColors.stockLight,
                      shape: const RoundedRectangleBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: busy
                        ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.stockLight),
                    )
                        : const Icon(Icons.ios_share, size: 17),
                    label: Text(busy ? '만드는 중' : '내보내기',
                        style: AppText.ui(size: 14, weight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 고른 항목 아래에 찍히는 작은 이름표.
class _SwatchLabel extends StatelessWidget {
  const _SwatchLabel(this.text, {required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: AppText.ui(
          size: 9.5,
          height: 1.0,
          weight: active ? FontWeight.w600 : FontWeight.w400,
          color: active ? AppColors.ink : AppColors.inkSoft,
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({required this.stock, required this.onPick});

  final ShareStock stock;
  final ValueChanged<ShareStock> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        for (final s in ShareStock.values)
          GestureDetector(
            onTap: () => onPick(s),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: s.paper,
                      border: Border.all(
                        color: s == stock ? AppColors.ink : AppColors.line,
                        width: s == stock ? 2 : 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SwatchLabel(s.label, active: s == stock),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GrainRow extends StatelessWidget {
  const _GrainRow({
    required this.stock,
    required this.grain,
    required this.onPick,
  });

  final ShareStock stock;
  final FolderTexture? grain;
  final ValueChanged<FolderTexture?> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        for (final g in _grains)
          GestureDetector(
            onTap: () => onPick(g.$1),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    foregroundDecoration: BoxDecoration(
                      border: Border.all(
                        color: g.$1 == grain ? AppColors.ink : AppColors.line,
                        width: g.$1 == grain ? 2 : 1,
                      ),
                    ),
                    // 지금 고른 종이색 위에 그 결을 실제로 찍어 보여줍니다.
                    child: g.$1 == null
                        ? ColoredBox(color: stock.paper)
                        : FolderSurface(
                      color: stock.paper,
                      texture: g.$1!,
                      seed: 4,
                      wear: 0.4,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _SwatchLabel(g.$2, active: g.$1 == grain),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TrimRow extends StatelessWidget {
  const _TrimRow({required this.trim, required this.onPick});

  final ShareTrim trim;
  final ValueChanged<ShareTrim> onPick;

  @override
  Widget build(BuildContext context) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      children: [
        for (final t in ShareTrim.values)
          GestureDetector(
            onTap: () => onPick(t),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: t == trim
                      ? AppColors.oxblood.withValues(alpha: 0.08)
                      : null,
                  border: Border.all(
                    color: t == trim ? AppColors.oxblood : AppColors.line,
                    width: t == trim ? 1.4 : 1,
                  ),
                ),
                child: Text(
                  t.label,
                  style: AppText.ui(
                    size: 12,
                    height: 1.0,
                    weight: t == trim ? FontWeight.w600 : FontWeight.w400,
                    color: t == trim ? AppColors.oxblood : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}