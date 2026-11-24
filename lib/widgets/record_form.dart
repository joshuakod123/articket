import 'package:material_ui/material_ui.dart';

import '../models/ticket_draft.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class RecordForm extends StatefulWidget {
  const RecordForm({super.key, required this.draft, required this.formKey});
  final TicketDraft draft;
  final GlobalKey<FormState> formKey;
  @override
  State<RecordForm> createState() => _RecordFormState();
}

class _RecordFormState extends State<RecordForm> {
  TicketDraft get d => widget.draft;
  Widget field(
    String label,
    String value,
    ValueChanged<String> change, {
    bool required = false,
    int lines = 1,
    int maxLength = 200,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.ui(size: 13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: value,
          maxLines: lines,
          maxLength: maxLength,
          decoration: InputDecoration(counterText: '', hintText: label),
          textInputAction: lines == 1
              ? TextInputAction.next
              : TextInputAction.newline,
          onChanged: change,
          validator: required
              ? (v) => v == null || v.trim().isEmpty ? '$label 입력해 주세요' : null
              : null,
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Form(
    key: widget.formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field('전시명', d.title, (v) => d.title = v, required: true),
        field('전시장', d.venue, (v) => d.venue = v, required: true),
        Text('관람일', style: AppText.ui(size: 13, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today_outlined, size: 18),
          label: Text(
            '${d.visitedAt.year}.${d.visitedAt.month.toString().padLeft(2, '0')}.${d.visitedAt.day.toString().padLeft(2, '0')}',
          ),
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: d.visitedAt,
              firstDate: DateTime(1900),
              lastDate: DateTime(2200),
            );
            if (date != null && mounted) setState(() => d.visitedAt = date);
          },
        ),
        const SizedBox(height: 18),
        DropdownButtonFormField<String>(
          initialValue:
              ['미술', '미디어아트', '사진', '공예', '건축', '공연', '기타'].contains(d.genre)
              ? d.genre
              : '기타',
          decoration: const InputDecoration(labelText: '장르'),
          items: [
            '미술',
            '미디어아트',
            '사진',
            '공예',
            '건축',
            '공연',
            '기타',
          ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
          onChanged: (v) {
            if (v != null) setState(() => d.genre = v);
          },
        ),
        const SizedBox(height: 22),
        Text('관람 별점', style: AppText.ui(size: 13, weight: FontWeight.w600)),
        Wrap(
          children: List.generate(
            5,
            (i) => IconButton(
              tooltip: '${i + 1}점',
              onPressed: () =>
                  setState(() => d.rating = d.rating == i + 1 ? 0 : i + 1),
              icon: Icon(
                i < d.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: AppColors.accent,
                size: 32,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        field('한 줄 감상', d.oneLiner, (v) => d.oneLiner = v, maxLength: 100),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: d.note.isNotEmpty || d.companion.isNotEmpty,
          title: Text('자세한 감상 더 남기기', style: AppText.ui(size: 13)),
          children: [
            field(
              '자세한 기록 (선택)',
              d.note,
              (v) => d.note = v,
              lines: 4,
              maxLength: 5000,
            ),
            field('함께한 사람 (선택)', d.companion, (v) => d.companion = v),
          ],
        ),
      ],
    ),
  );
}
