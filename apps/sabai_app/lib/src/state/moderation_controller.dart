import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/community_models.dart';
import '../data/repositories/app_repository.dart';

/// Staff queue of reported community posts. The server decides who may use it (support.manage); this controller only
/// reports what the server answers.
class ModerationController extends ChangeNotifier {
  ModerationController(this._repo);

  final AppRepository _repo;

  List<ReportedPost> queue = const [];
  bool loading = false;
  bool loadedOnce = false;
  String? error;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void reset() {
    if (!loadedOnce && queue.isEmpty && !loading && error == null) return;
    queue = const [];
    loading = false;
    loadedOnce = false;
    error = null;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      queue = await _repo.reportedPosts();
    } catch (e) {
      error = describeApiErrorTh(e);
    }
    loading = false;
    loadedOnce = true;
    notifyListeners();
  }

  /// [action] is `remove` or `dismiss`. On success the post leaves the queue.
  Future<bool> act(String id, String action, {String note = ''}) async {
    error = null;
    try {
      await _repo.moderatePost(id: id, action: action, note: note.trim());
      queue = queue.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return false;
    }
  }
}
