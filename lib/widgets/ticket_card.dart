import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'frame_shapes.dart';
import 'paper.dart';
import 'poster.dart';
import 'ticket_clipper.dart' show Barcode;

/// 티켓 앞면. 프레임에 따라 실루엣과 정보 배치가 달라집니다.
class TicketFront extends StatelessWidget {
  const TicketFront({
    super.key,
    required this.ticket,
    this.tilt = 0,
    this.compact = false,
  });

  final Ticket ticket;

  /// 자이로 기울기 (-1..1).
  final double tilt;

  /// 그리드 썸네일용 축소 레이아웃.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: clipperFor(ticket.frame),
      child: PaperSurface(
        color: AppColors.stockLight,
        seed: ticket.serial.hashCode,
        child: ticket.frame.horizontal ? _horizontal() : _vertical(),
      ),
    );
  }

  // ── 세로형 (클래식 / 영수증 / 필름 / 우표 / 미니멀) ──
  Widget _vertical() {
    final f = ticket.frame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: f.flexPoster,
          child: f.matted
              ? Padding(
            padding: EdgeInsets.all(compact ? 6 : 12),
            child: _posterBlock(),
          )
              : _posterBlock(),
        ),
        if (f.hasPerforation)
          PerforationLine(color: AppColors.pulp, inset: compact ? 8 : 14),
        Expanded(
          flex: 100 - f.flexPoster,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 16,
              vertical: compact ? 6 : 12,
            ),
            child: compact ? _CompactStub(ticket: ticket) : _FullStub(ticket: ticket),
          ),
        ),
      ],
    );
  }

  // ── 가로형 (가로 스텁) ────────────────────────────
  Widget _horizontal() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: ticket.frame.flexPoster, child: _posterBlock()),
        PerforationLine(
          color: AppColors.pulp,
          vertical: true,
          inset: compact ? 6 : 12,
        ),
        Expanded(
          flex: 100 - ticket.frame.flexPoster,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 10,
              vertical: compact ? 6 : 12,
            ),
            child: _SideStub(ticket: ticket, compact: compact),
          ),
        ),
      ],
    );
  }

  Widget _posterBlock() {
    return Poster(
      ticket: ticket,
      tilt: tilt,
      holoStrength: compact ? 0.5 : 0.9,
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 라벨 줄. 좁은 폭에서 넘치지 않도록 둘 다 Flexible로 감쌉니다.
            if (!compact)
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'ADMIT ONE',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: AppText.eyebrow(
                          color: AppColors.stock.withValues(alpha: .85)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      ticket.genre.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppText.eyebrow(
                          color: AppColors.stock.withValues(alpha: .85)),
                    ),
                  ),
                ],
              ),
            const Spacer(),
            Text(
              ticket.title,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(
                size: compact ? 14 : (ticket.frame.horizontal ? 22 : 26),
                color: AppColors.stockLight,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 6),
              Text(
                ticket.venue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(
                  size: 12,
                  color: AppColors.stock.withValues(alpha: .75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 그리드 썸네일용 스텁. 날짜와 짧은 바코드만.
class _CompactStub extends StatelessWidget {
  const _CompactStub({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            ticket.dateLabel,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: AppText.data(size: 8, spacing: 0.4, color: AppColors.ink),
          ),
        ),
        Flexible(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Barcode(serial: ticket.serial, height: 10),
          ),
        ),
      ],
    );
  }
}

/// 세로형 티켓의 아래 스텁. 날짜·장소 + 바코드.
class _FullStub extends StatelessWidget {
  const _FullStub({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _field('DATE', ticket.dateLabel)),
              Flexible(child: _field('VENUE', ticket.venue)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Barcode(serial: ticket.serial, height: 22),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(ticket.serial,
                    style: AppText.data(
                        size: 8, spacing: 0.6, color: AppColors.inkSoft)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label,
          maxLines: 1,
          style: AppText.eyebrow(
              color: AppColors.inkSoft.withValues(alpha: .6))),
      const SizedBox(height: 2),
      Text(value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.data(
              size: 11,
              spacing: 0.6,
              color: AppColors.ink,
              weight: FontWeight.w700)),
    ],
  );
}

/// 가로형 티켓의 오른쪽 스텁. 세로로 세운 바코드.
class _SideStub extends StatelessWidget {
  const _SideStub({required this.ticket, required this.compact});

  final Ticket ticket;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(ticket.shortDate,
              style: AppText.data(
                  size: compact ? 9 : 12,
                  spacing: 0.6,
                  weight: FontWeight.w700,
                  color: AppColors.ink)),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Center(
              child: Barcode(serial: ticket.serial, height: compact ? 10 : 16),
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('★${ticket.rating}',
              style: AppText.data(size: compact ? 8 : 10, color: AppColors.foil)),
        ),
      ],
    );
  }
}

/// 티켓 뒷면. 별점 · 한 줄 평 · 감상문.
class TicketBack extends StatelessWidget {
  const TicketBack({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: clipperFor(ticket.frame),
      child: PaperSurface(
        color: AppColors.stock,
        seed: ticket.serial.hashCode + 1,
        grain: 0.07,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('DIARY', style: AppText.eyebrow(color: AppColors.oxblood)),
                  const Spacer(),
                  Flexible(
                    child: Text('NO. ${ticket.serial.split('-').last}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.data(
                            size: 9, spacing: 0.6, color: AppColors.inkSoft)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Stars(rating: ticket.rating),
              const SizedBox(height: 16),
              Text(
                ticket.oneLiner.isEmpty ? '한 줄 평을 남겨보세요' : ticket.oneLiner,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(
                  size: 19,
                  color:
                  ticket.oneLiner.isEmpty ? AppColors.pulp : AppColors.oxblood,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(color: AppColors.pulp),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    ticket.note.isEmpty ? '아직 감상문이 없습니다.' : ticket.note,
                    style: AppText.ui(
                      size: 13,
                      color:
                      ticket.note.isEmpty ? AppColors.pulp : AppColors.inkSoft,
                      height: 1.75,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('WITH',
                      style: AppText.eyebrow(
                          color: AppColors.inkSoft.withValues(alpha: .6))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ticket.companion.isEmpty ? '—' : ticket.companion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.data(
                          size: 10, spacing: 0.6, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final on = i < rating;
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Icon(
            on ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 18,
            color: on ? AppColors.foil : AppColors.pulp,
          ),
        );
      }),
    );
  }
}