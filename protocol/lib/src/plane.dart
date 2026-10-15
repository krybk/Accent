/// Control-plane read contract.
///
/// The wire types between a client and a control plane reached through the
/// gateway at `/v1/plane`. Errors use the existing `ApiError` ({code, message}).
/// Timestamps are ISO-8601 strings on the wire and [DateTime] in Dart.
library;

/// Usage totals over one window.
class UsageBucket {
  const UsageBucket({
    required this.steps,
    required this.untrackedSteps,
    required this.costUsd,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
  });

  final int steps;

  /// Steps recorded before token counts existed: counted and priced, no tokens.
  final int untrackedSteps;
  final double costUsd;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;

  factory UsageBucket.fromJson(Map<String, dynamic> json) => UsageBucket(
    steps: json['steps'] as int,
    untrackedSteps: json['untracked_steps'] as int,
    costUsd: (json['cost_usd'] as num).toDouble(),
    inputTokens: json['input_tokens'] as int,
    outputTokens: json['output_tokens'] as int,
    cacheReadTokens: json['cache_read_tokens'] as int,
    cacheWriteTokens: json['cache_write_tokens'] as int,
  );

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'untracked_steps': untrackedSteps,
    'cost_usd': costUsd,
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'cache_read_tokens': cacheReadTokens,
    'cache_write_tokens': cacheWriteTokens,
  };
}

/// Usage of one model over the three reporting windows.
class ModelUsage {
  const ModelUsage({
    required this.model,
    required this.today,
    required this.last7d,
    required this.last30d,
  });

  final String model;
  final UsageBucket today;
  final UsageBucket last7d;
  final UsageBucket last30d;

  factory ModelUsage.fromJson(Map<String, dynamic> json) => ModelUsage(
    model: json['model'] as String,
    today: UsageBucket.fromJson(json['today'] as Map<String, dynamic>),
    last7d: UsageBucket.fromJson(json['last_7d'] as Map<String, dynamic>),
    last30d: UsageBucket.fromJson(json['last_30d'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'model': model,
    'today': today.toJson(),
    'last_7d': last7d.toJson(),
    'last_30d': last30d.toJson(),
  };
}

/// Usage of one role, with the model it ran on, over the three windows.
class RoleUsage {
  const RoleUsage({
    required this.role,
    required this.model,
    required this.today,
    required this.last7d,
    required this.last30d,
  });

  final String role;
  final String model;
  final UsageBucket today;
  final UsageBucket last7d;
  final UsageBucket last30d;

  factory RoleUsage.fromJson(Map<String, dynamic> json) => RoleUsage(
    role: json['role'] as String,
    model: json['model'] as String,
    today: UsageBucket.fromJson(json['today'] as Map<String, dynamic>),
    last7d: UsageBucket.fromJson(json['last_7d'] as Map<String, dynamic>),
    last30d: UsageBucket.fromJson(json['last_30d'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'role': role,
    'model': model,
    'today': today.toJson(),
    'last_7d': last7d.toJson(),
    'last_30d': last30d.toJson(),
  };
}

/// Response of `GET /v1/plane/usage`.
class PlaneUsage {
  const PlaneUsage({
    required this.generatedAt,
    required this.models,
    required this.roles,
  });

  final DateTime generatedAt;
  final List<ModelUsage> models;
  final List<RoleUsage> roles;

  factory PlaneUsage.fromJson(Map<String, dynamic> json) => PlaneUsage(
    generatedAt: DateTime.parse(json['generated_at'] as String),
    models: (json['models'] as List)
        .map((e) => ModelUsage.fromJson(e as Map<String, dynamic>))
        .toList(),
    roles: (json['roles'] as List)
        .map((e) => RoleUsage.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'models': models.map((e) => e.toJson()).toList(),
    'roles': roles.map((e) => e.toJson()).toList(),
  };
}

/// One task of a plan, with subtask progress.
class PlanTaskSummary {
  const PlanTaskSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.target,
    required this.subtasksDone,
    required this.subtasksTotal,
  });

  final String id;
  final String title;
  final String status;

  /// Where the task's work lands, free text.
  final String target;
  final int subtasksDone;
  final int subtasksTotal;

  factory PlanTaskSummary.fromJson(Map<String, dynamic> json) =>
      PlanTaskSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        target: json['target'] as String,
        subtasksDone: json['subtasks_done'] as int,
        subtasksTotal: json['subtasks_total'] as int,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'target': target,
    'subtasks_done': subtasksDone,
    'subtasks_total': subtasksTotal,
  };
}

/// One plan and its tasks; [id] is opaque.
class PlanSummary {
  const PlanSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.tasks,
  });

  final String id;
  final String title;
  final String status;
  final List<PlanTaskSummary> tasks;

  factory PlanSummary.fromJson(Map<String, dynamic> json) => PlanSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    status: json['status'] as String,
    tasks: (json['tasks'] as List)
        .map((e) => PlanTaskSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'tasks': tasks.map((e) => e.toJson()).toList(),
  };
}

/// Response of `GET /v1/plane/plans`.
class PlanList {
  const PlanList({required this.plans});

  final List<PlanSummary> plans;

  factory PlanList.fromJson(Map<String, dynamic> json) => PlanList(
    plans: (json['plans'] as List)
        .map((e) => PlanSummary.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'plans': plans.map((e) => e.toJson()).toList(),
  };
}

/// Availability of one model provider.
class PlaneProvider {
  const PlaneProvider({
    required this.name,
    required this.hasKey,
    required this.current,
    this.coolingUntil,
    this.reason,
  });

  final String name;
  final bool hasKey;
  final bool current;
  final DateTime? coolingUntil;
  final String? reason;

  factory PlaneProvider.fromJson(Map<String, dynamic> json) => PlaneProvider(
    name: json['name'] as String,
    hasKey: json['has_key'] as bool,
    current: json['current'] as bool,
    coolingUntil: json['cooling_until'] == null
        ? null
        : DateTime.parse(json['cooling_until'] as String),
    reason: json['reason'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'has_key': hasKey,
    'current': current,
    if (coolingUntil != null)
      'cooling_until': coolingUntil!.toUtc().toIso8601String(),
    if (reason != null) 'reason': reason,
  };
}

/// Health of one service on the plane.
class PlaneService {
  const PlaneService({required this.name, required this.healthy, this.detail});

  final String name;
  final bool healthy;
  final String? detail;

  factory PlaneService.fromJson(Map<String, dynamic> json) => PlaneService(
    name: json['name'] as String,
    healthy: json['healthy'] as bool,
    detail: json['detail'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'healthy': healthy,
    if (detail != null) 'detail': detail,
  };
}

/// One active pause of a tier.
class PlanePause {
  const PlanePause({
    required this.tier,
    required this.model,
    required this.use,
    required this.reason,
    this.until,
  });

  final String tier;
  final String model;
  final String use;

  /// Null means indefinite.
  final DateTime? until;
  final String reason;

  factory PlanePause.fromJson(Map<String, dynamic> json) => PlanePause(
    tier: json['tier'] as String,
    model: json['model'] as String,
    use: json['use'] as String,
    until: json['until'] == null
        ? null
        : DateTime.parse(json['until'] as String),
    reason: json['reason'] as String,
  );

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'model': model,
    'use': use,
    if (until != null) 'until': until!.toUtc().toIso8601String(),
    'reason': reason,
  };
}

/// Response of `GET /v1/plane/status`.
class PlaneStatus {
  const PlaneStatus({
    required this.generatedAt,
    required this.providers,
    required this.services,
    required this.paused,
  });

  final DateTime generatedAt;
  final List<PlaneProvider> providers;
  final List<PlaneService> services;
  final List<PlanePause> paused;

  factory PlaneStatus.fromJson(Map<String, dynamic> json) => PlaneStatus(
    generatedAt: DateTime.parse(json['generated_at'] as String),
    providers: (json['providers'] as List)
        .map((e) => PlaneProvider.fromJson(e as Map<String, dynamic>))
        .toList(),
    services: (json['services'] as List)
        .map((e) => PlaneService.fromJson(e as Map<String, dynamic>))
        .toList(),
    paused: (json['paused'] as List)
        .map((e) => PlanePause.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'generated_at': generatedAt.toUtc().toIso8601String(),
    'providers': providers.map((e) => e.toJson()).toList(),
    'services': services.map((e) => e.toJson()).toList(),
    'paused': paused.map((e) => e.toJson()).toList(),
  };
}

/// One action a client may request.
class PlaneAction {
  const PlaneAction({
    required this.token,
    required this.args,
    required this.summary,
  });

  final String token;

  /// One of `none`, `int`, `opt-int`.
  final String args;
  final String summary;

  factory PlaneAction.fromJson(Map<String, dynamic> json) => PlaneAction(
    token: json['token'] as String,
    args: json['args'] as String,
    summary: json['summary'] as String,
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'args': args,
    'summary': summary,
  };
}

/// Response of `GET /v1/plane/actions`.
class PlaneActionList {
  const PlaneActionList({required this.actions});

  final List<PlaneAction> actions;

  factory PlaneActionList.fromJson(Map<String, dynamic> json) =>
      PlaneActionList(
        actions: (json['actions'] as List)
            .map((e) => PlaneAction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'actions': actions.map((e) => e.toJson()).toList(),
  };
}

/// Body of `POST /v1/plane/actions`.
class PlaneActionRequest {
  const PlaneActionRequest({required this.token, this.arg});

  final String token;
  final String? arg;

  factory PlaneActionRequest.fromJson(Map<String, dynamic> json) =>
      PlaneActionRequest(
        token: json['token'] as String,
        arg: json['arg'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'token': token,
    if (arg != null) 'arg': arg,
  };
}

/// The 200 response of `POST /v1/plane/actions`.
class PlaneActionResult {
  const PlaneActionResult({
    required this.token,
    required this.exitCode,
    required this.output,
  });

  final String token;
  final int exitCode;
  final String output;

  factory PlaneActionResult.fromJson(Map<String, dynamic> json) =>
      PlaneActionResult(
        token: json['token'] as String,
        exitCode: json['exit_code'] as int,
        output: json['output'] as String,
      );

  Map<String, dynamic> toJson() => {
    'token': token,
    'exit_code': exitCode,
    'output': output,
  };
}

/// The body of `POST /v1/plane/chat`.
class PlaneChatRequest {
  const PlaneChatRequest({
    required this.message,
    this.sessionId,
    required this.tier,
  });

  final String message;
  final String? sessionId;
  final String tier;

  factory PlaneChatRequest.fromJson(Map<String, dynamic> json) =>
      PlaneChatRequest(
        message: json['message'] as String,
        sessionId: json['session_id'] as String?,
        tier: json['tier'] as String,
      );

  Map<String, dynamic> toJson() => {
    'message': message,
    'session_id': sessionId,
    'tier': tier,
  };
}

/// One server-sent event of the `POST /v1/plane/chat` answer stream.
sealed class PlaneChatEvent {
  const PlaneChatEvent();

  Map<String, dynamic> toJson();

  static PlaneChatEvent parse(String event, Map<String, dynamic> data) =>
      switch (event) {
        'session' => PlaneChatSession.fromJson(data),
        'delta' => PlaneChatDelta.fromJson(data),
        'done' => PlaneChatDone.fromJson(data),
        'error' => PlaneChatError.fromJson(data),
        _ => throw FormatException('unknown chat event: $event'),
      };
}

/// The `session` chat event: which session and model answer.
final class PlaneChatSession extends PlaneChatEvent {
  const PlaneChatSession({required this.sessionId, required this.model});

  final String sessionId;
  final String model;

  factory PlaneChatSession.fromJson(Map<String, dynamic> json) =>
      PlaneChatSession(
        sessionId: json['session_id'] as String,
        model: json['model'] as String,
      );

  @override
  Map<String, dynamic> toJson() => {'session_id': sessionId, 'model': model};
}

/// The `delta` chat event: a piece of the answer text.
final class PlaneChatDelta extends PlaneChatEvent {
  const PlaneChatDelta({required this.text});

  final String text;

  factory PlaneChatDelta.fromJson(Map<String, dynamic> json) =>
      PlaneChatDelta(text: json['text'] as String);

  @override
  Map<String, dynamic> toJson() => {'text': text};
}

/// The `done` chat event: the answer is complete, with its cost.
final class PlaneChatDone extends PlaneChatEvent {
  const PlaneChatDone({
    required this.sessionId,
    required this.model,
    required this.costUsd,
    required this.inputTokens,
    required this.outputTokens,
    required this.cacheReadTokens,
    required this.cacheWriteTokens,
    required this.turns,
  });

  final String sessionId;
  final String model;
  final double? costUsd;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final int? turns;

  factory PlaneChatDone.fromJson(Map<String, dynamic> json) => PlaneChatDone(
    sessionId: json['session_id'] as String,
    model: json['model'] as String,
    costUsd: (json['cost_usd'] as num?)?.toDouble(),
    inputTokens: json['input_tokens'] as int,
    outputTokens: json['output_tokens'] as int,
    cacheReadTokens: json['cache_read_tokens'] as int,
    cacheWriteTokens: json['cache_write_tokens'] as int,
    turns: json['turns'] as int?,
  );

  @override
  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'model': model,
    'cost_usd': costUsd,
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'cache_read_tokens': cacheReadTokens,
    'cache_write_tokens': cacheWriteTokens,
    'turns': turns,
  };
}

/// The `error` chat event; [code] is refused, timeout, failed or switched.
final class PlaneChatError extends PlaneChatEvent {
  const PlaneChatError({
    required this.code,
    required this.message,
    required this.subtype,
    required this.apiErrorStatus,
  });

  final String code;
  final String message;
  final String? subtype;
  final int? apiErrorStatus;

  factory PlaneChatError.fromJson(Map<String, dynamic> json) => PlaneChatError(
    code: json['code'] as String,
    message: json['message'] as String,
    subtype: json['subtype'] as String?,
    apiErrorStatus: json['api_error_status'] as int?,
  );

  @override
  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    'subtype': subtype,
    'api_error_status': apiErrorStatus,
  };
}

/// The body of `POST /v1/plane/plans/{id}/guidance`.
class PlaneGuidanceRequest {
  const PlaneGuidanceRequest({required this.text});

  final String text;

  factory PlaneGuidanceRequest.fromJson(Map<String, dynamic> json) =>
      PlaneGuidanceRequest(text: json['text'] as String);

  Map<String, dynamic> toJson() => {'text': text};
}

/// The response of `POST /v1/plane/plans/{id}/guidance`.
class PlaneGuidanceResult {
  const PlaneGuidanceResult({required this.planId, required this.commentUrl});

  final String planId;
  final String commentUrl;

  factory PlaneGuidanceResult.fromJson(Map<String, dynamic> json) =>
      PlaneGuidanceResult(
        planId: json['plan_id'] as String,
        commentUrl: json['comment_url'] as String,
      );

  Map<String, dynamic> toJson() => {
    'plan_id': planId,
    'comment_url': commentUrl,
  };
}

/// One model tier's switch state in `GET /v1/plane/models`.
class PlaneModelSwitch {
  const PlaneModelSwitch({
    required this.tier,
    required this.model,
    required this.enabled,
    required this.standIn,
    required this.standInModel,
    required this.until,
    required this.reason,
  });

  final String tier;
  final String model;
  final bool enabled;
  final String? standIn;
  final String? standInModel;
  final DateTime? until;
  final String? reason;

  factory PlaneModelSwitch.fromJson(Map<String, dynamic> json) =>
      PlaneModelSwitch(
        tier: json['tier'] as String,
        model: json['model'] as String,
        enabled: json['enabled'] as bool,
        standIn: json['stand_in'] as String?,
        standInModel: json['stand_in_model'] as String?,
        until: json['until'] == null
            ? null
            : DateTime.parse(json['until'] as String),
        reason: json['reason'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'tier': tier,
    'model': model,
    'enabled': enabled,
    'stand_in': standIn,
    'stand_in_model': standInModel,
    'until': until?.toUtc().toIso8601String(),
    'reason': reason,
  };
}

/// The response of `GET /v1/plane/models` and of the disable/enable calls.
class PlaneModelSwitchList {
  const PlaneModelSwitchList({required this.models});

  final List<PlaneModelSwitch> models;

  factory PlaneModelSwitchList.fromJson(Map<String, dynamic> json) =>
      PlaneModelSwitchList(
        models: [
          for (final m in json['models'] as List<dynamic>)
            PlaneModelSwitch.fromJson(m as Map<String, dynamic>),
        ],
      );

  Map<String, dynamic> toJson() => {
    'models': [for (final m in models) m.toJson()],
  };
}

/// One entry of `GET /v1/plane/queue`.
class PlaneQueueEntry {
  const PlaneQueueEntry({
    required this.id,
    required this.title,
    required this.status,
    required this.position,
    required this.held,
    required this.ownerOrdered,
  });

  final String id;
  final String title;
  final String status;
  final int position;
  final bool held;
  final bool ownerOrdered;

  factory PlaneQueueEntry.fromJson(Map<String, dynamic> json) =>
      PlaneQueueEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        position: json['position'] as int,
        held: json['held'] as bool,
        ownerOrdered: json['owner_ordered'] as bool,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'position': position,
    'held': held,
    'owner_ordered': ownerOrdered,
  };
}

/// The response of `GET /v1/plane/queue` and of `POST /v1/plane/queue/{id}/{verb}`.
class PlaneQueue {
  const PlaneQueue({required this.entries});

  final List<PlaneQueueEntry> entries;

  factory PlaneQueue.fromJson(Map<String, dynamic> json) => PlaneQueue(
    entries: [
      for (final e in json['queue'] as List<dynamic>)
        PlaneQueueEntry.fromJson(e as Map<String, dynamic>),
    ],
  );

  Map<String, dynamic> toJson() => {
    'queue': [for (final e in entries) e.toJson()],
  };
}

/// The path segment of `POST /v1/plane/queue/{id}/{verb}` is `verb.name`.
enum PlaneQueueVerb { up, down, top, bottom, hold, resume }
