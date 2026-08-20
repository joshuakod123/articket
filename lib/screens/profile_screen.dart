import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/folder_style.dart';
import '../widgets/folder_texture.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';
import '../widgets/scrapbook.dart' show WashiTape;
import '../widgets/ticket_canvas.dart';
import 'ticket_detail_screen.dart';

/// 관람자 이름. 앱을 켜 둔 동안 유지됩니다.
///
/// Phase 1 이후 로컬 DB(Hive/Isar)로 옮길 때 이 노티파이어만 갈아 끼우면
/// 화면 코드는 그대로 둘 수 있습니다.
final ValueNotifier<String> viewerName = ValueNotifier<String>('이름 없는 관람자');

/// 내 기록.
///
/// ## 이 화면이 왜 하얗게 비어 있었나
///
/// 예전 회원증 카드가 `Row(crossAxisAlignment: CrossAxisAlignment.stretch)` 였습니다.
/// stretch는 **바깥에서 받은 높이를 그대로 자식에게 강제로 물립니다.** 그런데 이
/// Row는 `ListView` 안에 있었고, 세로 스크롤 뷰가 자식에게 주는 높이는 무한대입니다.
/// 결국 카드가 "높이 = 무한"으로 잡히면서 그 아래 내용이 전부 화면 밖으로 밀려
/// 앱바만 남은 빈 화면이 됐습니다. (디버그 빌드였다면 빨간 오버플로 대신
/// `BoxConstraints forces an infinite height` 예외가 떴을 자리입니다)
///
/// 고치는 방법은 둘 중 하나입니다.
/// 1. `IntrinsicHeight`로 감싸 자식들의 자연 높이를 먼저 재게 하거나,
/// 2. 애초에 높이가 정해진 상자 안에 넣거나.
///
/// 여기서는 2번을 택했습니다. 회원증은 실물처럼 **비율이 정해진 카드**라서
/// `AspectRatio`로 높이를 못 박는 편이 더 정확합니다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TicketStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('MY RECORD',
            style: AppText.eyebrow(size: 12, color: AppColors.ink)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final tickets = store.tickets;
          final now = DateTime.now();
          final thisYear =
              tickets.where((t) => t.visitedAt.year == now.year).length;

          final rated = tickets.where((t) => t.rating > 0).toList();
          final avg = rated.isEmpty
              ? 0.0
              : rated.map((t) => t.rating).reduce((a, b) => a + b) /
              rated.length;

          // 가장 오래된 기록의 해 = 관람을 시작한 해.
          // 회원 번호도 같은 값에서 나옵니다(TicketStore.memberSerialText).
          final since = store.joinedYear;

          // 최근에 본 것 여섯.
          final recent = tickets.toList()
            ..sort((a, b) => b.visitedAt.compareTo(a.visitedAt));

          // 장르별 집계.
          final genres = <String, int>{};
          for (final t in tickets) {
            genres[t.genre] = (genres[t.genre] ?? 0) + 1;
          }
          final genreList = genres.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // 가장 자주 간 장소.
          final venues = <String, int>{};
          for (final t in tickets) {
            venues[t.venue] = (venues[t.venue] ?? 0) + 1;
          }
          final topVenues = venues.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return Stack(
            children: [
              const WallGrain(opacity: 0.05, seed: 73),
              ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 44),
                children: [
                  // ── 회원증 ─────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _MemberPlate(
                      total: tickets.length,
                      since: since,
                      serial: store.memberSerialText,
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── 숫자 넉 줄 ─────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _StatStrip(
                      cells: [
                        ('티켓', '${tickets.length}'),
                        ('서류철', '${store.folders.length}'),
                        ('올해', '$thisYear'),
                        ('평균', avg == 0 ? '—' : avg.toStringAsFixed(1)),
                      ],
                    ),
                  ),

                  if (recent.isNotEmpty) ...[
                    const SizedBox(height: 34),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _SectionHead('최근에 본 것', 'LATELY'),
                    ),
                    const SizedBox(height: 16),
                    _PinBoard(tickets: recent.take(6).toList()),
                  ],

                  if (genreList.isNotEmpty) ...[
                    const SizedBox(height: 34),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _SectionHead('무엇을 봤나', 'BY GENRE'),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (final e in genreList)
                            _Bar(
                              label: e.key,
                              value: e.value,
                              total: tickets.length,
                            ),
                        ],
                      ),
                    ),
                  ],

                  if (topVenues.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _SectionHead('어디에 자주 갔나', 'BY VENUE'),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          for (final e in topVenues.take(5))
                            Padding(
                              padding:
                              const EdgeInsets.symmetric(vertical: 9),
                              child: Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.foil,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.ui(
                                          size: 13.5, color: AppColors.ink),
                                    ),
                                  ),
                                  Text('${e.value}회',
                                      style: AppText.data(
                                          size: 11, color: AppColors.foil)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: _SectionHead('보관함', 'STORAGE'),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _Row(
                          icon: Icons.cloud_off_outlined,
                          title: '기기에만 저장 중',
                          subtitle: '앱을 지우면 기록도 같이 사라져요',
                          onTap: () => PaperToast.show(
                            context,
                            '클라우드 백업은 Phase 2에서 붙습니다',
                            detail: 'ROADMAP · PHASE 2',
                          ),
                        ),
                        _Row(
                          icon: Icons.ios_share,
                          title: '기록 내보내기',
                          subtitle: '티켓 전체를 파일 한 장으로',
                          onTap: () => PaperToast.show(
                            context,
                            '내보내기는 Phase 1 후반에 붙습니다',
                            detail: 'ROADMAP · PHASE 1',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),
                  Center(
                    child: Text(
                      'ARTICKET',
                      style: AppText.wordmark(
                          size: 13,
                          color: AppColors.pulp,
                          weight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 관람 회원증.
///
/// 리넨 클로스로 싼 짙은 옥스블러드 카드. 오른쪽에는 도록 표지처럼 **연도를
/// 세로로 눕혀** 크게 깔고, 왼쪽에 이름과 발급 정보를 얹었습니다.
/// 이름을 누르면 그 자리에서 고칠 수 있습니다.
///
/// ## 한 장 안에서 연도가 두 개였던 문제
///
/// 세로로 깔린 큰 숫자와 "○○년부터"는 **가장 오래된 기록의 해**(2025)를,
/// 아래쪽 번호는 `DateTime.now().year`(2026)를 쓰고 있었습니다. 게다가 그
/// 번호의 뒷자리가 **티켓 장수**여서, 티켓을 한 장 더 만들면 회원 번호가
/// 조용히 바뀌었습니다. 회원 번호가 그러면 안 됩니다.
///
/// 이제 카드 안의 모든 숫자가 [TicketStore.joinedYear] 하나에서 나오고,
/// 그게 무슨 뜻인지 `MEMBER SINCE`로 못 박아 둡니다.
class _MemberPlate extends StatelessWidget {
  const _MemberPlate({
    required this.total,
    required this.since,
    required this.serial,
  });

  final int total;
  final int since;

  /// 회원 번호(`M-2025-0006`). 티켓 발권 번호와 모양이 다릅니다.
  final String serial;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.9)),
      // 비율을 못 박습니다. ListView 안에서 높이가 무한으로 새지 않는 유일한 방법.
      child: AspectRatio(
        aspectRatio: 1.62, // 실제 신용카드 비율.
        child: FolderSurface(
          color: AppColors.oxblood,
          texture: FolderTexture.linen,
          seed: 91,
          wear: 0.7,
          child: Stack(
            children: [
              // 배경으로 깔리는 커다란 세로 연도.
              Positioned(
                right: -6,
                top: -10,
                bottom: -10,
                child: IgnorePointer(
                  child: RotatedBox(
                    quarterTurns: 1,
                    child: Center(
                      child: Text(
                        '$since',
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: AppText.plate(
                          size: 78,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('ARTICKET',
                            style: AppText.wordmark(
                                size: 11,
                                spacing: 4.5,
                                color: Colors.white
                                    .withValues(alpha: 0.85))),
                        const Spacer(),
                        // 세로로 깔린 큰 연도가 무슨 숫자인지 여기서 밝힙니다.
                        Text('MEMBER SINCE $since',
                            style: AppText.eyebrow(
                                size: 8,
                                color:
                                Colors.white.withValues(alpha: 0.55))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                        height: 1,
                        color: Colors.white.withValues(alpha: 0.22)),

                    const Spacer(),

                    // 이름.
                    GestureDetector(
                      onTap: () => _rename(context),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Flexible(
                            child: ValueListenableBuilder<String>(
                              valueListenable: viewerName,
                              builder: (context, name, _) => Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.display(
                                    size: 26, color: AppColors.stockLight),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.edit_outlined,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.45)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$since년부터 $total장',
                      style: AppText.ui(
                          size: 11.5,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),

                    const SizedBox(height: 12),
                    SizedBox(
                      height: 1,
                      child: CustomPaint(painter: _DashPainter()),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text('NO.',
                            style: AppText.eyebrow(
                                size: 7.5,
                                color: Colors.white
                                    .withValues(alpha: 0.35))),
                        const SizedBox(width: 6),
                        Text(serial,
                            style: AppText.data(
                                size: 9.5,
                                spacing: 1.4,
                                color: Colors.white
                                    .withValues(alpha: 0.55))),
                        const Spacer(),
                        Text('SEOUL',
                            style: AppText.eyebrow(
                                size: 8,
                                color:
                                Colors.white.withValues(alpha: 0.4))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 이름 고치기.
  ///
  /// ## 왜 여기서 앱이 죽었나 (`_dependents.isEmpty` 어서션)
  ///
  /// 예전 코드는 이랬습니다.
  ///
  /// ```dart
  /// final controller = TextEditingController(...);
  /// final result = await showDialog(...);
  /// controller.dispose();          // ← 여기
  /// ```
  ///
  /// `showDialog` 의 `await` 는 **`Navigator.pop` 이 불린 순간** 풀립니다.
  /// 그런데 다이얼로그는 그때 아직 화면에 있습니다. 닫히는 애니메이션이
  /// 150ms 남아 있고, 그동안 `TextField`(정확히는 `EditableText`)는 살아서
  /// 이 컨트롤러를 계속 듣고 있습니다.
  ///
  /// 즉 **살아 있는 위젯이 쓰는 컨트롤러를 먼저 죽인** 것입니다. 사라지는
  /// 도중의 `EditableText` 가 폐기된 컨트롤러를 건드리며 예외를 던지고,
  /// 그 예외 때문에 엘리먼트 트리의 `deactivate` 순회가 중간에 끊깁니다.
  /// 그러면 위쪽 `InheritedElement`(Theme·MediaQuery 등)는 아직 자기를
  /// 구독 중인 자손을 남긴 채 비활성화되고, 프레임워크가 그걸 잡아
  /// `framework.dart` 의 `assert(_dependents.isEmpty)` 로 터집니다.
  /// 화면을 덮은 빨간 에러는 그 **2차 증상**이었습니다.
  ///
  /// 그래서 컨트롤러의 수명을 다이얼로그 자신에게 넘깁니다.
  /// `State.dispose()` 는 위젯이 트리에서 완전히 빠진 뒤에 불리므로,
  /// "쓰는 쪽보다 먼저 죽는" 일이 구조적으로 불가능해집니다.
  /// (이 프로젝트의 다른 컨트롤러들은 이미 전부 이 방식입니다.)
  Future<void> _rename(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: viewerName.value),
    );

    if (result == null) return;
    final name = result.trim();
    if (name.isEmpty) return;
    viewerName.value = name;
  }
}

/// 이름을 묻는 작은 다이얼로그.
///
/// 컨트롤러를 **자기가 만들고 자기가 버립니다.** 이게 핵심입니다.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
  TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    // 다이얼로그가 트리에서 완전히 빠진 뒤에 불립니다. 안전합니다.
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.stockLight,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      title: Text('뭐라고 부를까요',
          style: AppText.display(size: 18, color: AppColors.ink)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 14,
        textInputAction: TextInputAction.done,
        style: AppText.ui(size: 15, color: AppColors.ink),
        cursorColor: AppColors.oxblood,
        decoration: InputDecoration(
          counterText: '',
          hintText: '이름 없는 관람자',
          hintStyle: AppText.ui(size: 15, color: AppColors.pulp),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.line),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.oxblood, width: 1.4),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('그대로',
              style: AppText.ui(size: 13, color: AppColors.inkSoft)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('바꾸기',
              style: AppText.ui(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.oxblood)),
        ),
      ],
    );
  }
}

/// 회원증의 절취선.
class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0.5), Offset(x + 3.2, 0.5), p);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => false;
}

/// 숫자 넉 칸. 높이를 고정해 두어 어떤 스크롤 안에서도 안전합니다.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.cells});

  final List<(String, String)> cells;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      child: PaperSurface(
        color: AppColors.stock,
        grain: 0.05,
        fiber: 0.6,
        seed: 33,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border.all(color: AppColors.line)),
          child: Row(
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0)
                  Container(width: 1, height: 40, color: AppColors.line),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cells[i].$2,
                          maxLines: 1,
                          style: AppText.plate(
                              size: 24, color: AppColors.foil)),
                      const SizedBox(height: 3),
                      Text(cells[i].$1,
                          maxLines: 1,
                          style: AppText.ui(
                              size: 10.5,
                              height: 1.0,
                              color: AppColors.inkSoft)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 최근 티켓을 핀으로 꽂아 둔 판.
///
/// 목록으로 세우면 그냥 리스트가 됩니다. 살짝씩 다른 각도로 눕히고 테이프를
/// 한 조각씩 붙여, 벽에 꽂아둔 것처럼 보이게 했습니다.
class _PinBoard extends StatelessWidget {
  const _PinBoard({required this.tickets});

  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 206,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        itemCount: tickets.length,
        itemBuilder: (context, i) {
          final t = tickets[i];
          // 같은 자리에 늘 같은 각도가 나오도록 인덱스로 고정합니다.
          final tilt = (math.sin(i * 2.7) * 0.035);

          return Padding(
            padding: const EdgeInsets.only(right: 18),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TicketDetailScreen(ticketId: t.id),
                ),
              ),
              child: Transform.rotate(
                angle: tilt,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        SizedBox(
                          height: 150,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                boxShadow: paperShadow(depth: 0.45)),
                            child: AspectRatio(
                              aspectRatio: t.frame.aspect,
                              child: TicketCanvas(
                                ticket: t,
                                compact: true,
                                showLayers: false,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: -7,
                          child: WashiTape(
                            width: 44,
                            height: 15,
                            color: AppColors.foil.withValues(alpha: 0.42),
                            angle: -0.06 + tilt * 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      t.dateLabel,
                      maxLines: 1,
                      softWrap: false,
                      style: AppText.hand(size: 16, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.ko, this.en);

  final String ko;
  final String en;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(ko,
            style: AppText.ui(
                size: 13, weight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(width: 10),
        Text(en, style: AppText.eyebrow(color: AppColors.pulp)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: AppColors.line)),
      ],
    );
  }
}

/// 장르 분포 막대. 색 대신 길이만으로 읽힙니다.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(size: 12.5, color: AppColors.ink)),
              ),
              Text('$value',
                  style: AppText.data(size: 10.5, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                Container(height: 6, color: AppColors.line),
                Container(
                  height: 6,
                  width: c.maxWidth * ratio,
                  color: AppColors.foil.withValues(alpha: 0.85),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.ui(size: 13.5, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.ui(size: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.pulp),
          ],
        ),
      ),
    );
  }
}

/// 통계에 쓰는 작은 확장. 화면 밖에서도 재활용할 수 있게 남겨둡니다.
extension TicketStats on List<Ticket> {
  int get ratedCount => where((t) => t.rating > 0).length;
}