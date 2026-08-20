// Articket 스모크 테스트.
//
// 아카이브 홈(파일 드로어)이 뜨고, 서류철을 열어 스크랩북까지 들어가는지,
// 서류철을 새로 만들 수 있는지 확인합니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:articket/main.dart';
import 'package:articket/data/ticket_store.dart';
import 'package:articket/models/layer.dart';
import 'package:articket/models/ticket.dart';
import 'package:articket/widgets/index_tab.dart';
import 'package:articket/widgets/stamp.dart';

void main() {
  testWidgets('아카이브 홈에 서류철이 쌓여 있다', (WidgetTester tester) async {
    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    expect(find.text('티켓 서랍'), findsOneWidget);

    // 목업 폴더 개수만큼 서류철이 렌더링됩니다.
    final folderCount = TicketStore.instance.folders.length;
    expect(find.byType(FolderCard), findsNWidgets(folderCount));
  });

  testWidgets('서류철을 누르면 표지가 열리고 스크랩북이 나온다',
          (WidgetTester tester) async {
        await tester.pumpWidget(const ArticketApp());
        await tester.pumpAndSettle();

        final first = TicketStore.instance.folders.first;
        // 맨 위 서류철의 탭 부분(윗변 근처)을 누릅니다. 아래 서류철이 몸통을 덮기 때문입니다.
        await tester.tapAt(
          tester.getTopLeft(find.byType(FolderCard).first) + const Offset(40, 50),
        );
        await tester.pumpAndSettle();

        // 폴더 화면은 AppBar에 라벨을, 페이지 머리말에 부제를 보여줍니다.
        expect(find.text(first.label), findsWidgets);
        expect(find.text(first.subtitle), findsWidgets);
      });

  testWidgets('서류철을 새로 만들 수 있다', (WidgetTester tester) async {
    final store = TicketStore.instance;
    final before = store.folders.length;

    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('서류철 만들기'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '테스트 서류철');
    await tester.tap(find.text('서류철 만들기'));
    await tester.pumpAndSettle();

    expect(store.folders.length, before + 1);
    expect(find.byType(FolderCard), findsNWidgets(before + 1));

    // 다음 테스트에 영향을 주지 않도록 되돌립니다.
    store.removeFolder(store.folders.last.id);
  });

  testWidgets('아래 탭바로 달력·내 기록으로 건너간다', (WidgetTester tester) async {
    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    // 달력.
    await tester.tap(find.text('달력'));
    await tester.pumpAndSettle();
    expect(find.text('CALENDAR'), findsOneWidget);

    // 내 기록. 예전에 빈 화면이던 자리에 회원증이 떠야 합니다.
    await tester.tap(find.text('내 기록'));
    await tester.pumpAndSettle();
    expect(find.text('MY RECORD'), findsOneWidget);
    // 회원증 머리말은 이제 "무슨 연도인지"까지 말합니다.
    expect(
      find.text('MEMBER SINCE ${TicketStore.instance.joinedYear}'),
      findsOneWidget,
    );

    // 서랍으로 복귀.
    await tester.tap(find.text('서랍'));
    await tester.pumpAndSettle();
    expect(find.text('티켓 서랍'), findsOneWidget);
  });

  testWidgets('저장소가 폴더별 티켓을 걸러낸다', (WidgetTester tester) async {
    final store = TicketStore.instance;
    for (final folder in store.folders) {
      final tickets = store.ticketsIn(folder.id);
      expect(tickets.every((t) => t.folderId == folder.id), isTrue);
      expect(tickets.length, store.countIn(folder.id));
    }
  });


  // ── 발권 번호 ─────────────────────────────────
  //
  // 예전에는 번호가 목업에 손으로 적혀 있거나(`AK-2026-00114`),
  // "전체 티켓 수 + 1"로 만들어졌습니다. 지우고 만들면 번호가 겹쳤고,
  // 2026년 첫 관람이 114번이었습니다.

  test('발권 번호는 관람한 해 기준으로 1번부터 매겨진다', () {
    final store = TicketStore.instance;
    for (final t in store.tickets) {
      expect(t.serial, startsWith('AK-${t.visitedAt.year}-'));
    }

    // 같은 해 안에서 번호가 겹치지 않는다.
    final byYear = <int, Set<String>>{};
    for (final t in store.tickets) {
      final set = byYear.putIfAbsent(t.visitedAt.year, () => <String>{});
      expect(set.add(t.serial), isTrue, reason: '번호가 겹쳤습니다: ${t.serial}');
    }

    // 그 해의 첫 티켓은 반드시 001번이다.
    for (final year in byYear.keys) {
      expect(byYear[year], contains('AK-$year-001'));
    }
  });

  test('티켓을 넣고 빼면 번호가 다시 매겨진다', () {
    final store = TicketStore.instance;
    final folderId = store.folders.first.id;

    final fresh = Ticket(
      id: 'test-serial-1',
      folderId: folderId,
      title: '번호 시험',
      venue: '어딘가',
      // 아주 이른 날짜 → 그 해 1번이 되어야 합니다.
      visitedAt: DateTime(2024, 1, 2),
    );
    store.add(fresh);
    expect(fresh.serial, 'AK-2024-001');

    // 발권 번호를 넘기지 않아도 store가 채웁니다.
    expect(store.tickets.where((t) => t.serial.isEmpty), isEmpty);

    store.remove(fresh.id);
    expect(store.tickets.any((t) => t.id == fresh.id), isFalse);
  });

  test('회원 번호는 티켓을 추가해도 바뀌지 않는다', () {
    final store = TicketStore.instance;
    final before = store.memberSerialText;

    final fresh = Ticket(
      id: 'test-member-1',
      folderId: store.folders.first.id,
      title: '회원 번호 시험',
      venue: '어딘가',
      // 시작 연도보다 나중이라 joinedYear는 그대로여야 합니다.
      visitedAt: DateTime(store.joinedYear + 1, 5, 5),
    );
    store.add(fresh);
    expect(store.memberSerialText, before);

    store.remove(fresh.id);
    expect(store.memberSerialText, before);
  });

  // ── 도장 ─────────────────────────────────────

  test('도장 내용은 접었다 펴도 그대로다', () {
    const spec = StampSpec(
      shape: StampShape.scallop,
      top: 'ARTICKET',
      center: '관람 완료',
      bottom: '2026.07.14',
    );
    final again = StampSpec.decode(spec.encode());

    expect(again.shape, spec.shape);
    expect(again.top, spec.top);
    expect(again.center, spec.center);
    expect(again.bottom, spec.bottom);
  });

  test('도장 구분자가 섞여 들어와도 깨지지 않는다', () {
    const spec = StampSpec(center: 'a|b|c', top: '', bottom: '');
    final again = StampSpec.decode(spec.encode());
    expect(again.center, 'a b c');
    expect(again.shape, StampShape.circle);
  });

  test('도장 레이어를 저장했다 불러올 수 있다', () {
    final layer = ScrapLayer(
      id: 'stamp-1',
      kind: LayerKind.stamp,
      content: const StampSpec(center: '관람 완료').encode(),
      fontSize: 96,
    );
    final back = ScrapLayer.decodeList(ScrapLayer.encodeList([layer])).single;

    expect(back.kind, LayerKind.stamp);
    expect(StampSpec.decode(back.content).center, '관람 완료');
    expect(back.fontSize, 96);
  });

}