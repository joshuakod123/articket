import 'package:flutter/material.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/ticket_canvas.dart';
import 'ticket_detail_screen.dart';

/// 관람 기록을 달로 펼친 화면.
///
/// 흔한 달력처럼 점이나 숫자를 찍는 대신, **그날 본 티켓을 그 칸에 그대로
/// 끼워 넣었습니다.** 한 달을 훑으면 어떤 색의 전시를 보고 다녔는지가
/// 글자 없이 먼저 보입니다.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final store = TicketStore.instance;

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

  void _shift(int by) {
    setState(() => _month = DateTime(_month.year, _month.month + by));
  }

  /// 그 달의 1일이 무슨 요일 칸에서 시작하는지. (일요일 = 0)
  int get _leading => DateTime(_month.year, _month.month, 1).weekday % 7;

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('CALENDAR',
            style: AppText.eyebrow(size: 12, color: AppColors.ink)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          // 그 달의 티켓을 날짜별로 묶습니다.
          final byDay = <int, List<Ticket>>{};
          for (final t in store.tickets) {
            if (t.visitedAt.year == _month.year &&
                t.visitedAt.month == _month.month) {
              byDay.putIfAbsent(t.visitedAt.day, () => []).add(t);
            }
          }

          final monthly = byDay.values.expand((e) => e).toList()
            ..sort((a, b) => a.visitedAt.compareTo(b.visitedAt));

          final cells = _leading + _daysInMonth;
          final rows = (cells / 7).ceil();

          return Stack(
            children: [
              const WallGrain(opacity: 0.05, seed: 61),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                children: [
                  _MonthBar(
                    month: _month,
                    count: monthly.length,
                    onPrev: () => _shift(-1),
                    onNext: () => _shift(1),
                    onToday: () => setState(() => _month = DateTime(
                        DateTime.now().year, DateTime.now().month)),
                  ),
                  const SizedBox(height: 14),

                  // 요일 머리.
                  Row(
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Center(
                            child: Text(
                              _weekdays[i],
                              style: AppText.data(
                                size: 10,
                                spacing: 0.4,
                                color: i == 0
                                    ? AppColors.oxblood
                                    : AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(height: 1, color: AppColors.line),
                  const SizedBox(height: 8),

                  // 날짜 칸.
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: rows * 7,
                    itemBuilder: (context, i) {
                      final day = i - _leading + 1;
                      if (day < 1 || day > _daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      return _DayCell(
                        day: day,
                        isSunday: i % 7 == 0,
                        tickets: byDay[day] ?? const [],
                        onTap: () => _openDay(byDay[day] ?? const []),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // 그 달의 목록.
                  Row(
                    children: [
                      Text('THIS MONTH',
                          style: AppText.eyebrow(color: AppColors.oxblood)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Container(height: 1, color: AppColors.line)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (monthly.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      child: Center(
                        child: Text('이 달엔 아직 기록이 없습니다',
                            style: AppText.ui(
                                size: 13, color: AppColors.inkSoft)),
                      ),
                    )
                  else
                    for (final t in monthly) _MonthRow(ticket: t),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDay(List<Ticket> tickets) {
    if (tickets.isEmpty) return;
    if (tickets.length == 1) {
      _push(tickets.first);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.stockLight,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Text('이 날의 티켓 ${tickets.length}장',
                style: AppText.ui(size: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 10),
            for (final t in tickets)
              ListTile(
                title: Text(t.title.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(size: 14, color: AppColors.ink)),
                subtitle: Text(t.venue,
                    maxLines: 1,
                    style: AppText.ui(size: 11, color: AppColors.inkSoft)),
                onTap: () {
                  Navigator.pop(context);
                  _push(t);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _push(Ticket t) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TicketDetailScreen(ticketId: t.id),
    ),
  );
}

/// 달 이동 줄. 탁상 달력의 머리처럼 큼직하게 둡니다.
class _MonthBar extends StatelessWidget {
  const _MonthBar({
    required this.month,
    required this.count,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime month;
  final int count;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, color: AppColors.ink),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onToday,
            child: Column(
              children: [
                Text(
                  '${month.year}',
                  style: AppText.data(
                      size: 11, spacing: 2.6, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 2),
                Text(
                  month.month.toString().padLeft(2, '0'),
                  style: AppText.plate(size: 44, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count FILED',
                  style: AppText.data(
                      size: 9, spacing: 1.6, color: AppColors.foil),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, color: AppColors.ink),
        ),
      ],
    );
  }
}

/// 하루 한 칸. 티켓이 있으면 그 자리에 티켓을 끼웁니다.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSunday,
    required this.tickets,
    required this.onTap,
  });

  final int day;
  final bool isSunday;
  final List<Ticket> tickets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = tickets.isNotEmpty;

    return GestureDetector(
      onTap: has ? onTap : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            day.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: AppText.data(
              size: 9.5,
              spacing: 0.4,
              weight: has ? FontWeight.w700 : FontWeight.w400,
              color: has
                  ? AppColors.ink
                  : (isSunday
                  ? AppColors.oxblood.withValues(alpha: 0.5)
                  : AppColors.pulp),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: has
                ? _Peek(ticket: tickets.first, more: tickets.length - 1)
                : DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.line.withValues(alpha: 0.55),
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 칸에 끼운 티켓 머리. 세로로 잘라 넣습니다.
class _Peek extends StatelessWidget {
  const _Peek({required this.ticket, required this.more});

  final Ticket ticket;

  /// 같은 날 티켓이 더 있으면 오른쪽 위에 숫자를 붙입니다.
  final int more;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.3)),
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: double.infinity,
                child: AspectRatio(
                  aspectRatio: ticket.frame.aspect,
                  child: TicketCanvas(
                    ticket: ticket,
                    compact: true,
                    // 아주 작은 칸이라 스티커까지 넣으면 지저분해집니다.
                    showLayers: false,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (more > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.oxblood,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${more + 1}',
                style: AppText.data(
                    size: 7.5, spacing: 0, color: AppColors.stockLight),
              ),
            ),
          ),
      ],
    );
  }
}

/// 아래 목록 한 줄.
class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                ticket.visitedAt.day.toString().padLeft(2, '0'),
                style: AppText.data(
                    size: 15, weight: FontWeight.w700, color: AppColors.foil),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 15, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    ticket.venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(size: 11, color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '★' * ticket.rating,
              maxLines: 1,
              style: AppText.data(size: 10, color: AppColors.foil),
            ),
          ],
        ),
      ),
    );
  }
}