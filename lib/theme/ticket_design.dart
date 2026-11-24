/// A ticket's typography/layout is independent from its physical frame.
enum TicketDesign {
  legacy('기존 디자인'),
  editorial('에디토리얼'),
  scrapbook('스크랩북'),
  graphic('그래픽');

  const TicketDesign(this.label);
  final String label;
  static TicketDesign parse(String? value) => TicketDesign.values.firstWhere(
    (v) => v.name == value,
    orElse: () => TicketDesign.legacy,
  );
  static const selectable = [editorial, scrapbook, graphic];
}
