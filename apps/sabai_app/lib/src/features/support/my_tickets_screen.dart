import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/support_models.dart';
import '../../state/tickets_controller.dart';
import 'new_ticket_screen.dart';
import 'ticket_detail_screen.dart';

/// The customer's own support requests, newest first.
class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<TicketsController>().load();
    });
  }

  Future<void> _new() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(builder: (_) => const NewTicketScreen()));
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ส่งคำขอแล้ว เจ้าหน้าที่จะตอบในรายการนี้')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TicketsController>();
    Widget body;
    if (c.loading && c.tickets.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (c.error != null && c.tickets.isEmpty) {
      body = Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(c.error!, key: const Key('ticketsError')),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: c.load, child: const Text('ลองอีกครั้ง')),
              ])));
    } else if (c.tickets.isEmpty) {
      body = const Center(child: Text('ยังไม่มีคำขอความช่วยเหลือ', key: Key('ticketsEmpty')));
    } else {
      body = RefreshIndicator(
        onRefresh: c.load,
        child: ListView(
          children: [
            for (final t in c.tickets) _TicketTile(ticket: t),
            if (c.hasMore)
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton(key: const Key('ticketsMore'), onPressed: c.loading ? null : c.loadMore, child: const Text('ดูเพิ่มเติม')),
              ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('คำขอความช่วยเหลือของฉัน')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newTicketButton'),
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: const Text('แจ้งปัญหา'),
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: body)),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});

  final SupportTicket ticket;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('ticket-${ticket.id}'),
      title: Text(ticket.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        ticketCategoryLabelTh(ticket.category),
        ticketStatusLabelTh(ticket.status),
        ticketDate(ticket.createdAt),
        if (ticket.replyCount > 0) 'ตอบแล้ว ${ticket.replyCount}',
      ].where((s) => s.isNotEmpty).join(' · ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TicketDetailScreen(ticketId: ticket.id))),
    );
  }
}
