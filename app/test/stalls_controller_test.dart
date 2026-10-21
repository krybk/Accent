import 'dart:async';
import 'dart:convert';

import 'package:accent/services/gateway_client.dart';
import 'package:accent/services/stalls_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _payload(int issue, {int hours = 24}) => http.Response(
  jsonEncode({
    'slots': 2,
    'running': 1,
    'free': 1,
    'plans': [
      {'issue': issue, 'title': 'Plan $issue', 'state': 'working'},
    ],
    'summary': {'hours': hours},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _failure() => http.Response(
  jsonEncode({
    'error': {'code': 'x', 'message': 'y'},
  }),
  500,
  headers: {'content-type': 'application/json'},
);

GatewayClient _client(Future<http.Response> Function(http.Request) handler) =>
    GatewayClient(
      baseUri: Uri.parse('https://gateway.example.com:8443'),
      token: 't',
      httpClient: MockClient(handler),
    );

void main() {
  const tick = Duration(seconds: 45);

  testWidgets('start requests once, then on every tick', (tester) async {
    final hours = <String?>[];
    final controller = StallsController(
      _client((r) async {
        hours.add(r.url.queryParameters['hours']);
        return _payload(101);
      }),
    );
    controller.start();
    controller.start();
    await tester.pump();
    expect(hours, ['24']);
    expect(controller.stalls!.plans.first.issue, 101);
    await tester.pump(tick);
    expect(hours, ['24', '24']);
    controller.dispose();
  });

  testWidgets('a tick during a request sends nothing extra', (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    final controller = StallsController(
      _client((r) async {
        calls++;
        await gate.future;
        return _payload(101);
      }),
      // Shorter than the client's request timeout, so the held request is
      // still in flight when the timer fires.
      pollInterval: const Duration(seconds: 5),
    );
    controller.start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 1);
    gate.complete();
    await tester.pump();
    expect(controller.stalls, isNotNull);
    controller.dispose();
  });

  testWidgets('failure keeps stalls, sets error, notifies; success clears', (
    tester,
  ) async {
    var fail = false;
    final controller = StallsController(
      _client((r) async => fail ? _failure() : _payload(101)),
    );
    var notified = 0;
    controller.addListener(() => notified++);
    controller.start();
    await tester.pump();
    final before = controller.stalls;
    expect(before, isNotNull);
    expect(notified, 1);

    fail = true;
    await tester.pump(tick);
    expect(controller.stalls, same(before));
    expect(controller.error, isNotNull);
    expect(notified, 2);

    fail = false;
    await tester.pump(tick);
    expect(controller.error, isNull);
    expect(controller.stalls, isNot(same(before)));
    expect(notified, 3);
    controller.dispose();
  });

  testWidgets('a result for stale hours is discarded', (tester) async {
    final first = Completer<void>();
    final hours = <String?>[];
    final controller = StallsController(
      _client((r) async {
        final h = r.url.queryParameters['hours'];
        hours.add(h);
        if (h == '24') {
          await first.future;
          return _payload(101);
        }
        return _payload(102, hours: 168);
      }),
    );
    controller.start();
    await tester.pump();
    controller.setHours(168);
    await tester.pump();
    expect(hours, ['24', '168']);
    expect(controller.stalls!.plans.first.issue, 102);

    first.complete();
    await tester.pump();
    expect(controller.stalls!.plans.first.issue, 102);
    expect(controller.hours, 168);
    controller.dispose();
  });

  testWidgets('nothing is requested after dispose', (tester) async {
    var calls = 0;
    final controller = StallsController(
      _client((r) async {
        calls++;
        return _payload(101);
      }),
    );
    controller.start();
    await tester.pump();
    expect(calls, 1);
    controller.dispose();
    await tester.pump(tick);
    await tester.pump(tick);
    expect(calls, 1);
  });

  testWidgets('setHours rejects unsupported windows', (tester) async {
    final controller = StallsController(_client((r) async => _payload(101)));
    expect(() => controller.setHours(48), throwsArgumentError);
    expect(controller.hours, 24);
    controller.dispose();
  });
}
