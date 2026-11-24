import 'package:material_ui/material_ui.dart';
import '../../data/ticket_query.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../brand_logo.dart';

class ArchiveHeader extends StatelessWidget {
  const ArchiveHeader({
    super.key,
    required this.count,
    required this.year,
    required this.years,
    required this.filter,
    required this.onYear,
    required this.onFilter,
    required this.onSearch,
  });
  final int count;
  final int? year;
  final List<int> years;
  final ArchiveFilter filter;
  final ValueChanged<int?> onYear;
  final ValueChanged<ArchiveFilter> onFilter;
  final VoidCallback onSearch;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const ArticketLogo(height: 23),
          const Spacer(),
          IconButton(
            tooltip: '기록 검색',
            onPressed: onSearch,
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('나의 관람 기록', style: AppText.display(size: 25)),
                const SizedBox(height: 4),
                Text(
                  '$count장의 티켓, $count개의 순간',
                  style: AppText.ui(color: AppColors.inkSoft, size: 13),
                ),
              ],
            ),
          ),
          PopupMenuButton<int>(
            tooltip: '연도 선택',
            onSelected: (v) => onYear(v == 0 ? null : v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 0, child: Text('전체 연도')),
              ...years.map((v) => PopupMenuItem(value: v, child: Text('$v년'))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    year?.toString() ?? '전체',
                    style: AppText.ui(weight: FontWeight.w600),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ArchiveFilter.values
              .map(
                (v) => Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    showCheckmark: false,
                    selected: filter == v,
                    onSelected: (_) => onFilter(v),
                    selectedColor: AppColors.ink,
                    backgroundColor: AppColors.bg,
                    side: BorderSide.none,
                    labelStyle: AppText.ui(
                      size: 13,
                      color: filter == v ? Colors.white : AppColors.ink,
                    ),
                    label: Text(switch (v) {
                      ArchiveFilter.all => '전체',
                      ArchiveFilter.exhibition => '전시',
                      ArchiveFilter.performance => '공연',
                      ArchiveFilter.favorites => '즐겨찾기',
                    }),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );
}
