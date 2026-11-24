import 'package:flutter/material.dart';
import '../data/ticket_store.dart';
import '../data/ticket_query.dart';
import '../widgets/ticket_canvas.dart';
import 'ticket_detail_screen.dart';

class TicketSearchScreen extends StatefulWidget {
  const TicketSearchScreen({
    super.key,
    this.initialFilter = ArchiveFilter.all,
    this.year,
  });
  final ArchiveFilter initialFilter;
  final int? year;
  @override
  State<TicketSearchScreen> createState() => _TicketSearchScreenState();
}

class _TicketSearchScreenState extends State<TicketSearchScreen> {
  String _query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('기록 검색')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: '전시명, 장소, 감상으로 검색',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: TicketStore.instance,
            builder: (context, _) {
              final items = queryTickets(
                TicketStore.instance.tickets,
                search: _query,
                filter: widget.initialFilter,
                year: widget.year,
              );
              if (items.isEmpty) {
                return const Center(child: Text('일치하는 기록이 없어요'));
              }
              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final t = items[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    leading: SizedBox(
                      width: 40,
                      height: 65,
                      child: TicketCanvas(ticket: t, compact: true),
                    ),
                    title: Text(t.title),
                    subtitle: Text('${t.venue} · ${t.dateLabel}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => TicketDetailScreen(ticketId: t.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
