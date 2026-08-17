// Articket 스모크 테스트.
//
// flutter create가 만든 기본 카운터 테스트를 대체합니다.
// 아카이브 홈이 뜨고, 서류철을 열어 티켓 목록까지 들어가는지 확인합니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:articket/main.dart';
import 'package:articket/data/ticket_store.dart';
import 'package:articket/widgets/index_tab.dart';

void main() {
  testWidgets('아카이브 홈에 서류철이 쌓여 있다', (WidgetTester tester) async {
    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    expect(find.text('나의\n티켓북'), findsOneWidget);

    // 목업 폴더 개수만큼 서류철이 렌더링됩니다.
    final folderCount = TicketStore.instance.folders.length;
    expect(find.byType(FolderCard), findsNWidgets(folderCount));
  });

  testWidgets('서류철을 누르면 폴더 화면이 열린다', (WidgetTester tester) async {
    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    final first = TicketStore.instance.folders.first;
    await tester.tap(find.byType(FolderCard).first);
    await tester.pumpAndSettle();

    // 폴더 화면은 AppBar에 라벨을, 본문에 부제를 보여줍니다.
    expect(find.text(first.label), findsOneWidget);
    expect(find.text(first.subtitle), findsOneWidget);
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