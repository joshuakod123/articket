import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:articket/models/ticket.dart';
import 'package:articket/models/layer.dart';
import 'package:articket/models/ticket_draft.dart';
import 'package:articket/theme/ticket_design.dart';
import 'package:articket/data/remote_store.dart';
import 'package:articket/data/ticket_query.dart';

void main() {
  Ticket ticket(
    String id, {
    String title = '빛과 공간',
    String venue = '서울 미술관',
    String genre = '미술',
    bool favorite = false,
    int year = 2026,
  }) => Ticket(
    id: id,
    folderId: 'folder',
    title: title,
    venue: venue,
    visitedAt: DateTime(year, 11, 21),
    genre: genre,
    isFavorite: favorite,
  );
  test('old records preserve their appearance and default to non-favorite', () {
    final json = ticket('old').toJson()
      ..remove('design')
      ..remove('isFavorite');
    final restored = Ticket.fromJson(json);
    expect(restored.design, TicketDesign.legacy);
    expect(restored.isFavorite, isFalse);
    expect(TicketDesign.parse('unknown-future-layout'), TicketDesign.legacy);
  });
  test('all three designs and favorites survive cloud payload roundtrip', () {
    for (final design in TicketDesign.selectable) {
      final t = ticket('id-${design.name}', favorite: true)..design = design;
      final row = RemoteStore.ticketRow(t, 'user');
      final restored = RemoteStore.ticketFromRow(row);
      expect(restored.design, design);
      expect(restored.isFavorite, isTrue);
      expect(restored.visitedAt, DateTime(2026, 11, 21));
    }
  });
  test(
    'cloud payload excludes device photo paths but preserves private asset keys',
    () {
      final t = ticket('photo')
        ..posterPath = '/private/device/poster.jpg'
        ..posterKey = 'user/poster.jpg';
      t.layers.add(
        ScrapLayer(
          id: 'layer',
          kind: LayerKind.photo,
          content: '/private/device/photo.jpg',
          photoKey: 'user/layer.jpg',
        ),
      );
      final row = RemoteStore.ticketRow(t, 'user');
      final encoded = jsonEncode(row);
      expect(encoded, isNot(contains('/private/device')));
      final restored = RemoteStore.ticketFromRow(row);
      expect(restored.posterPath, isNull);
      expect(restored.posterKey, 'user/poster.jpg');
      expect(restored.layers.single.content, isEmpty);
      expect(restored.layers.single.photoKey, 'user/layer.jpg');
    },
  );
  test(
    'editing a draft preserves original identity, number and decorations',
    () {
      final original = ticket('draft')
        ..issuedYear = 2026
        ..issuedSeq = 12;
      original.layers.add(
        ScrapLayer(id: 'memo', kind: LayerKind.text, content: 'my note'),
      );
      final draft = TicketDraft.fromTicket(original)
        ..title = '바뀐 제목'
        ..note = '새 감상';
      expect(original.title, '빛과 공간');
      draft.applyTo(original);
      expect(original.title, '바뀐 제목');
      expect(original.serial, 'AK-2026-012');
      expect(original.layers.single.content, 'my note');
      expect(original.id, 'draft');
    },
  );
  test('query combines year, genre, favorite and case-insensitive text', () {
    final records = [
      ticket('a', title: 'FORM', favorite: true),
      ticket('b', title: '공연', genre: '공연'),
      ticket('c', year: 2025, favorite: true),
    ];
    expect(queryTickets(records, search: ' form ').map((t) => t.id), ['a']);
    expect(
      queryTickets(
        records,
        year: 2026,
        filter: ArchiveFilter.favorites,
      ).map((t) => t.id),
      ['a'],
    );
    expect(
      queryTickets(records, filter: ArchiveFilter.performance).map((t) => t.id),
      ['b'],
    );
    expect(queryTickets(records, search: '없는 전시'), isEmpty);
  });
}
