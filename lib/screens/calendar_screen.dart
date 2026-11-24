import 'package:flutter/material.dart';
import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/brand_logo.dart';
import '../widgets/ticket_canvas.dart';
import 'ticket_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final store = TicketStore.instance;
  late DateTime _month;
  int? _day;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final tickets = store.tickets;
    final initial =
        tickets.any(
              (t) =>
                  t.visitedAt.year == now.year &&
                  t.visitedAt.month == now.month,
            ) ||
            tickets.isEmpty
        ? now
        : tickets
              .map((t) => t.visitedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    _month = DateTime(initial.year, initial.month);
  }

  void shift(int by) => setState(() {
    _month = DateTime(_month.year, _month.month + by);
    _day = null;
  });
  void open(Ticket t) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => TicketDetailScreen(ticketId: t.id)),
  );
  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final tickets =
            store.tickets
                .where(
                  (t) =>
                      t.visitedAt.year == _month.year &&
                      t.visitedAt.month == _month.month,
                )
                .toList()
              ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));
        final byDay = <int, List<Ticket>>{};
        for (final t in tickets) {
          byDay.putIfAbsent(t.visitedAt.day, () => []).add(t);
        }
        final lead = DateTime(_month.year, _month.month, 1).weekday % 7;
        final days = DateTime(_month.year, _month.month + 1, 0).day;
        final visible = _day == null ? tickets : byDay[_day] ?? <Ticket>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: ArticketLogo(height: 23),
            ),
            const SizedBox(height: 24),
            Text('관람 달력', style: AppText.display(size: 27)),
            const SizedBox(height: 22),
            Row(
              children: [
                IconButton(
                  tooltip: '이전 달',
                  onPressed: () => shift(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_month.year}년 ${_month.month}월',
                      style: AppText.ui(size: 18, weight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '다음 달',
                  onPressed: () => shift(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: ['일', '월', '화', '수', '목', '금', '토']
                  .asMap()
                  .entries
                  .map(
                    (e) => Expanded(
                      child: Center(
                        child: Text(
                          e.value,
                          style: AppText.ui(
                            size: 12,
                            color: e.key == 0
                                ? AppColors.accentDark
                                : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ((lead + days + 6) ~/ 7) * 7,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: .70,
              ),
              itemBuilder: (context, i) {
                final day = i - lead + 1;
                if (day < 1 || day > days) {
                  return const SizedBox.shrink();
                }
                final ts = byDay[day] ?? <Ticket>[];
                return InkWell(
                  onTap: () => setState(() => _day = _day == day ? null : day),
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _day == day
                              ? AppColors.accent
                              : Colors.transparent,
                        ),
                        child: Text(
                          '$day',
                          style: AppText.ui(
                            size: 12,
                            color: _day == day ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                      if (ts.isNotEmpty)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: TicketCanvas(
                              ticket: ts.first,
                              compact: true,
                            ),
                          ),
                        ),
                      if (ts.length > 1)
                        Text('+${ts.length - 1}', style: AppText.ui(size: 8)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _day == null ? '이 달에는 아직 기록이 없어요' : '이 날에는 기록이 없어요',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final t in visible)
              Card(
                color: AppColors.butter,
                elevation: 0,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: SizedBox(
                    width: 42,
                    height: 70,
                    child: TicketCanvas(ticket: t, compact: true),
                  ),
                  title: Text(t.title),
                  subtitle: Text('${t.venue}\n${t.dateLabel}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(t),
                ),
              ),
          ],
        );
      },
    ),
  );
}
