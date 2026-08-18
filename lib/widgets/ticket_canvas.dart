import 'package:flutter/material.dart';

import '../models/layer.dart';
import '../models/ticket.dart';
import 'scrap_layers.dart';
import 'ticket_card.dart';

/// 티켓 한 장 **위에** 스크랩 레이어가 얹힌 한 덩어리.
///
/// 예전에는 레이어를 화면 전체(`Scaffold`의 `Stack`)에 깔고 그 위에 티켓을
/// 얹었습니다. 그래서 좌표가 **화면 기준**이었고,
///
/// - 티켓을 뒤집으면 레이어만 배경에 남았고,
/// - 티켓 크기·프레임이 바뀌면 붙여둔 자리가 어긋났고,
/// - 다른 기기에서 열면 스티커가 티켓 밖으로 밀려났습니다.
///
/// 레이어의 `dx`/`dy`는 원래부터 0~1 비율이므로, **기준 사각형만 티켓으로
/// 바꾸면** 전부 해결됩니다. 이 위젯이 그 기준을 티켓 자신으로 못 박습니다.
///
/// 붙인 것이 티켓 밖으로 조금 삐져나오는 건 자연스러우므로
/// `clipBehavior: Clip.none`으로 잘라내지 않습니다.
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

  /// 뒷면이나 썸네일에서는 레이어를 숨깁니다.
  final bool showLayers;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // 부모가 AspectRatio/SizedBox로 크기를 정해 주는 게 정상입니다.
        final canvas = Size(
          c.hasBoundedWidth ? c.maxWidth : ticketDesignWidth,
          c.hasBoundedHeight
              ? c.maxHeight
              : (c.hasBoundedWidth ? c.maxWidth : ticketDesignWidth) /
              ticket.frame.aspect,
        );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: TicketFront(ticket: ticket, tilt: tilt, compact: compact),
            ),
            if (showLayers)
              for (final layer in ticket.layers)
                PlacedLayer(layer: layer, canvas: canvas),
          ],
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

  /// 좌표의 기준이 되는 사각형. 이제 화면이 아니라 **티켓**입니다.
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