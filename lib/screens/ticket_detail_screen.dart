import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/ticket_store.dart';
import '../models/layer.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/ticket_card.dart';
import 'editor_screen.dart';
import 'ticket_style_sheet.dart';
import '../widgets/scrap_layers.dart';
import '../widgets/paper_toast.dart';

export '../widgets/scrap_layers.dart' show buildLayerContent;

/// 티켓 한 장을 펼친 화면.
/// 스크랩북 레이어 위에 3D 플립 티켓이 얹힙니다.
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

  /// 자이로가 없는 기기(데스크톱/웹/에뮬레이터)에서도 앱이 죽지 않도록 감쌉니다.
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
    // 모션 축소 설정을 켠 사용자는 애니메이션 없이 바로 전환합니다.
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
            title: Text(ticket.serial),
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
                tooltip: '내보내기',
                icon: const Icon(Icons.ios_share),
                onPressed: () => PaperToast.show(
                  context,
                  '9:16 내보내기는 Phase 1 후반에 붙습니다',
                  detail: 'ROADMAP · PHASE 1',
                ),
              ),
              IconButton(
                tooltip: '삭제',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(ticket),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Stack(
            children: [
              // ── 스크랩북 레이어 (배경) ─────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final canvas = Size(c.maxWidth, c.maxHeight);
                      return Stack(
                        children: [
                          for (final l in ticket.layers)
                            _PlacedLayer(layer: l, canvas: canvas),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ── 플립 티켓 ─────────────────────────────
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
                          front: Hero(
                            tag: 'ticket-${ticket.id}',
                            child: TicketFront(ticket: ticket, tilt: _tilt),
                          ),
                          back: TicketBack(ticket: ticket),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const WallGrain(seed: 9),

              // ── 안내 & 액션 ───────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _ActionBar(
                  hint: _showingBack ? '탭하면 앞면' : '탭하면 감상 기록',
                  onDecorate: () => Navigator.of(context).push(
                    MaterialPageRoute(
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

  Future<void> _confirmDelete(Ticket ticket) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.stockLight,
        shape: const RoundedRectangleBorder(),
        title: Text('티켓을 버릴까요?',
            style: AppText.ui(size: 16, color: AppColors.ink)),
        content: Text('${ticket.serial}은(는) 복구할 수 없습니다.',
            style: AppText.ui(size: 13, color: AppColors.inkSoft)),
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

/// 캔버스 위 스크랩 레이어 렌더러. 에디터와 상세 화면이 공유합니다.
class _PlacedLayer extends StatelessWidget {
  const _PlacedLayer({required this.layer, required this.canvas});

  final ScrapLayer layer;
  final Size canvas;

  @override
  Widget build(BuildContext context) {
    final pos = layer.offsetIn(canvas);
    return Positioned(
      left: pos.dx,
      top: pos.dy,
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
    );
  }
}


class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.hint, required this.onDecorate});

  final String hint;
  final VoidCallback onDecorate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bg.withValues(alpha: 0), AppColors.bg],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(hint,
                  style: AppText.data(size: 10, color: AppColors.inkSoft)),
            ),
            FilledButton.icon(
              onPressed: onDecorate,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.stockLight,
                shape: const RoundedRectangleBorder(),
                padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
              icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
              label: Text('꾸미기',
                  style: AppText.ui(size: 13, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}