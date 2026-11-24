import 'package:material_ui/material_ui.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class TicketStubButton extends StatelessWidget {
  const TicketStubButton({
    super.key,
    required this.onPressed,
    this.label = '티켓 만들기',
    this.code = 'NEW',
    this.width = 210,
    this.height = 52,
  });
  final VoidCallback onPressed;
  final String label, code;
  final double width, height;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 20),
      label: Text(label),
    ),
  );
}

class NewTicketRail extends StatelessWidget {
  const NewTicketRail({
    super.key,
    required this.onPressed,
    this.hint,
    this.code = 'NEW',
  });
  final VoidCallback onPressed;
  final String? hint;
  final String code;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.bg,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add),
                label: const Text('티켓 추가'),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 7),
              Text(
                hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(size: 10, color: AppColors.inkSoft),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
