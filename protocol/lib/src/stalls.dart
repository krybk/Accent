/// A JSON value as a string-keyed map, or an empty map when it is not a map.
Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

int? _int(Object? v) => v is num ? v.toInt() : null;

double? _dbl(Object? v) => v is num ? v.toDouble() : null;

String? _str(Object? v) => v is String ? v : null;

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>(),
      ]
    : const [];

/// The whole `GET /v1/plane/stalls` payload.
class PlaneStalls {
  const PlaneStalls({
    this.at,
    this.slots = 0,
    this.running = 0,
    this.free = 0,
    this.idleReason,
    this.plans = const [],
    this.waiting = const [],
    this.attention = const [],
    this.states = const {},
    this.summary = const PlaneStallSummary(),
  });

  final String? at;
  final int slots;
  final int running;
  final int free;
  final String? idleReason;
  final List<PlaneStallPlan> plans;
  final List<PlaneBuildWait> waiting;
  final List<PlaneAttention> attention;
  final Map<String, String> states;
  final PlaneStallSummary summary;

  /// How many attention items need the owner to act.
  int get actCount => attention.where((a) => a.severity == 'act').length;

  factory PlaneStalls.fromJson(Map<String, dynamic> json) => PlaneStalls(
    at: _str(json['at']),
    slots: _int(json['slots']) ?? 0,
    running: _int(json['running']) ?? 0,
    free: _int(json['free']) ?? 0,
    idleReason: _str(json['idle_reason']),
    plans: [for (final e in _list(json['plans'])) PlaneStallPlan.fromJson(e)],
    waiting: [
      for (final e in _list(json['waiting'])) PlaneBuildWait.fromJson(e),
    ],
    attention: [
      for (final e in _list(json['attention'])) PlaneAttention.fromJson(e),
    ],
    states: {
      for (final e in _map(json['states']).entries)
        if (e.value is String) e.key: e.value as String,
    },
    summary: PlaneStallSummary.fromJson(_map(json['summary'])),
  );
}

/// One plan's current state in `GET /v1/plane/stalls`.
class PlaneStallPlan {
  const PlaneStallPlan({
    this.issue = 0,
    this.title = '',
    this.status = '',
    this.priority,
    this.state = '',
    this.detail = '',
    this.sessions = 0,
    this.wants = 0,
    this.since,
    this.forMin = 0,
  });

  final int issue;
  final String title;
  final String status;
  final int? priority;
  final String state;
  final String detail;
  final int sessions;
  final int wants;
  final String? since;
  final int forMin;

  factory PlaneStallPlan.fromJson(Map<String, dynamic> json) => PlaneStallPlan(
    issue: _int(json['issue']) ?? 0,
    title: _str(json['title']) ?? '',
    status: _str(json['status']) ?? '',
    priority: _int(json['priority']),
    state: _str(json['state']) ?? '',
    detail: _str(json['detail']) ?? '',
    sessions: _int(json['sessions']) ?? 0,
    wants: _int(json['wants']) ?? 0,
    since: _str(json['since']),
    forMin: _int(json['for_min']) ?? 0,
  );
}

/// One build waiting for a slot in `GET /v1/plane/stalls`.
class PlaneBuildWait {
  const PlaneBuildWait({
    this.issue,
    this.item,
    this.step,
    this.repo,
    this.kind,
    this.waitedMin = 0,
  });

  final int? issue;
  final String? item;
  final String? step;
  final String? repo;
  final String? kind;
  final int waitedMin;

  factory PlaneBuildWait.fromJson(Map<String, dynamic> json) {
    final i = json['issue'];
    return PlaneBuildWait(
      issue: i is int ? i : (i is String ? int.tryParse(i) : null),
      item: _str(json['item']),
      step: _str(json['step']),
      repo: _str(json['repo']),
      kind: _str(json['kind']),
      waitedMin: _int(json['waited_min']) ?? 0,
    );
  }
}

/// One item needing attention in `GET /v1/plane/stalls`.
class PlaneAttention {
  const PlaneAttention({
    this.kind = '',
    this.severity = '',
    this.issue,
    this.title = '',
    this.detail = '',
    this.action = '',
    this.url,
    this.task,
    this.since,
  });

  final String kind;
  final String severity;
  final int? issue;
  final String title;
  final String detail;
  final String action;
  final String? url;
  final String? task;
  final String? since;

  factory PlaneAttention.fromJson(Map<String, dynamic> json) => PlaneAttention(
    kind: _str(json['kind']) ?? '',
    severity: _str(json['severity']) ?? '',
    issue: _int(json['issue']),
    title: _str(json['title']) ?? '',
    detail: _str(json['detail']) ?? '',
    action: _str(json['action']) ?? '',
    url: _str(json['url']),
    task: _str(json['task']),
    since: _str(json['since']),
  );
}

/// The hour-window summary in `GET /v1/plane/stalls`.
class PlaneStallSummary {
  const PlaneStallSummary({
    this.hours = 0,
    this.byPlan = const {},
    this.idleSlotHours = const {},
    this.freeShare,
    this.longest = const [],
  });

  final int hours;
  final Map<int, Map<String, double>> byPlan;
  final Map<String, double> idleSlotHours;
  final double? freeShare;
  final List<PlaneStallInterval> longest;

  factory PlaneStallSummary.fromJson(Map<String, dynamic> json) {
    final byPlan = <int, Map<String, double>>{};
    for (final e in _map(json['by_plan']).entries) {
      final k = int.tryParse(e.key);
      if (k == null) continue;
      byPlan[k] = {
        for (final s in _map(e.value).entries)
          if (s.value is num) s.key: (s.value as num).toDouble(),
      };
    }
    return PlaneStallSummary(
      hours: _int(json['hours']) ?? 0,
      byPlan: byPlan,
      idleSlotHours: {
        for (final e in _map(json['idle_slot_hours']).entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
      freeShare: _dbl(json['free_share']),
      longest: [
        for (final e in _list(json['longest'])) PlaneStallInterval.fromJson(e),
      ],
    );
  }
}

/// One long stall interval in `GET /v1/plane/stalls`.
class PlaneStallInterval {
  const PlaneStallInterval({
    this.issue = 0,
    this.state = '',
    this.detail,
    this.start,
    this.minutes = 0.0,
  });

  final int issue;
  final String state;
  final String? detail;
  final String? start;
  final double minutes;

  factory PlaneStallInterval.fromJson(Map<String, dynamic> json) =>
      PlaneStallInterval(
        issue: _int(json['issue']) ?? 0,
        state: _str(json['state']) ?? '',
        detail: _str(json['detail']),
        start: _str(json['start']),
        minutes: _dbl(json['minutes']) ?? 0.0,
      );
}
