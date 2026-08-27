/// 티켓 한 장을 만드는 순서 안내.
///
/// ## 왜 따로 있나
///
/// 첫 투어([WelcomeTour])는 **앱이 무엇인지**를 말합니다 — 서랍이 있고,
/// 서류철이 있고, 티켓이 있다. 그런데 이 앱을 여는 진짜 이유인
/// **"그래서 티켓은 어떻게 만드는데"** 는 아무 데서도 알려주지 않았습니다.
/// 사용자는 티켓을 뽑은 뒤 빈 티켓 한 장 앞에서 멈춥니다.
///
/// 이 파일이 그 구멍을 둘로 나눠 메웁니다.
///
/// | 언제 | 무엇 |
/// |---|---|
/// | 첫 발권 **직전** | [showTicketWorkshopGuide] — 세 단계 한 장짜리 안내 |
/// | 에디터 **첫 진입** | [ticketEditorCoachSteps] — 실제 버튼을 도려내는 코치 마크 |
///
/// 앞의 것은 "무슨 일이 벌어질지"를, 뒤의 것은 "이 버튼이 무엇인지"를 말합니다.
/// 둘 다 각각 딱 한 번 뜨고, 설정에서 다시 볼 수 있습니다.
///
/// ## 말투
///
/// 안내는 **사람이 말을 거는 자리**입니다. 티켓·회원증·표제지에 인쇄된
/// 글자는 합니다체를 지키지만, 여기서는 해요체로 짧게 말합니다.
/// 좋은 점을 설명하지 않고 다음에 할 일만 말합니다.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../../theme/feel.dart';
import '../../widgets/coach_marks.dart';
import '../../widgets/paper.dart';
import '../../widgets/stub_button.dart';

// ─────────────────────────────────────────────────────────────
// 1. 첫 발권 직전 — 세 단계 안내
// ─────────────────────────────────────────────────────────────

/// 티켓을 만들기 직전에 한 번 뜨는 시트. 닫히면 발권이 이어집니다.
Future<void> showTicketWorkshopGuide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x77120E08),
    builder: (_) => const _WorkshopSheet(),
  );
}

@immutable
class _Step {
  const _Step({
    required this.plate,
    required this.no,
    required this.title,
    required this.body,
  });

  final _Plate plate;
  final String no;
  final String title;
  final String body;
}

enum _Plate { write, face, decorate }

const _steps = <_Step>[
  _Step(
    plate: _Plate.write,
    no: '01',
    title: '무엇을 봤는지 적어요',
    body: '제목이랑 장소, 별점. 한 줄 평까지 적으면 티켓 뒷면에 인쇄돼요.',
  ),
  _Step(
    plate: _Plate.face,
    no: '02',
    title: '티켓 얼굴을 골라요',
    body: '모양은 여섯 가지. 포스터 자리에는 찍어둔 사진을 넣거나 색으로 채워요.',
  ),
  _Step(
    plate: _Plate.decorate,
    no: '03',
    title: '그다음은 마음대로',
    body: '스티커, 도장, 손글씨, 테이프. 끌어서 옮기고 두 손가락으로 돌려요.',
  ),
];

class _WorkshopSheet extends StatelessWidget {
  const _WorkshopSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(boxShadow: paperShadow(depth: 1.1)),
          child: PaperSurface(
            color: AppColors.stockLight,
            grain: 0.05,
            seed: 61,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 표제. 여기만 인쇄물 말투를 유지합니다.
                  Text('HOW TO MAKE ONE',
                      style: AppText.eyebrow(color: AppColors.foil, size: 9)),
                  const SizedBox(height: 10),
                  Text(
                    '티켓 한 장 만드는 법',
                    style: AppText.display(size: 25, color: AppColors.ink),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '순서대로 안 해도 괜찮아요. 나중에 다 고쳐져요.',
                    style: AppText.ui(
                        size: 12.5, height: 1.6, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 18),
                  Container(height: 1, color: AppColors.line),

                  for (final s in _steps) _StepRow(step: s),

                  const SizedBox(height: 20),
                  Center(
                    child: TicketStubButton(
                      onPressed: () {
                        Feel.stamp();
                        Navigator.of(context).maybePop();
                      },
                      label: '만들러 가기',
                      code: 'GO',
                      width: 220,
                    ),
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

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(painter: _PlatePainter(step.plate)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(step.no,
                        style: AppText.data(size: 9.5, color: AppColors.foil)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(height: 1, color: AppColors.line),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(step.title,
                    style: AppText.ui(
                        size: 14.5,
                        weight: FontWeight.w600,
                        color: AppColors.ink)),
                const SizedBox(height: 5),
                Text(step.body,
                    style: AppText.ui(
                        size: 12.5, height: 1.62, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 삽화 — 선으로만 그린 도판 석 장
// ─────────────────────────────────────────────────────────────

/// 스크린샷을 쓰지 않는 이유는 [WelcomeTour] 와 같습니다.
/// 화면이 바뀌어도 실루엣은 계속 맞습니다.
class _PlatePainter extends CustomPainter {
  const _PlatePainter(this.plate);

  final _Plate plate;

  static const _design = 56.0;

  Paint get _line => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.3
    ..strokeCap = StrokeCap.round
    ..color = AppColors.ink;

  Paint get _thin => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round
    ..color = AppColors.pulp;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / _design;
    canvas.save();
    canvas.translate(
      (size.width - _design * s) / 2,
      (size.height - _design * s) / 2,
    );
    canvas.scale(s);

    switch (plate) {
      case _Plate.write:
        _write(canvas);
      case _Plate.face:
        _face(canvas);
      case _Plate.decorate:
        _decorate(canvas);
    }

    canvas.restore();
  }

  /// 01 — 캡션 카드에 적히는 글줄과 별.
  void _write(Canvas canvas) {
    final card = Rect.fromLTWH(6, 9, 44, 38);
    canvas.drawRect(card, _line);

    // 라벨 두 줄.
    for (var i = 0; i < 2; i++) {
      final y = 18.0 + i * 8;
      canvas.drawLine(Offset(12, y), Offset(30, y), _thin);
      canvas.drawLine(Offset(12, y + 3), Offset(42, y + 3), _thin);
    }

    // 별 세 개 — 별점.
    for (var i = 0; i < 3; i++) {
      _star(canvas, Offset(15.0 + i * 8, 40), 3.2);
    }
  }

  /// 02 — 좌우가 물린 티켓 실루엣 + 포스터 자리.
  void _face(Canvas canvas) {
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(13, 6, 30, 44),
        const Radius.circular(2),
      ));
    final holes = Path()
      ..addOval(Rect.fromCircle(center: const Offset(13, 34), radius: 3.4))
      ..addOval(Rect.fromCircle(center: const Offset(43, 34), radius: 3.4));

    canvas.drawPath(Path.combine(PathOperation.difference, body, holes), _line);

    // 포스터 자리 — 대각선 두 줄로 "그림이 들어갈 칸"임을 표시.
    final poster = const Rect.fromLTWH(18, 11, 20, 18);
    canvas.drawRect(poster, _thin);
    canvas.drawLine(poster.topLeft, poster.bottomRight, _thin);
    canvas.drawLine(poster.topRight, poster.bottomLeft, _thin);

    // 절취선.
    for (double x = 15; x < 41; x += 4) {
      canvas.drawLine(Offset(x, 34), Offset(x + 2, 34), _thin);
    }
  }

  /// 03 — 티켓 위에 비뚜름하게 얹힌 조각들.
  void _decorate(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(10, 10, 30, 38),
        const Radius.circular(2),
      ),
      _thin,
    );

    // 테이프 한 조각.
    canvas.save();
    canvas.translate(14, 12);
    canvas.rotate(-0.32);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 17, 6), _line);
    canvas.restore();

    // 별 스티커.
    _star(canvas, const Offset(37, 26), 5.4);

    // 도장 — 동그라미 안 짧은 줄.
    canvas.drawCircle(const Offset(21, 33), 7, _line);
    canvas.drawLine(const Offset(17, 33), const Offset(25, 33), _thin);

    // 손글씨 한 줄.
    final scrawl = Path()..moveTo(13, 44);
    for (var i = 0; i < 4; i++) {
      final x = 13.0 + i * 6;
      scrawl.quadraticBezierTo(x + 3, i.isEven ? 40 : 48, x + 6, 44);
    }
    canvas.drawPath(scrawl, _thin);
  }

  void _star(Canvas canvas, Offset c, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.44;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = Offset(c.dx + rr * math.cos(a), c.dy + rr * math.sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), _line);
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.plate != plate;
}

// ─────────────────────────────────────────────────────────────
// 2. 에디터 코치 마크
// ─────────────────────────────────────────────────────────────

/// 에디터에 처음 들어왔을 때 도려내 보여줄 자리들.
///
/// 네 단계를 넘기지 않습니다. 다섯 장째부터는 아무도 읽지 않고 건너뛰기만
/// 찾습니다. 그래서 되돌리기는 자기 단계를 갖지 않고 **필요해지는 순간의
/// 본문**(붙이기 단계)에 한 줄로 얹었습니다.
///
/// 키가 아직 레이아웃되지 않았으면 [CoachStep] 이 알아서 구멍 없이
/// 카드만 띄웁니다. 툴바가 가로로 스크롤되어 화면 밖에 있는 버튼이 있어도
/// 안내가 깨지지 않습니다.
List<CoachStep> ticketEditorCoachSteps({
  required GlobalKey canvasKey,
  required GlobalKey faceKey,
  required GlobalKey decorateKey,
  required GlobalKey recordKey,
}) {
  return [
    CoachStep(
      target: canvasKey,
      eyebrow: 'STEP 01',
      title: '여기가 티켓 한 장이에요',
      body: '붙인 건 한 손가락으로 끌어 옮기고, 두 손가락으로 돌리거나 크기를 바꿔요.',
      pad: const EdgeInsets.all(12),
      side: CoachSide.below,
    ),
    CoachStep(
      target: faceKey,
      eyebrow: 'STEP 02',
      title: '모양과 포스터',
      body: '티켓 모양은 여섯 가지예요. 포스터 자리에는 사진을 넣거나 색으로 채워요.',
      pad: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      side: CoachSide.above,
    ),
    CoachStep(
      target: decorateKey,
      eyebrow: 'STEP 03',
      title: '붙이는 것들',
      body: '골라서 톡 누르면 티켓 가운데에 얹혀요. 마음에 안 들면 위쪽 ↩︎ 로 되돌리면 돼요.',
      pad: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      side: CoachSide.above,
    ),
    CoachStep(
      target: recordKey,
      eyebrow: 'STEP 04',
      title: '뒷면에 적기',
      body: '제목이랑 별점, 한 줄 평은 여기서 적어요. 적은 건 티켓 뒷면에 인쇄돼요.',
      pad: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      side: CoachSide.above,
    ),
  ];
}