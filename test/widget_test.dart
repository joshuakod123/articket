// Articket 스모크 테스트.
//
// 아카이브 홈(파일 드로어)이 뜨고, 서류철을 열어 스크랩북까지 들어가는지,
// 서류철을 새로 만들 수 있는지 확인합니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:articket/main.dart';
import 'package:articket/data/ticket_store.dart';
import 'package:articket/widgets/index_tab.dart';

void main() {
  testWidgets('아카이브 홈에 서류철이 쌓여 있다', (WidgetTester tester) async {
    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    expect(find.text('나의 티켓북'), findsOneWidget);

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

  testWidgets('저장소가 폴더별 티켓을 걸러낸다', (WidgetTester tester) async {
    final store = TicketStore.instance;
    for (final folder in store.folders) {
      final tickets = store.ticketsIn(folder.id);
      expect(tickets.every((t) => t.folderId == folder.id), isTrue);
      expect(tickets.length, store.countIn(folder.id));
    }
  });
}