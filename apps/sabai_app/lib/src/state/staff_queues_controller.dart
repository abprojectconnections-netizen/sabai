import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/staff_models.dart';
import '../data/models/support_models.dart';
import '../data/repositories/app_repository.dart';

/// One work queue: its current page(s), filter and loading state.
class QueueState<T> {
  List<T> items = <T>[];
  int total = 0;
  String status = '';
  String query = '';
  bool loading = false;
  bool loaded = false;
  String? error;
  int generation = 0;

  bool get hasMore => items.length < total;

  /// Back to the empty state (used on sign-out); also invalidates any request still in flight.
  void clear() {
    items = <T>[];
    total = 0;
    status = '';
    query = '';
    loading = false;
    loaded = false;
    error = null;
    generation++;
  }
}

/// Staff work queues (bookings, disputes, partners). The server decides who may use each queue and which status changes are
/// allowed; this controller only reports what the server answers and refreshes the list after every action.
class StaffQueuesController extends ChangeNotifier {
  StaffQueuesController(this._repo);

  static const int pageSize = 20;

  final AppRepository _repo;
  final bookings = QueueState<QueueBooking>();
  final disputes = QueueState<QueueDispute>();
  final partners = QueueState<QueuePartner>();
  final tickets = QueueState<QueueTicket>();

  /// The ticket open in the detail screen, with its conversation.
  StaffTicketDetail? ticketDetail;
  bool ticketDetailLoading = false;
  String? ticketDetailError;
  int _ticketDetailGen = 0;

  /// Message of the last failed action; cleared when the next action starts.
  String? actionError;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void reset() {
    final all = <QueueState<Object?>>[bookings, disputes, partners, tickets];
    if (all.every((q) => !q.loaded && !q.loading && q.error == null) && actionError == null && ticketDetail == null && ticketDetailError == null) return;
    for (final q in all) {
      q.clear();
    }
    actionError = null;
    ticketDetail = null;
    ticketDetailLoading = false;
    ticketDetailError = null;
    _ticketDetailGen++;
    scheduleMicrotask(_notify);
  }

  /// Loads page 1 (or the next page when [more]). A slower, older response never overwrites a newer one.
  Future<void> _load<T>(QueueState<T> q, Future<StaffPage<T>> Function(int offset) fetch, {bool more = false}) async {
    if (more && (q.loading || !q.hasMore)) return;
    final gen = more ? q.generation : ++q.generation;
    q.loading = true;
    if (!more) q.error = null;
    notifyListeners();
    try {
      final page = await fetch(more ? q.items.length : 0);
      if (gen != q.generation) return;
      q.items = more ? [...q.items, ...page.items] : page.items;
      q.total = page.total;
    } catch (e) {
      if (gen != q.generation) return;
      if (!more) {
        q.items = <T>[];
        q.total = 0;
      }
      q.error = describeApiErrorTh(e);
    }
    q.loading = false;
    q.loaded = true;
    _notify();
  }

  Future<void> loadBookings({String? status, String? query, bool more = false}) {
    bookings.status = status ?? bookings.status;
    bookings.query = query ?? bookings.query;
    return _load(bookings, (o) => _repo.staffBookings(status: bookings.status, query: bookings.query, offset: o, limit: pageSize), more: more);
  }

  Future<void> loadDisputes({String? status, bool more = false}) {
    disputes.status = status ?? disputes.status;
    return _load(disputes, (o) => _repo.staffDisputes(status: disputes.status, offset: o, limit: pageSize), more: more);
  }

  Future<void> loadPartners({String? status, bool more = false}) {
    partners.status = status ?? partners.status;
    return _load(partners, (o) => _repo.staffPartners(status: partners.status, offset: o, limit: pageSize), more: more);
  }

  Future<void> loadTickets({String? status, bool more = false}) {
    tickets.status = status ?? tickets.status;
    return _load(tickets, (o) => _repo.staffTickets(status: tickets.status, offset: o, limit: pageSize), more: more);
  }

  Future<void> openTicket(String id) async {
    final gen = ++_ticketDetailGen;
    ticketDetail = null;
    ticketDetailLoading = true;
    ticketDetailError = null;
    notifyListeners();
    await _loadTicketDetail(id, gen);
  }

  Future<void> _loadTicketDetail(String id, int gen) async {
    try {
      final d = await _repo.staffTicket(id);
      if (gen != _ticketDetailGen) return;
      ticketDetail = d;
      ticketDetailError = null;
    } catch (e) {
      if (gen != _ticketDetailGen) return;
      ticketDetailError = describeApiErrorTh(e);
    }
    ticketDetailLoading = false;
    _notify();
  }

  Future<void> _reloadTicket(String id) async {
    final gen = ++_ticketDetailGen;
    await _loadTicketDetail(id, gen);
    await loadTickets();
  }

  static const _ticketConflict = 'คำขอนี้ถูกปิดหรือเปลี่ยนสถานะไปแล้ว กรุณาตรวจสอบสถานะล่าสุด';

  Future<bool> replyToTicket(String id, String body) =>
      _act(() => _repo.replyAsStaff(id: id, body: body.trim()), () => _reloadTicket(id), conflictMessage: _ticketConflict);

  Future<bool> changeTicketStatus(String id, String to, {String note = ''}) =>
      _act(() => _repo.changeTicketStatus(id: id, to: to, note: note.trim()), () => _reloadTicket(id), conflictMessage: _ticketConflict);

  /// Runs a write, then refreshes the affected list. A failed write also refreshes, because the usual cause is a row that
  /// someone else already moved.
  Future<bool> _act(Future<void> Function() write, Future<void> Function() reload, {String? conflictMessage}) async {
    actionError = null;
    var ok = true;
    try {
      await write();
    } catch (e) {
      actionError = conflictMessage != null && e is ApiError && e.code == 'CONFLICT' ? conflictMessage : describeApiErrorTh(e);
      ok = false;
    }
    await reload();
    return ok;
  }

  Future<bool> changeBookingStatus(String id, String to, {String note = ''}) =>
      _act(() => _repo.changeBookingStatus(id: id, to: to, note: note.trim()), () => loadBookings());

  Future<bool> changeDisputeStatus(String id, String to, {String note = ''}) =>
      _act(() => _repo.changeDisputeStatus(id: id, to: to, note: note.trim()), () => loadDisputes());

  Future<bool> changePartnerStatus(String id, String to, {String note = ''}) =>
      _act(() => _repo.changePartnerStatus(id: id, to: to, note: note.trim()), () => loadPartners());

  Future<bool> openDispute(String bookingId, String reason, {String description = ''}) =>
      _act(() => _repo.openDispute(bookingId: bookingId, reason: reason, description: description), () => loadDisputes());
}
