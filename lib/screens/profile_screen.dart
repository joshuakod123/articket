import 'package:flutter/material.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/folder_texture.dart';
import '../widgets/paper.dart';
import '../widgets/paper_toast.dart';

/// 내 정보.
///
/// 프로필 사진과 설정 목록 대신, **관람 이력을 요약한 대장(臺帳) 한 장**으로
/// 만들었습니다. 이 앱에서 사용자를 설명하는 건 계정이 아니라 본 것들입니다.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TicketStore.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('MY RECORD',
            style: AppText.eyebrow(size: 12, color: AppColors.ink)),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final tickets = store.tickets;
          final now = DateTime.now();
          final thisYear =
              tickets.where((t) => t.visitedAt.year == now.year).length;

          final rated = tickets.where((t) => t.rating > 0).toList();
          final avg = rated.isEmpty
              ? 0.0
              : rated.map((t) => t.rating).reduce((a, b) => a + b) /
              rated.length;

          // 장르별 집계.
          final genres = <String, int>{};
          for (final t in tickets) {
            genres[t.genre] = (genres[t.genre] ?? 0) + 1;
          }
          final genreList = genres.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // 가장 자주 간 장소.
          final venues = <String, int>{};
          for (final t in tickets) {
            venues[t.venue] = (venues[t.venue] ?? 0) + 1;
          }
          final topVenues = venues.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return Stack(
            children: [
              const WallGrain(opacity: 0.05, seed: 73),
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  _Ledger(
                    tickets: tickets.length,
                    folders: store.folders.length,
                    thisYear: thisYear,
                    average: avg,
                  ),
                  const SizedBox(height: 30),

                  if (genreList.isNotEmpty) ...[
                    const _SectionHead('무엇을 봤나', 'BY GENRE'),
                    const SizedBox(height: 14),
                    for (final e in genreList)
                      _Bar(
                        label: e.key,
                        value: e.value,
                        total: tickets.length,
                      ),
                    const SizedBox(height: 30),
                  ],

                  if (topVenues.isNotEmpty) ...[
                    const _SectionHead('어디에 자주 갔나', 'BY VENUE'),
                    const SizedBox(height: 10),
                    for (final e in topVenues.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.ui(
                                    size: 13.5, color: AppColors.ink),
                              ),
                            ),
                            Text('${e.value}회',
                                style: AppText.data(
                                    size: 11, color: AppColors.foil)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],

                  const _SectionHead('보관함', 'STORAGE'),
                  const SizedBox(height: 10),
                  _Row(
                    icon: Icons.cloud_off_outlined,
                    title: '기기에만 저장 중',
                    subtitle: '앱을 지우면 기록도 함께 사라집니다',
                    onTap: () => PaperToast.show(
                      context,
                      '클라우드 백업은 Phase 2에서 붙습니다',
                      detail: 'ROADMAP · PHASE 2',
                    ),
                  ),
                  _Row(
                    icon: Icons.ios_share,
                    title: '기록 내보내기',
                    subtitle: '티켓 전체를 파일 한 장으로',
                    onTap: () => PaperToast.show(
                      context,
                      '내보내기는 Phase 1 후반에 붙습니다',
                      detail: 'ROADMAP · PHASE 1',
                    ),
                  ),

                  const SizedBox(height: 34),
                  Center(
                    child: Text(
                      'ARTICKET',
                      style: AppText.wordmark(
                          size: 13,
                          color: AppColors.pulp,
                          weight: FontWeight.w400),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 숫자 넷을 큼직하게 찍은 대장.
class _Ledger extends StatelessWidget {
  const _Ledger({
    required this.tickets,
    required this.folders,
    required this.thisYear,
    required this.average,
  });

  final int tickets;
  final int folders;
  final int thisYear;
  final double average;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.6)),
      child: PaperSurface(
        color: AppColors.stockLight,
        grain: 0.06,
        seed: 5,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('LEDGER',
                      style: AppText.eyebrow(color: AppColors.oxblood)),
                  const Spacer(),
                  Text(
                    '${DateTime.now().year}',
                    style: AppText.data(
                        size: 9, spacing: 1.6, color: AppColors.pulp),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DebossedText(
                '지금까지 $tickets장',
                depth: 0.35,
                style: AppText.display(size: 26, color: AppColors.ink),
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: AppColors.line),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Cell(label: '서류철', value: '$folders'),
                  _Cell(label: '올해', value: '$thisYear'),
                  _Cell(
                    label: '평균 별점',
                    value: average == 0 ? '—' : average.toStringAsFixed(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppText.eyebrow(
                  color: AppColors.inkSoft.withValues(alpha: 0.7))),
          const SizedBox(height: 6),
          Text(value,
              style: AppText.plate(size: 26, color: AppColors.foil)),
        ],
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead(this.ko, this.en);

  final String ko;
  final String en;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(ko,
            style: AppText.ui(
                size: 13, weight: FontWeight.w600, color: AppColors.ink)),
        const SizedBox(width: 10),
        Text(en, style: AppText.eyebrow(color: AppColors.pulp)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: AppColors.line)),
      ],
    );
  }
}

/// 장르 분포 막대. 색 대신 길이만으로 읽힙니다.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.value,
    required this.total,
  });

  final String label;
  final int value;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : value / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.ui(size: 12.5, color: AppColors.ink)),
              ),
              Text('$value',
                  style:
                  AppText.data(size: 10.5, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  children: [
                    Container(height: 6, color: AppColors.line),
                    Container(
                      height: 6,
                      width: c.maxWidth * ratio,
                      color: AppColors.foil.withValues(alpha: 0.8),
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

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.inkSoft),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.ui(size: 13.5, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                      AppText.ui(size: 11, color: AppColors.inkSoft)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.pulp),
          ],
        ),
      ),
    );
  }
}

/// 통계에 쓰는 작은 확장. 화면 밖에서도 재활용할 수 있게 남겨둡니다.
extension TicketStats on List<Ticket> {
  int get ratedCount => where((t) => t.rating > 0).length;
}