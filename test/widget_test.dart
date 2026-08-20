// Articket 스모크 테스트.
//
// 아카이브 홈(파일 드로어)이 뜨고, 서류철을 열어 스크랩북까지 들어가는지,
// 서류철을 새로 만들 수 있는지 확인합니다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:articket/screens/root_shell.dart';
import 'package:articket/theme/app_theme.dart';
import 'package:articket/data/ticket_store.dart';
import 'package:articket/models/layer.dart';
import 'package:articket/models/ticket.dart';
import 'package:articket/widgets/index_tab.dart';
import 'package:articket/widgets/stamp.dart';

/// 테스트에서는 [AppGate]를 건너뛰고 본 화면만 띄웁니다.
///
/// 앱을 통째로 켜면 스플래시 900ms + 로그인 화면을 지나야 하고, 그러려면
/// 테스트마다 계정을 만들어 두어야 합니다. 여기서 보려는 건 서랍이지
/// 로그인 흐름이 아니므로 [RootShell]을 직접 물립니다.
/// (로그인·탈퇴 흐름은 따로 테스트를 씁니다)
Widget _shell() => MaterialApp(theme: AppTheme.build(), home: const RootShell());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 저장소가 진짜 파일을 건드리지 않게 가짜 prefs 를 물립니다.
    SharedPreferences.setMockInitialValues({});
    // 예전에는 TicketStore 생성자가 목업을 부어 넣었지만, 이제 load() 가
    // 첫 실행일 때만 깝니다. 테스트에서도 한 번 불러 줘야 합니다.
    await TicketStore.instance.load();
  });

  testWidgets('아카이브 홈에 서류철이 쌓여 있다', (WidgetTester tester) async {
    await tester.pumpWidget(_shell());
    await tester.pumpAndSettle();

    expect(find.text('티켓 서랍'), findsOneWidget);

    // 목업 폴더 개수만큼 서류철이 렌더링됩니다.
    final folderCount = TicketStore.instance.folders.length;
    expect(find.byType(FolderCard), findsNWidgets(folderCount));
  });

  testWidgets('서류철을 누르면 표지가 열리고 스크랩북이 나온다',
          (WidgetTester tester) async {
        await tester.pumpWidget(_shell());
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

    await tester.pumpWidget(_shell());
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
    await tester.pumpWidget(_shell());
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

  test('발권 번호는 관람한 해를 앞에 달고 그 해 안에서 겹치지 않는다', () {
    final store = TicketStore.instance;
    final byYear = <int, Set<String>>{};
    for (final t in store.tickets) {
      expect(t.isIssued, isTrue, reason: '번호가 안 찍힌 티켓: ${t.title}');
      expect(t.serial, startsWith('AK-${t.issuedYear}-'));
      final set = byYear.putIfAbsent(t.issuedYear, () => <String>{});
      expect(set.add(t.serial), isTrue, reason: '번호가 겹쳤습니다: ${t.serial}');
    }
  });

  test('한 번 찍힌 번호는 다른 티켓을 지워도 바뀌지 않는다', () {
    final store = TicketStore.instance;
    final folderId = store.folders.first.id;

    final a = Ticket(
      id: 'test-serial-a',
      folderId: folderId,
      title: '먼저 온 표',
      venue: '어딘가',
      visitedAt: DateTime(2024, 1, 2),
    );
    final b = Ticket(
      id: 'test-serial-b',
      folderId: folderId,
      title: '나중 온 표',
      venue: '어딘가',
      visitedAt: DateTime(2024, 3, 4),
    );
    store.add(a);
    store.add(b);

    final aSerial = a.serial;
    final bSerial = b.serial;
    expect(aSerial, isNot(bSerial));

    // 앞 티켓을 버려도 뒤 티켓의 번호는 **그대로**여야 합니다.
    // 예전에는 여기서 b 가 a 의 번호를 물려받았습니다.
    store.remove(a.id);
    expect(b.serial, bSerial);

    // 그리고 버린 번호는 다시 발급되지 않습니다.
    final c = Ticket(
      id: 'test-serial-c',
      folderId: folderId,
      title: '그 다음 표',
      venue: '어딘가',
      visitedAt: DateTime(2024, 6, 7),
    );
    store.add(c);
    expect(c.serial, isNot(aSerial));
    expect(c.serial, isNot(bSerial));

    store.remove(b.id);
    store.remove(c.id);
  });

  test('관람일을 고쳐도 이미 찍힌 번호는 그대로다', () {
    final store = TicketStore.instance;
    final t = Ticket(
      id: 'test-serial-d',
      folderId: store.folders.first.id,
      title: '날짜 고칠 표',
      venue: '어딘가',
      visitedAt: DateTime(2024, 8, 9),
    );
    store.add(t);
    final stamped = t.serial;

    t.visitedAt = DateTime(2023, 1, 1);
    store.touch();
    expect(t.serial, stamped);

    store.remove(t.id);
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