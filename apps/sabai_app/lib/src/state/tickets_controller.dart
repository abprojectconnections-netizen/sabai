import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/support_models.dart';
import '../data/repositories/app_repository.dart';

/// The signed-in customer's support tickets: the list, one open conversation, and the actions on it. Every action reloads what it
/// changed from the server, so the screen shows what the server holds even after a failure. Cleared on sign-out.
class TicketsController extends ChangeNotifier {
  TicketsController(this._repo);

  static const int pageSize = 20;

  final AppRepository _repo;
  bool _disposed = false;

  List<SupportTicket> tickets = const [];
  int total = 0;
  bool loading = false;
  bool loadedOnce = false;
  String? error;
  int _gen = 0;

  SupportTicketDetail? detail;
  bool detailLoading = false;
  String? detailError;
  int _detailGen = 0;

  /// Message from the last failed action, cleared at the start of the next one.
  String? actionError;

  bool get hasMore => tickets.length < total;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void reset() {
    if (!loadedOnce && tickets.isEmpty && detail == null && !loading && !detailLoading && error == null && detailError == null) return;
    tickets = const [];
    total = 0;
    loading = false;
    loadedOnce = false;
    error = null;
    detail = null;
    detailLoading = false;
    detailError = null;
    actionError = null;
    _gen++;
    _detailGen++;
    scheduleMicrotask(_notify);
  }

  Future<void> load() async {
    final gen = ++_gen;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _repo.myTickets(offset: 0, limit: pageSize);
      if (gen != _gen) return;
      tickets = page.items;
      total = page.total;
    } catch (e) {
      if (gen != _gen) return;
      error = describeApiErrorTh(e);
    }
    loading = false;
    loadedOnce = true;
    _notify();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final gen = _gen;
    loading = true;
    notifyListeners();
    try {
      final page = await _repo.myTickets(offset: tickets.length, limit: pageSize);
      if (gen != _gen) return;
      tickets = [...tickets, ...page.items];
      total = page.total;
    } catch (e) {
      if (gen != _gen) return;
      error = describeApiErrorTh(e);
    }
    loading = false;
    _notify();
  }

  Future<void> openDetail(String id) async {
    final gen = ++_detailGen;
    detail = null;
    detailLoading = true;
    detailError = null;
    notifyListeners();
    await _loadDetail(id, gen);
  }

  Future<void> _loadDetail(String id, int gen) async {
    try {
      final d = await _repo.myTicket(id);
      if (gen != _detailGen) return;
      detail = d;
      detailError = null;
    } catch (e) {
      if (gen != _detailGen) return;
      detailError = describeApiErrorTh(e);
    }
    detailLoading = false;
    _notify();
  }

  /// Opens a ticket. Returns its id, or null with [actionError] set.
  Future<String?> create({required String subject, required String category, required String description}) async {
    actionError = null;
    try {
      final id = await _repo.createTicket(subject: subject.trim(), category: category, description: description.trim());
      await load();
      return id;
    } catch (e) {
      actionError = _message(e, createConflict: true);
      _notify();
      return null;
    }
  }

  Future<bool> reply(String id, String body) => _act(id, () => _repo.replyToMyTicket(id: id, body: body.trim()));

  Future<bool> close(String id) => _act(id, () => _repo.closeMyTicket(id));

  Future<bool> _act(String id, Future<void> Function() run) async {
    actionError = null;
    var ok = true;
    try {
      await run();
    } catch (e) {
      ok = false;
      actionError = _message(e);
    }
    final gen = ++_detailGen;
    await _loadDetail(id, gen);
    unawaited(load()); // the list shows status and reply count too
    return ok;
  }

  String _message(Object e, {bool createConflict = false}) {
    if (e is ApiError && e.code == 'CONFLICT') {
      return createConflict ? 'คุณมีคำขอที่ยังไม่ปิดครบ 5 รายการ กรุณารอเจ้าหน้าที่ตอบหรือปิดรายการเดิมก่อน' : 'คำขอนี้ถูกปิดแล้ว';
    }
    if (e is ApiError && e.code == 'RATE_LIMITED') return 'ส่งบ่อยเกินไป กรุณารอสักครู่แล้วลองอีกครั้ง';
    return describeApiErrorTh(e);
  }
}
