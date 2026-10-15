import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('PlaneStats parses every field', () {
    final s = PlaneStats.fromJson({
      'generated_at': '2026-10-15T06:00:00Z',
      'days': 14,
      'by_sphere_kind': [
        {
          'sphere': 'alpha',
          'kind': 'feature',
          'tasks': 12,
          'task_wall_min_p50': 30,
          'task_wall_min_p90': 75.5,
          'task_work_min_p50': 20,
          'opus_tokens_p50': 1000,
          'sonnet_tokens_p50': 2000,
          'session_mem_mb_p90': 900,
          'session_cores_p75': 1.5,
          'gates_min_p50': 4,
        },
        {
          'sphere': 'beta',
          'kind': 'fix',
          'tasks': 3,
          'task_wall_min_p50': 10.5,
          'task_wall_min_p90': 20,
          'task_work_min_p50': 8.5,
          'opus_tokens_p50': 500,
          'sonnet_tokens_p50': 600,
          'session_mem_mb_p90': 400.5,
          'session_cores_p75': 1,
          'gates_min_p50': 2.5,
        },
      ],
      'by_step': [
        {
          'step': 'plan',
          'model': 'opus',
          'n': 5,
          'min_p50': 6,
          'min_p90': 12.5,
          'tokens_p50': 3000,
          'share_of_time_pct': 40,
        },
        {
          'step': 'build',
          'model': 'sonnet',
          'n': 9,
          'min_p50': 7.5,
          'min_p90': 15,
          'tokens_p50': 4000,
          'share_of_time_pct': 55.5,
        },
      ],
      'forecast': [
        {
          'issue': 11,
          'title': 'First plan',
          'status': 'running',
          'issue_progress_pct': 50,
          'requirements': {'done': 3, 'open': 2.0, 'bad': 'x'},
          'slice': 2,
          'tasks_total': 10,
          'tasks_left': 5,
          'pace_tasks_per_hour': 2,
          'eta_hours_at_pace': 2.5,
          'issue_eta_days': 1,
          'note': 'on track',
        },
        {
          'issue': 12,
          'title': 'Second plan',
          'status': 'waiting',
          'issue_progress_pct': 12.5,
          'requirements': {'open': 4},
          'slice': 1,
          'tasks_total': 8,
          'tasks_left': 8,
          'pace_tasks_per_hour': 0.5,
          'eta_hours_at_pace': 16,
          'issue_eta_days': 2.5,
          'note': 'slow',
        },
      ],
    });
    expect(s.generatedAt, '2026-10-15T06:00:00Z');
    expect(s.days, 14);

    expect(s.groups.map((g) => g.sphere), ['alpha', 'beta']);
    final a = s.groups[0];
    expect(a.kind, 'feature');
    expect(a.tasks, 12);
    expect(a.taskWallMinP50, 30.0);
    expect(a.taskWallMinP50, isA<double>());
    expect(a.taskWallMinP90, 75.5);
    expect(a.taskWorkMinP50, 20.0);
    expect(a.taskWorkMinP50, isA<double>());
    expect(a.opusTokensP50, 1000);
    expect(a.sonnetTokensP50, 2000);
    expect(a.sessionMemMbP90, 900.0);
    expect(a.sessionMemMbP90, isA<double>());
    expect(a.sessionCoresP75, 1.5);
    expect(a.gatesMinP50, 4.0);
    expect(a.gatesMinP50, isA<double>());
    final b = s.groups[1];
    expect(b.kind, 'fix');
    expect(b.tasks, 3);
    expect(b.taskWallMinP50, 10.5);
    expect(b.taskWallMinP90, 20.0);
    expect(b.taskWallMinP90, isA<double>());
    expect(b.taskWorkMinP50, 8.5);
    expect(b.opusTokensP50, 500);
    expect(b.sonnetTokensP50, 600);
    expect(b.sessionMemMbP90, 400.5);
    expect(b.sessionCoresP75, 1.0);
    expect(b.sessionCoresP75, isA<double>());
    expect(b.gatesMinP50, 2.5);

    expect(s.steps.map((x) => x.step), ['plan', 'build']);
    expect(s.steps[0].model, 'opus');
    expect(s.steps[0].n, 5);
    expect(s.steps[0].minP50, 6.0);
    expect(s.steps[0].minP50, isA<double>());
    expect(s.steps[0].minP90, 12.5);
    expect(s.steps[0].tokensP50, 3000);
    expect(s.steps[0].shareOfTimePct, 40.0);
    expect(s.steps[0].shareOfTimePct, isA<double>());
    expect(s.steps[1].model, 'sonnet');
    expect(s.steps[1].n, 9);
    expect(s.steps[1].minP50, 7.5);
    expect(s.steps[1].minP90, 15.0);
    expect(s.steps[1].minP90, isA<double>());
    expect(s.steps[1].tokensP50, 4000);
    expect(s.steps[1].shareOfTimePct, 55.5);

    expect(s.forecast.map((f) => f.planId), ['11', '12']);
    final f = s.forecast[0];
    expect(f.title, 'First plan');
    expect(f.status, 'running');
    expect(f.progressPct, 50.0);
    expect(f.progressPct, isA<double>());
    expect(f.requirements, {'done': 3, 'open': 2});
    expect(f.slice, 2);
    expect(f.tasksTotal, 10);
    expect(f.tasksLeft, 5);
    expect(f.paceTasksPerHour, 2.0);
    expect(f.paceTasksPerHour, isA<double>());
    expect(f.etaHours, 2.5);
    expect(f.etaDays, 1.0);
    expect(f.etaDays, isA<double>());
    expect(f.note, 'on track');
    final g = s.forecast[1];
    expect(g.title, 'Second plan');
    expect(g.status, 'waiting');
    expect(g.progressPct, 12.5);
    expect(g.requirements, {'open': 4});
    expect(g.slice, 1);
    expect(g.tasksTotal, 8);
    expect(g.tasksLeft, 8);
    expect(g.paceTasksPerHour, 0.5);
    expect(g.etaHours, 16.0);
    expect(g.etaHours, isA<double>());
    expect(g.etaDays, 2.5);
    expect(g.note, 'slow');
  });

  test('PlaneStats reads nulls as null and defaults', () {
    final s = PlaneStats.fromJson({
      'generated_at': null,
      'days': null,
      'by_sphere_kind': [
        {
          'sphere': null,
          'kind': null,
          'tasks': null,
          'task_wall_min_p50': null,
          'task_wall_min_p90': null,
          'task_work_min_p50': null,
          'opus_tokens_p50': null,
          'sonnet_tokens_p50': null,
          'session_mem_mb_p90': null,
          'session_cores_p75': null,
          'gates_min_p50': null,
        },
        'junk',
      ],
      'by_step': [
        {
          'step': null,
          'model': null,
          'n': null,
          'min_p50': null,
          'min_p90': null,
          'tokens_p50': null,
          'share_of_time_pct': null,
        },
      ],
      'forecast': [
        {
          'issue': 11,
          'title': null,
          'status': null,
          'issue_progress_pct': null,
          'requirements': null,
          'slice': null,
          'tasks_total': null,
          'tasks_left': null,
          'pace_tasks_per_hour': null,
          'eta_hours_at_pace': null,
          'issue_eta_days': null,
          'note': null,
        },
      ],
    });
    expect(s.generatedAt, isNull);
    expect(s.days, isNull);
    expect(s.groups, hasLength(1));
    final g = s.groups[0];
    expect(g.sphere, '');
    expect(g.kind, '');
    expect(g.tasks, isNull);
    expect(g.taskWallMinP50, isNull);
    expect(g.taskWallMinP90, isNull);
    expect(g.taskWorkMinP50, isNull);
    expect(g.opusTokensP50, isNull);
    expect(g.sonnetTokensP50, isNull);
    expect(g.sessionMemMbP90, isNull);
    expect(g.sessionCoresP75, isNull);
    expect(g.gatesMinP50, isNull);
    expect(s.steps, hasLength(1));
    final t = s.steps[0];
    expect(t.step, '');
    expect(t.model, '');
    expect(t.n, isNull);
    expect(t.minP50, isNull);
    expect(t.minP90, isNull);
    expect(t.tokensP50, isNull);
    expect(t.shareOfTimePct, isNull);
    expect(s.forecast, hasLength(1));
    final f = s.forecast[0];
    expect(f.planId, '11');
    expect(f.title, '');
    expect(f.status, '');
    expect(f.progressPct, isNull);
    expect(f.requirements, isEmpty);
    expect(f.slice, isNull);
    expect(f.tasksTotal, isNull);
    expect(f.tasksLeft, isNull);
    expect(f.paceTasksPerHour, isNull);
    expect(f.etaHours, isNull);
    expect(f.etaDays, isNull);
    expect(f.note, isNull);
  });

  test('PlaneStats tolerates absent sections and an empty body', () {
    final s = PlaneStats.fromJson({
      'generated_at': '2026-10-15T06:00:00Z',
      'days': 7,
      'by_sphere_kind': [
        {'sphere': 'alpha', 'kind': 'fix'},
      ],
    });
    expect(s.generatedAt, '2026-10-15T06:00:00Z');
    expect(s.days, 7);
    expect(s.groups, hasLength(1));
    expect(s.groups[0].sphere, 'alpha');
    expect(s.groups[0].tasks, isNull);
    expect(s.steps, isEmpty);
    expect(s.forecast, isEmpty);

    final e = PlaneStats.fromJson({});
    expect(e.generatedAt, isNull);
    expect(e.days, isNull);
    expect(e.groups, isEmpty);
    expect(e.steps, isEmpty);
    expect(e.forecast, isEmpty);
  });
}
