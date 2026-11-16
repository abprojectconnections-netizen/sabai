import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/trip_models.dart';
import '../data/repositories/app_repository.dart';

/// State of the trips feature. Cleared when the user signs out (see app.dart).
class TripsController extends ChangeNotifier {
  TripsController(this._repo);

  final AppRepository _repo;

  List<Trip> trips = const [];
  bool loading = false;
  String? error;

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Called from a provider update (build phase), so listeners are notified on a microtask, never synchronously.
  void reset() {
    if (trips.isEmpty && !loading && error == null) return;
    trips = const [];
    loading = false;
    error = null;
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    error = null;
    try {
      await action();
      return true;
    } catch (e) {
      error = describeApiErrorTh(e);
      return false;
    } finally {
      notifyListeners();
    }
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    await _run(() async => trips = await _repo.trips());
    loading = false;
    notifyListeners();
  }

  Future<Trip?> create(String name, {String startDate = '', String endDate = ''}) async {
    Trip? created;
    await _run(() async {
      created = await _repo.createTrip(name: name, startDate: startDate, endDate: endDate);
      trips = await _repo.trips();
    });
    return created;
  }

  Future<bool> delete(String id) => _run(() async {
        await _repo.deleteTrip(id);
        trips = trips.where((t) => t.id != id).toList();
      });

  /// Detail with days and activities. Returns null (and sets [error]) on failure.
  Future<Trip?> open(String id) async {
    Trip? t;
    await _run(() async => t = await _repo.trip(id));
    return t;
  }

  Future<bool> addActivity(String tripId,
          {required String title, required String date, String startTime = '', String endTime = ''}) =>
      _run(() async {
        await _repo.addActivity(tripId: tripId, title: title, date: date, startTime: startTime, endTime: endTime);
      });

  Future<bool> removeActivity(String tripId, String activityId) =>
      _run(() => _repo.removeActivity(tripId: tripId, activityId: activityId));
}
