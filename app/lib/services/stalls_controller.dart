import 'dart:async';

import 'package:accent_protocol/protocol.dart';
import 'package:flutter/foundation.dart';

import 'gateway_client.dart';

/// Polling state for the Situation screen: the latest [PlaneStalls] snapshot,
/// the last error and the selected time window.
class StallsController extends ChangeNotifier {
  StallsController(
    this.client, {
    this.pollInterval = const Duration(seconds: 45),
  });

  final GatewayClient client;
  final Duration pollInterval;

  PlaneStalls? _stalls;
  Object? _error;
  int _hours = 24;
  Timer? _timer;
  int _inFlight = 0;
  bool _disposed = false;

  PlaneStalls? get stalls => _stalls;
  Object? get error => _error;
  int get hours => _hours;

  /// Fetches now and then every [pollInterval]. A second call is a no-op.
  void start() {
    if (_timer != null || _disposed) return;
    refresh();
    _timer = Timer.periodic(pollInterval, (_) => _tick());
  }

  void _tick() {
    if (_inFlight > 0) return;
    refresh();
  }

  /// Never throws: a failure is kept in [error] and the old [stalls] stay.
  Future<void> refresh() async {
    final asked = _hours;
    _inFlight++;
    PlaneStalls? result;
    Object? failure;
    var failed = false;
    try {
      result = await client.planeStalls(hours: asked);
    } catch (e) {
      failed = true;
      failure = e;
    } finally {
      _inFlight--;
    }
    if (_disposed || asked != _hours) return;
    if (failed) {
      _error = failure;
    } else {
      _stalls = result;
      _error = null;
    }
    notifyListeners();
  }

  void setHours(int hours) {
    if (hours != 24 && hours != 168) {
      throw ArgumentError.value(hours, 'hours');
    }
    if (hours == _hours) return;
    _hours = hours;
    notifyListeners();
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
