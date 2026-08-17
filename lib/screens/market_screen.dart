import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';

/// C2C 크리에이터 마켓 (Phase 3).
/// 지금은 화면 구조와 카드 레이아웃만 잡아둔 상태입니다.
class MarketScreen extends StatelessWidget {
  const MarketScreen({super.key});

  static const _packs = [
    _Pack('빈티지 뮤지엄', '프레임 6종 · 스티커 24개', '₩2,500', Color(0xFF6E1F1B), '@paperjam'),
    _Pack('오로라 홀로그램', '홀로 텍스처 4종', '₩1,800', Color(0xFF3B2E5A), '@nn_studio'),
    _Pack('미니멀 갤러리', '프레임 8종', '₩1,200', Color(0xFF3F4A3C), '@grid_daily'),
    _Pack('플로피 디스크', '스킨 12종 · 레트로', '₩2,000', Color(0xFF2E3B4E), '@floppy'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MARKET')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('크리에이터\n템플릿',
                      style:
                      AppText.display(size: 34, color: AppColors.stock)),
                  const SizedBox(height: 10),
                  Text('유저가 직접 만들어 올린 프레임과 스티커 팩',
                      style:
                      AppText.ui(size: 13, color: AppColors.inkSoft)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 0.74,
              ),
              delegate: SliverChildBuilderDelegate(
                    (context, i) => _PackCard(pack: _packs[i]),
                childCount: _packs.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pack {
  const _Pack(this.name, this.detail, this.price, this.tint, this.creator);
  final String name;
  final String detail;
  final String price;
  final Color tint;
  final String creator;
}

class _PackCard extends StatelessWidget {
  const _PackCard({required this.pack});
  final _Pack pack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: PaperSurface(
              color: pack.tint,
              grain: 0.08,
              seed: pack.name.hashCode,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(pack.creator,
                        style: AppText.data(
                            size: 9,
                            color: AppColors.stock.withValues(alpha: .7))),
                    Text(pack.name,
                        style: AppText.display(
                            size: 20, color: AppColors.stockLight)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(pack.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(size: 11, color: AppColors.inkSoft)),
        const SizedBox(height: 4),
        Text(pack.price,
            style: AppText.data(size: 11, color: AppColors.foil)),
      ],
    );
  }
}