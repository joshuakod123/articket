import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/paper.dart';

/// 기록 시트를 엽니다.
Future<void> openRecordSheet(
    BuildContext context, {
      required Ticket ticket,
      required TicketStore store,
    }) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => RecordSheet(ticket: ticket, store: store),
  );
}

/// 전시명 · 장소 · 날짜 · 별점 · 감상을 적는 곳.
///
/// 예전에는 라벨과 밑줄만 세로로 늘어선 폼이라, 앱의 다른 화면과 재질이 달랐습니다.
/// 이 화면을 **미술관 벽에 붙은 캡션 카드**로 다시 짰습니다.
///
/// - 위쪽에 전시명이 표제처럼 크게 서고, 그 아래 얇은 황동 괘선.
/// - 라벨은 전부 타자기 고정폭 대문자(`TITLE` / `VENUE` / `DATE`)로 왼쪽에 붙습니다.
/// - 별점은 도장을 찍듯 큼직하게, 누르면 촉감이 옵니다.
/// - 한 줄 평은 **손글씨 서체로 입력**되어, 적는 동안 이미 스크랩북 글씨입니다.
/// - 감상문 칸에는 옅은 괘선이 깔려 정말 노트에 적는 것처럼 보입니다.
class RecordSheet extends StatefulWidget {
  const RecordSheet({super.key, required this.ticket, required this.store});

  final Ticket ticket;
  final TicketStore store;

  @override
  State<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<RecordSheet> {
  late final _title = TextEditingController(text: widget.ticket.title);
  late final _venue = TextEditingController(text: widget.ticket.venue);
  late final _oneLiner = TextEditingController(text: widget.ticket.oneLiner);
  late final _note = TextEditingController(text: widget.ticket.note);
  late final _companion = TextEditingController(text: widget.ticket.companion);

  late int _rating = widget.ticket.rating;
  late DateTime _visited = widget.ticket.visitedAt;
  late String _genre = widget.ticket.genre;

  static const _genres = ['미술', '미디어아트', '사진', '공예', '건축', '공연', '기타'];

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _oneLiner.dispose();
    _note.dispose();
    _companion.dispose();
    super.dispose();
  }

  void _save() {
    final messenger = Navigator.of(context);
    final title = _title.text.trim();

    widget.ticket
      ..title = title.isEmpty ? '제목 없는 전시' : title
      ..venue = _venue.text.trim().isEmpty ? '장소 미정' : _venue.text.trim()
      ..visitedAt = _visited
      ..genre = _genre
      ..rating = _rating
      ..oneLiner = _oneLiner.text.trim()
      ..note = _note.text.trim()
      ..companion = _companion.text.trim();
    widget.store.touch();

    HapticFeedback.mediumImpact();
    messenger.pop();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _visited,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.oxblood,
            onPrimary: AppColors.stockLight,
            surface: AppColors.stockLight,
            onSurface: AppColors.ink,
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: AppColors.stockLight,
            shape: RoundedRectangleBorder(),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _visited = picked);
  }

  String get _dateLabel =>
      '${_visited.year}.${_two(_visited.month)}.${_two(_visited.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Stack(
        children: [
          Positioned.fill(
            child: PaperSurface(
              color: AppColors.stockLight,
              grain: 0.055,
              seed: widget.ticket.id.hashCode,
              child: const SizedBox.expand(),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                    22,
                    18,
                    22,
                    MediaQuery.viewInsetsOf(context).bottom + 24,
                  ),
                  children: [
                    // ── 머리말 ─────────────────────────
                    Row(
                      children: [
                        Text('RECORD', style: AppText.eyebrow(color: AppColors.oxblood)),
                        const Spacer(),
                        Text(
                          widget.ticket.serial,
                          style: AppText.data(
                              size: 9, spacing: 1.2, color: AppColors.pulp),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // ── 표제 (전시명) ────────────────────
                    TextField(
                      controller: _title,
                      maxLines: 2,
                      minLines: 1,
                      style: AppText.display(size: 25, color: AppColors.ink),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: '전시 제목',
                        hintStyle:
                        AppText.display(size: 25, color: AppColors.pulp),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1.6, color: AppColors.foil),
                    const SizedBox(height: 6),
                    Container(height: 1, color: AppColors.line),
                    const SizedBox(height: 22),

                    // ── 캡션 항목 ──────────────────────
                    _CaptionField(
                      label: 'VENUE',
                      hint: '어디에서 봤나요',
                      controller: _venue,
                    ),
                    _CaptionRow(
                      label: 'DATE',
                      child: GestureDetector(
                        onTap: _pickDate,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            children: [
                              Text(
                                _dateLabel,
                                style: AppText.data(
                                  size: 14,
                                  spacing: 1.0,
                                  weight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.edit_calendar_outlined,
                                  size: 15, color: AppColors.foil),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _CaptionRow(
                      label: 'GENRE',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final g in _genres)
                              _Chip(
                                label: g,
                                on: g == _genre,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _genre = g);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    _CaptionField(
                      label: 'WITH',
                      hint: '혼자 / 누구와',
                      controller: _companion,
                    ),

                    const SizedBox(height: 26),

                    // ── 별점 ──────────────────────────
                    Text('이 전시에 몇 점을 줄까요',
                        style:
                        AppText.ui(size: 12, color: AppColors.inkSoft)),
                    const SizedBox(height: 10),
                    _Stars(
                      rating: _rating,
                      onChanged: (v) {
                        HapticFeedback.lightImpact();
                        setState(() => _rating = v);
                      },
                    ),

                    const SizedBox(height: 26),

                    // ── 한 줄 평 ───────────────────────
                    Text('한 줄 평',
                        style: AppText.ui(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      decoration: BoxDecoration(
                        color: AppColors.stock,
                        border: Border.all(color: AppColors.line),
                      ),
                      child: TextField(
                        controller: _oneLiner,
                        maxLines: 2,
                        minLines: 1,
                        style: AppText.hand(size: 24, color: AppColors.oxblood),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '한 문장으로 남긴다면',
                          hintStyle:
                          AppText.hand(size: 24, color: AppColors.pulp),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── 감상문 ─────────────────────────
                    Text('감상문',
                        style: AppText.ui(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.ink)),
                    const SizedBox(height: 6),
                    _RuledBox(
                      child: TextField(
                        controller: _note,
                        maxLines: null,
                        minLines: 5,
                        style: AppText.ui(
                            size: 13.5, height: 1.85, color: AppColors.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: '기억나는 대로, 아무렇게나 적어도 됩니다',
                          hintStyle: AppText.ui(
                              size: 13.5, height: 1.85, color: AppColors.pulp),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ── 저장 ──────────────────────────
                    _StampButton(onTap: _save),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        '적어둔 내용은 티켓 뒷면에 인쇄됩니다',
                        style: AppText.data(
                            size: 9, spacing: 0.8, color: AppColors.pulp),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 왼쪽에 고정폭 라벨, 오른쪽에 내용. 캡션 카드의 기본 한 줄.
class _CaptionRow extends StatelessWidget {
  const _CaptionRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                label,
                style: AppText.eyebrow(
                    color: AppColors.inkSoft.withValues(alpha: 0.75)),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                Container(height: 1, color: AppColors.line),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptionField extends StatelessWidget {
  const _CaptionField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _CaptionRow(
      label: label,
      child: TextField(
        controller: controller,
        style: AppText.ui(size: 14.5, color: AppColors.ink),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: hint,
          hintStyle: AppText.ui(size: 14, color: AppColors.pulp),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: on ? AppColors.ink : Colors.transparent,
          border: Border.all(color: on ? AppColors.ink : AppColors.line),
        ),
        child: Text(
          label,
          style: AppText.ui(
            size: 11.5,
            weight: on ? FontWeight.w600 : FontWeight.w400,
            color: on ? AppColors.stockLight : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// 도장 다섯 칸. 누른 만큼 황동으로 채워집니다.
class _Stars extends StatelessWidget {
  const _Stars({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          GestureDetector(
            // 같은 별을 다시 누르면 0점으로 지웁니다.
            onTap: () => onChanged(rating == i ? 0 : i),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: i <= rating
                      ? AppColors.foil.withValues(alpha: 0.14)
                      : Colors.transparent,
                  border: Border.all(
                    color: i <= rating ? AppColors.foil : AppColors.line,
                    width: i <= rating ? 1.4 : 1,
                  ),
                ),
                child: Icon(
                  i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 22,
                  color: i <= rating ? AppColors.foil : AppColors.pulp,
                ),
              ),
            ),
          ),
        const Spacer(),
        Text(
          rating == 0 ? '—' : '$rating.0',
          style: AppText.data(size: 13, color: AppColors.foil),
        ),
      ],
    );
  }
}

/// 옅은 괘선이 깔린 입력 칸. 노트에 적는 것처럼 보입니다.
class _RuledBox extends StatelessWidget {
  const _RuledBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.stock,
        border: Border.all(color: AppColors.line),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _RulePainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _RulePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.line.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    // 본문 줄간(13.5 × 1.85 ≈ 25)에 맞춘 괘선.
    for (double y = 34; y < size.height; y += 25) {
      canvas.drawLine(Offset(12, y), Offset(size.width - 12, y), p);
    }
  }

  @override
  bool shouldRepaint(_RulePainter old) => false;
}

/// 서류에 쾅 찍는 저장 도장.
class _StampButton extends StatelessWidget {
  const _StampButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(boxShadow: paperShadow(depth: 0.4)),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: AppColors.oxblood,
            border: Border.all(
              color: AppColors.stockLight.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.12),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'FILE',
                      style: AppText.data(
                        size: 10,
                        spacing: 2.6,
                        weight: FontWeight.w700,
                        color: AppColors.stockLight.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 16,
                      color: AppColors.stockLight.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '기록 저장',
                      style: AppText.ui(
                        size: 15,
                        weight: FontWeight.w600,
                        color: AppColors.stockLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}