import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/admin_models.dart';
import '../data/repositories/app_repository.dart';

/// State for the admin console: dashboard counts, the user list and the audit trail. The server decides who may call each
/// endpoint; this controller only reports what the server answers. Cleared on sign-out.
class AdminController extends ChangeNotifier {
  AdminController(this._repo);

  static const int pageSize = 20;

  final AppRepository _repo;
  bool _disposed = false;

  // Dashboard
  DashboardStats? stats;
  bool statsLoading = false;
  String? statsError;

  // Users
  List<AdminUser> users = const [];
  int usersTotal = 0;
  String userQuery = '';
  String userStatus = '';
  bool usersLoading = false;
  String? usersError;
  int _usersGen = 0;

  // Audit trail
  List<AuditEntry> audit = const [];
  int auditTotal = 0;
  String auditAction = '';
  bool auditLoading = false;
  String? auditError;
  int _auditGen = 0;

  /// Message from the last failed action (for example a suspension), cleared at the start of the next one.
  String? actionError;

  bool get hasMoreUsers => users.length < usersTotal;
  bool get hasMoreAudit => audit.length < auditTotal;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void reset() {
    if (stats == null && users.isEmpty && audit.isEmpty && !statsLoading && !usersLoading && !auditLoading && statsError == null && usersError == null && auditError == null) {
      return;
    }
    stats = null;
    statsLoading = false;
    statsError = null;
    users = const [];
    usersTotal = 0;
    userQuery = '';
    userStatus = '';
    usersLoading = false;
    usersError = null;
    audit = const [];
    auditTotal = 0;
    auditAction = '';
    auditLoading = false;
    auditError = null;
    actionError = null;
    _usersGen++;
    _auditGen++;
    scheduleMicrotask(_notify);
  }

  Future<void> loadStats() async {
    statsLoading = true;
    statsError = null;
    notifyListeners();
    try {
      stats = await _repo.adminDashboard();
    } catch (e) {
      statsError = describeApiErrorTh(e);
    }
    statsLoading = false;
    _notify();
  }

  /// Starts a new search (page 1). A slower, older response never overwrites a newer search.
  Future<void> loadUsers({String? query, String? status}) async {
    userQuery = query ?? userQuery;
    userStatus = status ?? userStatus;
    final gen = ++_usersGen;
    usersLoading = true;
    usersError = null;
    notifyListeners();
    try {
      final page = await _repo.adminUsers(query: userQuery, status: userStatus, offset: 0, limit: pageSize);
      if (gen != _usersGen) return;
      users = page.items;
      usersTotal = page.total;
    } catch (e) {
      if (gen != _usersGen) return;
      users = const [];
      usersTotal = 0;
      usersError = describeApiErrorTh(e);
    }
    usersLoading = false;
    _notify();
  }

  Future<void> loadMoreUsers() async {
    if (usersLoading || !hasMoreUsers) return;
    final gen = _usersGen;
    usersLoading = true;
    notifyListeners();
    try {
      final page = await _repo.adminUsers(query: userQuery, status: userStatus, offset: users.length, limit: pageSize);
      if (gen != _usersGen) return;
      users = [...users, ...page.items];
      usersTotal = page.total;
    } catch (e) {
      if (gen != _usersGen) return;
      usersError = describeApiErrorTh(e);
    }
    usersLoading = false;
    _notify();
  }

  /// Loads one account with its detail fields; returns null and sets [actionError] on failure.
  Future<AdminUser?> loadUser(String id) async {
    actionError = null;
    try {
      return await _repo.adminUser(id);
    } catch (e) {
      actionError = describeApiErrorTh(e);
      _notify();
      return null;
    }
  }

  /// Suspends or reactivates [id]. On success the row in the list is updated in place.
  Future<bool> setStatus(String id, String status, {String reason = ''}) async {
    actionError = null;
    try {
      await _repo.setUserStatus(id: id, status: status, reason: reason.trim());
      users = [for (final u in users) u.id == id ? u.copyWith(status: status) : u];
      // A filtered list (for example "suspended only") must not keep a row that no longer matches.
      if (userStatus.isNotEmpty && userStatus != status) {
        final before = users.length;
        users = users.where((u) => u.id != id).toList();
        if (users.length < before && usersTotal > 0) usersTotal--;
      }
      _notify();
      return true;
    } catch (e) {
      actionError = describeApiErrorTh(e);
      _notify();
      return false;
    }
  }

  Future<void> loadAudit({String? action}) async {
    auditAction = action ?? auditAction;
    final gen = ++_auditGen;
    auditLoading = true;
    auditError = null;
    notifyListeners();
    try {
      final page = await _repo.auditLogs(action: auditAction, offset: 0, limit: pageSize);
      if (gen != _auditGen) return;
      audit = page.items;
      auditTotal = page.total;
    } catch (e) {
      if (gen != _auditGen) return;
      audit = const [];
      auditTotal = 0;
      auditError = describeApiErrorTh(e);
    }
    auditLoading = false;
    _notify();
  }

  Future<void> loadMoreAudit() async {
    if (auditLoading || !hasMoreAudit) return;
    final gen = _auditGen;
    auditLoading = true;
    notifyListeners();
    try {
      final page = await _repo.auditLogs(action: auditAction, offset: audit.length, limit: pageSize);
      if (gen != _auditGen) return;
      audit = [...audit, ...page.items];
      auditTotal = page.total;
    } catch (e) {
      if (gen != _auditGen) return;
      auditError = describeApiErrorTh(e);
    }
    auditLoading = false;
    _notify();
  }
}
