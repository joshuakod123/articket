import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';
import '../widgets/scaled_canvas.dart';
import '../widgets/ticket_canvas.dart';
import '../widgets/ticket_card.dart';
import 'editor_screen.dart';
import 'share_card_screen.dart';
import 'ticket_style_sheet.dart';
import 'record_sheet.dart';

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
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
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
    final gyro = _gyro;
    if (gyro != null) unawaited(gyro.cancel().catchError((Object _) {}));
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final ticket = store.byId(widget.ticketId);
      if (ticket == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('없는 티켓이에요')),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('나의 티켓'),
          actions: [
            IconButton(
              tooltip: ticket.isFavorite ? '즐겨찾기 해제' : '즐겨찾기',
              onPressed: () {
                ticket.isFavorite = !ticket.isFavorite;
                store.touch();
              },
              icon: Icon(
                ticket.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                color: ticket.isFavorite ? AppColors.accent : AppColors.ink,
              ),
            ),
            IconButton(
              tooltip: '공유하기',
              onPressed: () => _share(ticket),
              icon: const Icon(Icons.ios_share),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'delete') {
                  _confirmDelete(ticket);
                } else {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) =>
                        TicketStyleSheet(ticket: ticket, store: store),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'style', child: Text('티켓 스타일')),
                PopupMenuItem(value: 'delete', child: Text('티켓 삭제')),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
          children: [
            SizedBox(
              height: ticket.frame.horizontal ? 240 : 455,
              child: Center(
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
                          child: TicketCanvas(ticket: ticket, tilt: _tilt),
                        ),
                        back: TicketBack(ticket: ticket),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Center(
              child: AnimatedBuilder(
                animation: _flip,
                builder: (context, _) => TextButton.icon(
                  onPressed: _toggle,
                  icon: const Icon(
                    Icons.flip_camera_android_outlined,
                    size: 18,
                  ),
                  label: Text(_showingBack ? '앞면 보기' : '뒷면 보기'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('나의 별점'),
                const Spacer(),
                Text(
                  ticket.rating == 0 ? '아직 남기지 않았어요' : '★' * ticket.rating,
                  style: AppText.ui(size: 22, color: AppColors.accent),
                ),
              ],
            ),
            if (ticket.oneLiner.isNotEmpty) ...[
              const Divider(),
              Text(ticket.oneLiner, style: AppText.hand(size: 24)),
            ],
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        openRecordSheet(context, ticket: ticket, store: store),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('기록 수정'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EditorScreen(ticketId: ticket.id),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                    label: const Text('꾸미기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  /// 티켓 한 장을 9:16 카드로 만들어 SNS로 내보냅니다.
  void _share(Ticket ticket) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShareCardScreen(
          // 상세 화면에서 보던 크기(가로 300)로 그린 뒤 통째로 줄입니다.
          // 상자에 맞춰 다시 흐르면 티켓 안 글자 비율이 화면과 달라집니다.
          artwork: ScaledCanvas(
            design: Size(300, 300 / ticket.frame.aspect),
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
        title: Text(
          '이 티켓을 버릴까요?',
          style: AppText.ui(size: 16, color: AppColors.ink),
        ),
        // 사용자가 알아볼 수 있는 이름으로 묻습니다.
        content: Text(
          '「${ticket.title.replaceAll('\n', ' ')}」\n'
          '붙여둔 것도 같이 사라져요. 되돌릴 수 없어요.',
          style: AppText.ui(size: 13, height: 1.6, color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '그대로 두기',
              style: AppText.ui(size: 13, color: AppColors.ink),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              '버리기',
              style: AppText.ui(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.oxblood,
              ),
            ),
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
