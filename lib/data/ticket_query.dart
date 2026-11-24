import '../models/ticket.dart';

enum ArchiveFilter { all, exhibition, performance, favorites }

List<Ticket> queryTickets(
  Iterable<Ticket> tickets, {
  int? year,
  ArchiveFilter filter = ArchiveFilter.all,
  String search = '',
}) {
  final q = search.trim().toLowerCase();
  final result = tickets
      .where(
        (t) =>
            (year == null || t.visitedAt.year == year) &&
            (switch (filter) {
              ArchiveFilter.all => true,
              ArchiveFilter.exhibition => t.genre != '공연',
              ArchiveFilter.performance => t.genre == '공연',
              ArchiveFilter.favorites => t.isFavorite,
            }) &&
            (q.isEmpty ||
                [
                  t.title,
                  t.venue,
                  t.oneLiner,
                  t.note,
                  t.companion,
                ].any((v) => v.toLowerCase().contains(q))),
      )
      .toList();
  result.sort((a, b) {
    final c = b.visitedAt.compareTo(a.visitedAt);
    return c == 0 ? a.id.compareTo(b.id) : c;
  });
  return result;
}
