import 'package:flutter/material.dart';
import '../../services/guide_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../widgets/brand_logo.dart';
import '../../models/ticket.dart';
import '../../theme/ticket_design.dart';
import '../../widgets/home/recent_ticket_gallery.dart';

Future<void> showWelcomeTour(BuildContext context) => Navigator.push<void>(
  context,
  MaterialPageRoute(
    builder: (_) => WelcomeTour(onDone: () => Navigator.pop(context)),
  ),
);

class WelcomeTour extends StatelessWidget {
  const WelcomeTour({super.key, this.onDone});
  final VoidCallback? onDone;
  @override
  Widget build(BuildContext context) {
    // Explicitly identified sample designs, never saved as the user's memories.
    final samples = TicketDesign.selectable
        .asMap()
        .entries
        .map(
          (e) => Ticket(
            id: 'intro-${e.key}',
            folderId: 'intro',
            title: ['빛과 공간', '오후의 미술관', 'FORM'][e.key],
            venue: '디자인 미리보기',
            visitedAt: DateTime(2026, 11, 21),
            design: e.value,
            frame: e.key == 1 ? TicketFrame.stamp : TicketFrame.classic,
            posterTint: e.key == 2
                ? const [AppColors.blue, AppColors.butter]
                : const [Color(0xFFB8A7D4), Color(0xFFE3D78D)],
          ),
        )
        .toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            const Center(child: ArticketLogo(height: 62, vertical: true)),
            const SizedBox(height: 36),
            Text(
              '좋았던 순간을,\n나만의 티켓으로',
              textAlign: TextAlign.center,
              style: AppText.display(size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              '전시와 공연의 감동을 모으고, 꾸미고, 다시 꺼내보세요.',
              textAlign: TextAlign.center,
              style: AppText.ui(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 22),
            IgnorePointer(
              child: RecentTicketGallery(tickets: samples, onOpen: (_) {}),
            ),
            Text(
              '티켓 디자인 미리보기',
              textAlign: TextAlign.center,
              style: AppText.ui(size: 11, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () async {
                if (onDone != null) {
                  onDone!();
                } else {
                  await GuideService.instance.markIntroSeen();
                }
              },
              child: const Text('시작하기'),
            ),
          ],
        ),
      ),
    );
  }
}
