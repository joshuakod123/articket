import 'package:material_ui/material_ui.dart';
import '../../models/ticket.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text.dart';
import '../ticket_canvas.dart';
import '../folder_texture.dart';

class FolderPreviewCard extends StatelessWidget {
  const FolderPreviewCard({
    super.key,
    required this.folder,
    required this.tickets,
    this.onTap,
    this.onLongPress,
  });
  final ArchiveFolder folder;
  final List<Ticket> tickets;
  final VoidCallback? onTap, onLongPress;
  @override
  Widget build(BuildContext context) {
    final ink = folder.color.computeLuminance() < .3
        ? Colors.white
        : AppColors.ink;
    return Semantics(
      button: onTap != null,
      label: '${folder.subtitle}, 티켓 ${tickets.length}장',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(15),
          child: SizedBox(
            height: 140,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 14,
                  width: 75,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: folder.color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned.fill(
                  top: 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FolderSurface(
                      color: folder.color,
                      texture: folder.texture,
                      seed: folder.id.hashCode,
                      wear: 0,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 16,
                            right: 12,
                            top: 16,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  folder.subtitle.isEmpty
                                      ? folder.label
                                      : folder.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: folder.font.style(
                                    size: 14,
                                    color: ink,
                                  ),
                                ),
                                Text(
                                  '${tickets.length}장',
                                  style: AppText.ui(size: 12, color: ink),
                                ),
                              ],
                            ),
                          ),
                          if (tickets.isNotEmpty)
                            Positioned(
                              right: 12,
                              bottom: -22,
                              width: 80,
                              height: 100,
                              child: Transform.rotate(
                                angle: -.08,
                                child: TicketCanvas(
                                  ticket: tickets.first,
                                  compact: true,
                                ),
                              ),
                            ),
                          if (tickets.isEmpty)
                            Positioned(
                              right: 15,
                              bottom: 16,
                              child: Icon(
                                Icons.confirmation_number_outlined,
                                color: ink.withValues(alpha: .35),
                                size: 40,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
