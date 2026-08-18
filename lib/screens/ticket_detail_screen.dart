import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/ticket_canvas.dart';
import '../widgets/ticket_card.dart';
import 'editor_screen.dart';
import 'share_card_screen.dart';
import 'ticket_style_sheet.dart';

// 에디터가 이 파일에서 가져다 쓰던 이름을 그대로 다시 내보냅니다.
export '../widgets/scrap_layers.dart' show buildLayerContent;

/// 티켓 한 장을 펼친 화면.
///
/// 붙여둔 스크랩 레이어는 **티켓 앞면에 함께 붙어** 있어서, 뒤집으면 같이 넘어갑니다.
/// (예전에는 화면 배경에 깔려 있어서 티켓만 돌아가고 스티커는 남았습니다)
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  final store = TicketStore.instance;

  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  StreamSubscription<GyroscopeEvent>? _gyro;
  double _tilt = 0;

  bool get _showingBack => _flip.value > 0.5;

  @override
  void initState() {
    super.initState();
    _listenGyro();
  }

  /// 자이로가 없는 기기(데스크톱/웹/시뮬레이터)에서도 죽지 않도록 감쌉니다.
  void _listenGyro() {
    try {
      _gyro = gyroscopeEventStream().listen(
            (e) {
          if (!mounted) return;
          setState(() {
            _tilt = (_tilt * 0.85 + e.y * 0.15).clamp(-1.0, 1.0);
          });
        },
        onError: (_) {},
        cancelOnError: true,
      );
    } catch (_) {
      _gyro = null;
    }
  }

  @override
  void dispose() {
    _gyro?.cancel();
    _flip.dispose();
    super.dispose();
  }

  void _toggle() {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      _flip.value = _showingBack ? 0 : 1;
      setState(() {});
      return;
    }
    _showingBack ? _flip.reverse() : _flip.forward();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ticket = store.byId(widget.ticketId);
        if (ticket == null) {
          return const Scaffold(body: Center(child: Text('삭제된 티켓입니다')));
        }

        return Scaffold(
          appBar: AppBar(
            // 발권 번호(AK-2026-…)는 사람이 읽을 정보가 아니라 내부 식별자입니다.
            // 화면 제목에는 관람일을 띄우고, 번호는 티켓 위에만 남깁니다.
            title: Text(
              ticket.dateLabel,
              style: AppText.data(size: 12, spacing: 1.6, color: AppColors.ink),
            ),
            actions: [
              IconButton(
                tooltip: '모양 바꾸기',
                icon: const Icon(Icons.crop_free),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.stockLight,
                  builder: (_) =>
                      TicketStyleSheet(ticket: ticket, store: store),
                ),
              ),
              IconButton(
                tooltip: '공유하기',
                icon: const Icon(Icons.ios_share),
                onPressed: () => _share(ticket),
              ),
              IconButton(
                tooltip: '버리기',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(ticket),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Stack(
            children: [
              const WallGrain(seed: 9),

              Center(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    ticket.frame.horizontal ? 20 : 44,
                    0,
                    ticket.frame.horizontal ? 20 : 44,
                    90,
                  ),
                  child: AspectRatio(
                    aspectRatio: ticket.frame.aspect,
                    child: GestureDetector(
                      onTap: _toggle,
                      child: AnimatedBuilder(
                        animation: _flip,
                        builder: (context, _) => _FlipCard(
                          progress: _flip.value,
                          tilt: _tilt,
                          // 앞면 = 티켓 + 붙여둔 것들. 한 몸으로 돕니다.
                          front: Hero(
                            tag: 'ticket-${ticket.id}',
                            child: TicketCanvas(ticket: ticket, tilt: _tilt),
                          ),
                          back: TicketBack(ticket: ticket),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ActionBar(
                  hint: _showingBack ? '탭하면 앞면' : '탭하면 감상 기록',
                  onDecorate: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EditorScreen(ticketId: ticket.id),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 티켓 한 장을 9:16 카드로 만들어 SNS로 내보냅니다.
  void _share(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShareCardScreen(
          artwork: AspectRatio(
            aspectRatio: ticket.frame.aspect,
            child: TicketCanvas(ticket: ticket),
          ),
          title: ticket.title.replaceAll('\n', ' '),
          subtitle: '${ticket.venue} · ${ticket.dateLabel}',
          meta: ticket.rating > 0 ? '★' * ticket.rating : '',
          fileName: 'articket_ticket',
          shareText: '${ticket.title.replaceAll('\n', ' ')} — ARTICKET',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Ticket ticket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.stockLight,
        shape: const RoundedRectangleBorder(),
        title: Text('이 티켓을 버릴까요?',
            style: AppText.ui(size: 16, color: AppColors.ink)),
        // 사용자가 알아볼 수 있는 이름으로 묻습니다.
        content: Text(
          '「${ticket.title.replaceAll('\n', ' ')}」\n'
              '붙여둔 것들도 함께 사라지고, 되돌릴 수 없습니다.',
          style: AppText.ui(size: 13, height: 1.6, color: AppColors.inkSoft),
        ),
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
    if (ok == true && mounted) {
      store.remove(ticket.id);
      Navigator.of(context).pop();
    }
  }
}

/// Y축 회전으로 앞/뒷면을 뒤집습니다.
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.progress,
    required this.front,
    required this.back,
    this.tilt = 0,
  });

  /// 0 = 앞면, 1 = 뒷면.
  final double progress;
  final Widget front;
  final Widget back;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    final angle = progress * math.pi;
    final isBack = progress > 0.5;

    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0012) // 원근
      ..rotateX(tilt * 0.05) // 자이로 미세 기울기
      ..rotateY(angle);

    return Transform(
      alignment: Alignment.center,
      transform: matrix,
      child: DecoratedBox(
        decoration: BoxDecoration(boxShadow: paperShadow(depth: 1.4)),
        // 뒷면은 한 번 더 뒤집어야 글씨가 정방향으로 보입니다.
        child: isBack
            ? Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()..rotateY(math.pi),
          child: back,
        )
            : front,
      ),
    );
  }
}

/// 화면 아래 안내 + 꾸미기 버튼.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.hint, required this.onDecorate});

  final String hint;
  final VoidCallback onDecorate;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.stock,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Stack(
        children: [
          const WallGrain(opacity: 0.05, seed: 44),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 12, color: AppColors.inkSoft),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDecorate,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 17),
                    label: Text('꾸미기',
                        style: AppText.ui(
                            size: 13, weight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.oxblood,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}