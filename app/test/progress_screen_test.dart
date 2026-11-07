import 'dart:async';
import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/progress_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _plan(
  int issue,
  String project,
  String phase, {
  double? pct,
  int total = 0,
  int done = 0,
  List<Map<String, dynamic>> left = const [],
  int sessions = 0,
  double? sliceHours,
  double? issueDays,
  String? blocked,
}) => {
  'issue': issue,
  'project': project,
  'title': '$project: title',
  'phase': phase,
  'requirements': {'pct': pct},
  'slice': {
    'number': 1,
    'tasks_total': total,
    'tasks_done': done,
    'tasks_left': total - done,
    'left': left,
  },
  'sessions': sessions,
  'eta': {'slice_hours': sliceHours, 'issue_days': issueDays},
  'blocked': blocked,
};

final _full = {
  'generated_at': '2026-11-07T03:00:00Z',
  'plans': [
    _plan(
      288,
      'Hopdeck',
      'working',
      pct: 78.1,
      total: 7,
      done: 6,
      left: [
        {'id': 't6', 'title': 'Mosh client', 'status': 'running'},
      ],
      sessions: 2,
      sliceHours: 55.5,
    ),
    _plan(
      528,
      'Alf',
      'working',
      pct: 63,
      total: 16,
      done: 14,
      left: [
        {'id': 't13', 'title': 'Catalogue', 'status': 'running'},
        {'id': 't15', 'title': 'Screens', 'status': 'running'},
      ],
      sliceHours: 12.7,
      issueDays: 2.6,
    ),
    _plan(299, 'Kvorum', 'paused', pct: 54.5, total: 5, done: 1),
    _plan(
      441,
      'Hetonis Конфигуратор',
      'blocked',
      blocked: 'R5 релизы по одной функции',
    ),
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
  String locale = 'ru',
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
      locale: Locale(locale),
      home: Scaffold(body: ProgressScreen(client: client)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the table has the four Russian columns and one row per plan', (
    tester,
  ) async {
    await _pump(tester, (r) => _json(_full));
    for (final h in ['Проект', 'Сделано', 'Что дальше', 'Прогноз']) {
      expect(find.text(h), findsOneWidget);
    }
    expect(find.text('Hopdeck #288'), findsOneWidget);
    expect(find.text('78% требований'), findsOneWidget);
    expect(
      find.text(
        'в текущем этапе осталась 1 задача из 7\nt6 Mosh client\n'
        'работают 2 агента',
      ),
      findsOneWidget,
    );
    expect(find.text('~56 ч до конца этапа'), findsOneWidget);
    expect(
      find.text(
        'в текущем этапе осталось 2 задачи из 16\nt13 Catalogue\nt15 Screens',
      ),
      findsOneWidget,
    );
    expect(
      find.text('~13 ч до конца этапа, ~2,6 дня до конца всего Issue'),
      findsOneWidget,
    );
    expect(find.text('на паузе'), findsOneWidget);
    expect(find.text('Hetonis Конфигуратор #441'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0 задач'), findsOneWidget);
    expect(
      find.text('заблокирован (ждёт владельца: R5 релизы по одной функции)'),
      findsOneWidget,
    );
  });

  testWidgets('the refresh button asks the plane again and redraws', (
    tester,
  ) async {
    var calls = 0;
    await _pump(tester, (r) {
      calls++;
      expect(r.url.path, '/v1/plane/progress');
      return _json({
        'plans': [_plan(288, 'Hopdeck', 'working', pct: calls == 1 ? 50 : 60)],
      });
    });
    expect(find.text('50% требований'), findsOneWidget);
    await tester.tap(find.byKey(const Key('progress-refresh')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('60% требований'), findsOneWidget);
  });

  testWidgets('unknown forecasts say so; English works too', (tester) async {
    await _pump(
      tester,
      (r) => _json({
        'plans': [_plan(7, 'Plan', 'waiting', pct: 10, total: 2, done: 2)],
      }),
      locale: 'en',
    );
    expect(find.text('Forecast'), findsOneWidget);
    expect(find.text('all 2 tasks of the stage done'), findsOneWidget);
    expect(find.text('not enough data yet'), findsOneWidget);
  });

  testWidgets('a failed first load offers to try again', (tester) async {
    var calls = 0;
    final done = Completer<void>();
    await _pump(tester, (r) {
      calls++;
      if (calls == 1) return _json({'code': 'x', 'message': 'down'}, 500);
      done.complete();
      return _json({'plans': []});
    });
    expect(find.text('Повторить'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(done.isCompleted, isTrue);
    expect(find.text('Открытых планов нет'), findsOneWidget);
  });
}
