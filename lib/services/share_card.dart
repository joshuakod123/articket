import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 화면에 그려진 것을 그대로 이미지로 떠서 다른 앱으로 넘깁니다.
///
/// 스크린샷과 다른 점은 **필요한 부분만, 화면 해상도보다 높게** 뜬다는 것입니다.
/// `pixelRatio: 3`으로 떠서 인스타그램 스토리(1080×1920)에 올려도 종이 결과
/// 바코드가 뭉개지지 않습니다.
class ShareCard {
  ShareCard._();

  /// [key]가 달린 [RepaintBoundary]를 PNG로 떠서 공유 시트를 엽니다.
  ///
  /// 이미지 파일은 임시 폴더에 만듭니다. 사용자가 공유를 취소해도
  /// OS가 알아서 정리하므로 따로 지우지 않습니다.
  static Future<void> shareBoundary(
      GlobalKey key, {
        String name = 'articket',
        String? text,
        double pixelRatio = 3,
        double? targetWidth,
      }) async {
    final file = await captureToFile(
      key,
      name: name,
      pixelRatio: pixelRatio,
      targetWidth: targetWidth,
    );
    if (file == null) return;

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }

  /// 이미지만 파일로 떠서 돌려줍니다. (공유 시트는 열지 않습니다)
  /// [targetWidth]를 주면 **화면에 그려진 크기와 상관없이** 그 가로 픽셀로
  /// 떠냅니다. 작은 폰이든 태블릿이든 결과 이미지가 항상 같은 해상도라
  /// 인스타그램에 올렸을 때 화질이 들쭉날쭉하지 않습니다.
  static Future<File?> captureToFile(
      GlobalKey key, {
        String name = 'articket',
        double pixelRatio = 3,
        double? targetWidth,
      }) async {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) return null;

    // 아직 첫 프레임이 안 그려졌으면 한 프레임 기다립니다.
    if (object.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }

    var ratio = pixelRatio;
    if (targetWidth != null && object.hasSize && object.size.width > 0) {
      ratio = (targetWidth / object.size.width).clamp(1.0, 8.0);
    }

    final image = await object.toImage(pixelRatio: ratio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return null;

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/${name}_$stamp.png');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }
}