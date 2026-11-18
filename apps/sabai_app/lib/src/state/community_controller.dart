import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/community_models.dart';
import '../data/repositories/app_repository.dart';

/// The community feed. Posts appear at once (no pre-moderation); abuse is reported afterwards.
class CommunityController extends ChangeNotifier {
  CommunityController(this._repo);

  final AppRepository _repo;

  List<CommunityPost> posts = const [];
  bool loading = false;
  bool loadedOnce = false;
  String? error;

  /// True when the last [post] call stored the post, even if tagging then failed.
  bool lastPostPublished = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void reset() {
    if (!loadedOnce && posts.isEmpty && !loading && error == null) return;
    posts = const [];
    loading = false;
    loadedOnce = false;
    error = null;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> ensureLoaded() async {
    if (loadedOnce || loading) return;
    await load();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      posts = await _repo.communityFeed();
    } catch (e) {
      error = describeApiErrorTh(e);
    }
    loading = false;
    loadedOnce = true;
    notifyListeners();
  }

  /// Publishes a post. If it is saved but tagging fails, the post stays and [error] says so.
  Future<bool> post(String body, List<String> tags) async {
    error = null;
    lastPostPublished = false;
    CommunityPost created;
    try {
      created = await _repo.createPost(body.trim());
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return false;
    }
    lastPostPublished = true;
    var saved = created;
    if (tags.isNotEmpty) {
      try {
        final stored = await _repo.setTags(contentType: 'COMMUNITY_POST', contentId: created.id, tags: tags);
        saved = created.withTags(stored);
      } catch (e) {
        error = 'โพสต์แล้ว แต่ตั้งแท็กไม่สำเร็จ: ${describeApiErrorTh(e)}';
      }
    }
    posts = [saved, ...posts];
    notifyListeners();
    return error == null;
  }

  Future<bool> delete(String id) async {
    error = null;
    try {
      await _repo.deletePost(id);
      posts = posts.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return false;
    }
  }

  /// Reports a post; the server hides it from this user afterwards, so it leaves the list here too.
  Future<bool> report(String id, String reason, {String detail = ''}) async {
    error = null;
    try {
      await _repo.reportPost(id: id, reason: reason, detail: detail);
      posts = posts.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return false;
    }
  }
}
