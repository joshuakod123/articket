import 'package:articket/services/guide_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:articket/data/ticket_store.dart';
import 'package:articket/data/sync_service.dart';
import 'package:articket/data/local_store.dart';
import 'package:articket/models/ticket_draft.dart';
import 'package:articket/models/ticket.dart';
import 'package:articket/theme/app_theme.dart';
import 'package:articket/theme/ticket_design.dart';
import 'package:articket/widgets/ticket_canvas.dart';
import 'package:articket/widgets/ticket_card.dart';
import 'package:articket/screens/ticket_create_screen.dart';
import 'package:articket/screens/ticket_detail_screen.dart';
import 'package:articket/screens/auth/auth_screen.dart';
import 'package:articket/screens/onboarding/welcome_tour.dart';
import 'package:articket/screens/root_shell.dart';
import 'package:articket/screens/editor_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = TicketStore.instance;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    await GuideService.instance.load();
    await GuideService.instance.markEditorCoachSeen();
  });
  setUp(() async {
    await store.wipe();
  });
  Widget app(Widget page) => MaterialApp(theme: AppTheme.build(), home: page);
  void size(WidgetTester t, Size s) {
    t.view.physicalSize = s;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  testWidgets(
    'cancelling creation creates neither a ticket nor a default folder',
    (t) async {
      size(t, const Size(390, 844));
      await t.pumpWidget(app(const RootShell()));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, '+ 첫 티켓 만들기'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '취소할 기록');
      await t.pageBack();
      await t.pumpAndSettle();
      expect(store.tickets, isEmpty);
      expect(store.folders, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'creating validates fields and creates exactly one ticket and folder',
    (t) async {
      size(t, const Size(390, 844));
      await t.pumpWidget(app(const TicketCreateScreen()));
      await t.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, '티켓 만들기');
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(store.tickets, isEmpty);
      await t.enterText(find.byType(TextFormField).at(0), '오후의 미술관');
      await t.enterText(find.byType(TextFormField).at(1), '서울시립미술관');
      await t.ensureVisible(submit);
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(store.tickets.length, 1);
      expect(store.folders.length, 1);
      expect(store.tickets.single.design, TicketDesign.scrapbook);
      expect(find.byType(TicketDetailScreen), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('favorite toggles on detail and is persisted', (t) async {
    size(t, const Size(390, 844));
    store.seedSampleData();
    final ticket = store.tickets.first;

    await t.pumpWidget(app(TicketDetailScreen(ticketId: ticket.id)));

    await t.pumpAndSettle();

    await t.tap(find.byTooltip('즐겨찾기'));

    await t.pumpAndSettle();

    await t.pump();
    await store.flush();

    final saved = await LocalStore.instance.readList(LocalStore.kTickets);
    expect(ticket.isFavorite, isTrue);
    expect(
      (saved!.firstWhere((j) => j['id'] == ticket.id) as Map)['isFavorite'],
      isTrue,
    );
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'all design/frame combinations render at thumbnail and detail size',
    (t) async {
      for (final design in TicketDesign.selectable) {
        for (final frame in TicketFrame.values) {
          final ticket = TicketDraft(
            title: '아주 긴 전시 제목을 적어도 안전한 기록',
            venue: '서울시립미술관',
            design: design,
            oneLiner: '오래 머물고 싶은 색.',
            note: '감상문을 남깁니다.',
          ).build(id: 'render', folderId: 'folder')..frame = frame;
          for (final width in [62.0, 300.0]) {
            await t.pumpWidget(
              app(
                Center(
                  child: SizedBox(
                    width: width,
                    height: width / frame.aspect,
                    child: TicketCanvas(ticket: ticket),
                  ),
                ),
              ),
            );
            await t.pump();
            expect(t.takeException(), isNull);
            await t.pumpWidget(
              app(
                Center(
                  child: SizedBox(
                    width: width,
                    height: width / frame.aspect,
                    child: TicketBack(ticket: ticket),
                  ),
                ),
              ),
            );
            await t.pump();
            expect(t.takeException(), isNull);
          }
        }
      }
    },
  );
  testWidgets('login, onboarding and editor fit a narrow viewport', (t) async {
    size(t, const Size(320, 700));
    await t.pumpWidget(app(const AuthScreen()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.pumpWidget(app(const WelcomeTour()));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    store.seedSampleData();
    await t.pumpWidget(app(EditorScreen(ticketId: store.tickets.first.id)));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
  testWidgets('pending mutations are persisted before the network debounce', (
    t,
  ) async {
    await SyncService.instance.attach();
    store.seedSampleData();
    store.touch();
    await t.runAsync(() async {
      await store.flush();
      await SyncService.instance.flushLocalState();
    });
    final dirty = await LocalStore.instance.readMap(SyncService.kDirty);
    expect(dirty, isNotEmpty);
    expect(SyncService.instance.hasPendingChanges, isTrue);
    await SyncService.instance.reset();
  });
}
