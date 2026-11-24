import 'package:articket/screens/settings_screen.dart';
import 'package:articket/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> openSettings(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.build(), home: const SettingsScreen()),
    );
    await tester.tap(find.text('계정 정보'));
    await tester.pumpAndSettle();
  }

  testWidgets('rename closes with the keyboard and can reopen safely', (
    tester,
  ) async {
    await openSettings(tester, const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '새로운 이름');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pump();
    tester.view.resetViewInsets();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('계정 정보'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '다시 열기');
    await tester.tapAt(const Offset(10, 100));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('rename fits a short viewport while the keyboard is visible', (
    tester,
  ) async {
    await openSettings(tester, const Size(568, 320));
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '가로 화면');
    final save = find.widgetWithText(FilledButton, '저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
