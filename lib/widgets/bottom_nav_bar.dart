import 'package:material_ui/material_ui.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class ArticketNavBar extends StatelessWidget {
  const ArticketNavBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;
  static const _labels = ['서랍', '달력', '내 기록'];
  static const _icons = [
    Icons.inventory_2_outlined,
    Icons.calendar_month_outlined,
    Icons.person_outline_rounded,
  ];
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.bg,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: Row(
          children: List.generate(
            3,
            (i) => Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _icons[i],
                        size: 25,
                        color: i == index ? AppColors.ink : AppColors.inkSoft,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _labels[i],
                        style: AppText.ui(
                          size: 11,
                          weight: i == index
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 26,
                        height: 3,
                        decoration: BoxDecoration(
                          color: i == index
                              ? AppColors.accent
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
