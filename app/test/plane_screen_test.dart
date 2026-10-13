import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/plane_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  final posts = <Map<String, dynamic>>[];

  Future<http.Response> handler(http.Request request) async {
    final route = '${request.method} ${request.url.path}';
    switch (route) {
      case 'GET /v1/plane/plans':
        return _json({
          'plans': [
            {
              'id': 'p1',
              'title': 'Example plan',
              'status': 'active',
              'tasks': [
                {
                  'id': 't1',
                  'title': 'Write the parser',
                  'status': 'done',
                  'target': 'core',
                  'subtasks_done': 2,
                  'subtasks_total': 2,
                },
                {
                  'id': 't2',
                  'title': 'Ship the screen',
                  'status': 'pending',
                  'target': 'app',
                  'subtasks_done': 0,
                  'subtasks_total': 0,
                },
              ],
            },
          ],
        });
      case 'GET /v1/plane/status':
        return _json({
          'generated_at': '2026-10-13T10:00:00Z',
          'providers': [
            {'name': 'anthropic', 'has_key': true, 'current': true},
            {
              'name': 'other',
              'has_key': true,
              'current': false,
              'cooling_until': '2026-10-13T12:00:00Z',
              'reason': 'rate limited',
            },
          ],
          'services': [
            {'name': 'worker', 'healthy': true},
          ],
          'paused': [],
        });
      case 'GET /v1/plane/actions':
        return _json({
          'actions': [
            {'token': 's', 'args': 'none', 'summary': 'status'},
            {'token': 'p', 'args': 'int', 'summary': 'plan progress'},
          ],
        });
      case 'POST /v1/plane/actions':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        posts.add(body);
        return _json({
          'token': body['token'],
          'exit_code': 0,
          'output': body['token'] == 's' ? 'all quiet' : 'progress 7',
        });
    }
    return _json({'code': 'not_found', 'message': route}, 404);
  }

  Future<void> pumpScreen(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) h,
  ) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final client = GatewayClient(
      baseUri: Uri.parse('https://gateway.example.com:8443'),
      token: 't',
      httpClient: MockClient(h),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: PlaneScreen(client: client)),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(posts.clear);

  testWidgets('task rows show done and pending icons', (tester) async {
    await pumpScreen(tester, handler);
    final done = find.widgetWithText(ListTile, 'Write the parser');
    final pending = find.widgetWithText(ListTile, 'Ship the screen');
    expect(
      find.descendant(of: done, matching: find.byIcon(Icons.check_circle)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: pending, matching: find.byIcon(Icons.check_circle)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: pending,
        matching: find.byIcon(Icons.radio_button_unchecked),
      ),
      findsOneWidget,
    );
  });

  testWidgets('cooling provider shown, empty paused section hidden', (
    tester,
  ) async {
    await pumpScreen(tester, handler);
    expect(find.textContaining('rate limited'), findsOneWidget);
    expect(find.text('Paused models'), findsNothing);
  });

  testWidgets('action without args runs at once', (tester) async {
    await pumpScreen(tester, handler);
    await tester.tap(find.text('!s'));
    await tester.pumpAndSettle();
    expect(posts, [
      {'token': 's'},
    ]);
    expect(posts.single.containsKey('arg'), isFalse);
    expect(find.text('all quiet'), findsOneWidget);
    expect(find.text('Exit code 0'), findsOneWidget);
  });

  testWidgets('action with int arg asks for it first', (tester) async {
    await pumpScreen(tester, handler);
    await tester.tap(find.text('!p'));
    await tester.pumpAndSettle();
    expect(find.byKey(PlaneScreen.argField), findsOneWidget);
    expect(posts, isEmpty);

    await tester.tap(find.byKey(PlaneScreen.runButton));
    await tester.pumpAndSettle();
    expect(posts, isEmpty);
    expect(find.byKey(PlaneScreen.argField), findsOneWidget);

    await tester.enterText(find.byKey(PlaneScreen.argField), '7');
    await tester.tap(find.byKey(PlaneScreen.runButton));
    await tester.pumpAndSettle();
    expect(posts, [
      {'token': 'p', 'arg': '7'},
    ]);
    expect(find.text('progress 7'), findsOneWidget);
  });

  testWidgets('load error offers a retry', (tester) async {
    await pumpScreen(tester, (request) async {
      if (request.url.path == '/v1/plane/status') {
        return _json({'code': 'plane_unavailable', 'message': 'down'}, 503);
      }
      return handler(request);
    });
    expect(find.text('The control plane is not answering'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
