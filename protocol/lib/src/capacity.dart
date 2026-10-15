/// A JSON value as a string-keyed map, or an empty map when it is not a map.
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

double? _dbl(Object? v) => (v as num?)?.toDouble();

int? _int(Object? v) => (v as num?)?.toInt();

/// One host's load in `GET /v1/plane/capacity`; [name] is the host's map key.
class PlaneHostLoad {
  const PlaneHostLoad({
    required this.name,
    this.ok,
    this.busy,
    this.cpuPct,
    this.memPct,
    this.diskPct,
    this.diskFreeGb,
  });

  final String name;
  final bool? ok;
  final bool? busy;
  final double? cpuPct;
  final double? memPct;
  final double? diskPct;
  final double? diskFreeGb;

  factory PlaneHostLoad.fromJson(String name, Map<String, dynamic> json) =>
      PlaneHostLoad(
        name: name,
        ok: json['ok'] as bool?,
        busy: json['busy'] as bool?,
        cpuPct: _dbl(json['cpu_pct']),
        memPct: _dbl(json['mem_pct']),
        diskPct: _dbl(json['disk_pct']),
        diskFreeGb: _dbl(json['disk_free_gb']),
      );
}

/// One subscription window in `GET /v1/plane/capacity`; [name] is e.g. `5h`.
class PlaneSubscriptionWindow {
  const PlaneSubscriptionWindow({
    required this.name,
    this.used,
    this.usedPct,
    this.budgetEstimate,
    this.burnPerHour,
  });

  final String name;
  final int? used;
  final double? usedPct;
  final int? budgetEstimate;
  final int? burnPerHour;

  factory PlaneSubscriptionWindow.fromJson(
    String name,
    Map<String, dynamic> json,
  ) => PlaneSubscriptionWindow(
    name: name,
    used: _int(json['used']),
    usedPct: _dbl(json['used_pct']),
    budgetEstimate: _int(json['budget_estimate']),
    burnPerHour: _int(json['burn_per_hour']),
  );
}

/// The slots one running plan holds in `GET /v1/plane/capacity`.
class PlaneSlotUse {
  const PlaneSlotUse({required this.planId, this.slots});

  final String planId;
  final int? slots;

  factory PlaneSlotUse.fromJson(String planId, Map<String, dynamic> json) =>
      PlaneSlotUse(planId: planId, slots: _int(json['slots']));
}

/// The load a planned plan is expected to add in `GET /v1/plane/capacity`.
class PlanePlannedLoad {
  const PlanePlannedLoad({
    required this.planId,
    required this.repo,
    required this.width,
    this.memMb,
    this.cores,
  });

  final String planId;
  final String repo;
  final int width;
  final double? memMb;
  final double? cores;

  factory PlanePlannedLoad.fromJson(Map<String, dynamic> json) =>
      PlanePlannedLoad(
        planId: '${json['issue']}',
        repo: json['repo'] as String? ?? '',
        width: (json['width'] as num?)?.toInt() ?? 0,
        memMb: _dbl(json['mem_mb']),
        cores: _dbl(json['cores']),
      );
}

/// The response of `GET /v1/plane/capacity`; every field tolerates absence.
class PlaneCapacity {
  const PlaneCapacity({
    this.slotsNow,
    this.target,
    this.running,
    this.reason,
    this.cores,
    this.cpuPct,
    this.memPct,
    this.memAvailableMb,
    this.memTotalMb,
    this.diskPct,
    this.diskFreeGb,
    this.diskHoursLeft,
    this.hosts = const [],
    this.subscriptionReason,
    this.windows = const [],
    this.slotsByPlan = const [],
    this.planned = const [],
    this.plannedSessions,
    this.plannedMemMb,
    this.plannedCores,
  });

  final int? slotsNow;
  final int? target;
  final int? running;
  final String? reason;
  final int? cores;
  final double? cpuPct;
  final double? memPct;
  final double? memAvailableMb;
  final double? memTotalMb;
  final double? diskPct;
  final double? diskFreeGb;
  final double? diskHoursLeft;
  final List<PlaneHostLoad> hosts;
  final String? subscriptionReason;
  final List<PlaneSubscriptionWindow> windows;
  final List<PlaneSlotUse> slotsByPlan;
  final List<PlanePlannedLoad> planned;
  final int? plannedSessions;
  final double? plannedMemMb;
  final double? plannedCores;

  factory PlaneCapacity.fromJson(Map<String, dynamic> json) {
    final state = _map(json['state']);
    final subscription = _map(state['subscription']);
    final planned = json['planned'];
    return PlaneCapacity(
      slotsNow: _int(json['slots_now']),
      target: _int(state['target']),
      running: _int(state['running']),
      reason: state['reason'] as String?,
      cores: _int(state['cores']),
      cpuPct: _dbl(state['cpu_fast']),
      memPct: _dbl(state['mem_fast']),
      memAvailableMb: _dbl(state['mem_avail_slow_mb']),
      memTotalMb: _dbl(state['mem_total_mb']),
      diskPct: _dbl(state['disk_pct']),
      diskFreeGb: _dbl(state['disk_free_gb']),
      diskHoursLeft: _dbl(state['disk_hours_left']),
      hosts: [
        for (final e in _map(state['hosts']).entries)
          PlaneHostLoad.fromJson(e.key, _map(e.value)),
      ],
      subscriptionReason: subscription['reason'] as String?,
      windows: [
        for (final e in _map(subscription['windows']).entries)
          PlaneSubscriptionWindow.fromJson(e.key, _map(e.value)),
      ],
      slotsByPlan: [
        for (final e in _map(_map(json['scheduler'])['running']).entries)
          PlaneSlotUse.fromJson(e.key, _map(e.value)),
      ],
      planned: [
        if (planned is List)
          for (final e in planned)
            if (e is Map) PlanePlannedLoad.fromJson(_map(e)),
      ],
      plannedSessions: _int(json['planned_sessions']),
      plannedMemMb: _dbl(json['planned_mem_mb']),
      plannedCores: _dbl(json['planned_cores']),
    );
  }
}
