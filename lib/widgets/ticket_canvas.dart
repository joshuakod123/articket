import 'package:flutter/material.dart';

import '../models/layer.dart';
import '../models/ticket.dart';
import 'scrap_layers.dart';
import 'ticket_card.dart';

/// 티켓 한 장 **위에** 스크랩 레이어가 얹힌 한 덩어리.
///
/// 좌표 기준이 티켓이라는 점(그래서 뒤집으면 같이 넘어간다는 점)은 그대로고,
/// 여기에 **축척**을 더했습니다.
///
/// 그전에는 레이어의 위치만 비율이고 크기는 절대값이었습니다.
/// `fontSize: 24`짜리 글자는 에디터(폭 300pt)에서든 스크랩북 페이지(폭 150pt)에서든
/// 똑같이 24pt로 그려졌습니다. 그래서 작게 줄어든 티켓 위에서는 글자만 두 배로
/// 커 보이며 티켓 밖으로 뛰쳐나갔습니다.
/// (스크랩북에서 "우와 사랑해"가 페이지를 가로지르던 게 이 문제입니다)
///
/// 해결은 [TicketFront]와 같은 방식입니다. **항상 [ticketDesignWidth] 폭의 원도
/// 한 장으로 그리고 통째로 축척합니다.** 티켓과 레이어가 같은 배율로 줄어드니
/// 에디터에서 본 그림이 어디서든 그대로 나옵니다.
class TicketCanvas extends StatelessWidget {
  const TicketCanvas({
    super.key,
    required this.ticket,
    this.tilt = 0,
    this.compact = false,
    this.showLayers = true,
  });

  final Ticket ticket;
  final double tilt;
  final bool compact;

  /// 뒷면이나 아주 작은 썸네일에서는 레이어를 숨깁니다.
  final bool showLayers;

  @override
  Widget build(BuildContext context) {
    final designH = ticketDesignWidth / ticket.frame.aspect;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth ? c.maxWidth : ticketDesignWidth;
        final h = c.hasBoundedHeight ? c.maxHeight : w / ticket.frame.aspect;

        return SizedBox(
          width: w,
          height: h,
          child: FittedBox(
            fit: BoxFit.fill,
            // 붙인 것이 티켓 밖으로 조금 삐져나오는 건 자연스럽습니다.
            clipBehavior: Clip.none,
            child: SizedBox(
              width: ticketDesignWidth,
              height: designH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: TicketFront(
                      ticket: ticket,
                      tilt: tilt,
                      compact: compact,
                    ),
                  ),
                  if (showLayers)
                    for (final layer in ticket.layers)
                      PlacedLayer(
                        layer: layer,
                        // 기준은 화면도, 실제 렌더 크기도 아닌 **원도**입니다.
                        canvas: Size(ticketDesignWidth, designH),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 캔버스 좌표에 얹힌 레이어 한 장. (편집 불가, 보기 전용)
class PlacedLayer extends StatelessWidget {
  const PlacedLayer({
    super.key,
    required this.layer,
    required this.canvas,
  });

  final ScrapLayer layer;

  /// 좌표의 기준이 되는 사각형.
  final Size canvas;

  @override
  Widget build(BuildContext context) {
    final pos = layer.offsetIn(canvas);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: IgnorePointer(
        child: FractionalTranslation(
          translation: const Offset(-0.5, -0.5),
          child: Transform.rotate(
            angle: layer.rotation,
            child: Transform.scale(
              scale: layer.scale,
              child: buildLayerContent(layer),
            ),
          ),
        ),
      ),
    );
  }
}

/// 자유 배치에서 티켓이 처음 놓이는 자리. 페이지 대비 0~1 비율입니다.
///
/// 두 열로 어긋나게 떨어뜨려 처음부터 서로 완전히 겹치지 않게 합니다.
/// 꾸미기 화면과 스크랩북 화면이 **같은 함수**를 봐야 자리가 어긋나지 않습니다.
Offset defaultTicketPlacement(int index) {
  final col = index.isEven ? 0.31 : 0.69;
  final row = 0.24 + (index ~/ 2) * 0.28;
  return Offset(col, row.clamp(0.16, 0.84));
}