import 'package:accent_protocol/protocol.dart';
import 'package:test/test.dart';

void main() {
  test('both disks and laptop sensors survive the wire contract', () {
    final data = PlaneCapacity.fromJson({
      'state': {
        'hosts': {
          'buildhost': {
            'ok': true,
            'temperature_c': 67.5,
            'disks': [
              {
                'device': '/dev/sda2',
                'mount': '/',
                'total_gb': 120,
                'free_gb': 44,
                'used_pct': 63,
              },
              {
                'device': '/dev/sdc1',
                'mount': '/mnt/build-disk',
                'total_gb': 737,
                'free_gb': 577,
                'used_pct': 16,
              },
            ],
            'sensors': [
              {'name': 'coretemp: Package id 0', 'celsius': 67.5},
            ],
          },
        },
      },
    });
    final host = data.hosts.single;
    expect(host.temperatureC, 67.5);
    expect(host.disks.map((d) => d.mount), ['/', '/mnt/build-disk']);
    expect(host.disks.last.freeGb, 577);
    expect(host.sensors.single.celsius, 67.5);
    expect(PlaneCapacity.fromJson({}).disks, isEmpty);
  });
  test('live progress and held state are independent from scheduler state', () {
    final p = PlaneStallPlan.fromJson({
      'issue': 288,
      'state': 'frozen',
      'held': true,
      'slice': 13,
      'tasks_done': 14,
      'tasks_total': 18,
      'steps_last_hour': 5,
      'active_tasks': [
        {
          'id': 't6',
          'title': 'Terminal',
          'status': 'running',
          'subtasks_done': 3,
          'subtasks_total': 4,
        },
      ],
    });
    expect(p.held, isTrue);
    expect(p.tasksDone, 14);
    expect(p.stepsLastHour, 5);
    expect(p.activeTasks.single.title, 'Terminal');
    expect(p.activeTasks.single.subtasksDone, 3);
  });
}
