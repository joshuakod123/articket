import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/scrapbook.dart';
import '../widgets/ticket_card.dart';
import 'ticket_detail_screen.dart';

/// 보기 방식. 기본은 스크랩북(펼친 다이어리)입니다.
enum FolderView { book, grid, list }

/// 서류철 내부.
///
/// 서류철을 열면 손으로 꾸민 스크랩북이 펼쳐집니다. 페이지를 옆으로 넘기면
/// 티켓이 마스킹 테이프로 붙어 있고, 옆에 손글씨로 감상이 적혀 있습니다.
/// 바인더(3열 그리드)와 목록으로도 볼 수 있고, 길게 누르면 티켓을 버립니다.
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.folder});

  final ArchiveFolder folder;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final store = TicketStore.instance;
  final _pages = PageController();

  FolderView _view = FolderView.book;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(_onScroll);
  }

  void _onScroll() {
    final p = _pageValue;
    if ((p - _page).abs() > 0.001) setState(() => _page = p);
  }

  /// 아직 레이아웃 전이면 .page가 던지므로 안전하게 읽습니다.
  double get _pageValue {
    if (!_pages.hasClients) return 0;
    final pos = _pages.position;
    if (!pos.hasPixels || !pos.hasContentDimensions) return 0;
    return _pages.page ?? 0;
  }

  @override
  void dispose() {
    _pages.removeListener(_onScroll);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.label),
        actions: [
          IconButton(
            tooltip: switch (_view) {
              FolderView.book => '바인더로 보기',
              FolderView.grid => '목록으로 보기',
              FolderView.list => '스크랩북으로 보기',
            },
            onPressed: () => setState(() {
              _view = FolderView
                  .values[(_view.index + 1) % FolderView.values.length];
            }),
            icon: Icon(switch (_view) {
              FolderView.book => Icons.grid_view_outlined,
              FolderView.grid => Icons.view_agenda_outlined,
              FolderView.list => Icons.auto_stories_outlined,
            }),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final tickets = store.ticketsIn(widget.folder.id);
              if (tickets.isEmpty) return _Empty(onCreate: _create);

              return switch (_view) {
                FolderView.book => _book(tickets),
                FolderView.grid => _grid(tickets),
                FolderView.list => _list(tickets),
              };
            },
          ),
          const WallGrain(seed: 5),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.oxblood,
        foregroundColor: AppColors.stockLight,
        elevation: 2,
        shape: const RoundedRectangleBorder(),
        icon: const Icon(Icons.add, size: 18),
        label: Text('티켓 만들기',
            style: AppText.ui(size: 13, weight: FontWeight.w600)),
      ),
    );
  }

  // ── 스크랩북 ─────────────────────────────────────

  Widget _book(List<Ticket> tickets) {
    // 한 페이지에 두 장씩 붙입니다.
    final pages = <List<Ticket>>[];
    for (var i = 0; i < tickets.length; i += 2) {
      pages.add(tickets.sublist(i, math.min(i + 2, tickets.length)));
    }

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pages,
            itemCount: pages.length,
            itemBuilder: (context, i) {
              final delta = (i - _page).clamp(-1.0, 1.0);

              // 넘어가는 페이지가 안쪽 제본을 축으로 살짝 젖혀집니다.
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.0011)
                ..rotateY(delta * 0.42);

              return Transform(
                alignment:
                delta >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                transform: matrix,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(boxShadow: paperShadow(depth: .7)),
                    child: NotebookPage(
                      seed: widget.folder.id.hashCode + i,
                      eyebrow: widget.folder.subtitle,
                      title: widget.folder.label,
                      footer:
                      'PAGE ${(i + 1).toString().padLeft(2, '0')} / ${pages.length.toString().padLeft(2, '0')}',
                      child: Column(
                        children: [
                          for (var k = 0; k < pages[i].length; k++)
                            Expanded(
                              child: _ScrapEntry(
                                ticket: pages[i][k],
                                flip: (i + k).isOdd,
                                slot: i * 2 + k,
                                onOpen: () => _openTicket(pages[i][k]),
                                onDelete: () => _confirmDelete(pages[i][k]),
                              ),
                            ),
                          if (pages[i].length == 1)
                            const Expanded(child: _EmptySlot()),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _PageDots(count: pages.length, page: _page),
        const SizedBox(height: 74),
      ],
    );
  }

  // ── 바인더 · 목록 ────────────────────────────────

  Widget _grid(List<Ticket> tickets) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _sectionHead(tickets.length)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            delegate: SliverChildBuilderDelegate(
                  (context, i) => _GridCell(
                ticket: tickets[i],
                onDelete: () => _confirmDelete(tickets[i]),
              ),
              childCount: tickets.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _list(List<Ticket> tickets) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _sectionHead(tickets.length)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList.separated(
            itemCount: tickets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _ListRow(
              ticket: tickets[i],
              onDelete: () => _confirmDelete(tickets[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHead(int count) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.folder.subtitle,
            style: AppText.display(size: 30, color: AppColors.ink)),
        const SizedBox(height: 6),
        Text('$count장 · 길게 누르면 버릴 수 있습니다',
            style: AppText.data(size: 10, color: AppColors.inkSoft)),
      ],
    ),
  );

  // ── 동작 ────────────────────────────────────────

  void _openTicket(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TicketDetailScreen(ticketId: ticket.id),
      ),
    );
  }

  void _create() {
    final id = const Uuid().v4();
    final seq = store.tickets.length + 1;
    final ticket = Ticket(
      id: id,
      folderId: widget.folder.id,
      title: '제목 없는 전시',
      venue: '장소 미정',
      visitedAt: DateTime.now(),
      serial: 'AK-${DateTime.now().year}-${seq.toString().padLeft(5, '0')}',
      posterTint: [widget.folder.color, AppColors.ink],
    );
    store.add(ticket);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: id)),
    );
  }

  /// 길게 누른 티켓 삭제. 상세 화면의 삭제와 같은 다이얼로그를 씁니다.
  Future<void> _confirmDelete(Ticket ticket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.stockLight,
        shape: const RoundedRectangleBorder(),
        title: Text('티켓을 버릴까요?',
            style: AppText.ui(size: 16, color: AppColors.ink)),
        content: Text(
            '${ticket.title.replaceAll('\n', ' ')}\n${ticket.serial} · 복구할 수 없습니다.',
            style: AppText.ui(size: 13, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('그대로 두기',
                style: AppText.ui(size: 13, color: AppColors.ink)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('버리기',
                style: AppText.ui(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.oxblood)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) store.remove(ticket.id);
  }
}

/// 스크랩북 페이지에 붙인 티켓 한 장 + 손글씨 기록.
class _ScrapEntry extends StatelessWidget {
  const _ScrapEntry({
    required this.ticket,
    required this.flip,
    required this.slot,
    required this.onOpen,
    required this.onDelete,
  });

  final Ticket ticket;

  /// 짝수/홀수 칸마다 좌우를 바꿔 붙입니다.
  final bool flip;
  final int slot;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  static const _tapes = <Color>[
    Color(0x998C7134),
    Color(0x993F4A3C),
    Color(0x996B1F1A),
    Color(0x992E3B4E),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // 테이프가 삐져나올 자리를 남기고 티켓 크기를 잡습니다.
        var th = c.maxHeight - 26;
        var tw = th * ticket.frame.aspect;
        final maxW = c.maxWidth * 0.44;
        if (tw > maxW) {
          tw = maxW;
          th = tw / ticket.frame.aspect;
        }
        if (th < 40) th = 40;

        final angle = (slot.isEven ? 1 : -1) * (0.022 + (slot % 3) * 0.008);

        final card = SizedBox(
          width: tw,
          height: th,
          child: GestureDetector(
            onTap: onOpen,
            onLongPress: onDelete,
            child: TapedItem(
              angle: angle,
              tapeColor: _tapes[slot % _tapes.length],
              child: TicketFront(ticket: ticket, compact: true),
            ),
          ),
        );

        final memo = _Memo(ticket: ticket, slot: slot);

        final children = flip
            ? [Expanded(child: memo), const SizedBox(width: 18), card]
            : [card, const SizedBox(width: 18), Expanded(child: memo)];

        return Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        );
      },
    );
  }
}

/// 티켓 옆에 손으로 적어둔 기록.
class _Memo extends StatelessWidget {
  const _Memo({required this.ticket, required this.slot});

  final Ticket ticket;
  final int slot;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(ticket.dateLabel,
                style: AppText.data(
                    size: 8.5, spacing: 1.2, color: AppColors.inkSoft)),
            const SizedBox(width: 6),
            if (slot % 3 == 0) const DoodleStar(size: 15),
          ],
        ),
        const SizedBox(height: 5),
        Flexible(
          child: Text(
            ticket.title.replaceAll('\n', ' '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(
                size: 13.5,
                weight: FontWeight.w700,
                height: 1.25,
                color: AppColors.ink),
          ),
        ),
        const SizedBox(height: 3),
        const DoodleUnderline(width: 74),
        const SizedBox(height: 7),
        Flexible(
          child: Text(
            ticket.oneLiner.isEmpty ? '아직 아무 말도 적지 않았다.' : ticket.oneLiner,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppText.hand(
              size: 19,
              height: 1.15,
              color: ticket.oneLiner.isEmpty
                  ? AppColors.pulp
                  : AppColors.oxblood,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('★' * ticket.rating,
                style: AppText.data(size: 9, spacing: 0.4, color: AppColors.foil)),
            if (ticket.rating > 0) const SizedBox(width: 6),
            Flexible(
              child: Text(
                ticket.venue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(size: 10, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 페이지가 한 칸 비었을 때 채우는 빈 자리.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('다음 장을 기다리는 중',
              style: AppText.hand(size: 20, color: AppColors.pulp)),
          const SizedBox(height: 6),
          const DoodleUnderline(width: 110),
        ],
      ),
    );
  }
}

/// 스크랩북 아래의 페이지 표시.
class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox(height: 10);

    final current = page.round();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == current ? 16 : 5,
              height: 5,
              decoration: BoxDecoration(
                color: i == current ? AppColors.oxblood : AppColors.line,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.ticket, required this.onDelete});

  final Ticket ticket;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      ),
      onLongPress: onDelete,
      // 프레임마다 비율이 달라서 셀 안에서 가운데 맞춰 넣습니다.
      child: Center(
        child: AspectRatio(
          aspectRatio: ticket.frame.aspect,
          child: DecoratedBox(
            // 밝은 벽 위에서 종이가 떠 보이도록 얕은 그림자.
            decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.45)),
            child: Hero(
              tag: 'ticket-${ticket.id}',
              child: TicketFront(ticket: ticket, compact: true),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.ticket, required this.onDelete});

  final Ticket ticket;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      ),
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 44, color: ticket.posterTint.first),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 18, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  Text('${ticket.dateLabel}  ·  ${ticket.venue}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 12, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('★ ${ticket.rating}',
                style: AppText.data(size: 11, color: AppColors.foil)),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('아직 철해둔 티켓이 없습니다',
              style: AppText.ui(size: 14, color: AppColors.inkSoft)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onCreate,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              side: const BorderSide(color: AppColors.ink),
              shape: const RoundedRectangleBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: Text('첫 티켓 만들기', style: AppText.ui(size: 13)),
          ),
        ],
      ),
    );
  }
}