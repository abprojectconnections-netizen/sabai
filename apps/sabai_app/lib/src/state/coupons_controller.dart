import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/community_models.dart';
import '../data/repositories/app_repository.dart';

/// Saved coupons. Display and storage only: nothing here sends a coupon with a booking.
class CouponsController extends ChangeNotifier {
  CouponsController(this._repo);

  final AppRepository _repo;

  List<SavedCoupon> coupons = const [];
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
    if (!loadedOnce && coupons.isEmpty && !loading && error == null) return;
    coupons = const [];
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
      coupons = await _repo.myCoupons();
    } catch (e) {
      error = describeApiErrorTh(e);
    }
    loading = false;
    loadedOnce = true;
    notifyListeners();
  }

  /// Saves a code, then reloads the list so states come from the server. Returns true on success.
  Future<bool> claim(String raw) async {
    final code = raw.trim();
    error = null;
    if (code.isEmpty) {
      error = 'กรุณากรอกรหัสคูปอง';
      notifyListeners();
      return false;
    }
    try {
      await _repo.claimCoupon(code);
    } on ApiError catch (e) {
      error = _claimMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return false;
    }
    await load();
    return error == null;
  }

  String _claimMessage(ApiError e) {
    switch (e.code) {
      case 'NOT_FOUND':
        return 'ไม่พบรหัสคูปองนี้';
      case 'CONFLICT':
        return 'บันทึกคูปองนี้ไม่ได้: อาจบันทึกไปแล้ว หมดอายุ ยังไม่เริ่มใช้ หรือถูกใช้ครบแล้ว';
      default:
        return describeApiErrorTh(e);
    }
  }
}
