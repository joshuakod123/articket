import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'paper.dart';

/// 서랍에 세워 꽂은 서류철 한 장의 실루엣.
///
/// 위쪽 오른편에 인덱스 탭이 돌출되고, 몸통은 서랍 바닥까지 곧게 내려갑니다.
/// [tab]을 끄면 탭 없는 매끈한 표지가 됩니다.
class SpineShape extends CustomClipper<Path> {
  SpineShape({
    this.tabHeight = 34,
    this.tabWidth = 60,
    this.slant = 8,
    this.radius = 5,
    this.tab = true,
  });

  final double tabHeight;
  final double tabWidth;

  /// 탭 옆면 기울기. 서류철 특유의 사다리꼴 각도.
  final double slant;
  final double radius;
  final bool tab;

  @override
  Path getClip(Size size) {
    final r = radius;
    final w = size.width;
    final h = size.height;

    if (!tab || tabWidth >= w) {
      return Path()
        ..moveTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }

    final t = tabHeight;
    final shoulder = w - tabWidth;

    return Path()
      ..moveTo(0, t + r)
      ..quadraticBezierTo(0, t, r, t)
      ..lineTo(shoulder, t)
      ..lineTo(shoulder + slant, r)
      ..quadraticBezierTo(shoulder + slant + 1, 0, shoulder + slant + r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
  }

  @override
  bool shouldReclip(SpineShape old) =>
      old.tabWidth != tabWidth || old.tabHeight != tabHeight || old.tab != tab;
}

/// 서랍에 꽂힌 서류철 한 장.
///
/// 세로로 세운 큰 제목, 위쪽에 끼워둔 사진 창, 돌출된 인덱스 탭으로 이루어집니다.
class FolderSpine extends StatelessWidget {
  const FolderSpine({
    super.key,
    required this.folder,
    required this.count,
    required this.onTap,
    this.lifted = false,
    this.photo = const [],
    this.fileNo = 1,
  });

  final ArchiveFolder folder;
  final int count;
  final VoidCallback onTap;

  /// 눌린 순간 살짝 뽑혀 올라옵니다.
  final bool lifted;

  /// 위쪽 사진 창에 채울 그라디언트. 티켓이 없으면 빈 판이 들어갑니다.
  final List<Color> photo;

  /// 밑동에 찍히는 정리 번호.
  final int fileNo;

  static const _tabHeight = 34.0;
  static const _tabWidth = 60.0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${folder.subtitle}, 티켓 $count장',
      child: GestureDetector(
        onTap: onTap,
        child: PhysicalShape(
          clipper: SpineShape(tabHeight: _tabHeight, tabWidth: _tabWidth),
          color: folder.color,
          shadowColor: const Color(0xFF3B2F1E),
          elevation: lifted ? 16 : 7,
          child: Stack(
            children: [
              // 서류철 표면의 결.
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter:
                      GrainPainter(opacity: 0.11, seed: folder.id.hashCode),
                    ),
                  ),
                ),
              ),

              // 왼쪽 접힌 모서리의 빛.
              Positioned(
                left: 0,
                top: _tabHeight,
                bottom: 0,
                width: 4,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 오른쪽으로 갈수록 지는 그늘. 서류철끼리 겹쳐 보이게 합니다.
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 16,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 인덱스 탭에 찍은 분류 코드.
              Positioned(
                right: 9,
                top: 11,
                width: _tabWidth - 20,
                child: Text(
                  _code,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: AppText.data(
                    size: 7,
                    spacing: 1.1,
                    weight: FontWeight.w700,
                    color: AppColors.stockLight.withValues(alpha: 0.88),
                  ),
                ),
              ),

              // 위쪽에 끼워둔 사진 창.
              Positioned(
                left: 9,
                right: 9,
                top: _tabHeight + 12,
                height: 116,
                child: _PhotoWindow(colors: photo, seed: folder.id.hashCode),
              ),

              // 세로로 세운 제목.
              Positioned(
                left: 0,
                right: 6,
                top: _tabHeight + 144,
                bottom: 14,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            folder.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: AppText.ui(
                              size: 19,
                              weight: FontWeight.w700,
                              height: 1.05,
                              spacing: -0.2,
                              color: AppColors.stockLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          count == 0 ? 'EMPTY' : '$count',
                          style: AppText.data(
                            size: 11,
                            spacing: 0.6,
                            weight: FontWeight.w700,
                            color: AppColors.stockLight.withValues(alpha: 0.55),
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            folder.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: AppText.data(
                              size: 8,
                              spacing: 2.0,
                              color:
                              AppColors.stockLight.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 서류철 밑동의 정리 번호.
              Positioned(
                left: 10,
                bottom: 8,
                child: Text(
                  'FILE_${fileNo.toString().padLeft(2, '0')}',
                  style: AppText.data(
                    size: 7,
                    spacing: 1.0,
                    color: AppColors.stockLight.withValues(alpha: 0.34),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 탭에 찍는 짧은 코드. 라벨이 길면 뒤쪽 한 토막만 씁니다.
  String get _code {
    final parts = folder.label.split('/').map((s) => s.trim()).toList();
    final tail = parts.isEmpty ? folder.label : parts.last;
    return tail.length > 9 ? tail.substring(0, 9) : tail;
  }
}

/// 서류철 위쪽에 끼워둔 사진/색지 한 장.
class _PhotoWindow extends StatelessWidget {
  const _PhotoWindow({required this.colors, required this.seed});

  final List<Color> colors;
  final int seed;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      // 아직 아무것도 끼워두지 않은 서류철.
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.stockLight.withValues(alpha: 0.28),
          ),
        ),
        child: Center(
          child: Text(
            'NO FILM',
            style: AppText.data(
              size: 7,
              spacing: 1.6,
              color: AppColors.stockLight.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final fill = colors.length >= 2 ? colors : [colors.first, AppColors.ink];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: fill,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: CustomPaint(
              painter: GrainPainter(opacity: 0.07, seed: seed + 3),
            ),
          ),
          // 인화지 흰 테두리 한 겹.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.stockLight.withValues(alpha: 0.34),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 서랍 맨 앞에 세워둔 표지. 아카이브 전체를 요약합니다.
class ArchiveCover extends StatelessWidget {
  const ArchiveCover({
    super.key,
    required this.total,
    required this.folders,
  });

  final int total;
  final int folders;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;

    return PhysicalShape(
      clipper: SpineShape(tab: false),
      color: AppColors.ink,
      shadowColor: const Color(0xFF3B2F1E),
      elevation: 10,
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: GrainPainter(opacity: 0.13, seed: 21),
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 18,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 표지 위쪽의 황동 라벨 판.
          Positioned(
            left: 14,
            right: 14,
            top: 18,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.foil.withValues(alpha: 0.7),
                ),
              ),
              child: Center(
                child: Text(
                  'ARCHIVE',
                  style: AppText.data(
                    size: 9,
                    spacing: 3.0,
                    weight: FontWeight.w700,
                    color: AppColors.foil,
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            top: 84,
            bottom: 16,
            child: RotatedBox(
              quarterTurns: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'ARTICKET_$year',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: AppText.data(
                          size: 26,
                          spacing: -0.6,
                          weight: FontWeight.w700,
                          color: AppColors.stockLight,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '$folders FOLDERS · $total FILED',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                        style: AppText.data(
                          size: 8,
                          spacing: 1.6,
                          color: AppColors.stockLight.withValues(alpha: 0.45),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 서랍 바닥. 종이 밑동이 닿는 그늘.
class DrawerFloor extends StatelessWidget {
  const DrawerFloor({super.key, this.height = 26});

  final double height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: AppColors.pulp),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.bgDeep,
                      AppColors.bgDeep.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 서랍 레이아웃 상수.
class SpineMetrics {
  const SpineMetrics._();

  static const width = 106.0;

  /// 앞 서류철이 뒤 서류철을 덮는 만큼.
  static const overlap = 24.0;
  static const coverWidth = 132.0;
  static const leftPad = 18.0;
  static const gapAfterCover = 8.0;

  static double get step => width - overlap;

  /// i번째 서류철의 왼쪽 좌표.
  static double xOf(int i) =>
      leftPad + coverWidth + gapAfterCover + i * step;

  /// 인덱스 탭이 서로 가리지 않도록 서류철마다 높이를 어긋나게 둡니다.
  static double stagger(int i) => (i % 3) * 15.0;

  static double drawerWidth(int folders) =>
      xOf(math.max(0, folders - 1)) + width + 22;
}