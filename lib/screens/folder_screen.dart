import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';
import '../widgets/paper.dart';
import '../widgets/scaled_canvas.dart';
import '../widgets/scrap_page.dart';
import '../widgets/scrapbook.dart';
import '../widgets/stub_button.dart';
import '../widgets/ticket_canvas.dart';
import 'page_decor_screen.dart';
import 'share_card_screen.dart';
import 'ticket_detail_screen.dart';

/// 보기 방식. 기본은 스크랩북(펼친 다이어리)입니다.
enum FolderView { book, grid, list }

/// 서류철 내부.
///
/// 서류철을 열면 손으로 꾸민 스크랩북이 펼쳐집니다.
/// 자동 배치에서는 티켓이 두 장씩 테이프로 붙고 옆에 손글씨 메모가 붙습니다.
/// 자유 배치(`folder.freeLayout`)에서는 한 장에 전부 모아 사용자가 직접 앉힙니다.
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.folder});

  final ArchiveFolder folder;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final store = TicketStore.instance;
  final _pages = PageController();

  /// 공유 카드에 쓸 페이지 스냅샷 대상.
  final _pageKey = GlobalKey();

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
        title: Text(
          widget.folder.label,
          style: widget.folder.font.style(size: 13, color: AppColors.ink),
        ),
        actions: [
          IconButton(
            tooltip: '공유하기',
            onPressed: _share,
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: '페이지 꾸미기',
            onPressed: _decorate,
            icon: const Icon(Icons.brush_outlined),
          ),
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
              if (tickets.isEmpty) {
                return _Empty(onCreate: _create, onDecorate: _decorate);
              }

              return switch (_view) {
                FolderView.book => widget.folder.freeLayout
                    ? _freeBook(tickets)
                    : _book(tickets),
                FolderView.grid => _grid(tickets),
                FolderView.list => _list(tickets),
              };
            },
          ),
          const WallGrain(seed: 5),
        ],
      ),
      bottomNavigationBar: NewTicketRail(
        onPressed: _create,
        code: 'NEW',
        hint:
        '${widget.folder.label} · ${store.countIn(widget.folder.id)} FILED',
      ),
    );
  }

  // ── 스크랩북 (자동 배치) ──────────────────────────

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

              final page = _DecoratedPage(
                folder: widget.folder,
                seed: widget.folder.id.hashCode + i,
                footer:
                'PAGE ${(i + 1).toString().padLeft(2, '0')} / ${pages.length.toString().padLeft(2, '0')}',
                child: AutoScrapPage(
                  tickets: pages[i],
                  pageIndex: i,
                  onOpen: _openTicket,
                  onDelete: _confirmDelete,
                ),
              );

              return Transform(
                alignment:
                delta >= 0 ? Alignment.centerLeft : Alignment.centerRight,
                transform: matrix,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  child: DecoratedBox(
                    decoration:
                    BoxDecoration(boxShadow: paperShadow(depth: 0.9)),
                    // 지금 보고 있는 페이지만 공유 대상으로 표시합니다.
                    child: i == _page.round()
                        ? RepaintBoundary(key: _pageKey, child: page)
                        : page,
                  ),
                ),
              );
            },
          ),
        ),
        _PageDots(count: pages.length, page: _page),
        const SizedBox(height: 10),
      ],
    );
  }

  // ── 스크랩북 (자유 배치) ──────────────────────────

  /// 사용자가 직접 앉힌 자리 그대로 한 장에 펼칩니다.
  ///
  /// 좌표와 기본 자리는 꾸미기 화면과 **같은 함수**([defaultTicketPlacement])를
  /// 쓰므로, 거기서 본 그림이 그대로 나옵니다.
  Widget _freeBook(List<Ticket> tickets) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
      child: DecoratedBox(
        decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.9)),
        child: RepaintBoundary(
          key: _pageKey,
          child: LayoutBuilder(
            builder: (context, c) {
              final canvas = Size(c.maxWidth, c.maxHeight);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: NotebookPage(
                      seed: widget.folder.id.hashCode,
                      eyebrow: widget.folder.subtitle,
                      title: widget.folder.label,
                      footer: 'FREE LAYOUT',
                      child: const SizedBox.expand(),
                    ),
                  ),
                  for (var i = 0; i < tickets.length; i++)
                    _PlacedTicket(
                      ticket: tickets[i],
                      index: i,
                      canvas: canvas,
                      onTap: () => _openTicket(tickets[i]),
                      onLongPress: () => _confirmDelete(tickets[i]),
                    ),
                  for (final l in widget.folder.pageLayers)
                    PlacedLayer(layer: l, canvas: canvas),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── 바인더 · 목록 ────────────────────────────────

  Widget _grid(List<Ticket> tickets) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _sectionHead(tickets.length)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
        Text('$count장 · 목록 보기에서 하나씩 정리할 수 있습니다',
            style: AppText.data(size: 10, color: AppColors.inkSoft)),
      ],
    ),
  );

  // ── 동작 ────────────────────────────────────────

  void _openTicket(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(ticketId: ticket.id),
      ),
    );
  }

  void _decorate() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PageDecorScreen(folderId: widget.folder.id),
      ),
    );
  }

  /// 지금 보고 있는 페이지를 9:16 카드로 만들어 내보냅니다.
  void _share() {
    if (_view != FolderView.book) setState(() => _view = FolderView.book);

    final count = store.countIn(widget.folder.id);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShareCardScreen(
          // 화면에서 보던 페이지를 **같은 비율 그대로** 옮깁니다.
          // 상자 크기에 맞춰 다시 흐르게 두면 티켓만 작아지고 글자는 그대로라
          // 줄이 겹칩니다. 340×472(=0.72) 로 그린 뒤 통째로 줄입니다.
          artwork: ScaledCanvas(
            design: const Size(340, 472),
            child: _SharePage(folder: widget.folder, store: store),
          ),
          title: widget.folder.subtitle,
          subtitle: '${widget.folder.label} · 티켓 $count장',
          meta: 'SCRAPBOOK',
          fileName: 'articket_page',
          shareText: '${widget.folder.subtitle} — ARTICKET',
        ),
      ),
    );
  }

  void _create() {
    final id = const Uuid().v4();
    // 발권 번호는 여기서 만들지 않습니다.
    // store.add() 가 이 순간 딱 한 번 도장을 찍고, 그 뒤로는 바뀌지 않습니다.
    final ticket = Ticket(
      id: id,
      folderId: widget.folder.id,
      title: '제목 없는 전시',
      venue: '장소 미정',
      visitedAt: DateTime.now(),
      posterTint: [widget.folder.color, AppColors.ink],
    );
    store.add(ticket);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(ticketId: id),
      ),
    );
  }

  /// 티켓 삭제. 발권 번호(AK-…)는 내부 식별자라 제목으로 묻습니다.
  Future<void> _confirmDelete(Ticket ticket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.stockLight,
        shape: const RoundedRectangleBorder(),
        title: Text('이 티켓을 버릴까요?',
            style: AppText.ui(size: 16, color: AppColors.ink)),
        content: Text(
          '「${ticket.title.replaceAll('\n', ' ')}」\n'
              '붙여둔 것들도 함께 사라지고, 되돌릴 수 없습니다.',
          style: AppText.ui(size: 13, height: 1.6, color: AppColors.inkSoft),
        ),
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

/// 노트 속지 + 사용자가 꾸민 페이지 장식.
///
/// 좌표 기준은 `PageDecorScreen`과 똑같이 **페이지 한 장 전체**입니다.
/// 장식은 티켓보다 위에 그리지만 [PlacedLayer]가 `IgnorePointer`를 물고 있어서
/// 탭은 아래 티켓으로 통과합니다.
class _DecoratedPage extends StatelessWidget {
  const _DecoratedPage({
    required this.folder,
    required this.seed,
    required this.footer,
    required this.child,
  });

  final ArchiveFolder folder;
  final int seed;
  final String footer;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final canvas = Size(c.maxWidth, c.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: NotebookPage(
                seed: seed,
                eyebrow: folder.subtitle,
                title: folder.label,
                footer: footer,
                child: child,
              ),
            ),
            for (final layer in folder.pageLayers)
              PlacedLayer(layer: layer, canvas: canvas),
          ],
        );
      },
    );
  }
}

/// 자유 배치로 앉힌 티켓 한 장.
class _PlacedTicket extends StatelessWidget {
  const _PlacedTicket({
    required this.ticket,
    required this.index,
    required this.canvas,
    required this.onTap,
    required this.onLongPress,
  });

  final Ticket ticket;
  final int index;
  final Size canvas;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final at = defaultTicketPlacement(index);
    return Positioned(
      left: (ticket.px ?? at.dx) * canvas.width,
      top: (ticket.py ?? at.dy) * canvas.height,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: ticket.protation,
          child: TapedTicket(
            ticket: ticket,
            width: canvas.width * freeTicketWidthFactor * ticket.pscale,
            angle: 0,
            tapeColor: scrapTapes[index % scrapTapes.length],
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }
}

/// 공유 카드에 들어갈 페이지 한 장. (제스처 없이 그림만)
class _SharePage extends StatelessWidget {
  const _SharePage({required this.folder, required this.store});

  final ArchiveFolder folder;
  final TicketStore store;

  @override
  Widget build(BuildContext context) {
    final tickets = store.ticketsIn(folder.id);

    return LayoutBuilder(
      builder: (context, c) {
        final canvas = Size(c.maxWidth, c.maxHeight);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: NotebookPage(
                seed: folder.id.hashCode,
                eyebrow: folder.subtitle,
                title: folder.label,
                footer: 'ARTICKET',
                child: folder.freeLayout
                    ? const SizedBox.expand()
                    : AutoScrapPage(
                    tickets: tickets.take(2).toList(), pageIndex: 0),
              ),
            ),
            if (folder.freeLayout)
              for (var i = 0; i < tickets.length; i++)
                _PlacedTicket(
                  ticket: tickets[i],
                  index: i,
                  canvas: canvas,
                  onTap: () {},
                  onLongPress: () {},
                ),
            for (final l in folder.pageLayers)
              PlacedLayer(layer: l, canvas: canvas),
          ],
        );
      },
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
        MaterialPageRoute<void>(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      ),
      onLongPress: onDelete,
      // 프레임마다 비율이 달라서 셀 안에서 가운데 맞춰 넣습니다.
      child: Center(
        child: AspectRatio(
          aspectRatio: ticket.frame.aspect,
          child: DecoratedBox(
            decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.45)),
            child: Hero(
              tag: 'ticket-${ticket.id}',
              child: TicketCanvas(ticket: ticket, compact: true),
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
        MaterialPageRoute<void>(
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
            const SizedBox(width: 8),
            Text('★ ${ticket.rating}',
                style: AppText.data(size: 11, color: AppColors.foil)),
            // 길게 누르기가 어려운 환경에서도 지울 수 있는, 눈에 보이는 길.
            IconButton(
              tooltip: '버리기',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.pulp),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate, required this.onDecorate});

  final VoidCallback onCreate;
  final VoidCallback onDecorate;

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
          const SizedBox(height: 6),
          TextButton(
            onPressed: onDecorate,
            style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
            child: Text('빈 페이지부터 꾸미기', style: AppText.ui(size: 12)),
          ),
        ],
      ),
    );
  }
}