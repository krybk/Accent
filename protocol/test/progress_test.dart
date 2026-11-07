import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('PlaneProgress parses every field', () {
    final p = PlaneProgress.fromJson({
      'generated_at': '2026-11-07T03:00:00Z',
      'plans': [
        {
          'issue': 288,
          'title': 'Hopdeck: a free MobaXterm',
          'project': 'Hopdeck',
          'status': 'running',
          'state': 'working',
          'detail': '2 session(s)',
          'phase': 'working',
          'held': false,
          'requirements': {'pct': 78.1, 'done': 25, 'total': 32},
          'slice': {
            'number': 18,
            'tasks_total': 7,
            'tasks_done': 6,
            'tasks_left': 1,
            'left': [
              {'id': 't6', 'title': 'Mosh client', 'status': 'running'},
            ],
          },
          'sessions': 2,
          'eta': {'slice_hours': 55.5, 'issue_days': 2.6, 'issue_hours': 62.4},
          'blocked': null,
          'questions': [
            {'task': 't6', 'text': 'Which port?'},
          ],
        },
      ],
    });
    expect(p.generatedAt, '2026-11-07T03:00:00Z');
    final r = p.plans.single;
    expect(r.issue, 288);
    expect(r.project, 'Hopdeck');
    expect(r.phase, 'working');
    expect(r.requirementsPct, 78.1);
    expect(r.requirementsDone, 25);
    expect(r.requirementsTotal, 32);
    expect(r.slice, 18);
    expect((r.tasksTotal, r.tasksDone, r.tasksLeft), (7, 6, 1));
    expect(r.left.single.id, 't6');
    expect(r.left.single.title, 'Mosh client');
    expect(r.sessions, 2);
    expect(r.etaSliceHours, 55.5);
    expect(r.etaIssueDays, 2.6);
    expect(r.etaIssueHours, 62.4);
    expect(r.blocked, isNull);
    expect(r.questions.single.text, 'Which port?');
  });

  test('missing and null values read as unknown, not as errors', () {
    final r = PlaneProgress.fromJson({
      'plans': [
        {
          'issue': 441,
          'phase': 'blocked',
          'requirements': {'pct': null},
          'eta': {'slice_hours': null},
          'blocked': 'waiting for the owner',
        },
        'not a map',
      ],
    }).plans.single;
    expect(r.requirementsPct, isNull);
    expect(r.etaSliceHours, isNull);
    expect(r.etaIssueDays, isNull);
    expect(r.tasksTotal, 0);
    expect(r.left, isEmpty);
    expect(r.blocked, 'waiting for the owner');
    expect(PlaneProgress.fromJson({}).plans, isEmpty);
  });
}
