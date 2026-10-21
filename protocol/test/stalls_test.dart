import 'dart:convert';
import 'dart:io';

import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  late PlaneStalls stalls;

  setUp(() {
    final json = jsonDecode(
      File('test/fixtures/stalls.json').readAsStringSync(),
    );
    stalls = PlaneStalls.fromJson(json as Map<String, dynamic>);
  });

  test('top-level fields', () {
    expect(stalls.at, '2026-10-21T05:00:00Z');
    expect(stalls.slots, 4);
    expect(stalls.running, 1);
    expect(stalls.free, 3);
    expect(stalls.idleReason, 'build_wait');
    expect(stalls.states.length, 2);
    expect(stalls.states['101'], 'working');
  });

  test('plan 101 fields', () {
    final p = stalls.plans.first;
    expect(p.issue, 101);
    expect(p.title, 'Plan 101');
    expect(p.status, 'open');
    expect(p.priority, 0);
    expect(p.state, 'working');
    expect(p.detail, 'detail working');
    expect(p.sessions, 1);
    expect(p.wants, 1);
    expect(p.since, '2026-10-20T21:19:00Z');
    expect(p.forMin, 10);
    expect(stalls.plans[1].priority, isNull);
  });

  test('plan states survive verbatim in order', () {
    expect(stalls.plans.map((p) => p.state).toList(), [
      'working',
      'short_of_slots',
      'build_wait',
      'draining',
      'planning',
      'planning_wait',
      'queued',
      'cooldown',
      'waiting_merge',
      'waiting_owner',
      'blocked',
      'budget',
      'held',
      'frozen',
      'idle',
      'mystery_state',
    ]);
  });

  test('waiting entry with string issue', () {
    final w = stalls.waiting.first;
    expect(w.issue, 150);
    expect(w.item, 'item-1');
    expect(w.step, 'step-1');
    expect(w.repo, 'owner/repo');
    expect(w.kind, 'build');
    expect(w.waitedMin, 25);
  });

  test('waiting entry without issue', () {
    final w = stalls.waiting[1];
    expect(w.issue, isNull);
    expect(w.waitedMin, 5);
  });

  test('question attention', () {
    final a = stalls.attention.first;
    expect(a.kind, 'question');
    expect(a.severity, 'act');
    expect(a.issue, 101);
    expect(a.title, 'Plan 101');
    expect(a.detail, 'question detail');
    expect(a.action, 'fix question');
    expect(a.url, 'https://example.org/issues/101');
    expect(a.task, 't2');
    expect(a.since, '2026-10-20T21:19:00Z');
  });

  test('disk attention', () {
    final a = stalls.attention.firstWhere((a) => a.kind == 'disk');
    expect(a.issue, isNull);
    expect(a.title, '');
    expect(a.url, isNull);
    expect(a.task, isNull);
  });

  test('attention kinds and severities survive verbatim', () {
    expect(stalls.attention.map((a) => a.kind).toList(), [
      'question',
      'blocked',
      'budget',
      'held',
      'build_wait',
      'disk',
      'host_busy',
      'service',
      'provider',
      'mystery_kind',
    ]);
    expect(stalls.attention.last.severity, 'mystery');
    expect(stalls.actCount, 2);
  });

  test('summary', () {
    final s = stalls.summary;
    expect(s.hours, 24);
    expect(s.byPlan.length, 1);
    expect(s.byPlan.containsKey(101), isTrue);
    expect(s.byPlan[101]!['working'], 1.0);
    expect(s.byPlan[101]!['draining'], 110.5);
    expect(s.idleSlotHours.keys.toList(), ['build_wait', 'scheduler']);
    expect(s.idleSlotHours['build_wait'], 2.5);
    expect(s.freeShare, 0.25);
  });

  test('longest interval', () {
    expect(stalls.summary.longest.length, 1);
    final i = stalls.summary.longest.first;
    expect(i.issue, 101);
    expect(i.state, 'draining');
    expect(i.detail, 'round age');
    expect(i.start, '2026-10-20T21:19:00Z');
    expect(i.minutes, 110.0);
  });

  test('null free_share and empty longest', () {
    final s = PlaneStalls.fromJson({
      'summary': {'free_share': null, 'longest': []},
    });
    expect(s.summary.freeShare, isNull);
    expect(s.summary.longest, isEmpty);
  });

  test('empty payload does not throw', () {
    final s = PlaneStalls.fromJson({});
    expect(s.slots, 0);
    expect(s.plans, isEmpty);
    expect(s.summary.hours, 0);
    expect(s.at, isNull);
  });

  test('non-numeric issue string is null', () {
    expect(PlaneBuildWait.fromJson({'issue': 'abc'}).issue, isNull);
  });
}
