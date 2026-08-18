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
///
/// 예전 문제: 달력은 늘 "오늘이 든 달"에서 시작했습니다. 기록이 7월과 작년에
/// 몰려 있으면 8월에 들어와 텅 빈 격자만 보게 되고, 다른 달에 기록이 있다는
/// 사실조차 화면에 없었습니다. 그래서 티켓과 달력이 따로 노는 것처럼 보였습니다.
///
/// 고친 점 셋:
/// 1. 이 달에 기록이 없으면 **기록이 있는 가장 최근 달**을 펴고 들어옵니다.
/// 2. 달 아래에 **연도 띠**를 붙여 1~12월 중 어디에 기록이 있는지 점으로 보여주고,
///    누르면 그 달로 넘어갑니다.
/// 3. 빈 달에서는 가장 가까운 기록으로 건너뛰는 버튼을 답니다.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final store = TicketStore.instance;

  late DateTime _month;

  static const _weekdays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

  @override
  void initState() {
    super.initState();
    _month = _openingMonth();
  }

  /// 처음 펼 달. 이 달에 기록이 있으면 이 달, 없으면 가장 최근 기록의 달.
  DateTime _openingMonth() {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);

    final ts = store.tickets;
    if (ts.isEmpty) return thisMonth;

    final hasThisMonth = ts.any((t) =>
    t.visitedAt.year == now.year && t.visitedAt.month == now.month);
    if (hasThisMonth) return thisMonth;

    final latest =
    ts.map((t) => t.visitedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return DateTime(latest.year, latest.month);
  }

  void _shift(int by) =>
      setState(() => _month = DateTime(_month.year, _month.month + by));

  void _goto(DateTime m) => setState(() => _month = DateTime(m.year, m.month));

  /// 그 달의 1일이 무슨 요일 칸에서 시작하는지. (일요일 = 0)
  int get _leading => DateTime(_month.year, _month.month, 1).weekday % 7;

  int get _daysInMonth => DateTime(_month.year, _month.month + 1, 0).day;

  bool get _isThisMonth {
    final now = DateTime.now();
    return now.year == _month.year && now.month == _month.month;
  }

  /// `연*100+월` → 그 달의 티켓 수.
  Map<int, int> _countByMonth() {
    final m = <int, int>{};
    for (final t in store.tickets) {
      final k = t.visitedAt.year * 100 + t.visitedAt.month;
      m[k] = (m[k] ?? 0) + 1;
    }
    return m;
  }

  /// 지금 보고 있는 달에서 가장 가까운, 기록이 있는 달.
  DateTime? _nearestFilled(Map<int, int> byMonth) {
    if (byMonth.isEmpty) return null;

    final here = _month.year * 12 + _month.month;
    int? best;
    var bestGap = 1 << 30;

    for (final k in byMonth.keys) {
      final gap = ((k ~/ 100) * 12 + (k % 100) - here).abs();
      final b = best;
      // 거리가 같으면 과거보다 최근 달을 고릅니다.
      if (b == null || gap < bestGap || (gap == bestGap && k > b)) {
        bestGap = gap;
        best = k;
      }
    }
    return best == null ? null : DateTime(best ~/ 100, best % 100);
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
          final byMonth = _countByMonth();

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
          final jump = monthly.isEmpty ? _nearestFilled(byMonth) : null;

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
                            onToday: () => _goto(DateTime.now()),
                          ),

                          // 이 해의 어느 달에 기록이 있는지.
                          _YearStrip(
                            year: _month.year,
                            selected: _month.month,
                            byMonth: byMonth,
                            onYear: (y) => _goto(DateTime(y, _month.month)),
                            onMonth: (m) => _goto(DateTime(_month.year, m)),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
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
                          style:
                          AppText.data(size: 11, color: AppColors.foil)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Container(height: 1, color: AppColors.line)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (monthly.isEmpty)
                    _EmptyMonth(
                      jump: jump,
                      onJump: jump == null ? null : () => _goto(jump),
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
            Text('이 날 본 것 ${tickets.length}장',
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
                mainAxisSize: MainAxisSize.min,
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
    final filled = count > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 큰 숫자는 Bodoni. 한글이 섞이지 않는 자리라 안전합니다.
                  Text(
                    month.month.toString().padLeft(2, '0'),
                    style: AppText.plate(size: 46, color: AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(_names[month.month - 1],
                      style:
                      AppText.eyebrow(size: 8, color: AppColors.oxblood)),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: filled
                          ? AppColors.foil.withValues(alpha: 0.12)
                          : null,
                      border: Border.all(
                        color: AppColors.foil
                            .withValues(alpha: filled ? 0.7 : 0.35),
                      ),
                    ),
                    child: Text(
                      filled ? '$count FILED' : 'EMPTY',
                      style: AppText.data(
                        size: 8,
                        spacing: 1.6,
                        color: AppColors.foil
                            .withValues(alpha: filled ? 1 : 0.55),
                      ),
                    ),
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

/// 연도 띠.
///
/// 1월부터 12월까지 열두 칸을 늘어놓고, **기록이 있는 달에만 점을 찍습니다.**
/// 달력이 티켓을 실제로 읽고 있다는 걸 한눈에 보여주는 자리입니다.
class _YearStrip extends StatelessWidget {
  const _YearStrip({
    required this.year,
    required this.selected,
    required this.byMonth,
    required this.onYear,
    required this.onMonth,
  });

  final int year;
  final int selected;

  /// `연*100+월` → 티켓 수.
  final Map<int, int> byMonth;

  final ValueChanged<int> onYear;
  final ValueChanged<int> onMonth;

  @override
  Widget build(BuildContext context) {
    var yearTotal = 0;
    for (final e in byMonth.entries) {
      if (e.key ~/ 100 == year) yearTotal += e.value;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AppColors.line),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Arrow(icon: Icons.arrow_left, onTap: () => onYear(year - 1)),
              const SizedBox(width: 6),
              Text('$year',
                  style: AppText.data(
                      size: 11, spacing: 2.6, color: AppColors.ink)),
              const SizedBox(width: 8),
              Text('· $yearTotal',
                  style: AppText.data(size: 9.5, color: AppColors.pulp)),
              const SizedBox(width: 6),
              _Arrow(icon: Icons.arrow_right, onTap: () => onYear(year + 1)),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: Row(
              children: [
                for (var m = 1; m <= 12; m++)
                  Expanded(
                    child: _MonthPip(
                      month: m,
                      count: byMonth[year * 100 + m] ?? 0,
                      selected: m == selected,
                      onTap: () => onMonth(m),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: AppColors.pulp),
      ),
    );
  }
}

/// 연도 띠의 한 달 칸.
class _MonthPip extends StatelessWidget {
  const _MonthPip({
    required this.month,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final int month;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final has = count > 0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: selected
            ? BoxDecoration(
          color: AppColors.oxblood.withValues(alpha: 0.07),
          border: Border.all(
              color: AppColors.oxblood.withValues(alpha: 0.55)),
        )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              month.toString().padLeft(2, '0'),
              maxLines: 1,
              softWrap: false,
              style: AppText.data(
                size: 8.5,
                spacing: 0,
                height: 1.0,
                weight: has ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? AppColors.oxblood
                    : (has ? AppColors.ink : AppColors.pulp),
              ),
            ),
            const SizedBox(height: 4),
            // 기록이 있는 달에만 도장을 찍습니다. 두 장 이상이면 굵게.
            Container(
              width: has ? (count > 1 ? 7 : 4) : 4,
              height: 4,
              decoration: BoxDecoration(
                shape: count > 1 ? BoxShape.rectangle : BoxShape.circle,
                color: has
                    ? (selected ? AppColors.oxblood : AppColors.foil)
                    : AppColors.line.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
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
            // 빈 날은 상자로 두르지 않습니다. 격자만 가득한 화면이 되면
            // 정작 티켓이 끼워진 칸이 묻힙니다. 바닥에 괘선만 한 줄.
                : Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 1,
                color: AppColors.line.withValues(alpha: 0.55),
              ),
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

/// 이 달이 비었을 때. 가장 가까운 기록으로 건너뛰게 해 줍니다.
class _EmptyMonth extends StatelessWidget {
  const _EmptyMonth({required this.jump, required this.onJump});

  final DateTime? jump;
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Column(
        children: [
          Text('이 달은 비었어요',
              style: AppText.hand(size: 22, color: AppColors.pulp)),
          const SizedBox(height: 6),
          const DoodleUnderline(width: 130),
          if (jump != null && onJump != null) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onJump,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.line),
                  color: AppColors.stockLight.withValues(alpha: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.subdirectory_arrow_right,
                        size: 14, color: AppColors.foil),
                    const SizedBox(width: 8),
                    Text(
                      '${jump!.year}.${jump!.month.toString().padLeft(2, '0')} 로 가기',
                      style: AppText.ui(size: 12, color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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