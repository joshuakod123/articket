import 'dart:convert';
import 'package:flutter/material.dart';

/// 에디터 캔버스에 올라가는 요소의 종류.
///
/// 값을 **더할 때는 끝에** 붙이세요. 저장은 이름으로 하지만(`kind.name`),
/// 중간에 끼워 넣으면 이 enum을 인덱스로 쓰는 코드가 조용히 어긋납니다.
enum LayerKind { sticker, text, tape, photo, stamp }

/// 스크랩북 캔버스의 레이어 하나.
///
/// 좌표는 캔버스 크기에 대한 0.0~1.0 비율로 저장합니다.
/// 화면 크기가 달라져도 배치가 유지되고, 서버에 그대로 직렬화할 수 있습니다.
class ScrapLayer {
  ScrapLayer({
    required this.id,
    required this.kind,
    required this.content,
    this.dx = 0.5,
    this.dy = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color = 0xFFE8E2D4,
    this.fontSize = 16,
    this.font = 'hand',
  });

  final String id;
  final LayerKind kind;

  /// sticker → `art:star` 또는 이모지 / text → 문자열
  /// tape → 무늬 이름(`plain`·`stripe`…) / photo → 파일 경로
  /// stamp → `모양|윗글자|가운뎃글자|아랫글자` ([StampSpec] 참고)
  String content;

  double dx;
  double dy;
  double scale;

  /// 라디안.
  double rotation;

  int color;
  double fontSize;

  /// 글자 레이어의 서체. `FolderFont`의 이름을 그대로 씁니다.
  /// 인덱스가 아니라 이름으로 저장해, 나중에 서체를 끼워 넣어도 안 깨집니다.
  String font;

  Offset offsetIn(Size canvas) => Offset(dx * canvas.width, dy * canvas.height);

  ScrapLayer copyWith({String? id, String? content}) => ScrapLayer(
    id: id ?? this.id,
    kind: kind,
    content: content ?? this.content,
    dx: dx,
    dy: dy,
    scale: scale,
    rotation: rotation,
    color: color,
    fontSize: fontSize,
    font: font,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'kind': kind.name,
    'content': content,
    'dx': dx,
    'dy': dy,
    'scale': scale,
    'rotation': rotation,
    'color': color,
    'fontSize': fontSize,
    'font': font,
  };

  factory ScrapLayer.fromMap(Map<String, dynamic> m) => ScrapLayer(
    id: m['id'] as String,
    kind: LayerKind.values.firstWhere(
          (e) => e.name == m['kind'],
      orElse: () => LayerKind.sticker,
    ),
    content: m['content'] as String,
    dx: (m['dx'] as num).toDouble(),
    dy: (m['dy'] as num).toDouble(),
    scale: (m['scale'] as num).toDouble(),
    rotation: (m['rotation'] as num).toDouble(),
    color: m['color'] as int,
    fontSize: (m['fontSize'] as num).toDouble(),
    font: m['font'] as String? ?? 'hand',
  );

  static String encodeList(List<ScrapLayer> layers) =>
      jsonEncode(layers.map((l) => l.toMap()).toList());

  static List<ScrapLayer> decodeList(String raw) => (jsonDecode(raw) as List)
      .map((e) => ScrapLayer.fromMap(e as Map<String, dynamic>))
      .toList();
}