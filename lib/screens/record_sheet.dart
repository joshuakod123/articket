import 'package:flutter/material.dart';
import '../data/ticket_store.dart';
import '../models/ticket.dart';
import '../models/ticket_draft.dart';
import '../widgets/record_form.dart';

Future<void> openRecordSheet(
  BuildContext context, {
  required Ticket ticket,
  required TicketStore store,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => RecordSheet(ticket: ticket, store: store),
);

class RecordSheet extends StatefulWidget {
  const RecordSheet({super.key, required this.ticket, required this.store});
  final Ticket ticket;
  final TicketStore store;
  @override
  State<RecordSheet> createState() => _RecordSheetState();
}

class _RecordSheetState extends State<RecordSheet> {
  late final draft = TicketDraft.fromTicket(widget.ticket);
  final _form = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: FractionallySizedBox(
      heightFactor: .9,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '관람 기록 수정',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: RecordForm(draft: draft, formKey: _form),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_form.currentState!.validate()) {
                      draft.applyTo(widget.ticket);
                      widget.store.touch();
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('기록 저장'),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
