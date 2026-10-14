import 'dart:convert';

import 'package:accent/l10n/app_localizations.dart';
import 'package:accent/screens/usage_screen.dart';
import 'package:accent/services/gateway_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _bucketJson(int steps, {int untracked = 0}) => {
  'steps': steps,
  'untracked_steps': untracked,
  'cost_usd': 1.5,
  'input_tokens': 12345,
  'output_tokens': 100,
  'cache_read_tokens': 0,
  'cache_write_tokens': 0,
};

final _fixture = {
  'generated_at': '2026-10-13T09:00:00Z',
  'models': [
    {
      'model': 'example-model',
      'today': _bucketJson(3),
      'last_7d': _bucketJson(42, untracked: 2),
      'last_30d': _bucketJson(100),
    },
  ],
  'roles': [
    {
      'role': 'chat',
      'model': 'example-model',
      'today': _bucketJson(0),
      'last_7d': _bucketJson(5),
      'last_30d': _bucketJson(5),
    },
    {
      'role': 'executor',
      'model': 'example-model',
      'today': _bucketJson(0),
      'last_7d': _bucketJson(37),
      'last_30d': _bucketJson(37),
    },
  ],
};

Map<String, dynamic> _sw(
  String tier,
  String model, {
  bool enabled = true,
  String? standIn,
  String? standInModel,
  String? until,
  String? reason,
}) => {
  'tier': tier,
  'model': model,
  'enabled': enabled,
  'stand_in': standIn,
  'stand_in_model': standInModel,
  'until': until,
  'reason': reason,
};

final _models = {
  'models': [_sw('opus', 'model-a'), _sw('sonnet', 'model-b')],
};

Future<void> _pump(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handler,
) async {
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
      home: Scaffold(body: UsageScreen(client: client)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<http.Response> _json(Object body, [int status = 200]) async =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<http.Response> _ok(http.Request r) async =>
    _json(r.url.path == '/v1/plane/models' ? _models : _fixture);

Future<http.Response> Function(http.Request) _recording(
  List<http.Request> log, {
  Map<String, dynamic>? models,
  Future<http.Response> Function(http.Request)? onPost,
}) => (r) async {
  if (r.method == 'POST') {
    log.add(r);
    if (onPost != null) return onPost(r);
  }
  if (r.url.path == '/v1/plane/models') return _json(models ?? _models);
  return _json(_fixture);
};

Finder _switch(String tier) => find.byKey(Key('model-switch-$tier'));

bool _value(WidgetTester tester, String tier) =>
    tester.widget<SwitchListTile>(_switch(tier)).value;

final _opusOff = {
  'models': [
    _sw(
      'opus',
      'model-a',
      enabled: false,
      standIn: 'sonnet',
      standInModel: 'model-b',
      reason: 'owner',
    ),
    _sw('sonnet', 'model-b'),
  ],
};

void main() {
  group('formatTokens', () {
    test('formats plain, thousands and millions', () {
      expect(formatTokens(999), '999');
      expect(formatTokens(12345), '12.3k');
      expect(formatTokens(4560000), '4.56M');
    });
  });

  testWidgets('shows the 7 day window by default', (tester) async {
    await _pump(tester, _ok);
    expect(find.text('Steps: 42'), findsOneWidget);
    expect(find.text('2 steps predate token accounting'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('chat'), findsNothing);
    expect(find.text('executor'), findsOneWidget);
  });

  testWidgets('switching to Today changes the figures and hides idle roles', (
    tester,
  ) async {
    await _pump(tester, _ok);
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(find.text('Steps: 3'), findsOneWidget);
    expect(find.text('Steps: 42'), findsNothing);
    expect(find.text('executor'), findsNothing);
  });

  testWidgets('shows the error and a retry button', (tester) async {
    await _pump(
      tester,
      (r) async => http.Response(
        jsonEncode({'code': 'plane_unavailable', 'message': 'down'}),
        503,
        headers: {'content-type': 'application/json'},
      ),
    );
    expect(find.text('The control plane is not answering'), findsNWidgets(2));
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the switches work while the usage figures fail', (tester) async {
    final log = <http.Request>[];
    await _pump(tester, (r) async {
      if (r.method == 'POST') {
        log.add(r);
        return _json(_opusOff);
      }
      if (r.url.path == '/v1/plane/models') return _json(_models);
      return _json({'code': 'internal', 'message': 'boom'}, 500);
    });
    expect(_switch('opus'), findsOneWidget);
    expect(_switch('sonnet'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(_switch('opus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch off'));
    await tester.pumpAndSettle();
    expect(log, hasLength(1));
    expect(log.single.method, 'POST');
    expect(log.single.url.path, '/v1/plane/models/opus/disable');
    expect(_value(tester, 'opus'), false);
  });

  testWidgets('renders the Models section with a switch per tier', (
    tester,
  ) async {
    await _pump(tester, _ok);
    expect(find.text('Models'), findsOneWidget);
    expect(find.text('opus'), findsOneWidget);
    expect(find.text('model-a'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsNWidgets(2));
  });

  testWidgets('switching a tier off confirms, posts and replaces the list', (
    tester,
  ) async {
    final log = <http.Request>[];
    await _pump(tester, _recording(log, onPost: (r) => _json(_opusOff)));
    await tester.tap(_switch('opus'));
    await tester.pumpAndSettle();
    expect(find.text('Switch opus off?'), findsOneWidget);
    await tester.tap(find.text('Switch off'));
    await tester.pumpAndSettle();
    expect(log, hasLength(1));
    expect(log.single.url.path, '/v1/plane/models/opus/disable');
    expect(
      find.textContaining('Off — running on sonnet (model-b)'),
      findsOneWidget,
    );
    expect(_value(tester, 'opus'), false);
  });

  testWidgets('cancelling the dialog posts nothing', (tester) async {
    final log = <http.Request>[];
    await _pump(tester, _recording(log));
    await tester.tap(_switch('opus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(_value(tester, 'opus'), true);
  });

  testWidgets('the last model cannot be switched off', (tester) async {
    final log = <http.Request>[];
    await _pump(
      tester,
      _recording(
        log,
        onPost: (r) => _json({'code': 'last_model', 'message': 'x'}, 409),
      ),
    );
    await tester.tap(_switch('opus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch off'));
    await tester.pumpAndSettle();
    expect(
      find.text('This is the last model that is on; it cannot be switched off'),
      findsOneWidget,
    );
    expect(_value(tester, 'opus'), true);
  });

  testWidgets('a disabled tier shows its until time', (tester) async {
    final log = <http.Request>[];
    await _pump(
      tester,
      _recording(
        log,
        models: {
          'models': [
            _sw(
              'opus',
              'model-a',
              enabled: false,
              standIn: 'sonnet',
              standInModel: 'model-b',
              until: '2026-10-14T18:00:00.000Z',
            ),
            _sw('sonnet', 'model-b'),
          ],
        },
      ),
    );
    expect(find.textContaining('until '), findsOneWidget);
  });

  testWidgets('switching a disabled tier on posts enable without a dialog', (
    tester,
  ) async {
    final log = <http.Request>[];
    await _pump(
      tester,
      _recording(log, models: _opusOff, onPost: (r) => _json(_models)),
    );
    await tester.tap(_switch('opus'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(log, hasLength(1));
    expect(log.single.url.path, '/v1/plane/models/opus/enable');
    expect(_value(tester, 'opus'), true);
  });

  testWidgets('a models failure leaves the usage figures in place', (
    tester,
  ) async {
    await _pump(
      tester,
      (r) => r.url.path == '/v1/plane/models'
          ? _json({'code': 'plane_not_configured', 'message': 'x'}, 404)
          : _json(_fixture),
    );
    expect(find.text('Steps: 42'), findsOneWidget);
    expect(
      find.text('No control plane is configured on this server'),
      findsOneWidget,
    );
  });
}
