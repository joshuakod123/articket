import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import 'holo_foil.dart';
import 'paper.dart';

/// 티켓의 포스터 영역.
///
/// 사진을 골랐으면 그 사진을, 아니면 고른 색 그라디언트를 채웁니다.
/// 홀로그램 텍스처가 켜져 있으면 자이로 기울기에 따라 펄이 흐릅니다.
class Poster extends StatelessWidget {
  const Poster({
    super.key,
    required this.ticket,
    this.tilt = 0,
    this.holoStrength = 0.9,
    this.child,
  });

  final Ticket ticket;
  final double tilt;
  final double holoStrength;

  /// 포스터 위에 겹칠 내용(제목 등).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _fill(),
        // 사진 위 글씨가 묻히지 않도록 아래쪽만 살짝 어둡게.
        if (ticket.hasPhoto)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xB3000000)],
                stops: [0.45, 1.0],
              ),
            ),
          ),
        if (ticket.holographic)
        // 셰이더가 되면 회절 포일, 안 되면 조용히 그라디언트로 폴백합니다.
          HoloFoil(
            tilt: tilt,
            strength: holoStrength,
            seed: ticket.id.hashCode,
          ),
        if (child != null) child!,
      ],
    );
  }

  Widget _fill() {
    if (ticket.hasPhoto && !kIsWeb) {
      final file = File(ticket.posterPath!);
      return Image.file(
        file,
        fit: BoxFit.cover,
        // 파일이 지워졌거나 접근할 수 없으면 색으로 되돌아갑니다.
        errorBuilder: (_, __, ___) => _gradient(),
      );
    }
    return _gradient();
  }

  Widget _gradient() => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: ticket.posterTint.length >= 2
            ? ticket.posterTint
            : [ticket.posterTint.first, AppColors.ink],
      ),
    ),
  );
}