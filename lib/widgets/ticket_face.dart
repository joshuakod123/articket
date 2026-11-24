import 'package:material_ui/material_ui.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/ticket_design.dart';
import 'frame_shapes.dart';
import 'paper.dart';
import 'poster.dart';
import 'ticket_clipper.dart';
import 'print_box.dart';

class DesignedTicketFace extends StatelessWidget {
  const DesignedTicketFace({
    super.key,
    required this.ticket,
    this.tilt = 0,
    this.compact = false,
  });
  final Ticket ticket;
  final double tilt;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final graphic = ticket.design == TicketDesign.graphic;
    final scrap = ticket.design == TicketDesign.scrapbook;
    final ink = graphic ? Colors.white : AppColors.ink;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (graphic)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  ticket.isIssued
                      ? ticket.issuedSeq.toString().padLeft(3, '0')
                      : '—',
                  style: AppText.ui(
                    size: 36,
                    weight: FontWeight.w900,
                    color: ink,
                    height: 1.1,
                  ),
                ),
                const Spacer(),
                Text(
                  'ARTICKET\nCOLLECTION',
                  style: AppText.data(size: 9, color: ink),
                ),
              ],
            ),
          ),
        if (!graphic)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'ARTICKET',
                  style: AppText.wordmark(size: 11, spacing: 2, color: ink),
                ),
                const Spacer(),
                Text(
                  'EXHIBITION',
                  style: AppText.data(size: 8, color: AppColors.oxblood),
                ),
              ],
            ),
          ),
        Expanded(
          flex: 65,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: scrap ? 16 : 12),
            child: Poster(
              ticket: ticket,
              tilt: tilt,
              holoStrength: compact ? .3 : .8,
            ),
          ),
        ),
        Expanded(
          flex: 35,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      ticket.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: graphic
                          ? AppText.ui(
                              size: 23,
                              weight: FontWeight.w900,
                              color: ink,
                              height: 1.15,
                            )
                          : AppText.plate(size: 22, color: ink),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ticket.venue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(size: 11, color: ink),
                ),
                const SizedBox(height: 7),
                Text(
                  ticket.dateLabel,
                  style: AppText.data(size: 12, color: ink),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 18,
                  child: Barcode(seed: ticket.id, height: 18, color: ink),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    return ClipPath(
      clipper: clipperFor(ticket.frame),
      child: PaperSurface(
        color: graphic ? AppColors.blue : AppColors.stockLight,
        grain: compact ? .015 : .025,
        seed: ticket.id.hashCode,
        child: ticket.frame.horizontal
            ? Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Poster(ticket: ticket, tilt: tilt),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ARTICKET',
                            style: AppText.wordmark(
                              size: 8,
                              color: ink,
                              spacing: 1,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            ticket.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(
                              size: 18,
                              weight: FontWeight.w700,
                              color: ink,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ticket.venue,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.ui(size: 9, color: ink),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ticket.shortDate,
                            style: AppText.data(size: 11, color: ink),
                          ),
                          const Spacer(),
                          Barcode(seed: ticket.id, height: 15, color: ink),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : content,
      ),
    );
  }
}

class DesignedTicketBack extends StatelessWidget {
  const DesignedTicketBack({super.key, required this.ticket});
  final Ticket ticket;
  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: clipperFor(ticket.frame),
    child: PaperSurface(
      color: AppColors.stockLight,
      grain: .025,
      child: Padding(
        padding: EdgeInsets.all(ticket.frame.horizontal ? 12 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ARTICKET', style: AppText.wordmark(size: 11, spacing: 3)),
            const SizedBox(height: 12),
            if (!ticket.frame.horizontal) ...[
              _row('전시명', ticket.title),
              _row('관람일', ticket.dateLabel),
              _row('장소', ticket.venue),
              const Divider(height: 20),
            ],
            Text(
              '★' * ticket.rating,
              style: AppText.ui(size: 18, color: AppColors.accent),
            ),
            if (ticket.oneLiner.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  ticket.oneLiner,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.hand(size: 22),
                ),
              ),
            Expanded(
              child: FittedParagraph(
                text: ticket.note,
                style: AppText.hand(size: 19, height: 1.4),
              ),
            ),
            if (!ticket.frame.horizontal && ticket.companion.isNotEmpty)
              _row('함께한 사람', ticket.companion),
            const SizedBox(height: 10),
            Barcode(seed: ticket.id, height: 16),
            const SizedBox(height: 5),
            Text(ticket.serial, style: AppText.data(size: 9)),
          ],
        ),
      ),
    ),
  );
  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: AppText.ui(size: 10, color: AppColors.inkSoft),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.ui(size: 12),
          ),
        ),
      ],
    ),
  );
}
