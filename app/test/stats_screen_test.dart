import 'dart:async';
import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/stats_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _full = {
  'days': 14,
  'forecast': [
    {
      'issue': '11',
      'title': 'First plan',
      'status': 'running',
      'issue_progress_pct': 50,
      'tasks_total': 8,
      'tasks_left': 3,
      'eta_hours_at_pace': 6.5,
    },
  ],
  'by_sphere_kind': [
    {
      'sphere': 'alpha',
      'kind': 'feature',
      'tasks': 4,
      'task_wall_min_p50': 12.5,
      'task_work_min_p50': 8.5,
      'opus_tokens_p50': 120000,
      'sonnet_tokens_p50': 800,
      'session_mem_mb_p90': 2048.5,
      'session_cores_p75': 1.5,
      'gates_min_p50': 3.5,
    },
  ],
  'by_step': [
    {
      'step': 'plan',
      'model': 'opus',
      'n': 10,
      'min_p50': 4.5,
      'min_p90': 9.5,
      'share_of_time_pct': 40.5,
    },
  ],
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
      home: Scaffold(body: StatsScreen(client: client)),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  testWidgets('a full payload renders every section', (tester) async {
    await _pump(tester, (r) => _json(_full));
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('#11 First plan'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0.5,
    );
    expect(find.text('Requirements done: 50.0%'), findsOneWidget);
    expect(find.text('Tasks left in this slice: 3 of 8'), findsOneWidget);
    expect(find.text('At the current pace: 6.5 h'), findsOneWidget);
    expect(find.text('alpha · feature'), findsOneWidget);
    expect(
      find.text(
        '4 tasks · 12.5 min wall · 8.5 min work · Opus 120.0k / Sonnet 800 '
        'tokens\n'
        'Session memory p90 2048.5 MB · cores p75 1.5 · gates p50 3.5 min',
      ),
      findsOneWidget,
    );
    expect(find.text('plan · opus'), findsOneWidget);
    expect(
      find.text('10 runs · p50 4.5 min · p90 9.5 min · 40.5% of time'),
      findsOneWidget,
    );
    expect(find.text('Last 14 days'), findsOneWidget);
  });

  testWidgets('a null renders a dash and no progress bar', (tester) async {
    await _pump(
      tester,
      (r) => _json({
        'forecast': [
          {'issue': '12', 'title': 'Second plan', 'eta_hours_at_pace': null},
        ],
      }),
    );
    expect(find.text('At the current pace: — h'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Requirements done: —%'), findsOneWidget);
  });

  testWidgets('absent sections have no header', (tester) async {
    await _pump(tester, (r) => _json({'days': 7}));
    expect(find.text('By step'), findsNothing);
    expect(find.text('Forecast'), findsNothing);
    expect(find.text('By sphere and kind'), findsNothing);
    expect(find.text('Last 7 days'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed first load offers Try again', (tester) async {
    var ok = false;
    await _pump(
      tester,
      (r) => ok
          ? _json(_full)
          : _json({'code': 'plane_unavailable', 'message': 'x'}, 503),
    );
    expect(find.text('Try again'), findsOneWidget);
    ok = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('stats-forecast-11')), findsOneWidget);
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
