import 'package:material_ui/material_ui.dart';
import '../data/ticket_store.dart';
import '../data/ticket_query.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ticket_canvas.dart';
import 'settings_screen.dart';
import 'ticket_detail_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(
      listenable: Listenable.merge([
        TicketStore.instance,
        AuthService.instance,
      ]),
      builder: (context, _) {
        final store = TicketStore.instance;
        final viewer = AuthService.instance.viewer;
        final tickets = queryTickets(store.tickets);
        final genres = <String, int>{};
        for (final t in tickets) {
          genres[t.genre] = (genres[t.genre] ?? 0) + 1;
        }
        final top = genres.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                const ArticketLogo(height: 23),
                const Spacer(),
                IconButton(
                  tooltip: '설정',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const SettingsScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text('나의 기록', style: AppText.display(size: 27)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.lavender,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person_outline, color: AppColors.ink),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viewer?.name ?? '나의 관람',
                              style: AppText.display(size: 21),
                            ),
                            Text(
                              'ARTICKET MEMBER',
                              style: AppText.data(size: 9),
                            ),
                            Text(
                              viewer?.memberSerialText ?? 'M-0000-0000',
                              style: AppText.data(size: 10),
                            ),
                          ],
                        ),
                      ),
                      const ArticketLogo(height: 32, symbolOnly: true),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      stat('티켓', tickets.length),
                      stat('서류철', store.folders.length),
                      stat(
                        '방문한 곳',
                        tickets
                            .map((t) => t.venue.trim())
                            .where((v) => v.isNotEmpty)
                            .toSet()
                            .length,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              '최근에 모은 티켓',
              style: AppText.ui(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 15),
            if (tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('첫 기록이 쌓이면 여기에 모아드릴게요'),
              ),
            if (tickets.isNotEmpty)
              SizedBox(
                height: 165,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tickets.take(6).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => SizedBox(
                    width: 95,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              TicketDetailScreen(ticketId: tickets[i].id),
                        ),
                      ),
                      child: TicketCanvas(ticket: tickets[i], compact: true),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 30),
            Text(
              '장르별 관람 기록',
              style: AppText.ui(size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            for (final e in top)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    SizedBox(width: 80, child: Text(e.key)),
                    Expanded(
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(10),
                        value: e.value / tickets.length,
                        backgroundColor: AppColors.bgDeep,
                        color: top.indexOf(e).isEven
                            ? const Color(0xFFC4AFE1)
                            : AppColors.butter,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text('${e.value}회'),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
  Widget stat(String label, int value) => Expanded(
    child: Column(
      children: [
        Text(label, style: AppText.ui(size: 11)),
        const SizedBox(height: 4),
        Text('$value', style: AppText.ui(size: 26, weight: FontWeight.w700)),
      ],
    ),
  );
}
