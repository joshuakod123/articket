import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/ticket_card.dart';
import 'ticket_detail_screen.dart';

/// 서류철 내부. 포토카드 바인더처럼 티켓을 3열 그리드로 봅니다.
class FolderScreen extends StatefulWidget {
  const FolderScreen({super.key, required this.folder});

  final ArchiveFolder folder;

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final store = TicketStore.instance;
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.folder.label),
        actions: [
          IconButton(
            tooltip: _grid ? '목록으로 보기' : '바인더로 보기',
            onPressed: () => setState(() => _grid = !_grid),
            icon: Icon(_grid
                ? Icons.view_agenda_outlined
                : Icons.grid_view_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final tickets = store.ticketsIn(widget.folder.id);

          if (tickets.isEmpty) return _Empty(onCreate: _create);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.folder.subtitle,
                          style: AppText.display(
                              size: 30, color: AppColors.stock)),
                      const SizedBox(height: 6),
                      Text('${tickets.length}장',
                          style: AppText.data(
                              size: 10, color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ),
              if (_grid)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.56,
                    ),
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => _GridCell(ticket: tickets[i]),
                      childCount: tickets.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList.separated(
                    itemCount: tickets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _ListRow(ticket: tickets[i]),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.oxblood,
        foregroundColor: AppColors.stockLight,
        icon: const Icon(Icons.add, size: 18),
        label: Text('티켓 만들기', style: AppText.ui(size: 13, weight: FontWeight.w600)),
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
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      ),
      // 프레임마다 비율이 달라서 셀 안에서 가운데 맞춰 넣습니다.
      child: Center(
        child: AspectRatio(
          aspectRatio: ticket.frame.aspect,
          child: Hero(
            tag: 'ticket-${ticket.id}',
            child: TicketFront(ticket: ticket, compact: true),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TicketDetailScreen(ticketId: ticket.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.inkSoft)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 44,
              color: ticket.posterTint.first,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title.replaceAll('\n', ' '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(size: 18, color: AppColors.stock),
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
              foregroundColor: AppColors.stock,
              side: const BorderSide(color: AppColors.inkSoft),
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