import 'package:material_ui/material_ui.dart';
import '../../models/ticket.dart';
import '../../theme/app_colors.dart';
import '../ticket_canvas.dart';

/// The gallery only shows real stored records, in groups of up to three.
class RecentTicketGallery extends StatefulWidget {
  const RecentTicketGallery({
    super.key,
    required this.tickets,
    required this.onOpen,
  });
  final List<Ticket> tickets;
  final ValueChanged<Ticket> onOpen;
  @override
  State<RecentTicketGallery> createState() => _RecentTicketGalleryState();
}

class _RecentTicketGalleryState extends State<RecentTicketGallery> {
  int _page = 0;
  @override
  void didUpdateWidget(RecentTicketGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tickets.map((t) => t.id).join() !=
        widget.tickets.map((t) => t.id).join()) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = (widget.tickets.length / 3).ceil();
    return Column(
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            key: ValueKey(widget.tickets.map((t) => t.id).join()),
            itemCount: count,
            onPageChanged: (v) => setState(() => _page = v),
            itemBuilder: (context, page) {
              final items = widget.tickets.skip(page * 3).take(3).toList();
              return LayoutBuilder(
                builder: (context, c) {
                  final sum = items.fold<double>(
                    0,
                    (value, t) => value + t.frame.aspect,
                  );
                  final height = ((c.maxWidth - 24) / sum).clamp(90.0, 190.0);
                  final widths = items
                      .map((t) => height * t.frame.aspect)
                      .toList();
                  final total =
                      widths.fold<double>(0, (a, b) => a + b) +
                      8 * (items.length - 1);
                  final left = (c.maxWidth - total) / 2;
                  return Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 14,
                        child: Container(
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.lavender,
                            borderRadius: BorderRadius.all(
                              Radius.elliptical(200, 65),
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < items.length; i++)
                        Positioned(
                          left:
                              left +
                              widths.take(i).fold<double>(0, (a, b) => a + b) +
                              i * 8,
                          top: items.length == 3 && i == 1 ? 12 : 28,
                          width: widths[i],
                          height: height,
                          child: Transform.rotate(
                            angle: (i - (items.length - 1) / 2) * .045,
                            child: Semantics(
                              button: true,
                              label: '${items[i].title} 티켓 열기',
                              child: GestureDetector(
                                onTap: () => widget.onOpen(items[i]),
                                child: TicketCanvas(
                                  ticket: items[i],
                                  compact: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        if (count > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${_page + 1} / $count',
              style: const TextStyle(fontSize: 10, color: AppColors.inkSoft),
            ),
          ),
      ],
    );
  }
}
