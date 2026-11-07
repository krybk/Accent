int? _int(Object? v) => v is num ? v.toInt() : null;

double? _dbl(Object? v) => v is num ? v.toDouble() : null;

String? _str(Object? v) => v is String ? v : null;

Map<String, dynamic> _map(Object? v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) e.cast<String, dynamic>(),
      ]
    : const [];

/// The whole `GET /v1/plane/progress` payload: the owner's progress table,
/// computed by the plane on every request.
class PlaneProgress {
  const PlaneProgress({this.generatedAt, this.plans = const []});

  final String? generatedAt;
  final List<PlaneProgressPlan> plans;

  factory PlaneProgress.fromJson(Map<String, dynamic> json) => PlaneProgress(
    generatedAt: _str(json['generated_at']),
    plans: [
      for (final e in _list(json['plans'])) PlaneProgressPlan.fromJson(e),
    ],
  );
}

/// A task of the running slice that is not done yet.
class PlaneProgressTask {
  const PlaneProgressTask({this.id = '', this.title = '', this.status = ''});

  final String id;
  final String title;
  final String status;

  factory PlaneProgressTask.fromJson(Map<String, dynamic> json) =>
      PlaneProgressTask(
        id: _str(json['id']) ?? '',
        title: _str(json['title']) ?? '',
        status: _str(json['status']) ?? '',
      );
}

/// A question a task asks the owner.
class PlaneProgressQuestion {
  const PlaneProgressQuestion({this.task = '', this.text = ''});

  final String task;
  final String text;

  factory PlaneProgressQuestion.fromJson(Map<String, dynamic> json) =>
      PlaneProgressQuestion(
        task: _str(json['task']) ?? '',
        text: _str(json['text']) ?? '',
      );
}

/// One open plan's row of `GET /v1/plane/progress`.
///
/// [phase] is the plane's word for the forecast cell: `working`, `paused`
/// (held or frozen), `blocked`, `waiting_owner` or `waiting`. Every ETA is null
/// when the plane has too little history to say.
class PlaneProgressPlan {
  const PlaneProgressPlan({
    this.issue = 0,
    this.title = '',
    this.project = '',
    this.status = '',
    this.state = '',
    this.detail,
    this.phase = '',
    this.held = false,
    this.requirementsPct,
    this.requirementsDone = 0,
    this.requirementsTotal = 0,
    this.slice = 1,
    this.tasksTotal = 0,
    this.tasksDone = 0,
    this.tasksLeft = 0,
    this.left = const [],
    this.sessions = 0,
    this.etaSliceHours,
    this.etaIssueDays,
    this.etaIssueHours,
    this.blocked,
    this.questions = const [],
  });

  final int issue;
  final String title;
  final String project;
  final String status;
  final String state;
  final String? detail;
  final String phase;
  final bool held;
  final double? requirementsPct;
  final int requirementsDone;
  final int requirementsTotal;
  final int slice;
  final int tasksTotal;
  final int tasksDone;
  final int tasksLeft;
  final List<PlaneProgressTask> left;
  final int sessions;
  final double? etaSliceHours;
  final double? etaIssueDays;
  final double? etaIssueHours;
  final String? blocked;
  final List<PlaneProgressQuestion> questions;

  factory PlaneProgressPlan.fromJson(Map<String, dynamic> json) {
    final req = _map(json['requirements']);
    final sl = _map(json['slice']);
    final eta = _map(json['eta']);
    return PlaneProgressPlan(
      issue: _int(json['issue']) ?? int.tryParse('${json['issue']}') ?? 0,
      title: _str(json['title']) ?? '',
      project: _str(json['project']) ?? '',
      status: _str(json['status']) ?? '',
      state: _str(json['state']) ?? '',
      detail: _str(json['detail']),
      phase: _str(json['phase']) ?? '',
      held: json['held'] == true,
      requirementsPct: _dbl(req['pct']),
      requirementsDone: _int(req['done']) ?? 0,
      requirementsTotal: _int(req['total']) ?? 0,
      slice: _int(sl['number']) ?? 1,
      tasksTotal: _int(sl['tasks_total']) ?? 0,
      tasksDone: _int(sl['tasks_done']) ?? 0,
      tasksLeft: _int(sl['tasks_left']) ?? 0,
      left: [for (final e in _list(sl['left'])) PlaneProgressTask.fromJson(e)],
      sessions: _int(json['sessions']) ?? 0,
      etaSliceHours: _dbl(eta['slice_hours']),
      etaIssueDays: _dbl(eta['issue_days']),
      etaIssueHours: _dbl(eta['issue_hours']),
      blocked: _str(json['blocked']),
      questions: [
        for (final e in _list(json['questions']))
          PlaneProgressQuestion.fromJson(e),
      ],
    );
  }
}
