import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:articket/data/ticket_store.dart';
import 'package:articket/models/ticket.dart';
import 'package:articket/models/ticket_draft.dart';
import 'package:articket/services/guide_service.dart';
import 'package:articket/theme/app_colors.dart';
import 'package:articket/theme/app_theme.dart';
import 'package:articket/theme/ticket_design.dart';
import 'package:articket/theme/folder_style.dart';
import 'package:articket/screens/root_shell.dart';
import 'package:articket/screens/auth/auth_screen.dart';
import 'package:articket/screens/folder_screen.dart';
import 'package:articket/screens/ticket_detail_screen.dart';
import 'package:articket/screens/ticket_create_screen.dart';
import 'package:articket/screens/editor_screen.dart';
import 'package:articket/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final store = TicketStore.instance;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    await GuideService.instance.load();
    await GuideService.instance.markEditorCoachSeen();
    for (final entry in {
      'AppSans': 'NotoSansKR-400.ttf',
      'TicketSerif': 'GowunBatang-Regular.ttf',
      'TicketHand': 'NanumPenScript-Regular.ttf',
      'TicketMono': 'CourierPrime-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load('assets/fonts/${entry.value}'))).load();
    }
    await (FontLoader('AppSans')
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-600.ttf'))
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-700.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (var i = 0; i < 3; i++) {
      store.addFolder(
        ArchiveFolder(
          id: 'preview-folder-$i',
          label: 'FILE 0${i + 1}',
          subtitle: ['올해의 전시', '기억할 순간', '공연의 밤'][i],
          color: [AppColors.lavender, AppColors.butter, AppColors.sage][i],
          font: FolderFont.serif,
          texture: FolderTexture.plain,
        ),
      );
    }
    for (var i = 0; i < 12; i++) {
      store.add(
        TicketDraft(
          title: ['빛과 공간', '오후의 미술관', 'FORM'][i % 3],
          venue: '서울시립미술관',
          visitedAt: DateTime(2026, 11, 21 - i),
          rating: 5,
          oneLiner: '오래 머물고 싶은 색.',
          note: '빛이 바뀔 때마다 다른 분위기가 느껴져서, 천천히 더 오래 보고 싶었다.',
          design: TicketDesign.selectable[i % 3],
        ).build(id: 'preview-ticket-$i', folderId: 'preview-folder-${i % 3}'),
      );
    }
    await store.flush();
  });
  testWidgets(
    'core screens render on a phone; optional export uses the real Flutter renderer',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final screens = <String, Widget>{
        'home': const RootShell(),
        'calendar': const RootShell(initialIndex: 1),
        'my-record': const RootShell(initialIndex: 2),
        'login': const AuthScreen(),
        'folder': FolderScreen(folder: store.folders.first),
        'ticket': TicketDetailScreen(ticketId: store.tickets[1].id),
        'create': const TicketCreateScreen(),
        'editor': EditorScreen(ticketId: store.tickets[1].id),
        'settings': const SettingsScreen(),
      };
      for (final entry in screens.entries) {
        final boundary = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            key: ValueKey(entry.key),
            theme: AppTheme.build(),
            home: RepaintBoundary(key: boundary, child: entry.value),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: entry.key);
        if (const bool.fromEnvironment('EXPORT_PREVIEWS')) {
          await t.runAsync(() async {
            final render =
                boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await render.toImage(pixelRatio: 3);
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            final dir = Directory('work/previews');
            await dir.create(recursive: true);
            await File(
              '${dir.path}/${entry.key}.png',
            ).writeAsBytes(data!.buffer.asUint8List());
          });
        }
      }
    },
  );
}
