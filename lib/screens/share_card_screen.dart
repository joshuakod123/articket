import 'package:flutter/material.dart';

import '../services/share_card.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import '../widgets/scrapbook.dart' show WashiTape;

/// 공유 카드 배경. 종이 세 종류만 고르게 합니다.
enum ShareStock {
  cream('미색', AppColors.stockLight, AppColors.ink),
  kraft('크라프트', Color(0xFFC9B18B), Color(0xFF33261A)),
  ink('먹지', Color(0xFF241F1A), AppColors.stockLight);

  const ShareStock(this.label, this.paper, this.text);

  final String label;
  final Color paper;
  final Color text;
}

/// SNS로 내보낼 9:16 카드를 만드는 화면.
///
/// 스크린샷을 그냥 올리면 앱 UI(앱바·탭바·상태바)까지 같이 나갑니다.
/// 여기서는 **작품만 종이 위에 다시 앉혀서** 스토리 비율로 짭니다.
/// 위에 로고, 아래에 제목과 날짜, 모서리에 마스킹 테이프 한 조각.
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
                padding: const EdgeInsets.all(20),
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
            busy: _busy,
            onStock: (s) => setState(() => _stock = s),
            onShare: _share,
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.stock,
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.meta,
  });

  final ShareStock stock;
  final Widget artwork;
  final String title;
  final String subtitle;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final onPaper = stock.text;
    final faint = onPaper.withValues(alpha: 0.55);

    return PaperSurface(
      color: stock.paper,
      grain: 0.07,
      fiber: 0.8,
      seed: title.hashCode,
      child: Stack(
        children: [
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('ARTICKET',
                        style:
                        AppText.wordmark(size: 13, color: onPaper, spacing: 5)),
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
        ],
      ),
    );
  }
}

class _Bottom extends StatelessWidget {
  const _Bottom({
    required this.stock,
    required this.busy,
    required this.onStock,
    required this.onShare,
  });

  final ShareStock stock;
  final bool busy;
  final ValueChanged<ShareStock> onStock;
  final VoidCallback onShare;

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
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final s in ShareStock.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                      child: GestureDetector(
                        onTap: () => onStock(s),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: s.paper,
                                border: Border.all(
                                  color: s == stock
                                      ? AppColors.ink
                                      : AppColors.line,
                                  width: s == stock ? 2 : 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(s.label,
                                style: AppText.ui(
                                    size: 10,
                                    color: s == stock
                                        ? AppColors.ink
                                        : AppColors.inkSoft)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : onShare,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.oxblood,
                    foregroundColor: AppColors.stockLight,
                    shape: const RoundedRectangleBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: busy
                      ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.stockLight),
                  )
                      : const Icon(Icons.ios_share, size: 17),
                  label: Text(busy ? '만드는 중' : '내보내기',
                      style:
                      AppText.ui(size: 14, weight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}