// Articket 스모크 테스트.
//
// 아카이브 홈(파일 드로어)이 뜨고, 서류철을 뽑아 스크랩북까지 들어가는지 확인합니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:articket/main.dart';
import 'package:articket/data/ticket_store.dart';
import 'package:articket/widgets/index_tab.dart';

void main() {
  testWidgets('아카이브 홈에 서류철이 세워져 있다', (WidgetTester tester) async {
    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    expect(find.text('나의 티켓북'), findsOneWidget);
    expect(find.byType(ArchiveCover), findsOneWidget);

    // 목업 폴더 개수만큼 서류철이 렌더링됩니다.
    final folderCount = TicketStore.instance.folders.length;
    expect(find.byType(FolderSpine), findsNWidgets(folderCount));
  });

  testWidgets('서류철을 누르면 스크랩북이 펼쳐진다', (WidgetTester tester) async {
    await tester.pumpWidget(const ArticketApp());
    await tester.pumpAndSettle();

    // 맨 앞(왼쪽) 서류철을 누릅니다.
    final first = TicketStore.instance.folders.first;
    await tester.tap(find.byType(FolderSpine).last, warnIfMissed: false);
    await tester.pumpAndSettle();

    // 폴더 화면은 AppBar에 라벨을, 페이지 머리말에 부제를 보여줍니다.
    expect(find.text(first.label), findsWidgets);
    expect(find.text(first.subtitle), findsWidgets);
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