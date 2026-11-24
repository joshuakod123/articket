import 'package:articket/theme/app_colors.dart';
import 'package:articket/theme/app_theme.dart';
import 'package:articket/theme/folder_style.dart';
import 'package:articket/widgets/index_tab.dart';
import 'package:articket/widgets/stamp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Korean folder labels and every stamp shape lay out and paint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final font in FolderFont.values)
                  SizedBox(
                    width: FolderTabLabel.widthOf('올해의 전시 ARTICKET', font),
                    child: FolderTabLabel(
                      text: '올해의 전시 ARTICKET',
                      font: font,
                      onColor: AppColors.ink,
                    ),
                  ),
                for (final shape in StampShape.values)
                  StampMark(
                    spec: StampSpec(
                      shape: shape,
                      top: 'ARTICKET',
                      center: '관람 완료',
                      bottom: '2026.11.24',
                    ),
                    color: AppColors.ink,
                    size: 48,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(FolderTabLabel),
      findsNWidgets(FolderFont.values.length),
    );
    expect(find.byType(StampMark), findsNWidgets(StampShape.values.length));
    expect(tester.takeException(), isNull);
  });
}
