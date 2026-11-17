import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/engagement_models.dart';
import '../data/repositories/app_repository.dart';

/// Splits "a, b ,c" into tag labels (comma separated: a tag may contain spaces).
List<String> parseTagInput(String raw) =>
    raw.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

class ReviewsController extends ChangeNotifier {
  ReviewsController(this._repo);

  final AppRepository _repo;

  List<Review> reviews = const [];
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
    if (!loadedOnce && reviews.isEmpty && !loading && error == null) return;
    reviews = const [];
    loading = false;
    loadedOnce = false;
    error = null;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  bool hasReviewedBooking(String bookingId) =>
      reviews.any((r) => r.subjectType == reviewSubjectBooking && r.subjectId == bookingId);

  Future<void> ensureLoaded() async {
    if (loadedOnce || loading) return;
    await load();
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      reviews = await _repo.myReviews();
    } catch (e) {
      error = describeApiErrorTh(e);
    }
    loading = false;
    loadedOnce = true;
    notifyListeners();
  }

  /// Reviews one of the user's own bookings. If the review is saved but tagging fails, the review stays
  /// and [error] says so (never a silent loss).
  Future<bool> reviewBooking(String bookingId, double rating, String body, List<String> tags) async {
    error = null;
    Review created;
    try {
      created = await _repo.createReview(
          subjectType: reviewSubjectBooking, subjectId: bookingId, rating: rating, body: body);
    } on ApiError catch (e) {
      error = e.code == 'CONFLICT' ? 'คุณรีวิวรายการนี้ไปแล้ว' : describeApiErrorTh(e);
      notifyListeners();
      return false;
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return false;
    }
    var saved = created;
    if (tags.isNotEmpty) {
      try {
        final stored = await _repo.setTags(contentType: 'REVIEW', contentId: created.id, tags: tags);
        saved = created.withTags(stored);
      } catch (e) {
        error = 'บันทึกรีวิวแล้ว แต่ตั้งแท็กไม่สำเร็จ: ${describeApiErrorTh(e)}';
      }
    }
    reviews = [saved, ...reviews];
    notifyListeners();
    return error == null;
  }

  Future<bool> delete(String id) async {
    error = null;
    try {
      await _repo.deleteReview(id);
      reviews = reviews.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return false;
    }
  }
}
