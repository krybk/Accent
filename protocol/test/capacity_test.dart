import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('PlaneCapacity parses every field', () {
    final c = PlaneCapacity.fromJson({
      'slots_now': 3,
      'state': {
        'slots': 4,
        'target': 5,
        'running': 2,
        'reason': 'cpu high',
        'cores': 8,
        'cpu_fast': 41,
        'mem_fast': 55.5,
        'mem_avail_slow_mb': 6000,
        'mem_total_mb': 16000.5,
        'disk_pct': 62,
        'disk_free_gb': 120.25,
        'disk_hours_left': 48,
        'hosts': {
          'laptop': {
            'ok': true,
            'busy': false,
            'cpu_pct': 10,
            'mem_pct': 20.5,
            'disk_pct': 30,
            'disk_free_gb': 40.5,
          },
          'server': {
            'ok': false,
            'busy': true,
            'cpu_pct': null,
            'mem_pct': 70,
            'disk_pct': 80.5,
            'disk_free_gb': 90,
          },
        },
        'subscription': {
          'reason': 'near limit',
          'windows': {
            '5h': {
              'used': 120,
              'used_pct': 60,
              'budget_estimate': 200,
              'burn_per_hour': 25,
            },
            '7d': {
              'used': 900,
              'used_pct': 45.5,
              'budget_estimate': 2000,
              'burn_per_hour': 5,
            },
          },
        },
      },
      'planned': [
        {'issue': 11, 'repo': 'alpha', 'width': 2, 'mem_mb': 1500, 'cores': 2},
        {
          'issue': 12,
          'repo': 'beta',
          'width': 1,
          'mem_mb': 700.5,
          'cores': 1.5,
        },
      ],
      'scheduler': {
        'running': {
          '11': {'slots': 2, 'since': 1000},
          '12': {'slots': 1, 'since': 2000.5},
        },
      },
      'planned_sessions': 3,
      'planned_mem_mb': 2200,
      'planned_cores': 3.5,
    });
    expect(c.slotsNow, 3);
    expect(c.target, 5);
    expect(c.running, 2);
    expect(c.reason, 'cpu high');
    expect(c.cores, 8);
    expect(c.cpuPct, 41.0);
    expect(c.cpuPct, isA<double>());
    expect(c.memPct, 55.5);
    expect(c.memAvailableMb, 6000.0);
    expect(c.memAvailableMb, isA<double>());
    expect(c.memTotalMb, 16000.5);
    expect(c.diskPct, 62.0);
    expect(c.diskPct, isA<double>());
    expect(c.diskFreeGb, 120.25);
    expect(c.diskHoursLeft, 48.0);
    expect(c.diskHoursLeft, isA<double>());

    expect(c.hosts.map((h) => h.name), ['laptop', 'server']);
    final laptop = c.hosts[0];
    expect(laptop.ok, true);
    expect(laptop.busy, false);
    expect(laptop.cpuPct, 10.0);
    expect(laptop.cpuPct, isA<double>());
    expect(laptop.memPct, 20.5);
    expect(laptop.diskPct, 30.0);
    expect(laptop.diskPct, isA<double>());
    expect(laptop.diskFreeGb, 40.5);
    final server = c.hosts[1];
    expect(server.ok, false);
    expect(server.busy, true);
    expect(server.cpuPct, isNull);
    expect(server.memPct, 70.0);
    expect(server.diskPct, 80.5);
    expect(server.diskFreeGb, 90.0);
    expect(server.diskFreeGb, isA<double>());

    expect(c.subscriptionReason, 'near limit');
    expect(c.windows.map((w) => w.name), ['5h', '7d']);
    expect(c.windows[0].used, 120);
    expect(c.windows[0].usedPct, 60.0);
    expect(c.windows[0].usedPct, isA<double>());
    expect(c.windows[0].budgetEstimate, 200);
    expect(c.windows[0].burnPerHour, 25);
    expect(c.windows[1].used, 900);
    expect(c.windows[1].usedPct, 45.5);
    expect(c.windows[1].budgetEstimate, 2000);
    expect(c.windows[1].burnPerHour, 5);

    expect(c.slotsByPlan.map((s) => s.planId), ['11', '12']);
    expect(c.slotsByPlan[0].slots, 2);
    expect(c.slotsByPlan[1].slots, 1);

    expect(c.planned.map((p) => p.planId), ['11', '12']);
    expect(c.planned[0].repo, 'alpha');
    expect(c.planned[0].width, 2);
    expect(c.planned[0].memMb, 1500.0);
    expect(c.planned[0].memMb, isA<double>());
    expect(c.planned[0].cores, 2.0);
    expect(c.planned[0].cores, isA<double>());
    expect(c.planned[1].repo, 'beta');
    expect(c.planned[1].width, 1);
    expect(c.planned[1].memMb, 700.5);
    expect(c.planned[1].cores, 1.5);

    expect(c.plannedSessions, 3);
    expect(c.plannedMemMb, 2200.0);
    expect(c.plannedMemMb, isA<double>());
    expect(c.plannedCores, 3.5);
  });

  test('PlaneCapacity reads nulls as null and defaults', () {
    final c = PlaneCapacity.fromJson({
      'slots_now': null,
      'state': {
        'target': null,
        'running': null,
        'reason': null,
        'cores': null,
        'cpu_fast': null,
        'mem_fast': null,
        'mem_avail_slow_mb': null,
        'mem_total_mb': null,
        'disk_pct': null,
        'disk_free_gb': null,
        'disk_hours_left': null,
        'hosts': {
          'laptop': {
            'ok': null,
            'busy': null,
            'cpu_pct': null,
            'mem_pct': null,
            'disk_pct': null,
            'disk_free_gb': null,
          },
          'server': 'down',
        },
        'subscription': {
          'reason': null,
          'windows': {
            '5h': {
              'used': null,
              'used_pct': null,
              'budget_estimate': null,
              'burn_per_hour': null,
            },
            '7d': 'n/a',
          },
        },
      },
      'planned': [
        {
          'issue': 11,
          'repo': null,
          'width': null,
          'mem_mb': null,
          'cores': null,
        },
        'junk',
      ],
      'scheduler': {
        'running': {
          '11': {'slots': null},
          '12': 7,
        },
      },
      'planned_sessions': null,
      'planned_mem_mb': null,
      'planned_cores': null,
    });
    expect(c.slotsNow, isNull);
    expect(c.target, isNull);
    expect(c.running, isNull);
    expect(c.reason, isNull);
    expect(c.cores, isNull);
    expect(c.cpuPct, isNull);
    expect(c.memPct, isNull);
    expect(c.memAvailableMb, isNull);
    expect(c.memTotalMb, isNull);
    expect(c.diskPct, isNull);
    expect(c.diskFreeGb, isNull);
    expect(c.diskHoursLeft, isNull);
    expect(c.hosts.map((h) => h.name), ['laptop', 'server']);
    for (final h in c.hosts) {
      expect(h.ok, isNull);
      expect(h.busy, isNull);
      expect(h.cpuPct, isNull);
      expect(h.memPct, isNull);
      expect(h.diskPct, isNull);
      expect(h.diskFreeGb, isNull);
    }
    expect(c.subscriptionReason, isNull);
    expect(c.windows.map((w) => w.name), ['5h', '7d']);
    for (final w in c.windows) {
      expect(w.used, isNull);
      expect(w.usedPct, isNull);
      expect(w.budgetEstimate, isNull);
      expect(w.burnPerHour, isNull);
    }
    expect(c.slotsByPlan.map((s) => s.planId), ['11', '12']);
    expect(c.slotsByPlan[0].slots, isNull);
    expect(c.slotsByPlan[1].slots, isNull);
    expect(c.planned, hasLength(1));
    expect(c.planned[0].planId, '11');
    expect(c.planned[0].repo, '');
    expect(c.planned[0].width, 0);
    expect(c.planned[0].memMb, isNull);
    expect(c.planned[0].cores, isNull);
    expect(c.plannedSessions, isNull);
    expect(c.plannedMemMb, isNull);
    expect(c.plannedCores, isNull);
  });

  test('PlaneCapacity tolerates absent sections and an empty body', () {
    final c = PlaneCapacity.fromJson({'slots_now': 2});
    expect(c.slotsNow, 2);
    expect(c.target, isNull);
    expect(c.reason, isNull);
    expect(c.hosts, isEmpty);
    expect(c.windows, isEmpty);
    expect(c.slotsByPlan, isEmpty);
    expect(c.planned, isEmpty);
    expect(c.subscriptionReason, isNull);
    expect(c.plannedSessions, isNull);

    final e = PlaneCapacity.fromJson({});
    expect(e.slotsNow, isNull);
    expect(e.hosts, isEmpty);
    expect(e.windows, isEmpty);
    expect(e.slotsByPlan, isEmpty);
    expect(e.planned, isEmpty);
    expect(e.plannedMemMb, isNull);
    expect(e.plannedCores, isNull);
  });
}
