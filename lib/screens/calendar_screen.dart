import 'package:flutter/material.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/scrapbook.dart' show DoodleUnderline;
import '../widgets/ticket_canvas.dart';
import 'ticket_detail_screen.dart';

/// 관람 기록을 달로 펼친 화면.
///
/// 흔한 달력처럼 점을 찍는 대신 **그날 본 티켓을 그 칸에 그대로 끼웠습니다.**
/// 한 달을 훑으면 어떤 색의 전시를 보고 다녔는지가 글자 없이 먼저 보입니다.
///
/// 생김새는 벽에 거는 탁상 달력입니다. 위에 스프링 제본이 지나가고,
/// 달 숫자는 커다란 활자로 눌러 찍혀 있습니다.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final store = TicketStore.instance;

  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  /// 그 달의 1일이 무슨 요일 칸에서 시작하는지. (일요일 = 0)
  int get _leading => DateTime(_month.year, _month.month, 1).weekday % 7;

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  bool get _isThisMonth {
    final now = DateTime.now();
    return now.year == _month.year && now.month == _month.month;
  }

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
          final today = DateTime.now().day;

          return Stack(
            children: [
              const WallGrain(opacity: 0.05, seed: 61),
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                children: [
                  // ── 달력 한 장 ─────────────────────
                  DecoratedBox(
                    decoration:
                    BoxDecoration(boxShadow: paperShadow(depth: 0.8)),
                    child: PaperSurface(
                      color: AppColors.stockLight,
                      grain: 0.055,
                      fiber: 0.7,
                      seed: _month.month * 31 + _month.year,
                      child: Column(
                        children: [
                          const _SpiralBinding(),
                          _MonthPlate(
                            month: _month,
                            count: monthly.length,
                            onPrev: () => _shift(-1),
                            onNext: () => _shift(1),
                            onToday: () => setState(() => _month = DateTime(
                                DateTime.now().year, DateTime.now().month)),
                          ),
                          Padding(
                            padding:
                            const EdgeInsets.fromLTRB(14, 4, 14, 18),
                            child: Column(
                              children: [
                                // 요일 머리.
                                Row(
                                  children: [
                                    for (var i = 0; i < 7; i++)
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            _weekdays[i],
                                            style: AppText.data(
                                              size: 7.5,
                                              spacing: 0.9,
                                              weight: FontWeight.w700,
                                              color: i == 0
                                                  ? AppColors.oxblood
                                                  .withValues(alpha: 0.8)
                                                  : AppColors.inkSoft,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 7),
                                Container(height: 1, color: AppColors.line),
                                const SizedBox(height: 10),

                                GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                  const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 7,
                                    mainAxisSpacing: 7,
                                    crossAxisSpacing: 5,
                                    childAspectRatio: 0.70,
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
                                      isToday: _isThisMonth && day == today,
                                      tickets: byDay[day] ?? const [],
                                      onTap: () =>
                                          _openDay(byDay[day] ?? const []),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ── 그 달의 목록 ────────────────────
                  Row(
                    children: [
                      Text('이 달의 기록',
                          style: AppText.ui(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.ink)),
                      const SizedBox(width: 10),
                      Text('${monthly.length}',
                          style: AppText.data(
                              size: 11, color: AppColors.foil)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Container(height: 1, color: AppColors.line)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (monthly.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26),
                      child: Column(
                        children: [
                          Text('이 달엔 아직 기록이 없습니다',
                              style: AppText.hand(
                                  size: 22, color: AppColors.pulp)),
                          const SizedBox(height: 6),
                          const DoodleUnderline(width: 130),
                        ],
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
      shape: const RoundedRectangleBorder(),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Text('이 날의 티켓 ${tickets.length}장',
                style: AppText.ui(size: 13, color: AppColors.inkSoft)),
            const SizedBox(height: 8),
            for (final t in tickets)
              ListTile(
                title: Text(t.title.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 16, color: AppColors.ink)),
                subtitle: Text(t.venue,
                    maxLines: 1,
                    style: AppText.ui(size: 11, color: AppColors.inkSoft)),
                onTap: () {
                  Navigator.pop(context);
                  _push(t);
                },
              ),
            const SizedBox(height: 14),
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

/// 탁상 달력 위쪽의 스프링 제본.
class _SpiralBinding extends StatelessWidget {
  const _SpiralBinding();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: 22,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < 9; i++)
              Column(
                children: [
                  // 종이에 뚫린 구멍.
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ink.withValues(alpha: 0.32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.55),
                        width: 0.8,
                      ),
                    ),
                  ),
                  // 구멍을 물고 있는 철사.
                  Container(
                    width: 3,
                    height: 6,
                    color: AppColors.inkSoft.withValues(alpha: 0.55),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 달 이동 줄. 숫자를 커다란 활자로 눌러 찍습니다.
class _MonthPlate extends StatelessWidget {
  const _MonthPlate({
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

  static const _names = [
    'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
    'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left,
                size: 22, color: AppColors.inkSoft),
          ),
          Expanded(
            child: GestureDetector(
              onTap: onToday,
              behavior: HitTestBehavior.opaque,
              child: Column(
                children: [
                  Text('${month.year}',
                      style: AppText.data(
                          size: 10, spacing: 3.0, color: AppColors.pulp)),
                  const SizedBox(height: 1),
                  // 큰 숫자는 Bodoni. 한글이 섞이지 않는 자리라 안전합니다.
                  Text(
                    month.month.toString().padLeft(2, '0'),
                    style: AppText.plate(size: 46, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(_names[month.month - 1],
                      style: AppText.eyebrow(
                          size: 8, color: AppColors.oxblood)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 2),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.foil.withValues(alpha: 0.6)),
                    ),
                    child: Text('$count FILED',
                        style: AppText.data(
                            size: 8, spacing: 1.6, color: AppColors.foil)),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right,
                size: 22, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

/// 하루 한 칸. 티켓이 있으면 그 자리에 티켓을 끼웁니다.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSunday,
    required this.isToday,
    required this.tickets,
    required this.onTap,
  });

  final int day;
  final bool isSunday;
  final bool isToday;
  final List<Ticket> tickets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = tickets.isNotEmpty;

    return GestureDetector(
      onTap: has ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 14,
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: isToday
                    ? const BoxDecoration(color: AppColors.oxblood)
                    : null,
                child: Text(
                  day.toString().padLeft(2, '0'),
                  style: AppText.data(
                    size: 9,
                    spacing: 0.2,
                    weight: has ? FontWeight.w700 : FontWeight.w400,
                    color: isToday
                        ? AppColors.stockLight
                        : (has
                        ? AppColors.ink
                        : (isSunday
                        ? AppColors.oxblood.withValues(alpha: 0.45)
                        : AppColors.pulp)),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: has
                ? _Peek(ticket: tickets.first, more: tickets.length - 1)
                : DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                    color: AppColors.line.withValues(alpha: 0.5)),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

/// 칸에 끼운 티켓 머리. 위쪽만 잘라 넣습니다.
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
            right: -4,
            top: -4,
            child: Container(
              width: 15,
              height: 15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.oxblood,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.stockLight, width: 1.2),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 38,
              child: Text(
                ticket.visitedAt.day.toString().padLeft(2, '0'),
                style: AppText.plate(size: 20, color: AppColors.foil),
              ),
            ),
            Container(width: 1, height: 30, color: AppColors.line),
            const SizedBox(width: 14),
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