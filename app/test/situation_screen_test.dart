import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/situation_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:accent/services/stalls_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<http.Response> _json(Object body) async => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

class _Env {
  _Env(this.payload);

  Map<String, dynamic> payload;
  final requests = <http.Request>[];
  late final GatewayClient client;
  late final StallsController controller;

  Future<http.Response> handle(http.Request r) {
    requests.add(r);
    final path = r.url.path;
    if (path == '/v1/plane/stalls') return _json(payload);
    if (path == '/v1/plane/plans/101/guidance') {
      return _json({
        'plan_id': '101',
        'comment_url': 'https://example.org/issues/101#c1',
      });
    }
    if (path.startsWith('/v1/plane/queue')) return _json({'queue': []});
    return _json({});
  }
}

Future<_Env> _pump(
  WidgetTester tester,
  Map<String, dynamic> payload, {
  Size size = const Size(1080, 6000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final env = _Env(payload);
  env.client = GatewayClient(
    baseUri: Uri.parse('https://gateway.example.com:8443'),
    token: 't',
    httpClient: MockClient(env.handle),
  );
  env.controller = StallsController(
    env.client,
    pollInterval: const Duration(hours: 1),
  )..start();
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SituationScreen(client: env.client, controller: env.controller),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return env;
}

Map<String, dynamic> _att(
  String kind,
  String severity,
  int issue, {
  String detail = '',
}) => {
  'kind': kind,
  'severity': severity,
  'issue': issue,
  'title': 'Plan $issue',
  'detail': detail,
};

void main() {
  testWidgets('question card replies through the dialog', (tester) async {
    final env = await _pump(tester, {
      'attention': [_att('question', 'act', 101)],
    });
    expect(find.text('Question'), findsOneWidget);
    expect(find.text('#101 Plan 101'), findsOneWidget);
    await tester.tap(find.byKey(const Key('situation-attention-action-0')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('situation-reply-send')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const Key('situation-reply-field')),
      'please rebase',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('situation-reply-send')));
    await tester.pumpAndSettle();
    final posts = env.requests.where((r) => r.method == 'POST').toList();
    expect(posts, hasLength(1));
    expect(posts.single.url.path, '/v1/plane/plans/101/guidance');
    expect(jsonDecode(posts.single.body), {'text': 'please rebase'});
    expect(
      find.text('Sent: https://example.org/issues/101#c1'),
      findsOneWidget,
    );
    env.controller.dispose();
  });

  testWidgets('info items are collapsed until toggled', (tester) async {
    final env = await _pump(tester, {
      'attention': [
        _att('question', 'act', 101, detail: 'act detail'),
        _att('blocked', 'warn', 102, detail: 'warn detail'),
        _att('disk', 'info', 103, detail: 'info detail'),
      ],
    });
    expect(find.text('act detail'), findsOneWidget);
    expect(find.text('warn detail'), findsOneWidget);
    expect(find.text('info detail'), findsNothing);
    await tester.tap(find.byKey(const Key('situation-info-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('info detail'), findsOneWidget);
    env.controller.dispose();
  });

  testWidgets('unknown state falls back to the code', (tester) async {
    final env = await _pump(tester, {
      'plans': [
        {'issue': 102, 'title': 'Plan 102', 'state': 'mystery_state'},
        {'issue': 101, 'title': 'Plan 101', 'state': 'working'},
      ],
      'states': <String, String>{},
    });
    expect(
      find.descendant(
        of: find.byKey(const Key('situation-state-102')),
        matching: find.text('mystery_state'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('situation-state-101')),
        matching: find.text('Working'),
      ),
      findsOneWidget,
    );
    env.controller.dispose();
  });

  testWidgets('long state label keeps the title readable', (tester) async {
    final env = await _pump(tester, {
      'plans': [
        {
          'issue': 372,
          'title': 'Spreadsheet export for the weekly report',
          'state': 'repo_busy',
          'detail': 'round leased',
          'sessions': 0,
          'for_min': 12,
        },
      ],
      'states': {
        'repo_busy':
            "ready work waits for its repository, leased by another plan's round",
      },
    }, size: const Size(360, 6000));
    expect(tester.takeException(), isNull);
    final title = find.text('#372 Spreadsheet export for the weekly report');
    expect(title, findsOneWidget);
    expect(tester.getSize(title).width, greaterThanOrEqualTo(200));
    expect(tester.getSize(title).height, lessThanOrEqualTo(60));
    final chip = find.byKey(const Key('situation-state-372'));
    expect(chip, findsOneWidget);
    expect(tester.getSize(chip).width, lessThanOrEqualTo(360));
    env.controller.dispose();
  });

  testWidgets('long build waits are highlighted', (tester) async {
    final env = await _pump(tester, {
      'waiting': [
        {'issue': '150', 'item': 't5.s1', 'waited_min': 25},
        {'kind': 'offload', 'waited_min': 5},
      ],
    });
    expect(find.byKey(const Key('situation-wait-long-0')), findsOneWidget);
    expect(find.byKey(const Key('situation-wait-long-1')), findsNothing);
    expect(find.byKey(const Key('situation-wait-1')), findsOneWidget);
    env.controller.dispose();
  });

  testWidgets('7 days refetches with hours=168', (tester) async {
    final env = await _pump(tester, {});
    await tester.tap(find.byKey(const Key('situation-hours-168')));
    await tester.pumpAndSettle();
    final last = env.requests.lastWhere(
      (r) => r.url.path == '/v1/plane/stalls',
    );
    expect(last.url.queryParameters['hours'], '168');
    env.controller.dispose();
  });

  testWidgets('held attention resumes the plan', (tester) async {
    final env = await _pump(tester, {
      'attention': [_att('held', 'act', 103)],
    });
    await tester.tap(find.byKey(const Key('situation-attention-action-0')));
    await tester.pumpAndSettle();
    expect(
      env.requests.any(
        (r) => r.method == 'POST' && r.url.path == '/v1/plane/queue/103/resume',
      ),
      isTrue,
    );
    expect(find.text('Done'), findsOneWidget);
    env.controller.dispose();
  });

  test('stallStateLabel and attentionKindLabel', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(stallStateLabel(l10n, 'working', {}), 'Working');
    expect(
      stallStateLabel(l10n, 'scheduler', {}),
      'Scheduler has not topped up',
    );
    expect(stallStateLabel(l10n, 'odd', {'odd': 'Odd one'}), 'Odd one');
    expect(stallStateLabel(l10n, 'odd', {}), 'odd');
    expect(attentionKindLabel(l10n, 'host_busy'), 'Build host busy');
    expect(attentionKindLabel(l10n, 'other'), 'other');
  });
}
