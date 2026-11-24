import 'package:material_ui/material_ui.dart';
import '../data/ticket_store.dart';
import '../data/ticket_query.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/home/archive_header.dart';
import '../widgets/home/recent_ticket_gallery.dart';
import '../widgets/home/folder_preview_card.dart';
import 'folder_screen.dart';
import 'folder_list_screen.dart';
import 'folder_workbench.dart';
import 'ticket_create_screen.dart';
import 'ticket_detail_screen.dart';
import 'ticket_search_screen.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, this.navBarKey, this.active = true});
  final GlobalKey? navBarKey;
  final bool active;
  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final store = TicketStore.instance;
  int? _year;
  ArchiveFilter _filter = ArchiveFilter.all;
  void _create() => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => const TicketCreateScreen()),
  );
  void _open(Ticket t) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => TicketDetailScreen(ticketId: t.id)),
  );
  Future<void> _folder([ArchiveFolder? f]) => openFolderWorkbench(
    context,
    store: store,
    folder: f,
    fileNo: store.folders.length + 1,
  ).then((_) {});
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: FilledButton.icon(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('관람 기록 남기기'),
      ),
    ),
    body: SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = queryTickets(
            store.tickets,
            year: _year,
            filter: _filter,
          );
          final years =
              store.tickets.map((t) => t.visitedAt.year).toSet().toList()
                ..sort((a, b) => b.compareTo(a));
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                sliver: SliverList.list(
                  children: [
                    ArchiveHeader(
                      count: items.length,
                      year: _year,
                      years: years,
                      filter: _filter,
                      onYear: (v) => setState(() => _year = v),
                      onFilter: (v) => setState(() => _filter = v),
                      onSearch: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const TicketSearchScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (items.isNotEmpty) ...[
                      RecentTicketGallery(tickets: items, onOpen: _open),
                      Row(
                        children: [
                          Text(
                            '최근에 모은 티켓',
                            style: AppText.ui(
                              size: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => TicketSearchScreen(
                                  initialFilter: _filter,
                                  year: _year,
                                ),
                              ),
                            ),
                            child: const Text('모두 보기 ↗'),
                          ),
                        ],
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              size: 70,
                              color: AppColors.inkSoft,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              store.tickets.isEmpty
                                  ? '첫 관람을 간직해볼까요?'
                                  : '이 조건의 티켓은 아직 없어요',
                              textAlign: TextAlign.center,
                              style: AppText.display(size: 21),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '전시명과 날짜만으로 시작할 수 있어요.',
                              textAlign: TextAlign.center,
                              style: AppText.ui(
                                size: 13,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              onPressed: _create,
                              child: const Text('+ 첫 티켓 만들기'),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Row(
                      children: [
                        Text('나의 서류철', style: AppText.display(size: 21)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const FolderListScreen(),
                            ),
                          ),
                          child: const Text('전체 보기'),
                        ),
                        IconButton(
                          tooltip: '서류철 만들기',
                          onPressed: () => _folder(),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (store.folders.isEmpty)
                      OutlinedButton.icon(
                        onPressed: () => _folder(),
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('서류철부터 만들기'),
                      ),
                    if (store.folders.isNotEmpty)
                      LayoutBuilder(
                        builder: (context, c) => Wrap(
                          spacing: 12,
                          runSpacing: 14,
                          children: store.folders
                              .take(2)
                              .map(
                                (f) => SizedBox(
                                  width: (c.maxWidth - 12) / 2,
                                  child: FolderPreviewCard(
                                    folder: f,
                                    tickets: store.ticketsIn(f.id),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute<void>(
                                        builder: (_) => FolderScreen(folder: f),
                                      ),
                                    ),
                                    onLongPress: () => _folder(f),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
