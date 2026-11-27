import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/util/dates.dart';
import '../../data/models/staff_models.dart';
import '../../data/models/support_models.dart';
import '../../state/app_state.dart';
import '../../state/staff_queues_controller.dart';

/// Staff work queues. A tab appears only for the queues /me says this person may use (a Booking Officer sees bookings and
/// disputes, not partners); the server checks every call anyway and lists the allowed next statuses with each row.
class StaffQueuesScreen extends StatelessWidget {
  const StaffQueuesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AppState>().account;
    final tabs = <(String, String, Widget)>[
      if (account.canManageBookings) ('bookings', 'การจอง', const _BookingsTab()),
      if (account.canManageDisputes) ('disputes', 'ข้อพิพาท', const _DisputesTab()),
      if (account.canManageTickets) ('tickets', 'ตั๋วช่วยเหลือ', const _TicketsTab()),
      if (account.canReviewPartners) ('partners', 'พาร์ตเนอร์', const _PartnersTab()),
    ];
    if (tabs.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('คิวงานเจ้าหน้าที่')), body: const Center(child: Text('บัญชีนี้ไม่มีคิวงานที่ใช้ได้', key: Key('noQueues'))));
    }
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('คิวงานเจ้าหน้าที่'),
          bottom: TabBar(tabs: [for (final t in tabs) Tab(key: Key('tab-${t.$1}'), text: t.$2)]),
        ),
        body: TabBarView(children: [for (final t in tabs) t.$3]),
      ),
    );
  }
}

const _bookingFilters = [('', 'ทั้งหมด'), ('PENDING', 'รอดำเนินการ'), ('CONFIRMED', 'ยืนยันแล้ว'), ('PAID', 'ชำระแล้ว'), ('CANCELLED', 'ยกเลิก')];
const _disputeFilters = [('', 'ทั้งหมด'), ('OPEN', 'เปิดอยู่'), ('IN_REVIEW', 'กำลังตรวจสอบ'), ('RESOLVED', 'แก้ไขแล้ว'), ('REJECTED', 'ปฏิเสธ')];
const _ticketFilters = [('', 'ทั้งหมด'), ('OPEN', 'รอเจ้าหน้าที่'), ('IN_PROGRESS', 'กำลังดำเนินการ'), ('RESOLVED', 'แก้ไขแล้ว'), ('CLOSED', 'ปิดแล้ว')];
const _partnerFilters = [('', 'ทั้งหมด'), ('PENDING', 'รอดำเนินการ'), ('APPROVED', 'อนุมัติแล้ว'), ('SUSPENDED', 'ถูกระงับ'), ('REJECTED', 'ปฏิเสธ')];

/// Shared frame of a queue: optional header, status chips, then loading / error / empty / list with "load more".
class _QueueView<T> extends StatelessWidget {
  const _QueueView({
    required this.name,
    required this.state,
    required this.filters,
    required this.onFilter,
    required this.onRefresh,
    required this.onMore,
    required this.itemBuilder,
    this.header,
  });

  final String name;
  final QueueState<T> state;
  final List<(String, String)> filters;
  final ValueChanged<String> onFilter;
  final Future<void> Function() onRefresh;
  final VoidCallback onMore;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (state.loading && state.items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && state.items.isEmpty) {
      body = Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(state.error!, key: Key('$name-error'))));
    } else if (state.items.isEmpty) {
      body = Center(child: Text('ไม่มีรายการในคิวนี้', key: Key('$name-empty')));
    } else {
      body = RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          itemCount: state.items.length + 1,
          itemBuilder: (context, i) {
            if (i == state.items.length) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Text('แสดง ${state.items.length} จาก ${state.total}', key: Key('$name-count'), style: Theme.of(context).textTheme.bodySmall),
                  if (state.hasMore) TextButton(key: Key('$name-more'), onPressed: state.loading ? null : onMore, child: const Text('โหลดเพิ่ม')),
                ]),
              );
            }
            return itemBuilder(context, state.items[i]);
          },
        ),
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(children: [
          if (header != null) header!,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, children: [
                for (final f in filters)
                  ChoiceChip(
                    key: Key('qf-$name-${f.$1.isEmpty ? 'all' : f.$1}'),
                    label: Text(f.$2),
                    selected: state.status == f.$1,
                    onSelected: (_) => onFilter(f.$1),
                  ),
              ]),
            ),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

/// Runs a status change after a confirmation (with an optional note) and reports the outcome in a snackbar.
Future<void> _confirmAndRun(
  BuildContext context, {
  required String title,
  required String detail,
  required bool destructive,
  required Future<bool> Function(String note) run,
}) async {
  final c = context.read<StaffQueuesController>();
  // Taken before the awaits: after a successful change the row may leave a filtered list and unmount, but the message must still show.
  final messenger = ScaffoldMessenger.of(context);
  final note = await showDialog<String>(context: context, builder: (_) => _ConfirmDialog(title: title, detail: detail, destructive: destructive));
  if (note == null) return;
  final ok = await run(note);
  messenger.showSnackBar(SnackBar(content: Text(ok ? 'ดำเนินการแล้ว' : (c.actionError ?? 'ดำเนินการไม่สำเร็จ'))));
}

class _Actions extends StatelessWidget {
  const _Actions({required this.keyPrefix, required this.kind, required this.from, required this.next, required this.onChange, this.extra = const []});

  final String keyPrefix;
  final String kind;
  final String from;
  final List<String> next;
  final void Function(String to) onChange;
  final List<Widget> extra;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final to in next)
        isDestructiveStatus(to)
            ? OutlinedButton(
                key: Key('$keyPrefix-to-$to'),
                style: OutlinedButton.styleFrom(foregroundColor: error),
                onPressed: () => onChange(to),
                child: Text(statusActionTh(kind, from, to)),
              )
            : FilledButton(key: Key('$keyPrefix-to-$to'), onPressed: () => onChange(to), child: Text(statusActionTh(kind, from, to))),
      ...extra,
    ]);
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab();

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StaffQueuesController>().loadBookings(status: '', query: '');
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openDispute(QueueBooking b) async {
    final c = context.read<StaffQueuesController>();
    final r = await showDialog<(String, String)>(context: context, builder: (_) => _DisputeDialog(code: b.code));
    if (r == null || !mounted) return;
    final ok = await c.openDispute(b.id, r.$1, description: r.$2);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'เปิดข้อพิพาทแล้ว' : (c.actionError ?? 'ดำเนินการไม่สำเร็จ'))));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffQueuesController>();
    final canDispute = context.watch<AppState>().account.canManageDisputes;
    return _QueueView<QueueBooking>(
      name: 'bookings',
      state: c.bookings,
      filters: _bookingFilters,
      onFilter: (s) => c.loadBookings(status: s),
      onRefresh: () => c.loadBookings(),
      onMore: () => c.loadBookings(more: true),
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          key: const Key('bookingSearchField'),
          controller: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'ค้นหาจากรหัสการจอง',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(key: const Key('bookingSearchButton'), icon: const Icon(Icons.arrow_forward), tooltip: 'ค้นหา', onPressed: () => c.loadBookings(query: _search.text)),
          ),
          onSubmitted: (v) => c.loadBookings(query: v),
        ),
      ),
      itemBuilder: (context, b) => Card(
        key: Key('bk-${b.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${b.code} · ${b.currency} ${b.total}', style: Theme.of(context).textTheme.titleMedium)),
              Chip(key: Key('bk-${b.id}-status'), label: Text(statusLabelTh(b.status))),
            ]),
            Text('${b.customerEmail} · ${formatDate(b.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            if (b.nextStatuses.isEmpty && !canDispute)
              Text('ไม่มีการดำเนินการที่ทำได้', style: Theme.of(context).textTheme.bodySmall)
            else
              _Actions(
                keyPrefix: 'bk-${b.id}',
                kind: 'booking',
                from: b.status,
                next: b.nextStatuses,
                extra: [
                  if (canDispute) TextButton(key: Key('bk-${b.id}-dispute'), onPressed: () => _openDispute(b), child: const Text('เปิดข้อพิพาท')),
                ],
                onChange: (to) => _confirmAndRun(
                  context,
                  title: '${statusActionTh('booking', b.status, to)}?',
                  detail: 'การจอง ${b.code} จะเปลี่ยนเป็น "${statusLabelTh(to)}" และถูกบันทึกในประวัติตรวจสอบ',
                  destructive: isDestructiveStatus(to),
                  run: (note) => c.changeBookingStatus(b.id, to, note: note),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _DisputesTab extends StatefulWidget {
  const _DisputesTab();

  @override
  State<_DisputesTab> createState() => _DisputesTabState();
}

class _DisputesTabState extends State<_DisputesTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StaffQueuesController>().loadDisputes(status: '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffQueuesController>();
    return _QueueView<QueueDispute>(
      name: 'disputes',
      state: c.disputes,
      filters: _disputeFilters,
      onFilter: (s) => c.loadDisputes(status: s),
      onRefresh: () => c.loadDisputes(),
      onMore: () => c.loadDisputes(more: true),
      itemBuilder: (context, d) => Card(
        key: Key('ds-${d.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${d.bookingCode.isEmpty ? 'ไม่ทราบรหัสการจอง' : d.bookingCode} · ${d.reason}', style: Theme.of(context).textTheme.titleMedium)),
              Chip(key: Key('ds-${d.id}-status'), label: Text(statusLabelTh(d.status))),
            ]),
            if (d.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(d.description)),
            Text('เปิดโดย ${d.openedBy} · ${formatDate(d.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
            if (d.nextStatuses.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Actions(
                keyPrefix: 'ds-${d.id}',
                kind: 'dispute',
                from: d.status,
                next: d.nextStatuses,
                onChange: (to) => _confirmAndRun(
                  context,
                  title: '${statusActionTh('dispute', d.status, to)}?',
                  detail: 'ข้อพิพาทของ ${d.bookingCode} จะเปลี่ยนเป็น "${statusLabelTh(to)}" และถูกบันทึกในประวัติตรวจสอบ',
                  destructive: isDestructiveStatus(to),
                  run: (note) => c.changeDisputeStatus(d.id, to, note: note),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _PartnersTab extends StatefulWidget {
  const _PartnersTab();

  @override
  State<_PartnersTab> createState() => _PartnersTabState();
}

class _PartnersTabState extends State<_PartnersTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StaffQueuesController>().loadPartners(status: '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffQueuesController>();
    return _QueueView<QueuePartner>(
      name: 'partners',
      state: c.partners,
      filters: _partnerFilters,
      onFilter: (s) => c.loadPartners(status: s),
      onRefresh: () => c.loadPartners(),
      onMore: () => c.loadPartners(more: true),
      itemBuilder: (context, p) => Card(
        key: Key('pt-${p.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(p.legalName, style: Theme.of(context).textTheme.titleMedium)),
              Chip(key: Key('pt-${p.id}-status'), label: Text(statusLabelTh(p.status))),
            ]),
            Text('เจ้าของ ${p.ownerEmail} · สมัครเมื่อ ${formatDate(p.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
            if (p.nextStatuses.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Actions(
                keyPrefix: 'pt-${p.id}',
                kind: 'partner',
                from: p.status,
                next: p.nextStatuses,
                onChange: (to) => _confirmAndRun(
                  context,
                  title: '${statusActionTh('partner', p.status, to)}?',
                  detail: '${p.legalName} จะเปลี่ยนเป็น "${statusLabelTh(to)}" และถูกบันทึกในประวัติตรวจสอบ',
                  destructive: isDestructiveStatus(to),
                  run: (note) => c.changePartnerStatus(p.id, to, note: note),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Confirmation with an optional note. Owns its text controller so it is disposed with the dialog; returns the note
/// (possibly empty) on confirm and null on cancel.
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({required this.title, required this.detail, required this.destructive});

  final String title;
  final String detail;
  final bool destructive;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.detail),
        const SizedBox(height: 12),
        TextField(key: const Key('statusNote'), controller: _note, maxLength: 300, decoration: const InputDecoration(labelText: 'หมายเหตุ (ไม่บังคับ)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        FilledButton(
          key: const Key('confirmStatus'),
          style: widget.destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
          onPressed: () => Navigator.of(context).pop(_note.text),
          child: const Text('ยืนยัน'),
        ),
      ],
    );
  }
}

/// Opens a dispute on a booking: the reason is required (max 100 characters), the description is optional.
class _DisputeDialog extends StatefulWidget {
  const _DisputeDialog({required this.code});

  final String code;

  @override
  State<_DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<_DisputeDialog> {
  final _reason = TextEditingController();
  final _description = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final r = _reason.text.trim();
    if (r.isEmpty) {
      setState(() => _error = 'กรุณาระบุเหตุผล');
      return;
    }
    Navigator.of(context).pop((r, _description.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('เปิดข้อพิพาท ${widget.code}'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('disputeReason'), controller: _reason, maxLength: 100, decoration: InputDecoration(labelText: 'เหตุผล (จำเป็น)', errorText: _error)),
          TextField(key: const Key('disputeDescription'), controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'รายละเอียด (ไม่บังคับ)')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        FilledButton(key: const Key('confirmDispute'), onPressed: _submit, child: const Text('เปิดข้อพิพาท')),
      ],
    );
  }
}

class _TicketsTab extends StatefulWidget {
  const _TicketsTab();

  @override
  State<_TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<_TicketsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StaffQueuesController>().loadTickets(status: '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffQueuesController>();
    return _QueueView<QueueTicket>(
      name: 'tickets',
      state: c.tickets,
      filters: _ticketFilters,
      onFilter: (s) => c.loadTickets(status: s),
      onRefresh: () => c.loadTickets(),
      onMore: () => c.loadTickets(more: true),
      itemBuilder: (context, t) => Card(
        key: Key('tk-${t.id}'),
        child: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => StaffTicketScreen(ticketId: t.id))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(t.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium)),
                Chip(key: Key('tk-${t.id}-status'), label: Text(statusLabelTh(t.status))),
              ]),
              Text(
                [
                  ticketCategoryLabelTh(t.category),
                  t.customerEmail,
                  if (t.bookingCode.isNotEmpty) 'การจอง ${t.bookingCode}',
                  formatDate(t.createdAt),
                  if (t.messageCount > 0) '${t.messageCount} ข้อความ',
                ].where((x) => x.isNotEmpty).join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One ticket for staff: the customer's description, the conversation, a reply box and the status changes the server allows.
/// Customers see staff replies as "เจ้าหน้าที่" without a name.
class StaffTicketScreen extends StatefulWidget {
  const StaffTicketScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  State<StaffTicketScreen> createState() => _StaffTicketScreenState();
}

class _StaffTicketScreenState extends State<StaffTicketScreen> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StaffQueuesController>().openTicket(widget.ticketId);
    });
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    final c = context.read<StaffQueuesController>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final ok = await c.replyToTicket(widget.ticketId, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      _reply.clear();
    } else {
      messenger.showSnackBar(SnackBar(content: Text(c.actionError ?? 'ส่งไม่สำเร็จ')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffQueuesController>();
    final d = c.ticketDetail;
    Widget body;
    if (d == null) {
      body = c.ticketDetailError != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(c.ticketDetailError!, key: const Key('staffTicketError'))))
          : const Center(child: CircularProgressIndicator());
    } else {
      final t = d.ticket;
      body = Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Text(t.subject, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              [ticketCategoryLabelTh(t.category), t.customerEmail, if (t.bookingCode.isNotEmpty) 'การจอง ${t.bookingCode}', formatDate(t.createdAt)].join(' · '),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Chip(key: const Key('staffTicketStatus'), label: Text(statusLabelTh(t.status))),
            const SizedBox(height: 8),
            Text(d.description, key: const Key('staffTicketDescription')),
            if (t.nextStatuses.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Actions(
                keyPrefix: 'tkd',
                kind: 'ticket',
                from: t.status,
                next: t.nextStatuses,
                onChange: (to) => _confirmAndRun(
                  context,
                  title: '${statusActionTh('ticket', t.status, to)}?',
                  detail: 'คำขอนี้จะเปลี่ยนเป็น "${statusLabelTh(to)}" และถูกบันทึกในประวัติตรวจสอบ${to == 'CLOSED' ? ' ลูกค้าจะตอบเพิ่มไม่ได้อีก' : ''}',
                  destructive: isDestructiveStatus(to),
                  run: (note) => c.changeTicketStatus(widget.ticketId, to, note: note),
                ),
              ),
            ],
            const Divider(height: 32),
            if (d.messages.isEmpty) const Text('ยังไม่มีข้อความ', key: Key('staffNoMessages')),
            for (final m in d.messages)
              Align(
                alignment: m.fromStaff ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  key: Key('smsg-${m.id}'),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: m.fromStaff ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.fromStaff ? 'เจ้าหน้าที่' : 'ลูกค้า', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(m.body),
                  ]),
                ),
              ),
          ]),
        ),
        if (t.status == 'CLOSED')
          const Padding(padding: EdgeInsets.all(16), child: Text('คำขอนี้ปิดแล้ว ตอบเพิ่มไม่ได้', key: Key('staffTicketClosedNote')))
        else
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('staffReplyField'),
                    controller: _reply,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'ตอบลูกค้า', counterText: ''),
                  ),
                ),
                IconButton(key: const Key('staffSendReply'), onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
              ]),
            ),
          ),
      ]);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('คำขอความช่วยเหลือ')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 900), child: body)),
    );
  }
}
