import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/frame_shapes.dart';
import '../widgets/poster.dart';

/// 티켓 모양과 포스터를 고르는 시트.
///
/// 왼쪽 탭은 실루엣(프레임 6종), 오른쪽 탭은 포스터(사진 또는 색)입니다.
class TicketStyleSheet extends StatefulWidget {
  const TicketStyleSheet({
    super.key,
    required this.ticket,
    required this.store,
    this.initialTab = 0,
  });

  final Ticket ticket;
  final TicketStore store;
  final int initialTab;

  @override
  State<TicketStyleSheet> createState() => _TicketStyleSheetState();
}

class _TicketStyleSheetState extends State<TicketStyleSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
  TabController(length: 2, vsync: this, initialIndex: widget.initialTab);

  final _picker = ImagePicker();
  bool _picking = false;

  Ticket get t => widget.ticket;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _apply(VoidCallback change) {
    setState(change);
    widget.store.touch();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final shot = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 90,
      );
      if (shot != null) {
        _apply(() => t.posterPath = shot.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진을 불러오지 못했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.inkSoft,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabs,
            indicatorColor: AppColors.foil,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.stock,
            unselectedLabelColor: AppColors.inkSoft,
            labelStyle: AppText.eyebrow(),
            tabs: const [Tab(text: 'FRAME'), Tab(text: 'POSTER')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _framesTab(scrollController),
                _posterTab(scrollController),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 프레임 탭 ────────────────────────────────────
  Widget _framesTab(ScrollController controller) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 18,
        crossAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemCount: TicketFrame.values.length,
      itemBuilder: (context, i) {
        final frame = TicketFrame.values[i];
        final selected = t.frame == frame;

        return GestureDetector(
          onTap: () => _apply(() => t.frame = frame),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? AppColors.foil : AppColors.inkSoft,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(8),
                  // 실제 클리퍼로 실루엣 미리보기를 그립니다.
                  child: AspectRatio(
                    aspectRatio: frame.aspect,
                    child: ClipPath(
                      clipper: clipperFor(frame),
                      child: Poster(ticket: t, holoStrength: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(frame.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(
                    size: 12,
                    weight: FontWeight.w600,
                    color: selected ? AppColors.foil : AppColors.stock,
                  )),
              Text(frame.hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.ui(size: 9, color: AppColors.inkSoft)),
            ],
          ),
        );
      },
    );
  }

  // ── 포스터 탭 ────────────────────────────────────
  Widget _posterTab(ScrollController controller) {
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      children: [
        Text('사진 넣기', style: AppText.eyebrow(color: AppColors.foil)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _sourceButton(
                icon: Icons.photo_library_outlined,
                label: '갤러리',
                onTap: _picking ? null : () => _pickPhoto(ImageSource.gallery),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _sourceButton(
                icon: Icons.photo_camera_outlined,
                label: '촬영',
                onTap: _picking ? null : () => _pickPhoto(ImageSource.camera),
              ),
            ),
          ],
        ),
        if (t.hasPhoto) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => _apply(() => t.posterPath = null),
            icon: const Icon(Icons.close, size: 15, color: AppColors.oxblood),
            label: Text('사진 빼고 색으로',
                style: AppText.ui(size: 12, color: AppColors.oxblood)),
          ),
        ],
        const SizedBox(height: 26),
        Row(
          children: [
            Text('색으로 채우기', style: AppText.eyebrow(color: AppColors.foil)),
            const SizedBox(width: 8),
            if (t.hasPhoto)
              Text('· 사진을 빼면 적용됩니다',
                  style: AppText.ui(size: 10, color: AppColors.inkSoft)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final p in PosterPalette.presets)
              _swatch(p, selected: !t.hasPhoto && _sameTint(p.colors)),
          ],
        ),
        const SizedBox(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: t.holographic,
          onChanged: (v) => _apply(() => t.holographic = v),
          title: Text('홀로그램 텍스처',
              style: AppText.ui(size: 14, color: AppColors.stock)),
          subtitle: Text('기기를 기울이면 펄이 흐릅니다',
              style: AppText.ui(size: 11, color: AppColors.inkSoft)),
        ),
      ],
    );
  }

  bool _sameTint(List<Color> colors) =>
      t.posterTint.length == colors.length &&
          t.posterTint.first.toARGB32() == colors.first.toARGB32();

  Widget _sourceButton({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(border: Border.all(color: AppColors.inkSoft)),
        child: Column(
          children: [
            if (_picking)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.foil),
              )
            else
              Icon(icon, size: 20, color: AppColors.stock),
            const SizedBox(height: 8),
            Text(label, style: AppText.ui(size: 12, color: AppColors.stock)),
          ],
        ),
      ),
    );
  }

  Widget _swatch(PosterPalette palette, {required bool selected}) {
    return GestureDetector(
      onTap: () => _apply(() {
        t.posterTint = palette.colors;
        t.posterPath = null;
      }),
      child: SizedBox(
        width: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: palette.colors,
                ),
                border: Border.all(
                  color: selected ? AppColors.foil : Colors.transparent,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.check,
                      size: 14, color: AppColors.stockLight),
                ),
              )
                  : null,
            ),
            const SizedBox(height: 5),
            Text(palette.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.ui(size: 10, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}