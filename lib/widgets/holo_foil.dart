import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'paper.dart';

/// 회절 포일 오버레이. 셰이더가 되면 셰이더로, 안 되면 기존 그라디언트로.
///
/// ## 폴백이 필수인 이유
///
/// [ui.FragmentProgram]은 Impeller 전제입니다. 웹, 아주 오래된 기기, 일부
/// 데스크톱 구성에서는 로드 자체가 실패할 수 있습니다. 그래서 **실패를
/// 정상 경로로 취급**합니다. 이 앱이 자이로를 다루는 방식과 같습니다 —
/// 없으면 없는 대로 조용히 동작합니다.
///
/// 셰이더를 못 쓰면 [HoloOverlay]가 그대로 뜹니다. 사용자는 조금 덜 화려한
/// 홀로그램을 볼 뿐, 빈 화면이나 에러를 보지 않습니다.
///
/// ## 설치
///
/// `pubspec.yaml` 의 `flutter:` 아래에 셰이더를 등록해야 합니다.
///
/// ```yaml
/// flutter:
///   uses-material-design: true
///   shaders:
///     - shaders/holo_foil.frag
/// ```
///
/// 등록을 빠뜨려도 앱은 죽지 않고 폴백으로 돌아갑니다.
class HoloFoil extends StatefulWidget {
  const HoloFoil({
    super.key,
    required this.tilt,
    this.strength = 1.0,
    this.seed = 0,
  });

  /// 자이로 기울기 -1.0 ~ 1.0. 센서가 없으면 0.
  final double tilt;

  /// 0이면 완전히 투명. 프레임별로 페이드할 때 씁니다.
  final double strength;

  /// 티켓마다 표면 무늬가 달라지도록.
  final int seed;

  @override
  State<HoloFoil> createState() => _HoloFoilState();
}

class _HoloFoilState extends State<HoloFoil> {
  /// 프로그램은 앱 전체에서 한 번만 컴파일합니다.
  static Future<ui.FragmentProgram?>? _program;

  /// 한 번 실패하면 다시 시도하지 않습니다. 매 프레임 예외를 삼키는 것보다
  /// 조용히 폴백에 머무는 편이 낫습니다.
  static bool _unavailable = false;

  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 웹은 런타임 셰이더 지원이 들쭉날쭉합니다. 시도하지 않습니다.
    if (kIsWeb || _unavailable) return;

    _program ??= _compile();
    final program = await _program;
    if (!mounted || program == null) return;

    setState(() => _shader = program.fragmentShader());
  }

  static Future<ui.FragmentProgram?> _compile() async {
    try {
      return await ui.FragmentProgram.fromAsset('shaders/holo_foil.frag');
    } catch (e) {
      // 에셋 미등록, 컴파일 실패, 미지원 백엔드 — 전부 같은 처리.
      debugPrint('[HoloFoil] 셰이더를 쓸 수 없어 그라디언트로 대체합니다: $e');
      _unavailable = true;
      return null;
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;

    if (shader == null) {
      return HoloOverlay(tilt: widget.tilt, strength: widget.strength);
    }

    return IgnorePointer(
      child: CustomPaint(
        painter: _FoilPainter(
          shader: shader,
          tilt: widget.tilt.clamp(-1.0, 1.0),
          strength: widget.strength.clamp(0.0, 1.0),
          seed: (widget.seed % 997).toDouble(),
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _FoilPainter extends CustomPainter {
  _FoilPainter({
    required this.shader,
    required this.tilt,
    required this.strength,
    required this.seed,
  });

  final ui.FragmentShader shader;
  final double tilt;
  final double strength;
  final double seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || strength <= 0) return;

    // 선언 순서 = 인덱스 순서. .frag 의 uniform 순서와 반드시 맞아야 합니다.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, tilt)
      ..setFloat(3, strength)
      ..setFloat(4, seed);

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = shader
        ..blendMode = BlendMode.screen,
    );
  }

  @override
  bool shouldRepaint(_FoilPainter old) =>
      old.tilt != tilt || old.strength != strength || old.seed != seed;
}