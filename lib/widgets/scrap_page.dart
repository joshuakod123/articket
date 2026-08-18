import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'scrapbook.dart';
import 'ticket_canvas.dart';

/// 페이지에 쓰는 테이프 색. 자리마다 돌아가며 씁니다.
const scrapTapes = <Color>[
  Color(0x998C7134),
  Color(0x993F4A3C),
  Color(0x996B1F1A),
  Color(0x992E3B4E),
];

/// 테이프로 붙인 티켓 한 장.
///
/// 스크랩북·꾸미기 화면이 **같은 위젯**을 써야 꾸미기에서 본 그림과
/// 완성된 페이지가 일치합니다.
class TapedTicket extends StatelessWidget {
  const TapedTicket({
    super.key,
    required this.ticket,
    required this.width,
    this.angle = 0.02,
    this.tapeColor = const Color(0x998C7134),
    this.onTap,
    this.onLongPress,
  });

  final Ticket ticket;
  final double width;
  final double angle;
  final Color tapeColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width / ticket.frame.aspect,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: TapedItem(
          angle: angle,
          tapeColor: tapeColor,
          child: TicketCanvas(ticket: ticket, compact: true),
        ),
      ),
    );
  }
}

/// 티켓 옆에 손으로 적어둔 기록.
class ScrapMemo extends StatelessWidget {
  const ScrapMemo({super.key, required this.ticket, required this.slot});

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
              color:
              ticket.oneLiner.isEmpty ? AppColors.pulp : AppColors.oxblood,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('★' * ticket.rating,
                style:
                AppText.data(size: 9, spacing: 0.4, color: AppColors.foil)),
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

/// 자동 배치 한 칸. 티켓과 메모가 좌우로 번갈아 앉습니다.
class AutoScrapEntry extends StatelessWidget {
  const AutoScrapEntry({
    super.key,
    required this.ticket,
    required this.flip,
    required this.slot,
    this.onOpen,
    this.onDelete,
  });

  final Ticket ticket;

  /// 짝수/홀수 칸마다 좌우를 바꿔 붙입니다.
  final bool flip;
  final int slot;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

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

        final card = TapedTicket(
          ticket: ticket,
          width: tw,
          angle: (slot.isEven ? 1 : -1) * (0.022 + (slot % 3) * 0.008),
          tapeColor: scrapTapes[slot % scrapTapes.length],
          onTap: onOpen,
          onLongPress: onDelete,
        );

        final memo = ScrapMemo(ticket: ticket, slot: slot);

        final children = flip
            ? [Expanded(child: memo), const SizedBox(width: 18), card]
            : [card, const SizedBox(width: 18), Expanded(child: memo)];

        return Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        );
      },
    );
  }
}

/// 자동 배치 페이지 한 장의 내용. (티켓 두 장 + 메모)
class AutoScrapPage extends StatelessWidget {
  const AutoScrapPage({
    super.key,
    required this.tickets,
    required this.pageIndex,
    this.onOpen,
    this.onDelete,
  });

  final List<Ticket> tickets;
  final int pageIndex;
  final void Function(Ticket)? onOpen;
  final void Function(Ticket)? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var k = 0; k < tickets.length; k++)
          Expanded(
            child: AutoScrapEntry(
              ticket: tickets[k],
              flip: (pageIndex + k).isOdd,
              slot: pageIndex * 2 + k,
              onOpen: onOpen == null ? null : () => onOpen!(tickets[k]),
              onDelete: onDelete == null ? null : () => onDelete!(tickets[k]),
            ),
          ),
        if (tickets.length == 1) const Expanded(child: EmptySlot()),
      ],
    );
  }
}

/// 페이지가 한 칸 비었을 때 채우는 빈 자리.
class EmptySlot extends StatelessWidget {
  const EmptySlot({super.key});

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

/// 자유 배치에서 페이지 대비 티켓이 차지하는 기본 폭.
const double freeTicketWidthFactor = 0.40;