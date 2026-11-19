import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/engagement_models.dart';
import '../data/repositories/app_repository.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repo);

  final AppRepository _repo;

  List<AppNotification> items = const [];
  int unreadCount = 0;
  bool loading = false;
  bool loadedOnce = false;
  String? error;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Sign-out: called during a provider update (build phase), so listeners are notified on a microtask.
  void reset() {
    if (!loadedOnce && items.isEmpty && !loading && error == null) return;
    items = const [];
    unreadCount = 0;
    loading = false;
    loadedOnce = false;
    error = null;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  /// Loads once per sign-in (the bell calls this); [load] forces a refresh.
  Future<void> ensureLoaded() async {
    if (loadedOnce || loading) return;
    await load();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final page = await _repo.notifications();
      items = page.items;
      unreadCount = page.unreadCount;
    } catch (e) {
      error = describeApiErrorTh(e);
    }
    loading = false;
    loadedOnce = true;
    notifyListeners();
  }

  Future<void> markRead(AppNotification n) async {
    if (n.read) return;
    try {
      await _repo.markNotificationRead(n.id);
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return;
    }
    items = [for (final x in items) x.id == n.id ? x.copyWith(read: true) : x];
    if (unreadCount > 0) unreadCount -= 1;
    notifyListeners();
  }

  Future<void> markAllRead() async {
    try {
      await _repo.markAllNotificationsRead();
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return;
    }
    items = [for (final x in items) x.copyWith(read: true)];
    unreadCount = 0;
    notifyListeners();
  }
}
