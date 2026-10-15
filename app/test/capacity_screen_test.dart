import 'dart:async';
import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/capacity_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _full = {
  'slots_now': 3,
  'state': {
    'target': 4,
    'running': 2,
    'reason': 'memory is the limit',
    'cores': 8,
    'cpu_fast': 41.5,
    'mem_fast': 62,
    'mem_avail_slow_mb': 2048,
    'mem_total_mb': 8192,
    'disk_pct': 55,
    'disk_free_gb': 120,
    'hosts': {
      'laptop': {
        'ok': true,
        'cpu_pct': 10,
        'mem_pct': 20,
        'disk_pct': 30,
        'disk_free_gb': 40,
      },
      'server': {'ok': false},
    },
    'subscription': {
      'reason': 'close to the limit',
      'windows': {
        '5h': {
          'used': 12300,
          'used_pct': 40,
          'budget_estimate': 30000,
          'burn_per_hour': 2000,
        },
      },
    },
  },
  'scheduler': {
    'running': {
      '11': {'slots': 2},
    },
  },
  'planned': [
    {'issue': 12, 'repo': 'beta', 'width': 1, 'mem_mb': 900, 'cores': 1.5},
  ],
  'planned_sessions': 1,
  'planned_mem_mb': 900,
  'planned_cores': 1.5,
};

Future<http.Response> _json(Object body, [int status = 200]) async =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<void> _pump(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = GatewayClient(
    baseUri: Uri.parse('https://gateway.example.com:8443'),
    token: 't',
    httpClient: MockClient(handler),
  );
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: CapacityScreen(client: client)),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets('a full payload renders every section', (tester) async {
    await _pump(tester, (r) => _json(_full));
    expect(find.text('Agent slots: 3, running: 2'), findsOneWidget);
    expect(find.text('memory is the limit'), findsOneWidget);
    expect(find.text('CPU: 41.5%'), findsOneWidget);
    expect(
      find.text('Memory: 62.0% (2048.0 of 8192.0 MB free)'),
      findsOneWidget,
    );
    expect(find.text('Cores: 8'), findsOneWidget);
    expect(find.byKey(const Key('capacity-host-laptop')), findsOneWidget);
    expect(find.text('laptop'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('capacity-host-server')),
        matching: find.text('Not reachable'),
      ),
      findsOneWidget,
    );
    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('close to the limit'), findsOneWidget);
    expect(
      find.text('5h: 12.3k tokens (40.0%), 2.0k per hour'),
      findsOneWidget,
    );
    expect(find.text('Slots by plan'), findsOneWidget);
    expect(find.text('Plan #11: 2 slots'), findsOneWidget);
    expect(find.text('Planned load'), findsOneWidget);
    expect(
      find.text('#12 beta: 1 sessions, 900.0 MB, 1.5 cores'),
      findsOneWidget,
    );
    expect(find.text('Total: 1 sessions, 900.0 MB, 1.5 cores'), findsOneWidget);
  });

  testWidgets('a null value renders as a dash', (tester) async {
    await _pump(
      tester,
      (r) => _json({
        'state': {'cpu_fast': null},
      }),
    );
    expect(find.text('CPU: —%'), findsOneWidget);
  });

  testWidgets('absent sections leave out their headers', (tester) async {
    await _pump(tester, (r) => _json({'slots_now': 1}));
    expect(tester.takeException(), isNull);
    expect(find.text('Subscription'), findsNothing);
    expect(find.text('Slots by plan'), findsNothing);
    expect(find.text('Planned load'), findsNothing);
    expect(find.text('This server'), findsOneWidget);
  });

  testWidgets('a failed first load offers Try again', (tester) async {
    var ok = false;
    await _pump(
      tester,
      (r) => ok ? _json(_full) : _json({'code': 'x', 'message': 'x'}, 500),
    );
    expect(find.text('Try again'), findsOneWidget);
    ok = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Agent slots: 3, running: 2'), findsOneWidget);
  });

  testWidgets('the initial load finishing after the screen is gone is safe', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await _pump(tester, (r) => pending.future, settle: false);
    await tester.pumpWidget(const SizedBox());
    pending.complete(await _json(_full));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
