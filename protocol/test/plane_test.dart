import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

Map<String, dynamic> bucket(int n) => {
  'steps': n,
  'untracked_steps': n + 1,
  'cost_usd': n + 0.5,
  'input_tokens': n * 10,
  'output_tokens': n * 20,
  'cache_read_tokens': n * 30,
  'cache_write_tokens': n * 40,
};

void expectBucket(UsageBucket b, int n) {
  expect(b.steps, n);
  expect(b.untrackedSteps, n + 1);
  expect(b.costUsd, n + 0.5);
  expect(b.inputTokens, n * 10);
  expect(b.outputTokens, n * 20);
  expect(b.cacheReadTokens, n * 30);
  expect(b.cacheWriteTokens, n * 40);
}

void main() {
  test('PlaneUsage round-trips', () {
    final usage = PlaneUsage.fromJson({
      'generated_at': '2026-10-12T10:00:00.000Z',
      'models': [
        {
          'model': 'm1',
          'today': bucket(1),
          'last_7d': bucket(2),
          'last_30d': bucket(3),
        },
      ],
      'roles': [
        {
          'role': 'developer',
          'model': 'm1',
          'today': bucket(4),
          'last_7d': bucket(5),
          'last_30d': bucket(6),
        },
      ],
    });

    void check(PlaneUsage u) {
      expect(u.generatedAt.toUtc(), DateTime.utc(2026, 10, 12, 10));
      expect(u.models, hasLength(1));
      expect(u.models.single.model, 'm1');
      expectBucket(u.models.single.today, 1);
      expectBucket(u.models.single.last7d, 2);
      expectBucket(u.models.single.last30d, 3);
      expect(u.roles, hasLength(1));
      expect(u.roles.single.role, 'developer');
      expect(u.roles.single.model, 'm1');
      expectBucket(u.roles.single.today, 4);
      expectBucket(u.roles.single.last7d, 5);
      expectBucket(u.roles.single.last30d, 6);
    }

    check(usage);
    final again = PlaneUsage.fromJson(usage.toJson());
    check(again);
  });

  test('PlanList round-trips', () {
    final list = PlanList.fromJson({
      'plans': [
        {
          'id': 'p1',
          'title': 'First plan',
          'status': 'active',
          'tasks': [
            {
              'id': 't1',
              'title': 'First task',
              'status': 'running',
              'target': 'some place',
              'subtasks_done': 2,
              'subtasks_total': 5,
            },
          ],
        },
      ],
    });

    void check(PlanList l) {
      expect(l.plans, hasLength(1));
      final plan = l.plans.single;
      expect(plan.id, 'p1');
      expect(plan.title, 'First plan');
      expect(plan.status, 'active');
      expect(plan.tasks, hasLength(1));
      final task = plan.tasks.single;
      expect(task.id, 't1');
      expect(task.title, 'First task');
      expect(task.status, 'running');
      expect(task.target, 'some place');
      expect(task.subtasksDone, 2);
      expect(task.subtasksTotal, 5);
    }

    check(list);
    final again = PlanList.fromJson(list.toJson());
    check(again);
  });

  test('PlaneStatus round-trips with every nullable field present', () {
    final status = PlaneStatus.fromJson({
      'generated_at': '2026-10-12T10:00:00.000Z',
      'providers': [
        {
          'name': 'prov',
          'has_key': true,
          'current': false,
          'cooling_until': '2026-10-12T11:00:00.000Z',
          'reason': 'rate limited',
        },
      ],
      'services': [
        {'name': 'svc', 'healthy': false, 'detail': 'down'},
      ],
      'paused': [
        {
          'tier': 'high',
          'model': 'm1',
          'use': 'planning',
          'until': '2026-10-12T12:00:00.000Z',
          'reason': 'budget',
        },
      ],
    });

    void check(PlaneStatus s) {
      expect(s.generatedAt.toUtc(), DateTime.utc(2026, 10, 12, 10));
      expect(s.providers, hasLength(1));
      final p = s.providers.single;
      expect(p.name, 'prov');
      expect(p.hasKey, true);
      expect(p.current, false);
      expect(p.coolingUntil!.toUtc(), DateTime.utc(2026, 10, 12, 11));
      expect(p.reason, 'rate limited');
      expect(s.services, hasLength(1));
      expect(s.services.single.name, 'svc');
      expect(s.services.single.healthy, false);
      expect(s.services.single.detail, 'down');
      expect(s.paused, hasLength(1));
      final pause = s.paused.single;
      expect(pause.tier, 'high');
      expect(pause.model, 'm1');
      expect(pause.use, 'planning');
      expect(pause.until!.toUtc(), DateTime.utc(2026, 10, 12, 12));
      expect(pause.reason, 'budget');
    }

    check(status);
    final again = PlaneStatus.fromJson(status.toJson());
    check(again);
  });

  test('PlaneStatus decodes absent nullable fields as null', () {
    final status = PlaneStatus.fromJson({
      'generated_at': '2026-10-12T10:00:00.000Z',
      'providers': [
        {'name': 'prov', 'has_key': false, 'current': true},
      ],
      'services': [
        {'name': 'svc', 'healthy': true},
      ],
      'paused': [
        {
          'tier': 'low',
          'model': 'm2',
          'use': 'coding',
          'until': null,
          'reason': 'manual',
        },
      ],
    });

    void check(PlaneStatus s) {
      expect(s.generatedAt.toUtc(), DateTime.utc(2026, 10, 12, 10));
      final p = s.providers.single;
      expect(p.name, 'prov');
      expect(p.hasKey, false);
      expect(p.current, true);
      expect(p.coolingUntil, isNull);
      expect(p.reason, isNull);
      expect(s.services.single.name, 'svc');
      expect(s.services.single.healthy, true);
      expect(s.services.single.detail, isNull);
      final pause = s.paused.single;
      expect(pause.tier, 'low');
      expect(pause.model, 'm2');
      expect(pause.use, 'coding');
      expect(pause.until, isNull);
      expect(pause.reason, 'manual');
    }

    check(status);
    final json = status.toJson();
    final provider = (json['providers'] as List).single as Map<String, dynamic>;
    final service = (json['services'] as List).single as Map<String, dynamic>;
    final pause = (json['paused'] as List).single as Map<String, dynamic>;
    expect(provider.containsKey('cooling_until'), isFalse);
    expect(provider.containsKey('reason'), isFalse);
    expect(service.containsKey('detail'), isFalse);
    expect(pause.containsKey('until'), isFalse);
    final again = PlaneStatus.fromJson(json);
    check(again);
  });

  test('PlaneActionList round-trips', () {
    final list = PlaneActionList.fromJson({
      'actions': [
        {'token': 'pause', 'args': 'opt-int', 'summary': 'Pause a tier'},
        {'token': 'status', 'args': 'none', 'summary': 'Show status'},
      ],
    });

    void check(PlaneActionList l) {
      expect(l.actions, hasLength(2));
      expect(l.actions[0].token, 'pause');
      expect(l.actions[0].args, 'opt-int');
      expect(l.actions[0].summary, 'Pause a tier');
      expect(l.actions[1].token, 'status');
      expect(l.actions[1].args, 'none');
      expect(l.actions[1].summary, 'Show status');
    }

    check(list);
    final again = PlaneActionList.fromJson(list.toJson());
    check(again);
  });

  test('PlaneActionRequest round-trips with arg', () {
    final request = PlaneActionRequest.fromJson({'token': 'pause', 'arg': '3'});
    expect(request.token, 'pause');
    expect(request.arg, '3');
    final again = PlaneActionRequest.fromJson(request.toJson());
    expect(again.token, 'pause');
    expect(again.arg, '3');
  });

  test('PlaneActionRequest round-trips without arg', () {
    final request = PlaneActionRequest.fromJson({'token': 'status'});
    expect(request.token, 'status');
    expect(request.arg, isNull);
    final json = request.toJson();
    expect(json.containsKey('arg'), isFalse);
    final again = PlaneActionRequest.fromJson(json);
    expect(again.token, 'status');
    expect(again.arg, isNull);
  });

  test('PlaneActionResult round-trips', () {
    final result = PlaneActionResult.fromJson({
      'token': 'pause',
      'exit_code': 2,
      'output': 'done\n',
    });
    expect(result.token, 'pause');
    expect(result.exitCode, 2);
    expect(result.output, 'done\n');
    final again = PlaneActionResult.fromJson(result.toJson());
    expect(again.token, 'pause');
    expect(again.exitCode, 2);
    expect(again.output, 'done\n');
  });
}
