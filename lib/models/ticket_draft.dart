import 'package:flutter/material.dart';
import 'ticket.dart';
import '../theme/ticket_design.dart';

/// A form owns this draft. Creating/cancelling a draft never mutates the store.
class TicketDraft {
  TicketDraft({
    this.title = '',
    this.venue = '',
    DateTime? visitedAt,
    this.genre = '미술',
    this.rating = 0,
    this.oneLiner = '',
    this.note = '',
    this.companion = '',
    this.folderId,
    this.posterPath,
    this.design = TicketDesign.scrapbook,
  }) : visitedAt = visitedAt ?? DateTime.now();
  String title, venue, genre, oneLiner, note, companion;
  DateTime visitedAt;
  int rating;
  String? folderId, posterPath;
  TicketDesign design;
  factory TicketDraft.fromTicket(Ticket t) => TicketDraft(
    title: t.title,
    venue: t.venue,
    visitedAt: t.visitedAt,
    genre: t.genre,
    rating: t.rating,
    oneLiner: t.oneLiner,
    note: t.note,
    companion: t.companion,
    folderId: t.folderId,
    posterPath: t.posterPath,
    design: t.design,
  );
  Ticket build({required String id, required String folderId}) => Ticket(
    id: id,
    folderId: folderId,
    title: title.trim(),
    venue: venue.trim(),
    visitedAt: visitedAt,
    genre: genre,
    rating: rating,
    oneLiner: oneLiner.trim(),
    note: note.trim(),
    companion: companion.trim(),
    posterPath: posterPath,
    design: design,
    frame: design == TicketDesign.scrapbook
        ? TicketFrame.stamp
        : TicketFrame.classic,
    posterTint: switch (design) {
      TicketDesign.graphic => const [Color(0xFF2551E8), Color(0xFFE7EC78)],
      TicketDesign.scrapbook => const [Color(0xFFB8A7D4), Color(0xFFE8DFA3)],
      _ => const [Color(0xFF647E98), Color(0xFFDAA882)],
    },
  );
  void applyTo(Ticket t) {
    t.title = title.trim();
    t.venue = venue.trim();
    t.visitedAt = visitedAt;
    t.genre = genre;
    t.rating = rating;
    t.oneLiner = oneLiner.trim();
    t.note = note.trim();
    t.companion = companion.trim();
  }
}
