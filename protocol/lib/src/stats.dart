/// A JSON value as a string-keyed map, or an empty map when it is not a map.
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

/// The map elements of a JSON value, or nothing when it is not a list.
List<Map<String, dynamic>> _maps(Object? v) => [
  if (v is List)
    for (final e in v)
      if (e is Map) _map(e),
];

double? _dbl(Object? v) => (v as num?)?.toDouble();

int? _int(Object? v) => (v as num?)?.toInt();

/// One sphere/kind row of `GET /v1/plane/stats`.
class PlaneStatsGroup {
  const PlaneStatsGroup({
    required this.sphere,
    required this.kind,
    this.tasks,
    this.taskWallMinP50,
    this.taskWallMinP90,
    this.taskWorkMinP50,
    this.opusTokensP50,
    this.sonnetTokensP50,
    this.sessionMemMbP90,
    this.sessionCoresP75,
    this.gatesMinP50,
  });

  final String sphere;
  final String kind;
  final int? tasks;
  final double? taskWallMinP50;
  final double? taskWallMinP90;
  final double? taskWorkMinP50;
  final int? opusTokensP50;
  final int? sonnetTokensP50;
  final double? sessionMemMbP90;
  final double? sessionCoresP75;
  final double? gatesMinP50;

  factory PlaneStatsGroup.fromJson(Map<String, dynamic> json) =>
      PlaneStatsGroup(
        sphere: json['sphere'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        tasks: _int(json['tasks']),
        taskWallMinP50: _dbl(json['task_wall_min_p50']),
        taskWallMinP90: _dbl(json['task_wall_min_p90']),
        taskWorkMinP50: _dbl(json['task_work_min_p50']),
        opusTokensP50: _int(json['opus_tokens_p50']),
        sonnetTokensP50: _int(json['sonnet_tokens_p50']),
        sessionMemMbP90: _dbl(json['session_mem_mb_p90']),
        sessionCoresP75: _dbl(json['session_cores_p75']),
        gatesMinP50: _dbl(json['gates_min_p50']),
      );
}

/// One step/model row of `GET /v1/plane/stats`.
class PlaneStepStats {
  const PlaneStepStats({
    required this.step,
    required this.model,
    this.n,
    this.minP50,
    this.minP90,
    this.tokensP50,
    this.shareOfTimePct,
  });

  final String step;
  final String model;
  final int? n;
  final double? minP50;
  final double? minP90;
  final int? tokensP50;
  final double? shareOfTimePct;

  factory PlaneStepStats.fromJson(Map<String, dynamic> json) => PlaneStepStats(
    step: json['step'] as String? ?? '',
    model: json['model'] as String? ?? '',
    n: _int(json['n']),
    minP50: _dbl(json['min_p50']),
    minP90: _dbl(json['min_p90']),
    tokensP50: _int(json['tokens_p50']),
    shareOfTimePct: _dbl(json['share_of_time_pct']),
  );
}

/// One plan's progress forecast in `GET /v1/plane/stats`.
class PlaneForecast {
  const PlaneForecast({
    required this.planId,
    required this.title,
    required this.status,
    this.progressPct,
    this.requirements = const {},
    this.slice,
    this.tasksTotal,
    this.tasksLeft,
    this.paceTasksPerHour,
    this.etaHours,
    this.etaDays,
    this.note,
  });

  final String planId;
  final String title;
  final String status;
  final double? progressPct;
  final Map<String, int> requirements;
  final int? slice;
  final int? tasksTotal;
  final int? tasksLeft;
  final double? paceTasksPerHour;
  final double? etaHours;
  final double? etaDays;
  final String? note;

  factory PlaneForecast.fromJson(Map<String, dynamic> json) => PlaneForecast(
    planId: '${json['issue']}',
    title: json['title'] as String? ?? '',
    status: json['status'] as String? ?? '',
    progressPct: _dbl(json['issue_progress_pct']),
    requirements: {
      for (final e in _map(json['requirements']).entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    },
    slice: _int(json['slice']),
    tasksTotal: _int(json['tasks_total']),
    tasksLeft: _int(json['tasks_left']),
    paceTasksPerHour: _dbl(json['pace_tasks_per_hour']),
    etaHours: _dbl(json['eta_hours_at_pace']),
    etaDays: _dbl(json['issue_eta_days']),
    note: json['note'] as String?,
  );
}

/// The response of `GET /v1/plane/stats`; every field tolerates absence.
class PlaneStats {
  const PlaneStats({
    this.generatedAt,
    this.days,
    this.groups = const [],
    this.steps = const [],
    this.forecast = const [],
  });

  final String? generatedAt;
  final int? days;
  final List<PlaneStatsGroup> groups;
  final List<PlaneStepStats> steps;
  final List<PlaneForecast> forecast;

  factory PlaneStats.fromJson(Map<String, dynamic> json) => PlaneStats(
    generatedAt: json['generated_at'] as String?,
    days: _int(json['days']),
    groups: [
      for (final e in _maps(json['by_sphere_kind']))
        PlaneStatsGroup.fromJson(e),
    ],
    steps: [for (final e in _maps(json['by_step'])) PlaneStepStats.fromJson(e)],
    forecast: [
      for (final e in _maps(json['forecast'])) PlaneForecast.fromJson(e),
    ],
  );
}
