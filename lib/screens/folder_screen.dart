import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/ticket_card.dart';
import 'ticket_detail_screen.dart';

/// 서류철 내부. 포토카드 바인더처럼 티켓을 3열 그리드로 봅니다.
/// 티켓을 길게 누르면 삭제할 수 있습니다.
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
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final tickets = store.ticketsIn(widget.folder.id);

              if (tickets.isEmpty) return _Empty(onCreate: _create);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.folder.subtitle,
                              style: AppText.display(
                                  size: 30, color: AppColors.ink)),
                          const SizedBox(height: 6),
                          Text('${tickets.length}장 · 길게 누르면 버릴 수 있습니다',
                              style: AppText.data(
                                  size: 10, color: AppColors.inkSoft)),
                          const SizedBox(height: 14),
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
                    )
                  else
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
          child: Container(
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