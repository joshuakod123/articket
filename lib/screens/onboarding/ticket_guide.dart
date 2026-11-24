import 'package:flutter/material.dart';
import '../../widgets/coach_marks.dart';
import '../../theme/app_text.dart';

Future<void> showTicketWorkshopGuide(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('티켓 한 장 만드는 법', style: AppText.display(size: 22)),
            const SizedBox(height: 20),
            const ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('무엇을 봤는지 적어요'),
              subtitle: Text('전시명과 장소, 날짜를 입력하면 티켓이 만들어져요.'),
            ),
            const ListTile(
              leading: Icon(Icons.style_outlined),
              title: Text('티켓 얼굴을 골라요'),
              subtitle: Text('세 가지 디자인과 프레임, 사진으로 내 취향을 담아요.'),
            ),
            const ListTile(
              leading: Icon(Icons.auto_awesome_outlined),
              title: Text('그다음은 마음대로'),
              subtitle: Text('스티커와 글자를 붙이고 서류철에 보관해요.'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('알겠어요'),
              ),
            ),
          ],
        ),
      ),
    );

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
      // 도구 줄 맨 끝에 혼자 떨어져 있는 버튼이라, 이름을 불러 줍니다.
      body:
          '맨 오른쪽 「기록」이에요. 제목이랑 별점, 한 줄 평을 여기서 적으면 '
          '티켓 뒷면에 인쇄돼요.',
      pad: const EdgeInsets.fromLTRB(4, 6, 4, 6),
      side: CoachSide.above,
    ),
  ];
}
