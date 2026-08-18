import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'frame_shapes.dart';
import 'paper.dart';
import 'poster.dart';
import 'ticket_clipper.dart' show Barcode;

/// 티켓은 "인쇄물"입니다. 인쇄물은 크기가 달라져도 **배치가 변하지 않고 축척만
/// 달라져야** 합니다. 예전 구현은 62pt 썸네일에서도 14pt 글자를 그대로 얹었기
/// 때문에, 스텁 칸(20pt 남짓)에 21pt짜리 Column이 들어가면서
/// `BOTTOM OVERFLOWED BY n PIXELS` 줄무늬가 떴습니다.
///
/// 그래서 티켓을 **항상 [ticketDesignWidth] 폭의 원도 한 장으로 그린 뒤**,
/// 주어진 상자에 맞춰 통째로 축척합니다. 이러면
///
/// - 크기가 아무리 작아져도 넘칠 수가 없고(원도에서 이미 안 넘침),
/// - 62pt 썸네일이 진짜 축소 인쇄물처럼 보이며,
/// - `compact` 분기마다 패딩·폰트를 따로 관리할 필요가 사라집니다.
const double ticketDesignWidth = 300.0;

/// 사용자의 시스템 글자 배율까지 따라가면 원도가 흔들립니다. 배율을 고정합니다.
Widget _asPrint(BuildContext context, Widget child) {
  final mq = MediaQuery.maybeOf(context);
  if (mq == null) return child;
  return MediaQuery(
    data: mq.copyWith(textScaler: TextScaler.noScaling),
    child: child,
  );
}

/// 원도를 그려서 주어진 상자에 축척해 넣습니다.
///
/// 제약이 무한대인 자리(예: Column 안에 그냥 놓인 경우)에서도 죽지 않도록
/// 원도 크기로 폴백합니다.
class _Scaled extends StatelessWidget {
  const _Scaled({required this.aspect, required this.child});

  final double aspect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final designH = ticketDesignWidth / aspect;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth ? c.maxWidth : ticketDesignWidth;
        final h = c.hasBoundedHeight ? c.maxHeight : w / aspect;

        return SizedBox(
          width: w,
          height: h,
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: ticketDesignWidth,
              height: designH,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

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

  /// 썸네일 여부. 이제 **레이아웃이 아니라 밀도만** 바꿉니다.
  /// (홀로그램·잔결처럼 작게 보면 지저분해지는 요소를 덜어냅니다)
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return _asPrint(
      context,
      _Scaled(
        aspect: ticket.frame.aspect,
        child: ClipPath(
          clipper: clipperFor(ticket.frame),
          child: PaperSurface(
            color: AppColors.stockLight,
            seed: ticket.serial.hashCode,
            grain: compact ? 0.035 : 0.055,
            child: ticket.frame.horizontal ? _horizontal() : _vertical(),
          ),
        ),
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
              ? Padding(padding: const EdgeInsets.all(12), child: _posterBlock())
              : _posterBlock(),
        ),
        if (f.hasPerforation)
          const PerforationLine(color: AppColors.pulp, inset: 14),
        Expanded(
          flex: 100 - f.flexPoster,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _Stub(ticket: ticket),
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
        const PerforationLine(
            color: AppColors.pulp, vertical: true, inset: 12),
        Expanded(
          flex: 100 - ticket.frame.flexPoster,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: _SideStub(ticket: ticket),
          ),
        ),
      ],
    );
  }

  Widget _posterBlock() {
    return Poster(
      ticket: ticket,
      tilt: tilt,
      holoStrength: compact ? 0.45 : 0.9,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppText.display(
                size: ticket.frame.horizontal ? 22 : 26,
                color: AppColors.stockLight,
              ),
            ),
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
        ),
      ),
    );
  }
}

/// 세로형 티켓의 아래 스텁. 날짜·장소 + 바코드.
///
/// 원도 폭이 고정이라 더 이상 `FittedBox` 곡예가 필요 없지만,
/// 사용자가 아주 긴 장소명을 넣는 경우를 위해 말줄임만 남겨둡니다.
class _Stub extends StatelessWidget {
  const _Stub({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 스텁 칸이 유난히 얇은 프레임(미니멀 등)에서도 안전하도록,
        // 원도 안에서 한 번 더 축소될 여지를 남깁니다.
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: _infoWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _field('DATE', ticket.dateLabel),
                  const SizedBox(height: 8),
                  _field('VENUE', ticket.venue),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Barcode(serial: ticket.serial, height: 22),
                const SizedBox(height: 4),
                Text(
                  ticket.serial,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.data(
                      size: 8, spacing: 0.6, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 원도(300pt) 기준 정보 칸의 폭.
  static const _infoWidth = 156.0;

  Widget _field(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        maxLines: 1,
        style: AppText.eyebrow(
            color: AppColors.inkSoft.withValues(alpha: .6)),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppText.data(
          size: 11,
          spacing: 0.6,
          color: AppColors.ink,
          weight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// 가로형 티켓의 오른쪽 스텁. 세로로 세운 바코드.
class _SideStub extends StatelessWidget {
  const _SideStub({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          ticket.shortDate,
          maxLines: 1,
          style: AppText.data(
            size: 12,
            spacing: 0.6,
            weight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: Center(
              child: Barcode(serial: ticket.serial, height: 16),
            ),
          ),
        ),
        Text(
          '★${ticket.rating}',
          maxLines: 1,
          style: AppText.data(size: 10, color: AppColors.foil),
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
    final short = ticket.frame.horizontal;

    return _asPrint(
      context,
      _Scaled(
        aspect: ticket.frame.aspect,
        child: ClipPath(
          clipper: clipperFor(ticket.frame),
          child: PaperSurface(
            color: AppColors.stock,
            seed: ticket.serial.hashCode + 1,
            grain: 0.07,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  18, short ? 14 : 20, 18, short ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('DIARY',
                          style: AppText.eyebrow(color: AppColors.oxblood)),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          'NO. ${ticket.serial.split('-').last}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.data(
                              size: 9, spacing: 0.6, color: AppColors.inkSoft),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: short ? 8 : 12),
                  _Stars(rating: ticket.rating),
                  SizedBox(height: short ? 8 : 14),
                  Text(
                    ticket.oneLiner.isEmpty ? '한 줄 평을 남겨보세요' : ticket.oneLiner,
                    maxLines: short ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(
                      size: short ? 15 : 18,
                      color: ticket.oneLiner.isEmpty
                          ? AppColors.pulp
                          : AppColors.ink,
                    ),
                  ),
                  SizedBox(height: short ? 8 : 14),
                  Container(height: 1, color: AppColors.line),
                  SizedBox(height: short ? 8 : 12),

                  // 감상문은 남는 만큼만 차지하고, 자리가 없으면 0까지 줄어듭니다.
                  Expanded(
                    child: Text(
                      ticket.note.isEmpty ? '' : ticket.note,
                      overflow: TextOverflow.fade,
                      style: AppText.ui(
                          size: 12, height: 1.6, color: AppColors.inkSoft),
                    ),
                  ),

                  Row(
                    children: [
                      Text('WITH',
                          style: AppText.eyebrow(
                              color: AppColors.inkSoft.withValues(alpha: .6))),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          ticket.companion.isEmpty ? '—' : ticket.companion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                          AppText.ui(size: 11, color: AppColors.inkSoft),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        ticket.dateLabel,
                        maxLines: 1,
                        style: AppText.data(
                            size: 9, spacing: 0.6, color: AppColors.pulp),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 15,
              color: i <= rating ? AppColors.foil : AppColors.pulp,
            ),
          ),
      ],
    );
  }
}