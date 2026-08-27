import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/feel.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/paper.dart';
import '../../widgets/stub_button.dart';

/// 가입 직후 딱 한 번 뜨는 안내. **도록의 앞부속(前付)** 형식입니다.
///
/// ## 규칙 세 가지
///
/// 1. **네 장을 넘기지 않습니다.** 다섯 장째부터는 아무도 읽지 않고
///    건너뛰기만 찾습니다.
/// 2. **기능 목록이 아니라 순서를 말합니다.** "서류철을 만들고 → 티켓을 철하고
///    → 꾸미고 → 되돌아본다". 사용자가 다음에 무엇을 할지 알고 나가야 합니다.
/// 3. **삽화는 코드로 그립니다.** 스크린샷을 넣으면 화면이 바뀌는 순간
///    안내가 거짓말이 됩니다. 여기 삽화는 이 앱의 실루엣(서류철·티켓·도장)
///    그대로라 화면이 바뀌어도 계속 맞습니다.
///
/// 건너뛰기는 **처음부터 보입니다.** 숨겨두면 안내가 아니라 관문이 됩니다.
Future<void> showWelcomeTour(BuildContext context) {
  return Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => const WelcomeTour(),
      transitionsBuilder: (_, anim, __, child) {
        final t = anim.drive(CurveTween(curve: Curves.easeOutCubic));
        return FadeTransition(
          opacity: t,
          child: ScaleTransition(
            scale: t.drive(Tween<double>(begin: 0.985, end: 1)),
            child: child,
          ),
        );
      },
    ),
  );
}

class WelcomeTour extends StatefulWidget {
  const WelcomeTour({super.key});

  @override
  State<WelcomeTour> createState() => _WelcomeTourState();
}

/// 삽화 종류.
enum _Plate { drawer, file, decorate, review }

@immutable
class _Chapter {
  const _Chapter({
    required this.plate,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final _Plate plate;
  final String eyebrow;
  final String title;
  final String body;
}

const _chapters = <_Chapter>[
  _Chapter(
    plate: _Plate.drawer,
    eyebrow: 'CHAPTER 01',
    title: '표를 버리지 않는\n서랍입니다',
    body: '다녀온 전시의 티켓을 여기에 철해 둡니다.\n'
        '지갑에서 구겨지다 버려지던 조각이\n한 장씩 쌓여 한 해의 기록이 됩니다.',
  ),
  _Chapter(
    plate: _Plate.file,
    eyebrow: 'CHAPTER 02',
    title: '서류철을 만들고\n그 안에 철합니다',
    body: '연도별로, 장르별로, 마음대로 나누세요.\n'
        '서류철을 하나 만든 뒤 그 안에서\n티켓을 발권하면 번호가 찍힙니다.',
  ),
  _Chapter(
    plate: _Plate.decorate,
    eyebrow: 'CHAPTER 03',
    title: '티켓은\n꾸미라고 있습니다',
    body: '포스터를 얹고, 별점을 찍고,\n'
        '스티커·도장·테이프를 붙입니다.\n한 줄 평은 손글씨로 남습니다.',
  ),
  _Chapter(
    plate: _Plate.review,
    eyebrow: 'CHAPTER 04',
    title: '달력과 기록으로\n되돌아보기',
    body: '관람한 날은 달력에 도장처럼 남고,\n'
        '내 기록에는 회원증과 통계가 쌓입니다.\n아래 탭 세 개가 그 세 방입니다.',
  ),
];

class _WelcomeTourState extends State<WelcomeTour> {
  final _pages = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _last => _i >= _chapters.length - 1;

  void _next() {
    if (_last) {
      _finish();
      return;
    }
    Feel.pick();
    _pages.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _finish() {
    Feel.stamp();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // 스플래시·로그인과 **같은 조명**. 화면이 갈아 끼워져도 배경이 이어집니다.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.35),
                  radius: 1.1,
                  colors: [Color(0x33FFF8EA), Color(0x00FFF8EA)],
                ),
              ),
            ),
          ),
          // ⚠️ [WallGrain]은 이미 자기가 `Positioned.fill`입니다. 한 번 더
          //    감싸면 ParentDataWidget 이 둘이 되어 어서션이 납니다.
          const WallGrain(opacity: 0.05, seed: 17),

          SafeArea(
            child: Column(
              children: [
                _header(),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _chapters.length,
                    onPageChanged: (i) => setState(() => _i = i),
                    itemBuilder: (context, i) => _Page(chapter: _chapters[i]),
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 10, 12, 0),
      child: Row(
        children: [
          const PunchedWordmark(scale: 0.3, caption: ''),
          const SizedBox(width: 12),
          Expanded(
            child: Container(height: 1, color: AppColors.line),
          ),
          const SizedBox(width: 12),
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _finish,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(
                  '건너뛰기',
                  style: AppText.ui(size: 12, color: AppColors.pulp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 절취선 위의 눈금처럼 생긴 페이지 표시.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _chapters.length; i++) ...[
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  width: i == _i ? 18 : 6,
                  height: 3,
                  color: i == _i ? AppColors.oxblood : AppColors.line,
                ),
                const SizedBox(width: 5),
              ],
            ],
          ),
          const SizedBox(height: 20),
          TicketStubButton(
            onPressed: _next,
            label: _last ? '서랍 열기' : '다음',
            code: _last ? 'GO' : '${_i + 1}',
            width: 232,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 한 장
// ─────────────────────────────────────────────────────────────

class _Page extends StatelessWidget {
  const _Page({required this.chapter});

  final _Chapter chapter;

  @override
  Widget build(BuildContext context) {
    // ⚠️ 여기서 Column 을 그냥 쓰면 작은 기기·큰 글자 설정에서 몇 픽셀씩
    //    넘칩니다(로그인 화면에서 실제로 났던 그 오버플로). 최소 높이만
    //    보장하고 넘치면 스크롤되게 둡니다.
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              SizedBox(
                width: 240,
                height: 168,
                child: CustomPaint(painter: _PlatePainter(chapter.plate)),
              ),
              const SizedBox(height: 34),
              Text(chapter.eyebrow,
                  style: AppText.eyebrow(color: AppColors.foil, size: 9)),
              const SizedBox(height: 14),
              Text(
                chapter.title,
                textAlign: TextAlign.center,
                style: AppText.display(
                    size: 26, height: 1.34, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Text(
                chapter.body,
                textAlign: TextAlign.center,
                style: AppText.ui(
                    size: 13, height: 1.85, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 삽화
// ─────────────────────────────────────────────────────────────

/// 도록의 도판처럼, 선으로만 그린 삽화 넉 장.
///
/// 실루엣은 앱 안의 것과 같습니다. 서류철은 위에 사다리꼴 탭이 하나 솟아
/// 있고, 티켓은 좌우가 반원으로 물려 있습니다.
class _PlatePainter extends CustomPainter {
  const _PlatePainter(this.plate);

  final _Plate plate;

  static const _design = Size(240, 168);

  @override
  void paint(Canvas canvas, Size size) {
    // 설계 좌표(240×168)로 그리고 실제 상자에 맞춰 한 번만 늘립니다.
    final s = math.min(size.width / _design.width, size.height / _design.height);
    canvas.save();
    canvas.translate(
      (size.width - _design.width * s) / 2,
      (size.height - _design.height * s) / 2,
    );
    canvas.scale(s);

    switch (plate) {
      case _Plate.drawer:
        _drawer(canvas);
      case _Plate.file:
        _file(canvas);
      case _Plate.decorate:
        _decorate(canvas);
      case _Plate.review:
        _review(canvas);
    }

    canvas.restore();
  }

  // ── 붓 ──────────────────────────────────────────

  Paint get _line => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.4
    ..strokeJoin = StrokeJoin.round
    ..color = AppColors.ink.withValues(alpha: 0.78);

  Paint get _hair => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = AppColors.foil.withValues(alpha: 0.85);

  Paint get _paper => Paint()..color = AppColors.stockLight;

  Paint get _shade => Paint()..color = AppColors.bgDeep.withValues(alpha: 0.75);

  // ── 조각 ────────────────────────────────────────

  /// 서류철 실루엣. 위쪽 한 자리에 사다리꼴 탭이 솟습니다.
  Path _folder(Rect r, double tabStart, double tabWidth) {
    const t = 11.0;
    return Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + t)
      ..lineTo(r.left + tabStart, r.top + t)
      ..lineTo(r.left + tabStart + 4, r.top)
      ..lineTo(r.left + tabStart + tabWidth - 4, r.top)
      ..lineTo(r.left + tabStart + tabWidth, r.top + t)
      ..lineTo(r.right, r.top + t)
      ..lineTo(r.right, r.bottom)
      ..close();
  }

  /// 티켓 실루엣. 좌우 가운데가 반원으로 물려 있습니다.
  Path _ticket(Rect r) {
    const bite = 5.0;
    final body = Path()..addRect(r);
    final holes = Path()
      ..addOval(Rect.fromCircle(
          center: Offset(r.left, r.center.dy), radius: bite))
      ..addOval(Rect.fromCircle(
          center: Offset(r.right, r.center.dy), radius: bite));
    return Path.combine(PathOperation.difference, body, holes);
  }

  void _dashed(Canvas c, Offset a, Offset b, {double dash = 4, double gap = 3}) {
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var t = 0.0;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.pulp;
    while (t < total) {
      final end = math.min(t + dash, total);
      c.drawLine(a + dir * t, a + dir * end, p);
      t = end + gap;
    }
  }

  void _star(Canvas c, Offset o, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.44;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = o + Offset(math.cos(a) * rad, math.sin(a) * rad);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = AppColors.foil);
  }

  // ── 넉 장 ───────────────────────────────────────

  /// 01 — 서랍에 겹쳐 꽂힌 서류철 세 장.
  void _drawer(Canvas c) {
    // 뒤에서 앞으로. 뒤 장일수록 좁고 흐립니다.
    final back = Rect.fromLTWH(34, 26, 172, 46);
    c.drawPath(_folder(back, 18, 46), _shade);
    c.drawPath(_folder(back, 18, 46), _hair);

    final mid = Rect.fromLTWH(28, 62, 184, 46);
    c.drawPath(_folder(mid, 72, 48), _paper);
    c.drawPath(_folder(mid, 72, 48), _line);

    // 앞 서류철 뒤로 티켓 두 장이 삐죽 나옵니다.
    for (final r in [
      Rect.fromLTWH(56, 84, 32, 30),
      Rect.fromLTWH(96, 80, 28, 34),
    ]) {
      c.drawPath(_ticket(r), _paper);
      c.drawPath(_ticket(r), _hair);
    }

    final front = Rect.fromLTWH(22, 104, 196, 48);
    c.drawPath(_folder(front, 124, 52), _paper);
    c.drawPath(_folder(front, 124, 52), _line);

    // 앞판에 붙은 라벨 두 줄.
    c.drawLine(const Offset(40, 128), const Offset(96, 128), _hair);
    c.drawLine(const Offset(40, 136), const Offset(74, 136), _hair);
  }

  /// 02 — 티켓이 서류철 안으로 들어갑니다.
  void _file(Canvas c) {
    final ticket = Rect.fromLTWH(74, 14, 92, 54);
    c.drawPath(_ticket(ticket), _paper);
    c.drawPath(_ticket(ticket), _line);

    // 절취선과 발권 번호 자리.
    _dashed(c, const Offset(148, 18), const Offset(148, 64));
    c.drawLine(const Offset(84, 34), const Offset(136, 34), _hair);
    c.drawLine(const Offset(84, 44), const Offset(118, 44), _hair);

    // 들어가는 길.
    _dashed(c, const Offset(120, 74), const Offset(120, 96), dash: 5, gap: 4);
    final head = Path()
      ..moveTo(114, 92)
      ..lineTo(120, 100)
      ..lineTo(126, 92);
    c.drawPath(head, _line..strokeWidth = 1.4);

    final folder = Rect.fromLTWH(30, 96, 180, 56);
    c.drawPath(_folder(folder, 26, 50), _paper);
    c.drawPath(_folder(folder, 26, 50), _line);

    // 포켓 앞판. 티켓은 이 선 뒤로 들어갑니다.
    c.drawLine(const Offset(30, 124), const Offset(210, 124), _hair);
  }

  /// 03 — 꾸며진 티켓 한 장.
  void _decorate(Canvas c) {
    final t = Rect.fromLTWH(46, 26, 148, 108);
    c.drawPath(_ticket(t), _paper);
    c.drawPath(_ticket(t), _line);

    // 포스터 자리.
    c.drawRect(const Rect.fromLTWH(58, 38, 60, 62), _shade);
    c.drawRect(const Rect.fromLTWH(58, 38, 60, 62), _hair);

    // 제목 두 줄과 손글씨 한 줄.
    c.drawLine(const Offset(128, 44), const Offset(180, 44), _hair);
    c.drawLine(const Offset(128, 54), const Offset(166, 54), _hair);
    _dashed(c, const Offset(58, 112), const Offset(180, 112), dash: 3, gap: 3);

    // 별점 셋.
    for (var i = 0; i < 3; i++) {
      _star(c, Offset(134 + i * 17.0, 76), 7);
    }

    // 마스킹 테이프 — 왼쪽 위 모서리에 비스듬히.
    c.save();
    c.translate(46, 26);
    c.rotate(-0.42);
    c.drawRect(
      const Rect.fromLTWH(-22, -8, 52, 16),
      Paint()..color = AppColors.kraft.withValues(alpha: 0.55),
    );
    c.restore();

    // 도장 — 오른쪽 아래에 겹쳐 찍힙니다.
    final stamp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.oxblood.withValues(alpha: 0.72);
    c.drawCircle(const Offset(178, 116), 20, stamp);
    c.drawCircle(const Offset(178, 116), 15, stamp..strokeWidth = 0.8);
  }

  /// 04 — 달력과 회원증.
  void _review(Canvas c) {
    final cal = Rect.fromLTWH(24, 24, 116, 110);
    c.drawRect(cal, _paper);
    c.drawRect(cal, _line);
    c.drawLine(const Offset(24, 44), const Offset(140, 44), _line);

    // 날짜 눈금. 관람한 날에는 옥스블러드 점이 찍힙니다.
    const filled = {2, 6, 9, 13};
    for (var i = 0; i < 20; i++) {
      final col = i % 5;
      final row = i ~/ 5;
      final o = Offset(38 + col * 22.0, 60 + row * 20.0);
      if (filled.contains(i)) {
        c.drawCircle(o, 4.5, Paint()..color = AppColors.oxblood);
      } else {
        c.drawCircle(
            o,
            3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = AppColors.pulp);
      }
    }

    // 회원증.
    final card = Rect.fromLTWH(150, 56, 74, 48);
    c.drawRect(card.shift(const Offset(3, 4)), _shade);
    c.drawRect(card, _paper);
    c.drawRect(card, _line);
    c.drawLine(const Offset(158, 70), const Offset(198, 70), _hair);
    c.drawLine(const Offset(158, 80), const Offset(214, 80), _hair);
    c.drawLine(const Offset(158, 90), const Offset(186, 90), _hair);
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.plate != plate;
}