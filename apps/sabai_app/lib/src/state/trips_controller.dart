import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/errors/api_error.dart';
import '../data/models/trip_models.dart';
import '../domain/trip_planner.dart';
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

  /// Saves a planner result as a real trip: creates the trip, then adds each item as an activity on its day.
  /// Activities are added one by one; if some fail the trip and the successful ones stay, and [PlanSaveResult.failed]
  /// says how many were lost (never a silent loss).
  Future<PlanSaveResult?> createFromPlan({
    required String name,
    required String startDate,
    required String endDate,
    required List<PlannedDay> plan,
  }) async {
    error = null;
    Trip trip;
    try {
      trip = await _repo.createTrip(name: name, startDate: startDate, endDate: endDate);
    } catch (e) {
      error = describeApiErrorTh(e);
      notifyListeners();
      return null;
    }
    final start = DateTime.parse(startDate);
    var added = 0;
    var failed = 0;
    for (var i = 0; i < plan.length; i++) {
      final day = DateTime(start.year, start.month, start.day + i);
      final iso = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      for (final item in plan[i].items) {
        try {
          await _repo.addActivity(tripId: trip.id, title: item.text, date: iso, startTime: item.time);
          added++;
        } catch (e) {
          failed++;
          error = describeApiErrorTh(e);
        }
      }
    }
    try {
      trips = await _repo.trips();
    } catch (_) {
      // The list refreshes the next time the tab opens.
    }
    notifyListeners();
    return PlanSaveResult(tripId: trip.id, added: added, failed: failed);
  }
}

class PlanSaveResult {
  const PlanSaveResult({required this.tripId, required this.added, required this.failed});
  final String tripId;
  final int added;
  final int failed;
}
